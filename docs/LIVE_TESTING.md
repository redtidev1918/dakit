# Live provider verification

Fixture tests prove mapping behavior; they cannot prove that a real account,
provider policy, signed media URL, or native network route still behaves the same.
The opt-in verifier exercises those boundaries without storing a credential in the
repository.

## Inputs

Prepare one provider UUID for each required case:

- downloadable image;
- downloadable video;
- downloadable archive;
- literature or journal;
- restricted, paid, blocked, or otherwise non-downloadable work.

The example client displays artwork UUIDs in its home cards and detail view. Use
content you are authorized to access. Do not treat a page slug or numeric number in
a website URL as an API UUID.

Supply a current user access token through the environment. Never put the token,
refresh token, authorization code, client secret, or signed media URL in an
argument, source file, report, issue, or ordinary CI secret.

```shell
read -s DAKIT_ACCESS_TOKEN
export DAKIT_ACCESS_TOKEN
export http_proxy=http://127.0.0.1:7892
export https_proxy=http://127.0.0.1:7892
export DAKIT_LIVE_OUTPUT=/absolute/safe/path/live-output

dart run packages/dakit_api/example/live_contract.dart \
  image=IMAGE_UUID \
  video=VIDEO_UUID \
  archive=ARCHIVE_UUID \
  literature=LITERATURE_UUID \
  restricted=RESTRICTED_UUID

unset DAKIT_ACCESS_TOKEN
```

The proxy variables are optional. Dart does not reliably substitute `all_proxy`
for `http_proxy` and `https_proxy`, so set the latter two when a local HTTP proxy is
required.

## Evidence produced

The verifier performs a DNS → TCP → TLS → HTTP probe, calls `user/whoami`, fetches
each detail, expands full text, resolves original metadata where allowed, and
downloads every transferable case completely. It records actual bytes, expected
bytes, SHA-256, media kind, access state, HTTP status, and redacted diagnostic stage
codes in `report.json`. It never writes bearer tokens or signed source URLs.

Literature is validated through the official content endpoint. If it also has a
downloadable text file, that file is transferred; otherwise successful rendered
content is the acceptance evidence. A restricted case passes only when metadata or
the original endpoint denies transfer. A preview URL is never accepted.

Use `--metadata-only` for preparation and `--allow-partial` while collecting case
UUIDs. Neither option satisfies the complete acceptance matrix. Live verification
is intentionally excluded from ordinary CI because it requires a real user session
and provider-controlled content.
