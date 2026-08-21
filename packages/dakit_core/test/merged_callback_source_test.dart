import 'dart:async';

import 'package:dakit_core/dakit_core.dart';
import 'package:test/test.dart';

/// A source whose stream never closes, matching an OS app-links stream. A
/// sequential `yield*` over it would starve every later source.
final class _NeverClosingSource implements InitialCallbackUriSource {
  final StreamController<Uri> _controller = StreamController<Uri>();

  @override
  Future<Uri?> initialUri() async => null;

  @override
  Stream<Uri> get uris => _controller.stream;
}

final class _StreamSource implements CallbackUriSource {
  const _StreamSource(this.stream);

  final Stream<Uri> stream;

  @override
  Stream<Uri> get uris => stream;
}

void main() {
  test(
    'delivers from a later source when an earlier stream never closes',
    () async {
      final webView = StreamController<Uri>.broadcast();
      final merged = MergedCallbackUriSource(
        initial: _NeverClosingSource(),
        others: <CallbackUriSource>[_StreamSource(webView.stream)],
      );

      final first = merged.uris.first;
      final callback = Uri.parse('dakit://oauth/callback?code=x&state=y');
      webView.add(callback);

      expect(await first, callback);

      await webView.close();
    },
  );

  test('delegates the cold-start URI to the initial source', () async {
    final merged = MergedCallbackUriSource(
      initial: _InitialUriSource(Uri.parse('dakit://oauth/callback?code=cold')),
    );

    expect(
      await merged.initialUri(),
      Uri.parse('dakit://oauth/callback?code=cold'),
    );
  });
}

final class _InitialUriSource implements InitialCallbackUriSource {
  const _InitialUriSource(this.uri);

  final Uri uri;

  @override
  Future<Uri?> initialUri() async => uri;

  @override
  Stream<Uri> get uris => const Stream<Uri>.empty();
}
