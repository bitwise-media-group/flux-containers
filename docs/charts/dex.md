---
description: "OpenID Connect identity provider and OAuth 2.0 broker with pluggable connectors."
---

# dex

[Dex](https://dexidp.io) is an OpenID Connect identity provider that federates upstream identity sources (GitHub,
Google, LDAP and others) through pluggable connectors. It's deployed by the flux-manifests
[`dex`](https://github.com/bitwise-media-group/flux-manifests/tree/main/components/dex) component.

--8<-- "build/chart-docs/dex/facts.md"

## How it's mirrored

- **The image is tracked, not taken from the chart.** Dex images release faster than the chart, and the chart's
  `appVersion` can lag new `v2.x` images for months. Pinning the chart alone would strand the platform on a vulnerable
  image. A track rule re-picks the newest `v2.x` tag that has cleared the cooldown on every `make update` and writes it
  to `.image.tag` in the discovery values. That line is a fact; don't edit it by hand. See
  [Tracked images](../concepts/tracked-images.md).
- **Unsigned chart, signed image.** The chart is a GitHub release asset behind a `gh-pages` index (chart-releaser, no
  signing), which is a documented gap. The image is keyless-signed by the `dexidp/dex` release workflow.
- **Findings are mostly latent.** The image is Alpine-based, and upstream bundles every connector's dependencies whether
  or not a connector is configured. The allowlist preamble records that the platform runs no SAML or git-based
  connectors; per-finding reachability lives in each entry's `notes`.

```yaml title="charts/dex/values/discovery.yaml"
--8<-- "charts/dex/values/discovery.yaml"
```

## Images

--8<-- "build/chart-docs/dex/images.md"

## Accepted findings

--8<-- "build/chart-docs/dex/allowlist.md"

## Manifest

??? example "charts/dex/manifest.yaml"

    ```yaml
    --8<-- "charts/dex/manifest.yaml"
    ```

## Values reference

--8<-- "build/chart-docs/dex/values.md"
