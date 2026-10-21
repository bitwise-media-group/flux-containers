# Adding a chart

## 1. Scaffold the entry

```sh
make add URL=oci://ghcr.io/example/charts/widget        # entry named after the last path segment
make add URL=https://charts.example.com CHART=widget    # an https repo doesn't name the chart, so you do
```

`patchy mirror add` detects what the URL points at and creates `charts/<name>/`. That holds a `manifest.yaml` pinned to
the newest stable upstream version, with a stay-in-major constraint and `provider: none` provenance placeholders, plus a
starter `values/discovery.yaml`. Nothing is vendored yet. Review the scaffold before you run anything else.

## 2. Write the intent

Edit `charts/<name>/manifest.yaml`. Every field is described in [Chart manifest](../reference/manifest.md).

- **`chart.versionConstraint`**: the range `update` may move within. Usually this is the current major.
- **`chart.lockstep`**: set it if the chart is released as a pair with another entry. Both entries then share the group
  name.
- **`chart.verifyUpstream`** and **`images.verifyUpstream`**: find out how upstream signs. Look for cosign keyless in
  the release workflow, a published cosign key, or a dedicated signatures repository. Write real rules. Use
  `provider: none` only for a genuine gap, with a comment explaining why.
- **`images.extra`**: add images the chart's workloads launch at runtime that `helm template` can't see. Give each one a
  `reason`.
- **`images.exclude`**: drop images that never run under Flux, such as helm test hooks.
- **`images.track`**: use for images released on their own schedule. See
  [Tracked images](../concepts/tracked-images.md).
- **`scan.allowlist.generate`** and **`preamble`**: opt in to generated allowlists. The preamble gives reviewers context
  for the whole file.

Then fill in `values/discovery.yaml` with whatever the chart needs to render the same image set a real deployment would.
That means required inputs, the features the platform turns on, and the namespace it deploys into. The render must also
be **deterministic**: turn off anything that generates random material (certificates, passwords) on every render.
Otherwise the byte-identity gate fails.

## 3. Generate and validate

```sh
make update CHART=widget
make validate CHART=widget
```

The first `update` vendors the chart and writes every fact. `validate` then has to pass: regeneration must be
byte-identical, provenance must verify, the scan must have no blocking findings outside the allowlist, and lint must
pass.

## 4. Document it

Add the chart to this site. The generator already writes the chart's fragments, but nothing shows them until a page
includes them.

1. Create `docs/charts/<name>.md`. Copy an existing chart page: it's a `description` front-matter line, a short
   introduction, a **How it's mirrored** section, and the generated fragments (`--8<--` includes of
   `build/chart-docs/<name>/*.md`).
2. Add it to the `Charts` section of `nav` in `zensical.toml`. The landing page reads its chart list, count and card
   text from there.
3. Add it to the **By role** table in `docs/charts/index.md`.

Run `make serve` and check the page. The images, findings and values tables are generated, so you only write the prose.

## 5. Open the PR

pr-validate runs the full pipeline and posts its summary. After merge, the publish workflow mirrors the images and
pushes the chart. The chart can then be consumed from `oci://<registry>/charts/<name>`.
