---
description: "Renders the FluxInstance resource the operator turns into the Flux distribution controllers."
---

# flux-instance

The flux-instance chart renders the `FluxInstance` custom resource that tells the [Flux Operator](flux-operator.md)
which Flux distribution to run and how. The operator then deploys the Flux controllers (source, kustomize, helm and
notification) from it. It's deployed by the flux-manifests
[`flux`](https://github.com/bitwise-media-group/flux-manifests/tree/main/components/flux) component.

--8<-- "build/chart-docs/flux-instance/facts.md"

## How it's mirrored

- **The controller images are derived, not discovered.** The chart renders only the `FluxInstance` resource, so
  `helm template` never sees a controller image, yet clusters pull them from the mirror's `images/ghcr.io/fluxcd` path.
  The manifest's `images.distributionManifests` rule points at the operator's distribution-manifests artifact and names
  the four components. `make update` reads that artifact at the tag matching the vendored `appVersion` and writes the
  generated `images.extra.yaml` sidecar. The sidecar always holds exactly the controller set the pinned operator
  deploys, and the manifest stays pure intent.
- **Lockstep with flux-operator.** Both charts are in the `flux` group and bump together.
- **One reasoned OCI reference.** The chart's default `distribution.artifact` points outside the mirror and survives in
  the rendered output. `ociRefs.allow` permits it with a reason: consumers neutralise it (terraform pins the bootstrap
  to the operator's release tag, and the flux-manifests post-renderer removes it after adoption).
- **Findings belong to the distribution.** The scanned images are the Flux controllers, so an accepted finding clears
  with the next flux-operator / flux-instance release.

Discovery renders with the chart defaults: `values/discovery.yaml` is empty.

## Images

--8<-- "build/chart-docs/flux-instance/images.md"

## Accepted findings

--8<-- "build/chart-docs/flux-instance/allowlist.md"

## Manifest

??? example "charts/flux-instance/manifest.yaml"

    ```yaml
    --8<-- "charts/flux-instance/manifest.yaml"
    ```

## Values reference

--8<-- "build/chart-docs/flux-instance/values.md"
