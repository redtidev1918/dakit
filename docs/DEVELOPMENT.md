# 开发、构建与发布

## 固定工具链

当前基线：

```text
Flutter 3.47.1 stable (framework 6655482ec0)
Engine 5d53178869
Dart 3.13.1
```

GitHub Actions 使用同一 Flutter 版本。升级工具链时，应在一个独立提交中更新 CI、`.metadata`、原生工程和本文，并重新验证三个平台。

## 仓库结构

```text
packages/dakit_core/       平台无关领域包
packages/dakit_api/        Dart OAuth/HTTP 包
packages/dakit_flutter/    Flutter 平台适配包
packages/dakit_cli/        纯 Dart 命令行客户端
apps/example_client/       三平台集成客户端
tool/verify.sh             本地与 CI 共用质量门
```

根 `pubspec.yaml` 管理 Dart workspace 和唯一锁文件。库包必须保留 README、CHANGELOG、LICENSE、pubspec 与示例，以满足发布检查。Flutter 原生 runner 和 `.metadata` 是构建/迁移输入，不是无用模板。

## 日常验证

```shell
dart pub get
./tool/verify.sh
```

`tool/verify.sh` 会先拉取依赖，再通过 melos 依次检查格式、静态分析，并运行
core、api、flutter 与示例应用测试。当前基线为 107 个测试。

更细粒度的 melos 命令：

```shell
dart run melos run format
dart run melos run analyze
dart run melos run test
dart run melos run test:coverage
dart run melos run graph
dart run melos run doc
dart run melos run publish:check
```

`doc` 会把公开包的 API 文档生成到 `docs/api/<package>/`。该目录由脚本生成，不提交到
Git；发布前用 `dart run melos run doc` 检查每个包能生成 0 warning / 0 error 的文档。

真实 OAuth/API 测试不进入普通 CI，因为它需要用户授权并受 provider 内容影响。测试方法见 [LIVE_TESTING.md](LIVE_TESTING.md)。

## 平台构建

Android 需要 JDK 17、Android API/Build Tools 36 和 NDK `28.2.13676358`：

```shell
cd apps/example_client
flutter build apk --debug
```

macOS 需要 Xcode：

```shell
cd apps/example_client
flutter build macos --debug
```

Windows 需要对应 Flutter/Visual Studio 工具链。MSIX 才会注册 OAuth scheme：

```powershell
cd apps/example_client
flutter build windows --release
dart run msix:create --build-windows false --install-certificate false
```

这些都是集成 smoke build，不是商店发布包。正式发行由宿主应用提供自己的 bundle/package identity、签名、图标、隐私说明和商店元数据。

## CI

`.github/workflows/ci.yml` 在 push、pull request 和手动触发时执行：

- Ubuntu：格式、分析、107 个测试；
- Ubuntu：生成并上传 `coverage/lcov.info`；
- Ubuntu/Android：debug APK；
- macOS：debug `.app`；
- Windows：release runner 与带 `dakit` 协议的开发 MSIX；
- 每个平台上传 smoke artifact。

平台 job 依赖质量 job，同一分支的新运行会取消旧运行。普通流水线不保存 client ID、secret、token、代理密码或签名凭据。

## 包发布检查

从干净提交执行：

```shell
dart pub publish --dry-run --directory packages/dakit_core
dart pub publish --dry-run --directory packages/dakit_api
flutter pub publish --dry-run --directory packages/dakit_flutter
```

发布顺序为 core → api → flutter。正式发布前还需确认 pub.dev 上的包名可用、repository 链接、版本依赖和 changelog 一致。当前三个公开包已发布为 `0.1.0`，完整发布流程见 [RELEASING.md](RELEASING.md)。

## 提交纪律

- 每个里程碑保持可构建并同步更新 [STATUS.md](STATUS.md)；
- 不提交 `.dart_tool`、`build`、IDE 状态、代理配置、token 或真实服务报告；
- 不手改生成的 plugin registrant；升级插件后通过 Flutter 工具重新生成并验证；
- 公共 API 变更必须增加测试和 changelog；
- 新 endpoint 先定义 core 契约，再实现 api 映射，不让 DTO 进入 UI。
