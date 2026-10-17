#!/usr/bin/env bash
# sorry_lint.sh — thin shim; implementation in sorry_lint.py (comment-aware
# sorry-tag linting is too fiddly for portable bash).
exec python3 "$(dirname "$0")/sorry_lint.py" "$@"
