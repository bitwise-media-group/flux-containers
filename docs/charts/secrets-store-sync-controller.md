---
description: "Syncs secrets from external stores (via the Secrets Store CSI providers) into Kubernetes Secrets."
---

# secrets-store-sync-controller

The [Secrets Store Sync Controller](https://github.com/kubernetes-sigs/secrets-store-sync-controller) syncs secrets from
external secret stores, through the Secrets Store CSI Driver providers, into native Kubernetes `Secret` objects, without
a CSI volume mount. It's deployed by the flux-manifests
[`secret-sync`](https://github.com/bitwise-media-group/flux-manifests/tree/main/components/secret-sync) component, on
AWS clusters.

--8<-- "build/chart-docs/secrets-store-sync-controller/facts.md"

## How it's mirrored

- **Pre-1.0 upstream.** The constraint floor matches `SECRET_SYNC_SEMVER` in the flux-manifests `secret-sync` component.
  Raise both together as upstream stabilises.
- **Unsigned chart, signed image.** The chart archives are unsigned (chart-releaser behind a `gh-pages` index), which is
  a documented gap. The `registry.k8s.io/secrets-store-sync` image is keyless-signed by the Kubernetes release promoter.
- **Discovery uses the runtime namespace.** The render targets `secret-sync`, where the component deploys it, instead of
  the chart default. It also requests EKS Pod Identity tokens (`pods.eks.amazonaws.com`) and pins the system node pool.

```yaml title="charts/secrets-store-sync-controller/values/discovery.yaml"
--8<-- "charts/secrets-store-sync-controller/values/discovery.yaml"
```

## Images

--8<-- "build/chart-docs/secrets-store-sync-controller/images.md"

## Accepted findings

--8<-- "build/chart-docs/secrets-store-sync-controller/allowlist.md"

## Manifest

??? example "charts/secrets-store-sync-controller/manifest.yaml"

    ```yaml
    --8<-- "charts/secrets-store-sync-controller/manifest.yaml"
    ```

## Values reference

--8<-- "build/chart-docs/secrets-store-sync-controller/values.md"
