# Live Service Acceptance

Fixture tests only prove the local mapping logic; they cannot prove that real account permissions, provider policies, temporary media addresses, and device networking still work. Full acceptance must be authorized by the user and use representative artworks they have access to.

## Security Requirements

- Use only your own Public OAuth app and account;
- Provide the access token through hidden environment input;
- Do not put access/refresh tokens, authorization codes, client secrets, or signed media URLs into command arguments, source code, reports, issues, or ordinary CI;
- The output directory must be a secure absolute path on the local machine, and delete it as needed after completion;
- Testing restricted/paid content only verifies "correct rejection"; do not attempt to bypass permissions.

## Preparation

Before running the full matrix, prepare the following in advance:

- A valid Public OAuth app, plus a completed user authorization session (you can provide the access token directly);
- DeviantArt UUIDs for five categories of artwork: image, video, archive/attachment, literature, restricted;
- An optional local HTTP proxy address (this repository's examples use `127.0.0.1:7892`);
- A secure absolute output directory, for example `/tmp/dakit-live-output`.

## Test Matrix

Prepare the following DeviantArt API UUIDs, not the slug or numeric ID from web page URLs:

1. A downloadable image;
2. A downloadable video;
3. A downloadable archive or attachment;
4. Literature or a journal;
5. A restricted, paid, blocked, or non-downloadable artwork.

The example client shows the UUID in the artwork card and details. Use content you have access to and are allowed to save.

## Running

```shell
read -r -s DAKIT_ACCESS_TOKEN
export DAKIT_ACCESS_TOKEN
export http_proxy=http://127.0.0.1:7892
export https_proxy=http://127.0.0.1:7892
export DAKIT_LIVE_OUTPUT=/absolute/path/dakit-live-output

dart run packages/dakit_api/example/live_contract.dart \
  image=IMAGE_UUID \
  video=VIDEO_UUID \
  archive=ARCHIVE_UUID \
  literature=LITERATURE_UUID \
  restricted=RESTRICTED_UUID

unset DAKIT_ACCESS_TOKEN
```

The proxy variables can be omitted. Dart does not guarantee that `all_proxy` can replace `http_proxy`/`https_proxy`; when you need a local HTTP proxy, set the latter two explicitly.

## Acceptance Evidence

The script performs DNS → TCP → TLS → HTTP, `user/whoami`, artwork details, body text, and original-file resolution in sequence. Every case that is allowed to transfer is fully stream-read, and records actual/expected byte counts, SHA-256, media type, availability, HTTP status, and redacted diagnostic codes to `report.json`.

Pass conditions:

- The image, video, and archive actual byte counts are complete, and SHA-256 computation finishes;
- Literature at least obtains the body text through the official content endpoint; if there is an additional downloadable attachment, it must also transfer completely;
- The restricted case returns a non-transferable status;
- No case may substitute a preview URL for original;
- The report contains no token, Cookie, authorization code, or signed source URL.

`--metadata-only` can be used to collect test data, and `--allow-partial` can be used to prepare the matrix incrementally; neither counts as full acceptance.

## Current Results

A security smoke test has been completed with an invalid token: real networking passes the four-stage probe through the environment proxy, the API correctly returns `api.provider.invalid_token`, and the report leaks no credentials. This only proves routing, error classification, and redaction — not the full media matrix.

The full matrix still awaits a valid Public OAuth session and five representative UUIDs. Once complete you must update [STATUS.md](STATUS.md), but do not commit raw reports or credentials.
