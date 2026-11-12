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
- **Docker-in-Docker is spelled out, not `containerMode`.** `containerMode.type: dind` hardcodes the sidecar image as
  `docker:dind`, a moving tag no value overrides. The mirror's tags are immutable, so a `dind` tag could never be
  republished at a new digest. Following the chart's own guidance, the discovery values leave `containerMode` empty and
  put the dind pod spec (externals init container, privileged `dind` sidecar, socket and work volumes) in `template`, as
  containerMode dind would generate it, with the sidecar pinned to a versioned `docker.io/library/docker:<version>-dind`
  tag. That image is locked, scanned and mirrored beside the runner. A deployment that wants dind does the same: unset
  `containerMode`, write the dind spec into its own `template`, and reference the mirrored tags.
- **Renovate bumps the dind tag.** patchy's track rules only pick plain `X.Y.Z` tags, so they can't follow the `-dind`
  variant. The sidecar's image line carries a `# renovate:` annotation instead, and Renovate's docker versioning keeps
  the suffix. Local `make mirror-upgrade` leaves it alone. The runner image is also referenced by the externals init
  container, through a YAML anchor on the runner's pin, so it has a single pin.
- **Signed runner, unsigned chart and dind.** The runner image is keyless-signed by the `actions/runner` release
  workflow, as a sigstore bundle attached via OCI referrers. The chart and the `docker` Docker Official Image carry no
  cosign signature upstream (documented gaps).
- **Generated allowlist, grouped by reachability.** Each runner bump changes the finding set, so the allowlist is
  regenerated from the scan. The preamble sorts entries into three groups. The first is the Docker-in-Docker toolchain,
  which is reachable now that dind is on: the sidecar's daemon runs privileged, and the runner's docker CLI and buildx
  drive it. Its findings are accepted because the daemon only listens on a pod-local socket and dind scale sets run on
  isolated capacity, not because they're unreachable. The second is the bundled Node runtimes and npm's vendored
  modules, reachable only when a workflow runs them. The third is Ubuntu base packages, each with its own note.
- **Discovery describes a real scale set.** The org's config URL and secret name, the controller's service account, and
  the runner and dind pod spec make the render match what the platform deploys.

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
