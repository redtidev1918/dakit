# artrelay_core

Platform-neutral contracts for ArtRelay clients. This package exports stable domain
models, typed failures, repository interfaces, pagination, authentication storage
boundaries, and structured diagnostics. It has no Flutter dependency.

Host applications implement or obtain the repository interfaces and remain free to
choose their own UI, state management, cache, and database.

`MediaRepository` resolves protected original-file metadata independently from
`ArtworkRepository`. A transfer engine therefore consumes a `MediaAsset` without
knowing provider endpoints, OAuth details, or UI state.

`ArtworkContentRepository` exposes full literature/journal content separately from
metadata. Embedded markup, rendered HTML, and CSS remain inert strings so each host
can apply its own sanitization and rendering policy.
