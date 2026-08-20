# 发布 DAKit 包

DAKit 是一个 Dart workspace，公开包为 `dakit_core`、`dakit_api` 和
`dakit_flutter`。`dakit_cli` 与 `example_client` 是仓库内的工具和应用，不发布。

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

## 更新版本

公开包遵循语义化版本。当前仍是 `0.1.0-dev.1`，正式发布前需要：

1. 更新对应包的 `pubspec.yaml` `version`。
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

## 正式发布

确认包名可用且 dry-run 通过后，再执行正式发布。发布顺序必须是：

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
