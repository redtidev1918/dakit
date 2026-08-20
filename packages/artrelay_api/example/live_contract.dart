import 'dart:convert';
import 'dart:io';

import 'package:artrelay_api/artrelay_api.dart';
import 'package:artrelay_core/artrelay_core.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';

const _requiredKinds = <_LiveKind>{
  _LiveKind.image,
  _LiveKind.video,
  _LiveKind.archive,
  _LiveKind.literature,
  _LiveKind.restricted,
};

Future<void> main(List<String> arguments) async {
  _Configuration? configuration;
  try {
    configuration = _Configuration.parse(arguments, Platform.environment);
    final report = await _verify(configuration);
    await _emitReport(configuration, report);
    if (report['passed'] != true) exitCode = 1;
  } on _UsageException catch (error) {
    stderr.writeln(error.message);
    stderr.writeln(_usage);
    exitCode = 64;
  } on ArtRelayException catch (error) {
    final report = <String, Object?>{
      'schema': 1,
      'passed': false,
      'failure': <String, Object?>{
        'kind': error.kind.name,
        'code': error.code,
        'message': error.message,
      },
    };
    if (configuration != null) {
      await _emitReport(configuration, report);
    } else {
      stdout.writeln(const JsonEncoder.withIndent('  ').convert(report));
    }
    exitCode = 1;
  } on Object {
    const report = <String, Object?>{
      'schema': 1,
      'passed': false,
      'failure': <String, Object?>{
        'kind': 'unexpected',
        'code': 'live.unexpected',
        'message': 'The live verifier encountered an unexpected failure.',
      },
    };
    if (configuration != null) {
      await _emitReport(configuration, report);
    } else {
      stdout.writeln(const JsonEncoder.withIndent('  ').convert(report));
    }
    exitCode = 1;
  }
}

Future<void> _emitReport(
  _Configuration configuration,
  Map<String, Object?> report,
) async {
  final encoded = const JsonEncoder.withIndent('  ').convert(report);
  stdout.writeln(encoded);
  await configuration.outputDirectory.create(recursive: true);
  await File(
    '${configuration.outputDirectory.path}${Platform.pathSeparator}report.json',
  ).writeAsString('$encoded\n', flush: true);
}

Future<Map<String, Object?>> _verify(_Configuration configuration) async {
  final diagnostics = _LiveDiagnostics();
  final profile = NetworkProfile.environment();
  final connectivity = await ConnectivityProbe(
    target: Uri.https('www.deviantart.com', '/api/v1/oauth2/placebo'),
    profile: profile,
  ).run();
  if (!connectivity.reachable) {
    return <String, Object?>{
      'schema': 1,
      'passed': false,
      'failure': <String, Object?>{
        'kind': 'network',
        'code': connectivity.failure?.code ?? 'network.unreachable',
        'message': 'The staged connectivity probe could not reach the service.',
      },
      'network': _networkReport(profile, connectivity),
      'download_files': configuration.downloadFiles,
      'output_directory': configuration.outputDirectory.path,
      'cases': const <Object?>[],
    };
  }
  final transport = OfficialApiClient(
    session: _EnvironmentTokenProvider(configuration.accessToken),
    networkProfile: profile,
    diagnostics: diagnostics,
    config: ApiConfig(userAgent: 'ArtRelay-LiveVerifier/0.1'),
  );
  final accountRepository = OfficialAccountRepository(transport);
  final artworkRepository = OfficialArtworkRepository(transport);
  final contentRepository = OfficialArtworkContentRepository(transport);
  final mediaRepository = OfficialMediaRepository(transport);
  final mediaClient = createNetworkDio(
    profile: profile,
    options: BaseOptions(
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(minutes: 30),
      headers: const <String, Object?>{
        'User-Agent': 'ArtRelay-LiveVerifier/0.1',
        'Accept-Encoding': 'gzip',
      },
    ),
  );
  try {
    final user = await accountRepository.currentUser();
    final results = <Map<String, Object?>>[];
    for (final testCase in configuration.cases) {
      results.add(
        await _verifyCase(
          testCase,
          artworkRepository: artworkRepository,
          contentRepository: contentRepository,
          mediaRepository: mediaRepository,
          mediaClient: mediaClient,
          outputDirectory: configuration.outputDirectory,
          downloadFiles: configuration.downloadFiles,
        ),
      );
    }
    return <String, Object?>{
      'schema': 1,
      'passed':
          connectivity.reachable &&
          results.every((result) => result['passed'] == true),
      'account': <String, Object?>{'id': user.id, 'username': user.username},
      'network': _networkReport(profile, connectivity),
      'download_files': configuration.downloadFiles,
      'output_directory': configuration.outputDirectory.path,
      'cases': results,
      'diagnostics': _diagnosticReport(diagnostics),
    };
  } on ArtRelayException catch (error) {
    return <String, Object?>{
      'schema': 1,
      'passed': false,
      'failure': <String, Object?>{
        'kind': error.kind.name,
        'code': error.code,
        'message': error.message,
      },
      'network': _networkReport(profile, connectivity),
      'download_files': configuration.downloadFiles,
      'output_directory': configuration.outputDirectory.path,
      'cases': const <Object?>[],
      'diagnostics': _diagnosticReport(diagnostics),
    };
  } finally {
    mediaClient.close(force: true);
  }
}

List<Map<String, Object?>> _diagnosticReport(_LiveDiagnostics diagnostics) =>
    diagnostics.events
        .map(
          (event) => <String, Object?>{
            'stage': event.stage.name,
            'level': event.level.name,
            'code': event.code,
            if (event.elapsed != null)
              'elapsed_ms': event.elapsed!.inMilliseconds,
          },
        )
        .toList(growable: false);

Map<String, Object?> _networkReport(
  NetworkProfile profile,
  ConnectivityReport connectivity,
) => <String, Object?>{
  'profile': profile.mode.name,
  'reachable': connectivity.reachable,
  'stages': connectivity.stages
      .map(
        (stage) => <String, Object?>{
          'stage': stage.stage.name,
          'passed': stage.succeeded,
          'code': stage.code,
          'elapsed_ms': stage.elapsed.inMilliseconds,
        },
      )
      .toList(growable: false),
};

Future<Map<String, Object?>> _verifyCase(
  _LiveCase testCase, {
  required OfficialArtworkRepository artworkRepository,
  required OfficialArtworkContentRepository contentRepository,
  required OfficialMediaRepository mediaRepository,
  required Dio mediaClient,
  required Directory outputDirectory,
  required bool downloadFiles,
}) async {
  try {
    final artwork = await artworkRepository.getById(testCase.artworkId);
    if (testCase.kind == _LiveKind.restricted) {
      var availability = artwork.downloadAvailability;
      if (availability == MediaAvailability.available) {
        availability = (await mediaRepository.originalFile(artwork.id))
            .availability;
      }
      final passed = availability != MediaAvailability.available;
      return _caseReport(
        testCase,
        passed: passed,
        artwork: artwork,
        availability: availability,
        failure: passed ? null : 'restricted_case_resolved_as_available',
      );
    }

    if (testCase.kind == _LiveKind.literature) {
      final content = await contentRepository.get(artwork.id);
      final hasText = artwork.textContent != null || !content.isEmpty;
      if (!hasText) {
        return _caseReport(
          testCase,
          passed: false,
          artwork: artwork,
          availability: artwork.downloadAvailability,
          failure: 'literature_content_empty',
        );
      }
      if (artwork.downloadAvailability != MediaAvailability.available ||
          !downloadFiles) {
        return _caseReport(
          testCase,
          passed: true,
          artwork: artwork,
          availability: artwork.downloadAvailability,
          extra: <String, Object?>{
            'rendered_content': true,
            'downloaded': false,
          },
        );
      }
    }

    if (artwork.downloadAvailability != MediaAvailability.available) {
      return _caseReport(
        testCase,
        passed: false,
        artwork: artwork,
        availability: artwork.downloadAvailability,
        failure: 'original_not_available',
      );
    }
    final asset = await mediaRepository.originalFile(artwork.id);
    final expectedKind = _mediaKind(testCase.kind);
    if (!asset.canTransfer || asset.kind != expectedKind) {
      return _caseReport(
        testCase,
        passed: false,
        artwork: artwork,
        availability: asset.availability,
        failure: asset.canTransfer
            ? 'media_kind_mismatch'
            : 'media_not_transferable',
        extra: <String, Object?>{
          'expected_kind': expectedKind.name,
          'actual_kind': asset.kind.name,
        },
      );
    }
    if (!downloadFiles) {
      return _caseReport(
        testCase,
        passed: true,
        artwork: artwork,
        availability: asset.availability,
        extra: <String, Object?>{
          'kind': asset.kind.name,
          'expected_bytes': asset.byteLength,
          'downloaded': false,
        },
      );
    }
    await outputDirectory.create(recursive: true);
    final filename = '${testCase.kind.name}-${_safeFilename(asset.filename)}';
    final file = File(
      '${outputDirectory.path}${Platform.pathSeparator}$filename',
    );
    final response = await mediaClient.download(
      asset.uri!.toString(),
      file.path,
      deleteOnError: true,
    );
    final actualBytes = await file.length();
    final expectedBytes = asset.byteLength;
    final sizeMatches = expectedBytes == null
        ? actualBytes > 0
        : actualBytes == expectedBytes;
    final digest = await sha256.bind(file.openRead()).first;
    return _caseReport(
      testCase,
      passed: sizeMatches,
      artwork: artwork,
      availability: asset.availability,
      failure: sizeMatches ? null : 'download_size_mismatch',
      extra: <String, Object?>{
        'kind': asset.kind.name,
        'http_status': response.statusCode,
        'expected_bytes': expectedBytes,
        'actual_bytes': actualBytes,
        'sha256': digest.toString(),
        'filename': filename,
        'downloaded': true,
      },
    );
  } on ArtRelayException catch (error) {
    final expectedRestriction =
        testCase.kind == _LiveKind.restricted &&
        (error.kind == ArtRelayFailureKind.authentication ||
            error.kind == ArtRelayFailureKind.authorization ||
            error.kind == ArtRelayFailureKind.restricted);
    return <String, Object?>{
      'kind': testCase.kind.name,
      'artwork_id': testCase.artworkId,
      'passed': expectedRestriction,
      'failure_code': error.code,
      'failure_kind': error.kind.name,
    };
  } on Object {
    return <String, Object?>{
      'kind': testCase.kind.name,
      'artwork_id': testCase.artworkId,
      'passed': false,
      'failure_code': 'live.unexpected',
    };
  }
}

Map<String, Object?> _caseReport(
  _LiveCase testCase, {
  required bool passed,
  required Artwork artwork,
  required MediaAvailability availability,
  String? failure,
  Map<String, Object?> extra = const <String, Object?>{},
}) => <String, Object?>{
  'kind': testCase.kind.name,
  'artwork_id': testCase.artworkId,
  'passed': passed,
  'title': artwork.title,
  'availability': availability.name,
  'failure_code': ?failure,
  ...extra,
};

MediaKind _mediaKind(_LiveKind kind) => switch (kind) {
  _LiveKind.image => MediaKind.image,
  _LiveKind.video => MediaKind.video,
  _LiveKind.archive => MediaKind.archive,
  _LiveKind.document => MediaKind.document,
  _LiveKind.literature => MediaKind.literature,
  _LiveKind.restricted => MediaKind.unknown,
};

String _safeFilename(String? value) {
  final leaf = value == null
      ? 'original.bin'
      : value.replaceAll('\\', '/').split('/').last;
  final safe = leaf.replaceAll(RegExp(r'[^A-Za-z0-9._ -]'), '_').trim();
  return safe.isEmpty || safe == '.' || safe == '..' ? 'original.bin' : safe;
}

enum _LiveKind { image, video, archive, document, literature, restricted }

final class _LiveCase {
  const _LiveCase(this.kind, this.artworkId);

  final _LiveKind kind;
  final String artworkId;
}

final class _Configuration {
  const _Configuration({
    required this.accessToken,
    required this.cases,
    required this.outputDirectory,
    required this.downloadFiles,
  });

  factory _Configuration.parse(
    List<String> arguments,
    Map<String, String> environment,
  ) {
    final token = environment['ARTRELAY_ACCESS_TOKEN']?.trim();
    if (token == null || token.isEmpty) {
      throw const _UsageException('ARTRELAY_ACCESS_TOKEN is required.');
    }
    var downloadFiles = true;
    var allowPartial = false;
    final cases = <_LiveCase>[];
    for (final argument in arguments) {
      if (argument == '--metadata-only') {
        downloadFiles = false;
        continue;
      }
      if (argument == '--allow-partial') {
        allowPartial = true;
        continue;
      }
      final separator = argument.indexOf('=');
      if (separator <= 0 || separator == argument.length - 1) {
        throw _UsageException('Invalid live case: $argument');
      }
      final kindName = argument.substring(0, separator);
      final artworkId = argument.substring(separator + 1).trim();
      final kind = _LiveKind.values
          .where((item) => item.name == kindName)
          .firstOrNull;
      if (kind == null || artworkId.isEmpty) {
        throw _UsageException('Invalid live case: $argument');
      }
      if (cases.any((testCase) => testCase.kind == kind)) {
        throw _UsageException('Duplicate live case: $kindName');
      }
      cases.add(_LiveCase(kind, artworkId));
    }
    if (!allowPartial) {
      final supplied = cases.map((testCase) => testCase.kind).toSet();
      final missing = _requiredKinds.difference(supplied);
      if (missing.isNotEmpty) {
        throw _UsageException(
          'Missing required cases: ${missing.map((item) => item.name).join(', ')}',
        );
      }
    }
    if (cases.isEmpty) throw const _UsageException('No live cases supplied.');
    final output = environment['ARTRELAY_LIVE_OUTPUT']?.trim();
    final outputDirectory = output == null || output.isEmpty
        ? Directory(
            '${Directory.systemTemp.path}${Platform.pathSeparator}'
            'artrelay-live-${DateTime.now().toUtc().microsecondsSinceEpoch}',
          )
        : Directory(output);
    return _Configuration(
      accessToken: token,
      cases: List<_LiveCase>.unmodifiable(cases),
      outputDirectory: outputDirectory,
      downloadFiles: downloadFiles,
    );
  }

  final String accessToken;
  final List<_LiveCase> cases;
  final Directory outputDirectory;
  final bool downloadFiles;
}

final class _EnvironmentTokenProvider implements AuthTokenProvider {
  _EnvironmentTokenProvider(String accessToken)
    : _tokens = AuthTokens(
        accessToken: accessToken,
        tokenType: 'Bearer',
        expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
        scopes: const <String>{'basic', 'browse'},
      );

  final AuthTokens _tokens;

  @override
  Future<AuthTokens> validTokens({bool forceRefresh = false}) async => _tokens;
}

final class _LiveDiagnostics implements DiagnosticSink {
  final List<DiagnosticEvent> events = <DiagnosticEvent>[];

  @override
  void add(DiagnosticEvent event) => events.add(event);
}

final class _UsageException implements Exception {
  const _UsageException(this.message);

  final String message;
}

const _usage = '''
Usage:
  ARTRELAY_ACCESS_TOKEN=... dart run example/live_contract.dart \\
    image=UUID video=UUID archive=UUID literature=UUID restricted=UUID

Options:
  --metadata-only  Resolve metadata without downloading transferable files.
  --allow-partial  Permit a subset while preparing a complete matrix.

Optional environment:
  ARTRELAY_LIVE_OUTPUT=/safe/output/directory
  http_proxy=http://127.0.0.1:7892
  https_proxy=http://127.0.0.1:7892
''';
