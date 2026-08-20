import 'package:dakit_flutter/dakit_flutter.dart';
import 'package:flutter/material.dart';

import '../client_controller.dart';
import '../app_strings.dart';

final class ArtworkBrowser extends StatelessWidget {
  const ArtworkBrowser({required this.controller, super.key});

  final ExampleClientController controller;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    if (controller.artworks.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(strings.noArtwork),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(strings.home, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        for (final artwork in controller.artworks) ...<Widget>[
          Card(
            child: ListTile(
              key: Key('artwork-${artwork.id}'),
              onTap: () => controller.openArtwork(artwork.id),
              title: Text(artwork.title),
              subtitle: Text('@${artwork.author.username} · ${artwork.id}'),
              trailing: Icon(
                artwork.downloadAvailability == MediaAvailability.available
                    ? Icons.download_done
                    : Icons.visibility,
              ),
            ),
          ),
          if (controller.selectedArtwork?.id == artwork.id)
            _ArtworkDetail(controller: controller),
        ],
      ],
    );
  }
}

final class _ArtworkDetail extends StatelessWidget {
  const _ArtworkDetail({required this.controller});

  final ExampleClientController controller;

  @override
  Widget build(BuildContext context) {
    final artwork = controller.selectedArtwork;
    final original = controller.selectedOriginal;
    final transfer = controller.selectedTransfer;
    final theme = Theme.of(context);
    final strings = AppStrings.of(context);
    return Card(
      key: const Key('artwork-detail'),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    artwork?.title ?? strings.artworkDetail,
                    style: theme.textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  tooltip: strings.closeDetail,
                  onPressed: controller.closeArtwork,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            if (controller.loadingArtwork) ...<Widget>[
              const LinearProgressIndicator(),
              const SizedBox(height: 12),
              Text(strings.loadingDetail),
            ],
            if (artwork != null) ...<Widget>[
              Text('@${artwork.author.username} · ${artwork.id}'),
              if (artwork.description case final description?) ...<Widget>[
                const SizedBox(height: 12),
                Text(description),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  Chip(
                    label: Text(
                      strings.availabilityLabel(artwork.downloadAvailability),
                    ),
                  ),
                  if (artwork.isMature)
                    Chip(label: Text(strings.matureContent)),
                  for (final asset in artwork.media)
                    Chip(label: Text('${asset.kind.name} ${asset.role.name}')),
                ],
              ),
            ],
            if (controller.artworkFailure case final failure?) ...<Widget>[
              const SizedBox(height: 12),
              Text(
                '${failure.code}: ${strings.failureMessage(failure)}',
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ],
            if (!controller.loadingArtwork &&
                artwork != null &&
                artwork.downloadAvailability !=
                    MediaAvailability.available) ...<Widget>[
              const SizedBox(height: 12),
              Text(strings.noOriginal),
            ],
            if (original != null) ...<Widget>[
              const Divider(height: 32),
              Text(strings.originalFile, style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(
                '${original.filename ?? strings.unnamedFile} · '
                '${original.kind.name} · '
                '${_formatBytes(original.byteLength, strings)}',
              ),
              Text(
                '${strings.availability}: '
                '${strings.availabilityLabel(original.availability)}',
              ),
              const SizedBox(height: 12),
              if (transfer == null || transfer.isFinal)
                FilledButton.icon(
                  key: const Key('download-original-button'),
                  onPressed:
                      original.canTransfer && !controller.schedulingTransfer
                      ? controller.downloadOriginal
                      : null,
                  icon: const Icon(Icons.download),
                  label: Text(
                    controller.schedulingTransfer
                        ? strings.scheduling
                        : transfer?.state == TransferState.completed
                        ? strings.downloadAgain
                        : strings.downloadOriginal,
                  ),
                ),
            ],
            if (transfer != null) ...<Widget>[
              const Divider(height: 32),
              Text(strings.transfer, style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(
                '${transfer.state.name} · ${transfer.filename ?? transfer.id}',
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(value: transfer.progress.clamp(0, 1)),
              const SizedBox(height: 8),
              Text(_transferSummary(transfer, strings)),
              if (transfer.localPath case final path?) SelectableText(path),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  if (transfer.state
                      case TransferState.queued ||
                          TransferState.running ||
                          TransferState.retrying)
                    OutlinedButton.icon(
                      onPressed: controller.controllingTransfer
                          ? null
                          : controller.pauseTransfer,
                      icon: const Icon(Icons.pause),
                      label: Text(strings.pause),
                    ),
                  if (transfer.state == TransferState.paused)
                    FilledButton.tonalIcon(
                      onPressed: controller.controllingTransfer
                          ? null
                          : controller.resumeTransfer,
                      icon: const Icon(Icons.play_arrow),
                      label: Text(strings.resume),
                    ),
                  if (!transfer.isFinal)
                    TextButton.icon(
                      onPressed: controller.controllingTransfer
                          ? null
                          : controller.cancelTransfer,
                      icon: const Icon(Icons.cancel_outlined),
                      label: Text(strings.cancel),
                    ),
                ],
              ),
            ],
            if (controller.transferFailure case final failure?) ...<Widget>[
              const SizedBox(height: 12),
              Text(
                '${failure.code}: ${strings.failureMessage(failure)}',
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _transferSummary(
    TransferSnapshot snapshot,
    AppStrings strings,
  ) {
    final values = <String>[
      '${(snapshot.progress * 100).clamp(0, 100).toStringAsFixed(1)}%',
      if (snapshot.expectedBytes != null)
        _formatBytes(snapshot.expectedBytes, strings),
      if (snapshot.networkBytesPerSecond != null)
        '${_formatBytes(snapshot.networkBytesPerSecond, strings)}/s',
      if (snapshot.timeRemaining != null)
        '${snapshot.timeRemaining!.inSeconds}s ${strings.remaining}',
      if (snapshot.failureCode != null) snapshot.failureCode!,
    ];
    return values.join(' · ');
  }

  static String _formatBytes(int? bytes, AppStrings strings) {
    if (bytes == null || bytes < 0) return strings.sizeUnknown;
    const units = <String>['B', 'KiB', 'MiB', 'GiB', 'TiB'];
    var value = bytes.toDouble();
    var unit = 0;
    while (value >= 1024 && unit < units.length - 1) {
      value /= 1024;
      unit += 1;
    }
    final precision = unit == 0 ? 0 : 1;
    return '${value.toStringAsFixed(precision)} ${units[unit]}';
  }
}
