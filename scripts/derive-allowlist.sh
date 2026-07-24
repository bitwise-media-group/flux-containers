#!/usr/bin/env bash
# Copyright 2026 BitWise Media Group Ltd
# SPDX-License-Identifier: MIT

# Regenerate charts/<name>/security/allowlist.yaml from a fresh scan of the locked images,
# for charts that opt in with .scan.allowlist.generate. Hand-curating a per-CVE list stops
# being review and starts being transcription once the images bump on their own schedule
# (.images.track) -- so the machine transcribes and the PR review is where the risk is
# actually accepted.
#
# Three rules make the regenerated file trustworthy rather than a rubber stamp:
#
#   - Findings that no longer appear are DROPPED. An allowlist entry outlives its finding
#     silently otherwise, and a stale accept is indistinguishable from a live one.
#   - Surviving entries KEEP their original expired_at. Regenerating must not roll the
#     clock forward, or nothing would ever reach re-review -- the expiry is the whole
#     forcing function. New entries get scan.allowlistNewDays from today.
#   - Per-entry `notes` are preserved verbatim. Statements are machine facts (package,
#     installed version, fixed-in version); anything a human concluded about reachability
#     belongs in notes, or in .scan.allowlist.preamble for whole-file context.
#
# Deliberately NOT part of refresh/validate: the finding set moves with grype's vulnerability
# database, so regenerating inside pr-validate would diff a tree nobody touched. `make update`
# runs it after refresh, which is exactly when the image set can have changed.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

chart="${1:?usage: derive-allowlist.sh <chart>}"
need yq jq grype

dir="$(chart_dir "$chart")"
m="$(manifest_path "$chart")"
lock="$(lock_path "$chart")"

[[ "$(manifest_or "$chart" '.scan.allowlist.generate' 'false')" == "true" ]] || exit 0
[[ -f "$lock" ]] || die "no lock for chart '$chart'; run refresh first"

out="$dir/security/allowlist.yaml"
work="$(mktemp -d "${TMPDIR:-/tmp}/allowlist.XXXXXX")"
trap 'rm -rf "$work"' EXIT

# Mirror scan.sh's gate exactly, or the generated file would accept findings the scan does
# not block (noise) or miss ones it does (a red gate no amount of regenerating clears).
if [[ "$(manifest_or "$chart" '.scan.failOn | join(",")' '')" != "" ]]; then
  severities="$(manifest "$chart" '.scan.failOn | join(",")')"
else
  severities="$(global '.scan.failOn | join(",")')"
fi
ignore_unfixed="$(manifest_or "$chart" '.scan.ignoreUnfixed' "$(global '.scan.ignoreUnfixed')")"

fail_on=""
for level in LOW MEDIUM HIGH CRITICAL; do
  if [[ ",$severities," == *",$level,"* ]]; then
    fail_on="$level"
    break
  fi
done
[[ -n "$fail_on" ]] || die "scan.failOn must contain one of LOW, MEDIUM, HIGH, CRITICAL (got '$severities')"

case "$fail_on" in
  CRITICAL) blocking='["Critical"]' ;;
  HIGH) blocking='["Critical","High"]' ;;
  MEDIUM) blocking='["Critical","High","Medium"]' ;;
  LOW) blocking='["Critical","High","Medium","Low"]' ;;
esac

grype_args=(--quiet -o json)
[[ "$ignore_unfixed" == "true" ]] && grype_args+=(--only-fixed)

# id \t package \t installed \t fixed-in, one row per (image, finding).
rows="$work/rows.tsv"
: > "$rows"
while IFS=$'\t' read -r source digest; do
  [[ -n "$source" ]] || continue
  ref="$(rewrite_source "${source%%:*}")@$digest"
  log "scanning $source for allowlist derivation"
  grype "${grype_args[@]}" "registry:$ref" 2>/dev/null |
    jq -r --argjson sevs "$blocking" '
      .matches[]
      | select(.vulnerability.severity as $s | $sevs | index($s))
      | [ .vulnerability.id,
          .artifact.name,
          .artifact.version,
          ((.vulnerability.fix.versions // []) | join(" "))
        ] | @tsv' >> "$rows" ||
    die "grype failed for $source"
done < <(yq '.images[] | [.source, .digest] | @tsv' "$lock")

sort -u -o "$rows" "$rows"

today_epoch="$(date +%s)"
new_days="$(global '.scan.allowlistNewDays')"
new_expiry="$(TZ=UTC date -r $((today_epoch + new_days * 86400)) '+%Y-%m-%d' 2>/dev/null ||
  date -u -d "@$((today_epoch + new_days * 86400))" '+%Y-%m-%d')"

# Previous file is the source of truth for expiries and notes; read before overwriting.
prev="$work/prev.yaml"
if [[ -f "$out" ]]; then cp "$out" "$prev"; else printf 'vulnerabilities: []\n' > "$prev"; fi

entries="$work/entries.json"
echo '[]' > "$entries"
kept=0
added=0

while IFS= read -r id; do
  [[ -n "$id" ]] || continue
  pkgs="$(ID="$id" awk -F'\t' -v id="$id" '$1 == id { print $2 }' "$rows" | sort -u | paste -sd '/' -)"
  installed="$(awk -F'\t' -v id="$id" '$1 == id { print $3 }' "$rows" | sort -uV | paste -sd '/' -)"
  # Advisories often list a chain of fixed-in versions across several release branches
  # (the Go stdlib reports 1.25.x, 1.26.x and a 1.27 rc for one finding). The useful
  # number is the lowest release ABOVE what the image ships -- the minimal upgrade that
  # clears it -- not the newest in the chain, which can be an rc from a branch the image
  # will never be on. Pre-releases are dropped outright; this pipeline only ships releases.
  fixes="$(awk -F'\t' -v id="$id" '$1 == id { for (i = 4; i <= NF; i++) print $i }' "$rows" |
    tr ' ' '\n' | grep . | grep -Eiv -e '-(rc|alpha|beta|pre|dev)' | sort -uV)"
  # Normalise for comparison only (v1.2.3, go1.26.4, 28.5.2+incompatible); the statement
  # still quotes the version string grype actually reported.
  max_installed="$(printf '%s\n' "$installed" | tr '/' '\n' |
    sed -E 's/^(v|go)//; s/\+.*$//' | sort -V | tail -1)"
  fixed="$(printf '%s\n%s\n' "$max_installed" "$fixes" | grep . | sort -uV |
    awk -v inst="$max_installed" 'found { print; exit } $0 == inst { found = 1 }')"
  # No listed fix above what is installed (a fix only on an older branch): fall back to
  # the newest release in the chain rather than claiming nothing exists.
  [[ -n "$fixed" ]] || fixed="$(printf '%s\n' "$fixes" | grep . | tail -1)"
  [[ -n "$fixed" ]] || fixed="an unreleased version"

  statement="Fixed in $pkgs $fixed; the locked image ships $installed. Derived from the grype scan at bump time; accepted in PR review."

  expiry="$(ID="$id" yq '.vulnerabilities[]? | select(.id == env(ID)) | .expired_at // ""' "$prev" | awk 'NR==1')"
  notes="$(ID="$id" yq '.vulnerabilities[]? | select(.id == env(ID)) | .notes // ""' "$prev" | awk 'NR==1')"
  if [[ -n "$expiry" ]]; then
    kept=$((kept + 1))
  else
    expiry="$new_expiry"
    added=$((added + 1))
  fi

  jq --arg id "$id" --arg st "$statement" --arg exp "$expiry" --arg notes "$notes" \
    '. += [ {id: $id, statement: $st, expired_at: $exp}
            + (if $notes == "" then {} else {notes: $notes} end) ]' \
    "$entries" > "$entries.tmp"
  mv "$entries.tmp" "$entries"
done < <(cut -f1 "$rows" | sort -u)

dropped=0
while IFS= read -r id; do
  [[ -n "$id" ]] || continue
  cut -f1 "$rows" | grep -qxF "$id" || { dropped=$((dropped + 1)); log "dropping $id (no longer reported)"; }
done < <(yq '.vulnerabilities[]?.id // ""' "$prev")

mkdir -p "$dir/security"
{
  printf '# Copyright 2026 BitWise Media Group Ltd\n'
  printf '# SPDX-License-Identifier: MIT\n\n'
  printf '# GENERATED by scripts/derive-allowlist.sh — do not hand-edit the entries.\n'
  printf '# Regenerated by "make update" from a fresh scan of images.lock.yaml: findings that\n'
  printf '# no longer appear are dropped, surviving entries keep their original expired_at, and\n'
  printf '# per-entry notes are preserved. Whole-file context lives in .scan.allowlist.preamble\n'
  printf '# in manifest.yaml; per-finding analysis goes in a "notes" field on the entry.\n'
  preamble="$(yq '.scan.allowlist.preamble // ""' "$m")"
  if [[ -n "$preamble" ]]; then
    printf '#\n'
    while IFS= read -r line; do
      if [[ -n "$line" ]]; then printf '# %s\n' "$line"; else printf '#\n'; fi
    done <<< "$preamble"
  fi
  jq -n --slurpfile e "$entries" '{vulnerabilities: $e[0]}' | yq -P
} > "$work/out.yaml"

# Match the quoting the hand-written allowlists use, so a chart opting in produces no
# gratuitous diff against the repo's existing style.
sed -E 's/^( *expired_at: )([0-9]{4}-[0-9]{2}-[0-9]{2})$/\1"\2"/' "$work/out.yaml" > "$out"

log "wrote $out ($kept kept, $added new, $dropped dropped)"

# An entry whose expiry has already passed fails lint by design; say so here rather than
# letting it surface as a mystery lint failure two steps later.
while IFS= read -r expiry; do
  [[ -n "$expiry" ]] || continue
  expiry_epoch="$(date -j -f '%Y-%m-%d' "$expiry" +%s 2>/dev/null || date -d "$expiry" +%s 2>/dev/null)" || continue
  ((expiry_epoch > today_epoch)) || warn "$chart: allowlist entries expired on $expiry — re-review required, lint will fail"
done < <(yq '.vulnerabilities[]?.expired_at // ""' "$out" | sort -u)
