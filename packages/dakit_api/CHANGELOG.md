## 0.1.0-dev.1

- Add public-client OAuth Authorization Code + S256 PKCE lifecycle.
- Add persisted, single-flight browser authorization with cold-start recovery and
  structured stage diagnostics.
- Add versioned, retrying, authenticated official API transport.
- Add account, artwork, gallery, collection, and original-media repositories.
- Add tolerant DTO mapping and schema-derived contract fixtures.
- Add explicit environment, direct, and HTTP-proxy profiles for OAuth and API
  clients, including authenticated proxies and bypass suffixes.
- Add redacted DNS, TCP, TLS, and HTTP connectivity reports.
- Preserve OAuth transport failures as network errors instead of authentication
  errors.
- Encode token, refresh, and revoke bodies as real URL-encoded forms and verify the
  HTTP wire representation.
- Add structured deviation text, rendered content, and honest original-file
  availability mapping.
- Depend on a replaceable core token provider and add an opt-in, redacted live
  contract/media verifier.
- Prevent logout from being undone by an in-flight refresh or late browser token
  exchange, and preserve granted scopes when refresh responses omit `scope`.
- Make active browser authorization explicitly cancellable instead of waiting for
  the callback timeout.
- Add authenticated URL-encoded mutation transport without unsafe automatic POST
  retries, plus typed artwork comments, favourite/unfavourite, and watch/unwatch
  repositories.
- Preserve bounded provider API descriptions for actionable diagnostics.
- Add official adapters for full user profiles, daily selections, watched-user
  feeds, tag browsing, and gallery/collection folder listings with optional
  artwork preload data.
- Preserve opaque tag cursors separately from numeric offsets so either official
  continuation mode can be resumed correctly.
