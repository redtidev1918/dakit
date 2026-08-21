# Media, Text Content, and Background Transfer

DAKit splits "what an artwork is", "which original file the server permits retrieving", and "how to save the bytes to the device" into three layers, so that thumbnails are not mistaken for download results.

## Data Flow

```text
ArtworkRepository
  ├─ metadata and preview resources
  ├─ ArtworkContentRepository → literature/journal text, CSS, edit markup (lazy data)
  └─ MediaRepository.originalFile → authorized original-file metadata
                                      ↓
                               TransferManager
```

The image or video URL returned by `ArtworkRepository` may be only a preview. Only a `MediaAsset` returned by `MediaRepository.originalFile` after calling the dedicated download-metadata endpoint — and with `availability == available` — may be handed to the transfer manager.

## Home Page and Personalized Recommendations

`OfficialArtworkRepository.browse` uses the official `browse/home` and returns the **generic home page**, not the account's personalized recommendations. DeviantArt's personalized web home page (`rfy/deviations`) is driven by a **web session (Cookie + CSRF)**; the official OAuth API offers no equivalent endpoint, and it is outside DAKit's stable API scope. Clients that need the personalized home page must obtain that private endpoint themselves through a web session; DAKit does not scrape or adapt it.

## Availability

Original-file resolution explicitly distinguishes `available`, `loginRequired`, `purchaseRequired`, `restricted`, `unavailable`, and `missing`. Expected rejections such as login, permissions, or nonexistence become non-transferable domain values; network interruptions, rate limiting, and corrupted response structures still throw typed exceptions. The SDK never silently falls back to the preview URL on failure.

When a download is rejected as expected, `MediaAsset.availabilityReason` passes through the provider's `error_description` so the host can explain the specific reason to the user. For example, both can be `unavailable`, but the reason may be "Deviation not downloadable (the author has disabled downloads)" or "Free download limit reached (the free quota is used up)" — the former is permanent, while the latter can be resolved by waiting or upgrading. The host can:

```dart
final asset = await mediaRepository.originalFile(artwork.id);
if (asset.availability != MediaAvailability.available) {
  final reason = asset.availabilityReason; // the provider's human-readable description
  // Distinguish and prompt using reason, instead of only showing "not downloadable"
}
```

Literature and journal text are read through the content repository. HTML, CSS, font information, and raw markup are returned only as strings; the SDK does not execute scripts within them, nor does it create a WebView. The host is responsible for sanitization, rendering, and the content security policy.

## Background Transfer

The Flutter adapter `BackgroundTransferManager` uses the platform task-scheduling capability and supports:

- task recovery after process restart;
- queueing, progress, speed, estimated time remaining, and real byte counts;
- retry, pause, resume, and cancel;
- safe leaf filenames and app-relative directories;
- a media proxy configured independently of OAuth/API.

```dart
final transfers = BackgroundTransferManager(diagnostics: diagnostics);
await transfers.initialize();

final asset = await mediaRepository.originalFile(artwork.id);
if (asset.availability == MediaAvailability.available) {
  await transfers.enqueue(
    TransferRequest(id: taskId, asset: asset, filename: asset.filename),
  );
}
```

The SDK has no 16 KiB file or chunk-size limit. The transfer manager is agnostic to byte format and can handle images, videos, animations, archives, documents, or downloadable text; the formats and sizes actually downloadable are still determined by the provider, account permissions, mature-content/purchase restrictions, and the original-file endpoint.

Task records do not store OAuth headers. The media repository first obtains a temporary HTTPS URL, then submits the necessary metadata to the native scheduler. Hosts should not write signed URLs to logs, analytics services, or error reporting.

## Media Proxy

Background tasks may run in a native process different from Dart HTTP, so the media proxy must be configured separately:

```dart
await transfers.configureProxy(
  const ProxyConfiguration(host: '127.0.0.1', port: 7892),
);

// When the user disables the proxy, the native persisted config must be cleared explicitly.
await transfers.configureProxy(null);
```

The proxy is managed by the host's settings page and should not be hardcoded. The Android emulator typically uses `10.0.2.2` to reach the development machine; physical devices need a reachable LAN address.

## What Can Be Proven

Unit tests prove domain mapping, full-byte-length preservation, task recovery, and control calls; a successful build only proves the platform integration compiles. Confirming the behavior of images, videos, archives, literature, and restricted works against the real service requires completing the [real-service test matrix](LIVE_TESTING.md).
