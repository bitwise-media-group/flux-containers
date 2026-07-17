#!/usr/bin/env bash
# Copyright 2026 BitWise Media Group Ltd
# SPDX-License-Identifier: MIT

# Copy every locked image (by digest) to its mirror target and sign it keylessly (GitHub
# Actions OIDC -> Fulcio certificate + public Rekor entry). Idempotent: targets that
# already exist with the right digest and a valid signature are skipped, so re-runs never
# push twice. Target repositories need no pre-creation: Artifact Registry serves arbitrary
# slash paths beneath the one terraform-owned platform repository.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

chart="${1:?usage: publish-images.sh <chart>}"
need yq crane cosign

lock="$(lock_path "$chart")"
[[ -f "$lock" ]] || die "no lock for chart '$chart'"

identity="$(global '.signing.certificateIdentity')"
issuer="$(global '.signing.certificateOidcIssuer')"

while IFS=$'\t' read -r source digest target; do
  pull_ref="$(rewrite_source "${source%%:*}")@$digest"
  target_repo="${target%%:*}"
  target_digest_ref="$target_repo@$digest"

  if [[ "$(crane digest "$target" 2>/dev/null || true)" == "$digest" ]] \
    && cosign verify --certificate-identity "$identity" --certificate-oidc-issuer "$issuer" "$target_digest_ref" >/dev/null; then
    log "up to date: $target"
    continue
  fi

  log "copying $source -> $target"
  crane cp "$pull_ref" "$target"
  [[ "$(crane digest "$target")" == "$digest" ]] || die "digest changed while copying $source"

  log "signing $target_digest_ref"
  # --use-signing-config=false keeps cosign v3 on the legacy .sig-tag path — the format
  # Flux source-controller and Kyverno verification consume. The tlog entry is public
  # Rekor (cosign's default), deliberately: these are public repos, and keyless
  # verification wants the log.
  cosign sign --use-signing-config=false --recursive --yes "$target_digest_ref"
done < <(yq '.images[] | [.source, .digest, .target] | @tsv' "$lock")

log "images published"
