#!/usr/bin/env bash
# Copyright 2026 BitWise Media Group Ltd
# SPDX-License-Identifier: MIT

# Shared helpers for the chart pipeline scripts. Source, don't execute.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GLOBAL_CONFIG="$ROOT/config/global.yaml"

# The pinned toolchain (root mise.toml + mise.lock) is on PATH when scripts run
# through their mise tasks (`make <target>` forwards there). Direct invocations
# use whatever the shell provides; the `need` checks below catch missing tools.
log() { printf '>> %s\n' "$*" >&2; }
warn() { printf 'warning: %s\n' "$*" >&2; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }

need() {
  local tool
  for tool in "$@"; do
    command -v "$tool" >/dev/null || die "required tool not found: $tool"
  done
}

global() { # global <yq-expr> — errors when the value is missing
  yq -e "$1" "$GLOBAL_CONFIG"
}

chart_dir() { echo "$ROOT/charts/$1"; }

manifest_path() {
  local m="$ROOT/charts/$1/manifest.yaml"
  [[ -f "$m" ]] || die "no manifest for chart '$1' (expected $m)"
  echo "$m"
}

manifest() { # manifest <chart> <yq-expr> — errors when the value is missing
  yq -e "$2" "$(manifest_path "$1")"
}

manifest_or() { # manifest_or <chart> <yq-expr> <default>
  local v
  v="$(yq "$2 // \"\"" "$(manifest_path "$1")")"
  [[ -n "$v" ]] && echo "$v" || echo "$3"
}

lock_path() { echo "$ROOT/charts/$1/images.lock.yaml"; }

# Expand shorthand image references the way container runtimes do.
normalize_image() {
  local ref="$1" first path
  if [[ "$ref" != */* ]]; then
    echo "docker.io/library/$ref"
    return
  fi
  first="${ref%%/*}"
  if [[ "$first" != *.* && "$first" != *:* && "$first" != "localhost" ]]; then
    ref="docker.io/$ref"
  fi
  if [[ "$ref" == docker.io/* ]]; then
    path="${ref#docker.io/}"
    [[ "$path" == */* ]] || ref="docker.io/library/$path"
  fi
  echo "$ref"
}

# Rewrite an upstream pull through the platform pull-through cache when configured.
# Only affects where CI pulls FROM; recorded sources and publish targets keep the canonical name.
rewrite_source() {
  local ref="$1" host rest target
  host="${ref%%/*}"
  rest="${ref#*/}"
  target="$(yq ".sourceRegistryRewrites[\"$host\"] // \"\"" "$GLOBAL_CONFIG")"
  if [[ -n "$target" ]]; then
    echo "$target/$rest"
  else
    echo "$ref"
  fi
}

# Glob match helper for image patterns like "ghcr.io/fluxcd/*".
glob_match() { # glob_match <pattern> <value>
  # shellcheck disable=SC2254 # intentional glob expansion of the pattern
  case "$2" in
    $1) return 0 ;;
    *) return 1 ;;
  esac
}

# Minimal semver range check supporting space-separated bounds: ">=1.2.3 <2.0.0 !=1.5.0".
# Pre-release versions are rejected outright; we only ship releases.
semver_in_range() { # semver_in_range <version> <range>
  local v="$1" range="$2" bound op rhs
  [[ "$v" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || return 1
  for bound in $range; do
    if [[ "$bound" =~ ^(\>=|\<=|!=|\>|\<|=)([0-9]+\.[0-9]+\.[0-9]+)$ ]]; then
      op="${BASH_REMATCH[1]}"
      rhs="${BASH_REMATCH[2]}"
    else
      die "unsupported version constraint: '$bound'"
    fi
    case "$op" in
      "=") [[ "$v" == "$rhs" ]] || return 1 ;;
      "!=") [[ "$v" != "$rhs" ]] || return 1 ;;
      ">=") [[ "$(printf '%s\n%s\n' "$rhs" "$v" | sort -V | head -1)" == "$rhs" ]] || return 1 ;;
      "<=") [[ "$(printf '%s\n%s\n' "$v" "$rhs" | sort -V | head -1)" == "$v" ]] || return 1 ;;
      ">") [[ "$v" != "$rhs" && "$(printf '%s\n%s\n' "$rhs" "$v" | sort -V | head -1)" == "$rhs" ]] || return 1 ;;
      "<") [[ "$v" != "$rhs" && "$(printf '%s\n%s\n' "$v" "$rhs" | sort -V | head -1)" == "$v" ]] || return 1 ;;
    esac
  done
  return 0
}

# Parse an RFC3339 timestamp (registries emit fractional seconds and a Z) into a unix
# epoch. BSD and GNU date take incompatible flags, so try both — same posture as the
# expiry parsing in lint-manifests.sh.
epoch_of_rfc3339() { # epoch_of_rfc3339 <timestamp>
  local ts="${1%%.*}"
  ts="${ts%Z}"
  TZ=UTC date -j -f '%Y-%m-%dT%H:%M:%S' "$ts" +%s 2>/dev/null ||
    date -u -d "${ts}Z" +%s 2>/dev/null ||
    die "unparseable timestamp: '$1'"
}

# Pull the pinned upstream chart tgz into a directory; prints the tgz path.
pull_chart_tgz() { # pull_chart_tgz <chart> <destdir>
  local chart="$1" dest="$2" repo name version
  repo="$(manifest "$chart" '.chart.repo')"
  name="$(manifest "$chart" '.chart.name')"
  version="$(manifest "$chart" '.chart.version')"
  if [[ "$repo" == oci://* ]]; then
    helm pull "$repo/$name" --version "$version" --destination "$dest" >&2
  else
    helm pull "$name" --repo "$repo" --version "$version" --destination "$dest" >&2
  fi
  local tgz="$dest/$name-$version.tgz"
  [[ -f "$tgz" ]] || die "helm pull did not produce $tgz"
  echo "$tgz"
}

sha256_of() {
  shasum -a 256 "$1" 2>/dev/null | awk '{print $1}' || sha256sum "$1" | awk '{print $1}'
}
