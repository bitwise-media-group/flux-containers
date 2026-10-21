---
description: "Actions Runner Controller scale set: an AutoscalingRunnerSet of ephemeral GitHub Actions runners."
---

# gha-runner-scale-set

The scale-set half of [Actions Runner Controller](https://github.com/actions/actions-runner-controller): an
`AutoscalingRunnerSet` resource plus its RBAC. It does nothing on its own. The CRD, the controller and the listener
image all ship in [gha-runner-scale-set-controller](gha-runner-scale-set-controller.md), and a cluster needs both. It's
deployed by the flux-manifests [`arc`](https://github.com/bitwise-media-group/flux-manifests/tree/main/components/arc)
component.

--8<-- "build/chart-docs/gha-runner-scale-set/facts.md"

## How it's mirrored

- **Lockstep with the controller.** Both charts are in the `arc` lockstep group and always bump in one PR.
- **The runner image is tracked.** The runner (`ghcr.io/actions/actions-runner`) is released on the `actions/runner` 2.x
  schedule, which has nothing to do with this chart's version. The chart's own default is the mutable `:latest`. The
  track rule (bounded `>=2.320.0 <3.0.0`) writes the newest tag that has cleared the cooldown into
  `.template.spec.containers[0].image` in the discovery values. See [Tracked images](../concepts/tracked-images.md).
- **Unsigned chart, signed runner.** The chart is unsigned upstream (a documented gap). The runner image is
  keyless-signed by the `actions/runner` release workflow, as a sigstore bundle attached via OCI referrers.
- **Generated allowlist, grouped by reachability.** Each runner bump changes the finding set, so the allowlist is
  regenerated from the scan. The preamble sorts entries into two groups. The first is the Docker-in-Docker toolchain,
  latent because `containerMode: dind` is deliberately unset. The second is npm's vendored modules inside the runner's
  bundled Node, reachable only when a workflow runs npm.
- **Discovery describes a real scale set.** The org's config URL and secret name, the controller's service account and a
  runner container spec make the render match what the platform deploys.

```yaml title="charts/gha-runner-scale-set/values/discovery.yaml"
--8<-- "charts/gha-runner-scale-set/values/discovery.yaml"
```

## Images

--8<-- "build/chart-docs/gha-runner-scale-set/images.md"

## Accepted findings

--8<-- "build/chart-docs/gha-runner-scale-set/allowlist.md"

## Manifest

??? example "charts/gha-runner-scale-set/manifest.yaml"

    ```yaml
    --8<-- "charts/gha-runner-scale-set/manifest.yaml"
    ```

## Values reference

--8<-- "build/chart-docs/gha-runner-scale-set/values.md"
