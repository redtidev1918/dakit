# 发布 DAKit 包

DAKit 是一个 Dart workspace，公开包为 `dakit_core`、`dakit_api` 和
`dakit_flutter`。`dakit_cli` 不发布到 pub.dev，而是作为独立二进制发布；
`example_client` 仅用于仓库内集成验证。

## 发布 CLI 二进制

1. 更新 `packages/dakit_cli/pubspec.yaml` 与 `CHANGELOG.md`；
2. 运行 `./tool/verify.sh`，并在本机执行一次 `dart compile exe` smoke test；
3. 推送与版本完全一致的 tag，例如：

   ```shell
   git tag dakit_cli-v0.2.0
   git push origin dakit_cli-v0.2.0
   ```

`.github/workflows/cli-release.yml` 会分别在原生 runner 上构建并 smoke test Linux
x64/ARM64、Windows x64、macOS Intel/Apple Silicon 二进制，生成 SHA-256 清单后
创建 GitHub Release。macOS 资产必须保留 `unsigned-preview` 文件名和 Release
警告，直到接入 Apple Developer ID 签名与公证。

## 发布前

1. 固定 Flutter / Dart 工具链并确保本地可构建。
2. 从干净工作区运行完整质量门：

   ```shell
   ./tool/verify.sh
   ```

3. 检查依赖方向：

   ```shell
   dart run melos run graph
   ```

4. 确认没有把 token、client secret、代理密码或真实服务报告提交进仓库。
5. 生成并检查包级 API 文档：

   ```shell
   dart run melos run doc
   ```

   每个公开包应输出 `0 warnings and 0 errors`。

## 更新版本

pub.dev 公开包与 CLI 都遵循语义化版本。正式发布前需要：

1. 更新对应包的 `pubspec.yaml` `version`，并在正式发布前冻结为不带 `-dev` 后缀的
   稳定版本，例如 `0.1.0`。
2. 更新对应包的 `CHANGELOG.md`，使用 `Added` / `Changed` / `Fixed` /
   `Deprecated` / `Removed` / `Security` 分类。
3. 如果依赖关系变化，按 `core → api → flutter` 的顺序更新。
4. 提交消息使用 conventional commit，例如：

   ```text
   chore(release): dakit_core 0.2.0
   ```

## 发布前 dry-run

```shell
dart run melos run publish:check
```

也可以逐包检查：

```shell
dart pub publish --dry-run --directory packages/dakit_core
dart pub publish --dry-run --directory packages/dakit_api
flutter pub publish --dry-run --directory packages/dakit_flutter
```

## 通过 GitHub Actions 自动发布（推荐）

仓库已配置 `.github/workflows/publish.yml`，使用 pub.dev 的 **GitHub Actions
OIDC** 认证：由 GitHub 签发临时身份令牌，**无需保存长期 token / secret**。
发布由推送 git tag 触发，按依赖顺序分别打 tag：

```text
dakit_core-v0.2.0   ->   dakit_api-v0.2.0   ->   dakit_flutter-v0.2.0
```

### 一次性配置

对每个公开包，在 pub.dev 的 Admin 页开启自动发布（需是该包的 uploader，或
publisher 的 admin）：

1. 打开 `https://pub.dev/packages/<package>/admin`；
2. 在 **Automated publishing** 区域点击 **Enable publishing from GitHub
   Actions**；
3. 填写：
   - repository：`redtidev1918/dakit`
   - tag pattern：`<package>-v{{version}}`（例如
     `dakit_core-v{{version}}`、`dakit_api-v{{version}}`、
     `dakit_flutter-v{{version}}`）。
   - 勾选 **Enable publishing from push events**（tag 触发）。
   - 如需按钮发版，再勾选 **Enable publishing from workflow_dispatch events**。

> 自动发布只适用于**已发布过的包**；首次发布仍须用 `dart pub publish` 手动完成。

### 每次发布

1. 用 `melos version`（或手动）更新要发布包的 `pubspec.yaml` `version`，并更新
   其 `CHANGELOG.md`；
2. 确认 dry-run 通过（见上）；
3. 按依赖顺序推送 tag：

   ```shell
   git tag dakit_core-v0.2.0    && git push origin dakit_core-v0.2.0
   git tag dakit_api-v0.2.0     && git push origin dakit_api-v0.2.0
   git tag dakit_flutter-v0.2.0 && git push origin dakit_flutter-v0.2.0
   ```

4. 在 Actions 页观察对应的 publish job 完成。

注意：tag 里的版本号必须与对应包 `pubspec.yaml` 的 `version` 完全一致；pub.dev
上的版本**不可变**，同一个版本只能发布一次，重复打 tag 会失败。

### 按钮发版（workflow_dispatch，可选）

版本号已 bump 并推到 main 后，也可以不用打 tag，直接在
**Actions → Publish to pub.dev → Run workflow** 里选择要发布的包即可。它会发布
该包在 main 分支当前的版本。前置条件是在 pub.dev 上勾选了
**Enable publishing from workflow_dispatch events**。

## 手动发布（备用）

当无法启用 OIDC 自动发布时，可在本地完成认证后手动发布。发布顺序必须是：

```text
dakit_core -> dakit_api -> dakit_flutter
```

因为 `dakit_api` 依赖 `dakit_core`，`dakit_flutter` 依赖前两者；下游包不能先于
其依赖包出现在 pub.dev。

正式发布命令：

```shell
dart pub publish --directory packages/dakit_core
dart pub publish --directory packages/dakit_api
flutter pub publish --directory packages/dakit_flutter
```

发布后更新根 README 的安装方式，从 Git dependency 切换到 pub.dev 版本，并更新
[STATUS.md](STATUS.md)。
