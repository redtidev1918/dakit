# DAKit

DAKit 是用于构建第三方 DeviantArt 客户端的异步 Python 内核。

它不是单纯的批量下载器，也不是一个已经完成的终端客户端。DAKit 负责账号会话、作品、用户、浏览、分页、媒体和网站兼容；Flutter、桌面、Web 或移动客户端在它之上实现界面、导航、状态管理与平台能力。

```text
Flutter / Desktop / Web / Bot
              │
            DAKit
              │
  Auth · Users · Artworks · Browse · Media
              │
      DeviantArt API / Website
```

> DAKit 使用 DeviantArt 官方 OAuth API，并在官方 API 不覆盖的只读场景使用网站数据兼容层。网站接口可能变化。使用者应遵守 DeviantArt 服务条款、访问权限和作品授权要求。

## 项目状态

DAKit 目前处于 Alpha 阶段，适合客户端原型和 SDK 开发，不建议直接作为无需维护的生产依赖。

| 领域 | 状态 |
|---|---|
| OAuth2 Authorization Code | 已实现 |
| Cookie 会话兼容 | 已实现 |
| 登录状态、会话存储、登出 | 已实现 |
| 用户资料 | 已实现 |
| 作品详情 | 已实现 |
| 用户画廊、收藏夹 | 已实现 |
| 全局搜索、用户内搜索 | 已实现 |
| 图片、GIF、视频、文学 | 已实现 |
| 原文件链接与成熟内容识别 | 已实现 |
| 评论读取与回复 | 尚未实现 |
| 收藏、取消收藏 | 尚未实现 |
| 关注、取消关注 | 尚未实现 |
| 首页推荐、关注动态 | 尚未实现 |
| 通知与站内消息 | 尚未实现 |
| 面向普通用户的内置 OAuth 应用 | 尚未提供 |
| PyPI 发布 | 尚未发布 |

运行时可以通过 `DAKit.capabilities` 查询能力。未实现功能不会提供假成功接口。

## 普通用户须知

DAKit 当前是客户端开发库，不是类似 PixEz 的完整应用。普通用户通常不应直接安装或配置 DAKit，而应使用基于 DAKit 开发的图形客户端。

在最终客户端中，普通用户的体验应当只有：

1. 点击“登录”。
2. 在系统浏览器打开的 DeviantArt 官方页面登录并授权。
3. 返回客户端。

普通用户不应该填写 `client_id`、`client_secret` 或手工导出 Cookie。

目前仓库中的 CLI 是 SDK 调试工具。由于 DAKit 项目尚未注册并配置一个可供示例客户端使用的 OAuth 应用，CLI 登录仍需要客户端开发者自己的 OAuth 参数。这不是最终用户界面。

## 安装

DAKit 尚未发布到 PyPI。当前从 GitHub 安装：

```bash
pip install 'dakit @ git+https://github.com/redtidev1918/dakit.git'
```

本地开发安装：

```bash
git clone https://github.com/redtidev1918/dakit.git
cd dakit
python -m pip install -e '.[dev]'
pytest
```

需要 Python 3.10 或更新版本。

## 快速开始

### 创建客户端内核

```python
import asyncio

from dakit import DAKit


async def main() -> None:
    async with DAKit() as da:
        user = await da.users.get("sakimichan")
        print(user.username, user.avatar_url)

        page = await da.artworks.gallery(user.username, limit=24)
        for artwork in page.items:
            print(artwork.id, artwork.title, artwork.kind)


asyncio.run(main())
```

`DAKit` 是组合根。一个实例代表一个共享会话，并提供以下领域服务：

- `da.auth`：登录、状态检查、凭据生命周期和登出
- `da.users`：用户资料
- `da.artworks`：作品详情、画廊、收藏夹和分页
- `da.browse`：全局与用户内搜索
- `da.media(store)`：媒体解析与存储
- `da.session`：底层共享会话

不要为每个请求创建新的 `DAKit`。客户端通常为每个登录账号维护一个长生命周期实例。

## 登录模型

### 谁负责 OAuth 配置？

OAuth 应用由第三方客户端开发者注册和配置，而不是由普通用户配置。

```text
客户端开发者
  └─ 注册 DeviantArt OAuth 应用
       ├─ client_id
       ├─ redirect_uri
       └─ client_secret（只能保存在可信后端）

普通用户
  └─ 点击登录并在 DeviantArt 页面授权
```

### Authorization Code

DAKit 当前实现了 Authorization Code Grant。适合拥有可信后端，或仅用于本地开发验证的客户端：

```python
from dakit import DAKit, JsonCredentialStore, OAuthConfig


da = DAKit(credential_store=JsonCredentialStore())

state = await da.auth.login_oauth(
    OAuthConfig(
        client_id="your-client-id",
        client_secret="your-client-secret",
        redirect_uri="http://127.0.0.1:8765/callback",
        scopes=("basic", "browse"),
    )
)

print(state.authenticated, state.username)
```

登录过程：

1. DAKit 在 localhost 启动一次性回调监听。
2. 使用系统默认浏览器打开 DeviantArt 官方授权页。
3. 校验随机 OAuth `state`。
4. 使用授权码交换 Access Token。
5. 调用官方 `user/whoami` 验证账号。
6. 更新所有领域服务共享的会话。

### 移动端和桌面端安全

不要把 `client_secret` 打包到 Flutter、Android、iOS、Windows 或 macOS 客户端中。二进制中的 secret 可以被提取。

生产客户端应选择以下方案之一：

- Authorization Code 交换放在开发者后端。
- 使用 DeviantArt 支持的公开客户端授权方式，并仅在客户端保存公开 `client_id`。
- 由平台安全存储保存最终 Token，而不是保存账号密码。

DAKit 后续会增加不要求客户端 secret 的公开客户端登录流程。当前版本不会把不安全的内置 secret 当作便利功能提供。

### 凭据存储

`JsonCredentialStore` 适合 CLI 和本地开发。文件权限会设置为 `0600`：

```python
from dakit import JsonCredentialStore

store = JsonCredentialStore()
da = DAKit(credential_store=store)
```

正式客户端应实现 `CredentialStore`，连接系统安全设施：

- iOS/macOS Keychain
- Android Keystore
- Windows Credential Manager
- 服务端密钥管理系统

DAKit 不接收、记录或保存用户密码。

### Cookie 兼容

Cookie 入口只用于已有宿主会话和兼容测试，不应作为普通用户默认登录流程：

```python
state = await da.auth.login_cookies("auth=...; auth_secure=...")
```

## 用户、作品与浏览

### 用户资料

```python
user = await da.users.get("username")
print(user.id, user.username, user.avatar_url)
```

### 完整作品

```python
artwork = await da.artworks.get(
    "https://www.deviantart.com/user/art/title-123456"
)

print(artwork.title)
print(artwork.author)
print(artwork.kind)
print(artwork.media)
```

### 画廊分页

```python
page = await da.artworks.gallery("username", limit=24)

while True:
    for artwork in page.items:
        print(artwork.title)

    if not page.has_more:
        break

    page = await da.artworks.gallery(
        "username",
        cursor=page.next_cursor,
        limit=24,
    )
```

也可以异步迭代：

```python
async for artwork in da.artworks.iter_gallery("username"):
    print(artwork.title)
```

### 搜索

```python
global_results = await da.browse.search("landscape", limit=20)
user_results = await da.browse.search(
    "portrait",
    username="username",
    limit=20,
)
```

## 媒体不是客户端核心

下载属于独立媒体服务，不会污染用户、浏览和社交领域：

```python
from dakit import AssetQuality, FileSystemStore

artwork = await da.artworks.get(artwork_url)
media = da.media(FileSystemStore("./media-cache"))

saved = await media.download(
    artwork,
    quality=AssetQuality.FULL,
)

print(saved.location)
```

媒体服务当前支持：

- 普通图片
- GIF
- 最高可用分辨率视频
- 文学正文导出
- 原文件元数据与链接
- 成熟内容模糊占位图检测
- 临时文件与原子落盘

成熟内容需要拥有相应权限的登录会话。若 DeviantArt 只返回模糊占位图，DAKit 会抛出 `AuthenticationError`，不会将其报告为成功下载。

实现 `AssetStore` 可以写入客户端缓存、对象存储、数据库或移动端沙箱。

## 可替换基础设施

### 自定义网络层

```python
da = DAKit(
    transport=my_transport,
    credentials=my_credentials,
)
```

实现 `AsyncTransport` 可以接入：

- 客户端统一代理
- 请求缓存
- 证书固定
- 调试日志与遥测
- Mock Server
- Flutter/原生网络桥接

由调用方传入的 transport 仍归调用方所有。关闭 DAKit 时不会擅自关闭它。

### 稳定领域模型

上层客户端应依赖：

- `Artwork`
- `User`
- `Page[T]`
- `MediaVariant`
- `AuthState`
- `ClientCapabilities`

不要让 UI 直接依赖 DeviantArt `_puppy` JSON。网站字段只应存在于解析兼容层；必要的原始响应可以通过模型的 `raw` 字段用于诊断。

## 架构

```text
Application / Flutter Bridge / HTTP API
                    │
                  DAKit
                    │
             ClientSession
       credentials · OAuth · CSRF · HTTP
                    │
     ┌──────────┬──────────┬──────────┐
    Auth       Users     Artworks    Browse
                              │
                            Media
                    │
          Stable domain models
                    │
       AsyncTransport · AssetStore
```

模块职责：

```text
src/dakit/
├── client.py                 # 组合根和兼容门面
├── session.py                # 共享会话
├── auth.py                   # OAuth 配置与凭据存储
├── models.py                 # 稳定领域模型
├── parser.py                 # 网站响应兼容层
├── transport.py              # 可替换网络接口
├── downloads.py              # 媒体服务
└── services/
    ├── authentication.py
    ├── users.py
    ├── artworks.py
    └── browse.py
```

## CLI

CLI 是 SDK 调试入口，不是最终产品：

```bash
dakit search "digital art"
dakit url "https://www.deviantart.com/user/art/title-123"
dakit gallery username --limit 20
```

OAuth 开发测试：

```bash
export DAKIT_CLIENT_ID=...
export DAKIT_CLIENT_SECRET=...
export DAKIT_REDIRECT_URI=http://127.0.0.1:8765/callback

dakit login
dakit status
dakit logout
```

不要把包含 secret 的 `.env` 提交到仓库。

## 兼容性

早期版本中的 `DeviantArtClient` 暂时保留为 `DAKit` 的兼容别名。`gallery()`、`search()`、`deviation()` 等门面方法仍可调用，但新代码应使用领域服务：

```python
await da.artworks.gallery(...)
await da.browse.search(...)
await da.artworks.get(...)
```

## 路线图

1. 适合公开客户端的 OAuth 登录流程
2. 官方 OAuth API 优先的数据服务
3. 评论读取、线程和回复
4. 收藏、取消收藏、关注和取消关注
5. 首页推荐、关注动态和标签浏览
6. 通知与站内消息
7. Flutter/HTTP Bridge
8. 缓存、离线数据和多账号同步
9. PyPI 自动发布与版本兼容策略

## 开发与验证

```bash
pytest
ruff check .
mypy src
python -m build
```

项目使用 MIT License。
