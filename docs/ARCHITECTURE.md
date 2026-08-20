# ArtRelay architecture

ArtRelay is a reusable client SDK, not a downloader application. Its primary
consumer is a Flutter application, while the domain and HTTP packages remain
usable from standalone Dart programs.

## Goals

- Build Android, macOS, and Windows clients from one maintained codebase.
- Let host applications own their UI, navigation, state management, and database.
- Implement OAuth 2.1 Authorization Code with PKCE for public clients.
- Expose browsing, account, gallery, collection, publishing, and media workflows.
- Support foreground streaming and platform-managed background transfers.
- Produce structured, redacted diagnostics for network and authentication failures.
- Isolate upstream API changes behind adapters and contract tests.

## Non-goals

- Automating a browser or bypassing human verification.
- Storing a client secret in a mobile or desktop application.
- Silently disabling TLS verification.
- Promising that website scraping will survive arbitrary website changes.
- Coupling the SDK to Riverpod, Bloc, a widget library, or a concrete database.

## Package boundaries

```text
packages/
  artrelay_core/       Domain models, errors, repositories, pagination, diagnostics
  artrelay_api/        OAuth token exchange and official API adapter
  artrelay_flutter/    Browser, deep-link, secure-storage, and transfer integrations
apps/
  example_client/      Executable integration and platform smoke tests
```

Dependency direction:

```text
example_client -> artrelay_flutter -> artrelay_api -> artrelay_core
                              \---------------------> artrelay_core
```

`artrelay_core` must not import Flutter. `artrelay_api` may depend on Dart-only
packages such as Dio and crypto, but not on platform plugins. Platform behavior
is supplied through interfaces owned by the core or API layer.

## Authentication

The SDK uses an external system browser and a registered custom URI callback.
The public client identifier and redirect URI are supplied by the host app.

1. Generate a cryptographically random state and PKCE verifier.
2. Persist the pending transaction until the callback or timeout.
3. Launch the authorization URL in the system browser.
4. Receive the custom-scheme callback from the operating system.
5. Validate scheme, path, state, error parameters, and transaction age.
6. Exchange the code with the original verifier, without a client secret.
7. Store tokens through the host-provided secure token store.
8. Refresh once under a mutex so concurrent 401 responses do not race.

Browser automation, clipboard polling, and embedded login WebViews are forbidden.

## Networking and proxy behavior

The API package exposes an explicit transport profile. Supported modes are Dart
proxy-environment discovery, forced direct, an explicit HTTP proxy, and a
host-provided Dio transport. The environment mode reads documented process
variables; it does not pretend to discover every operating-system PAC setting.
API and media traffic can use separate profiles.

Diagnostics record stages such as DNS, connect, TLS, HTTP, OAuth callback, token
exchange, parsing, and storage. Tokens, authorization codes, cookies, and query
parameters known to contain credentials are always redacted.

## Media transfers

The core represents a media asset independently from the way it is transferred.
Flutter hosts use a native-scheduler-backed implementation with persisted recovery,
progress, retry, pause, resume, and cancellation. No fixed chunk size is part of
the public API.

The SDK distinguishes preview, original, downloadable attachment, video, archive,
document, literature, login-required, purchase-required, restricted, unavailable,
and missing assets. It never reports a preview as the original file. Expected
provider denials resolve to non-transferable media values; transport and schema
failures remain observable exceptions.

Structured text on deviation detail and rendered literature from
`deviation/content` are separate from byte transfers. HTML, CSS, and original
markup are modeled as inert data; the SDK does not create an embedded browser or
silently execute provider content.

Transfer task headers do not contain access tokens. The official media repository
resolves an HTTPS original URL first, then the transfer adapter persists only the
task metadata needed by the platform scheduler.

## Upstream compatibility

- Send the documented API minor-version header from one central interceptor.
- Map upstream DTOs into stable domain models.
- Accept unknown JSON fields and model documented optional fields as nullable.
- Keep website-derived metadata in an optional adapter, separate from official API DTOs.
- Run fixture tests and opt-in live contract tests against representative endpoints.
- Treat authentication or schema drift as typed failures with actionable diagnostics.

`OfficialApiClient` depends on the core `AuthTokenProvider` contract rather than a
concrete OAuth session. A host may therefore reuse the transport with ArtRelay's
secure OAuth lifecycle, an existing account subsystem, or an ephemeral live-test
token without importing persistence or browser behavior.

## Versioning

Packages use semantic versioning. Public API removals require a major release.
Generated or upstream DTOs are not exported from the top-level core library.
