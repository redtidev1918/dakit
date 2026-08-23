# 架构与扩展边界

DAKit 为第三方 Flutter 客户端提供分层 SDK。公共层描述稳定的领域能力，登录、HTTP、平台插件和示例 UI 分别位于可替换的实现边界。

## 依赖结构

```text
宿主应用 / example_client
          │
          ├─────────────── 自定义 UI、状态、缓存、数据库
          │
          ▼
    dakit_flutter ─────── 系统浏览器、深链、安全存储、后台任务
          │
          ▼
      dakit_api ───────── OAuth、网络策略、官方 API 适配器
          │
          ▼
     dakit_core ───────── 模型、错误、仓库、诊断、传输契约

    dakit_cli ─────────── 纯 Dart 命令行 kit（依赖 api/core，不依赖 Flutter）
```

`dakit_core` 不依赖 Flutter 或网络库；`dakit_api` 只使用 Dart 能力；`dakit_flutter` 才依赖平台插件；`dakit_cli` 是纯 Dart 的调试与批量下载工具。依赖只能向下，领域层永远不引用实现层。

## 每层职责

### `dakit_core`

- 稳定领域模型与分页值；
- 账户、用户资料、作品、发现流、目录、正文、媒体、评论和社交操作仓库接口；
- `AuthTokenProvider`、token/pending store 接口；
- `TransferManager` 与任务快照；
- `DAKitException`、故障分类和脱敏诊断事件。

这一层适合领域测试、离线缓存包装器和非 Flutter Dart 客户端。

### `dakit_api`

- PKCE 事务、回调验证、token exchange/refresh/revoke；
- 可替换的 OAuth endpoint 与官方 API transport；
- 环境、直连、显式 HTTP 代理和 Dio 注入；
- 当前已实现的账户、用户资料与关注关系、批量用户查询、作品、正文、首页/搜索、每日精选、关注动态、标签/主题导航、画廊/收藏夹目录与内容、原文件、评论、社交操作和消息中心仓库；
- 上游 JSON 到稳定领域模型的私有映射。

DTO 不从顶层库导出。官方响应新增未知字段不应破坏解析；必需字段消失时必须抛出明确 parsing failure。

`OfficialApiTransport` 提供读取扩展点，`OfficialApiMutationTransport` 额外提供统一的 URL-encoded POST。GET 会按配置退避重试 429/500/503；非幂等 POST 只会在 401 后刷新一次 token，不会自动重试可能已生效的写操作。

### `dakit_flutter`

- `DAKitOAuthClient` 组合常用登录生命周期；
- 系统浏览器、`app_links`、`flutter_secure_storage` 适配器；
- `BackgroundTransferManager` 平台后台传输实现。

它不提供页面、主题或状态管理依赖。宿主可以替换每个接口而无需 fork。

### `example_client`

这是可运行的集成探针：验证平台回调、网络诊断、账户/浏览、原文件解析和任务恢复。它不是 SDK 公共 API，也不是推荐的产品架构。

它用 `ClientRuntime` 作为组合根，把 OAuth、transport、仓库、连通性和传输任务集中装配后注入控制器，`main.dart` 只负责选择和启动 UI，避免散落构造代码。页面底部还提供 `DebugConsole`，通过 `runConsoleCommand` 调用控制器能力，便于在 UI 内排查问题。

### `dakit_cli`

命令行 kit 面向开发者调试、批量下载和脚本化使用。它按模块拆分：

- `cli.dart`：命令解析与分发；
- `cli_session.dart`：文件 token/config store、自动刷新会话、`CliContext`；
- `cli_networking.dart`：代理解析、流式下载器、UUID/文件名工具；
- `cli_platform.dart`：系统浏览器、loopback/粘贴回调；
- `cli_diagnostics.dart`：`--verbose` 诊断输出。

CLI 不依赖 Flutter 插件，可编译成自包含原生二进制供终端用户直接下载。它与
`dakit_flutter` 一样通过系统浏览器登录，不接触用户密码；macOS 二进制的签名状态
必须在资产名称和 Release 中明确标注。

## 解耦方式

| 宿主需求 | 扩展点 |
| --- | --- |
| 已有账户系统 | 实现 `AuthTokenProvider`，直接构造 `OfficialApiClient` |
| 自定义 Keychain/Keystore | 实现 `TokenStore`、`PendingAuthorizationStore` |
| 企业 PAC、VPN、证书固定 | 注入已配置的 Dio，不再传 `NetworkProfile` |
| 自定义浏览器或 HTTPS 回调 | 实现 `ExternalUriLauncher`、`CallbackUriSource` |
| 本地缓存/离线优先 | 包装 repository 接口，保持领域模型不变 |
| 不同后台任务框架 | 实现 `TransferManager` |
| Riverpod/Bloc/Redux | 只在宿主层绑定 repository，不进入 SDK |

## 上游变化策略

“自动适应网站所有更新”不是可验证承诺。稳定做法是缩小变化面：

1. 优先使用有版本的官方 API；
2. API 版本 header、base URI 和重试策略集中配置；
3. 上游 DTO 保持私有，映射到 SDK 模型；
4. 接受新增字段，对缺失必需字段给出可诊断失败；
5. 用官方 schema 派生的 fixture 做契约测试；
6. 用可选真实服务测试发现授权、策略和 schema 漂移；
7. 若未来加入网页兼容层，必须作为独立可选适配器，不能污染官方 API 包；
8. 对易变的响应子段做宽容解析：形状漂移时降级为空（例如
   `morelikethis/preview` 的收藏集分组），不让次要数据拖垮主内容，契约测试负责暴露漂移。

## 安全边界

- 只在外部系统浏览器登录，不自动填写凭据或绕过验证；
- Public Client 不接收、不保存 `client_secret`；
- TLS 验证不可通过 DAKit 公共 API 关闭；
- provider HTML/Markdown/CSS 是惰性数据，宿主渲染前自行清理；
- 诊断只记录安全字段，传输任务不携带 bearer token；
- 普通 CI 无账户凭据、代理密码或签名密钥。

## 版本与新增功能

三个包按语义化版本独立发布。新增通知、消息、提交作品等能力时，先在 core 增加最小领域契约，再在 api 实现官方适配器，最后由 Flutter/example 验证平台交互。不要直接从页面组件调用未封装 endpoint。
