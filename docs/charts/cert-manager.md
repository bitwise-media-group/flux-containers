---
description: "X.509 certificate management — ACME issuance and renewal, including Gateway API listener certificates."
---

# cert-manager

[cert-manager](https://cert-manager.io) issues and renews X.509 certificates from in-cluster `Certificate` resources. On
the platform it runs with the Gateway API integration on, solving ACME DNS-01 challenges against the cluster's delegated
zone. It's deployed by the flux-manifests
[`cert-manager`](https://github.com/bitwise-media-group/flux-manifests/tree/main/components/cert-manager) component, and
its issuers by `cert-manager-issuers`.

--8<-- "build/chart-docs/cert-manager/facts.md"

## How it's mirrored

- **Images move with the chart.** Every cert-manager image is tagged with the chart's `appVersion`, so there are no
  track rules. An independently tracked image could drift away from the CRDs the chart installs.
- **One image helm can't see.** The controller launches ACME solver pods from `cert-manager-acmesolver`, which it reads
  from a command-line flag rather than a pod spec. `images.extra` adds it at `{appVersion}`.
- **Image provenance uses the project key.** cert-manager signs its images with a published cosign public key and sha512
  payload digests, not keyless. The OCI chart itself carries no cosign signature, so the chart is a documented gap
  (`provider: none`).
- **Discovery renders the CRDs.** `crds.enabled: true` matches how the platform installs the chart.

The upstream tags keep their leading `v` (`v1.21.1`). The pin uses upstream's spelling, and consumers filter tags with a
semver range that tolerates it.

```yaml title="charts/cert-manager/values/discovery.yaml"
--8<-- "charts/cert-manager/values/discovery.yaml"
```

## Images

--8<-- "build/chart-docs/cert-manager/images.md"

## Accepted findings

--8<-- "build/chart-docs/cert-manager/allowlist.md"

## Manifest

??? example "charts/cert-manager/manifest.yaml"

    ```yaml
    --8<-- "charts/cert-manager/manifest.yaml"
    ```

## Values reference

--8<-- "build/chart-docs/cert-manager/values.md"
