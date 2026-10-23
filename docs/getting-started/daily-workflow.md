# Daily workflow

## Set up

Clone with submodules, because the shared toolchain lives at `.mise/`. Then trust the mise config once:

```sh
git clone --recurse-submodules https://github.com/bitwise-media-group/flux-containers.git
cd flux-containers
mise trust --all
make help
```

`make <task>` and `mise run <task>` are interchangeable. The Makefile only forwards, and exports `CHART` so
`make update CHART=dex` is the same as `CHART=dex mise run update`. The full list is in [Tasks](../reference/tasks.md).

## See what's out of date

```sh
make check-updates
```

This prints the update plan and changes nothing. It shows each entry's newest upstream version within its
`versionConstraint`, plus the target for each lockstep group. Most days you won't need it, because
[Renovate](../concepts/updates.md#the-renovate-flow) opens the PRs for you.

## Bump a chart

```sh
make update CHART=kyverno
```

`update` (`patchy mirror upgrade`) moves the pin to the newest version that satisfies the constraint. It re-picks any
[tracked images](../concepts/tracked-images.md), then regenerates every fact: the vendored chart, the rendered
manifests, the image lock, `images.extra.yaml` and generated allowlists. If everything is already current, it does
nothing. `make update-all` does the same for every entry.

For a lockstep pair, run `update` on either member, or let Renovate open the group PR. Both members move to the
group's target together.

## Validate before you push

```sh
make validate CHART=kyverno
```

`validate` runs everything pr-validate runs for one entry: it regenerates out of tree and requires the result to be
byte-identical to the commit, then verifies provenance, scans, and lints. `make validate-all` covers every entry and
adds the repo-wide lint gates. `make pr` formats, validates everything and builds this site.

## Reviewing an update PR

The diff is exactly what ships, so read it in this order:

1. **`manifest.yaml`**: the version (and nothing else, for a routine bump).
2. **`images.lock.yaml`**: which images, tags and digests changed. A new image means the chart now deploys something it
   didn't before.
3. **`security/allowlist.yaml`**: entries that appeared, disappeared or are close to expiry. Approving the PR is
   accepting those risks. See [Scanning & allowlists](../concepts/scanning.md).
4. **`rendered/manifests.yaml`**: what the chart now does to a cluster (RBAC, webhooks, CRDs).
5. **`vendor/`**: the raw upstream change, if you need it.

The pr-validate sticky comment summarises the provenance and scan results. Renovate's update PRs carry the `auto-merge`
label, so approving one is enough: the merge workflow lands it once every check is green. Anything else merges with a
`/merge` fast-forward (see the merge-notice comment on the PR). The publish workflow then pushes and signs whatever is
new.

## Editing intent

When you change a manifest rule, discovery values or a hand-written allowlist entry, run `make update CHART=<name>`
afterwards. That regenerates the facts the change affects, and pr-validate fails if they're stale.
