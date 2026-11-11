# Tasks

Every task is a mise task, and the Makefile forwards `make <task>` to `mise run <task>`. The pipeline tasks come from
the toolchain's [containers archetype](https://oss.bitwisemedia.uk/toolchain/archetypes/containers/) and forward to
`patchy mirror`. `ENTRY` selects entries, space-separated (`make mirror-validate ENTRY="dex kyverno"`); unset, a task
covers every entry. Flags for patchy go after `--` on `mise run` (`mise run mirror-validate -- -o markdown`). patchy
writes data to stdout and logs to stderr.

## Pipeline

| Task              | Runs                                      | Notes                                                                        |
| ----------------- | ----------------------------------------- | ---------------------------------------------------------------------------- |
| `mirror-check`    | `patchy mirror upgrade --check`           | the lockstep-aware update plan; touches nothing                              |
| `mirror-upgrade`  | `patchy mirror upgrade`                   | bump pin + tracked tags, regenerate every fact; a no-op when current         |
| `mirror-validate` | `patchy mirror validate`                  | regen byte-identity, provenance, scan, lint — what pr-validate runs          |
| `mirror-lint`     | `patchy mirror validate --only lint`      | manifests and CVE allowlists                                                 |
| `mirror-add`      | `patchy mirror add [$ENTRY] --url "$URL"` | scaffold an entry; `ENTRY` is required for an `https://` helm repository     |
| `mirror-publish`  | `patchy mirror sync`                      | needs a registry login with push rights; normally the publish workflow's job |

## Gates and rollups

| Task    | Runs                                                                                                                        |
| ------- | --------------------------------------------------------------------------------------------------------------------------- |
| `lint`  | license headers, container + shell + workflow (actionlint, zizmor) checks, and prose                                        |
| `fmt`   | prose format + license headers. Never rewrites YAML facts (see `.prettierignore`/`.licenseignore`)                          |
| `build` | `patchy build --all --dry-run`. The store has no `build:` entries, so it reports there is nothing to build and succeeds     |
| `ci`    | `lint`, `build`, `docs-build`: what the reusable CI workflow covers                                                         |
| `pr`    | `fmt`, `lint`, `mirror-validate` over every entry, `build`, `docs-build`, `commit` (runs an agent's `commit.sh` if present) |

No rollup the reusable CI runs includes a `mirror-*` task. Allowlist expiry makes `mirror-lint` time-dependent, so an
entry expiring anywhere in the store would fail every pull request; pr-validate lints the entries a pull request changes
instead, and the weekly rescan lints them all.

## Documentation

| Task         | Runs                                                                              |
| ------------ | --------------------------------------------------------------------------------- |
| `serve`      | regenerate the chart references, then `zensical serve` on <http://localhost:8003> |
| `docs-build` | regenerate the chart references, then `zensical build` into `site/`               |

`tasks.toml` restates `docs-build` and `serve` so the chart references are generated first, and `pr` so the local gate
runs the whole mirror pipeline. The toolchain's common tasks (`license`, `actionlint`, `zizmor`, `commit`) are available
as well. Run `make help` for the full list.

## The task file

This is the live `tasks.toml`, embedded when the site is built:

```toml
--8<-- "tasks.toml"
```
