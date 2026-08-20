# 网络、代理与国内开发环境

DAKit 明确区分三条网络路径：依赖下载、Dart 内的 OAuth/API、原生后台媒体传输。它们由不同工具处理，设置一个 `all_proxy` 并不能保证三条路径都生效。

## OAuth 与 API

为 OAuth 和官方 API 传入同一 `NetworkProfile`：

```dart
final network = NetworkProfile.httpProxy(
  proxyServer: HttpProxyServer(host: '127.0.0.1', port: 7892),
  bypassHosts: const <String>{'localhost'},
);

final oauth = DAKitOAuthClient(
  config: oauthConfig,
  networkProfile: network,
  diagnostics: diagnostics,
);
final api = OfficialApiClient(
  session: oauth.session,
  networkProfile: network,
  diagnostics: diagnostics,
);
```

可用模式：

- `NetworkProfile.environment()`：读取 Dart 进程的 `http_proxy`、`https_proxy`、`no_proxy`；
- `NetworkProfile.direct()`：强制直连，用于对照诊断；
- `NetworkProfile.httpProxy(...)`：显式 HTTP CONNECT 代理，可设置绕过主机和内存中的 Basic 凭据；
- 自定义 Dio：适用于 PAC、VPN SDK、企业网络栈、证书固定或测试 transport。

不能同时提供 Dio 和 `NetworkProfile`，否则配置意图不明确。`environment` 不会自动读取所有系统 PAC/桌面代理；手机进程通常也没有有用的代理环境变量。

系统浏览器是另一进程，登录网页使用浏览器/操作系统自己的网络设置，不受上述 Dio 配置控制。这解释了“应用连通性通过但授权页打不开”的情况。

## 媒体传输

原生后台任务不一定经过 Dart HTTP 栈，必须通过 `BackgroundTransferManager.configureProxy` 独立配置。关闭代理时显式传 `null`，否则插件之前持久化的配置可能继续生效。详见[媒体文档](MEDIA.md)。

## 分阶段诊断

`ConnectivityProbe` 按顺序执行：

1. `dns`：解析实际下一跳，代理模式下是代理主机；
2. `connect`：建立到下一跳的 TCP；
3. `tls`：建立 HTTPS tunnel 并用系统信任根校验证书；
4. `http`：等待任何 HTTP 响应，认证与业务权限另行判断。

检查在首个失败阶段停止，返回 `ConnectivityReport`，不会把可预期网络故障变成未捕获异常。运行独立探针：

```shell
dart run packages/dakit_api/example/connectivity.dart environment
dart run packages/dakit_api/example/connectivity.dart direct
dart run packages/dakit_api/example/connectivity.dart http 127.0.0.1 7892
```

诊断记录路由、阶段、耗时、HTTP 状态和稳定错误码，不记录代理密码、token、Cookie、OAuth code 或完整底层异常。

## 国内开发环境

本地 HTTP 代理可按命令设置：

```shell
export all_proxy=http://127.0.0.1:7892
export http_proxy=http://127.0.0.1:7892
export https_proxy=http://127.0.0.1:7892
```

`curl` 常读取 `all_proxy`，Dart `HttpClient` 主要读取 `http_proxy`/`https_proxy`，Flutter、Gradle 和浏览器还可能各自使用不同设置。排错时同时记录“哪条链路”和“哪种配置”，不要把所有失败归为代理问题。

[清华 TUNA Flutter 镜像帮助](https://mirrors.tuna.tsinghua.edu.cn/help/flutter/)提供以下 Flutter/Pub 配置：

```shell
export FLUTTER_STORAGE_BASE_URL=https://mirrors.tuna.tsinghua.edu.cn/flutter
export PUB_HOSTED_URL=https://mirrors.tuna.tsinghua.edu.cn/dart-pub
```

镜像与代理可以同时存在：请求先指向镜像域名，再由代理转发。但混用会增加变量，建议一次只验证一种路线。镜像同步可能滞后；下载到很小的 HTML 错误页时，取消镜像变量并通过代理访问官方源，不要关闭 TLS 或拼接不同来源的归档。

Pub 镜像还可能缺少官方安全公告接口。发布与依赖安全检查应至少再用官方 `https://pub.dev` 执行一次。提交 `pubspec.lock` 前确认 hosted source 没被临时镜像永久改写。

## Android 地址

Android 模拟器中的 `127.0.0.1` 指模拟器自己。访问开发电脑通常用 `10.0.2.2`；物理设备使用局域网可达地址。API 代理和媒体代理都需要改成设备能访问的地址，且本地代理软件必须允许相应监听范围。
