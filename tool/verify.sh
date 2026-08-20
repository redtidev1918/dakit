#!/usr/bin/env sh
set -eu

if ! command -v flutter >/dev/null 2>&1; then
  echo 'Flutter is required. See docs/DEVELOPMENT.md.' >&2
  exit 1
fi

dart pub get
dart run melos run format
dart run melos run analyze
dart run melos run test
