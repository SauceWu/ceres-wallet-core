#!/usr/bin/env bash
# Phase 6, Plan 04 — local release-mode FFI smoke test runner.
# Per .planning/phases/06-ffi-hardening-test-fixtures/06-CONTEXT.md (D-10):
#   "在 tool/ 加 tool/run_release_tests.sh：跑 flutter test --release test/release_mode_smoke_test.dart.
#    CI 后续可在 P13 接入；本阶段只验证脚本本地能跑通。"
#
# Usage:
#   tool/run_release_tests.sh
#
# Exit code:
#   0 if release-mode smoke test passes
#   non-zero on any failure
#
# CI integration is DEFERRED to Phase 13 per CONTEXT.md deferred ideas.
# This script is a developer-local quick-check.
set -euo pipefail

# Resolve repo root (script lives at tool/run_release_tests.sh).
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${REPO_ROOT}"

if ! command -v flutter >/dev/null 2>&1; then
  echo "error: flutter CLI not found on PATH" >&2
  exit 127
fi

echo "[run_release_tests] cwd: $(pwd)"
echo "[run_release_tests] flutter: $(flutter --version | head -n 1)"
echo "[run_release_tests] running: flutter test --release test/release_mode_smoke_test.dart"

flutter test --release test/release_mode_smoke_test.dart
