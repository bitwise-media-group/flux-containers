#!/usr/bin/env bash
# Copyright 2026 BitWise Media Group Ltd
# SPDX-License-Identifier: MIT

# Discover every container image referenced by the rendered chart, resolve each to a digest,
# and write images.lock.yaml. CI regenerates the lock and fails on any diff, so a reviewed
# chart bump always carries its reviewed image set.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

chart="${1:?usage: extract-images.sh <chart>}"
need yq crane jq

dir="$(chart_dir "$chart")"
name="$(manifest "$chart" '.chart.name')"
rendered="$dir/rendered/manifests.yaml"
[[ -s "$rendered" ]] || die "chart '$chart' is not rendered (or rendered empty); run render-chart.sh first"

image_ns="$(global '.registry.imageNamespace')"
registry="$(global '.registry.url')"
app_version="$(yq '.appVersion // ""' "$dir/vendor/$name/Chart.yaml")"

refs="$(mktemp "${TMPDIR:-/tmp}/images.XXXXXX")"
trap 'rm -rf "$refs"' EXIT

# Pod-spec images: any containers/initContainers/ephemeralContainers list at any depth.
# Guards: CRDs embed pod-template *schemas* where these keys hold maps, not lists.
for key in containers initContainers ephemeralContainers; do
  yq ea ".. | select(type == \"!!map\") | .$key | select(type == \"!!seq\")
          | .[] | select(type == \"!!map\") | .image // \"\"" "$rendered" 2>/dev/null \
    | grep -Ev '^(null|---)?$' >> "$refs" || true
done

# Operator-style CRs (Prometheus, Alertmanager, ThanosRuler) declare their workload image
# as a top-level spec.image rather than a pod spec.
yq ea '.spec.image | select(type == "!!str")' "$rendered" 2>/dev/null \
  | grep -Ev '^(null|---)?$' >> "$refs" || true

# Conservative pass over ConfigMap data for image-shaped strings (catches embedded pod
# templates; charts hiding images behind separate hub/tag fields need manifest images.extra).
yq ea 'select(.kind == "ConfigMap") | .data[]?' "$rendered" 2>/dev/null \
  | grep -Eo '"?image"?[[:space:]]*[:=][[:space:]]*"?[a-z0-9][a-z0-9._/-]*(:[0-9]+)?/[a-z0-9._/-]+:[a-zA-Z0-9][a-zA-Z0-9._-]*"?' \
  | sed -E 's/^"?image"?[[:space:]]*[:=][[:space:]]*"?//; s/"$//' \
  | grep -Ev '[{}$]' >> "$refs" || true

# Manifest-declared extras ({appVersion} expands from the vendored Chart.yaml).
while IFS= read -r extra; do
  [[ -n "$extra" ]] && printf '%s\n' "${extra//\{appVersion\}/$app_version}" >> "$refs"
done < <(yq '.images.extra // [] | .[].image' "$(manifest_path "$chart")")

# while-read rather than mapfile: macOS ships bash 3.2, and local runs use it.
excludes=()
while IFS= read -r pattern; do
  [[ -n "$pattern" ]] && excludes+=("$pattern")
done < <(yq '.images.exclude // [] | .[].pattern' "$(manifest_path "$chart")")

images=()
while IFS= read -r ref; do
  [[ -n "$ref" ]] || continue
  ref="$(normalize_image "$ref")"
  skip=""
  for pattern in "${excludes[@]:-}"; do
    [[ -n "$pattern" ]] && glob_match "$pattern" "$ref" && skip=1 && break
  done
  [[ -n "$skip" ]] && { log "excluded: $ref"; continue; }
  images+=("$ref")
done < <(sort -u "$refs")

allow_empty="$(manifest_or "$chart" '.images.allowEmpty' 'false')"
if [[ ${#images[@]} -eq 0 && "$allow_empty" != "true" ]]; then
  die "no images discovered for chart '$chart'; check discovery values (or set images.allowEmpty for CRD-only charts)"
fi

lock="$(lock_path "$chart")"
[[ -f "$lock" ]] || die "no lock for chart '$chart'; run vendor-chart.sh first"
yq -i '.images = []' "$lock"

for ref in "${images[@]}"; do
  pull_ref="$(rewrite_source "$ref")"
  log "resolving $ref"
  digest="$(crane digest "$pull_ref")" || die "failed to resolve digest for $ref (via $pull_ref)"
  platforms="$(crane manifest "$pull_ref" | jq -c '[.manifests[]? | .platform | select(.os != "unknown") | "\(.os)/\(.architecture)"] | unique')"
  # Split repo/tag, tolerating pinned digests (repo:tag@sha256:...) and registry ports.
  base="${ref%%@*}"
  if [[ "${base##*/}" == *:* ]]; then
    tag="${base##*:}"
    repo_path="${base%:*}"
  else
    tag="latest"
    repo_path="$base"
  fi
  SRC="$ref" DIGEST="$digest" TARGET="$registry/$image_ns/$repo_path:$tag" PLATFORMS="$platforms" \
    yq -i '.images += [{
      "source": env(SRC),
      "digest": env(DIGEST),
      "target": env(TARGET),
      "platforms": env(PLATFORMS)
    }]' "$lock"
done

yq -i '.images |= sort_by(.source)' "$lock"
log "wrote $lock (${#images[@]} images)"
