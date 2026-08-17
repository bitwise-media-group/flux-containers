# flux-containers

Supply-chain mirror store for the patchy platform, maintained by [`patchy mirror`]: every helm chart the
[flux-manifests] stack deploys is **vendored** (pinned upstream chart, committed verbatim), **rendered**, its images
**discovered and digest-pinned**, its upstream provenance **verified**, everything **scanned** (grype + kubescape,
allowlists with expiry), and — post-merge only — **published** to the platform Artifact Registry with **keyless cosign
signatures**. Clusters never pull charts or images from a public registry.

## Layout

```text
mirror.yaml               pipeline-wide config: registry, signing identity, scan gates
charts/<name>/
  manifest.yaml           INTENT — the only human-edited file (pin, constraint, verify rules)
  values/discovery.yaml   INTENT — render values so image discovery is complete
  security/allowlist.yaml INTENT — accepted CVEs (statement + expired_at, max 90 days)
  images.extra.yaml       GENERATED — machine-derived extra images (distribution manifests)
  vendor/<chart>/         FACT  — the upstream chart, byte-identical
  rendered/manifests.yaml FACT  — helm template output
  images.lock.yaml        FACT  — digest-resolved source -> mirror-target image map
artifacts/<name>/         same shape for non-chart OCI artifacts (manifest.yaml + lock.yaml)
```

The tree is the registry of entries — `patchy mirror` discovers `charts/*/manifest.yaml` and
`artifacts/*/manifest.yaml`; nothing lists them centrally. The intent/fact split is the core invariant:
`make update CHART=<name>` regenerates all facts, and pr-validate fails unless the committed tree regenerates
**byte-identically** — so what reviewers see is exactly what ships.

## Pipeline

The engine is the patchy CLI's `mirror` command group (pinned in `mise.toml`); the mise tasks are thin forwarders:

```sh
make check-updates                # the lockstep-aware update plan, read-only
make update CHART=<name>          # bump pin + tracked tags, regenerate all facts
make update-all
make validate CHART=<name>        # regen byte-identity + provenance + scan + lint
make validate-all
make add URL=oci://…              # scaffold a new entry (review, then update)
make publish CHART=<name>         # converge the registry (CI-only in practice)
```

patchy never runs git: `update` mutates files, `publish` writes only to the registry, and branches, commits and PRs
belong to the workflows.

Charts under management: `flux-operator`, `flux-instance` (the pair is released together upstream — the `lockstep` group
bumps both in one PR; flux-instance also carries the fluxcd distribution controller images in its generated
`images.extra.yaml`, derived from the operator's embedded manifests), `kyverno`, `cert-manager`, `external-dns`,
`opentelemetry-collector`, `dex`, `gha-runner-scale-set` + `gha-runner-scale-set-controller` (Actions Runner Controller
— also a lockstep pair, since ARC does not support a scale set running against a mismatched controller; the scale set's
runner image rides its own release train and is tracked separately, see below).

### Tracked images

Some charts reference an image on a release train of its own: the actions runner moves independently of the scale set
chart, so no chart version implies it, and the chart's own default is the mutable `:latest`. Those are declared per
chart under `.images.track` in `manifest.yaml`, and `patchy mirror upgrade` writes the resolved `<image>:<tag>` into the
chart's discovery values — that line is FACT, not intent, so change the rule rather than the pin.

Selection walks candidate tags newest-first and takes the first published at least `update.cooldownDays` ago
(`mirror.yaml`, 3 by default; override per image with `cooldownDays`, or 0 to track head). A release yanked or hot-fixed
inside its soak window is therefore never the one the platform adopts — at the cost of deliberately running a release
behind, so a freshly-published _fix_ waits out the same cooldown. Keep the window short for that reason.

The pick depends on wall-clock time, so it runs in `update` and never in `validate`: validation has to regenerate
byte-identically, and a tag ageing past the cooldown mid-review would otherwise fail pr-validate on an untouched tree.

### Generated allowlists

Once images bump on their own schedule, hand-transcribing a per-CVE allowlist each time stops being review and becomes
dictation. Charts can opt in with `.scan.allowlist.generate`, and `update` rebuilds `security/allowlist.yaml` from a
fresh scan of the locked images. Three rules keep the result honest:

- Findings that no longer appear are **dropped** — a stale accept is indistinguishable from a live one.
- Surviving entries **keep their original `expired_at`**. Regeneration never rolls the clock forward, so expiry stays
  the forcing function it was designed to be; new entries get `scan.allowlistNewDays` from today.
- Per-entry `notes` are **preserved verbatim**. Statements are machine facts (package, installed, fixed-in); anything a
  human concluded belongs in `notes`, or in `.scan.allowlist.preamble` for whole-file context.

Approval is the PR review: the diff shows exactly which accepts appeared, vanished, or aged. Charts that do not opt in
keep hand-written allowlists, which is still the right shape for a chart whose images only move when the chart does.
Matching is by finding ID **and aliases** (CVE/GHSA families cross-reference each other), so the entries survive a
scanner change.

## Security model

- **Keyless signing, public transparency log — by design.** The publish workflow signs everything with its GitHub OIDC
  identity (`…/flux-containers/.github/workflows/publish.yaml@refs/heads/main` — the job is hard-guarded to `main` so
  the subject never varies). Consumers (flux-manifests OCIRepositories, the Kyverno cluster policy, the FluxInstance
  verify patch) pin that exact identity. No KMS, no key distribution, nothing secret in the registry paths. (patchy also
  supports a `kms:` signing block — `gcpkms://`, `awskms://`, `azurekms://` — globally or per entry; this store
  deliberately uses neither.)
- **Upstream provenance** is verified per manifest rules before anything is mirrored (and re-verified on main before
  publishing): keyless (flux-operator/fluxcd, kyverno, otel collector images, external-dns's registry.k8s.io image) or
  key-based (cert-manager's project key, sha512 digests). Unsigned upstreams (`provider: none`) are documented gaps,
  listed in every verify run.
- **Scan gates**: grype fails the pipeline on CRITICAL/HIGH (fixed-upstream only); kubescape runs in warn mode.
  (`mirror.yaml` can also enable patchy's built-in osv scanner; this store keeps grype, whose finding set the committed
  allowlists were derived from.) Accepted findings need a statement and an `expired_at` within 90 days — expiry forces
  re-review; the weekly rescan catches CVEs published after merge and files security-labelled issues.
- **Publish idempotency**: an existing chart tag is never replaced, current-and-signed images are skipped, and the
  upstream archive is re-pulled and byte-compared against the committed vendor tree before anything ships — an upstream
  mutating a released version in place fails the publish loudly.

## CI / publishing

- **ci.yaml** (reusable): repo-wide lint (manifests, allowlists, shellcheck, license headers, prose, actionlint).
- **pr-validate.yaml**: the deep per-entry gate — `patchy mirror validate` (regeneration byte-identity, provenance,
  scans, lint), sticky PR comment.
- **publish.yaml** (push to main touching the store): WIF auth as the chart-publisher service account
  (`GCP_WIF_PROVIDER` / `GCP_CHART_PUBLISHER_SA` repository variables, from the terraform artifact-store outputs) →
  `patchy mirror sync --all`.
- **update-check.yaml** (daily): `patchy mirror upgrade --check`, then one stable `update/<group>` branch and one PR per
  lockstep group with work, refreshed in place — a newer upstream release rewrites the same PR instead of opening a
  sibling.
- **rescan.yaml** (weekly): fresh-DB rescan of the published sets.
- Merging is `/merge` fast-forward (see the merge-notice comment on any PR).

## Development

Clone with `--recurse-submodules` (the toolchain lives at `.mise/`), then `mise trust --all` once. `make help` lists
tasks. Local validate runs against upstream registries; publishing requires the CI identity and never runs locally.

[`patchy mirror`]: https://oss.bitwisemedia.uk/patchy/cli/patchy_mirror/
[flux-manifests]: https://github.com/bitwise-media-group/flux-manifests
