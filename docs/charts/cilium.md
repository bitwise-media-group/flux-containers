---
description: "eBPF-based networking, security and observability (CNI), with Hubble."
---

# cilium

[Cilium](https://cilium.io) is the eBPF-based CNI: pod networking, network policy, load balancing and, through
[Hubble](https://github.com/cilium/hubble), flow observability. It's deployed by the flux-manifests
[`cilium`](https://github.com/bitwise-media-group/flux-manifests/tree/main/components/cilium) component.

--8<-- "build/chart-docs/cilium/facts.md"

## How it's mirrored

- **Fully keyless upstream.** Cilium signs both the OCI chart and its images from its GitHub release workflows, so the
  chart and every `quay.io/cilium/*` image are verified keyless.
- **Images move with the chart.** The agent, operator and Envoy images are pinned by the chart itself (tag plus digest),
  so there are no track rules.
- **Discovery keeps the render deterministic.** By default the chart mints a fresh Hubble CA and server certificate on
  every render (`hubble.tls.auto.method=helm`). That would make `rendered/manifests.yaml` different on every run and
  fail the byte-identity gate. The discovery values turn auto-generation off and point Hubble at an externally managed
  Secret, so no certificate material is rendered.

```yaml title="charts/cilium/values/discovery.yaml"
--8<-- "charts/cilium/values/discovery.yaml"
```

## Images

--8<-- "build/chart-docs/cilium/images.md"

## Accepted findings

--8<-- "build/chart-docs/cilium/allowlist.md"

## Manifest

??? example "charts/cilium/manifest.yaml"

    ```yaml
    --8<-- "charts/cilium/manifest.yaml"
    ```

## Values reference

--8<-- "build/chart-docs/cilium/values.md"
