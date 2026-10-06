# Copyright 2026 BitWise Media Group Ltd
# SPDX-License-Identifier: MIT
#
# flux-containers — supply-chain pipeline for the patchy platform: vendors
# pinned upstream helm charts, discovers and digest-pins their images, verifies
# upstream provenance, scans everything, and publishes charts + images to the
# platform Artifact Registry with keyless cosign signatures.
#
# Everything lives in mise tasks: the shared toolchain submodule at .mise/
# provides the pinned tools + the common-only lint contract (selected in the
# root mise.toml), and tasks.toml carries the pipeline surface. This Makefile
# is only the thin forwarding shim —
# `make <task> CHART=<name>` == `CHART=<name> mise run <task>`.
export CHART
include .mise/common/include.mk
