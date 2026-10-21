---
description: "The OpenTelemetry Collector (contrib distribution): receives, processes and exports telemetry."
---

# opentelemetry-collector

The [OpenTelemetry Collector](https://opentelemetry.io/docs/collector/) receives, processes and exports traces, metrics
and logs. The platform runs the `-contrib` distribution in `deployment` mode.

--8<-- "build/chart-docs/opentelemetry-collector/facts.md"

## How it's mirrored

- **The contrib image is tracked.** Collector images release weekly and the chart's `appVersion` lags them. The
  discovery values select the `-contrib` repository, and a track rule re-picks the newest soaked `0.x` tag into
  `.image.tag` on every `make update`. See [Tracked images](../concepts/tracked-images.md).
- **Unsigned chart, signed image.** The OCI charts are published unsigned, which is a documented gap. The collector
  images are keyless-signed by the `opentelemetry-collector-releases` workflows.

```yaml title="charts/opentelemetry-collector/values/discovery.yaml"
--8<-- "charts/opentelemetry-collector/values/discovery.yaml"
```

## Images

--8<-- "build/chart-docs/opentelemetry-collector/images.md"

## Accepted findings

--8<-- "build/chart-docs/opentelemetry-collector/allowlist.md"

## Manifest

??? example "charts/opentelemetry-collector/manifest.yaml"

    ```yaml
    --8<-- "charts/opentelemetry-collector/manifest.yaml"
    ```

## Values reference

--8<-- "build/chart-docs/opentelemetry-collector/values.md"
