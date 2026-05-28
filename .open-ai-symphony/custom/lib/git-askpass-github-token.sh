#!/usr/bin/env bash
set -euo pipefail

# Git prompts this helper for noninteractive HTTPS auth.
case "${1:-}" in
  *Username*)
    printf '%s\n' "${GITHUB_USERNAME:-x-access-token}"
    ;;
  *Password*)
    printf '%s\n' "${GH_TOKEN:-${GITHUB_TOKEN:-}}"
    ;;
  *)
    printf '\n'
    ;;
esac
