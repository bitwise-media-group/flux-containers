# Updates & lockstep groups

## How a version is picked

`patchy mirror upgrade` takes the newest upstream release that satisfies the entry's `chart.versionConstraint`. The
constraint is usually "stay in the current major" (`>=1.18.0 <2.0.0`). Moving to a new major is a deliberate manifest
edit, never something [Renovate](#renovate) does on its own. `make mirror-upgrade` makes no change when the pin is
already the newest satisfying release.

```sh
make mirror-check                  # the plan, as a table; nothing is written
make mirror-upgrade ENTRY=external-dns      # one entry
make mirror-upgrade                     # every entry
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
produced: `patchy mirror upgrade --pinned`, which regenerates every Renovate PR, refuses a group whose members pin
different versions.

A chart without `lockstep` is a group of one, named after the chart.

## Renovate

[Renovate](automation.md#renovate) finds new upstream releases and owns the PRs: branches, rebases, verified commits and
the Dependency Dashboard. patchy rebuilds everything derived from the moved pin. `.github/renovate.json5` reads the pins
straight from the patchy entry schema:

| Pin                                        | Where                                         | Renovate datasource                                     |
| ------------------------------------------ | --------------------------------------------- | ------------------------------------------------------- |
| `chart.version`                            | `charts/<entry>/manifest.yaml`                | `docker` for `oci://` repos, `helm` for classic indexes |
| a [tracked image](tracked-images.md)'s tag | the rule's `valuesPath`, marked `# renovate:` | `docker`                                                |

After every bump, a post-upgrade task runs `patchy mirror upgrade --pinned <entry>`. It picks nothing itself: it checks
that the pin satisfies its `versionConstraint` and that every lockstep member agrees, then re-vendors, re-renders,
re-locks and re-derives the allowlist on the new pin. If a check fails, Renovate reports an artifact error on the PR
instead of committing anything.

- **One PR per entry**, on `renovate/<entry>`. A chart bump and its tracked-image bumps share the PR, because both
  regenerate the same lock, rendered manifests and allowlist.
- **One PR per lockstep group**, on `renovate/<group>`. The group comes from `chart.lockstep`, so a new member needs no
  Renovate change.
- **Majors are disabled.** Every constraint today is "stay in the current major", and `--pinned` would reject the pin
  anyway.
- **Commits** read `feat(<entry>): update <entry> chart to <version>`, or `feat(<group>): update <group> charts` for a
  group. They keep the release-please semantics the mirror has always used.
- **Nothing automerges.** The allowlist is regenerated, so a human approves every PR. The `auto-merge` label then lets
  the merge workflow land it once checks pass.
- **Cooldown.** The org preset's 3-day `minimumReleaseAge` stands in for `mirror.update.cooldownDays` wherever the
  registry reports a release time (helm indexes). OCI registries report none, so those updates open as soon as Renovate
  sees them, and the review is the soak. A per-image `cooldownDays` in a manifest only affects local
  `make mirror-upgrade`. To hold one image back in Renovate as well, add a `minimumReleaseAge` package rule for it.

Review and merge the PR like any other. See
[reviewing an update PR](../getting-started/daily-workflow.md#reviewing-an-update-pr).

## Tool updates

Renovate also keeps the pipeline's own tools current: the toolchain submodule (which pins patchy and every tool it
shells out to) and the pinned workflow actions. It never touches `charts/*/vendor/` or `charts/*/rendered/`, because
those are output of the post-upgrade task, not input.
