# DAKit

DAKit 是用于构建第三方 DeviantArt 客户端的异步 Python 内核。它负责会话、网站数据适配、领域模型、分页和媒体处理；Flutter、桌面、Web、Bot 或后端服务负责界面与产品逻辑。

下载不是项目主体，只是 `media` 领域提供的一项可选能力。

> DAKit 使用 DeviantArt 网站接口。这些接口没有公开稳定性承诺，使用者需要遵守服务条款、访问权限与作品授权要求。

## 设计目标

- 面向客户端，而非面向命令行脚本
- 远端 JSON 与应用领域模型隔离
- 所有领域服务共享一个认证会话和连接池
- 网络、凭据和媒体存储均可由宿主注入
- 不把未实现或受限操作伪装成成功
- 保持 Python API 稳定，并允许通过 HTTP/FFI 服务非 Python 客户端

## 安装

DAKit 尚未发布到 PyPI。当前请从 GitHub 安装：

```bash
pip install 'dakit @ git+https://github.com/redtidev1918/dakit.git'
```

开发环境：

```bash
python -m pip install -e '.[dev]'
pytest
```

需要 Python 3.10 或更新版本。

## 客户端内核

```python
import asyncio
from dakit import DAKit

async def main():
    async with DAKit() as da:
        user = await da.users.get("username")
        print(user.username, user.avatar_url)

        page = await da.artworks.gallery(user.username, limit=24)
        for artwork in page.items:
            print(artwork.id, artwork.title, artwork.kind)

        result = await da.browse.search("landscape", limit=10)
        print(result.items)

asyncio.run(main())
```

`DAKit` 是组合根，当前暴露：

- `da.session`：共享会话、凭据、CSRF 与传输生命周期
- `da.users`：用户资料
- `da.artworks`：作品详情、画廊、收藏夹和分页迭代
- `da.browse`：全局搜索与用户内搜索
- `da.media(store)`：媒体解析和可替换存储
- `da.capabilities`：运行时能力声明

## 登录与会话

DAKit 使用 DeviantArt 官方 OAuth2 Authorization Code Grant。系统浏览器负责登录、验证码和 2FA，SDK 不接收用户密码。第三方客户端需要先在 DeviantArt 开发者后台注册应用，并配置一个 localhost 回调地址，例如 `http://127.0.0.1:8765/callback`。

```bash
dakit login --client-id ID --client-secret SECRET \
  --redirect-uri http://127.0.0.1:8765/callback
dakit status
```

作为模块使用：

```python
from dakit import DAKit, JsonCredentialStore, OAuthConfig

da = DAKit(credential_store=JsonCredentialStore())
state = await da.auth.login_oauth(OAuthConfig(
    client_id="your-client-id",
    client_secret="your-client-secret",
    redirect_uri="http://127.0.0.1:8765/callback",
))
print(state.authenticated, state.username)
```

`JsonCredentialStore` 将会话保存为仅当前用户可读的 `0600` 文件。移动端或桌面客户端应实现 `CredentialStore`，接入 Keychain、Keystore 或系统凭据保险库。

也可以由宿主应用管理凭据并直接注入：

```python
from dakit import Credentials, DAKit

da = DAKit(credentials=Credentials("auth=...; auth_secure=..."))
print(da.session.authenticated)

# 用户切换后更新共享会话
da.set_credentials(Credentials("auth=new-session"))
```

GUI 客户端可以把加密存储、账号切换和登录 WebView 放在自身平台层，随后只向 DAKit 注入 Cookie。

## 作品与媒体

```python
from dakit import AssetQuality, FileSystemStore

artwork = await da.artworks.get(
    "https://www.deviantart.com/user/art/title-123"
)

media = da.media(FileSystemStore("./cache"))
saved = await media.download(artwork, quality=AssetQuality.FULL)
print(saved.location)
```

已处理的作品形态：

- 普通图片与 GIF
- 视频作品，选择最高可用视频流而不是封面
- 文学作品，解析完整正文并保存为 UTF-8 文本
- 原文件元数据与下载链接
- 成熟内容受限占位图检测

成熟内容需要有效登录会话。检测到模糊占位图时会抛出 `AuthenticationError`，不会把占位图当作真实作品。

## 自定义基础设施

实现 `AsyncTransport` 可以复用宿主的代理、缓存、证书固定、遥测或测试桩：

```python
da = DAKit(transport=my_transport, credentials=my_credentials)
```

实现 `AssetStore` 可以将媒体写入对象存储、数据库、移动端沙箱或客户端缓存。传入的 transport 归调用方所有，关闭 `DAKit` 时不会擅自关闭它。

## 架构

```text
Application / Flutter bridge / Web API
                  │
                DAKit
                  │
        ┌─────────┴─────────┐
        │   ClientSession   │  credentials, CSRF, connection lifecycle
        └─────────┬─────────┘
          ┌───────┼──────────┬──────────┐
       users   artworks    browse      media
          │       │           │          │
          └──── stable domain models ────┘
                  │
         AsyncTransport / AssetStore
```

网站响应只在 `parser` 层出现。应用应依赖 `Artwork`、`User`、`Page`、`MediaVariant` 等模型，不应直接依赖 `_puppy` 响应字段。

## 当前能力边界

| 领域 | 状态 |
|---|---|
| 作品详情、画廊、收藏夹 | 可用 |
| 用户资料 | 可用 |
| 全局与用户内搜索 | 可用 |
| 图片、GIF、视频、文学媒体 | 可用 |
| Cookie 会话与受限内容识别 | 可用 |
| OAuth2 登录、状态检查与登出 | 可用（需要宿主应用 OAuth 凭据） |
| 评论 | 尚未实现 |
| 收藏/取消收藏、关注/取消关注 | 尚未实现 |
| 首页推荐、关注动态、通知 | 尚未实现 |
| 多账号持久化 | 由宿主负责 |

未实现能力会反映在 `DAKit.capabilities` 中。项目不会为尚未验证的写操作提供虚假接口。

## 兼容性

0.2 版本的 `DeviantArtClient` 名称和 `gallery()`、`search()`、`deviation()` 等方法暂时保留，它们现在委托给领域服务。新代码应优先使用 `DAKit`。

## 参考 CLI

CLI 仅用于调试 SDK，不代表项目架构：

```bash
dakit search "digital art"
dakit url "https://www.deviantart.com/user/art/title-123"
dakit gallery username --limit 20
```

## 路线图

后续领域按以下顺序扩展：

1. 评论读取与线程模型
2. 首页推荐、关注动态和标签浏览
3. 收藏、关注与评论写操作
4. 通知和账号信息
5. 标准 HTTP bridge，供 Flutter 等客户端直接调用
6. 缓存、离线数据与同步策略

MIT License。
