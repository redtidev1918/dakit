# Media transfers

ArtRelay separates media discovery from file transfer:

1. `ArtworkRepository` returns metadata and preview variants.
2. `MediaRepository.originalFile` resolves the provider-authorized original.
3. `TransferManager` schedules that `MediaAsset` without knowing provider APIs.

This prevents a thumbnail or preview response from being mislabeled as a complete
download. There is no fixed 16 KiB body or chunk limit in the SDK.

## Flutter adapter

`BackgroundTransferManager` uses the maintained `background_downloader` plugin.
It maps native task schedulers into stable ArtRelay snapshots on Android, macOS,
Windows, and Linux. The adapter supports persisted task recovery, progress,
expected byte count, network rate, remaining time, retry state, pause, resume,
cancel, and an independently configurable transfer proxy.

```dart
final transfers = BackgroundTransferManager(diagnostics: diagnostics);
await transfers.initialize();

final original = await mediaRepository.originalFile(artwork.id);
final task = await transfers.enqueue(
  TransferRequest(
    id: uniqueTaskId,
    asset: original,
    requiresWifi: false,
  ),
);

transfers.updates.listen(renderTransfer);
```

The example client initializes the manager before session restoration, reloads
persisted records, and displays them independently from the selected artwork. Its
detail workflow checks `Artwork.isDownloadable` before resolving an original and
coalesces scheduling/control actions so repeated taps cannot enqueue or mutate a
task concurrently. Late detail responses are generation-checked and cannot replace
a newer selection.

Tasks use an application-relative directory rather than persisting an absolute
mobile path. Filenames are reduced to a safe leaf name. Transfer task records do
not include OAuth headers; callers should enqueue the HTTPS URL resolved by the
official media endpoint.

## Proxy

Transfer traffic is configured independently from API traffic:

```dart
await transfers.configureProxy(
  const ProxyConfiguration(host: '127.0.0.1', port: 7892),
);

// Important: explicitly clear native persisted configuration.
await transfers.configureProxy(null);
```

The proxy belongs to the host application's settings. It is never hardcoded by
the SDK. TLS certificate validation cannot be disabled through the ArtRelay API.

## Format support

The transfer engine is byte-format agnostic and therefore does not truncate image,
video, animation, archive, document, or literature assets. Actual provider access
still depends on whether an item is downloadable, the account's authorization,
purchase/maturity restrictions, and the original metadata endpoint.

Unit tests prove transport mapping and full byte-length preservation with fixtures.
Live acceptance still requires representative provider items for each format; a
successful build alone is not evidence that every provider-side restriction works.
