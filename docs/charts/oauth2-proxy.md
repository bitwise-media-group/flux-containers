---
description: "An OAuth2/OIDC reverse proxy that puts dex SSO in front of web UIs with no login of their own."
---

# oauth2-proxy

[oauth2-proxy](https://oauth2-proxy.github.io/oauth2-proxy/) is a reverse proxy that signs people in through an OIDC
provider before passing requests on. The platform runs one instance per protected UI, signing in through dex. It's
deployed by the flux-manifests
[`auth-proxy`](https://github.com/bitwise-media-group/flux-manifests/tree/main/components/auth-proxy) component.

--8<-- "build/chart-docs/oauth2-proxy/facts.md"

## How it's mirrored

- **One image.** The chart pins the proxy image to its `appVersion`, so there are no track rules. Its `redis-ha`
  subchart and the `alpine` wait-for-redis init container are both off by default, and the platform keeps sessions in
  cookies, so neither image is mirrored.
- **Signed chart, unsigned image.** The OCI chart is keyless-signed by the oauth2-proxy release workflow. The image is
  published unsigned on both quay.io and ghcr.io, which is a documented gap.
- **No placeholder Secret.** Discovery names an existing Secret for the credentials, as the runtime does, so the chart
  renders no Secret with placeholder values.

```yaml title="charts/oauth2-proxy/values/discovery.yaml"
--8<-- "charts/oauth2-proxy/values/discovery.yaml"
```

## Images

--8<-- "build/chart-docs/oauth2-proxy/images.md"

## Accepted findings

--8<-- "build/chart-docs/oauth2-proxy/allowlist.md"

## Manifest

??? example "charts/oauth2-proxy/manifest.yaml"

    ```yaml
    --8<-- "charts/oauth2-proxy/manifest.yaml"
    ```

## Values reference

--8<-- "build/chart-docs/oauth2-proxy/values.md"
