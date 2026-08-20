# DAKit 集成客户端

此应用用于验证 SDK 在 Android、macOS 和 Windows 上的真实集成，不是产品 UI 模板。它覆盖系统浏览器登录、深链回调、网络诊断、账户与首页、作品详情、原文件解析、后台任务恢复和中英文错误展示。

## 运行

先创建 DeviantArt **Public** OAuth 应用，并将 `dakit://oauth/callback` 原样加入 redirect whitelist：

```shell
flutter run -d macos \
  --dart-define=DAKIT_CLIENT_ID=你的_PUBLIC_CLIENT_ID
```

为了自动开始一次人工可见的集成登录，可额外传入：

```shell
--dart-define=DAKIT_AUTO_AUTHORIZE=true
```

该开关只用于此诊断应用，普通 SDK 不会自行发起登录。

## 代理

显式配置 OAuth/API 代理：

```shell
--dart-define=DAKIT_PROXY_MODE=http \
--dart-define=DAKIT_PROXY_HOST=127.0.0.1 \
--dart-define=DAKIT_PROXY_PORT=7892
```

`DAKIT_PROXY_MODE` 也可设为 `environment` 或 `direct`。后台媒体任务另用 `DAKIT_TRANSFER_PROXY_HOST` 与 `DAKIT_TRANSFER_PROXY_PORT`；两者缺一会显示配置错误。Android 模拟器访问电脑代理时通常把 `127.0.0.1` 换成 `10.0.2.2`。

## 构建

```shell
flutter build apk --debug
flutter build macos --debug
```

Windows 需要 `flutter build windows --release` 后创建并安装 MSIX，系统才会注册 OAuth 协议。完整步骤见[开发文档](../../docs/DEVELOPMENT.md)，登录排错见[认证文档](../../docs/AUTHENTICATION.md)。
