---
description: "Synchronises Kubernetes Services, Ingresses and Gateway routes with DNS providers."
---

# external-dns

[ExternalDNS](https://kubernetes-sigs.github.io/external-dns/) publishes DNS records for Kubernetes `Service`, `Ingress`
and Gateway API route resources to the cluster's DNS provider. It's deployed by the flux-manifests
[`external-dns`](https://github.com/bitwise-media-group/flux-manifests/tree/main/components/external-dns) component,
with AWS (Route53) and Google (Cloud DNS) variants.

--8<-- "build/chart-docs/external-dns/facts.md"

## How it's mirrored

- **The image is tracked.** external-dns images release on their own train and the chart's `appVersion` can lag them. A
  track rule re-picks the newest soaked `v0.x` tag on every `make update` and writes it to `.image.tag` in the discovery
  values.
- **Unsigned chart, signed image.** kubernetes-sigs publishes no OCI chart yet, and the archives behind the `gh-pages`
  index are unsigned, which is a documented gap. The `registry.k8s.io` image is keyless-signed by the Kubernetes release
  promoter (`krel-trust@k8s-releng-prod.iam.gserviceaccount.com`, Google-issued).

```yaml title="charts/external-dns/values/discovery.yaml"
--8<-- "charts/external-dns/values/discovery.yaml"
```

## Images

--8<-- "build/chart-docs/external-dns/images.md"

## Accepted findings

--8<-- "build/chart-docs/external-dns/allowlist.md"

## Manifest

??? example "charts/external-dns/manifest.yaml"

    ```yaml
    --8<-- "charts/external-dns/manifest.yaml"
    ```

## Values reference

--8<-- "build/chart-docs/external-dns/values.md"
