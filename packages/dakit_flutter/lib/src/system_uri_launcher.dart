import 'package:dakit_core/dakit_core.dart';
import 'package:url_launcher/url_launcher.dart';

final class SystemUriLauncher implements ExternalUriLauncher {
  const SystemUriLauncher();

  @override
  Future<void> launch(Uri uri) async {
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched) {
      throw const DAKitException(
        kind: DAKitFailureKind.authentication,
        code: 'oauth.browser.launch_failed',
        message: 'The operating system could not open the authorization URL.',
      );
    }
  }
}
