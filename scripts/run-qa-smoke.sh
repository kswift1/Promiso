#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

usage() {
  cat <<'EOF'
Usage:
  ./scripts/run-qa-smoke.sh build
  ./scripts/run-qa-smoke.sh test

Optional env:
  PROMISO_BASE_BRANCH=<git ref>

Default base branch resolution:
  1. origin/release/v1.3.1
  2. release/v1.3.1
  3. origin/main
EOF
}

resolve_base_branch() {
  if [ -n "${PROMISO_BASE_BRANCH:-}" ]; then
    echo "$PROMISO_BASE_BRANCH"
    return 0
  fi

  local candidate
  for candidate in origin/release/v1.3.1 release/v1.3.1 origin/main; do
    if git rev-parse --verify --quiet "$candidate" >/dev/null; then
      echo "$candidate"
      return 0
    fi
  done

  echo "Could not resolve a base branch. Set PROMISO_BASE_BRANCH explicitly." >&2
  return 1
}

MODE="${1:-}"
if [ -z "$MODE" ] || [ "$MODE" = "--help" ] || [ "$MODE" = "-h" ]; then
  usage
  exit 0
fi

case "$MODE" in
  build)
    CHECK_MODE="build"
    ;;
  test)
    CHECK_MODE="test"
    ;;
  *)
    echo "Unknown mode: $MODE" >&2
    usage
    exit 1
    ;;
esac

BASE_BRANCH="$(resolve_base_branch)"

echo "QA smoke mode: $CHECK_MODE"
echo "Base branch: $BASE_BRANCH"
echo ""

PROMISO_CHECK_MODE="$CHECK_MODE" \
PROMISO_BASE_BRANCH="$BASE_BRANCH" \
./scripts/run-changed-tests.sh
