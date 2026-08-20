# ADR 0001: Flutter and Dart are the primary runtime

- Status: accepted
- Date: 2026-08-20

## Context

The project must serve as the base of an Android client, support macOS and Windows,
and be consumable as a dependency by applications similar to PixEz. The Python
preview required custom browser automation and could not be embedded into an APK.

## Decision

Use pure Dart packages for domain and HTTP functionality, a Flutter package for
platform integrations, and a Flutter example application for end-to-end tests.

Do not introduce Rust FFI or Kotlin Multiplatform initially. A native cross-language
core can be reconsidered when a concrete Kotlin, Swift, or other non-Flutter consumer
justifies its build and binding cost.

## Consequences

- Flutter clients get a direct package dependency and one debugging environment.
- Android, macOS, and Windows share most code and behavior.
- Non-Flutter applications do not receive a native SDK in the first release.
- Platform plugins remain behind interfaces so they can be replaced or federated.
- The project must maintain platform build CI in addition to Dart unit tests.

