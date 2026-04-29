#!/usr/bin/env bash
# Phase 6, Plan 04 — local FFI smoke test runner.
#
# IMPORTANT — Flutter mode caveat:
#   Flutter has NO host-side release-mode unit test CLI affordance. `flutter test`
#   runs against the host Dart VM in JIT only — there is no `--release` / `--profile`
#   flag for `flutter test` (verified against Flutter 3.38.7; `flutter test --help`
#   does not list any mode switch). The keepAlive idiom (Plan 06-03) is therefore
#   verified under JIT here, which is the highest-fidelity mode `flutter test`
#   supports. Empirical AOT / release-mode escape-analysis verification is
#   DEFERRED to a future phase via `integration_test/` + `flutter drive` against
#   a booted device (which builds AOT). The JIT smoke test still proves that
#   the keepAlive call site compiles, links, and runs alongside Plan 02's
#   fixture loader — providing the canonical idiom P7 / P11 will copy verbatim.
#
# Per .planning/phases/06-ffi-hardening-test-fixtures/06-CONTEXT.md (D-10):
#   "在 tool/ 加 tool/run_release_tests.sh：跑 flutter test test/release_mode_smoke_test.dart.
#    CI 后续可在 P13 接入；本阶段只验证脚本本地能跑通。"
#   (Original D-10 wording said `--release`; Phase 6 retro confirmed Flutter
#    does not support that flag and revised the criterion to JIT-mode invocation
#    with AOT verification deferred to a future integration_test plan.)
#
# Usage:
#   tool/run_release_tests.sh
#
# Exit code:
#   0 if smoke test passes
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
echo "[run_release_tests] running: flutter test test/release_mode_smoke_test.dart"

flutter test test/release_mode_smoke_test.dart
