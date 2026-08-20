import 'package:artrelay_flutter/artrelay_flutter.dart';
import 'package:flutter/widgets.dart';

import 'client_controller.dart';

/// Small, dependency-free application localization for the integration client.
///
/// SDK exceptions retain stable English developer messages and machine-readable
/// codes. User-facing text is localized here instead of changing SDK contracts.
final class AppStrings {
  const AppStrings._(this.zh);

  final bool zh;

  static AppStrings of(BuildContext context) => AppStrings._(
    Localizations.localeOf(context).languageCode.toLowerCase() == 'zh',
  );

  String t(String en, String zhCN) => zh ? zhCN : en;

  String get applicationTitle => t('DAKit Example', 'DAKit 示例客户端');
  String get clientTitle => t('DAKit integration client', 'DAKit 集成测试客户端');
  String get refreshAccount => t('Refresh account and home', '刷新账户和首页');
  String get signOut => t('Revoke session and sign out', '撤销授权并退出登录');
  String get authorize => t('Authorize in system browser', '在系统浏览器中授权');
  String get loginAgain => t('Start login again', '重新登录');
  String get retryApi => t('Retry API', '重试 API');
  String get runCheck => t('Run check', '重新检测');
  String get networkPath => t('Network path', '网络链路');
  String get diagnostics => t('Diagnostics', '诊断信息');
  String get diagnosticsPrivacy => t(
    'Secrets and authorization codes are never displayed.',
    '不会显示密钥、令牌或授权码。',
  );
  String get noDiagnostics => t('No diagnostic events yet.', '暂时没有诊断事件。');
  String get home => t('Home', '首页');
  String get noArtwork =>
      t('The home endpoint returned no artwork.', '首页接口没有返回作品。');
  String get closeDetail => t('Close detail', '关闭详情');
  String get artworkDetail => t('Artwork detail', '作品详情');
  String get loadingDetail =>
      t('Loading detail and original-file metadata…', '正在加载作品详情和原文件信息…');
  String get matureContent => t('Mature content', '敏感内容');
  String get noOriginal => t(
    'The official metadata does not provide a transferable original. Preview assets are never substituted.',
    '官方数据没有提供可传输的原文件；客户端不会用预览图冒充原文件。',
  );
  String get originalFile => t('Original file', '原文件');
  String get unnamedFile => t('Unnamed file', '未命名文件');
  String get availability => t('Availability', '可用状态');
  String get scheduling => t('Scheduling…', '正在创建任务…');
  String get downloadAgain => t('Download again', '再次下载');
  String get downloadOriginal => t('Download original', '下载原文件');
  String get transfer => t('Transfer', '传输任务');
  String get pause => t('Pause', '暂停');
  String get resume => t('Resume', '继续');
  String get cancel => t('Cancel', '取消');
  String get sizeUnknown => t('size unknown', '大小未知');
  String get remaining => t('remaining', '剩余');
  String get backgroundTransfers => t('Background transfers', '后台传输');
  String get transferPersistence => t(
    'Persisted and restored by the platform scheduler.',
    '由系统任务调度器持久化，并在重启后恢复。',
  );
  String get userId => t('User ID', '用户 ID');
  String get errorCode => t('Error code', '错误代码');

  String phaseTitle(ClientPhase phase, {required bool hasFailure}) =>
      switch (phase) {
        ClientPhase.configurationRequired =>
          hasFailure
              ? t('Network configuration is invalid', '网络配置无效')
              : t('Client ID is not configured', '尚未配置 Client ID'),
        ClientPhase.restoring => t('Restoring secure session', '正在恢复安全会话'),
        ClientPhase.signedOut => t('Ready to authorize', '可以开始授权'),
        ClientPhase.authorizing => t(
          'Waiting for browser callback',
          '正在等待浏览器回调',
        ),
        ClientPhase.loading => t('Loading account data', '正在加载账户数据'),
        ClientPhase.ready => t('Connected', '已连接'),
        ClientPhase.failure => t('Operation failed', '操作失败'),
      };

  String phaseMessage(
    ClientPhase phase, {
    required bool hasFailure,
    required int artworkCount,
  }) => switch (phase) {
    ClientPhase.configurationRequired =>
      hasFailure
          ? t(
              'Fix the proxy build defines and restart the example client.',
              '请修正代理启动参数，然后重启客户端。',
            )
          : t(
              'Pass the Public Client ID at build time. No client secret is used.',
              '请在启动时传入 Public Client ID；Public Client 不使用 client secret。',
            ),
    ClientPhase.restoring => t(
      'Checking secure storage and a possible cold-start callback.',
      '正在检查安全存储以及应用冷启动收到的 OAuth 回调。',
    ),
    ClientPhase.signedOut => t(
      'Authorization opens the real system browser and returns through dakit://oauth/callback.',
      '授权将在系统浏览器中进行，并通过 dakit://oauth/callback 返回客户端。',
    ),
    ClientPhase.authorizing => t(
      'Complete authorization in the browser. This screen updates automatically after the operating system delivers the callback.',
      '请在浏览器中完成授权。操作系统送达回调后，本页面会自动更新。',
    ),
    ClientPhase.loading => t(
      'The session is valid; requesting account and home data.',
      '会话有效，正在请求账户和首页数据。',
    ),
    ClientPhase.ready => t(
      '$artworkCount home items loaded.',
      '已加载 $artworkCount 个首页作品。',
    ),
    ClientPhase.failure => t(
      'The error code and diagnostic timeline below identify the failed stage.',
      '下方错误代码和诊断时间线会标明具体失败阶段。',
    ),
  };

  String failureMessage(ArtRelayException failure) => switch (failure.kind) {
    ArtRelayFailureKind.configuration => t(
      'The client configuration is invalid.',
      '客户端配置无效。',
    ),
    ArtRelayFailureKind.authentication => t(
      'Authentication could not be completed.',
      '登录认证未能完成。',
    ),
    ArtRelayFailureKind.authorization => t(
      'The account did not grant the required access.',
      '账户未授予所需权限。',
    ),
    ArtRelayFailureKind.network => t(
      'The network request could not be completed.',
      '网络请求未能完成。',
    ),
    ArtRelayFailureKind.storage => t(
      'Secure credential storage could not be accessed.',
      '无法访问系统安全凭据存储。',
    ),
    ArtRelayFailureKind.parsing => t(
      'The service response format was not recognized.',
      '无法识别服务端响应格式。',
    ),
    ArtRelayFailureKind.rateLimit => t(
      'Too many requests. Try again later.',
      '请求过于频繁，请稍后重试。',
    ),
    ArtRelayFailureKind.notFound => t(
      'The requested resource was not found.',
      '没有找到请求的资源。',
    ),
    ArtRelayFailureKind.restricted => t(
      'The requested resource is restricted.',
      '请求的资源受到访问限制。',
    ),
    ArtRelayFailureKind.transfer => t('The file transfer failed.', '文件传输失败。'),
    ArtRelayFailureKind.cancelled => t(
      'The operation was cancelled.',
      '操作已取消。',
    ),
    ArtRelayFailureKind.upstream => t(
      'An unexpected service error occurred.',
      '服务发生意外错误。',
    ),
  };

  String failureHint(ArtRelayException failure) => switch (failure.kind) {
    ArtRelayFailureKind.configuration => t(
      'Check the client ID and exact redirect whitelist.',
      '请检查 Client ID，以及完全匹配的重定向 URI 白名单。',
    ),
    ArtRelayFailureKind.authentication ||
    ArtRelayFailureKind.authorization => t(
      'Check browser completion, callback delivery, state, and provider access.',
      '请检查浏览器授权是否完成、系统是否送达回调、state 是否匹配及账户授权状态。',
    ),
    ArtRelayFailureKind.network => t(
      'Check DNS, TLS, proxy selection, and whether the service is reachable.',
      '请检查 DNS、TLS、代理选择以及服务是否可访问。',
    ),
    ArtRelayFailureKind.storage => t(
      'Check Keychain, Keystore, or Windows credential storage access.',
      '请检查 macOS Keychain、Android Keystore 或 Windows 凭据存储权限。',
    ),
    ArtRelayFailureKind.parsing => t(
      'The upstream response no longer satisfies a required SDK contract.',
      '上游响应可能已发生变化，不再满足 SDK 所需的数据契约。',
    ),
    _ => t(
      'Use the diagnostic event codes below to locate the failing stage.',
      '请根据下方诊断事件代码定位失败阶段。',
    ),
  };

  String availabilityLabel(MediaAvailability value) => switch (value) {
    MediaAvailability.available => t('Original allowed', '允许获取原文件'),
    MediaAvailability.loginRequired => t('Login required', '需要登录'),
    MediaAvailability.purchaseRequired => t('Purchase required', '需要购买'),
    MediaAvailability.restricted => t('Restricted', '访问受限'),
    MediaAvailability.unavailable => t('Preview only', '仅有预览'),
    MediaAvailability.missing => t('Original missing', '没有原文件'),
  };
}
