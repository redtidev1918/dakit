# 项目状态与续接说明

本文件只记录可验证的当前状态和下一步，避免把历史开发日志混入用户文档。每个重要里程碑与同一提交一起更新。

## 当前状态

- 分支：`main`；远端：`https://github.com/redtidev1918/dakit.git`；
- 产品名：DAKit — DeviantArt Client SDK；
- 版本阶段：`0.1.0-dev.1`，尚未发布 pub.dev；
- 运行时：Flutter 3.47.1 / Dart 3.13.1；
- 平台：Android、macOS、Windows/MSIX；
- 测试：格式与分析通过，69 个测试通过；
- 本机构建：Android debug APK、macOS debug app 通过；
- CI：Linux 质量门及 Android/macOS/Windows 四个 job 通过；
- 包发布检查：`dakit_core`、`dakit_api`、`dakit_flutter` dry-run 均为 0 warning；
- 未完成：有效 Public OAuth 应用下的五类真实媒体矩阵。

最新完整 CI 为 [run 32362107720](https://github.com/redtidev1918/dakit/actions/runs/32362107720)：Analyze and test 59 秒、Windows/MSIX 3 分 13 秒、macOS 2 分 44 秒、Android APK 5 分 29 秒，所有 artifact 上传成功。

## 已实现范围

- 分层领域模型、仓库、分页、错误、诊断和传输契约；
- Public Client Authorization Code + S256 PKCE；
- pending transaction/token 安全存储、冷启动回调、并发授权合并与串行 refresh；
- 账户、作品详情/正文、首页/搜索、画廊、收藏、原文件元数据；
- 环境/直连/显式 HTTP 代理、自定义 Dio、DNS/TCP/TLS/HTTP 探针；
- 原文件可用性分类，不以 preview 冒充 original；
- Flutter 后台任务恢复、进度、重试、暂停/继续/取消及独立代理；
- 中英文示例客户端和脱敏诊断面板；
- Android 自定义 scheme、macOS URL type、Windows MSIX 协议激活；
- 三包 MIT 许可证、package README/changelog 与可发布归档。

## 已验证的登录链路

macOS 实测已通过：安全保存 pending state → 启动系统浏览器 → 操作系统回调 → DNS/TCP/TLS/HTTP。随后 provider 返回 `oauth.provider.invalid_client`。当时提供的开发者凭据包含 `client_secret`，说明使用的是 Confidential 注册；DAKit 按设计不把该 secret 编译进客户端。

下一次真实登录必须新建 Public 应用，白名单精确包含 `dakit://oauth/callback`，并只向客户端提供 `client_id`。access/refresh token 仍然必须保密。

## 下一步

1. 使用有效 Public 应用完成系统浏览器登录；
2. 按 [LIVE_TESTING.md](LIVE_TESTING.md) 准备图片、视频、压缩包、文学、受限五类 UUID；
3. 运行完整流式下载与 SHA-256 验收；
4. 根据真实 provider 响应补契约测试，更新本文；
5. 确认 pub.dev 包名并按 core → api → flutter 顺序发布首个开发版。

## 中断后恢复

```shell
git status --short --branch
git log --oneline --decorate -5
flutter --version
./tool/verify.sh
```

先阅读根 [README](../README.md) 和本文。不要恢复旧 Python 实现；历史预览只保留在 Git tag `python-preview-1.0.0a1`。不要在普通 CI 或仓库中加入真实账户凭据。
