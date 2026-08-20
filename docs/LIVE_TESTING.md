# 真实服务验收

fixture 测试只能证明本地映射逻辑，不能证明真实账户权限、provider 策略、临时媒体地址和设备网络仍然有效。完整验收必须由用户授权，并使用有权访问的代表性作品。

## 安全要求

- 只使用自己的 Public OAuth 应用与账户；
- access token 通过隐藏的环境输入提供；
- 不把 access/refresh token、授权码、client secret 或签名媒体 URL 放入命令参数、源码、报告、issue 或普通 CI；
- 输出目录必须是本机安全的绝对路径，完成后按需删除；
- 测试受限/付费内容只验证“正确拒绝”，不尝试绕过权限。

## 准备

运行完整矩阵前，你需要提前准备好：

- 一个有效 Public OAuth 应用，以及已完成授权的用户会话（可直接提供 access token）；
- 五类作品的 DeviantArt UUID：图片、视频、压缩包/附件、文学、受限；
- 可选的本机 HTTP 代理地址（本仓库示例使用 `127.0.0.1:7892`）；
- 一个安全的绝对输出目录，例如 `/tmp/dakit-live-output`。

## 测试矩阵

准备以下 DeviantArt API UUID，而不是网页 URL 中的 slug 或数字编号：

1. 可下载图片；
2. 可下载视频；
3. 可下载压缩包或附件；
4. 文学或日志；
5. 受限、付费、被屏蔽或不可下载作品。

示例客户端会在作品卡片和详情中显示 UUID。使用你有权访问和保存的内容。

## 运行

```shell
read -r -s DAKIT_ACCESS_TOKEN
export DAKIT_ACCESS_TOKEN
export http_proxy=http://127.0.0.1:7892
export https_proxy=http://127.0.0.1:7892
export DAKIT_LIVE_OUTPUT=/绝对路径/dakit-live-output

dart run packages/dakit_api/example/live_contract.dart \
  image=IMAGE_UUID \
  video=VIDEO_UUID \
  archive=ARCHIVE_UUID \
  literature=LITERATURE_UUID \
  restricted=RESTRICTED_UUID

unset DAKIT_ACCESS_TOKEN
```

代理变量可省略。Dart 不保证用 `all_proxy` 替代 `http_proxy`/`https_proxy`，需要本地 HTTP 代理时显式设置后两者。

## 验收证据

脚本依次执行 DNS → TCP → TLS → HTTP、`user/whoami`、作品详情、正文和原文件解析。所有允许传输的案例都会完整流式读取，并记录实际/预期字节数、SHA-256、媒体类型、可用性、HTTP 状态和脱敏诊断码到 `report.json`。

通过条件：

- 图片、视频、压缩包的实际字节数完整，SHA-256 计算完成；
- 文学至少通过官方 content endpoint 取得正文；若另有可下载附件，也必须完整传输；
- 受限案例返回不可传输状态；
- 任一案例都不能以 preview URL 代替 original；
- 报告中不存在 token、Cookie、授权码或签名源 URL。

`--metadata-only` 可用于收集测试数据，`--allow-partial` 可用于逐步准备矩阵；二者都不能算完整验收。

## 当前结果

已用无效 token 完成安全冒烟：真实网络经过环境代理通过四阶段探针，API 正确返回 `api.provider.invalid_token`，报告未泄漏凭据。这只证明路由、错误分类与脱敏，不证明完整媒体矩阵。

完整矩阵仍待有效 Public OAuth 会话和五类代表性 UUID。完成后必须更新 [STATUS.md](STATUS.md)，但不要提交原始报告或凭据。
