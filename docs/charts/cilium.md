---
description: "eBPF-based networking, security and observability (CNI), with Hubble."
---

# cilium

[Cilium](https://cilium.io) is the eBPF-based CNI: pod networking, network policy, load balancing and, through
[Hubble](https://github.com/cilium/hubble), flow observability. It's deployed by the flux-manifests
[`cilium`](https://github.com/bitwise-media-group/flux-manifests/tree/main/components/cilium) component.

--8<-- "build/chart-docs/cilium/facts.md"

## How it's mirrored

- **Keyless upstream, bar the Hubble UI.** Cilium signs the OCI chart and its images from its GitHub release workflows,
  so the chart and every `quay.io/cilium/*` image are verified keyless. The exception is the Hubble UI's frontend and
  backend (`hubble-ui`, `hubble-ui-backend`), which ship unsigned from the separate cilium/hubble-ui repository. Two
  rules ahead of the catch-all record that gap for exactly those images; the relay is cilium-signed and still verifies.
- **Hubble relay and UI included.** flux-manifests runs both, behind its auth-proxy component, so discovery enables them
  and their three images are mirrored.
- **Images move with the chart.** The agent, operator, Envoy, relay and UI images are pinned by the chart itself (tag
  plus digest), so there are no track rules.
- **Discovery keeps the render deterministic.** By default the chart mints a fresh Hubble CA and server certificate on
  every render (`hubble.tls.auto.method=helm`). That would make `rendered/manifests.yaml` different on every run and
  fail the byte-identity gate. The discovery values turn auto-generation off and point Hubble's server and the relay's
  client at externally managed Secrets, so no certificate material is rendered.

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
