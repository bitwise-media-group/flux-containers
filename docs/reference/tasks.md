# Tasks

Every task is a mise task, and the Makefile forwards `make <task>` to `mise run <task>`, exporting `CHART`. Most
pipeline tasks forward to `patchy mirror` and act on the single entry named by `CHART`. The `*-all` variants attempt
every entry and print a summary. patchy writes data to stdout and logs to stderr.

## Pipeline

| Task            | Runs                                        | Notes                                                                        |
| --------------- | ------------------------------------------- | ---------------------------------------------------------------------------- |
| `check-updates` | `patchy mirror upgrade --check --all`       | the lockstep-aware update plan; touches nothing                              |
| `update`        | `patchy mirror upgrade "$CHART"`            | bump pin + tracked tags, regenerate every fact; a no-op when current         |
| `update-all`    | `patchy mirror upgrade --all`               |                                                                              |
| `validate`      | `patchy mirror validate "$CHART"`           | regen byte-identity, provenance, scan, lint — what pr-validate runs          |
| `validate-all`  | `lint`, then `patchy mirror validate --all` |                                                                              |
| `add`           | `patchy mirror add [$CHART] --url "$URL"`   | scaffold an entry; `CHART` is required for an `https://` helm repository     |
| `publish`       | `patchy mirror sync "$CHART"`               | needs a registry login with push rights; normally the publish workflow's job |
| `publish-all`   | `patchy mirror sync --all`                  | the publish workflow's verb                                                  |

## Gates and rollups

| Task           | Runs                                                                                                                                                                                        |
| -------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `lint`         | license headers, container + shell + workflow (actionlint, zizmor) checks, and prose                                                                                                        |
| `lint-entries` | `patchy mirror validate --all --only lint`: every entry's manifest and CVE allowlist. Not part of `lint`, because allowlist expiry is time-dependent; pr-validate lints the changed entries |
| `fmt`          | prose format + license headers. Never rewrites YAML facts (see `.prettierignore`/`.licenseignore`)                                                                                          |
| `ci`           | `lint` + `build`: what the reusable CI workflow covers                                                                                                                                      |
| `pr`           | `fmt`, `validate-all`, `build`. No commit step, like common's                                                                                                                               |

## Documentation

| Task         | Runs                                                                              |
| ------------ | --------------------------------------------------------------------------------- |
| `serve`      | regenerate the chart references, then `zensical serve` on <http://localhost:8003> |
| `docs-build` | regenerate the chart references, then `zensical build` into `site/`               |
| `build`      | `docs-build`; the reusable CI runs it so a broken page fails the PR               |

The toolchain's python archetype is included only for the docs site. It contributes `test` (pytest, which skips because
it isn't a dependency) and its own helpers. `tasks.toml` restates `fmt`, `ci` and `pr` so the archetype's ruff-first
variants don't replace them. The toolchain's common tasks (`license`, `actionlint`, `zizmor`, `commit`) are available as
well. Run `make help` for the full list.

## The task file

This is the live `tasks.toml`, embedded when the site is built:

```toml
--8<-- "tasks.toml"
```
