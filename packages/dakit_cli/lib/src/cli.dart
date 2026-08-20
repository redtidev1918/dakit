import 'dart:async';
import 'dart:io';

import 'package:args/args.dart';
import 'package:dakit_api/dakit_api.dart';
import 'package:dakit_core/dakit_core.dart';

import 'cli_diagnostics.dart';
import 'cli_networking.dart';
import 'cli_platform.dart';
import 'cli_session.dart';

const _defaultScopes = 'basic,browse';
const _usage = '''
DAKit command-line client

Usage:
  dakit --help
  dakit url UUID_OR_URL [--dest DIR] [--proxy HOST:PORT]
  dakit artist USERNAME [--limit N] [--delay S] [--dest DIR]
  dakit gallery USERNAME [GALLERY_ID] [--limit N] [--delay S]
  dakit fav USERNAME [FOLDER_ID] [--limit N] [--delay S]
  dakit search QUERY [--limit N] [--delay S]
  dakit login --client-id ID [--scopes basic,browse] [--proxy HOST:PORT]
  dakit login validate
  dakit whoami [--proxy HOST:PORT]
  dakit status [--proxy HOST:PORT]
  dakit version

Environment:
  DAKIT_CLIENT_ID      Public OAuth client ID (login only)
  http_proxy / https_proxy
''';

const _prerequisites = '''
Before `login`, prepare:
  1. Register a Public OAuth application on DeviantArt (not Confidential).
     DAKit client login never accepts a client_secret.
  2. Add this exact redirect URI to its whitelist:
       dakit://oauth/callback
  3. Keep the application's client_id ready.
     After authorizing, paste the full redirect URL when prompted.

Before downloading (`url`, `artist`, `gallery`, `fav`, `search`), run
`dakit login` once and prepare an artwork UUID or username as needed.
''';

Future<void> runCli(List<String> arguments) async {
  final parser = ArgParser()
    ..addFlag('help', abbr: 'h', negatable: false)
    ..addCommand('url', _downloadParser())
    ..addCommand('artist', _batchParser())
    ..addCommand('gallery', _batchParser())
    ..addCommand('fav', _batchParser())
    ..addCommand('search', _batchParser())
    ..addCommand('login', _loginParser())
    ..addCommand('whoami', _proxyParser())
    ..addCommand('status', _proxyParser())
    ..addCommand('version', _proxyParser());

  ArgResults results;
  try {
    results = parser.parse(arguments);
  } on FormatException catch (error) {
    stderr.writeln(error.message);
    stderr.writeln(_usage);
    exitCode = 64;
    return;
  }

  final command = results.command;
  final showHelp = command == null
      ? results['help'] as bool
      : command['help'] as bool;
  if (command == null || showHelp) {
    stdout.writeln(_help());
    return;
  }

  try {
    exitCode = await switch (command.name) {
      'login' => _login(command),
      'url' => _url(command),
      'artist' => _artist(command),
      'gallery' => _gallery(command),
      'fav' => _favourites(command),
      'search' => _search(command),
      'whoami' => _whoami(command),
      'status' => _status(command),
      'version' => _version(command),
      _ => Future<int>.value(64),
    };
  } on DAKitException catch (error) {
    stderr.writeln('${error.kind.name} ${error.code}: ${error.message}');
    exitCode = 1;
  } on Object catch (error) {
    stderr.writeln('unexpected: $error');
    exitCode = 1;
  }
}

ArgParser _loginParser() {
  final parser = ArgParser()
    ..addFlag('help', abbr: 'h', negatable: false)
    ..addFlag('verbose', abbr: 'v', negatable: false)
    ..addOption('client-id', abbr: 'c', help: 'Public OAuth client ID.')
    ..addOption(
      'scopes',
      defaultsTo: _defaultScopes,
      help: 'Comma-separated OAuth scopes.',
    )
    ..addOption('port', defaultsTo: '8765', help: 'Loopback callback port.')
    ..addOption('proxy', help: 'HTTP proxy as HOST:PORT.');
  return parser;
}

ArgParser _downloadParser() {
  final parser = ArgParser()
    ..addFlag('help', abbr: 'h', negatable: false)
    ..addFlag('verbose', abbr: 'v', negatable: false)
    ..addOption('proxy', help: 'HTTP proxy as HOST:PORT.')
    ..addOption('dest', defaultsTo: 'downloads', help: 'Output directory.')
    ..addOption('output', help: 'Alias for --dest.');
  return parser;
}

ArgParser _batchParser() {
  return ArgParser()
    ..addFlag('help', abbr: 'h', negatable: false)
    ..addFlag('verbose', abbr: 'v', negatable: false)
    ..addOption('proxy', help: 'HTTP proxy as HOST:PORT.')
    ..addOption('dest', defaultsTo: 'downloads', help: 'Output directory.')
    ..addOption('limit', defaultsTo: '24', help: 'Maximum items to download.')
    ..addOption(
      'delay',
      defaultsTo: '1',
      help: 'Delay in seconds between items.',
    )
    ..addOption(
      'organize',
      defaultsTo: 'by_author',
      help: 'File layout: by_author or flat.',
    );
}

ArgParser _proxyParser() {
  return ArgParser()
    ..addFlag('help', abbr: 'h', negatable: false)
    ..addFlag('verbose', abbr: 'v', negatable: false)
    ..addOption('proxy', help: 'HTTP proxy as HOST:PORT.');
}

String _help() => '$_usage\n$_prerequisites';

Future<int> _login(ArgResults arguments) async {
  if (arguments.rest.firstOrNull == 'validate') {
    return _whoami(arguments);
  }
  final clientId =
      arguments['client-id'] as String? ??
      Platform.environment['DAKIT_CLIENT_ID'];
  if (clientId == null || clientId.trim().isEmpty) {
    stderr.writeln(
      'Provide --client-id or DAKIT_CLIENT_ID.\n'
      'Run `dakit login --help` for the full checklist.',
    );
    return 64;
  }

  final scopes = (arguments['scopes'] as String)
      .split(',')
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty)
      .toSet();
  final useLoopback = arguments.rest.firstOrNull == 'loopback';
  late final Uri redirectUri;
  late final CallbackUriSource callbackSource;
  if (useLoopback) {
    final port = int.tryParse(arguments['port'] as String) ?? 8765;
    if (port < 1 || port > 65535) {
      stderr.writeln('--port must be between 1 and 65535.');
      return 64;
    }
    redirectUri = Uri.parse('http://127.0.0.1:$port/callback');
    final loopback = LoopbackCallbackSource(port: port, path: redirectUri.path);
    await loopback.start();
    callbackSource = loopback;
  } else {
    redirectUri = Uri.parse('dakit://oauth/callback');
    callbackSource = const StdinCallbackSource();
  }
  stdout.writeln('Required redirect URI whitelist: $redirectUri');

  final config = OAuthConfig(
    clientId: clientId.trim(),
    redirectUri: redirectUri,
    scopes: scopes,
  );
  final profile = resolveNetworkProfile(arguments['proxy'] as String?);
  final diagnostics = _diagnostics(arguments);
  final tokenStore = FileTokenStore();
  final endpoint = DioOAuthEndpoint(
    networkProfile: profile,
    diagnostics: diagnostics,
  );
  final tokenClient = OAuthTokenClient(
    endpoint: endpoint,
    diagnostics: diagnostics,
  );
  final session = OAuthSession(
    config: config,
    store: tokenStore,
    tokenClient: tokenClient,
  );
  final coordinator = OAuthAuthorizationCoordinator(
    config: config,
    launcher: const PlatformUriLauncher(),
    callbacks: callbackSource,
    pendingStore: MemoryPendingAuthorizationStore(),
    tokenClient: tokenClient,
    session: session,
    diagnostics: diagnostics,
  );

  stdout.writeln('Opening your browser. Complete login to continue.');
  try {
    final tokens = await coordinator.authorize();
    stdout.writeln('Credentials saved to ${tokenStore.path}');
    final user = await currentUser(
      StaticTokenProvider(tokens),
      profile,
      diagnostics,
    );
    stdout.writeln('account=${user.username} id=${user.id}');
    return 0;
  } finally {
    if (callbackSource case final LoopbackCallbackSource loopback) {
      await loopback.close();
    }
  }
}

Future<int> _whoami(ArgResults arguments) async {
  final profile = resolveNetworkProfile(arguments['proxy'] as String?);
  final diagnostics = _diagnostics(arguments);
  final tokens = await FileTokenStore().read();
  if (tokens == null) {
    stderr.writeln('Not logged in. Run `dakit login` first.');
    return 64;
  }
  final user = await currentUser(
    StaticTokenProvider(tokens),
    profile,
    diagnostics,
  );
  stdout.writeln('username=${user.username} id=${user.id}');
  return 0;
}

Future<int> _url(ArgResults arguments) async {
  final uuid = extractUuid(arguments.rest.firstOrNull);
  if (uuid == null) {
    stderr.writeln('Provide an artwork UUID or a URL ending in a UUID.');
    return 64;
  }
  final context = await _session(arguments);
  if (context == null) return 64;

  final mediaRepository = OfficialMediaRepository(context.transport);
  final asset = await mediaRepository.originalFile(uuid);
  if (!asset.canTransfer) {
    stderr.writeln('Not downloadable: availability=${asset.availability.name}');
    return 1;
  }

  final outputDirectory = Directory(
    arguments['dest'] as String? ??
        arguments['output'] as String? ??
        'downloads',
  );
  await outputDirectory.create(recursive: true);
  stdout.writeln(
    await downloadAsset(
      asset: asset,
      profile: context.profile,
      outputDirectory: outputDirectory,
    ),
  );
  return 0;
}

Future<int> _artist(ArgResults arguments) async {
  final username = arguments.rest.firstOrNull;
  if (username == null || username.trim().isEmpty) {
    stderr.writeln('Provide an artist username.');
    return 64;
  }
  final context = await _session(arguments);
  if (context == null) return 64;
  final galleryRepository = OfficialGalleryRepository(context.transport);
  return _downloadBatch(
    arguments,
    context,
    username,
    (request) => galleryRepository.gallery(username, request),
  );
}

Future<int> _gallery(ArgResults arguments) async {
  final username = arguments.rest.firstOrNull;
  if (username == null || username.trim().isEmpty) {
    stderr.writeln('Provide an artist username.');
    return 64;
  }
  final context = await _session(arguments);
  if (context == null) return 64;
  final galleryId = arguments.rest.elementAtOrNull(1);
  final folderRepository = OfficialFolderRepository(context.transport);
  final galleryRepository = OfficialGalleryRepository(context.transport);
  final destination = galleryId ?? username;
  return _downloadBatch(
    arguments,
    context,
    destination,
    galleryId == null
        ? (request) => galleryRepository.gallery(username, request)
        : (request) => folderRepository.galleryContents(
            galleryId,
            username: username,
            request: request,
          ),
  );
}

Future<int> _favourites(ArgResults arguments) async {
  final username = arguments.rest.firstOrNull;
  if (username == null || username.trim().isEmpty) {
    stderr.writeln('Provide an artist username.');
    return 64;
  }
  final context = await _session(arguments);
  if (context == null) return 64;
  final folderId = arguments.rest.elementAtOrNull(1);
  final folderRepository = OfficialFolderRepository(context.transport);
  final galleryRepository = OfficialGalleryRepository(context.transport);
  final destination = folderId ?? username;
  return _downloadBatch(
    arguments,
    context,
    destination,
    folderId == null
        ? (request) => galleryRepository.favourites(username, request)
        : (request) => folderRepository.collectionContents(
            folderId,
            username: username,
            request: request,
          ),
  );
}

Future<int> _search(ArgResults arguments) async {
  final parts = arguments.rest.toList(growable: false);
  if (parts.isEmpty) {
    stderr.writeln('Provide a search query.');
    return 64;
  }
  final query = parts.length > 1 ? parts.sublist(1).join(' ') : parts.first;
  final context = await _session(arguments);
  if (context == null) return 64;
  final artworkRepository = OfficialArtworkRepository(context.transport);
  return _downloadBatch(
    arguments,
    context,
    query,
    (request) => artworkRepository.search(query, request),
  );
}

Future<int> _version(ArgResults arguments) async {
  stdout.writeln('dakit_cli 0.1.0-dev.1');
  return 0;
}

Future<int> _downloadBatch(
  ArgResults arguments,
  CliContext context,
  String destination,
  Future<Page<Artwork>> Function(PageRequest request) load,
) async {
  final limit = positiveInt(arguments['limit'] as String, 24, '--limit');
  final delay = positiveInt(arguments['delay'] as String, 1, '--delay');
  final organize = (arguments['organize'] as String).trim();
  final root = Directory(arguments['dest'] as String);
  final outputDirectory = organize == 'flat'
      ? root
      : Directory(
          '${root.path}${Platform.pathSeparator}${safeFilename(destination)}',
        );
  await outputDirectory.create(recursive: true);

  final mediaRepository = OfficialMediaRepository(context.transport);
  var cursor = '';
  var count = 0;
  var failed = 0;
  Page<Artwork> page;
  do {
    page = await load(
      PageRequest(cursor: cursor.isEmpty ? null : cursor, limit: 24),
    );
    for (final artwork in page.items) {
      if (count >= limit) break;
      try {
        final asset = await mediaRepository.originalFile(artwork.id);
        if (!asset.canTransfer) {
          stdout.writeln(
            'skip=${artwork.id} availability=${asset.availability.name}',
          );
        } else {
          stdout.writeln(
            await downloadAsset(
              asset: asset,
              profile: context.profile,
              outputDirectory: outputDirectory,
            ),
          );
        }
      } on DAKitException catch (error) {
        failed += 1;
        stderr.writeln('failed=${artwork.id} ${error.code}');
      }
      count += 1;
      if (delay > 0) {
        await Future<void>.delayed(Duration(seconds: delay));
      }
      if (count >= limit) break;
    }
    cursor = page.nextCursor ?? '';
  } while (page.hasMore && count < limit);

  stdout.writeln('done=$count failed=$failed');
  return failed == 0 ? 0 : 1;
}

Future<CliContext?> _session(ArgResults arguments) async {
  final tokens = await FileTokenStore().read();
  if (tokens == null) {
    stderr.writeln('Not logged in. Run `dakit login` first.');
    return null;
  }
  return CliContext(
    profile: resolveNetworkProfile(arguments['proxy'] as String?),
    diagnostics: _diagnostics(arguments),
    tokens: tokens,
  );
}

Future<int> _status(ArgResults arguments) async {
  final profile = resolveNetworkProfile(arguments['proxy'] as String?);
  final diagnostics = _diagnostics(arguments);
  final report = await ConnectivityProbe(
    target: Uri.https('www.deviantart.com', '/api/v1/oauth2/placebo'),
    profile: profile,
    diagnostics: diagnostics,
  ).run();

  stdout.writeln('profile=${profile.mode.name}');
  for (final stage in report.stages) {
    stdout.writeln(
      '${stage.stage.name}=${stage.succeeded ? 'ok' : stage.code} '
      '${stage.elapsed.inMilliseconds}ms',
    );
  }
  return report.reachable ? 0 : 1;
}

DiagnosticSink _diagnostics(ArgResults arguments) =>
    arguments['verbose'] as bool
    ? const CliDiagnostics()
    : const NoopDiagnosticSink();
