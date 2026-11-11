# patchy.yaml

`patchy.yaml` at the repository root is [patchy's configuration](https://oss.bitwisemedia.uk/patchy/cli/#configuration)
for the store: the registries, signing identity and scan gates every `patchy mirror` command shares, and the mirror's
own settings under `mirror:`. Whatever is chart-specific belongs in that chart's manifest. The file carries no
`apiVersion` or `kind`. patchy also merges `~/.config/patchy/config.yaml` and `/etc/patchy/config.yaml` beneath it, but
nothing this store needs lives there.

| Field                                   | This store                                    | Meaning                                                                                               |
| --------------------------------------- | --------------------------------------------- | ----------------------------------------------------------------------------------------------------- |
| `registries[].name`                     | `google`                                      | the key used for this registry in each lock's `targets`                                               |
| `registries[].url`                      | the artifact-store `platform_registry` output | `<location>-docker.pkg.dev/<project>/<repository>`                                                    |
| `registries[].chartNamespace`           | `charts`                                      | path prefix for charts                                                                                |
| `registries[].imageNamespace`           | `images`                                      | path prefix for images, followed by the image's original registry path                                |
| `registries[].artifactNamespace`        | `artifacts`                                   | path prefix for non-chart artifacts                                                                   |
| `registries[].signing`                  | —                                             | optional per-registry override of `signing`                                                           |
| `signing.provider`                      | `keyless`                                     | `keyless` or `kms`                                                                                    |
| `signing.keyless.certificateIdentity`   | the publish workflow on `main`                | the identity the signatures carry; consumers pin it                                                   |
| `signing.keyless.certificateOidcIssuer` | GitHub Actions                                |                                                                                                       |
| `signing.keyless.tlogUpload`            | `true`                                        | upload to the public Rekor log (deliberate: the repositories are public)                              |
| `mirror.update.cooldownDays`            | `3`                                           | soak period for tracked-image picks. See [Tracked images](../concepts/tracked-images.md#the-cooldown) |
| `scan.scanners`                         | grype on; kubescape on, `warn`                | `osv`, `grype`, `kubescape` (with `mode`)                                                             |
| `scan.failOn`                           | `[CRITICAL, HIGH]`                            | severities that block                                                                                 |
| `scan.ignoreUnfixed`                    | `true`                                        | findings with no upstream fix don't block                                                             |
| `scan.allowlist.maxDays`                | `90`                                          | the furthest an `expired_at` may be                                                                   |
| `scan.allowlist.newDays`                | `90`                                          | expiry given to new generated entries; must be ≤ `scan.allowlist.maxDays`                             |
| `mirror.sourceRegistryRewrites`         | `{}`                                          | rewrites applied when pulling (a pull-through mirror); lock targets keep canonical paths              |

The Workload Identity Federation wiring the publish workflow uses is in repository variables, not here. It's workflow
configuration, not mirror policy.

## The file, as committed

```yaml
--8<-- "patchy.yaml"
```
