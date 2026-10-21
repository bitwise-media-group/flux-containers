# Working on the docs

This site is [Zensical](https://zensical.org), built with uv through the toolchain's python archetype. Its look comes
from the [toolchain site](https://oss.bitwisemedia.uk/toolchain/): the same `docs/stylesheets/extra.css` tokens and
header partials, with a landing page in `overrides/home.html`.

```sh
make serve        # http://localhost:8003, live reload for docs/ edits
make docs-build   # render into site/
```

Both commands regenerate the chart references first. Re-run `make serve` after a `make update` to pick up the new facts.

## Generated chart references

Chart pages are hand-written prose plus `--8<--` includes of fragments that `scripts/chart_docs.py` writes into
`build/chart-docs/` (git-ignored) from the committed tree:

| Fragment                                | Source                                                                 |
| --------------------------------------- | ---------------------------------------------------------------------- |
| `build/chart-docs/index.md`             | every chart's manifest, lock, vendored `Chart.yaml` and allowlist      |
| `build/chart-docs/<chart>/facts.md`     | `manifest.yaml`, `images.lock.yaml`, `Chart.yaml`, `mirror.yaml`       |
| `build/chart-docs/<chart>/images.md`    | `images.lock.yaml`, `images.extra.yaml` and the manifest's image rules |
| `build/chart-docs/<chart>/allowlist.md` | `security/allowlist.yaml`                                              |
| `build/chart-docs/<chart>/values.md`    | `vendor/<chart>/values.yaml`                                           |

Nothing generated is committed. The fragments come from facts that `make update` rewrites, so building them every time
is what stops the site falling behind a chart bump. `pymdownx.snippets` runs with `check_paths`, so a page that includes
a fragment that doesn't exist fails the build loudly.

### How the values reference is read

`values.yaml` files follow two comment conventions, and the generator handles both:

- **helm-docs** (`# -- description`, used by cilium, kyverno, dex, external-dns, flux and renovate). Only keys with a
  `# --` comment get a description. `# @default -- …` replaces the displayed default, `# @ignored` hides a key, a
  leading `(type)` sets the type, and cilium's `# @schema` blocks are skipped.
- **Plain comments** (cert-manager, ARC, the OpenTelemetry collector, the AWS Load Balancer Controller,
  secrets-store-sync-controller). The comment block directly above a key describes it, and a blank line breaks the link.
  Commented-out YAML inside a block is shown as an example, and a block that is only commented-out YAML is dropped.

Every leaf key gets a row, and so does every documented map. Rows are grouped under one heading per top-level key. Each
row's anchor is `#v-<dotted.path>`, so you can link to a single value.

## Pages that embed live files

Reference pages include repository files directly, such as `tasks.toml`, `mirror.yaml` and the chart manifests, with
`--8<-- "<path>"`. Snippet paths resolve against `docs/` and the repository root (`base_path` in `zensical.toml`).

## Linting

Prose under `docs/` follows the house prettier and markdownlint rules (`make lint`). `docs/.markdownlint.yaml` relaxes
the fenced-code rule, because admonition and tab bodies need indentation. The generated fragments and `site/` are
excluded.

## Publishing

`docs.yaml` builds the site and deploys it to GitHub Pages on every push to `main` that touches the docs or the store,
and once a day. Expired allowlist entries are flagged relative to the build date, so the daily run keeps those flags
accurate. CI builds it on every PR (`mise run build`). Pages must be set to **Settings → Pages → Source → GitHub
Actions**.
