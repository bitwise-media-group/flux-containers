# Updates & lockstep groups

## How a version is picked

The newest upstream release that satisfies the entry's `chart.versionConstraint` wins. The constraint is usually "stay
in the current major" (`>=1.18.0 <2.0.0`). Moving to a new major is a deliberate manifest edit, never something
automation does on its own. Two things apply that rule:

- **Renovate**, continuously, for every entry (see [the Renovate flow](#the-renovate-flow) below).
- **`make update`** (`patchy mirror upgrade`), locally, when you want a bump now. It makes no change when the pin is
  already the newest satisfying release.

```sh
make check-updates                  # the plan, as a table; nothing is written
make update CHART=external-dns      # one entry
make update-all                     # every entry
```

## Lockstep groups

Some charts are released together upstream and are only correct as a pair:

| Group  | Members                                                                                                                                    | Why they must match                                                                          |
| ------ | ------------------------------------------------------------------------------------------------------------------------------------------ | -------------------------------------------------------------------------------------------- |
| `flux` | [flux-operator](../charts/flux-operator.md), [flux-instance](../charts/flux-instance.md)                                                   | the operator embeds the Flux release whose controller images flux-instance's sidecar mirrors |
| `arc`  | [gha-runner-scale-set-controller](../charts/gha-runner-scale-set-controller.md), [gha-runner-scale-set](../charts/gha-runner-scale-set.md) | ARC doesn't support a scale set running against a controller of a different version          |

Members share a `chart.lockstep` value. For `make update`, the group's target is the **lowest** of the members' newest
satisfying versions: if upstream has published `flux-operator 0.59.0` but not yet `flux-instance 0.59.0`, the group
stays where it is until both exist. Renovate bumps each group in one PR (`renovate/flux`, `renovate/arc`). If it catches
only one member's release, `patchy mirror upgrade --pinned` refuses the diverged pins and the PR stays red until the
partner release lands. Either way, a half-mirrored release, where the operator references images the mirror doesn't
carry yet, can't be produced.

The Renovate groups are declared in `.github/renovate.json5` and duplicate `chart.lockstep`. Keep the two in step when
adding a group.

A chart without `lockstep` is a group of one, named after the chart.

## The Renovate flow

Renovate discovers new versions and owns the PR lifecycle; patchy rebuilds everything derived from them. Two custom
managers in `.github/renovate.json5` feed it:

- **Chart versions**: `chart.version` in every `charts/*/manifest.yaml`. `oci://` repos resolve through the docker
  datasource, classic repos through the helm index.
- **Tracked images**: the tag of each [tracked image](tracked-images.md) in `values/discovery.yaml`, marked by a
  `# renovate: datasource=docker depName=<image>` annotation on the line above it.

After each bump Renovate runs `patchy mirror upgrade --pinned <entry>`. `--pinned` resolves nothing and re-picks
nothing: it checks that the new pin satisfies its `versionConstraint` (and that every lockstep member shares it), then
re-vendors, re-renders, relocks and re-derives the allowlist on top. A pin that fails those checks shows up as an
artifact error on the PR.

- Majors are disabled for both managers; `--pinned` is the hard guard on the declared constraints.
- Every PR gets the `auto-merge` label but is never merged unattended: the allowlist is regenerated, so a human approves
  it, and the merge workflow lands it once checks are green.
- Commits are `feat(<entry>): …` (`feat(flux): …` / `feat(arc): …` for the groups), keeping release-please's semantics.
  Renovate creates them through the GitHub API, so they carry GitHub's verified signature.
- The org's 3-day `minimumReleaseAge` holds wherever the datasource reports a release date (helm index repos). OCI
  registries report none, so those PRs open as soon as a release appears. The human review is the gate there.

Review and merge the PR like any other. See
[reviewing an update PR](../getting-started/daily-workflow.md#reviewing-an-update-pr).

## Tool updates

Renovate also keeps the pipeline's own tools current: patchy, crane and yq in `mise.toml`, the toolchain submodule, and
the pinned workflow actions. It never proposes bumps inside `charts/*/vendor/` or `charts/*/rendered/`: those are
patchy's output, not input.
