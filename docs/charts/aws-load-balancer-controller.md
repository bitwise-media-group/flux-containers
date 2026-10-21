---
description:
  "Provisions AWS Application and Network Load Balancers for Kubernetes Ingress, Service and Gateway resources."
---

# aws-load-balancer-controller

The [AWS Load Balancer Controller](https://kubernetes-sigs.github.io/aws-load-balancer-controller/) provisions
Application Load Balancers for `Ingress` and Gateway API resources, and Network Load Balancers for `Service` resources
of type `LoadBalancer`, on EKS clusters. It's deployed by the flux-manifests
[`aws-load-balancer-controller`](https://github.com/bitwise-media-group/flux-manifests/tree/main/components/aws-load-balancer-controller)
component, on AWS clusters only.

--8<-- "build/chart-docs/aws-load-balancer-controller/facts.md"

## How it's mirrored

- **No upstream provenance yet.** The eks-charts helm repository publishes unsigned chart archives. The controller image
  on `public.ecr.aws` is matched by a catch-all `provider: none` rule. Both are documented gaps. Replace the catch-all
  with a real rule if upstream starts signing.
- **Images move with the chart.** The controller image is tagged with the chart's `appVersion`, so there are no track
  rules.
- **Discovery supplies the required inputs.** The chart refuses to render without a cluster name, region and VPC ID, so
  the discovery values pass placeholders. They also turn off the optional service-mutator webhook and the `IngressClass`
  resource, and turn on cert-manager for the webhook certificate. Placeholders only shape the render; the real values
  come from the flux-manifests component.

```yaml title="charts/aws-load-balancer-controller/values/discovery.yaml"
--8<-- "charts/aws-load-balancer-controller/values/discovery.yaml"
```

## Images

--8<-- "build/chart-docs/aws-load-balancer-controller/images.md"

## Accepted findings

--8<-- "build/chart-docs/aws-load-balancer-controller/allowlist.md"

## Manifest

??? example "charts/aws-load-balancer-controller/manifest.yaml"

    ```yaml
    --8<-- "charts/aws-load-balancer-controller/manifest.yaml"
    ```

## Values reference

--8<-- "build/chart-docs/aws-load-balancer-controller/values.md"
