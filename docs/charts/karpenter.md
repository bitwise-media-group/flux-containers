---
description: "Node auto-provisioning for EKS: launches and retires EC2 capacity for pending pods."
---

# karpenter

[Karpenter](https://karpenter.sh) provisions EC2 nodes for pods the scheduler can't place, and consolidates or retires
them when they're no longer needed. This is the AWS provider's chart, and it ships the `karpenter.sh` and
`karpenter.k8s.aws` CRDs (`NodePool`, `NodeClaim`, `EC2NodeClass` and friends) in its `crds/` directory. It's deployed
by the flux-manifests
[`karpenter`](https://github.com/bitwise-media-group/flux-manifests/tree/main/components/karpenter) component, on AWS
clusters only.

--8<-- "build/chart-docs/karpenter/facts.md"

## How it's mirrored

- **Fully keyless upstream.** `aws/karpenter-provider-aws` signs both the OCI chart and the controller image from its
  tag-push release workflow (`.github/workflows/release.yaml@refs/tags/v<version>`), so both are verified keyless
  against that identity.
- **One image, moving with the chart.** The controller is the only image (the v1 chart has no separate webhook), and the
  chart pins it by tag and digest, so there are no track rules.
- **The full chart, not `karpenter-crd`.** Upstream also publishes the CRDs alone as `karpenter-crd`, for installs that
  manage CRDs separately. The platform lets the main chart install them, so only this chart is mirrored.
- **Discovery mirrors the platform's deployment.** The controller renders into `kube-system`, as the `karpenter`
  ServiceAccount the terraform Pod Identity association binds, pinned to the `role: system` node group. The cluster name
  and interruption queue are placeholders: the real ones come from cluster variables in the flux-manifests component.

```yaml title="charts/karpenter/values/discovery.yaml"
--8<-- "charts/karpenter/values/discovery.yaml"
```

!!! warning "No AWS mirror target yet"

    `mirror.yaml` publishes to the Google Artifact Registry only. EKS clusters pull from the ECR registry terraform
    names as `CONTAINER_REGISTRY`, and nothing in this store writes there yet, so this chart's mirrored image only
    reaches AWS clusters once an ECR registry target (or a replication path into ECR) exists. See
    [Consuming the mirror](../reference/consuming.md#where-things-land).

## Images

--8<-- "build/chart-docs/karpenter/images.md"

## Accepted findings

--8<-- "build/chart-docs/karpenter/allowlist.md"

## Manifest

??? example "charts/karpenter/manifest.yaml"

    ```yaml
    --8<-- "charts/karpenter/manifest.yaml"
    ```

## Values reference

--8<-- "build/chart-docs/karpenter/values.md"
