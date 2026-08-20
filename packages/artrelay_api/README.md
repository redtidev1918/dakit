# artrelay_api

Dart-only OAuth and official HTTP integration for ArtRelay. The package depends on
`artrelay_core` and maps upstream responses into stable core models.

OAuth public clients use Authorization Code with S256 PKCE. The client ID and exact
redirect URI are runtime configuration; no client secret belongs in an application.

