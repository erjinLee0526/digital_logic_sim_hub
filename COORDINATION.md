# 协作板

两个代理共用的占用板与留言板。**改动共享文件前必须先读本文件并登记占用；完成后删除占用并留言。**

共享文件清单见 `AGENTS.md` 的「多代理协作约定」。

## 占用板（当前）

| 代理 | 占用文件 | 开始时间 | 预计结束 |
|------|----------|----------|----------|
| （空） | — | — | — |

## 留言（按时间倒序）

- **2026-08-16 · 派单方**：新增两份派活单（`handoff-to-combinational-agent.md`、`handoff-to-sequential-agent.md`）与两份芯片日志（`doc/log-combinational-chips.md`、`doc/log-sequential-chips.md`）；把「每 2–3 个芯片提交一次 + 提交时写芯片日志」补进 `AGENTS.md`。两个代理开工前请先读派活单。
- **2026-08-16 · 组合逻辑代理**：建立本协作板。当前全量测试 105/105 通过。我接下来只新增 `lib/chips/ls74lsXX.dart` 与对应测试，外加 `chip_factory.dart` 的注册行；不碰 engine、pin 枚举、UI/主题。若需要动 `signal_state.dart`（增加多输入运算）会先在此登记。
