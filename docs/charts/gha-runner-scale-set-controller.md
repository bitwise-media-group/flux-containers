---
description: "Actions Runner Controller: the CRDs, manager and listener for GitHub Actions runner scale sets."
---

# gha-runner-scale-set-controller

The controller half of [Actions Runner Controller](https://github.com/actions/actions-runner-controller) (ARC): the four
`actions.github.com` CRDs, the manager Deployment and its RBAC. The manager image doubles as the listener image (the
controller launches listener pods with it), so this chart's one image also covers every listener a scale set creates.
It's deployed by the flux-manifests
[`arc`](https://github.com/bitwise-media-group/flux-manifests/tree/main/components/arc) component, together with
[gha-runner-scale-set](gha-runner-scale-set.md).

--8<-- "build/chart-docs/gha-runner-scale-set-controller/facts.md"

## How it's mirrored

- **Lockstep with the scale set.** ARC doesn't support a scale set running against a controller of a different version,
  so both charts are in the `arc` lockstep group and always bump in one PR.
- **No upstream provenance.** ARC publishes the OCI charts and the controller image unsigned: there's no `.sig` tag and
  no sigstore bundle among the referrers. Both are documented gaps, so the mirror's own keyless signature is the first
  provenance anything on this path gets.
- **Findings are the controller's own dependencies.** They're compiled into the manager, listener and metrics binaries,
  on the GitHub API client path, so none of them are latent. A growing list is a signal to check whether ARC has cut a
  release.

Discovery renders with the chart defaults: `values/discovery.yaml` is empty.

## Images

--8<-- "build/chart-docs/gha-runner-scale-set-controller/images.md"

## Accepted findings

--8<-- "build/chart-docs/gha-runner-scale-set-controller/allowlist.md"

## Manifest

??? example "charts/gha-runner-scale-set-controller/manifest.yaml"

    ```yaml
    --8<-- "charts/gha-runner-scale-set-controller/manifest.yaml"
    ```

## Values reference

--8<-- "build/chart-docs/gha-runner-scale-set-controller/values.md"
