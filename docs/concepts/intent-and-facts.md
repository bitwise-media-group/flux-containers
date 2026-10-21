# Intent and facts

Every file in a chart directory is one of two kinds. **Intent** is what a human decided. **Facts** are what a machine
derived from that intent and from upstream. Reviewers approve intent. The pipeline proves the facts follow from it.

| File                      | Kind      | Written by                               | Says                                                         |
| ------------------------- | --------- | ---------------------------------------- | ------------------------------------------------------------ |
| `manifest.yaml`           | intent    | you (version bumps: `make update`)       | which chart, which versions, how upstream signs, what to add |
| `values/discovery.yaml`   | intent    | you (tracked-image lines: `make update`) | the values to render with so discovery sees every image      |
| `security/allowlist.yaml` | intent    | you, or `make update` when generated     | which scan findings are accepted, why, and until when        |
| `images.extra.yaml`       | generated | `make update`                            | extra images derived from distribution manifests             |
| `vendor/<chart>/`         | fact      | `make update`                            | the upstream chart, byte for byte                            |
| `rendered/manifests.yaml` | fact      | `make update`                            | the `helm template` output for the discovery values          |
| `images.lock.yaml`        | fact      | `make update`                            | every image, resolved to a digest, with its mirror targets   |

Some intent files contain machine-written lines. The version in `manifest.yaml`, the tracked image tag in
`values/discovery.yaml`, and a generated allowlist are all written by `make update`. To change one of those, change the
rule that produces it: the constraint, the track rule, or the scan. Don't edit the value.

## The byte-identity gate

`make update` (`patchy mirror upgrade`) is the only command that writes facts. `make validate` and pr-validate run the
same regeneration out of tree and **byte-compare** the result with the commit. A mismatch fails the PR, and it means one
of three things:

- someone edited intent without running `make update`;
- someone edited a fact by hand;
- upstream changed something it had already released, such as a re-pushed chart version or a mutated tag.

Each of these needs a human, and the gate makes sure one sees it. Because the committed tree regenerates exactly, a
reviewer can trust the diff: `rendered/manifests.yaml` is what the chart does to a cluster, and `images.lock.yaml` is
exactly the image set that will be mirrored.

## Determinism

Byte-identity only works if regeneration is deterministic, which shapes the rules elsewhere:

- **Wall-clock decisions happen only in `update`.** Picking a tracked image tag (it depends on how old a tag is) and
  stamping expiry dates on new allowlist entries never happen in `validate`. Otherwise a tag ageing past the cooldown
  mid-review would fail pr-validate on a tree nobody touched.
- **Discovery values avoid random output.** A chart that generates certificates or passwords on every render must have
  that turned off in `values/discovery.yaml`. The [cilium](../charts/cilium.md) Hubble TLS settings are an example.
- **Formatters stay out of facts.** `.prettierignore` and `.licenseignore` exclude `vendor/`, `rendered/`, the image
  locks and the generated sidecars, so `make fmt` never rewrites them.

## No central registry of entries

The tree is the list. `patchy mirror` finds entries by looking for `charts/*/manifest.yaml` and
`artifacts/*/manifest.yaml`. Adding a directory adds an entry, and deleting it removes one. This site's
[catalogue](../charts/index.md) is generated the same way.
