#!/usr/bin/env bash
set -euo pipefail

case "${1:-}" in
  *Username*)
    printf '%s\n' "x-access-token"
    ;;
  *Password*)
    printf '%s\n' "${HARNESS_GITHUB_TOKEN:-}"
    ;;
  *)
    printf '\n'
    ;;
esac
