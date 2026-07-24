#!/usr/bin/env bash
# Copyright 2026 BitWise Media Group Ltd
# SPDX-License-Identifier: MIT

# Validate every chart manifest and CVE allowlist. Allowlist entries must carry a statement
# and an expiry no further out than scan.allowlistMaxDays; expired entries fail the lint so
# accepted risk is re-reviewed on schedule.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

need yq
failures=0
fail() {
  printf 'lint: %s\n' "$*" >&2
  failures=$((failures + 1))
}

max_days="$(global '.scan.allowlistMaxDays')"
new_days="$(global '.scan.allowlistNewDays')"
today_epoch="$(date +%s)"
horizon_epoch=$((today_epoch + max_days * 86400))

# derive-allowlist.sh stamps new entries with allowlistNewDays; if that exceeded the
# policy horizon every generated file would fail the per-entry check below, which is a
# confusing way to discover a bad config value.
((new_days <= max_days)) ||
  fail "config: scan.allowlistNewDays ($new_days) exceeds scan.allowlistMaxDays ($max_days)"

for manifest_file in "$ROOT"/charts/*/manifest.yaml; do
  [[ -e "$manifest_file" ]] || continue
  chart="$(basename "$(dirname "$manifest_file")")"
  log "chart: ${chart}"

  for field in .name .chart.repo .chart.name .chart.version .publish.chartRepo; do
    yq -e "$field" "$manifest_file" >/dev/null || fail "$chart: manifest missing $field"
  done

  [[ "$(yq '.name' "$manifest_file")" == "$chart" ]] ||
    fail "$chart: manifest .name must match its directory"

  repo="$(yq '.chart.repo // ""' "$manifest_file")"
  [[ "$repo" == oci://* || "$repo" == https://* ]] ||
    fail "$chart: .chart.repo must be an oci:// or https:// URL"

  provider="$(yq '.chart.verifyUpstream.provider // "none"' "$manifest_file")"
  case "$provider" in
  none | cosign-keyless | cosign-key) ;;
  *) fail "$chart: unknown chart verifyUpstream provider '$provider'" ;;
  esac

  # Tracked images: the tag is machine-picked into a values file, so the rule must name
  # both an image and a path that already resolves there — track-image-tags.sh replaces
  # a value, it never invents one, and a typo'd path would otherwise fail only in CI.
  track_count="$(yq '.images.track // [] | length' "$manifest_file")"
  for ((i = 0; i < track_count; i++)); do
    yq -e ".images.track[$i].image" "$manifest_file" >/dev/null ||
      fail "$chart: images.track[$i] missing image"
    track_path="$(yq ".images.track[$i].valuesPath // \"\"" "$manifest_file")"
    [[ -n "$track_path" ]] || fail "$chart: images.track[$i] missing valuesPath"
    cooldown="$(yq ".images.track[$i].cooldownDays // \"\"" "$manifest_file")"
    [[ -z "$cooldown" || "$cooldown" =~ ^[0-9]+$ ]] ||
      fail "$chart: images.track[$i] cooldownDays must be a non-negative integer (got '$cooldown')"
    track_file="$(yq ".images.track[$i].valuesFile // \"\"" "$manifest_file")"
    [[ -n "$track_file" ]] || track_file="$(yq '.discovery.valuesFiles[0] // ""' "$manifest_file")"
    if [[ -z "$track_file" ]]; then
      fail "$chart: images.track[$i] has no valuesFile and the chart declares no discovery.valuesFiles"
    elif [[ -n "$track_path" ]]; then
      track_abs="$(dirname "$manifest_file")/$track_file"
      if [[ ! -f "$track_abs" ]]; then
        fail "$chart: images.track[$i] valuesFile '$track_file' not found"
      else
        yq -e "$track_path" "$track_abs" >/dev/null 2>&1 ||
          fail "$chart: images.track[$i] valuesPath '$track_path' does not resolve in $track_file"
      fi
    fi
  done

  generate="$(yq '.scan.allowlist.generate // false' "$manifest_file")"
  case "$generate" in
  true | false) ;;
  *) fail "$chart: scan.allowlist.generate must be true or false (got '$generate')" ;;
  esac

  rule_count="$(yq '.images.verifyUpstream // [] | length' "$manifest_file")"
  [[ "$rule_count" -gt 0 ]] || fail "$chart: images.verifyUpstream must declare at least one rule (use provider: none to document a gap)"
  for ((i = 0; i < rule_count; i++)); do
    rp="$(yq ".images.verifyUpstream[$i].provider // \"\"" "$manifest_file")"
    case "$rp" in
    none | cosign-keyless | cosign-key) ;;
    *) fail "$chart: images.verifyUpstream[$i] has unknown provider '$rp'" ;;
    esac
    yq -e ".images.verifyUpstream[$i].match" "$manifest_file" >/dev/null ||
      fail "$chart: images.verifyUpstream[$i] missing match pattern"
  done

  # Non-mirror OCI references: an oci:// scalar in the rendered output is a
  # registry pull the platform will make at runtime, and anything outside the
  # mirror bypasses the review gate this repo exists to be (the FluxInstance
  # distribution.artifact chart default -- upstream's :latest -- shipped
  # ungated controller bumps exactly this way). Real refs are whole scalars
  # starting with oci://, which skips the prose mentions in CRD descriptions.
  # Escapes need an .ociRefs.allow entry carrying pattern + reason.
  rendered_file="$(dirname "$manifest_file")/rendered/manifests.yaml"
  if [[ -s "$rendered_file" ]]; then
    mirror_prefix="oci://$(global '.registry.url')"
    allow_count="$(yq '.ociRefs.allow // [] | length' "$manifest_file")"
    for ((i = 0; i < allow_count; i++)); do
      yq -e ".ociRefs.allow[$i].pattern" "$manifest_file" >/dev/null ||
        fail "$chart: ociRefs.allow[$i] missing pattern"
      yq -e ".ociRefs.allow[$i].reason" "$manifest_file" >/dev/null ||
        fail "$chart: ociRefs.allow[$i] missing reason (why may this bypass the mirror?)"
    done
    while IFS= read -r ref; do
      [[ -n "$ref" ]] || continue
      [[ "$ref" == "$mirror_prefix"* ]] && continue
      allowed=""
      for ((i = 0; i < allow_count; i++)); do
        pattern="$(yq ".ociRefs.allow[$i].pattern // \"\"" "$manifest_file")"
        [[ -n "$pattern" ]] && glob_match "$pattern" "$ref" && allowed=1 && break
      done
      [[ -n "$allowed" ]] ||
        fail "$chart: rendered manifests reference '$ref' outside the mirror (allow via .ociRefs.allow with a reason, or fix the values)"
    done < <(yq ea '.. | select(tag == "!!str") | select(test("^oci://"))' "$rendered_file" 2>/dev/null | sort -u)
  fi

  allowlist="$(dirname "$manifest_file")/security/allowlist.yaml"
  if [[ -f "$allowlist" ]]; then
    entries="$(yq '.vulnerabilities // [] | length' "$allowlist")"
    for ((i = 0; i < entries; i++)); do
      id="$(yq ".vulnerabilities[$i].id // \"\"" "$allowlist")"
      statement="$(yq ".vulnerabilities[$i].statement // \"\"" "$allowlist")"
      expiry="$(yq ".vulnerabilities[$i].expired_at // \"\"" "$allowlist")"
      [[ -n "$id" ]] || fail "$chart: allowlist entry $i missing id"
      [[ -n "$statement" ]] || fail "$chart: allowlist $id missing statement"
      if [[ -z "$expiry" ]]; then
        fail "$chart: allowlist $id missing expired_at"
      else
        expiry_epoch="$(date -j -f '%Y-%m-%d' "$expiry" +%s 2>/dev/null || date -d "$expiry" +%s 2>/dev/null)" ||
          {
            fail "$chart: allowlist $id has unparseable expired_at '$expiry'"
            continue
          }
        ((expiry_epoch > today_epoch)) || fail "$chart: allowlist $id expired on $expiry"
        ((expiry_epoch <= horizon_epoch)) || fail "$chart: allowlist $id expires more than $max_days days out"
      fi
    done
  fi
done

((failures == 0)) || die "$failures lint failure(s)"
log "all manifests and allowlists valid"
