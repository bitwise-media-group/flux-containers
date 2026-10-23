# Tracked images

Usually an image moves when its chart does: the chart's `appVersion` sets the tag, and bumping the chart bumps the
image. Some images are released on their own schedule instead:

- The **actions runner** is released on `actions/runner` 2.x, which has nothing to do with the scale set chart's
  version. The chart's own default is the mutable `:latest`.
- **dex**, **external-dns** and the **OpenTelemetry collector** release images faster than their charts, whose
  `appVersion` can lag by months. Pinning the chart alone would leave the platform on an old, vulnerable image.

For these, the manifest declares a **track** rule:

```yaml
images:
  track:
    - image: ghcr.io/actions/actions-runner
      versionConstraint: ">=2.320.0 <3.0.0" # optional; default: the pinned tag's own major
      cooldownDays: 3 # optional; default: mirror.yaml update.cooldownDays
      valuesFile: values/discovery.yaml # optional; default: the first discovery values file
      valuesPath: .template.spec.containers[0].image
```

The pin lives at `valuesPath` in the discovery values. The value there is either a full image reference (`image:tag`)
or a bare tag, for charts that split `image.repository` from `image.tag`. The path must already exist: a pick replaces a
value but never creates one. That line is a **fact**. Don't edit it by hand. Change the rule instead.

Two things move it:

- **Renovate** reads the line through a `# renovate:` annotation directly above it, and opens a PR when a newer tag
  inside the major appears. Every tracked pin needs one, or Renovate never sees it:

  ```yaml
  image:
    # renovate: datasource=docker depName=ghcr.io/dexidp/dex
    tag: v2.46.0
  ```

  patchy's edits splice only the value token, so the annotation survives `make update`.

- **`make update`** picks a tag past the cooldown (below) and writes it in place.

| Chart                                                           | Tracked image                                                                             | Written to                           |
| --------------------------------------------------------------- | ----------------------------------------------------------------------------------------- | ------------------------------------ |
| [dex](../charts/dex.md)                                         | `ghcr.io/dexidp/dex`                                                                      | `.image.tag`                         |
| [external-dns](../charts/external-dns.md)                       | `registry.k8s.io/external-dns/external-dns`                                               | `.image.tag`                         |
| [gha-runner-scale-set](../charts/gha-runner-scale-set.md)       | `ghcr.io/actions/actions-runner`                                                          | `.template.spec.containers[0].image` |
| [opentelemetry-collector](../charts/opentelemetry-collector.md) | `ghcr.io/open-telemetry/opentelemetry-collector-releases/opentelemetry-collector-contrib` | `.image.tag`                         |

## The cooldown

The cooldown applies to `make update`'s own pick. Renovate can't see when an OCI image was published, so its tracked-tag
PRs open as soon as the tag appears; the human review is the gate there.

`update` walks the candidate tags from newest to oldest and takes the first one published at least `update.cooldownDays`
ago. That's 3 days by default, set in `mirror.yaml`. An image can override it with `cooldownDays`, and `0` tracks the
newest tag immediately.

So a release that upstream yanks or hot-fixes within its first few days is never the one the platform adopts. The cost
is that the platform deliberately runs one release behind, and a freshly published security _fix_ waits out the same
cooldown. Keep the window short for that reason.

## Why only `update` picks

The pick depends on wall-clock time, so it runs only in `update` and never in `validate`. Validation has to regenerate
byte-identically. If it re-picked, a tag ageing past the cooldown during review would fail pr-validate on a tree nobody
had touched. See [Determinism](intent-and-facts.md#determinism).

Renovate's post-upgrade step (`patchy mirror upgrade --pinned`) doesn't pick either: it keeps the tag Renovate wrote,
checks it against `versionConstraint`, and regenerates the lock, rendered manifests and allowlist around it. A tracked
image moves in its own PR, separately from its chart.
