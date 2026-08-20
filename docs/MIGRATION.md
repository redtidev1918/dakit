# Rewrite plan

The Python preview is archived by the Git tag `python-preview-1.0.0a1`. The main
branch is being replaced by a Dart/Flutter workspace. No Python compatibility is
promised after the rewrite.

## Milestones

### M0 — recoverable baseline

- [x] Verify a clean worktree and remote.
- [x] Tag and push the Python preview.
- [x] Record architecture, boundaries, risks, and continuation instructions.
- [x] Install and pin Flutter 3.47.1 / Dart 3.13.1.
- [x] Create the workspace and first green test suite.

### M1 — core and official API

- [ ] Stable domain models and typed failures.
- [ ] Repository, pagination, clock, transport, and diagnostic interfaces.
- [ ] Dio transport with timeouts, cancellation, redaction, and API versioning.
- [ ] OAuth PKCE transaction creation, callback validation, refresh, and logout.
- [ ] Official API DTO mapping and fixture tests.

### M2 — platform integration

- [ ] External browser launcher.
- [ ] Android, macOS, and Windows custom-scheme callbacks.
- [ ] Secure token storage.
- [ ] Background transfer adapter and task recovery.
- [ ] Proxy configuration and staged connectivity diagnostics.

### M3 — example client and live verification

- [ ] Minimal login/account/browse/detail UI.
- [ ] Download representative image, video, archive, literature, and restricted cases.
- [ ] Android debug APK smoke test.
- [ ] macOS smoke test.
- [ ] Windows CI build and smoke-test harness.

### M4 — release

- [ ] API documentation and integration guides.
- [ ] GitHub Actions quality and platform build matrix.
- [ ] Package publication dry run.
- [ ] Rename the remote repository only after package names and links are final.
- [x] Remove every obsolete Python file from main.

## Acceptance criteria

The rewrite is complete only when:

1. `dart analyze` and all unit tests pass without warnings.
2. The example client receives its OAuth callback automatically and restores a session.
3. Refresh is race-free and secrets never appear in logs.
4. API and media proxy settings are independently testable.
5. Failed DNS, TLS, callback, token, HTTP, parsing, storage, and transfer stages are distinguishable.
6. An Android APK builds and completes the documented smoke test.
7. macOS builds locally and Windows builds in CI.
8. A new Flutter app can consume the SDK using only documented public APIs.

## Migration rules

- Keep each milestone buildable and commit it before starting the next.
- Never mix generated DTOs with public domain models.
- Never add UI or state-management dependencies to the SDK packages.
- Do not add a website workaround to the official API adapter.
- Do not delete the archived Git tag.
