import 'package:artrelay_core/artrelay_core.dart';

final class OAuthConfig {
  OAuthConfig({
    required this.clientId,
    required this.redirectUri,
    this.scopes = const <String>{'basic', 'browse'},
    Uri? authorizationEndpoint,
    Uri? tokenEndpoint,
  }) : authorizationEndpoint =
           authorizationEndpoint ??
           Uri.https('www.deviantart.com', '/oauth2/authorize'),
       tokenEndpoint =
           tokenEndpoint ?? Uri.https('www.deviantart.com', '/oauth2/token') {
    if (clientId.trim().isEmpty) {
      throw const ArtRelayException(
        kind: ArtRelayFailureKind.configuration,
        code: 'oauth.client_id.empty',
        message: 'OAuth client ID must not be empty.',
      );
    }
    if (!redirectUri.hasScheme || redirectUri.hasFragment) {
      throw const ArtRelayException(
        kind: ArtRelayFailureKind.configuration,
        code: 'oauth.redirect.invalid',
        message: 'OAuth redirect URI must have a scheme and no fragment.',
      );
    }
  }

  final String clientId;
  final Uri redirectUri;
  final Set<String> scopes;
  final Uri authorizationEndpoint;
  final Uri tokenEndpoint;
}
