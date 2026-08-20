# DAKit

DAKit 是一个异步 Python 库，用来给第三方 DeviantArt 客户端提供认证、内容访问和基础设施边界。

项目目前是 `1.0.0a1`。这是预览版本：公开接口仍可能变化，部分能力只有单元测试，尚未完成真实账号的端到端验证。它不是完整 App，也不是通用下载器。

## 现在能做什么

| 能力 | 状态 | 数据来源 |
|---|---|---|
| Public OAuth 2.1 / PKCE | 已实现，真实账号待验证 | 官方 OAuth |
| Token 保存、状态检查、刷新 | 已实现，真实账号待验证 | 官方 OAuth API |
| 根据作品 URL 读取公开作品 | 已实测 | 官方 API 优先，网页回退 |
| 读取用户资料 | 实验性 | 官方 API |
| 读取用户 Gallery | 实验性 | 官方 API |
| 搜索 | 实验性，不保证可用 | 旧的 `/browse/newest` 入口 |
| 媒体地址与流式读取 | 已实现基础接口 | 作品响应中的媒体地址 |
| 原文件下载 | 未实现 | 官方 `/deviation/download/{id}` 尚未接入 |
| 收藏、关注、评论、Feed、通知、消息 | 未实现 | — |
| Token revoke | 未实现 | `logout()` 当前只删除本地 Token |

“实验性”表示代码入口已经存在，但还没有使用真实 OAuth 账号完成契约验证。DAKit 不会把这些能力描述成生产可用。

## 安装

DAKit 尚未发布到 PyPI。请直接从 GitHub 安装：

```bash
python -m pip install \
  'dakit @ git+https://github.com/redtidev1918/dakit.git'
```

本地开发：

```bash
git clone https://github.com/redtidev1918/dakit.git
cd dakit
python -m pip install -e '.[dev]'
```

要求 Python 3.10 或更高版本。

## 注册 DeviantArt 应用

在 DeviantArt 的应用管理页面注册应用时：

- Client type 选择 **Public**。
- Redirect URI 填写客户端能够接收的回调，例如 `myapp://oauth/callback`。
- DAKit 默认申请 `basic browse` 两个 scope。
- Public Client 没有、也不应保存 `client_secret`。

新注册的 DeviantArt 应用使用 OAuth 2.1。Authorization Code 流程必须使用 PKCE，且只允许 `S256`。授权请求和 Token 请求中的 Redirect URI 必须与白名单完全一致。

## 创建客户端

```python
from dakit import DAKit, PublicOAuthConfig
from dakit.adapters import JsonTokenStore

kit = DAKit(
    PublicOAuthConfig(
        client_id="your-public-client-id",
        redirect_uri="myapp://oauth/callback",
    ),
    token_store=JsonTokenStore(),
)
```

`DAKit` 是组合根。一个实例包含共享的 OAuth 状态、网络传输和内容适配器，通常应跟随一个登录账号长期存在。

使用库自带网络层时，应关闭实例：

```python
async with DAKit(oauth_config, token_store=token_store) as kit:
    artwork = await kit.content.artwork_url(artwork_url)
```

调用方传入 `transport=` 时，Transport 的生命周期仍归调用方所有，`DAKit.close()` 不会关闭它。

## 登录

DAKit 不控制 UI，也不在核心库中启动浏览器。宿主负责打开系统浏览器并接收回调。

```python
request = kit.auth.begin()

# 由 Android、iOS、桌面框架或 Web 宿主完成：
await host.open_system_browser(request.url)

# 宿主收到 myapp://oauth/callback?code=...&state=... 后：
state = await kit.auth.complete(request, callback_url)

print(state.authenticated)
print(state.username)
```

`begin()` 会生成：

- 随机 OAuth `state`
- 43–128 字符范围内的 `code_verifier`
- `BASE64URL(SHA256(code_verifier))` 形式的 challenge
- `code_challenge_method=S256`

`complete()` 会校验回调中的 `state`，使用授权码和 verifier 交换 Token，然后调用官方 `user/whoami` 确认账号。

`AuthorizationRequest` 中的 verifier 是短期敏感值。宿主必须在授权完成前保存同一个对象，不能记录到日志，也不能在进程重启后随意复用。

### Token 生命周期

```python
state = await kit.auth.status()
tokens = await kit.auth.refresh()
kit.auth.logout()
```

- DeviantArt 当前文档说明 Access Token 有效期为一小时。
- Refresh Token 当前文档说明有效期为三个月，之后需要用户重新授权。
- `status()` 遇到已过期 Access Token 时会尝试刷新。
- `logout()` 只清除内存和 `TokenStore`；当前版本没有调用官方 `/oauth2/revoke`。

`JsonTokenStore` 会将 Token 写入 `~/.config/dakit/tokens.json`，文件权限设置为 `0600`。它适合 CLI 和本地调试，不适合正式移动端产品。生产宿主应实现 `TokenStore`，连接 Keychain、Android Keystore、Windows Credential Manager 或自己的服务端安全存储。

## 读取内容

### 作品 URL

```python
artwork = await kit.content.artwork_url(
    "https://www.deviantart.com/artist/art/example-123456"
)

print(artwork.id)
print(artwork.title)
print(artwork.author)
print(artwork.kind)
```

`artwork_url()` 从 URL 末尾提取数字 ID。它先调用 `OfficialAPI`；官方调用失败时，如果提供了完整 URL，则尝试解析公开作品页面。

也可以直接使用 ID：

```python
artwork = await kit.content.artwork("123456")
```

直接传 ID 时没有网页 URL，因此默认网页适配器无法回退。

### 用户资料

```python
user = await kit.content.user("username")
```

该调用目前只走官方 `/user/profile/{username}`。网页适配器不会伪造用户资料。

### Gallery 与分页

```python
page = await kit.content.gallery("username", limit=24)

for artwork in page.items:
    print(artwork.title)

while page.has_more:
    page = await kit.content.gallery(
        "username",
        cursor=page.cursor,
        limit=24,
    )
```

目前 `Page.cursor` 同时承载官方 API 的 `next_offset` 字符串。Gallery 的官方最大 `limit` 是 24；DAKit 当前不会在本地提前截断超出范围的值，错误将由远端 API 返回。

### 搜索

```python
page = await kit.content.search("landscape", limit=24)
```

此入口目前调用 `/browse/newest?q=...`。DeviantArt 最新 API 目录不再列出 Browse Newest，但官方分页指南仍保留相关示例。因此该能力被标记为实验性，不应作为生产客户端的稳定搜索接口。

## 媒体

作品中的媒体通过 `Artwork.media` 暴露：

```python
for media in artwork.media:
    print(media.kind, media.width, media.height)
    print(media.original, media.restricted)
```

字段含义：

- `original=True`：官方作品响应把该地址标记为 download；不等同于 DAKit 已调用原文件下载 API。
- `restricted=True`：当前地址是网页返回的模糊占位资源，例如 URL 含 `blur_30`。
- `mime_type`、尺寸可能为空，调用方必须容忍缺失值。

不要把 `restricted=True` 的资源报告为下载成功，也不要根据文件扩展名猜测真实内容类型。成熟内容能否访问取决于账号年龄、账号设置、授权状态、作品权限以及 DeviantArt 返回的数据。

流式读取可用媒体：

```python
media = artwork.media[0]
if media.restricted:
    raise RuntimeError("the account cannot access this media")

async for chunk in kit.transport.stream(media.url):
    await destination.write(chunk)
```

DAKit 当前不提供文件命名、落盘或批量下载管理。这些属于宿主的缓存或媒体层。

## 数据来源与回退

默认适配器顺序是：

```text
OfficialAPI
    │  RemoteError / SchemaChangedError
    ▼
WebsiteFallback
```

可以检查最近一次调用实际使用了哪个适配器：

```python
print(kit.content.last_adapter)
print(kit.content.last_failures)
```

网页适配器不是“自动理解未来网页”的通用解析器。当前实现只读取公开作品页中的 `window.__INITIAL_STATE__` 或 `__NEXT_DATA__` 状态信封。页面结构变化时会抛出 `SchemaChangedError`，不会用空数据伪装成功。

官方 API 同样可能变化。DeviantArt 支持 `dA-minor-version` 请求头，并建议发布客户端时固定 minor version；当前 `OfficialAPI` 尚未固定该请求头，因此会接收最新响应版本。这是预览版的已知风险。

## 嵌入其他客户端

核心依赖通过 Protocol 定义，宿主可以替换网络、Token 存储和内容来源：

```python
kit = DAKit(
    oauth_config,
    transport=my_transport,
    token_store=my_token_store,
    sources=(primary_source, fallback_source),
)
```

### `Transport`

负责普通请求、流式读取和关闭。可以用来接入代理、缓存、证书固定、遥测或原生网络桥接。

### `TokenStore`

```python
class TokenStore:
    def load(self) -> TokenSet | None: ...
    def save(self, tokens: TokenSet) -> None: ...
    def clear(self) -> None: ...
```

### `ContentSource`

实现 `artwork`、`user`、`gallery` 和 `search` 后，可以替换官方适配器、增加缓存层或临时适配网站变化。每个 Source 必须提供可读的 `name`。

Flutter、Android 或 iOS 不能直接导入 Python 包时，需要由宿主提供进程内 Python 运行时、FFI 包装或独立 HTTP Bridge。DAKit 当前没有内置 Flutter Bridge。

## 错误处理

| 异常 | 含义 |
|---|---|
| `AuthenticationError` | Token 缺失、过期或被拒绝 |
| `TransportError` | 超时或底层网络失败 |
| `RemoteError` | 远端返回错误，或所有适配器都失败 |
| `SchemaChangedError` | 响应不再满足适配器预期结构 |

```python
from dakit import AuthenticationError, RemoteError, SchemaChangedError

try:
    artwork = await kit.content.artwork_url(url)
except AuthenticationError:
    await host.request_login()
except SchemaChangedError as error:
    telemetry.report(error.adapter, error.detail)
except RemoteError as error:
    host.show_error(str(error))
```

内置 `HttpxTransport` 只对网络超时和 HTTPX Transport Error 做有限指数退避。它目前不会自动重试官方建议重试的 `429`、`500` 或 `503`，也不会读取 `Retry-After`。高流量客户端应提供自己的 Transport 或在上层实现退避。

DeviantArt 要求 API 客户端发送 User-Agent 并使用 HTTP 压缩。HTTPX 默认适配器发送 `User-Agent: dakit/1`，HTTPX 会协商压缩响应。

## 架构

```text
src/dakit/
├── core/
│   ├── models.py       # Artwork、User、Media、TokenSet、Page
│   └── errors.py       # 稳定异常层级
├── ports.py            # Transport、TokenStore、ContentSource
├── adapters/
│   ├── official.py     # 官方 OAuth API
│   ├── website.py      # 公开作品页回退
│   ├── httpx.py        # 默认网络实现
│   └── tokens.py       # 本地 JSON Token 存储
├── auth.py             # Public OAuth + PKCE
├── client.py           # DAKit 组合根与 AdaptiveContent
└── cli.py              # 调试 CLI
```

依赖方向是 `core <- ports <- adapters/application`。核心模型不导入 HTTPX、文件系统、浏览器或 DeviantArt 原始响应结构。

## CLI

CLI 是调试工具，不是面向普通用户的完整客户端：

```bash
dakit login
dakit status
dakit artwork 'https://www.deviantart.com/user/art/title-123'
dakit gallery username --limit 24
dakit search landscape --limit 24
dakit logout
```

CLI 内置一个 Public Client ID，不包含 secret。可通过环境变量覆盖：

```bash
export DAKIT_CLIENT_ID='your-client-id'
export DAKIT_REDIRECT_URI='myapp://oauth/callback'
```

如果系统没有注册 `dakit://` 协议处理器，授权后浏览器可能显示无法打开。复制地址栏中的完整回调 URL，粘贴回 CLI 即可。

## 开发与验证

```bash
python -m pip install -e '.[dev]'
ruff check src tests
mypy src
pytest
python -m build
```

测试使用替换 Transport，不会访问真实账号。仓库另外做过一次公开作品页和媒体流验证，但成熟内容样本只返回了 18,396 字节的模糊占位图；该结果不能证明原文件下载可用。

## 已知限制

- 尚未用真实账号完成 PKCE、刷新、Profile 和 Gallery 的端到端测试。
- `logout()` 未调用官方 revoke。
- 官方 API minor version 尚未固定。
- Profile 适配器和最新官方响应结构仍需真实响应验证。
- Search 依赖未出现在最新参考目录中的旧入口。
- 网页回退只支持公开作品详情。
- 文学正文、原文件下载、社交写操作、Feed、通知与消息均未实现。
- 当前没有并发 Token 刷新锁，多请求同时遇到过期 Token 时可能重复刷新。

## DeviantArt 官方资料

- [Authentication and PKCE](https://deviantart.readme.io/docs/authentication)
- [API errors and adaptive rate limits](https://deviantart.readme.io/docs/errors)
- [API versioning](https://deviantart.readme.io/docs/versioning)
- [Pagination](https://deviantart.readme.io/docs/pagination)
- [API reference](https://deviantart.readme.io/reference)
- [Application registration](https://www.deviantart.com/developers/register)
- [API License Agreement](https://www.deviantart.com/about/policy/api/)

DAKit 与 DeviantArt 没有官方关联。使用本项目时，调用方负责遵守 DeviantArt API License、服务条款、用户授权和作品版权要求。

## License

MIT
