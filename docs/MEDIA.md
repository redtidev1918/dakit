# 媒体、正文与后台传输

DAKit 把“作品是什么”“服务端允许取得哪个原文件”“如何把字节保存到设备”拆成三层，避免缩略图被误认为下载结果。

## 数据流程

```text
ArtworkRepository
  ├─ 元数据与预览资源
  ├─ ArtworkContentRepository → 文学/日志正文、CSS、编辑标记（惰性数据）
  └─ MediaRepository.originalFile → 经授权的原文件元数据
                                      ↓
                               TransferManager
```

`ArtworkRepository` 返回的图片或视频 URL 可能只是预览。只有 `MediaRepository.originalFile` 调用专用下载元数据接口后返回、且 `availability == available` 的 `MediaAsset` 才能交给传输器。

## 可用性

原文件解析明确区分 `available`、`loginRequired`、`purchaseRequired`、`restricted`、`unavailable` 与 `missing`。登录、权限或不存在等预期拒绝会成为不可传输的领域值；网络中断、限流和响应结构损坏仍抛出类型化异常。SDK 不会在失败时偷偷回退到预览地址。

文学和日志正文通过内容仓库读取。HTML、CSS、字体信息与原始标记只作为字符串返回，SDK 不执行其中脚本，也不创建 WebView。宿主负责清理、渲染与内容安全策略。

## 后台传输

Flutter 适配器 `BackgroundTransferManager` 使用平台任务调度能力，支持：

- 进程重启后的任务恢复；
- 排队、进度、速度、预计剩余时间和真实字节数；
- 重试、暂停、继续、取消；
- 安全叶文件名和应用相对目录；
- 与 OAuth/API 独立配置的媒体代理。

```dart
final transfers = BackgroundTransferManager(diagnostics: diagnostics);
await transfers.initialize();

final asset = await mediaRepository.originalFile(artwork.id);
if (asset.availability == MediaAvailability.available) {
  await transfers.enqueue(
    TransferRequest(id: taskId, asset: asset, filename: asset.filename),
  );
}
```

SDK 没有 16 KiB 文件或分块上限。传输器对字节格式无感，可处理图片、视频、动画、压缩包、文档或可下载文本；真正可下载的格式和大小仍由 provider、账户权限、成熟内容/购买限制以及原文件接口决定。

任务记录不保存 OAuth header。媒体仓库先取得临时 HTTPS 地址，再向原生调度器提交必要元数据。宿主不应把签名 URL 写入日志、分析服务或错误上报。

## 媒体代理

后台任务可能运行在与 Dart HTTP 不同的原生进程，因此媒体代理必须单独配置：

```dart
await transfers.configureProxy(
  const ProxyConfiguration(host: '127.0.0.1', port: 7892),
);

// 用户关闭代理时必须显式清除原生持久配置。
await transfers.configureProxy(null);
```

代理由宿主设置页管理，不应硬编码。Android 模拟器访问开发电脑通常使用 `10.0.2.2`，真机需要可达的局域网地址。

## 能证明什么

单元测试证明领域映射、全字节长度保留、任务恢复和控制调用；构建成功只证明平台集成可编译。确认图片、视频、压缩包、文学和受限作品在真实服务上的行为，需要完成[真实服务测试矩阵](LIVE_TESTING.md)。
