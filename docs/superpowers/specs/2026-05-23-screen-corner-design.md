# AcMind 屏幕圆角与触发角设计稿

> 目标：在现有 `配置` 二级页中新增一个独立的 `屏幕圆角` 功能区，既提供屏幕四角的视觉圆角遮罩，也提供四角独立触发动作。此功能不属于 NotchV2、灵动刘海、Dynamic Continent 或 AppShell 的视觉结构修改。

## 背景

当前项目里已经存在一个“配置”二级页，以及一套围绕四角触发的基础设施。新的需求不是继续修改灵动刘海本体，而是把“显示器视觉圆角”和“四角热区触发”整理成一个清晰独立的模块，作为桌面级覆盖层能力来实现。

用户希望达到的效果是：

- 屏幕视觉上从直角矩形变成圆角矩形
- 四个角仍可单独配置触发动作
- 视觉遮罩和热区逻辑可以分开调节
- 功能入口保留在现有 `配置` 二级页里

## 目标

1. 在现有 `配置` 页中增加 `屏幕圆角` 区块。
2. 增加一个独立的 `ScreenCornerOverlay` 模块，负责每块显示器的透明覆盖层。
3. 在屏幕四角绘制圆角遮罩，使显示器视觉上更接近圆角矩形。
4. 为左上、右上、左下、右下四个角分别配置触发动作。
5. 热区触发需要状态机，避免抖动和重复触发。
6. 多显示器下共用一套设置，先保证主显示器可用，再支持所有 `NSScreen`。

## 非目标

- 不修改 NotchV2 的形状或窗口结构
- 不把功能写进灵动刘海的内部实现
- 不改 AppShell 主界面结构
- 不新增独立一级菜单入口
- 不使用静态 PNG 或截图式贴图来模拟圆角

## 信息架构

### 设置入口

功能入口保持在现有：

- 主界面
- `配置` 二级页

在 `配置` 页中新增一个新的分区：

- `屏幕圆角`

### 页面内容

`屏幕圆角` 分区包含：

- 启用屏幕圆角
- 圆角半径
- 遮罩颜色
- 遮罩透明度
- 启用触发角
- 热区大小
- 触发延迟
- 四个角各自的动作
- 开机自动启用

## 架构

### 1. 模块边界

建议新增独立目录：

```text
Features/ScreenCorners/
├── ScreenCornerOverlayWindow.swift
├── ScreenCornerOverlayView.swift
├── ScreenCornerMaskShape.swift
├── ScreenCornerHotZone.swift
├── ScreenCornerAction.swift
├── ScreenCornerSettings.swift
├── ScreenCornerController.swift
└── ScreenCornerSettingsView.swift
```

如果当前项目里已经有适合承载 overlay 的公共窗口管理方式，也可以复用底层窗口代码，但逻辑上仍需保持为独立模块。

### 2. 数据模型

新增 `ScreenCornerSettings`，作为本功能的统一配置模型。

建议字段：

- `isEnabled`
- `radius`
- `maskColor`
- `opacity`
- `enabledCorners`
- `hotCornersEnabled`
- `hotZoneSize`
- `triggerDelay`
- `actions`
- `launchAtLogin`

动作类型建议定义为：

```swift
enum ScreenCornerAction: String, Codable, CaseIterable
```

Phase 1 先实现：

- `none`
- `showAcMind`
- `hideAcMind`
- `toggleAcMind`
- `showAgent`
- `showSystemStatus`
- `toggleNotch`
- `lockScreen`
- `startScreenSaver`

后续可以再扩展 Mission Control、Launchpad、Sleep Display 等系统动作。

### 3. 视觉层

每个显示器创建一个透明 `NSPanel` 或 `NSWindow` 作为 overlay。

窗口要求：

- 不抢焦点
- 默认不拦截鼠标
- 透明背景
- 可跨 Spaces
- 覆盖当前屏幕 frame
- 高于普通窗口

推荐属性：

```swift
isOpaque = false
backgroundColor = .clear
hasShadow = false
ignoresMouseEvents = true
level = .screenSaver 或 .statusBar
collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
```

### 4. 圆角遮罩

`ScreenCornerOverlayView` 负责绘制四角遮罩。

遮罩逻辑不是裁剪系统桌面，而是在透明窗口上绘制黑色角块，让屏幕视觉上变成圆角矩形。

几何原则：

- 圆角半径和热区大小分离
- 视觉圆角可以更大，触发热区可以更小
- 每个角都独立控制是否显示

建议使用 `ScreenCornerMaskShape` 来生成四角路径，按角落位置分别绘制遮罩。

### 5. 热角控制器

`ScreenCornerController` 单独监听全局鼠标移动，维护热角状态机。

推荐状态：

```swift
enum HotCornerState {
    case idle
    case hovering(corner: ScreenCorner, enteredAt: Date)
    case triggered(corner: ScreenCorner)
}
```

触发规则：

1. 鼠标进入热区后开始计时。
2. 停留超过 `triggerDelay` 后执行动作。
3. 鼠标离开热区后重置。
4. 同一个角触发后，必须离开再进入才可再次触发。
5. 关闭热区或关闭功能后立即停止监听和清理状态。

### 6. 动作执行

动作执行必须在主线程外部调度，不阻塞鼠标监听。

建议抽出一个轻量分发函数，将动作映射到现有 App 能力：

- 显示主窗口
- 显示 Agent 页面
- 显示系统状态页
- 切换 Notch 窗口
- 锁屏
- 启动屏幕保护程序

如果某些系统动作涉及权限或系统兼容性不稳定，应先保留为可选动作，不影响核心遮罩和基础热角。

## 设置持久化

设置应继续接入现有应用设置体系，而不是另起一套孤立存储。

持久化要保证：

- 重启后恢复启用状态
- 重启后恢复圆角半径和透明度
- 重启后恢复四角动作
- 重启后恢复热区大小与延迟
- 启动时可自动恢复 overlay 和监听状态

## 多显示器

Phase 1 至少支持主显示器。

实现上应直接面向 `NSScreen.screens`，为每块屏幕创建独立 overlay。

要求：

- 某块屏幕启用后，该屏幕显示遮罩
- 拔插显示器后自动重建 overlay
- 共用一套设置，避免先做 per-screen 配置膨胀范围

## UI 设计

`ScreenCornerSettingsView` 可以采用以下结构：

```text
ScreenCornerSettingsView
├── Header
├── PreviewCard
├── CornerRadiusSection
├── HotCornerSection
└── AdvancedSection
```

### PreviewCard

展示一个小型显示器轮廓：

```text
╭────────────╮
│            │
│            │
╰────────────╯
```

预览区域需要能直观反映：

- 当前圆角半径
- 角块是否启用
- 角块当前绑定的动作

## 兼容性

必须保证：

- 不影响 NotchV2
- 不影响灵动刘海
- 不影响主界面布局
- 不影响桌面正常点击与拖拽
- 不影响全屏应用的交互
- 不让 overlay 抢焦点
- 不让热区过大导致误触

## 测试计划

### 单元测试

- 四角命中判定
- 状态机进入/退出/重复触发逻辑
- 设置持久化与反序列化
- 默认值与升级兼容

### 构建测试

- `swift test --parallel`
- `xcodebuild -project AcMind.xcodeproj -scheme AcMind -configuration Debug build`

### 手工验证

- 开启后 overlay 是否出现
- 关闭后 overlay 是否完全消失
- 圆角是否与预期一致
- 鼠标停留是否按延迟触发
- 多显示器切换是否稳定

## 交付标准

完成后应满足：

1. `配置` 页中出现 `屏幕圆角` 区块。
2. 启用后屏幕四角出现圆角遮罩。
3. 关闭后遮罩完全消失。
4. 圆角半径可调。
5. 遮罩不影响鼠标点击。
6. 四个角可分别设置动作。
7. 鼠标停留超过触发延迟后执行动作。
8. 同一角必须离开后才能再次触发。
9. 至少支持主显示器，并能扩展到多显示器。
10. 不影响 NotchV2、灵动刘海和 AppShell。

