# DAKit — DeviantArt 客户端 SDK

<p align="center">
  <img src="docs/icon.png" alt="DAKit" width="160" />
</p>

**语言 / Language:** 中文 · [English](README.en.md)

[![GitHub stars](https://img.shields.io/github/stars/redtidev1918/dakit?style=flat&color=yellow)](https://github.com/redtidev1918/dakit/stargazers)
[![GitHub license](https://img.shields.io/github/license/redtidev1918/dakit?style=flat)](LICENSE)
[![pub.dev](https://img.shields.io/pub/v/dakit_flutter?label=dakit_flutter&style=flat)](https://pub.dev/packages/dakit_flutter)
[![pub.dev](https://img.shields.io/pub/v/dakit_api?label=dakit_api&style=flat)](https://pub.dev/packages/dakit_api)
[![Docs](https://img.shields.io/badge/Docs-文档站点-6366f1?style=flat-square)](https://redtidev1918.github.io/dakit/)
[![pub.dev](https://img.shields.io/pub/v/dakit_core?label=dakit_core&style=flat)](https://pub.dev/packages/dakit_core)

DAKit 是面向 Dart 与 Flutter 的模块化 DeviantArt 客户端 SDK，为 Android、macOS 与 Windows 应用提供认证、官方 API、领域模型、诊断和后台传输能力。它既可以支撑完整的第三方客户端，也可以只作为其中一个功能模块使用。

本项目由社区独立维护，与 DeviantArt 没有隶属或背书关系。“DeviantArt”仅用于说明 SDK 所连接的服务。

> **参考实现 / Reference app**：完整的第三方客户端 [DAViewer](https://github.com/redtidev1918/daviewer) 就是基于 DAKit 构建的 —— 因 DeviantArt 官方放弃其 App 而诞生，是查看 DAKit 实际用法的最佳范例。

## 目录

- [能做什么](#能做什么)
- [开始前准备](#开始前准备)
- [包结构](#包结构)
- [安装](#安装)
- [命令行客户端](#命令行客户端)
- [最小示例](#最小示例)
- [文档](#文档)
- [开发](#开发)
- [设计底线](#设计底线)
- [许可证](#许可证)
- [参考与致谢](#参考与致谢)
- [社区 / Community](#社区--community)

## 能做什么

- 使用系统浏览器完成 Authorization Code + PKCE 登录；
- 安全保存 OAuth 会话，并在进程重启后恢复回调；
- 读取当前账户、用户资料与关系、作品详情与正文、首页/搜索、每日精选和关注动态；
- 浏览标签、标签补全、主题导航、画廊与收藏夹目录及目录内容；
- 读取「更多类似作品」预览，个别失效或异常的推荐不会影响其余结果；
- 读取/发布作品评论，收藏/取消收藏作品，关注/取消关注用户；
- 读取通知、反馈和 mentions，展开或删除消息堆栈；
- 从专用接口解析原文件，不把缩略图冒充原图；
- 在 Flutter 端排队、恢复、暂停、取消后台传输，并以失败保留记录的方式安全删除文件；
- 分别配置 API 与媒体代理，并定位 DNS、TCP、TLS、HTTP、OAuth、解析和存储故障；
- 通过稳定领域接口替换网络层、登录层、存储层或传输层。

目前尚未实现作品提交/编辑、Notes 私信和本地数据库。网站私有接口或页面抓取也不属于稳定 API。

## 开始前准备

运行任何登录、下载或诊断流程前，先确认下面几件事：

- 你需要一个 DeviantArt 开发者应用。客户端类程序（示例客户端、CLI、Android/macOS/Windows 应用）必须选 **Public**；只有把凭据安全保存在服务端时才选 **Confidential**。
- Public 应用只需要 `client_id`，不要使用或保存 `client_secret`；DAKit 的客户端登录流程不接收 secret。
- 回调地址必须精确写入应用的 OAuth2 Redirect URI Whitelist：
  - Flutter 示例客户端 / 桌面：`dakit://oauth/callback`
  - 命令行客户端：`http://127.0.0.1:8765/callback`
- 登录需要 `client_id`；下载可直接传作品网页链接、fav.me 短链或裸 UUID——
  `dakit url` 会把网页链接里的数字编号自动解析为 UUID。

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

包已发布到 pub.dev。完整 Flutter 集成只需依赖 `dakit_flutter`，它会自动解析
`dakit_api` 与 `dakit_core`：

```yaml
dependencies:
  dakit_flutter: ^0.1.12
```

如果只需要纯 Dart 能力，也可以按需声明：

```yaml
dependencies:
  dakit_core: ^0.1.15
  dakit_api: ^0.1.30
```

随后阅读[开始使用](docs/GETTING_STARTED.md)。直接在移动端或桌面端运行内置登录流程时，需要注册 **Public** OAuth 应用，并配置精确回调地址 `dakit://oauth/callback`。

## 命令行客户端

不需要安装 Dart 或 Flutter。直接从
[DAKit CLI Releases](https://github.com/redtidev1918/dakit/releases?q=dakit_cli)
下载与系统和 CPU 对应的压缩包：Linux x64/ARM64、Windows x64、macOS
Intel/Apple Silicon。macOS 二进制明确标记为**未签名测试版**，没有 Apple
Developer ID 签名或公证，Gatekeeper 可能拦截首次运行。每个 Release 同时提供
`SHA256SUMS`。

```text
dakit --help
dakit status --proxy 127.0.0.1:7892
dakit login --client-id 你的_PUBLIC_CLIENT_ID
dakit whoami
dakit url https://www.deviantart.com/loish/art/underwater-913624585 --dest downloads
dakit url https://fav.me/df3y58p --dest downloads
dakit url https://www.deviantart.com/loish/gallery --limit 50 --archive done.txt
dakit artist 用户名 --limit 24 --delay 0
dakit gallery 用户名 [gallery_id]
dakit fav 用户名 [folder_id]
dakit search "digital art" --limit 24
dakit logout
```

`url` 接受任意 DeviantArt 链接并自动识别目标：作品/日志页、fav.me 短链、
用户画廊、画廊/收藏夹、标签页和搜索链接都会路由到对应的下载逻辑（网页链接里的
数字编号会自动解析为 UUID）。批量下载还支持 `--archive 文件`（已下载 ID 跳过）、
`--filename 模板`（`{id}` `{title}` `{username}` `{published}` `{filename}` `{ext}`）
和 `--write-info-json`（每个作品旁写一份元数据 `.json`）。

登录前在 DeviantArt 注册 **Public** OAuth 应用，把
`http://127.0.0.1:8765/callback` 精确加入白名单。`login` 会打开系统浏览器并在
本机接收回调，不会要求 DeviantArt 密码进入 CLI。远程或无界面环境可另外加入
`dakit://oauth/callback`，再使用 `--manual --no-open`。

凭据保存到 `~/.config/dakit/`（Windows 为 `%APPDATA%/dakit/`），刷新令牌会自动
续期；`logout` 会撤销远端令牌，`logout --local` 只删除本地凭据。下载采用流式
临时文件，默认保留同名文件，需要替换时显式传入 `--overwrite`。

代理可通过 `--proxy HOST:PORT`、`--proxy http://HOST:PORT`、`http_proxy`、
`https_proxy` 或 HTTP 形式的 `all_proxy` 配置。`--verbose` / `-v` 会把脱敏诊断
输出到 `stderr`。CLI 只支持 HTTP 代理，不把 SOCKS5 静默当作 HTTP 使用。

下载与登录优先走官方 OAuth API；数字编号经网站公开的 `_puppy/dadeviation/init` 端点解析为 UUID（先读首页 CSRF 令牌）。CLI 只支持 HTTP 代理（不把 SOCKS5 静默当作 HTTP），不做预览画质切换或“防封”策略，官方接口支持原文件下载，CLI 不会用 preview 冒充 original。

### 成熟（年龄限制）多图作品

官方 OAuth API **看不到**成熟多图作品：`deviation/{uuid}` 会 404，也不返回附加页。但网站自己的 `_puppy/dadeviation/init` 端点在带上**登录网页 Cookie** 时会返回全部画面（主图 + 各附加页）。给 `url` 命令传 Cookie 即可完整下载：

```bash
dakit url <作品链接> --cookies 'auth=…; auth_secure=…; userinfo=…'
dakit url <作品链接> --cookies @~/da-cookies.txt       # 从文件读取
DAKIT_COOKIES='auth=…; auth_secure=…' dakit url <作品链接>  # 环境变量
```

在已登录的浏览器 DevTools（Application → Cookies）里复制 `auth` / `auth_secure` / `userinfo`。Cookie 属于敏感信息：绝不会写入日志（诊断对 `cookie`/`set-cookie` 脱敏，会话 `toString` 只显示是否存在/已登录标志）。不带 Cookie 时非成熟作品仍走 OAuth；成熟多图下载失败会提示加 `--cookies`。详见 `packages/dakit_cli/README.md`。

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

文档总览见 [docs/README.md](docs/README.md)（英文：[docs/en/README.md](docs/en/README.md)）。

**用户指南**（把 DAKit 嵌入自己的应用）：

- [开始使用](docs/GETTING_STARTED.md)：注册应用、运行示例、嵌入客户端；
- [认证](docs/AUTHENTICATION.md)：PKCE、平台回调、安全与排错；
- [网络](docs/NETWORKING.md)：代理模型、国内网络、分阶段诊断；
- [媒体](docs/MEDIA.md)：原文件、正文、后台任务与验收边界。

**开发与维护**（贡献者与维护者）：

- [架构](docs/ARCHITECTURE.md)：边界、扩展点、兼容策略；
- [开发](docs/DEVELOPMENT.md)：工具链、测试、三平台构建、CI、发布；
- [发布](docs/RELEASING.md)：包版本更新与 pub.dev 发布流程；
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

## 参考与致谢

DAKit 建立在以下开源项目之上：

- **[DeviantArt API](https://www.deviantart.com/developers/)** —— 所连接的官方服务与接口文档
- **[Flutter](https://flutter.dev)** / **[Dart](https://dart.dev)** —— 跨平台框架与语言
- **[dio](https://pub.dev/packages/dio)** —— HTTP 客户端（`dakit_api`、`dakit_cli`）
- **[crypto](https://pub.dev/packages/crypto)** —— PKCE 摘要（`dakit_api`、`dakit_cli`）
- **[flutter_secure_storage](https://pub.dev/packages/flutter_secure_storage)** —— 安全存储（OAuth 令牌）
- **[app_links](https://pub.dev/packages/app_links)** —— 深链回调
- **[url_launcher](https://pub.dev/packages/url_launcher)** —— 打开系统浏览器
- **[path_provider](https://pub.dev/packages/path_provider)** —— 本地路径
- **[background_downloader](https://pub.dev/packages/background_downloader)** —— 后台传输
- **[args](https://pub.dev/packages/args)** —— 命令行参数解析（`dakit_cli`）

接口映射与排错时参考的开源项目：

- **[gallery-dl](https://github.com/mikf/gallery-dl)** —— 记录了 DeviantArt 数据提取方式的下载器项目
- **[deviantart.ts](https://www.npmjs.com/package/deviantart.ts)** —— DeviantArt API 的 TypeScript 封装，用于核对接口参数

基于 DAKit 构建的完整客户端：[DAViewer](https://github.com/redtidev1918/daviewer)。

## 网络 / 出口要求（重要）

DeviantArt 会封锁「数据中心出口 IP」的网页与部分接口（WAF 按出口 IP 段放行）：

- **实测被拦**：Cloudflare Workers（网页 403、官方 API 数据面 500）、Fly.io（网页 403）及多数云主机；部分机房 IP 访问媒体变体（`/v1/fit|fill`）也返回 400/404。
- **可用的出口**：住宅网络实测全部正常；云服务器建议经 clash/mihomo 等代理走放行出口。
- 若网页端（`_puppy/dadeviation/init` 解析、作品页抓取）出现 403/400 且换 UA、加 Referer 无效，请先更换网络出口排查。
- **成熟 / NSFW**：匿名只能拿到打码预览（`blur_*` 变体），未打码原图需要登录（OAuth 或 Cookie）；原图走官方 `deviation/download/{uuid}`，受**免费账号每日下载额度**限制，超限返回 `Free download limit reached`，可降级取展示图或订阅 Core。

## 社区 / Community

- [贡献指南](CONTRIBUTING.md)
- [安全策略](SECURITY.md)
- [行为准则](CODE_OF_CONDUCT.md)

如果 DAKit 帮到了你，**点个 ⭐ Star** 能让更多需要它的人看到。
