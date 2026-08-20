#!/usr/bin/env sh
set -eu

if ! command -v flutter >/dev/null 2>&1; then
  echo 'Flutter is required. See docs/DEVELOPMENT.md.' >&2
  exit 1
fi

dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test \
  packages/artrelay_core/test \
  packages/artrelay_api/test \
  packages/artrelay_flutter/test \
  apps/example_client/test
