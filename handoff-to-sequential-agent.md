# 派活单：时序逻辑代理（74LS 时序芯片补充）

> 派单方给「时序逻辑代理」的开工说明。开工前先读根目录 `AGENTS.md` 与 `COORDINATION.md`（本文件是任务级补充，冲突时以 `AGENTS.md` 为准）。

## 你的任务

为 `digital_logic_sim`（Flutter + 74LS 四态仿真器）补充**带内部状态的时序芯片**：锁存器 / 寄存器 / 移位寄存器 / 计数器。你与「组合逻辑代理」并行开发、共用一个工作树（都在 `main`，无分支隔离），必须严格遵守下面的分工与 Git 约定。

## 芯片清单（按顺序，2–3 个一批）

| 批次 | 芯片 | 功能 | 封装 |
|------|------|------|------|
| 1 | 74LS175 | 四 D 触发器，公共异步清零 | DIP-16 |
| 1 | 74LS273 | 八 D 触发器，公共异步清零 | DIP-20 |
| 1 | 74LS373 | 八透明锁存器，LE 锁存 + OE 三态输出 | DIP-20 |
| 2 | 74LS164 | 8 位串入并出移位寄存器，异步清零 | DIP-14 |
| 2 | 74LS90 | 十进制计数器（2 分频 + 5 分频两段） | DIP-14 |
| 2 | 74LS161 | 4 位同步二进制计数器，异步清零 / 同步置数 | DIP-16 |

- 每批完成并验证后按下方 Git 规则提交一次，不要攒超过 3 个芯片。
- `74LS74` 已实现并有测试（`lib/chips/ls74ls74.dart`、`test/chips/ls74ls74_test.dart`），**不要重复实现**；若发现缺陷，沿用它的风格修复。
- 想加清单外型号（可选：74LS165、74LS194、74LS393）前，先在 `COORDINATION.md` 留言区声明型号，避免与组合代理撞型号。

## 每个芯片的交付物

1. `lib/chips/ls74lsXX.dart`：类名 `Chip74LSXX`，继承 `ChipDefinition`；引脚严格按数据手册（含 VCC/GND，编号与左右侧布局）。
2. `test/chips/ls74lsXX_test.dart`：覆盖引脚表、异步清零/置位优先级、时钟边沿、保持行为、`unknown`/`highZ` 传播。
3. 在共享文件 `lib/chips/chip_factory.dart` 里注册：加 import 和 `_registry` 表条目。

## 实现规范

- 照 `Chip74LS74` 的模式：用 `initialState` 存 `prev_clk` 等边沿记忆；计数器 / 移位寄存器的当前值也放进 `internalState`，`evaluate` 里读写。
- 时序芯片的 `truthTableGroups` 留空；`functionSummary`、`datasheetNotes` 写中文说明。
- 四态逻辑：输入含 `unknown` 或 `highZ` 时输出给 `unknown`；异步清零 / 置位优先级高于时钟沿。
- 不碰组合芯片文件、`lib/models/truth_table.dart`、`lib/widgets/chip_manual.dart`。`lib/engine/` 一般无需改动：现有 `internalState` 机制已支持有状态芯片。

## 共享文件流程（动 `chip_factory.dart` 等之前）

1. 读 `COORDINATION.md`，确认目标文件未被占用。
2. 在占用板登记：代理名、文件路径、时间。
3. 重读文件最新内容，在对方改动之上叠加，不要覆盖。
4. 完成后删除占用，并在留言区写明改了什么。

共享文件清单：`chip_factory.dart`、`chip_definition.dart`、`signal_state.dart`、`chip_instance.dart`、`simulation_engine.dart`、`io_input.dart`、`io_led.dart`。共享接口只做向后兼容或纯增量修改；破坏性变更先留言通知对方。

## Git 与日志

- 每完成 2–3 个芯片提交一次；提交信息带前缀并列出型号，例如 `时序: 新增 74LS175、74LS273、74LS373`。
- 提交前把本次芯片写进 `doc/log-sequential-chips.md`（你的专属日志），不要改动 `doc/log-combinational-chips.md`。
- 只用 `git add <具体路径>`（芯片文件 + 对应测试 + `chip_factory.dart` + 你的日志），**禁止 `git add -A`**。
- git 报 `index.lock` 已存在 = 对方正在提交：等 3 秒重试，最多 5 次。
- 每次开工先 `git status`；禁止 `reset --hard` / `checkout --`，回退一律用新提交。

## 验收

- 每批提交前和收工前都跑全量 `flutter analyze` 与 `flutter test`；基线 105 个用例必须保持全绿，另加新芯片测试。
- 开工先 `flutter pub get`（第三方库不随仓库提供）。flutter 若提示等待 startup lock（对方正在跑 flutter），等待即可。

## 回话

需要协调时在 `COORDINATION.md` 留言区回复，或通过派单方转达。
