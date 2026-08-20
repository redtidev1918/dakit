# DAKit

DAKit 是用于构建第三方艺术社区客户端的异步 Python 内核。1.x 是一次破坏性重写，不兼容旧下载器 API，也不保留旧登录方式。

它提供稳定领域模型、Public OAuth + PKCE、官方 API 适配器、网站只读回退和可替换基础设施。Flutter、桌面、移动端、Web 后端或机器人负责 UI 与平台生命周期。

## 设计边界

```text
Host application
      │
    DAKit ── Public OAuth + PKCE
      │
AdaptiveContent
  ├─ OfficialAPI（首选）
  └─ WebsiteFallback（有限只读降级）
      │
Transport · TokenStore · ContentSource
```

- `core`：稳定且不可变的领域对象，不依赖 HTTP、文件系统或浏览器。
- `ports`：宿主可实现的 `Transport`、`TokenStore`、`ContentSource`。
- `adapters`：官方 API、网站回退、HTTPX 和本地 Token 存储。
- `auth`：只实现适合公开客户端的 Authorization Code + PKCE。
- `client`：组合根与官方优先的自适应内容网关。
- `cli`：薄调试宿主；浏览器行为不会进入核心库。

旧版 `DeviantArtClient`、Cookie 登录、Confidential OAuth、localhost 回调、旧门面方法和下载器专用对象均已删除。

## 网站变化策略

不存在能够保证“自动适应任意网站更新”的解析器。DAKit 采用可维护的容错策略：

1. 优先调用版本更稳定的官方 OAuth API。
2. 只有公开作品详情可以回退到网站适配器。
3. 网站适配器支持多个状态信封，并把远端数据转换为稳定模型。
4. 契约不匹配时抛出 `SchemaChangedError`，包含适配器和失败位置。
5. `last_adapter` 和 `last_failures` 让宿主能够上报遥测并发现远端变更。
6. 宿主可以注入新的 `ContentSource`，无需修改 UI 或领域层。

不会静默吞掉解析错误，也不会用空对象伪装成功。

## 安装

尚未发布到 PyPI，请从 GitHub 安装：

```bash
pip install 'dakit @ git+https://github.com/redtidev1918/dakit.git'
```

本地开发：

```bash
git clone https://github.com/redtidev1918/dakit.git
cd dakit
python -m pip install -e '.[dev]'
pytest
```

需要 Python 3.10 或更高版本。

## Public OAuth + PKCE

Public Client 不应包含 `client_secret`。宿主打开授权 URL、接收自定义 URI，然后把完整回调交回 DAKit：

```python
from dakit import DAKit, PublicOAuthConfig

kit = DAKit(
    PublicOAuthConfig(
        client_id="your-public-client-id",
        redirect_uri="yourapp://oauth/callback",
    ),
    token_store=platform_token_store,
)

request = kit.auth.begin()
await platform.open_browser(request.url)

# 平台收到 yourapp://oauth/callback?... 后：
state = await kit.auth.complete(request, callback_url)
print(state.username)
```

DAKit 会生成 S256 challenge，校验随机 `state`，携带 `code_verifier` 交换 Token，调用官方 `user/whoami` 验证登录，并在到期后使用 Refresh Token 刷新。

正式客户端应实现 `TokenStore` 并连接 Keychain、Android Keystore、Windows Credential Manager 或服务端密钥系统。`JsonTokenStore` 只适合 CLI 和本地开发。

## 内容 API

```python
artwork = await kit.content.artwork_url(artwork_url)
user = await kit.content.user("username")
page = await kit.content.gallery("username", limit=24)
results = await kit.content.search("landscape", limit=24)

print(kit.content.last_adapter)
print(kit.content.last_failures)
```

领域对象只有 `Artwork`、`User`、`Media`、`Page[T]` 等稳定值，不暴露远端原始 JSON。媒体数据通过 `Artwork.media` 返回；宿主应先检查 `media.restricted`，它为真时代表网站只返回了模糊占位图，需要登录权限，不能当作原文件。可用媒体可通过注入的 `Transport.stream(media.url)` 写入缓存、数据库、对象存储或移动端沙箱。

## 自定义适配器

实现 `ContentSource` 后可将自己的代理、缓存 API 或更新后的解析器放在适配器链中：

```python
kit = DAKit(
    oauth_config,
    transport=my_transport,
    token_store=my_secure_store,
    sources=(official_source, cached_source, website_source),
)
```

这使网站更新只影响一个适配器，而不会迫使客户端 UI、缓存和业务状态一起重写。

## CLI

CLI 内置公共 Client ID，不包含 secret：

```bash
dakit login
dakit status
dakit artwork 'https://www.deviantart.com/user/art/title-123'
dakit gallery username
dakit search landscape
dakit logout
```

若系统没有注册 `dakit://`，浏览器跳转失败后复制完整回调 URL 并粘贴到 CLI。开发者可用 `DAKIT_CLIENT_ID` 和 `DAKIT_REDIRECT_URI` 覆盖默认配置。

## 当前能力与限制

- 已实现：PKCE 登录、Token 持久化与刷新、账号验证、作品、用户、画廊、搜索、分页、媒体变体、适配器回退。
- 网站回退目前只支持公开作品详情；账号数据和社交能力坚持走官方 API。
- 评论、收藏、关注、动态和通知尚未实现。
- 网站接口随时可能变化；`SchemaChangedError` 是需要更新适配器的明确信号。
- 项目目前为 `1.0.0a1`，尚未发布 PyPI。

## 验证

```bash
ruff check src tests
mypy src
pytest
python -m build
```

MIT License。
