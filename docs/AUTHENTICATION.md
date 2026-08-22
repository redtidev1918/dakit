# 认证与会话

DAKit 的内置设备端登录适配器实现 Authorization Code + S256 PKCE，适用于 Public Client。登录页面由系统默认浏览器打开；SDK 不接管用户名、密码、人机验证或第三方登录页面。使用 Confidential Client 的项目可以在可信后端完成 OAuth，再通过 `AuthTokenProvider` 将会话接入 API 层。

官方认证说明见 [DeviantArt Authentication](https://deviantart.readme.io/docs/authentication)。

## 选择 Client type

Client type 取决于凭据保存位置，而不是功能多少：

| 类型 | 适用场景 | DeviantArt 签发的应用凭据 | DAKit 支持方式 |
| --- | --- | --- | --- |
| Public | 移动端、桌面端、SPA 等无法保密的程序 | `client_id` | 内置 PKCE 登录 |
| Confidential | 有可信后端、能够保管长期密钥的服务 | `client_id` + `client_secret` | 后端认证后注入 `AuthTokenProvider` |

安装在用户设备上的代码和构建产物无法安全保存共享密钥。Public 应用通过 `client_id`、一次性授权码和 PKCE verifier 关联授权请求，不使用 `client_secret`。

`client_id` 是应用标识，可以出现在客户端；access token、refresh token 和 `client_secret` 都是私密凭据。Public/Confidential 描述的是开发者应用类型，不是 token 类型。

如果开发者后台给出了 `client_secret`，该应用注册就是 Confidential。这个注册可以继续用于后端，但不能直接交给 DAKit 的设备端登录适配器：把 secret 编译进客户端会泄露，省略它则会在 token exchange 阶段得到 `invalid_client`。直接运行 Flutter 客户端时，应另外创建 Public 注册。

## 完整生命周期

1. 生成随机 `state`、PKCE verifier 和 S256 challenge；
2. 将待完成事务写入平台安全存储；
3. 先订阅深链，再打开系统浏览器；
4. 操作系统把精确回调 URI 交还应用；
5. 校验协议、主机、路径、有效期和 `state`；
6. 使用原 verifier 交换授权码，不发送 secret；
7. 安全保存 access/refresh token，并删除待完成事务；
8. 并发刷新通过单一会话协调，避免多个 401 同时刷新。

应用应在启动早期创建 `DAKitOAuthClient`，先调用 `resumePending()`，再显示界面。用户主动点击登录时调用 `authorize()`。并发授权调用会合并为同一个操作。

## 安全存储

默认适配器使用 `flutter_secure_storage`：Android 使用系统安全存储，Windows 使用凭据存储，macOS 使用 Keychain。macOS 默认选择 `first_unlock_this_device` 且不启用 Data Protection Keychain，因此普通未签名开发构建无需 Keychain Sharing entitlement；有企业签名策略的宿主可注入自己的 `TokenStore` 和 `PendingAuthorizationStore`。

macOS 会把 Keychain 条目的 `kSecAttrService` 名直接显示在「…想要使用钥匙串中的机密信息」授权弹窗里；默认名 `flutter_secure_storage_service` 会让用户误以为应用在读取任意机密。宿主应改用 `clientSecureStorage(serviceName: '<产品名>')` 构建的存储，把条目命名为面向用户的产品名。

任何日志都不应包含 access token、refresh token、授权码、Cookie、PKCE verifier、代理密码或带签名的媒体 URL。DAKit 诊断只保留阶段、稳定错误码、耗时和经过筛选的属性。

## 平台回调

- Android：browsable intent filter 将 `dakit://oauth/callback` 送入主 Activity；
- macOS：`CFBundleURLTypes` 注册 `dakit` scheme；
- Windows：MSIX manifest 注册协议，`app_links` 把新进程收到的激活转发给现有实例。

自定义 scheme 易于集成，但任何其他应用都能尝试发起同名 URI，因此 `state`、精确 redirect 校验和短期事务缺一不可。将来如需 claimed HTTPS redirect，应由宿主平台适配器实现，不应绕开协调器验证。

## 故障定位

| 现象或代码 | 含义 | 检查项 |
| --- | --- | --- |
| 浏览器未打开 | launcher 或系统 URL 处理失败 | 默认浏览器、系统策略、诊断中的 launch 阶段 |
| 网页黑屏/加载失败 | 浏览器网络或站点策略问题 | 系统浏览器代理；它不继承 Dart 的应用内代理 |
| 登录后应用无反应 | 回调未被系统交回 | 平台 scheme 注册、redirect 是否完全一致 |
| callback state/redirect 错误 | 回调不属于当前事务 | 不要复用旧链接；清理旧流程后重试 |
| `oauth.provider.invalid_client` | provider 不接受应用身份 | Public 类型、正确 client ID、精确 redirect；不要使用 Confidential secret |
| token network/timeout/TLS | token endpoint 未连通 | 运行分阶段检查，确认应用内网络配置 |
| storage failure | 安全存储不可用 | 系统凭据库权限、设备锁屏设置、原生状态字段 |

认证故障和网络故障不会合并成“登录失败”一个模糊提示。需要自定义展示时，以 `DAKitException.kind` 与稳定 `code` 做本地化映射，不要向用户直接展示底层异常全文。

## OAuth scope 与功能

DAKit 在 `OAuthScope` 里集中维护了常量。功能与必需 scope 的对应关系：

| 功能 | 必需 scope | 缺少时的典型表现 |
| --- | --- | --- |
| 读取账号 / 用户资料 / 关注列表 | `user` | 401 |
| 收藏 / 取消收藏 | `collection` | 401 |
| 关注 / 取消关注用户 | `user.manage` | **403**（只有 `user` 不够） |
| 画廊 / 收藏夹目录 | `gallery` | 401 |
| 关注动态（deviantsyouwatch） | `feed` | 401 |
| 首页 / 搜索 / 每日推荐 | `browse` | 401 |
| 通知 / 反馈 / mentions | `message` | 401 |

授权时缺少的 scope 不会在 token exchange 阶段报错，而是表现为后续调用返回
401/403。排查“某个功能总是被拒”时，先核对 token 实际拿到了哪些 scope
（`AuthTokens.scopes`），而不是只检查是否“已登录”。

## Flutter：复用网页会话完成授权

DeviantArt 的网页登录态和 OAuth 是两套凭据。若客户端内嵌了一个已经登录
`deviantart.com` 的 WebView，可以把 OAuth 授权 URL 加载到**同一个** WebView 里：
因为 WebView 拥有网页会话 Cookie，用户无需重新输入密码，只确认授权页即可。

实现要点：

1. 自定义 `ExternalUriLauncher`，把授权 URL 转发给 WebView（而不是系统浏览器）；
2. WebView 拦截 `dakit://oauth/callback`，通过自定义 `CallbackUriSource` 交回协调器；
3. 用 `MergedCallbackUriSource` 把「系统 app-links 回调」和「WebView 回调」并发合并
   ——不要用顺序 `yield*`，app-links 流永不关闭，会饿死 WebView 回调；
4. 用户可能只在网页里登录而没有 OAuth token，或反之。宿主应把这两条状态向用户
   清晰呈现，或引导用户完成缺失的一步。

