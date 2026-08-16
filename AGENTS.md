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

## 多代理协作约定（两个代理并行开发时必读）

本仓库由两个代理并行开发：**组合逻辑代理**（门电路、译码器/选择器等无内部状态的芯片）与**时序逻辑代理**（触发器/计数器/移位寄存器、仿真引擎、UI）。两个代理共用一个工作树，没有分支隔离，因此必须遵守以下约定。

### 文件归属

- 组合逻辑代理负责：无内部状态的组合芯片文件 `lib/chips/ls74ls00/02/04/08/10/11/20/21/27/32/42/86/125/136/266...`、`lib/models/truth_table.dart`、`lib/widgets/chip_manual.dart` 及各芯片对应的测试文件 `test/chips/ls74lsXX_test.dart`。
- 时序逻辑代理负责：带内部状态的时序芯片文件 `lib/chips/ls74ls74/175/273/373/164/90/161...`、`lib/engine/`、`lib/canvas/`、`lib/widgets/`（芯片手册除外）、`lib/theme/`、`lib/screens/`、`lib/providers/`、`lib/models/pin.dart` 及各芯片对应的测试文件。
- 共享文件（双方都可能改，改前必须登记）：`lib/chips/chip_factory.dart`、`lib/models/chip_definition.dart`、`lib/models/signal_state.dart`、`lib/models/chip_instance.dart`、`lib/engine/simulation_engine.dart`、`lib/chips/io_input.dart`、`lib/chips/io_led.dart`。

### 改动共享文件前的流程

1. 先读根目录 `COORDINATION.md`，确认目标文件未被对方占用。
2. 在「占用板」登记：代理名、文件路径、时间。
3. 重读目标文件的最新内容（对方可能刚改过），在其基础上叠加，不要覆盖。
4. 完成后删除占用，并在「留言」区写明改了什么。
5. 收工前运行全量 `flutter analyze` 与 `flutter test`，确认没有破坏对方的测试。

### Git 规则

- 每完成 2–3 个芯片提交一次；提交信息带前缀并列出新增芯片型号，例如 `组合逻辑: 新增 74LS10、74LS11、74LS20`、`时序: 新增 74LS175、74LS273`。
- 每次提交时把新增芯片写进自己名下的日志：组合代理 → `doc/log-combinational-chips.md`，时序代理 → `doc/log-sequential-chips.md`。两份日志各自独占，互不改动。
- 禁止 `git reset --hard`、`git checkout -- <path>`；需要回退一律用新提交。
- 禁止 `git add -A`（会把对方未提交的工作卷进自己的提交）；按文件 `git add <具体路径>`，只加自己名下的文件。
- 提交时若 git 报 `index.lock` 已存在，说明对方正在提交：等 3 秒重试，最多 5 次。
- 每次开工先 `git status`，检查是否有对方的未提交改动，不要覆盖或删除。

### 冲突护栏

- 共享枚举/方法签名（`PinDirection`、`ChipDefinition.evaluate` 等）只做向后兼容或纯增量修改；破坏性变更必须先写入 `COORDINATION.md` 留言通知对方。
- 全量 `flutter test` 是强制回归网，覆盖双方的芯片与 UI 测试。
