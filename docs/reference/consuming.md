# Consuming the mirror

## Where things land

For a registry `<url>` in `mirror.yaml`, which for this store is
`us-central1-docker.pkg.dev/o-foundation-7e43/platform`:

| What  | Reference                                            | Example                                                              |
| ----- | ---------------------------------------------------- | -------------------------------------------------------------------- |
| Chart | `oci://<url>/<chartNamespace>/<name>`, tag = version | `oci://…/platform/charts/cert-manager` tag `v1.21.1`                 |
| Image | `<url>/<imageNamespace>/<original path>:<tag>`       | `…/platform/images/quay.io/jetstack/cert-manager-controller:v1.21.1` |

Images keep their **original registry path** under `images/`, so a chart value can be rewritten mechanically: prefix the
upstream repository with `<url>/images/`. Each chart page lists the exact mirror targets for its locked images.

## Verifying a signature

Everything is signed keylessly by the publish workflow:

```sh
identity="https://github.com/bitwise-media-group/flux-containers/.github/workflows/publish.yaml@refs/heads/main"
cosign verify \
  --certificate-identity "$identity" \
  --certificate-oidc-issuer "https://token.actions.githubusercontent.com" \
  us-central1-docker.pkg.dev/o-foundation-7e43/platform/charts/cert-manager:v1.21.1
```

Use the same command for any mirrored image path. Pulling needs read access to the Artifact Registry repository.

## In flux-manifests

Each flux-manifests component consumes a chart the same way. The registry and identity arrive as cluster variables
(`PLATFORM_REGISTRY`, `CONTAINER_REGISTRY`, `SIGNED_IDENTITY_ISSUER`, `SIGNED_IDENTITY_CHARTS`,
`SIGNED_IDENTITY_IMAGES`), set by terraform:

- A `ResourceSetInputProvider` lists the chart's tags in the mirror and selects the newest one inside a semver range.
  New mirrored versions reach clusters without a manifests change, within that range.
- An `OCIRepository` pulls `oci://${PLATFORM_REGISTRY}/charts/<name>` at that tag and **verifies** it with cosign
  against the publish workflow's identity.
- The `HelmRelease` values point every image at `${CONTAINER_REGISTRY}/images/<original path>`. The Kyverno cluster
  policy then requires the mirror's signature on every image at admission.

```yaml
apiVersion: source.toolkit.fluxcd.io/v1
kind: OCIRepository
metadata:
  name: cert-manager
  namespace: cert-manager
spec:
  interval: 1h
  url: oci://${PLATFORM_REGISTRY}/charts/cert-manager
  provider: gcp
  ref:
    tag: v1.21.1 # selected by the ResourceSetInputProvider
  verify:
    provider: cosign
    matchOIDCIdentity:
      - issuer: "${SIGNED_IDENTITY_ISSUER}"
        subject: "${SIGNED_IDENTITY_CHARTS}"
```

!!! tip "Use each chart's values reference"

    The **Values reference** on every [chart page](../charts/index.md) lists the keys a `HelmRelease` can set, with
    defaults and upstream descriptions, for exactly the vendored version. Link to a single value with its row anchor,
    for example `charts/kyverno/#v-admissionController.replicas`.

## Consumer-side constraints

The consumer's semver range and the mirror's `versionConstraint` are separate controls. The mirror decides which
versions **exist** in the registry. The consumer decides which of those a cluster **adopts**. Some charts keep them in
step on purpose. For example, the secrets-store-sync-controller constraint floor matches `SECRET_SYNC_SEMVER` in
flux-manifests, so raise both together.
