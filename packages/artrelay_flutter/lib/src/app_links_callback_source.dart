import 'package:app_links/app_links.dart';
import 'package:artrelay_core/artrelay_core.dart';

/// Receives custom-scheme callbacks from Android, macOS, and Windows.
final class AppLinksCallbackUriSource implements CallbackUriSource {
  AppLinksCallbackUriSource({AppLinks? appLinks})
    : _appLinks = appLinks ?? AppLinks();

  final AppLinks _appLinks;

  @override
  Stream<Uri> get uris => _appLinks.uriLinkStream;
}
