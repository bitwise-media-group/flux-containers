---
description: "Prometheus Operator, Prometheus, Alertmanager, Grafana and the exporters that monitor the cluster itself."
---

# kube-prometheus-stack

[kube-prometheus-stack](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack)
installs the Prometheus Operator with a Prometheus, an Alertmanager, Grafana, kube-state-metrics and node-exporter, plus
the default recording rules, alerts and dashboards for the cluster itself. It's deployed by the flux-manifests
[`kube-prometheus-stack`](https://github.com/bitwise-media-group/flux-manifests/tree/main/components/kube-prometheus-stack)
component into the `monitoring` namespace.

--8<-- "build/chart-docs/kube-prometheus-stack/facts.md"

## How it's mirrored

- **Images move with the chart.** Every image is pinned by the chart or one of its subcharts, so there are no track
  rules. The operator, its CRDs and its config-reloader have to stay on one version.
- **One image helm can't see.** The operator injects `prometheus-config-reloader` into every Prometheus and Alertmanager
  pod it creates, and reads the image from a command-line flag rather than a pod spec. `images.extra` adds it at
  `{appVersion}`.
- **No certgen job.** The platform issues the operator's admission webhook certificate with cert-manager, so the
  discovery values turn on `admissionWebhooks.certManager` and the `kube-webhook-certgen` image is never mirrored. The
  Grafana helm test hook is off too, since it never runs under Flux.
- **A deterministic render.** Without an existing secret, the Grafana subchart mints a random admin password on every
  render. Discovery names one so the byte-identity gate holds. The runtime release lets the chart generate its own.
- **Mixed provenance.** The prometheus-operator images are keyless-signed by their release workflow, and
  kube-state-metrics by the Kubernetes release promoter. The chart, Prometheus, Alertmanager, node-exporter, Grafana and
  the k8s-sidecar dashboard loader are published unsigned, which is a documented gap.
- **Majors are reviewed.** The chart cuts a major for each prometheus-operator CRD change or breaking values rename, so
  the constraint stays inside the current major.

```yaml title="charts/kube-prometheus-stack/values/discovery.yaml"
--8<-- "charts/kube-prometheus-stack/values/discovery.yaml"
```

## Images

--8<-- "build/chart-docs/kube-prometheus-stack/images.md"

## Accepted findings

--8<-- "build/chart-docs/kube-prometheus-stack/allowlist.md"

## Manifest

??? example "charts/kube-prometheus-stack/manifest.yaml"

    ```yaml
    --8<-- "charts/kube-prometheus-stack/manifest.yaml"
    ```

## Values reference

--8<-- "build/chart-docs/kube-prometheus-stack/values.md"
