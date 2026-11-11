# Copyright 2026 BitWise Media Group Ltd
# SPDX-License-Identifier: MIT
#
# flux-containers — supply-chain pipeline for the patchy platform: vendors
# pinned upstream helm charts, discovers and digest-pins their images, verifies
# upstream provenance, scans everything, and publishes charts + images to the
# platform Artifact Registry with keyless cosign signatures.
#
# Everything lives in mise tasks: the shared toolchain submodule at .mise/
# provides the pinned tools, the common lint contract and the containers
# archetype's mirror-* tasks (selected in the root mise.toml), and tasks.toml
# adds the docs site. This Makefile is only the thin forwarding shim —
# `make mirror-upgrade ENTRY=<name>` == `ENTRY=<name> mise run mirror-upgrade`.
include .mise/archetypes/containers/include.mk
