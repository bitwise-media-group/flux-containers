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
- **Docker-in-Docker is mirrored.** The discovery values set `containerMode.type: dind`, the mode the platform's runner
  scale sets use, so the render includes the chart's privileged `dind` sidecar and its `docker:dind` image is locked,
  scanned and mirrored beside the runner, at `images/docker.io/library/docker:dind`. The chart hardcodes that image and
  no value overrides it, so a deployment that must pull from the mirror rewrites the sidecar's image after rendering
  (for example with a Flux `postRenderers` patch) or spells the dind template out by hand with `containerMode` unset.
- **`dind` is a moving tag.** The lock records the digest the tag resolved to at the last `make mirror-upgrade`, and the
  mirror publishes that digest under the same tag. Docker rebuilds `dind` often, so expect the digest to move whenever
  this chart is updated.
- **Signed runner, unsigned chart and dind.** The runner image is keyless-signed by the `actions/runner` release
  workflow, as a sigstore bundle attached via OCI referrers. The chart and the `docker:dind` Docker Official Image carry
  no cosign signature upstream (documented gaps).
- **Generated allowlist, grouped by reachability.** Each runner bump changes the finding set, so the allowlist is
  regenerated from the scan. The preamble sorts entries into three groups. The first is the Docker-in-Docker toolchain,
  which is reachable now that dind is on: the sidecar's daemon runs privileged, and the runner's docker CLI and buildx
  drive it. Its findings are accepted because the daemon only listens on a pod-local socket and dind scale sets run on
  isolated capacity, not because they're unreachable. The second is the bundled Node runtimes and npm's vendored
  modules, reachable only when a workflow runs them. The third is Ubuntu base packages, each with its own note.
- **Discovery describes a real scale set.** The org's config URL and secret name, the controller's service account, a
  runner container spec and the dind container mode make the render match what the platform deploys.

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
