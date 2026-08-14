# AGENTS.md

本文件是给 AI 编码代理（Codex、Claude Code 等支持 AGENTS.md 的工具）的操作说明。

## 接手仓库时的必做步骤

1. 确认工具链：运行 `flutter --version`，要求 Flutter ≥ 3.38.4、Dart ≥ 3.10.3（以 `pubspec.lock` 的 sdks 段为准）。
2. 安装依赖：运行 `flutter pub get`。第三方库（flutter_riverpod、uuid、path_provider、collection 及间接依赖）不随仓库提供，必须先执行此命令。
3. 验证环境：运行 `flutter analyze`，再运行 `flutter test`。
4. 运行项目：`flutter run`（仓库目前仅包含 Windows 平台目录）。

## 约束

- 不要提交 `.dart_tool/`、`build/`、`windows/flutter/ephemeral/` 等生成产物（已被 `.gitignore` 排除）。
- 依赖变更必须同时提交 `pubspec.yaml` 和 `pubspec.lock`。
- 如需新增第三方包，在 `pubspec.yaml` 声明后运行 `flutter pub get`，不要手动修改 lock 文件。
