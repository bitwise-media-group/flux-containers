#!/usr/bin/env bash
# Copyright 2026 BitWise Media Group Ltd
# SPDX-License-Identifier: MIT

# Publish the chart to Artifact Registry and sign it keylessly. The pushed artifact is the
# byte-identical upstream tgz: we re-pull it, verify its digest against the lock and its
# contents against the committed vendor tree, so what ships is exactly what the PR reviewed.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

chart="${1:?usage: publish-chart.sh <chart>}"
need helm yq crane cosign

dir="$(chart_dir "$chart")"
name="$(manifest "$chart" '.chart.name')"
version="$(manifest "$chart" '.chart.version')"
lock="$(lock_path "$chart")"
[[ -f "$lock" ]] || die "no lock for chart '$chart'"

registry="$(global '.registry.url')"
identity="$(global '.signing.certificateIdentity')"
issuer="$(global '.signing.certificateOidcIssuer')"
chart_repo="$(manifest "$chart" '.publish.chartRepo')"

work="$(mktemp -d "${TMPDIR:-/tmp}/publish.XXXXXX")"
trap 'rm -rf "$work"' EXIT

tgz="$(pull_chart_tgz "$chart" "$work")"
expected_sha="$(yq -e '.chart.upstreamTgzSha256' "$lock")"
actual_sha="$(sha256_of "$tgz")"
[[ "$actual_sha" == "$expected_sha" ]] ||
  die "upstream tgz digest mismatch: lock has $expected_sha, upstream now serves $actual_sha"

mkdir -p "$work/extracted"
tar -xzf "$tgz" -C "$work/extracted"
diff -r "$work/extracted/$name" "$dir/vendor/$name" >/dev/null ||
  die "committed vendor tree differs from the upstream chart; re-run vendor-chart.sh"

if crane digest "$registry/$chart_repo:$version" >/dev/null 2>&1; then
  digest="$(crane digest "$registry/$chart_repo:$version")"
  log "chart version already published ($digest); verifying signature"
else
  log "pushing $name $version to oci://$registry/${chart_repo%/*}"
  push_output="$(helm push "$tgz" "oci://$registry/${chart_repo%/*}")"
  echo "$push_output" >&2
  digest="$(grep -Eo 'sha256:[a-f0-9]{64}' <<<"$push_output" | head -1)"
  [[ -n "$digest" ]] || die "could not determine pushed chart digest"
fi

if ! cosign verify --certificate-identity "$identity" --certificate-oidc-issuer "$issuer" "$registry/$chart_repo@$digest" >/dev/null; then
  log "signing $registry/$chart_repo@$digest"
  # legacy .sig-tag path (see publish-images.sh); public Rekor entry by design
  cosign sign --tlog-upload=true --use-signing-config=false --yes "$registry/$chart_repo@$digest"
fi

log "chart published: $registry/$chart_repo:$version@$digest"
