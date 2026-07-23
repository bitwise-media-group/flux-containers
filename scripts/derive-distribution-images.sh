#!/usr/bin/env bash
# Copyright 2026 BitWise Media Group Ltd
# SPDX-License-Identifier: MIT

# Rewrite the manifest's .images.extra from the flux distribution manifests
# artifact, for charts that declare .images.distributionManifests. The flux
# controllers are deployed by the operator from the FluxInstance CR, so helm
# discovery can never see them -- and hand-pinned extras drift the moment
# upstream cuts a release (the operator resolves the newest patch within its
# embedded minors, then pulls images the mirror doesn't carry). Deriving the
# set from the artifact tag matching the vendored chart's appVersion keeps
# the mirrored images in lockstep with the operator's embedded manifests by
# construction: one chart bump PR moves both. No-op for other charts.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

chart="${1:?usage: derive-distribution-images.sh <chart>}"
need yq crane

dir="$(chart_dir "$chart")"
name="$(manifest "$chart" '.chart.name')"

artifact="$(yq '.images.distributionManifests.artifact // ""' "$(manifest_path "$chart")")"
[[ -n "$artifact" ]] || exit 0

app_version="$(yq -e '.appVersion' "$dir/vendor/$name/Chart.yaml")" ||
  die "$chart: no vendored appVersion to expand the artifact ref with; run vendor-chart.sh first"
artifact="${artifact//\{appVersion\}/$app_version}"

work="$(mktemp -d "${TMPDIR:-/tmp}/distro.XXXXXX")"
trap 'rm -rf "$work"' EXIT

# The artifact is a single gzipped-tar layer holding flux/<version>/ manifest
# trees; crane export flattens it to the tree as a tar stream.
log "pulling distribution manifests $artifact"
crane export "${artifact#oci://}" - | tar -x -C "$work" flux

# The operator deploys the newest flux version present in its manifests (the
# release-frozen artifact and the operator image embed the same tree).
flux_version="$(find "$work/flux" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; | sort -V | tail -1)"
[[ -n "$flux_version" ]] || die "$chart: no flux versions in $artifact"

extras="$work/extras.yaml"
: > "$extras"
while IFS= read -r component; do
  [[ -n "$component" ]] || continue
  src="$work/flux/$flux_version/$component.yaml"
  [[ -f "$src" ]] || die "$chart: $artifact has no $component manifests for flux $flux_version"
  image="$(yq -e 'select(.kind == "Deployment") | .spec.template.spec.containers[0].image' "$src" | head -1)" ||
    die "$chart: no controller image in $src"
  # Distribution manifests carry registry-less refs (fluxcd/<name>:<tag>);
  # the operator prefixes distribution.registry, whose canonical home the
  # mirror preserves (images/ghcr.io/fluxcd).
  IMAGE="ghcr.io/$image" REASON="flux $flux_version distribution controller (derived from $artifact)" \
    yq -i '. += [{"image": env(IMAGE), "reason": env(REASON)}]' "$extras"
done < <(manifest "$chart" '.images.distributionManifests.components[]')

[[ -s "$extras" ]] || die "$chart: distributionManifests derived no images"

EXTRAS="$extras" yq -i '.images.extra = load(env(EXTRAS))' "$(manifest_path "$chart")"
log "derived $(yq 'length' "$extras") distribution images for flux $flux_version"
