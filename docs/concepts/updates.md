# Updates & lockstep groups

## How a version is picked

`patchy mirror upgrade` takes the newest upstream release that satisfies the entry's `chart.versionConstraint`. The
constraint is usually "stay in the current major" (`>=1.18.0 <2.0.0`). Moving to a new major is a deliberate manifest
edit, never something the daily sweep does on its own. `make update` makes no change when the pin is already the newest
satisfying release.

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

Members share a `chart.lockstep` value. The group's target is the **lowest** of the members' newest satisfying versions.
If upstream has published `flux-operator 0.59.0` but not yet `flux-instance 0.59.0`, the group stays where it is until
both exist. A half-mirrored release, where the operator references images the mirror doesn't carry yet, can't be
produced.

A chart without `lockstep` is a group of one, named after the chart.

## The daily sweep

The [update-check workflow](automation.md) runs `patchy mirror upgrade --check` every morning. Each group with work gets
one **stable branch**, `update/<group>`, recreated from `main`, and one PR that is refreshed in place:

- The branch name carries no version on purpose. A newer upstream release rewrites the same PR to the newer target
  instead of opening a sibling PR that conflicts with it.
- Each member gets its own commit (`feat(<chart>): update chart to <version>`). A run that only re-picks tracked images
  produces `feat(<chart>): update tracked images`.
- Commits are created through the GitHub API, so they carry GitHub's verified signature.

Review and merge the PR like any other. See
[reviewing an update PR](../getting-started/daily-workflow.md#reviewing-an-update-pr).

## Tool updates

Renovate keeps the pipeline's own tools current: patchy, crane and yq in `mise.toml`, the toolchain submodule, and the
pinned workflow actions. It never touches `charts/*/vendor/` or `charts/*/rendered/` (`.github/renovate.json5`), because
chart updates go through the pipeline above.
