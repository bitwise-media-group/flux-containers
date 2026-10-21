---
description: "The Flux Operator: installs, upgrades and reconciles Flux from a FluxInstance resource."
---

# flux-operator

The [Flux Operator](https://fluxcd.control-plane.io/operator/) manages the Flux controllers declaratively: it installs
and upgrades them from a `FluxInstance` resource, and adds `ResourceSet` templating that the flux-manifests stack is
built on. It's deployed by the flux-manifests
[`flux`](https://github.com/bitwise-media-group/flux-manifests/tree/main/components/flux) component, alongside
[flux-instance](flux-instance.md).

--8<-- "build/chart-docs/flux-operator/facts.md"

## How it's mirrored

- **Lockstep with flux-instance.** The two charts share one OCI repository and one version stream. They belong to the
  `flux` lockstep group, so the daily update check bumps both in one PR, and only once upstream has published both tags.
  A half-merged pair would ship an operator whose embedded Flux release the mirror can't serve yet. See
  [Updates & lockstep groups](../concepts/updates.md).
- **Images move with the chart.** The operator image is tagged with the chart's `appVersion`, so there are no track
  rules.
- **Fully keyless upstream.** The chart and image are both signed by `controlplaneio-fluxcd`'s GitHub workflows.

Discovery renders with the chart defaults: `values/discovery.yaml` is empty.

## Images

--8<-- "build/chart-docs/flux-operator/images.md"

## Accepted findings

--8<-- "build/chart-docs/flux-operator/allowlist.md"

## Manifest

??? example "charts/flux-operator/manifest.yaml"

    ```yaml
    --8<-- "charts/flux-operator/manifest.yaml"
    ```

## Values reference

--8<-- "build/chart-docs/flux-operator/values.md"
