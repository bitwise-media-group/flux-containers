# Chart catalogue

Every chart the mirror manages, as pinned on `main` when this site was built. Each chart directory holds a
`manifest.yaml`, and `patchy mirror` discovers the entries from the tree, so there's no central list. This table is
generated from the same files.

--8<-- "build/chart-docs/index.md"

**Chart provenance** is how the upstream chart archive itself is verified. Images carry their own rules, and most charts
marked _unverified_ still have keyless-verified images. Each chart's page lists the rule for every image. **Accepted
findings** counts the entries in `security/allowlist.yaml`. Each entry is an accepted risk with an expiry date. See
[Scanning & allowlists](../concepts/scanning.md).

## By role

| Role                    | Charts                                                                                                                                   |
| ----------------------- | ---------------------------------------------------------------------------------------------------------------------------------------- |
| GitOps                  | [flux-operator](flux-operator.md) + [flux-instance](flux-instance.md) (lockstep `flux`)                                                  |
| Networking & ingress    | [cilium](cilium.md), [aws-load-balancer-controller](aws-load-balancer-controller.md), [external-dns](external-dns.md)                    |
| Certificates & identity | [cert-manager](cert-manager.md), [dex](dex.md)                                                                                           |
| Policy & secrets        | [kyverno](kyverno.md), [secrets-store-sync-controller](secrets-store-sync-controller.md)                                                 |
| CI runners              | [gha-runner-scale-set-controller](gha-runner-scale-set-controller.md) + [gha-runner-scale-set](gha-runner-scale-set.md) (lockstep `arc`) |
| Observability           | [opentelemetry-collector](opentelemetry-collector.md)                                                                                    |
| Automation              | [renovate](renovate.md)                                                                                                                  |

## What each chart page shows

- **The pin**: upstream repository, pinned version and constraint, lockstep group, chart provenance and the published
  OCI reference.
- **How it's mirrored**: the intent behind the manifest. That covers why images are tracked or not, extra and excluded
  images, provenance gaps, and why the discovery values look the way they do.
- **Images**: every locked image with its digest, platforms and the provenance rule it matched, plus the mirror target
  paths.
- **Accepted findings**: the current allowlist with expiry dates.
- **Values reference**: every key in the vendored chart's `values.yaml`, with its type, default and upstream
  description. These are the values a flux-manifests `HelmRelease` can set. Each row has an anchor, so you can link to a
  single value, for example `cert-manager/#v-crds.enabled`.

!!! info "Discovery values are not deployment values"

    `values/discovery.yaml` exists only so the discovery render sees every image a real deployment would. A cluster's
    actual configuration lives in the flux-manifests component that deploys the chart.
