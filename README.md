# flux-containers

Supply-chain pipeline for the patchy platform: every helm chart the [flux-manifests] stack deploys is **vendored**
(pinned upstream chart, committed verbatim), **rendered**, its images **discovered and digest-pinned**, its upstream
provenance **verified**, everything **scanned** (grype + kubescape, allowlists with expiry), and — post-merge only —
**published** to the platform Artifact Registry with **keyless cosign signatures**. Clusters never pull charts or images
from a public registry.

## Layout

```text
config/global.yaml        pipeline-wide config: registry, signing identity, scan gates
charts/<name>/
  manifest.yaml           INTENT — the only human-edited file (pin, constraint, verify rules)
  values/discovery.yaml   INTENT — render values so image discovery is complete
  security/allowlist.yaml INTENT — accepted CVEs (statement + expired_at, max 90 days)
  vendor/<chart>/         FACT  — the upstream chart, byte-identical
  rendered/manifests.yaml FACT  — helm template output
  images.lock.yaml        FACT  — digest-resolved source -> mirror-target image map
scripts/                  the pipeline stages (bash, stdout=data stderr=logs)
```

The intent/fact split is the core invariant: `make refresh CHART=<name>` regenerates all facts, and pr-validate fails
unless the committed tree regenerates **byte-identically** — so what reviewers see is exactly what ships.

## Pipeline

`make <task> CHART=<name>` (see `make help`): `vendor` → `render` → `discover` → `verify` → `scan`, with `refresh`
(vendor+render+discover), `validate` (refresh+verify+scan), `update` (bump to newest in-constraint version + refresh),
and `publish` (images then chart — CI-only in practice).

Charts under management: `flux-operator`, `flux-instance` (the pair is released together upstream — bump both in one PR;
flux-instance also carries the fluxcd distribution controller images as `images.extra`, tags tracking the operator's
embedded flux version), `kyverno`, `cert-manager`, `external-dns`, `opentelemetry-collector`, `dex`.

## Security model

- **Keyless signing, public transparency log — by design.** The publish workflow signs everything with its GitHub OIDC
  identity (`…/flux-containers/.github/workflows/publish.yaml@refs/heads/main` — the job is hard-guarded to `main` so
  the subject never varies). Consumers (flux-manifests OCIRepositories, the Kyverno cluster policy, the FluxInstance
  verify patch) pin that exact identity. No KMS, no key distribution, nothing secret in the registry paths.
- **Upstream provenance** is verified per manifest rules before anything is mirrored (and re-verified on main before
  publishing): keyless (flux-operator/fluxcd, kyverno, otel collector images, external-dns's registry.k8s.io image) or
  key-based (cert-manager's project key, sha512 digests). Unsigned upstreams (`provider: none`) are documented gaps,
  listed in every verify run.
- **Scan gates**: grype fails the pipeline on CRITICAL/HIGH (fixed-upstream only); kubescape runs in warn mode. Accepted
  findings need a statement and an `expired_at` within 90 days — expiry forces re-review; the weekly rescan catches CVEs
  published after merge and files security-labelled issues.

## CI / publishing

- **ci.yaml** (reusable): repo-wide lint (manifests, allowlists, shellcheck, license headers, prose, actionlint).
- **pr-validate.yaml**: the deep per-chart gate — regeneration byte-identity, provenance, scans, sticky PR comment.
- **publish.yaml** (push to main touching `charts/**`): WIF auth as the chart-publisher service account
  (`GCP_WIF_PROVIDER` / `GCP_CHART_PUBLISHER_SA` repository variables, from the terraform artifact-store outputs) →
  mirror images by digest → push chart → keyless-sign all.
- **update-check.yaml** (daily): constraint-aware bump PRs.
- **rescan.yaml** (weekly): fresh-DB rescan of the published sets.
- Merging is `/merge` fast-forward (see the merge-notice comment on any PR).

## Development

Clone with `--recurse-submodules` (the toolchain lives at `.mise/`), then `mise trust --all` once. `make help` lists
tasks. Local verify/scan run against upstream registries; publishing requires the CI identity and never runs locally.

[flux-manifests]: https://github.com/bitwise-media-group/flux-manifests
