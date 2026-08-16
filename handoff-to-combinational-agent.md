# 派活单：组合逻辑代理（74LS 组合芯片补充）

> 派单方给「组合逻辑代理」的开工说明。开工前先读根目录 `AGENTS.md` 与 `COORDINATION.md`（本文件是任务级补充，冲突时以 `AGENTS.md` 为准）。

## 你的任务

为 `digital_logic_sim`（Flutter + 74LS 四态仿真器）补充**无内部状态的组合芯片**：多输入门、译码器等。你与「时序逻辑代理」并行开发、共用一个工作树（都在 `main`，无分支隔离），必须严格遵守下面的分工与 Git 约定。

## 芯片清单（按顺序，2–3 个一批）

| 批次 | 芯片 | 功能 | 封装 |
|------|------|------|------|
| 1 | 74LS10 | 三 3 输入与非门 | DIP-14 |
| 1 | 74LS11 | 三 3 输入与门 | DIP-14 |
| 1 | 74LS20 | 双 4 输入与非门 | DIP-14 |
| 2 | 74LS21 | 双 4 输入与门 | DIP-14 |
| 2 | 74LS27 | 三 3 输入或非门 | DIP-14 |
| 2 | 74LS42 | BCD 码 → 十进制译码器（1-of-10，低有效） | DIP-16 |

- 每批完成并验证后按下方 Git 规则提交一次，不要攒超过 3 个芯片。
- 已实现、**不要重复**：74LS00/02/04/08/32/86/136/266；`74LS74` 归时序代理，不要动。
- 想加清单外型号（可选：74LS138、74LS139、74LS148、74LS151、74LS157、74LS283）前，先在 `COORDINATION.md` 留言区声明型号，避免与时序代理撞型号。

## 每个芯片的交付物

1. `lib/chips/ls74lsXX.dart`：类名 `Chip74LSXX`，继承 `ChipDefinition`；引脚严格按数据手册（含 VCC/GND，编号与左右侧布局）。
2. `test/chips/ls74lsXX_test.dart`：覆盖引脚表、完整真值表、`unknown`/`highZ` 传播规则。
3. 在共享文件 `lib/chips/chip_factory.dart` 里注册：加 import 和 `_registry` 表条目。

## 实现规范

- 多输入门需要 `signal_state.dart` 里的 nand3/and3/nor3/nand4/and4 等静态方法：只做纯增量新增（不改现有签名），改前先在占用板登记。
- `truthTableGroups` 按门 / 译码段分组（供芯片手册渲染）；74LS42 用 `datasheetNotes` 注明非法 BCD 输入（10–15）时全部输出高。
- 不碰时序芯片文件、`lib/engine/`、`lib/models/pin.dart`、UI / 主题。

## 共享文件流程（动 `chip_factory.dart`、`signal_state.dart` 等之前）

1. 读 `COORDINATION.md`，确认目标文件未被占用。
2. 在占用板登记：代理名、文件路径、时间。
3. 重读文件最新内容，在对方改动之上叠加，不要覆盖。
4. 完成后删除占用，并在留言区写明改了什么。

共享文件清单：`chip_factory.dart`、`chip_definition.dart`、`signal_state.dart`、`chip_instance.dart`、`simulation_engine.dart`、`io_input.dart`、`io_led.dart`。共享接口只做向后兼容或纯增量修改；破坏性变更先留言通知对方。

## Git 与日志

- 每完成 2–3 个芯片提交一次；提交信息带前缀并列出型号，例如 `组合逻辑: 新增 74LS10、74LS11、74LS20`。
- 提交前把本次芯片写进 `doc/log-combinational-chips.md`（你的专属日志），不要改动 `doc/log-sequential-chips.md`。
- 只用 `git add <具体路径>`（芯片文件 + 对应测试 + `chip_factory.dart` + 你的日志），**禁止 `git add -A`**。
- git 报 `index.lock` 已存在 = 对方正在提交：等 3 秒重试，最多 5 次。
- 每次开工先 `git status`；禁止 `reset --hard` / `checkout --`，回退一律用新提交。

## 验收

- 每批提交前和收工前都跑全量 `flutter analyze` 与 `flutter test`；基线 105 个用例必须保持全绿，另加新芯片测试。
- 开工先 `flutter pub get`（第三方库不随仓库提供）。flutter 若提示等待 startup lock（对方正在跑 flutter），等待即可。

## 回话

需要协调时在 `COORDINATION.md` 留言区回复，或通过派单方转达。
