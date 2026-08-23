# Releasing DAKit Packages

DAKit is a Dart workspace whose public packages are `dakit_core`, `dakit_api`, and
`dakit_flutter`. `dakit_cli` is released as standalone binaries rather than to
pub.dev; `example_client` remains an in-repo integration target.

## Releasing CLI Binaries

1. Update `packages/dakit_cli/pubspec.yaml` and `CHANGELOG.md`;
2. Run `./tool/verify.sh` and a local `dart compile exe` smoke test;
3. Push a tag that exactly matches the package version, for example:

   ```shell
   git tag dakit_cli-v0.2.0
   git push origin dakit_cli-v0.2.0
   ```

`.github/workflows/cli-release.yml` builds and smoke-tests native Linux
x64/ARM64, Windows x64, and macOS Intel/Apple Silicon executables, generates a
SHA-256 manifest, and creates the GitHub Release. The macOS assets must keep the
`unsigned-preview` filename and release warning until Apple Developer ID signing
and notarization are configured.

## Before Releasing

1. Pin the Flutter / Dart toolchain and make sure it builds locally.
2. Run the full quality gate from a clean workspace:

   ```shell
   ./tool/verify.sh
   ```

3. Check the dependency direction:

   ```shell
   dart run melos run graph
   ```

4. Confirm that no tokens, client secrets, proxy passwords, or real service reports have been committed to the repository.
5. Generate and check the package-level API documentation:

   ```shell
   dart run melos run doc
   ```

   Each public package should output `0 warnings and 0 errors`.

## Updating Versions

The pub.dev packages and CLI follow semantic versioning. Before a formal release you need to:

1. Update the `version` in the corresponding package's `pubspec.yaml`, and freeze it to a stable version without the `-dev` suffix before the formal release, for example `0.1.0`.
2. Update the corresponding package's `CHANGELOG.md`, using the `Added` / `Changed` / `Fixed` /
   `Deprecated` / `Removed` / `Security` categories.
3. If the dependency relationships change, update them in the `core → api → flutter` order.
4. Use a conventional commit message, for example:

   ```text
   chore(release): dakit_core 0.2.0
   ```

## Pre-release Dry-run

```shell
dart run melos run publish:check
```

You can also check package by package:

```shell
dart pub publish --dry-run --directory packages/dakit_core
dart pub publish --dry-run --directory packages/dakit_api
flutter pub publish --dry-run --directory packages/dakit_flutter
```

## Automated Publishing via GitHub Actions (Recommended)

The repository is configured with `.github/workflows/publish.yml`, which uses pub.dev's **GitHub Actions
OIDC** authentication: GitHub issues a temporary identity token, so **no long-lived token / secret needs to be stored**.
Publishing is triggered by pushing git tags, tagged one at a time in dependency order:

```text
dakit_core-v0.2.0   ->   dakit_api-v0.2.0   ->   dakit_flutter-v0.2.0
```

### One-time Setup

For each public package, enable automated publishing on pub.dev's Admin page (you must be an uploader of that package, or an admin of the publisher):

1. Open `https://pub.dev/packages/<package>/admin`;
2. In the **Automated publishing** section, click **Enable publishing from GitHub
   Actions**;
3. Fill in:
   - repository: `redtidev1918/dakit`
   - tag pattern: `<package>-v{{version}}` (for example
     `dakit_core-v{{version}}`, `dakit_api-v{{version}}`,
     `dakit_flutter-v{{version}}`).
   - Check **Enable publishing from push events** (tag trigger).
   - If you want button-based releases, also check **Enable publishing from workflow_dispatch events**.

> Automated publishing only applies to **already published packages**; the first release must still be done manually with `dart pub publish`.

### Each Release

1. Use `melos version` (or do it manually) to update the `version` in the `pubspec.yaml` of the package(s) being released, and update their `CHANGELOG.md`;
2. Confirm the dry-run passes (see above);
3. Push the tags in dependency order:

   ```shell
   git tag dakit_core-v0.2.0    && git push origin dakit_core-v0.2.0
   git tag dakit_api-v0.2.0     && git push origin dakit_api-v0.2.0
   git tag dakit_flutter-v0.2.0 && git push origin dakit_flutter-v0.2.0
   ```

4. Watch the corresponding publish job complete on the Actions page.

Note: the version number in the tag must exactly match the `version` in the corresponding package's `pubspec.yaml`; versions on pub.dev are **immutable**, a given version can only be published once, and re-tagging the same version will fail.

### Button Release (workflow_dispatch, Optional)

After the version number has been bumped and pushed to main, you can also skip tagging and simply select the package to publish under
**Actions → Publish to pub.dev → Run workflow**. It publishes the package's current version on the main branch. The prerequisite is having checked
**Enable publishing from workflow_dispatch events** on pub.dev.

## Manual Publishing (Fallback)

When OIDC automated publishing cannot be enabled, you can publish manually after authenticating locally. The publish order must be:

```text
dakit_core -> dakit_api -> dakit_flutter
```

Because `dakit_api` depends on `dakit_core`, and `dakit_flutter` depends on the previous two; a downstream package cannot appear on pub.dev before its dependency packages.

Formal publish commands:

```shell
dart pub publish --directory packages/dakit_core
dart pub publish --directory packages/dakit_api
flutter pub publish --directory packages/dakit_flutter
```

After publishing, update the installation instructions in the root README to switch from Git dependencies to pub.dev versions, and update
[STATUS.md](STATUS.md).
