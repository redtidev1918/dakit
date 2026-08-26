# Architecture and Extension Boundaries

DAKit provides a layered SDK for third-party Flutter clients. The common layer describes stable domain capabilities; login, HTTP, platform plugins, and example UI each sit at replaceable implementation boundaries.

## Dependency Structure

```text
Host app / example_client
          │
          ├─────────────── Custom UI, state, cache, database
          │
          ▼
    dakit_flutter ─────── System browser, deep links, secure storage, background tasks
          │
          ▼
      dakit_api ───────── OAuth, network policy, official API adapters
          │
          ▼
     dakit_core ───────── Models, errors, repositories, diagnostics, transfer contracts

    dakit_cli ─────────── Pure-Dart CLI kit (depends on api/core, not Flutter)
```

`dakit_core` does not depend on Flutter or networking libraries; `dakit_api` uses only Dart capabilities; `dakit_flutter` is the layer that depends on platform plugins; `dakit_cli` is a pure-Dart debugging and batch-download tool. Dependencies point only downward; the domain layer never references implementation layers.

## Responsibilities of Each Layer

### `dakit_core`

- Stable domain models and pagination values;
- Repository interfaces for accounts, user profiles, deviations, the discovery feed, galleries, deviation content, media, comments, and social actions;
- `AuthTokenProvider`, token/pending store interfaces;
- `TransferManager` and task snapshots;
- `DAKitException`, failure classification, and sanitized diagnostic events.

This layer is suited to domain tests, offline cache wrappers, and non-Flutter Dart clients.

### `dakit_api`

- PKCE transactions, callback validation, token exchange/refresh/revoke;
- Replaceable OAuth endpoint and official API transport;
- Environments, direct connections, explicit HTTP proxy, and Dio injection;
- Currently implemented repositories for accounts, user profiles and watch relationships, bulk user lookup, deviations, deviation content, home/search, daily deviations, watch feed, tag/topic navigation, gallery/collection folders and contents, original files, comments, social actions, and the message center;
- Private mapping from upstream JSON to stable domain models.

DTOs are not exported from the top-level library. Unknown fields newly added by official responses must not break parsing; missing required fields must throw a clear parsing failure.

`OfficialApiTransport` provides the read extension point, and `OfficialApiMutationTransport` additionally provides unified URL-encoded POST. GETs retry 429/500/503 with configured backoff; non-idempotent POSTs only refresh the token once after a 401 and never auto-retry a write that may already have taken effect.

### `dakit_flutter`

- `DAKitOAuthClient` composes the common login lifecycle;
- System browser, `app_links`, `flutter_secure_storage` adapters;
- `BackgroundTransferManager` platform background-transfer implementation.

It provides no pages, theming, or state-management dependencies. Hosts can replace each interface without forking.

### `example_client`

This is a runnable integration probe: it verifies platform callbacks, network diagnostics, account/browsing, original file parsing, and task resume. It is not SDK public API, nor a recommended production architecture.

It uses `ClientRuntime` as a composition root that assembles OAuth, transport, repositories, connectivity, and transfer tasks before injecting them into controllers; `main.dart` only selects and starts the UI, avoiding scattered construction code. Pages also expose a `DebugConsole` at the bottom that calls controller capabilities via `runConsoleCommand`, making it easy to troubleshoot problems inside the UI.

### `dakit_cli`

The command-line kit targets developer debugging, batch downloads, and scripted use. It is split by module:

- `cli.dart`: command parsing and dispatch;
- `cli_session.dart`: file token/config stores, refreshing sessions, `CliContext`;
- `cli_networking.dart`: proxy parsing, streaming downloader, UUID/filename utilities;
- `cli_platform.dart`: system browser, loopback/paste callback;
- `cli_diagnostics.dart`: `--verbose` diagnostic output;
- `cli_url.dart`: DeviantArt link parsing and target auto-detection
  (`parseCliUrl`).

The CLI uses no Flutter plugins and compiles to self-contained native binaries
for direct end-user download. Like `dakit_flutter`, it signs in through the
system browser and never receives the user's password. macOS signing status must
remain explicit in asset names and release notes.

## Decoupling Approaches

| Host need | Extension point |
| --- | --- |
| Existing account system | Implement `AuthTokenProvider`, construct `OfficialApiClient` directly |
| Custom Keychain/Keystore | Implement `TokenStore`, `PendingAuthorizationStore` |
| Enterprise PAC, VPN, certificate pinning | Inject a preconfigured Dio instead of passing `NetworkProfile` |
| Custom browser or HTTPS callback | Implement `ExternalUriLauncher`, `CallbackUriSource` |
| Local cache / offline-first | Wrap repository interfaces, keeping domain models unchanged |
| Different background task framework | Implement `TransferManager` |
| Riverpod/Bloc/Redux | Bind repositories only in the host layer; they never enter the SDK |

## Upstream Change Strategy

"Automatically adapting to every website update" is not a verifiable promise. The stable approach is to shrink the surface of change:

1. Prefer the versioned official API;
2. Centralize the API version header, base URI, and retry policy;
3. Keep upstream DTOs private and map them to SDK models;
4. Accept newly added fields, and produce diagnosable failures for missing required fields;
5. Use contract tests with fixtures derived from official schemas;
6. Use optional real-service tests to detect authorization, policy, and schema drift;
7. If a web-compatibility layer is added in the future, it must be an independent optional adapter and must not pollute the official API package;
8. Parse volatile response sub-bundles tolerantly: degrade to empty on shape drift
   (e.g. the collection groups in `morelikethis/preview`), so secondary data never
   takes down the primary content; contract tests surface the drift.

## Security Boundaries

- Log in only through the external system browser; never auto-fill credentials or bypass verification;
- Public Clients neither receive nor store `client_secret`;
- TLS verification cannot be disabled through the DAKit public API;
- Provider HTML/Markdown/CSS is inert data; hosts sanitize it before rendering;
- Diagnostics log only safe fields, and transfer tasks never carry bearer tokens;
- Ordinary CI has no account credentials, proxy passwords, or signing keys.

## Versioning and New Features

The three packages are released independently under semantic versioning. When adding capabilities such as notifications, messages, or submitting deviations, first add the minimal domain contract in core, then implement the official adapter in api, and finally verify platform interaction in Flutter/example. Never call an unwrapped endpoint directly from page components.
