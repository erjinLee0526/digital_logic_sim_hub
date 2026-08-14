# Digital Logic Simulator

跨平台数字逻辑电路仿真器，基于 Flutter 开发，支持 74LS 系列 TTL 芯片的电路搭建与四态逻辑仿真（0 / 1 / Z / X），带传播延迟的时序仿真和 JSON 电路持久化。

## 功能特性

- **芯片系统**：内置 74LS00 四路 2 输入与非门（DIP-14），通过芯片注册表可扩展更多型号；芯片渲染包含圆角矩形、缺口标记、型号/门数/输入数/功能描述和引脚标签
- **画布编辑**：缩放（0.1x–5x）、平移；Wire / Move / Del 三种编辑模式；20px 网格吸附；组件间自动保持 40px 最小间距（添加时自动找位、拖动时阻止重叠）；引脚点击选中、ghost wire 预览、长按拖动、点击空白取消选中；引脚标签随缩放切换（低倍率仅编号，高倍率编号+功能名）
- **自动布线**：正交（Manhattan）走线，候选列扫描（半格步长）+ 绕行避障 + 加权 A* 兜底三层策略；路径按交叉数、同向重叠长度、软避让侵入等指标打分，新线自动绕开已有线；组件外围 2px 硬避让与 20px 软避让；统一对齐 20px 网格，多线引脚自动绘制连接点，走线颜色跟随信号状态
- **仿真引擎**：离散事件仿真（DES）事件队列，四态逻辑运算（NAND/AND/NOR/OR/XOR/NOT），传播延迟模拟（74LS00 约 10ns），多驱动冲突检测，支持单步 / 连续运行 / 重置
- **I/O 面板**：专用 INPUT 双输入开关组件（IN1/IN2 两路独立高低电平，画布点击就近切换）+ 专用 LED 输出组件（信号状态显示）；面板按全局编号展开所有输入开关
- **数据持久化**：JSON 保存 / 加载电路、文件列表浏览、新建电路
- **界面**：暗色主题（navy blue 调色板），信号状态配色（高绿 / 低蓝 / 高阻灰 / 未知红）；状态栏显示引脚友好描述（型号 · pin 编号 · 标签(方向)）

## 支持芯片

| 型号 | 功能 | 封装 / 类型 |
|------|------|------|
| 74LS00 | 4 Gates / 2 Input / NAND | DIP-14 |
| INPUT | 双输入开关（IN1/IN2 两路高低电平） | 80×80 组件 |
| LED | 高电平点亮指示 | 80×80 组件 |

> 规则文档 `doc/wiring_rules.md` 已升级到 v6，整理 DIP-14 / DIP-16 / DIP-20 / DIP-24 的引脚分布约定，并记录 20px 栅格吸附、组件避障与导线路由规则。

## 技术栈

| 层面 | 选择 |
|------|------|
| 框架 | Flutter + Dart（运行本项目建议 Flutter ≥ 3.38.4、Dart ≥ 3.10.3） |
| 状态管理 | Riverpod（StateNotifierProvider / StateProvider） |
| 画布渲染 | CustomPainter + InteractiveViewer |
| 仿真引擎 | 离散事件仿真，HeapPriorityQueue 事件队列 |
| 文件格式 | JSON（path_provider 持久化） |
| 依赖 | flutter_riverpod、uuid、path_provider、collection |

## 快速开始

### 环境要求

- 安装 Flutter SDK，建议 **Flutter ≥ 3.38.4 / Dart ≥ 3.10.3**（与 `pubspec.lock` 的解析版本一致；过旧的版本可能无法解析依赖）
- 开启 Windows 桌面支持（仓库目前只包含 Windows 平台目录）

### 安装依赖并运行

第三方库不会随仓库上传。克隆后必须先执行一次 `flutter pub get`，它会按照 `pubspec.yaml` 和 `pubspec.lock` 自动下载 `flutter_riverpod`、`uuid`、`path_provider`、`collection` 及其间接依赖；否则 IDE 会报 `package:xxx` 找不到。

```bash
flutter pub get
flutter run
```

> 如果因网络原因下载失败（仓库的 lock 文件指向国内镜像 `pub.flutter-io.cn`），可删除 `pubspec.lock` 后改用官方源重新解析：
>
> PowerShell：`$env:PUB_HOSTED_URL="https://pub.dev"; flutter pub get`

运行单元测试：

```bash
flutter test
```

## 项目结构

```
lib/
├── main.dart                  # 入口：ProviderScope + 暗色主题 + 横竖屏适配
├── app.dart                   # 主界面：AppBar + 芯片库 + 画布 + I/O 面板 + 状态栏
├── models/                    # 数据模型：信号四态、引脚、芯片定义/实例、导线、电路、网格吸附
├── chips/                     # 芯片实现：ChipFactory 注册表 + 74LS00 + INPUT + LED
├── engine/                    # 仿真引擎：DES 事件队列、事件、网表（预留）
├── canvas/                    # 画布：InteractiveViewer 容器、CustomPainter、点击检测
├── widgets/                   # 工具栏、芯片库面板、I/O 面板、状态栏
├── providers/                 # Riverpod：电路、编辑器工具、仿真引擎
├── services/                  # JSON 序列化与文件读写
└── theme/                     # 暗色主题
```

## 使用说明

1. 从左侧**芯片库**点击添加 74LS00 芯片到画布
2. 选择 **Wire** 模式，依次点击两个引脚完成连线；**Move** 模式拖动芯片/组件，位置会自动吸附到 20px 网格，与其他组件过近时会阻止重叠；**Del** 模式删除芯片/导线
3. 点击画布上的 **INPUT** 组件可按点击位置就近切换 IN1/IN2，或在右侧 **I/O 面板**按全局编号切换各输入开关，观察输出 LED 与走线颜色变化
4. 使用底部状态栏进行**单步 / 运行 / 重置**，通过菜单保存或加载电路文件

## 相关文档

- [doc/wiring_rules.md](doc/wiring_rules.md) — 连线规则 v6：坐标约定、DIP 引脚分布、20px 网格吸附、正交走线与分支路由算法
- [CLAUDE.md](CLAUDE.md) — 开发日志：架构说明、已修复 Bug、设计约定
- [AGENTS.md](AGENTS.md) — 给 AI 编码代理（Codex / Claude Code 等）的项目操作说明

## 路线图

- [ ] 更多 74LS 芯片（74LS02 / 74LS04 / 74LS08 / 74LS32 / 74LS86 等）
- [x] 专用 I/O 开关 / LED 组件
- [ ] 撤销 / 重做
- [ ] 导线中段分支（T-junction）
- [ ] 总线支持
- [ ] 导出图片 / PDF
- [ ] 子电路 / 层次化设计
- [ ] 大规模电路渲染性能优化
