# Digital Logic Simulator — 开发日志

## 项目概述

跨平台（Android/iOS/Windows）数字逻辑电路仿真软件，基于 Flutter 3.x + Dart。支持 74LS 系列芯片的四态逻辑仿真（0/1/Z/X）和时序仿真（传播延迟）。

## 环境准备

首次克隆后先运行 `flutter pub get` 安装依赖（要求 Flutter ≥ 3.38.4 / Dart ≥ 3.10.3，以 `pubspec.lock` 为准）。第三方库不随仓库提供，未执行此命令前 `package:xxx` 导入会报错。

## 技术栈

| 层面 | 选择 |
|------|------|
| 框架 | Flutter 3.x + Dart |
| 状态管理 | Riverpod (StateNotifierProvider, StateProvider) |
| 画布渲染 | CustomPainter + InteractiveViewer |
| 仿真引擎 | 离散事件仿真 (DES)，HeapPriorityQueue 事件队列 |
| 文件格式 | JSON（path_provider 持久化） |
| 依赖 | flutter_riverpod, uuid, path_provider, collection |

## 项目结构

```
lib/
├── main.dart                    # 入口，ProviderScope + 暗色主题
├── app.dart                     # 主界面：AppBar + 芯片库 + 画布 + I/O面板 + 状态栏
├── models/
│   ├── signal_state.dart        # 四态枚举：low/high/highZ/unknown + 逻辑运算
│   ├── pin.dart                 # PinDefinition (模板) + PinState (运行时)
│   ├── chip_definition.dart     # 抽象芯片定义（引脚布局、evaluate()）
│   ├── chip_instance.dart       # 芯片实例（位置、引脚状态、rect计算）
│   ├── wire.dart                # 导线（pinIdA ↔ pinIdB）
│   └── circuit.dart             # 电路 = 芯片列表 + 导线列表 (immutable + copyWith)
├── chips/
│   ├── chip_factory.dart        # 芯片注册表: {'74LS00': () => Chip74LS00()}
│   └── ls74ls00.dart            # 74LS00 四路2输入与非门 (DIP-14)
├── engine/
│   ├── simulation_engine.dart   # DES 引擎：rebuild → injectSignal → step/runUntilStable
│   ├── simulation_event.dart    # 仿真事件（timePs, pinId, newValue, priority）
│   └── netlist.dart             # (预留) 网表转换
├── canvas/
│   ├── circuit_canvas.dart      # InteractiveViewer + GestureDetector 容器
│   ├── circuit_painter.dart     # CustomPainter：网格、正交走线、芯片、引脚、接线点
│   └── hit_test.dart            # 点击检测：引脚 > 芯片体 > 导线 > 空白
├── widgets/
│   ├── toolbar.dart             # 浮动工具栏：Wire / Move / Del 三种模式
│   ├── chip_library_panel.dart  # 左侧芯片库：搜索 + 点击添加
│   ├── io_panel.dart            # 右侧 I/O 面板：输入开关 + 输出 LED
│   └── status_bar.dart          # 底部状态栏
├── providers/
│   ├── circuit_provider.dart    # CircuitNotifier：CRUD 操作 + forceUpdate()
│   ├── editor_provider.dart     # EditorTool 枚举 + 选中状态 providers
│   └── simulation_provider.dart # 仿真引擎单例 provider
├── services/
│   └── file_service.dart        # JSON 序列化/反序列化，文件读写
└── theme/
    └── dark_theme.dart          # 暗色主题：navy blue 调色板，信号颜色映射
```

## 已完成功能

### 芯片系统
- [x] 74LS00 四路2输入与非门（14引脚 DIP 封装）
- [x] 芯片渲染：圆角矩形 + 缺口标记 + 型号标签 + 描述文字 + 引脚编号
- [x] 引脚颜色：输入(蓝)、输出(黄)、VCC(红)、GND(灰)
- [x] 芯片注册表 ChipFactory，可扩展更多型号

### 画布交互
- [x] InteractiveViewer：缩放(0.1x-5x)、平移
- [x] 三种编辑模式：Wire（连线）、Move（拖动芯片）、Del（删除）
- [x] 引脚点击选中高亮 + ghost wire 预览
- [x] 长按芯片 + 拖动移动（Move 模式禁用 InteractiveViewer pan）
- [x] 芯片/导线/引脚删除
- [x] 点击空白取消所有选中

### 导线系统
- [x] 正交走线（Manhattan routing）
- [x] 两阶段路由算法：
  - Phase 1: 尝试50个候选路由列，逐段碰撞检测
  - Phase 2: 绕行——从芯片上方/下方绕过障碍物
- [x] 多线连接引脚处绘制接线点（junction dot）
- [x] 走线颜色跟随信号状态
- [x] 同芯片不同引脚可连线（反馈环路支持）

### 仿真引擎
- [x] 离散事件仿真 (DES)，HeapPriorityQueue 时间队列
- [x] 四态逻辑：NAND/AND/NOR/OR/XOR/NOT 运算
- [x] 未知态(X)和高阻态(Z)处理
- [x] 传播延迟模拟（74LS00: 10ns = 10000ps）
- [x] 导线信号传播（零延迟）
- [x] 多驱动冲突检测
- [x] 单步执行 (step) / 连续运行 (runUntilStable) / 重置
- [x] I/O 面板：输入开关（Toggle 高低电平）+ 输出 LED（显示状态）

### 数据持久化
- [x] JSON 格式保存/加载电路
- [x] 文件列表浏览 + 加载对话框
- [x] 新建电路

## 修复的关键 Bug

### 1. 芯片消失（仿真运行时）
- **原因**: `ref.invalidate(circuitProvider)` 在 `StateNotifierProvider` 上会销毁并重建 notifier，新 notifier 初始化为 `const Circuit()` 空电路
- **修复**: 新增 `CircuitNotifier.forceUpdate()`，调用 `state = state.copyWith()` 创建新 Circuit 包装对象触发 UI 重绘，内部芯片数据保留
- **影响文件**: `app.dart` (3处), `io_panel.dart` (1处)

### 2. 坐标双重变换
- **原因**: `_toCircuitCoords()` 对 InteractiveViewer 的变换矩阵取逆后应用到坐标。但 GestureDetector 在 Transform widget 内部，`localPosition` 已经是 canvas 坐标。双重变换导致坐标错误
- **修复**: 移除 `_toCircuitCoords`，所有事件处理直接用 `localPos`
- **影响文件**: `circuit_canvas.dart`

### 3. Move 模式拖动芯片失败
- **原因**: InteractiveViewer 的 pan 手势和 LongPressGestureRecognizer 竞争，pan 优先抢到手势
- **修复**: Move 模式下设置 `InteractiveViewer.panEnabled = false`
- **影响文件**: `circuit_canvas.dart`

### 4. 正交走线穿过芯片体
- **原因**: 旧算法只检测垂直段碰撞，不检测水平引出/引入段；且两芯片同侧引脚相连时水平回程段必然穿过中间芯片
- **修复**: 
  - Phase 1: 候选列遍历 + 全5段路径碰撞检测
  - Phase 2: 绕行策略——走到所有芯片外侧 → 上方/下方越过 → 平移进入
- **影响文件**: `circuit_painter.dart`, `hit_test.dart`

### 5. 编译错误
- `Icons.circuit_mac` → `Icons.cable`
- `PriorityQueue` → `HeapPriorityQueue`（需 `import 'package:collection/collection.dart'`）
- `fromBool(a != b)` → `SignalState.fromBool(a != b)`
- 缺少 `import 'package:flutter/services.dart'`（HapticFeedback）

## 设计约定

### 坐标系统
- Canvas 尺寸: 10000×10000 电路单位
- GestureDetector 在 InteractiveViewer 的 Transform 内部，`localPosition` 直接为 canvas 坐标
- 芯片 position 为矩形中心点
- 引脚位置 = chip.position + definition.pinRelativePositions[pinNum]

### 引脚编号规则
- 标准 DIP 封装：左侧 1-7（从上到下），右侧 14-8（从上到下）
- pinId 格式: `"{chipId}_{pinNumber}"`
- 引脚 1-7 出口方向为左(-1)，引脚 8-14 出口方向为右(+1)

### 状态管理
- Circuit 为 immutable 模型，变更通过 `copyWith` 创建新实例
- 仿真引擎通过 `forceUpdate()` 触发 UI 重绘（引擎直接修改 ChipInstance 内部状态）
- Provider 层次：circuitProvider → editorProvider → simulationProvider

### 信号状态颜色
- High (1): 绿色 `#00E676`
- Low (0): 蓝色 `#448AFF`  
- High-Z: 灰色 `#9E9E9E`
- Unknown (X): 红色 `#FF5252`

## 下一步计划

- [ ] 添加更多 74LS 芯片（74LS02, 74LS04, 74LS08, 74LS32, 74LS86 等）
- [ ] 完善 I/O 面板：专用开关/LED 组件（不用 74LS00 替代）
- [ ] 支持撤销/重做
- [ ] 支持导线中段分支（T-junction）而不仅限于引脚处
- [ ] 支持总线
- [ ] 导出图片/PDF
- [ ] 子电路/层次化设计
- [ ] 性能优化：大规模电路时只重绘脏区域
