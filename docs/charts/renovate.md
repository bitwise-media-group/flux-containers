---
description: "Self-hosted Renovate: automated dependency update pull requests."
---

# renovate

[Renovate](https://docs.renovatebot.com) opens dependency-update pull requests. This chart runs it self-hosted, as a
scheduled job that reads its configuration from a mounted file.

--8<-- "build/chart-docs/renovate/facts.md"

## How it's mirrored

- **Unsigned chart, signed image.** The OCI chart carries no verifiable signature, which is a documented gap. The
  `ghcr.io/renovatebot/renovate` image is keyless-signed by the release job in upstream's `build.yml`, as a bundle
  attached via OCI referrers. No GitHub build-provenance attestation is published, only the cosign signature.
- **Images move with the chart.** The chart pins the Renovate image, so there are no track rules.
- **Discovery mounts an existing config.** `renovate.existingConfigFile` points at a mounted `config.json`, matching how
  a cluster supplies configuration instead of inline values.

```yaml title="charts/renovate/values/discovery.yaml"
--8<-- "charts/renovate/values/discovery.yaml"
```

## Images

--8<-- "build/chart-docs/renovate/images.md"

## Accepted findings

--8<-- "build/chart-docs/renovate/allowlist.md"

## Manifest

??? example "charts/renovate/manifest.yaml"

    ```yaml
    --8<-- "charts/renovate/manifest.yaml"
    ```

## Values reference

--8<-- "build/chart-docs/renovate/values.md"
