# 派活单（第二轮）：时序逻辑代理（74LS 时序芯片补充）

> 第二轮派活单。**你的第一轮（批次 3/4）已完成，现在可直接开工本文件，无需等待组合代理的第一轮收尾。** 开工前先读根目录 `AGENTS.md` 与 `COORDINATION.md`（本文件是任务级补充，冲突时以 `AGENTS.md` 为准）。

## 你的任务

继续为 `digital_logic_sim`（Flutter + 74LS 四态仿真器）补充**带内部状态的时序芯片**：JK 触发器、寄存器、加/减计数器。并行开发约定与第一轮相同。

## 芯片清单（按顺序，2–3 个一批）

| 批次 | 芯片 | 功能 | 封装 |
|------|------|------|------|
| 5 | 74LS76 | 双 JK 触发器（异步置位 / 清零，正沿触发） | DIP-16 |
| 5 | 74LS112 | 双 JK 触发器（异步置位 / 清零，负沿触发） | DIP-16 |
| 5 | 74LS174 | 六 D 触发器（公共时钟与异步清零） | DIP-16 |
| 6 | 74LS190 | 十进制同步加减计数器（单时钟，异步置数，RCO） | DIP-16 |
| 6 | 74LS191 | 4 位二进制同步加减计数器（单时钟，异步置数） | DIP-16 |
| 6 | 74LS193 | 4 位二进制加减计数器（CU/CD 双时钟，异步清零 / 置数） | DIP-16 |

- 每批完成并验证后按下方 Git 规则提交一次，不要攒超过 3 个芯片。
- 已完成、**不要重复**：74LS74/90/161/164/175/273/373，以及你第一轮完成的 74LS93/160/163/393/165/194。
- 清单外可选后续：74LS192、74LS195、74LS374、74LS75；74LS123 单稳态依赖引擎定时事件，留到最后。加清单外型号前，先在 `COORDINATION.md` 留言区声明，避免撞型号。

## 与组合代理并行的注意事项

组合代理此刻可能仍在跑它的第一轮（74LS138/139/151/153/157/283），所以：

- `chip_factory.dart` 可能正被它占用或有未提交改动：注册本批芯片时严格走占用板，先读最新内容再叠加；一次占用登记最多加本批（3 颗）的注册行，改完立即释放。
- 它可能在工作区留下未提交的半成品芯片 / 测试文件。全量 `flutter test` 若被这些文件带红，**不要修对方文件**，先在 `COORDINATION.md` 留言说明；验收以你自己的新测试 + 全部已提交芯片测试为准，收工前对方若已提交，再跑一次全量确认全绿。
- git 只 `add` 自己名下的文件；`git status` 里属于对方的已暂存 / 未暂存改动是正常的，不要动。

## 每个芯片的交付物

1. `lib/chips/ls74lsXX.dart`：类名 `Chip74LSXX`，继承 `ChipDefinition`；引脚严格按数据手册（含 VCC/GND，编号与左右侧布局）。
2. `test/chips/ls74lsXX_test.dart`：覆盖引脚表、异步置位/清零优先级、时钟边沿（注意正沿 / 负沿）、保持与翻转、`unknown`/`highZ` 传播。
3. 在共享文件 `lib/chips/chip_factory.dart` 里注册：加 import 和 `_registry` 表条目。

## 实现规范

- 74LS76/112：JK 真值表（J=K=1 时在有效时钟沿翻转），异步置位/清零优先级高于时钟；76 正沿、112 负沿，`prev_clk` 的边沿方向要对。
- 74LS174：六路 D，公共上升沿时钟 + 公共异步清零，照 `Chip74LS175` 的模式扩展。
- 74LS190/191：单时钟加/减计数，`~U/D` 选方向、`~CTEN` 计数使能、异步置数；RCO 在最大/最小计数且使能时输出计数脉冲。
- 74LS193：CU、CD 两个独立计数时钟，异步清零与异步置数；进位 / 借位输出按数据手册。
- 计数器当前值放进 `internalState`（可用单键整数辅助，但输出引脚仍逐位返回 `SignalState`）；`truthTableGroups` 留空。
- 芯片库搜索只按型号名匹配（`ChipDefinition.matchesSearch`，已有回归测试）；写 `description` 无需考虑搜索命中，不要把搜索改回“型号或描述”匹配。
- 不碰组合芯片文件、`lib/models/truth_table.dart`、`lib/widgets/chip_manual.dart`；`lib/engine/` 一般无需改动。

## 共享文件流程（动 `chip_factory.dart` 等之前）

1. 读 `COORDINATION.md`，确认目标文件未被占用。
2. 在占用板登记：代理名、文件路径、时间。
3. 重读文件最新内容，在对方改动之上叠加，不要覆盖。
4. 完成后删除占用，并在留言区写明改了什么。

共享文件清单：`chip_factory.dart`、`chip_definition.dart`、`signal_state.dart`、`chip_instance.dart`、`simulation_engine.dart`、`io_input.dart`、`io_led.dart`。共享接口只做向后兼容或纯增量修改；破坏性变更先留言通知对方。

## Git 与日志

- 每完成 2–3 个芯片提交一次；提交信息带前缀并列出型号，例如 `时序: 新增 74LS76、74LS112、74LS174`。
- 提交前把本次芯片写进 `doc/log-sequential-chips.md`（你的专属日志），不要改动 `doc/log-combinational-chips.md`。
- 只用 `git add <具体路径>`（芯片文件 + 对应测试 + `chip_factory.dart` + 你的日志），**禁止 `git add -A`**。
- git 报 `index.lock` 已存在 = 对方正在提交：等 3 秒重试，最多 5 次。
- 每次开工先 `git status`；禁止 `reset --hard` / `checkout --`，回退一律用新提交。

## 验收

- 开工先跑一次全量 `flutter test` 记录当前通过数；每批提交前和收工前再跑全量 `flutter analyze` 与 `flutter test`，通过数不得低于开工基线，另加本批新芯片测试。
- 开工先 `flutter pub get`（第三方库不随仓库提供）。flutter 若提示等待 startup lock（对方正在跑 flutter），等待即可。

## 回话

需要协调时在 `COORDINATION.md` 留言区回复，或通过派单方转达。
