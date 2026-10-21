# Scanning & allowlists

## The gates

`mirror.yaml` sets the policy for the whole store, and each chart's manifest can override `failOn` and `ignoreUnfixed`
in its own `scan` block:

- **grype** scans every locked image. It **fails** the pipeline on `CRITICAL` and `HIGH` findings that have an upstream
  fix (`ignoreUnfixed: true`). A finding with no fixed release is reported but doesn't block.
- **kubescape** scans the rendered configuration (RBAC breadth, security contexts) in **warn** mode. Operator charts
  usually need broad permissions, so these findings inform review rather than block it.
- patchy also has a built-in **osv** scanner. This store leaves it off and keeps grype, whose finding set the committed
  allowlists were derived from.

## Allowlists

A blocking finding that you choose to accept goes in `charts/<name>/security/allowlist.yaml`:

```yaml
vulnerabilities:
  - id: CVE-2026-28387
    statement: Fixed in libcrypto3/libssl3 3.5.6-r0; the locked image ships 3.5.5-r0. ...
    expired_at: "2026-10-15"
    notes: Not reachable — the connector that links this is not configured on the platform.
```

Every entry needs a **statement** and an **`expired_at`** no more than `allowlistMaxDays` (90) days out. Expiry is what
makes acceptance temporary: when the date passes, the finding blocks again until someone either fixes it (usually with a
chart or image bump) or re-accepts it with a fresh review. Entries match by finding ID **and its aliases**, since CVE
and GHSA identifiers reference each other, so an entry still applies if the scanner reports the finding under another
ID.

Each chart page lists its current entries, ordered by expiry, under **Accepted findings**.

## Generated allowlists

Once images bump on their own schedule, copying a list of CVEs into the allowlist by hand on every bump isn't really
review. A chart can opt in with `scan.allowlist.generate: true`, and then `make update` rebuilds the file from a fresh
scan of the locked images. Every chart in this store has opted in. Three rules keep the result honest:

- **Findings that no longer appear are dropped.** A stale acceptance can't be told apart from a live one, so it doesn't
  stay.
- **Surviving entries keep their original `expired_at`.** Regeneration never moves the date later, so expiry still
  forces a review. New entries get `allowlistNewDays` (90) from today.
- **Per-entry `notes` are kept verbatim.** Statements are machine facts (package, installed version, fixed-in version).
  Anything a human concluded goes in `notes`, or in `scan.allowlist.preamble` for context about the whole file. The
  preamble is rendered as comments at the top of the generated file.

Approval is the PR review. The diff shows exactly which acceptances appeared, disappeared or got closer to expiry.

## After merge

The weekly [rescan workflow](automation.md) re-scans every published image set against a fresh vulnerability database.
It catches CVEs published after a chart merged, and allowlist entries close to expiry. It never blocks anything:
findings are filed as issues labelled `security`, fixed by bumping the chart or accepted in the allowlist.
