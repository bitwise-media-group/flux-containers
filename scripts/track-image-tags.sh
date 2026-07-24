#!/usr/bin/env bash
# Copyright 2026 BitWise Media Group Ltd
# SPDX-License-Identifier: MIT

# Re-pick the pinned tag for every image a chart declares under .images.track, and write
# it into the chart's discovery values. These are images on a release train of their own
# (the actions runner moves independently of the scale set chart), so nothing about the
# chart version tells us which tag to mirror -- and a chart default like `:latest` is a
# mutable tag the pipeline must never lock.
#
# Selection walks candidate tags newest-first and takes the first one published at least
# cooldownDays ago, so a release that gets yanked or hot-fixed within its soak period is
# never the one the platform adopts.
#
# Deliberately NOT part of `discover`/`refresh`: the pick depends on wall-clock time, and
# refresh must stay deterministic or pr-validate's byte-identity gate would fail whenever
# a tag aged past the cooldown between commit and CI. Only `make update` (and the daily
# update-check workflow) re-picks; every other stage uses the committed pin.
#
# Prints one `<image>\t<current-tag>\t<selected-tag>` line per tracked image, so callers
# can tell whether anything moved without diffing the tree. --check skips the write.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

check_only=""
[[ "${1:-}" == "--check" ]] && { check_only=1; shift; }
chart="${1:?usage: track-image-tags.sh [--check] <chart>}"
need yq crane jq

dir="$(chart_dir "$chart")"
m="$(manifest_path "$chart")"

# Walking every tag of a busy repository would be a lot of manifest fetches; a tag old
# enough to clear the cooldown is always within the first few of a newest-first walk.
max_candidates=25

count="$(yq '.images.track // [] | length' "$m")"
((count > 0)) || exit 0

now="$(date +%s)"
default_cooldown="$(global '.update.cooldownDays')"

for ((i = 0; i < count; i++)); do
  image="$(yq -e ".images.track[$i].image" "$m")" || die "$chart: images.track[$i] missing image"
  values_path="$(yq -e ".images.track[$i].valuesPath" "$m")" || die "$chart: images.track[$i] missing valuesPath"
  constraint="$(yq ".images.track[$i].versionConstraint // \"\"" "$m")"
  cooldown="$(yq ".images.track[$i].cooldownDays // \"\"" "$m")"
  [[ -n "$cooldown" ]] || cooldown="$default_cooldown"
  values_file="$(yq ".images.track[$i].valuesFile // \"\"" "$m")"
  [[ -n "$values_file" ]] || values_file="$(yq '.discovery.valuesFiles[0] // ""' "$m")"
  [[ -n "$values_file" ]] || die "$chart: images.track[$i] has no valuesFile and the chart declares no discovery.valuesFiles"
  [[ -f "$dir/$values_file" ]] || die "$chart: values file '$values_file' not found under charts/$chart/"

  current_ref="$(yq -e "$values_path" "$dir/$values_file")" ||
    die "$chart: '$values_path' does not resolve in $values_file (the tracked pin must already exist there)"
  current_tag="${current_ref##*:}"

  cutoff=$((now - cooldown * 86400))
  log "$image: picking newest tag published before $(TZ=UTC date -r "$cutoff" '+%Y-%m-%d' 2>/dev/null || date -u -d "@$cutoff" '+%Y-%m-%d') (${cooldown}d cooldown)"

  # Release tags only: this also drops the sha256-... referrer tags cosign attaches, and
  # any moving alias (`latest`) we must never pin.
  candidates="$(crane ls "$(rewrite_source "$image")" |
    grep -E '^v?[0-9]+\.[0-9]+\.[0-9]+$' | sort -Vr || true)"
  [[ -n "$candidates" ]] || die "$chart: no versioned tags found for $image"

  selected=""
  examined=0
  while IFS= read -r tag; do
    [[ -n "$tag" ]] || continue
    v="${tag#v}"
    if [[ -n "$constraint" ]]; then
      semver_in_range "$v" "$constraint" || continue
    fi
    ((examined++))
    if ((examined > max_candidates)); then
      die "$chart: no tag of $image cleared the ${cooldown}d cooldown within the newest $max_candidates in-constraint tags"
    fi
    created="$(crane config "$(rewrite_source "$image"):$tag" 2>/dev/null | jq -r '.created // ""')"
    [[ -n "$created" ]] || { warn "$image:$tag has no creation timestamp; skipping"; continue; }
    created_epoch="$(epoch_of_rfc3339 "$created")"
    if ((created_epoch <= cutoff)); then
      selected="$tag"
      break
    fi
    log "  skipping $tag (published ${created%%T*}, inside the cooldown)"
  done <<< "$candidates"

  [[ -n "$selected" ]] || die "$chart: no tag of $image satisfies the constraint and the ${cooldown}d cooldown"

  printf '%s\t%s\t%s\n' "$image" "$current_tag" "$selected"

  if [[ "$selected" == "$current_tag" ]]; then
    log "  $image:$selected already pinned"
    continue
  fi
  if [[ -n "$check_only" ]]; then
    log "  $image: $current_tag -> $selected (not written, --check)"
    continue
  fi
  REF="$image:$selected" yq -i "$values_path = strenv(REF)" "$dir/$values_file"
  log "  $image: $current_tag -> $selected (written to $values_file)"
done
