# CI & automation

Every workflow lives in `.github/workflows/`. The pipeline ones install the same pinned tools through the local
`pipeline-tools` composite action.

| Workflow                   | Trigger                                          | What it does                                                                                      |
| -------------------------- | ------------------------------------------------ | ------------------------------------------------------------------------------------------------- |
| `ci.yaml`                  | push to `main`, every PR                         | the org reusable CI: `mise run lint` (repo-wide gates) and `mise run build` (this site)           |
| `pr-validate.yaml`         | PRs touching charts, artifacts or tooling        | `patchy mirror validate --all`: regen byte-identity, provenance, scans, lint; uploads the summary |
| `pr-validate-comment.yaml` | `workflow_run` of PR Validate                    | posts the summary as a sticky PR comment, from the default branch                                 |
| `publish.yaml`             | push to `main` touching the store                | re-verifies on `main`, then `patchy mirror sync --all`: mirror, push and sign                     |
| `update-check.yaml`        | daily 06:00 UTC, manual                          | `patchy mirror upgrade --check`, then one `update/<group>` branch and PR per group with work      |
| `rescan.yaml`              | weekly, Monday 05:00 UTC, manual                 | fresh-database rescan of every entry; files `security`-labelled issues                            |
| `docs.yaml`                | push to `main` touching docs or the store, daily | builds this site (chart references + Zensical) and deploys it to GitHub Pages                     |
| `security.yaml`            | push, PR, weekly                                 | CodeQL over the GitHub Actions workflows (supply-chain scanning is the pipeline's own job)        |
| `merge.yaml` and friends   | `/merge`, `/auto-merge`, reviews                 | fast-forward merging that keeps commit signatures (see the merge-notice comment on any PR)        |

## The two PR gates

`ci.yaml` is cheap and runs on every PR. It covers license headers, container and deploy scans, shellcheck, workflow
lint (actionlint and zizmor), prose, chart manifest and allowlist lint (`patchy mirror validate --all --only lint`), and
the docs build. A broken page, or a chart page whose generated fragment is missing, fails here.

`pr-validate.yaml` is the deep, per-entry gate. It only runs when something that affects the pipeline changes:
`charts/`, `artifacts/`, `mirror.yaml`, the Makefile, mise configuration, `tasks.toml` or the toolchain submodule. It
contacts every upstream registry, so it's deliberately not part of `ci.yaml`.

## Publishing

`publish.yaml` authenticates to Google Cloud with **Workload Identity Federation**, as the chart-publisher service
account the terraform artifact-store module created. The `GCP_WIF_PROVIDER` and `GCP_CHART_PUBLISHER_SA` repository
variables hold those values. The job's OIDC token gets both the GCP access token and the Fulcio signing certificate. One
docker-keychain login covers image copies, chart pushes and signing. The `-o markdown` output of `sync` becomes the job
summary.

## Documentation

`docs.yaml` publishes this site to GitHub Pages. It runs on every push to `main` that touches the docs or the store,
because the chart pages are generated from the committed tree. It also runs daily, so the expired flags on accepted
findings stay current. CI already builds the site on every PR. See [Working on the docs](../reference/docs.md).
