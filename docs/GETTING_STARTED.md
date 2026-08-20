# 开始使用

本文从零完成开发者应用注册、示例客户端运行和 SDK 嵌入。先准备 Flutter 3.47.1、Dart 3.13.1，以及目标平台工具链。

## 1. 注册开发者应用

在 DeviantArt 的应用管理页创建应用。先根据程序的部署方式选择 Client type：

| 部署方式 | Client type | 客户端凭据 | DAKit 接入方式 |
| --- | --- | --- | --- |
| Flutter Android、macOS、Windows 或其他用户设备上的应用 | **Public** | `client_id` | 使用 DAKit 内置 Authorization Code + PKCE 登录 |
| 能安全保存凭据的自有后端 | **Confidential** | `client_id` + `client_secret` | 在后端完成认证；客户端通过自定义 `AuthTokenProvider` 接入会话 |

本仓库的示例客户端直接在用户设备上登录，因此应选择 **Public**。然后填写：

- OAuth2 Redirect URI Whitelist 填写 `dakit://oauth/callback`；
- Title、Description 和 Download URL 填写你自己的客户端信息；
- Original URLs Whitelist 仅用于 `original_url` 参数，与读取作品原文件无关，可在确有用途时填写。

凭据名称容易混淆：

- `client_id` 是开发者应用的公开标识；
- `client_secret` 是 Confidential 应用的长期机密，不是用户 token；
- `access_token` 和 `refresh_token` 是用户授权完成后签发的会话凭据。

如果应用管理页同时显示 `client_id` 和 `client_secret`，当前注册就是 **Confidential**。它可以保留给后端使用，但不能把 secret 编译进 APK、EXE 或 macOS 应用。要运行本仓库的示例客户端，请另外创建一个 Public 应用；Public 注册只需要把 `client_id` 传给 DAKit。

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

### 命令行客户端

如果暂时不需要图形界面，可以直接使用 `dakit_cli`：

```shell
dart run packages/dakit_cli/bin/dakit.dart status --proxy 127.0.0.1:7892
dart run packages/dakit_cli/bin/dakit.dart login --client-id 你的_PUBLIC_CLIENT_ID --proxy 127.0.0.1:7892
dart run packages/dakit_cli/bin/dakit.dart download 作品UUID --output downloads --proxy 127.0.0.1:7892
```

CLI 登录使用 loopback 回调 `http://127.0.0.1:8765/callback`，需要在 Public 应用白名单中精确加入该地址。凭据会保存到本机 `~/.config/dakit/credentials.json`（Windows 为 `%APPDATA%/dakit/credentials.json`），下载完成后 CLI 会输出保存路径、字节数、SHA-256 和媒体类型。

## 3. 嵌入 Flutter 应用

首次发布到 pub.dev 前，需要从 Git 仓库显式声明三个包；否则
`dakit_flutter` 尚未发布的传递依赖 `dakit_core` / `dakit_api` 无法解析：

```yaml
dependencies:
  dakit_core:
    git:
      url: https://github.com/redtidev1918/dakit.git
      path: packages/dakit_core
  dakit_api:
    git:
      url: https://github.com/redtidev1918/dakit.git
      path: packages/dakit_api
  dakit_flutter:
    git:
      url: https://github.com/redtidev1918/dakit.git
      path: packages/dakit_flutter
```

随后在 `runApp` 前创建 OAuth 客户端：

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
final userRepository = OfficialUserRepository(api);
final userLookupRepository = OfficialUserLookupRepository(api);
final artworkRepository = OfficialArtworkRepository(api);
final discoveryRepository = OfficialDiscoveryRepository(api);
final contentRepository = OfficialArtworkContentRepository(api);
final galleryRepository = OfficialGalleryRepository(api);
final folderRepository = OfficialFolderRepository(api);
final mediaRepository = OfficialMediaRepository(api);
final commentRepository = OfficialCommentRepository(api);
final socialRepository = OfficialSocialRepository(api);
final messageRepository = OfficialMessageRepository(api);
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
    OAuthScope.message,
    OAuthScope.user,
    OAuthScope.userManage,
  },
)
```

修改 scope 后必须让用户重新授权；已有 token 不会自动获得新增权限。收藏需要 `collection`，发布评论需要 `comment.post`，通知与反馈中心需要 `message`，检查当前账户是否关注某用户需要 `user`，关注管理需要 `user.manage`。

`dakit_core` 和 `dakit_api` 提供可组合的领域与网络能力，`dakit_flutter` 提供常用平台集成。已有账户后端可以向 `OfficialApiClient` 提供自定义 `AuthTokenProvider`；企业网络环境可以注入配置好的 Dio；安全存储、深链和后台任务也有独立替换接口。

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
