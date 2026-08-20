# 开始使用

本文从零完成开发者应用注册、示例客户端运行和 SDK 嵌入。先准备 Flutter 3.47.1、Dart 3.13.1，以及目标平台工具链。

## 1. 注册开发者应用

在 DeviantArt 的应用管理页创建应用：

- Client type 选择 **Public**；
- OAuth2 Redirect URI Whitelist 填写 `dakit://oauth/callback`；
- Title、Description 和 Download URL 填写你自己的客户端信息；
- Original URLs Whitelist 仅用于 `original_url` 参数，与读取作品原文件无关，可在确有用途时填写。

Public 应用只会给客户端使用 `client_id`。`client_id` 是可出现在客户端中的应用标识，不是密码；access token 与 refresh token 则始终属于用户私密凭据。如果开发者后台同时签发 `client_secret`，该注册是 Confidential 应用，不适合直接运行在 APK、桌面应用或 Flutter 客户端内。不要把 secret 写进源码或构建参数，应另建 Public 应用。

回调地址必须完全一致，包括协议、主机、路径、大小写和末尾斜杠。当前示例固定使用：

```text
dakit://oauth/callback
```

## 2. 运行示例客户端

在仓库根目录获取依赖并检查环境：

```shell
flutter pub get
flutter doctor -v
./tool/verify.sh
```

macOS：

```shell
cd apps/example_client
flutter run -d macos --dart-define=DAKIT_CLIENT_ID=你的_PUBLIC_CLIENT_ID
```

Android：

```shell
cd apps/example_client
flutter run -d android --dart-define=DAKIT_CLIENT_ID=你的_PUBLIC_CLIENT_ID
```

Windows 需要安装 MSIX 才能由系统注册 `dakit` 协议；未打包的 EXE 不会修改用户注册表。构建命令见[开发文档](DEVELOPMENT.md)。

示例应用跟随系统语言显示中文或英文。它用于验证登录、账户、浏览、作品详情、原文件解析、后台任务和诊断，不是生产 UI 模板。

## 3. 嵌入 Flutter 应用

从仓库依赖 `dakit_flutter` 后，在 `runApp` 前创建 OAuth 客户端：

```dart
final oauth = DAKitOAuthClient(
  config: OAuthConfig(
    clientId: clientId,
    redirectUri: Uri.parse('dakit://oauth/callback'),
    scopes: const <String>{'basic', 'browse'},
  ),
  networkProfile: NetworkProfile.environment(),
  diagnostics: diagnosticSink,
);

final resumed = await oauth.resumePending();
runApp(ClientApp(oauth: oauth, restoredTokens: resumed));
```

在用户点击登录后执行：

```dart
final tokens = await oauth.authorize();
```

构建 API 仓库：

```dart
final api = OfficialApiClient(
  session: oauth.session,
  networkProfile: NetworkProfile.environment(),
  diagnostics: diagnosticSink,
);

final accountRepository = OfficialAccountRepository(api);
final artworkRepository = OfficialArtworkRepository(api);
final contentRepository = OfficialArtworkContentRepository(api);
final galleryRepository = OfficialGalleryRepository(api);
final mediaRepository = OfficialMediaRepository(api);
final commentRepository = OfficialCommentRepository(api);
final socialRepository = OfficialSocialRepository(api);
```

默认 scope 只有 `basic` 与 `browse`。需要写操作时，在首次授权前明确申请对应权限：

```dart
OAuthConfig(
  clientId: clientId,
  redirectUri: Uri.parse('dakit://oauth/callback'),
  scopes: const <String>{
    OAuthScope.basic,
    OAuthScope.browse,
    OAuthScope.collection,
    OAuthScope.commentPost,
    OAuthScope.userManage,
  },
)
```

修改 scope 后必须让用户重新授权；已有 token 不会自动获得新增权限。收藏需要 `collection`，发布评论需要 `comment.post`，关注管理需要 `user.manage`。

宿主应用自行决定 UI、状态管理、缓存和数据库。需要已有账户系统时，可以向 `OfficialApiClient` 提供自定义 `AuthTokenProvider`；需要企业网络栈时，可以注入配置好的 Dio；需要不同安全存储或深链实现时，可以替换 `DAKitOAuthClient` 的对应接口。

## 4. 注册平台回调

示例已经包含 Android、macOS 和 Windows/MSIX 配置。复制到自己的应用时，必须同步替换应用标识与回调协议：

- Android：为主 Activity 添加 browsable intent filter，并避免与 Flutter 默认深链处理冲突；
- macOS：在 `CFBundleURLTypes` 注册协议；
- Windows：在 MSIX manifest 注册协议，并将激活事件转交现有进程。

以示例平台工程为可执行参考，不要只复制 Dart 代码。完整生命周期与常见失败见[认证文档](AUTHENTICATION.md)。

## 5. 下一步

- 代理或国内网络：[网络与诊断](NETWORKING.md)；
- 正确区分预览、原文件和正文：[媒体与传输](MEDIA.md)；
- 测试、构建、发布：[开发与维护](DEVELOPMENT.md)；
- 当前尚未完成的真实服务验收：[真实服务测试](LIVE_TESTING.md)。
