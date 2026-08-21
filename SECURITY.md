# Security Policy

## Supported versions

Only the latest published versions of each package and `main` are supported.

## Reporting a vulnerability

Do **not** open a public issue for security vulnerabilities. Email the
maintainer directly with a description, impact, and reproduction steps.

## Security posture

- DAKit uses OAuth Authorization Code + PKCE for client sign-in.
- It never stores or distributes a `client_secret` on the client.
- Tokens, authorization codes, cookies, and PKCE verifiers are never logged.
- TLS verification is never disabled.
