# Copyright 2026 BitWise Media Group Ltd
# SPDX-License-Identifier: MIT

"""Generate the per-chart reference fragments the docs site embeds.

Every chart page under docs/charts/ is hand-written prose plus a handful of
`--8<--` snippet includes pointing at build/chart-docs/<chart>/*.md, which
this script writes from the committed tree on every build:

  index.md               the chart catalogue table (docs/charts/index.md)
  <chart>/facts.md       pin, constraint, lockstep group, provenance, mirror path
  <chart>/images.md      the digest-pinned image lock
  <chart>/allowlist.md   accepted scan findings and their expiry
  <chart>/values.md      the vendored chart's values.yaml as a reference table

Nothing here is committed: the fragments are derived from FACT files that
`patchy mirror upgrade` rewrites, so generating them at build time is what
keeps the site from drifting behind a chart bump. Run from the repo root:

  uv run python scripts/chart_docs.py [--out build/chart-docs]
"""

from __future__ import annotations

import argparse
import html
import json
import re
import shutil
import sys
from dataclasses import dataclass, field
from datetime import date
from pathlib import Path
from typing import Any

import markdown
import yaml

REPO_URL = "https://github.com/bitwise-media-group/flux-containers"
PATCHY_CLI = "https://oss.bitwisemedia.uk/patchy/cli/"

# Defaults longer than this are cut in the table; the full value is one click
# away in the vendored values.yaml.
MAX_DEFAULT = 240


# ---------------------------------------------------------------- helpers


def load_yaml(path: Path) -> Any:
    with path.open(encoding="utf-8") as f:
        return yaml.safe_load(f)


def cell(text: Any) -> str:
    """Escape a value for a pipe-table cell."""
    return str(text).replace("|", "\\|").replace("\n", " ")


def code(text: Any) -> str:
    """Inline code for a pipe-table cell, with pipes escaped."""
    return f"`{cell(text)}`"


def tree_link(chart: str, rel: str = "") -> str:
    suffix = f"/{rel}" if rel else ""
    return f"{REPO_URL}/tree/main/charts/{chart}{suffix}"


def blob_link(chart: str, rel: str) -> str:
    return f"{REPO_URL}/blob/main/charts/{chart}/{rel}"


def osv_link(vuln_id: str) -> str:
    return f"https://osv.dev/vulnerability/{vuln_id}"


def provenance(rule: dict[str, Any] | None) -> str:
    """One-line summary of a verifyUpstream rule."""
    if not rule:
        return "not declared"
    provider = rule.get("provider", "none")
    if provider == "none":
        return "**unverified** (`provider: none`, documented gap)"
    if provider == "cosign-keyless":
        ident = rule.get("certificateIdentityRegexp") or rule.get("certificateIdentity", "")
        parts = [f"cosign keyless — identity {code(ident)}"]
        if rule.get("signatureRepository"):
            parts.append(f"signatures in {code(rule['signatureRepository'])}")
        return ", ".join(parts)
    if provider == "cosign-key":
        parts = [f"cosign key [{rule.get('key', '')}]({rule.get('key', '')})"]
        if rule.get("signatureDigestAlgorithm"):
            parts.append(f"{rule['signatureDigestAlgorithm']} digests")
        return ", ".join(parts)
    return code(provider)


# ---------------------------------------------------------------- the chart model


@dataclass
class Chart:
    name: str
    root: Path
    manifest: dict[str, Any]
    lock: dict[str, Any]
    chart_yaml: dict[str, Any]
    vendor_dir: Path
    extra: list[dict[str, Any]] = field(default_factory=list)
    allowlist: dict[str, Any] = field(default_factory=dict)

    @property
    def version(self) -> str:
        return str(self.lock.get("chart", {}).get("version") or self.manifest["chart"]["version"])

    @property
    def app_version(self) -> str:
        return str(self.chart_yaml.get("appVersion", ""))

    @property
    def lockstep(self) -> str:
        return str(self.manifest.get("chart", {}).get("lockstep", ""))

    @property
    def images(self) -> list[dict[str, Any]]:
        return self.lock.get("images") or []

    @property
    def tracked(self) -> list[dict[str, Any]]:
        return self.manifest.get("images", {}).get("track") or []


def load_chart(root: Path) -> Chart:
    manifest = load_yaml(root / "manifest.yaml")
    lock = load_yaml(root / "images.lock.yaml") or {}
    vendor_dir = root / "vendor" / manifest["chart"]["name"]
    chart_yaml = load_yaml(vendor_dir / "Chart.yaml") or {}
    chart = Chart(manifest["name"], root, manifest, lock, chart_yaml, vendor_dir)
    if (root / "images.extra.yaml").is_file():
        chart.extra = (load_yaml(root / "images.extra.yaml") or {}).get("extra") or []
    if (root / "security" / "allowlist.yaml").is_file():
        chart.allowlist = load_yaml(root / "security" / "allowlist.yaml") or {}
    return chart


# ---------------------------------------------------------------- facts / images / allowlist


def chart_ref(chart: Chart, registry: dict[str, Any]) -> str:
    repo = chart.manifest.get("publish", {}).get("chartRepo") or f"{registry['chartNamespace']}/{chart.name}"
    return f"oci://{registry['url']}/{repo}"


def render_facts(chart: Chart, mirror: dict[str, Any]) -> str:
    c = chart.manifest["chart"]
    d = chart.manifest.get("discovery", {})
    rows = [
        ("Upstream repository", code(c["repo"])),
        ("Upstream chart", code(c["name"])),
        ("Pinned version", code(chart.version)),
        (
            "App version",
            (code(chart.app_version) if chart.app_version else "—")
            + (" (chart default; tracked images below move independently)" if chart.tracked else ""),
        ),
        ("Version constraint", code(c.get("versionConstraint", "—"))),
        (
            "Lockstep group",
            f"{code(chart.lockstep)} — bumped together with its siblings" if chart.lockstep else "— (bumps alone)",
        ),
        ("Chart provenance", provenance(c.get("verifyUpstream"))),
        ("Discovery namespace", code(d.get("namespace", "default"))),
        ("Discovery kubeVersion", code(d.get("kubeVersion", "—"))),
    ]
    for registry in mirror.get("registries", []):
        ref = chart_ref(chart, registry)
        rows.append((f"Published chart ({registry['name']})", f"{code(ref)} (tag {code(chart.version)})"))

    links = [f"[Browse in the repository]({tree_link(chart.name)})"]
    if chart.chart_yaml.get("home"):
        links.append(f"[Project home]({chart.chart_yaml['home']})")
    for src in chart.chart_yaml.get("sources") or []:
        links.append(f"[{re.sub(r'^https?://', '', src).rstrip('/')}]({src})")

    out = []
    if chart.chart_yaml.get("description"):
        out.append(f"> {' '.join(str(chart.chart_yaml['description']).split())}\n")
    out.append("| Property | Value |\n| --- | --- |")
    out.extend(f"| {k} | {v} |" for k, v in rows)
    out.append("")
    out.append(" · ".join(links))
    return "\n".join(out) + "\n"


def short_digest(digest: str) -> str:
    algo, _, hexpart = digest.partition(":")
    return f"{algo}:{hexpart[:12]}…" if hexpart else digest


def match_rule(image: str, rules: list[dict[str, Any]]) -> dict[str, Any] | None:
    """First verifyUpstream rule whose glob matches the image (patchy semantics: first match wins)."""
    for rule in rules:
        pattern = "^" + re.escape(rule.get("match", "")).replace(r"\*", ".*") + "$"
        if re.match(pattern, image):
            return rule
    return None


def render_images(chart: Chart) -> str:
    images = chart.images
    if not images:
        return "This chart deploys no container images.\n"
    rules = chart.manifest.get("images", {}).get("verifyUpstream") or []
    tracked = {t["image"] for t in chart.tracked}
    extras = {e["image"]: e.get("reason", "") for e in chart.manifest.get("images", {}).get("extra") or []}
    extras.update({e["image"]: e.get("reason", "") for e in chart.extra})

    out = [
        "| Source image | Digest | Platforms | Provenance | Notes |",
        "| --- | --- | --- | --- | --- |",
    ]
    for img in images:
        source = img["source"]
        repo = source.split("@", 1)[0]
        repo = repo.rsplit(":", 1)[0] if ":" in repo.split("/")[-1] else repo
        notes = []
        if repo in tracked:
            notes.append("tracked on its own release train (`images.track`)")
        reason = next((r for e, r in extras.items() if e.split(":")[0] == repo), None)
        if reason is not None:
            notes.append(f"extra image: {reason}" if reason else "extra image")
        platforms = ", ".join(p.removeprefix("linux/") for p in img.get("platforms") or [])
        out.append(
            f'| {code(source)} | <span title="{img.get("digest", "")}">{code(short_digest(img.get("digest", "")))}'
            f"</span> | {cell(platforms) or '—'} | {provenance(match_rule(source, rules))} | "
            f"{cell('; '.join(notes)) or '—'} |"
        )

    targets: dict[str, list[str]] = {}
    for img in images:
        for reg, target in (img.get("targets") or {}).items():
            targets.setdefault(reg, []).append(target)
    out.append("")
    for reg, paths in targets.items():
        out.append(f'??? note "Mirror targets ({reg})"\n')
        out.append("    ```text")
        out.extend(f"    {p}" for p in paths)
        out.append("    ```\n")

    excludes = chart.manifest.get("images", {}).get("exclude") or []
    if excludes:
        out.append("Excluded from the mirror on purpose:\n")
        out.extend(f"- {code(e.get('pattern', e))}" for e in excludes)
        out.append("")
    return "\n".join(out) + "\n"


def render_allowlist(chart: Chart, today: date) -> str:
    vulns = chart.allowlist.get("vulnerabilities") or []
    if not vulns:
        return "No accepted findings: every blocking finding in the locked images is fixed.\n"
    expiries = sorted(str(v.get("expired_at", "")) for v in vulns)
    expired = sum(1 for e in expiries if e and e < today.isoformat())
    out = [
        (
            f"**{len(vulns)}** accepted finding{'s' if len(vulns) != 1 else ''}; "
            f"the earliest acceptance expires on **{expiries[0]}**.\n"
        ),
    ]
    if expired:
        out.append(
            f'!!! warning "{expired} acceptance{"s have" if expired != 1 else " has"} expired"\n\n'
            f"    As of {today.isoformat()}, when this site was built. Expired entries block `make validate` "
            "until the finding is fixed (usually by an update) or re-accepted in review.\n"
        )
    out += ["| Finding | Expires | Statement |", "| --- | --- | --- |"]
    for v in sorted(vulns, key=lambda v: (str(v.get("expired_at", "")), v.get("id", ""))):
        statement = cell(v.get("statement", ""))
        if v.get("notes"):
            statement += f"<br>*Notes:* {cell(v['notes'])}"
        when = str(v.get("expired_at", ""))
        if when and when < today.isoformat():
            when = f"**{when}** (expired)"
        out.append(f"| [{v['id']}]({osv_link(v['id'])}) | {when} | {statement} |")
    return "\n".join(out) + "\n"


# ---------------------------------------------------------------- values.yaml reference

KEY_RE = re.compile(
    r"""^(?P<indent>\s*)(?P<key>"[^"]*"|'[^']*'|[^\s#'"{}\[\],&*!|>%@`-][^:#]*?)\s*:(?:\s+(?P<rest>.*))?$"""
)
BLOCK_SCALAR_RE = re.compile(r"^[|>][-+0-9]*\s*(#.*)?$")
YAMLISH_RE = re.compile(r"""^(- )?["']?[a-z][\w./-]*["']?:( |$)""")
TYPE_HINT_RE = re.compile(r"^\((?P<type>[^)]+)\)\s*")
# Prose that happens to look like a YAML key ("ex: https://…", "ref: …").
PROSE_LEAD_RE = re.compile(r"^(ex|eg|e\.g|i\.e|ref|see|note|example|default):", re.IGNORECASE)
# The stock `helm create` header, which some charts leave glued to their first key.
BOILERPLATE_RE = re.compile(
    r"^(Default values for .*|This is a YAML-formatted file\.|Declare variables to be passed into your templates\.)$"
)


@dataclass
class Doc:
    description: str = ""
    type_hint: str = ""
    default: str = ""
    ignored: bool = False


def scan_comments(text: str) -> dict[tuple[str, ...], Doc]:
    """Map each key path in a values.yaml to the comment documenting it.

    Two conventions are in play across the vendored charts. helm-docs files
    (`# -- description`, `# @default -- …`, `# @ignored`, cilium's `# @schema`
    blocks) document only what carries a `# --` marker. Everything else uses
    a plain comment block directly above the key: a blank line breaks the
    association, commented-out YAML inside a block becomes a fenced example,
    and a block that is nothing but commented-out YAML is dropped.
    """
    helm_docs = re.search(r"^\s*# -- ", text, re.MULTILINE) is not None
    docs: dict[tuple[str, ...], Doc] = {}
    stack: list[tuple[int, tuple[str, ...]]] = []
    pending = Doc()
    # (is_yaml, text) per comment line; joined into a description at the key
    lines_: list[tuple[bool, str]] = []
    started = False
    in_schema = False
    block_indent: int | None = None

    def reset() -> None:
        nonlocal pending, lines_, started
        pending, lines_, started = Doc(), [], False

    def describe() -> str:
        if not helm_docs and not any(not y and t.strip() for y, t in lines_):
            return ""
        out: list[str] = []
        i = 0
        while i < len(lines_):
            if not lines_[i][0]:
                out.append(lines_[i][1])
                i += 1
                continue
            block = []
            while i < len(lines_) and lines_[i][0]:
                block.append(lines_[i][1])
                i += 1
            pad = min(len(b) - len(b.lstrip()) for b in block)
            out += ["", "```yaml", *(b[pad:] for b in block), "```", ""]
        return "\n".join(out).strip()

    for raw in text.splitlines():
        stripped = raw.strip()
        indent = len(raw) - len(raw.lstrip(" "))

        if block_indent is not None:
            if not stripped or indent > block_indent:
                continue
            block_indent = None

        if not stripped:
            if not in_schema:
                reset()
            continue

        if stripped.startswith("#"):
            body = stripped.lstrip("#")
            content = body.removeprefix(" ")
            if content.strip() == "@schema":
                in_schema = not in_schema
                continue
            if in_schema:
                continue
            if helm_docs:
                if content.startswith("-- ") or content == "--":
                    lines_, started = [(False, content[3:])], True
                elif content.startswith("@default -- "):
                    pending.default = content[len("@default -- ") :].strip()
                elif content.startswith("@ignore"):
                    pending.ignored = True
                elif started and not content.startswith("@"):
                    lines_.append((False, content))
                continue
            if content.startswith("+docs:") or BOILERPLATE_RE.match(content.strip()):
                continue
            lead = content.lstrip()
            is_yaml = bool(YAMLISH_RE.match(lead) and not PROSE_LEAD_RE.match(lead)) or (
                lead.startswith("- ") and len(content) - len(lead) >= 1
            )
            lines_.append((is_yaml, content))
            continue

        if stripped.startswith("- ") or stripped == "-":
            reset()
            continue

        m = KEY_RE.match(raw)
        if not m:
            reset()
            continue
        key = m.group("key").strip()
        if key[:1] in "\"'":
            key = key[1:-1]
        while stack and stack[-1][0] >= indent:
            stack.pop()
        path = (stack[-1][1] if stack else ()) + (key,)
        desc = describe()
        if key != "<<" and (desc or pending.default or pending.ignored):
            hint = TYPE_HINT_RE.match(desc)
            if hint:
                pending.type_hint = hint.group("type")
                desc = desc[hint.end() :]
            pending.description = desc
            docs[path] = pending
        reset()
        rest = (m.group("rest") or "").strip()
        if rest and BLOCK_SCALAR_RE.match(rest):
            block_indent = indent
        stack.append((indent, path))
    return docs


def type_of(value: Any) -> str:
    if value is None:
        return "null"
    if isinstance(value, bool):
        return "bool"
    if isinstance(value, int):
        return "int"
    if isinstance(value, float):
        return "float"
    if isinstance(value, str):
        return "string"
    if isinstance(value, list):
        return "list"
    if isinstance(value, dict):
        return "object"
    return type(value).__name__


def fmt_default(value: Any) -> str:
    text = json.dumps(value, default=str, ensure_ascii=False)
    if len(text) > MAX_DEFAULT:
        text = text[:MAX_DEFAULT] + " …"
    return text


def fmt_key(path: tuple[str, ...]) -> str:
    return ".".join(f'"{k}"' if re.search(r"[^\w-]", k) else k for k in path)


def anchor(path: tuple[str, ...]) -> str:
    return "v-" + re.sub(r"[^A-Za-z0-9_.-]+", "-", ".".join(path)).strip("-")


_MD = markdown.Markdown(extensions=["fenced_code", "sane_lists"])
_CODE_SPLIT = re.compile(r"(`+)(.*?)\1", re.DOTALL)


_HREF_RE = re.compile(r'href="(?![a-z][a-z0-9+.-]*:|#|/)([^"]*)"', re.IGNORECASE)


def md_to_html(text: str, base: str = "") -> str:
    """Render a values.yaml comment as inline-safe HTML for a table cell.

    Relative links in upstream comments ("see [values.yaml](values.yaml)")
    point into the chart's own tree, so they're rewritten against `base`, the
    vendored chart directory on GitHub, instead of resolving against this site.
    """
    if not text:
        return ""
    parts, pos = [], 0
    for m in _CODE_SPLIT.finditer(text):
        parts.append(re.sub(r"<(?!https?://)", "&lt;", text[pos : m.start()]))
        parts.append(m.group(0))
        pos = m.end()
    parts.append(re.sub(r"<(?!https?://)", "&lt;", text[pos:]))
    rendered = _MD.reset().convert("".join(parts))
    if base:
        rendered = _HREF_RE.sub(lambda m: f'href="{base}/{m.group(1)}"', rendered)
    if "<pre" in rendered:
        return re.sub(r"\n\s*\n", "\n", rendered)
    return rendered.replace("\n", " ")


@dataclass
class Row:
    path: tuple[str, ...]
    type: str
    default: str
    description: str


def walk(data: Any, docs: dict[tuple[str, ...], Doc], path: tuple[str, ...] = ()) -> list[Row]:
    rows: list[Row] = []
    if not isinstance(data, dict):
        return rows
    for key, value in data.items():
        p = path + (str(key),)
        doc = docs.get(p, Doc())
        if doc.ignored:
            continue
        branch = isinstance(value, dict) and value
        if not branch or doc.description:
            rows.append(
                Row(
                    p,
                    doc.type_hint or type_of(value),
                    doc.default or fmt_default(value),
                    doc.description,
                )
            )
        if branch:
            rows.extend(walk(value, docs, p))
    return rows


def render_table(rows: list[Row], base: str) -> str:
    out = [
        '<div class="md-typeset__scrollwrap"><div class="md-typeset__table"><table class="fc-values">',
        "<thead><tr><th>Key</th><th>Type</th><th>Default</th><th>Description</th></tr></thead>",
        "<tbody>",
    ]
    for r in rows:
        a = anchor(r.path)
        out.append(
            f'<tr id="{a}"><td><a href="#{a}"><code>{html.escape(fmt_key(r.path))}</code></a></td>'
            f"<td>{html.escape(r.type)}</td>"
            f"<td><code>{html.escape(r.default)}</code></td>"
            f"<td>{md_to_html(r.description, base)}</td></tr>"
        )
    out.append("</tbody></table></div></div>")
    return "\n".join(out)


def render_values(chart: Chart) -> str:
    values_path = chart.vendor_dir / "values.yaml"
    text = values_path.read_text(encoding="utf-8")
    data = yaml.safe_load(text) or {}
    docs = scan_comments(text)
    rows = walk(data, docs)

    rel = values_path.relative_to(chart.root).as_posix()
    base = blob_link(chart.name, chart.vendor_dir.relative_to(chart.root).as_posix())
    out = [
        (
            f"These are the defaults of the vendored chart ({len(rows)} keys), read from "
            f"[`{rel}`]({blob_link(chart.name, rel)}) when this site was built. Descriptions are upstream's own comments."
        )
    ]
    if (chart.vendor_dir / "values.schema.json").is_file():
        schema_rel = f"vendor/{chart.manifest['chart']['name']}/values.schema.json"
        out.append(
            f"The chart also ships a [JSON schema]({blob_link(chart.name, schema_rel)}) that helm validates values against."
        )
    out.append("")

    top: list[Row] = []
    sections: list[tuple[str, Row | None, list[Row]]] = []
    for r in rows:
        if len(r.path) == 1 and not (isinstance(data.get(r.path[0]), dict) and data.get(r.path[0])):
            top.append(r)
            continue
        if len(r.path) == 1:
            sections.append((r.path[0], r, []))
            continue
        if not sections or sections[-1][0] != r.path[0]:
            sections.append((r.path[0], None, []))
        sections[-1][2].append(r)

    if top:
        out.append("### Top-level values { #values-top-level }\n")
        out.append(render_table(top, base) + "\n")
    for key, head, children in sections:
        slug = re.sub(r"[^A-Za-z0-9_-]+", "-", key).strip("-")
        out.append(f"### `{key}` {{ #values-{slug} }}\n")
        if head and head.description:
            out.append(md_to_html(head.description, base) + "\n")
        if children:
            out.append(render_table(children, base) + "\n")
    return "\n".join(out)


# ---------------------------------------------------------------- index


def render_index(charts: list[Chart], today: date) -> str:
    out = [
        "| Chart | Version | App version | Images | Lockstep | Chart provenance | Accepted findings |",
        "| --- | --- | --- | --- | --- | --- | --- |",
    ]
    for c in charts:
        rule = c.manifest["chart"].get("verifyUpstream") or {}
        prov = "unverified" if rule.get("provider", "none") == "none" else rule["provider"]
        vulns = c.allowlist.get("vulnerabilities") or []
        findings = str(len(vulns))
        expired = sum(1 for v in vulns if str(v.get("expired_at", "")) < today.isoformat())
        if expired:
            findings += f" (**{expired} expired**)"
        out.append(
            f"| [{c.name}]({c.name}.md) | {code(c.version)} | {code(c.app_version) if c.app_version else '—'} | "
            f"{len(c.images)} | {code(c.lockstep) if c.lockstep else '—'} | {prov} | {findings} |"
        )
    return "\n".join(out) + "\n"


# ---------------------------------------------------------------- main


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("--root", type=Path, default=Path("."), help="repository root (default: .)")
    parser.add_argument("--out", type=Path, default=Path("build/chart-docs"), help="output directory")
    args = parser.parse_args(argv)

    mirror = load_yaml(args.root / "mirror.yaml")
    charts = [load_chart(p.parent) for p in sorted((args.root / "charts").glob("*/manifest.yaml"))]
    today = date.today()

    if args.out.exists():
        shutil.rmtree(args.out)
    args.out.mkdir(parents=True)
    (args.out / "index.md").write_text(render_index(charts, today), encoding="utf-8")
    for c in charts:
        d = args.out / c.name
        d.mkdir()
        (d / "facts.md").write_text(render_facts(c, mirror), encoding="utf-8")
        (d / "images.md").write_text(render_images(c), encoding="utf-8")
        (d / "allowlist.md").write_text(render_allowlist(c, today), encoding="utf-8")
        (d / "values.md").write_text(render_values(c), encoding="utf-8")
    print(f"chart-docs: wrote {len(charts)} chart references to {args.out}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
