# DAKit 文档

这是 DAKit 的文档目录。面向用户的项目概览、安装与命令行用法见根
[README](../README.md)；本目录按主题提供深入说明。英文版见
[English index](en/README.md)。

## 用户指南

面向把 DAKit 嵌入自己应用的开发者：

- [开始使用](GETTING_STARTED.md) —— 注册 OAuth 应用、运行示例客户端、把 SDK 嵌入
  自己的 Flutter 应用；
- [认证与会话](AUTHENTICATION.md) —— Authorization Code + PKCE、平台回调、
  安全存储与故障定位；
- [网络、代理与国内开发环境](NETWORKING.md) —— 三条网络路径、代理模型、
  分阶段诊断；
- [媒体、正文与后台传输](MEDIA.md) —— 预览与原文件的区分、正文数据、后台下载任务。

## 开发与维护

面向贡献者与维护者：

- [架构与扩展边界](ARCHITECTURE.md) —— 包分层、每层职责、扩展点、上游变化策略；
- [开发、构建与发布](DEVELOPMENT.md) —— 固定工具链、日常验证、三平台构建、CI；
- [发布 DAKit 包](RELEASING.md) —— CLI 二进制与 pub.dev 包的发布流程；
- [真实服务测试](LIVE_TESTING.md) —— 需用户授权的完整媒体验收矩阵；
- [项目状态](STATUS.md) —— 已验证结果与下一步。

## 约定

- 文档以中文为主，英文版位于 `docs/en/`，两份内容保持一致；
- 用户可见文案遵循根 README 的双语约定；
- 文档只描述当前行为；历史变更见各包的 `CHANGELOG.md`。
