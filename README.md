# DAKit

异步、强类型、可嵌入的 DeviantArt 客户端 SDK。项目采用“库优先”设计；命令行只是参考适配器，桌面客户端、Web 服务、Bot 和第三方 DeviantArt 客户端均可直接使用核心库。

> DeviantArt 没有为这里使用的网页接口提供稳定性保证。SDK 将不稳定字段隔离在解析层，但上游变化仍可能需要升级 SDK。使用者应遵守 DeviantArt 服务条款和内容授权要求。

## 安装

```bash
pip install dakit
```

开发安装：

```bash
python -m pip install -e '.[dev]'
pytest
```

## 作为库使用

```python
import asyncio
from dakit import DeviantArtClient


async def main():
    async with DeviantArtClient() as client:
        async for work in client.iter_gallery("username"):
            print(work.id, work.title, work.best_media())


asyncio.run(main())
```

认证信息由宿主决定如何保存，SDK 不会擅自读取浏览器或用户目录：

```python
from dakit import Credentials, DeviantArtClient

client = DeviantArtClient(credentials=Credentials("auth=...; auth_secure=..."))
```

下载到文件系统：

```python
from dakit import DownloadService, FileSystemStore

downloader = DownloadService(client.transport, FileSystemStore("./downloads"))
result = await downloader.download(work)
```

实现 `AsyncTransport` 可接入宿主已有的 HTTP 栈、缓存、测试桩或遥测；实现 `AssetStore` 可写入对象存储、数据库、移动端沙箱或自定义媒体库。公共异常均继承自 `DeviantArtError`。

## CLI

```bash
dakit search "digital art" --username username
dakit --output ./downloads gallery username --quality full --limit 20
```

Cookie 可通过全局 `--cookie` 参数或 `DEVIANTART_COOKIE` 提供。生产客户端建议直接调用 SDK 并自行管理密钥。

## 架构

```text
Host application
  ├── Credentials provider
  ├── DeviantArtClient ── Parser ── stable domain models
  ├── AsyncTransport (httpx by default)
  └── DownloadService ── AssetStore (filesystem by default)
```

公共入口集中在 `dakit.__init__`。远端响应不会直接泄漏成业务模型；排查兼容问题时可读取 `Deviation.raw`。

支持画廊、收藏夹、搜索、Cookie 认证透传、媒体质量选择、流式下载，以及自定义传输和存储适配器。Python 3.10+，MIT License。
