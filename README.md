# DAKit — DeviantArt 客户端 SDK

DAKit 是面向 Dart 与 Flutter 的模块化 DeviantArt 客户端 SDK，为 Android、macOS 与 Windows 应用提供认证、官方 API、领域模型、诊断和后台传输能力。它既可以支撑完整的第三方客户端，也可以只作为其中一个功能模块使用。

本项目由社区独立维护，与 DeviantArt 没有隶属或背书关系。“DeviantArt”仅用于说明 SDK 所连接的服务。

## 能做什么

- 使用系统浏览器完成 Authorization Code + PKCE 登录；
- 安全保存 OAuth 会话，并在进程重启后恢复回调；
- 读取当前账户、用户资料与关系、作品详情与正文、首页/搜索、每日精选和关注动态；
- 浏览标签、标签补全、主题导航、画廊与收藏夹目录及目录内容；
- 读取/发布作品评论，收藏/取消收藏作品，关注/取消关注用户；
- 读取通知、反馈和 mentions，展开或删除消息堆栈；
- 从专用接口解析原文件，不把缩略图冒充原图；
- 在 Flutter 端排队、恢复、暂停和取消后台传输；
- 分别配置 API 与媒体代理，并定位 DNS、TCP、TLS、HTTP、OAuth、解析和存储故障；
- 通过稳定领域接口替换网络层、登录层、存储层或传输层。

目前尚未实现作品提交/编辑、Notes 私信和本地数据库。网站私有接口或页面抓取也不属于稳定 API。

## 包结构

| 包 | 用途 | Flutter 依赖 |
| --- | --- | --- |
| `dakit_core` | 模型、错误、仓库接口、分页、诊断、传输契约 | 无 |
| `dakit_api` | OAuth PKCE、网络配置、连通性检查、官方 API 实现 | 无 |
| `dakit_flutter` | 系统浏览器、深链、安全存储、后台传输 | 有 |
| `dakit_cli` | 纯 Dart 命令行登录、下载与诊断客户端 | 无 |
| `example_client` | Android/macOS/Windows 集成与故障诊断客户端 | 应用 |

依赖方向固定为 `dakit_flutter → dakit_api → dakit_core`。业务应用只依赖所需层；使用完整 Flutter 集成时依赖 `dakit_flutter` 即可。

## 安装

首次发布到 pub.dev 前，从 Git 仓库引用。由于三个包尚未发布，需要把
`dakit_flutter` 依赖的 `dakit_core` 与 `dakit_api` 一并显式声明，否则
`pub` 无法解析传递依赖：

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

随后阅读[开始使用](docs/GETTING_STARTED.md)。直接在移动端或桌面端运行内置登录流程时，需要注册 **Public** OAuth 应用，并配置精确回调地址 `dakit://oauth/callback`。

## 命令行客户端

不想先写 Flutter 界面时，可以用纯 Dart 的 `dakit_cli` 完成登录和单文件下载：

```shell
dart run packages/dakit_cli/bin/dakit.dart status --proxy 127.0.0.1:7892
dart run packages/dakit_cli/bin/dakit.dart login --client-id 你的_PUBLIC_CLIENT_ID --proxy 127.0.0.1:7892
dart run packages/dakit_cli/bin/dakit.dart download 作品UUID --output downloads --proxy 127.0.0.1:7892
```

`login` 会在本机 `8765` 端口起临时回调服务并打开系统浏览器，凭据保存到 `~/.config/dakit/credentials.json`（Windows 在 `%APPDATA%`）。CLI 的回调地址是 `http://127.0.0.1:8765/callback`，需要把它加入该 Public 应用的白名单。代理参数可省略，CLI 会遵循 `http_proxy` / `https_proxy` 环境变量。

## 最小示例

```dart
final diagnostics = MyDiagnosticSink();
final network = NetworkProfile.environment();
final oauth = DAKitOAuthClient(
  config: OAuthConfig(
    clientId: clientId,
    redirectUri: Uri.parse('dakit://oauth/callback'),
  ),
  networkProfile: network,
  diagnostics: diagnostics,
);

final restored = await oauth.resumePending();
final tokens = restored ?? await oauth.authorize();

final transport = OfficialApiClient(
  session: oauth.session,
  networkProfile: network,
  diagnostics: diagnostics,
);
final account = await OfficialAccountRepository(transport).currentUser();
```

`authorize()` 应由用户操作触发。应用启动时应尽早创建客户端并调用 `resumePending()`，以接收冷启动深链。

## 文档

- [开始使用](docs/GETTING_STARTED.md)：注册应用、运行示例、嵌入客户端；
- [架构](docs/ARCHITECTURE.md)：边界、扩展点、兼容策略；
- [认证](docs/AUTHENTICATION.md)：PKCE、平台回调、安全与排错；
- [网络](docs/NETWORKING.md)：代理模型、国内网络、分阶段诊断；
- [媒体](docs/MEDIA.md)：原文件、正文、后台任务与验收边界；
- [开发](docs/DEVELOPMENT.md)：工具链、测试、三平台构建、CI、发布；
- [真实服务测试](docs/LIVE_TESTING.md)：需用户授权的完整媒体矩阵；
- [当前状态](docs/STATUS.md)：已验证结果和后续工作。

## 开发

项目固定使用 Flutter 3.47.1 / Dart 3.13.1。运行完整质量门：

```shell
./tool/verify.sh
```

普通 CI 不包含 OAuth 凭据。当前单元测试、Android APK、macOS 应用和 Windows/MSIX 构建均已在 GitHub Actions 验证；真实账户媒体矩阵仍需有效的 Public OAuth 应用和测试素材。

## 设计底线

- 不在客户端保存 `client_secret`，不绕过人机验证；
- 不使用嵌入式 WebView 代替系统浏览器登录；
- 不关闭 TLS 校验，不在日志中输出令牌、授权码、Cookie 或 PKCE verifier；
- 不把上游 DTO、插件类型或具体状态管理框架暴露为公共领域 API；
- 不承诺自动适配任意网页改版，兼容性由集中式适配器与契约测试维护。

## 许可证

[MIT](LICENSE)
