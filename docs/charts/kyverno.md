---
description: "Kubernetes-native policy engine: admission validation, mutation, generation and image verification."
---

# kyverno

[Kyverno](https://kyverno.io) is the policy engine. Its admission, background, cleanup and reports controllers validate,
mutate and generate resources, and verify image signatures. The platform's cluster policy is what enforces the mirror's
keyless signatures at admission. It's deployed by the flux-manifests
[`kyverno`](https://github.com/bitwise-media-group/flux-manifests/tree/main/components/kyverno) component, and its
policies by `kyverno-policies`.

--8<-- "build/chart-docs/kyverno/facts.md"

## How it's mirrored

- **Signatures live in a dedicated repository.** Kyverno keyless-signs the chart and images but publishes the signatures
  to `ghcr.io/kyverno/signatures` rather than next to the artifacts, so every rule sets `signatureRepository`.
- **The vanity registry.** Kyverno 1.18+ references its images through `reg.kyverno.io`. Rules cover both that and
  `ghcr.io/kyverno/*`.
- **Images move with the chart.** Every image is tagged with the chart's `appVersion`, so there are no track rules.
- **Test hooks stay out.** The helm-test `readiness-checker` image (on a mutable `latest` tag) is excluded: tests never
  run under Flux.
- **Discovery matches runtime.** `webhooksCleanup` and `policyReportsCleanup` (hook jobs) are off in the discovery
  values and in the flux-manifests component. That keeps the mirrored image set exactly what the cluster runs.

```yaml title="charts/kyverno/values/discovery.yaml"
--8<-- "charts/kyverno/values/discovery.yaml"
```

## Images

--8<-- "build/chart-docs/kyverno/images.md"

## Accepted findings

--8<-- "build/chart-docs/kyverno/allowlist.md"

## Manifest

??? example "charts/kyverno/manifest.yaml"

    ```yaml
    --8<-- "charts/kyverno/manifest.yaml"
    ```

## Values reference

--8<-- "build/chart-docs/kyverno/values.md"
