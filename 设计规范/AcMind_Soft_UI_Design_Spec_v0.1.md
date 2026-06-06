# AcMind Soft UI 设计规范 v0.1

> 目标：把 AcMind 从“系统默认工具界面”升级为一套可在 SwiftUI 中稳定落地的 Soft UI 产品界面。  
> 原则：所有尺寸固定、所有容器有最大/最小值、所有一级界面共享同一窗口骨架，避免不同页面大小漂移。

---

## 0. 适用范围

本规范适用于 AcMind macOS SwiftUI 主应用的一级页面：

- 首页 / Home
- Agent
- 收集箱 / Inbox
- 剪贴板 & 手机同步
- 日程
- 工具台
- 灵动大陆 & 配置
- 说入法
- 设置
- 模型管理

所有一级页面必须使用同一套：

- Window Shell
- Sidebar
- Top Bar
- Content Grid
- Card Token
- Spacing Token
- Shadow Token
- Typography Token

---

## 1. 设计目标

### 1.1 视觉方向

AcMind 主界面采用 **Soft UI / Neumorphism Lite** 风格。

核心特征：

- 浅灰白背景
- 大圆角容器
- 柔和阴影
- 黑色胶囊选中态
- 克制色彩点缀
- 高一致性卡片系统
- 高级但不牺牲工具效率

### 1.2 工程目标

必须满足：

1. 所有一级页面窗口大小一致。
2. Sidebar 宽度固定。
3. Top Bar 高度固定。
4. 内容区最大宽度固定。
5. 卡片尺寸来自固定规格，不允许自由生长。
6. 页面只允许在内容区内部滚动，不允许整体窗口布局变形。
7. 所有组件使用 token，不允许在业务页面里随手写圆角、阴影、颜色和间距。

---

## 2. 基础画布规范

### 2.1 主窗口尺寸

```swift
let windowMinWidth: CGFloat = 1280
let windowIdealWidth: CGFloat = 1440
let windowMaxWidth: CGFloat = 1440

let windowMinHeight: CGFloat = 820
let windowIdealHeight: CGFloat = 900
let windowMaxHeight: CGFloat = 900
```

主窗口固定为：

| 属性 | 数值 |
|---|---:|
| 最小宽度 | 1280 px |
| 理想宽度 | 1440 px |
| 最大宽度 | 1440 px |
| 最小高度 | 820 px |
| 理想高度 | 900 px |
| 最大高度 | 900 px |

> 推荐正式版本直接固定为 `1440 × 900`。  
> 如果需要兼容较小屏幕，最低只允许压缩到 `1280 × 820`，且页面结构不能改变。

### 2.2 页面统一结构

```text
┌──────────────────────────────────────────────────────────────┐
│ App Window 1440 × 900                                        │
│                                                              │
│  ┌──────────────┐   ┌─────────────────────────────────────┐  │
│  │ Sidebar      │   │ Main Area                           │  │
│  │ 280 × 868    │   │ 1112 × 868                          │  │
│  └──────────────┘   └─────────────────────────────────────┘  │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

| 区域 | 尺寸 |
|---|---:|
| Window | 1440 × 900 |
| 外边距 | 16 |
| Sidebar | 280 × 868 |
| Sidebar 与 Main 间距 | 16 |
| Main Area | 1112 × 868 |

计算方式：

```text
Main Width = 1440 - 16 - 280 - 16 - 16 = 1112
Main Height = 900 - 16 - 16 = 868
```

---

## 3. 全局 Token

### 3.1 Color Token

```swift
enum AcoreColor {
    static let appBackground = Color(hex: "#F5F6F8")
    static let surface = Color(hex: "#FFFFFF")
    static let surfaceSoft = Color(hex: "#F8F9FA")
    static let surfacePressed = Color(hex: "#ECEEF1")

    static let textPrimary = Color(hex: "#111111")
    static let textSecondary = Color(hex: "#5B616B")
    static let textTertiary = Color(hex: "#8A8F98")
    static let textInverse = Color(hex: "#FFFFFF")

    static let border = Color(hex: "#D7DBE1")
    static let divider = Color(hex: "#E7E9ED")

    static let accent = Color(hex: "#0A84FF")
    static let success = Color(hex: "#22C55E")
    static let warning = Color(hex: "#F59E0B")
    static let danger = Color(hex: "#EF4444")
    static let info = Color(hex: "#38BDF8")

    static let selectedDark = Color(hex: "#111827")
    static let selectedLight = Color(hex: "#FFFFFF")
}
```

### 3.2 Radius Token

```swift
enum AcoreRadius {
    static let xs: CGFloat = 6
    static let sm: CGFloat = 10
    static let md: CGFloat = 14
    static let lg: CGFloat = 18
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
    static let pill: CGFloat = 999
}
```

| 用途 | 圆角 |
|---|---:|
| 小标签 / 小按钮 | 10 |
| 输入框 | 18 |
| 普通卡片 | 24 |
| 主容器 | 32 |
| 胶囊按钮 | 999 |

### 3.3 Spacing Token

```swift
enum AcoreSpacing {
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 40
}
```

### 3.4 Shadow Token

```swift
enum AcoreShadow {
    static let softCard = ShadowSpec(
        color: Color.black.opacity(0.08),
        radius: 24,
        x: 0,
        y: 8
    )

    static let softPanel = ShadowSpec(
        color: Color.black.opacity(0.10),
        radius: 32,
        x: 0,
        y: 12
    )

    static let innerHighlight = ShadowSpec(
        color: Color.white.opacity(0.70),
        radius: 1,
        x: 0,
        y: 1
    )
}
```

### 3.5 Typography Token

```swift
enum AcoreTypography {
    static let display = Font.system(size: 28, weight: .semibold)
    static let title = Font.system(size: 20, weight: .semibold)
    static let headline = Font.system(size: 16, weight: .semibold)
    static let body = Font.system(size: 14, weight: .regular)
    static let bodyStrong = Font.system(size: 14, weight: .semibold)
    static let caption = Font.system(size: 12, weight: .regular)
    static let micro = Font.system(size: 11, weight: .regular)
}
```

---

## 4. Window Shell 固定规范

### 4.1 AppShell

所有一级页面必须包裹在 `AcoreAppShell` 内。

```swift
struct AcoreAppShell<Content: View>: View {
    let selectedModule: AcoreModule
    let content: Content

    var body: some View {
        HStack(spacing: 16) {
            AcoreSidebar(selectedModule: selectedModule)
                .frame(width: 280, height: 868)

            AcoreMainPanel {
                content
            }
            .frame(width: 1112, height: 868)
        }
        .padding(16)
        .frame(width: 1440, height: 900)
        .background(AcoreColor.appBackground)
    }
}
```

### 4.2 MainPanel

```swift
struct AcoreMainPanel<Content: View>: View {
    let content: Content

    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .frame(width: 1112, height: 868)
        .background(AcoreColor.surface.opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 28, x: 0, y: 12)
    }
}
```

---

## 5. Sidebar 固定规范

### 5.1 Sidebar 尺寸

| 属性 | 数值 |
|---|---:|
| 宽度 | 280 |
| 高度 | 868 |
| 内边距 | 24 |
| 顶部标题区高度 | 92 |
| 分组间距 | 28 |
| 菜单项高度 | 44 |
| 菜单项圆角 | 22 |

### 5.2 SidebarItem

```swift
struct AcoreSidebarItem: View {
    let icon: String
    let title: String
    let shortcut: String?
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .frame(width: 22, height: 22)

            Text(title)
                .font(AcoreTypography.bodyStrong)

            Spacer()

            if let shortcut {
                Text(shortcut)
                    .font(AcoreTypography.micro)
                    .foregroundStyle(isSelected ? AcoreColor.textInverse.opacity(0.72) : AcoreColor.textTertiary)
            }
        }
        .padding(.horizontal, 16)
        .frame(width: 232, height: 44)
        .foregroundStyle(isSelected ? AcoreColor.textInverse : AcoreColor.textPrimary)
        .background(isSelected ? AcoreColor.selectedDark : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: AcoreRadius.pill, style: .continuous))
    }
}
```

---

## 6. Main Area 统一布局

### 6.1 Main Area 内部结构

```text
Main Area 1112 × 868

┌────────────────────────────────────────────┐
│ Top Bar      1112 × 96                     │
├────────────────────────────────────────────┤
│ Page Content 1112 × 724                    │
├────────────────────────────────────────────┤
│ Status Bar   1112 × 48                     │
└────────────────────────────────────────────┘
```

| 区域 | 宽度 | 高度 |
|---|---:|---:|
| Top Bar | 1112 | 96 |
| Page Content | 1112 | 724 |
| Status Bar | 1112 | 48 |

### 6.2 Top Bar

```swift
struct AcoreTopBar: View {
    var title: String
    var subtitle: String?

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(AcoreTypography.display)
                    .foregroundStyle(AcoreColor.textPrimary)

                if let subtitle {
                    Text(subtitle)
                        .font(AcoreTypography.caption)
                        .foregroundStyle(AcoreColor.textSecondary)
                }
            }

            Spacer()

            AcorePillButton(title: "快速记录", icon: "pencil")
            AcorePillButton(title: "说入法", icon: "mic")
            AcoreSearchField()
        }
        .padding(.horizontal, 24)
        .frame(width: 1112, height: 96)
    }
}
```

### 6.3 Page Content 固定网格

页面内容区统一使用 12 栅格。

```text
Content Width = 1112
Horizontal Padding = 24 × 2
Grid Gap = 12 × 16
Column Width = 72

可用内容宽度 = 1112 - 48 = 1064
12列宽度 = 72 × 12 = 864
11个间距 = 16 × 11 = 176
合计 = 1040
剩余 24 作为栅格容差，两侧各 12
```

实际布局建议：

```swift
let columns = Array(
    repeating: GridItem(.fixed(72), spacing: 16),
    count: 12
)
```

---

## 7. Card 尺寸体系

所有卡片只允许使用以下尺寸，不允许业务页面自定义尺寸。

### 7.1 卡片基础尺寸

| 名称 | 跨列 | 宽度 | 高度 | 用途 |
|---|---:|---:|---:|---|
| Mini Card | 2 | 160 | 120 | 小状态、快捷入口 |
| Small Card | 3 | 248 | 156 | 单项指标 |
| Medium Card | 4 | 336 | 220 | 图表、状态组 |
| Large Card | 6 | 512 | 220 | 主图表、进程占用 |
| Wide Card | 12 | 1040 | 120 | 横向状态、搜索结果摘要 |
| Tall Card | 4 | 336 | 456 | 纵向列表 |
| Hero Card | 8 | 688 | 456 | 主内容区 |

计算公式：

```text
cardWidth = columnWidth × span + gap × (span - 1)
columnWidth = 72
gap = 16
```

### 7.2 卡片固定规则

```swift
enum AcoreCardSize {
    case mini      // 160 × 120
    case small     // 248 × 156
    case medium    // 336 × 220
    case large     // 512 × 220
    case wide      // 1040 × 120
    case tall      // 336 × 456
    case hero      // 688 × 456

    var size: CGSize {
        switch self {
        case .mini: return CGSize(width: 160, height: 120)
        case .small: return CGSize(width: 248, height: 156)
        case .medium: return CGSize(width: 336, height: 220)
        case .large: return CGSize(width: 512, height: 220)
        case .wide: return CGSize(width: 1040, height: 120)
        case .tall: return CGSize(width: 336, height: 456)
        case .hero: return CGSize(width: 688, height: 456)
        }
    }
}
```

### 7.3 Soft Card

```swift
struct AcoreSoftCard<Content: View>: View {
    let size: AcoreCardSize
    let content: Content

    var body: some View {
        content
            .padding(20)
            .frame(width: size.size.width, height: size.size.height)
            .background(AcoreColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: .black.opacity(0.08), radius: 24, x: 0, y: 8)
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(AcoreColor.border.opacity(0.55), lineWidth: 1)
            }
    }
}
```

---

## 8. 一级页面统一尺寸规范

### 8.1 所有页面必须一致

所有一级页面必须使用：

```swift
.frame(width: 1112, height: 868)
```

页面内部内容区必须使用：

```swift
.frame(width: 1112, height: 724)
```

允许滚动的只有：

```swift
ScrollView(.vertical)
```

但滚动区域本身高度固定为 `724`。

### 8.2 禁止行为

禁止在一级页面中出现：

```swift
.frame(maxWidth: .infinity, maxHeight: .infinity)
```

禁止页面根据内容撑开窗口。

禁止不同页面使用不同 padding。

禁止业务组件直接写：

```swift
.cornerRadius(...)
.shadow(...)
.padding(...)
```

必须使用统一组件或 token。

---

## 9. 首页布局规范

首页采用固定 Dashboard 布局。

### 9.1 首页内容布局

```text
Row 1: Small × 4
Row 2: Large × 2
Row 3: Large × 1 + Medium × 1 + Medium × 1
Row 4: Wide × 1
```

### 9.2 首页卡片分配

| 位置 | 组件 | 尺寸 |
|---|---|---|
| Row 1 Col 1 | CPU | Small Card |
| Row 1 Col 2 | 内存 | Small Card |
| Row 1 Col 3 | 网络 | Small Card |
| Row 1 Col 4 | 磁盘 | Small Card |
| Row 2 Left | 系统状态总览 | Large Card |
| Row 2 Right | 状态指示 | Large Card |
| Row 3 Left | 设备温度 | Large Card |
| Row 3 Middle | 风扇转速 | Medium Card |
| Row 3 Right | 快速操作 | Medium Card |
| Row 4 | 底部状态条 | Wide Card |

> 如果存在电池信息，电池进入 Row 1 替换磁盘；磁盘进入 Row 4 状态条。  
> 如果设备无电池，电池卡不显示，不允许出现大面积 N/A 卡片。

---

## 10. Agent 页面布局规范

Agent 页面必须复用同一窗口骨架。

### 10.1 Agent 布局

```text
Content Area 1112 × 724

┌──────────────┬──────────────────────────────┐
│ Conversation │ Chat Panel                    │
│ 336 × 724    │ 704 × 724                     │
└──────────────┴──────────────────────────────┘
```

| 区域 | 尺寸 |
|---|---:|
| 左侧会话列表 | 336 × 724 |
| 间距 | 16 |
| 右侧对话区 | 704 × 724 |

### 10.2 Agent 组件

| 组件 | 尺寸 |
|---|---:|
| 会话列表容器 | 336 × 724 |
| 会话项 | 288 × 64 |
| 对话区 | 704 × 724 |
| 输入框 | 656 × 64 |
| 消息气泡最大宽度 | 520 |

---

## 11. 收集箱 / 剪贴板页面布局规范

高密度内容页允许使用网格，但不允许突破固定容器。

### 11.1 页面结构

```text
Content Area 1112 × 724

┌──────────────┬──────────────────────────────┐
│ Filter Panel │ Item Grid                     │
│ 248 × 724    │ 800 × 724                     │
└──────────────┴──────────────────────────────┘
```

| 区域 | 尺寸 |
|---|---:|
| 筛选栏 | 248 × 724 |
| 间距 | 16 |
| 内容网格 | 800 × 724 |

### 11.2 内容卡片

| 类型 | 尺寸 |
|---|---:|
| 文本卡片 | 248 × 180 |
| 图片卡片 | 248 × 220 |
| 文件卡片 | 248 × 180 |
| 链接卡片 | 248 × 180 |

网格规则：

```swift
let itemColumns = Array(
    repeating: GridItem(.fixed(248), spacing: 16),
    count: 3
)
```

---

## 12. 日程页面布局规范

### 12.1 页面结构

```text
Content Area 1112 × 724

┌──────────────┬──────────────────────────────┐
│ Date Panel   │ Calendar View                │
│ 248 × 724    │ 800 × 724                    │
└──────────────┴──────────────────────────────┘
```

### 12.2 时间网格

| 项 | 数值 |
|---|---:|
| 日视图宽度 | 800 |
| 日视图高度 | 724 |
| 小时行高 | 60 |
| 15 分钟块高度 | 15 |
| 左侧时间轴宽度 | 56 |
| 任务块最小高度 | 15 |
| 任务块圆角 | 12 |

---

## 13. 设置 / 模型管理页面布局规范

### 13.1 页面结构

```text
Content Area 1112 × 724

┌──────────────┬──────────────────────────────┐
│ Setting Nav  │ Setting Detail               │
│ 248 × 724    │ 800 × 724                    │
└──────────────┴──────────────────────────────┘
```

### 13.2 设置项

| 组件 | 尺寸 |
|---|---:|
| 设置导航项 | 200 × 44 |
| 设置组卡片 | 800 × auto，最小 120，最大 360 |
| 单行设置项 | 752 × 52 |
| 开关 | 44 × 26 |
| 输入框 | 320 × 40 |

---

## 14. 状态条规范

底部状态条固定在 Main Area 内部底部。

```swift
struct AcoreStatusBar: View {
    var body: some View {
        HStack(spacing: 32) {
            AcoreStatusItem(icon: "cpu", title: "CPU", value: "21%")
            AcoreStatusItem(icon: "memorychip", title: "内存", value: "34.2 GB")
            AcoreStatusItem(icon: "network", title: "网络", value: "0.2 MB/s")
            AcoreStatusItem(icon: "shield", title: "权限", value: "正常")
        }
        .padding(.horizontal, 24)
        .frame(width: 1112, height: 48)
        .background(AcoreColor.surface.opacity(0.82))
    }
}
```

---

## 15. 统一交互规范

### 15.1 Hover

| 组件 | Hover 效果 |
|---|---|
| Sidebar Item | 背景 `#ECEEF1`，选中项不变 |
| Card | y: -2，阴影增强到 0.10 |
| Button | 背景略加深 |
| Icon Button | 背景出现浅灰圆形 |

### 15.2 Press

| 组件 | Press 效果 |
|---|---|
| Sidebar Item | scale 0.98 |
| Card | scale 0.995 |
| Button | scale 0.97 |

### 15.3 Animation

```swift
enum AcoreMotion {
    static let quick = Animation.easeOut(duration: 0.15)
    static let normal = Animation.easeInOut(duration: 0.20)
    static let emphasized = Animation.spring(response: 0.30, dampingFraction: 0.86)
}
```

---

## 16. SwiftUI 落地顺序

### Phase 1：Token

先建立：

```text
AcoreColor.swift
AcoreRadius.swift
AcoreSpacing.swift
AcoreShadow.swift
AcoreTypography.swift
AcoreMotion.swift
AcoreCardSize.swift
```

### Phase 2：基础组件

再建立：

```text
AcoreAppShell.swift
AcoreSidebar.swift
AcoreSidebarItem.swift
AcoreMainPanel.swift
AcoreTopBar.swift
AcoreStatusBar.swift
AcoreSoftCard.swift
AcorePillButton.swift
AcoreSearchField.swift
```

### Phase 3：页面迁移

迁移顺序：

1. 首页
2. 设置
3. 模型管理
4. Agent
5. 收集箱
6. 剪贴板 & 手机同步
7. 日程
8. 工具台
9. 灵动大陆 & 配置
10. 说入法

---

## 17. Codex / Trae 执行要求

执行时必须遵守：

1. 不允许改窗口尺寸。
2. 不允许改 Sidebar 宽度。
3. 不允许改 Main Area 宽度。
4. 不允许业务页面直接写 shadow / radius / color。
5. 所有页面必须走 `AcoreAppShell`。
6. 所有卡片必须走 `AcoreSoftCard`。
7. 所有页面内容区高度必须固定为 `724`。
8. 内容超出时使用内部 ScrollView，不允许撑开页面。
9. 所有一级页面在切换时窗口大小不得变化。
10. 每次修改后必须截图对比：首页、Agent、收集箱、设置四个页面。

---

## 18. 验收标准

### 18.1 尺寸验收

| 项 | 必须满足 |
|---|---|
| 主窗口 | 1440 × 900 |
| Sidebar | 280 × 868 |
| Main Area | 1112 × 868 |
| Top Bar | 1112 × 96 |
| Content Area | 1112 × 724 |
| Status Bar | 1112 × 48 |

### 18.2 视觉验收

必须满足：

- 页面背景统一为 `#F5F6F8`
- 主容器圆角统一为 `32`
- 卡片圆角统一为 `24`
- Sidebar 选中态为黑色胶囊
- 卡片不允许出现系统默认蓝色大面积选中态
- 图标尺寸统一为 16 / 18 / 22 三档
- 页面切换无尺寸跳动
- 内容区只在内部滚动

### 18.3 工程验收

必须满足：

- 所有 Token 独立文件管理
- 页面无裸写颜色 HEX
- 页面无裸写 `.shadow(...)`
- 页面无裸写 `.cornerRadius(...)`
- 页面无任意 `.frame(maxWidth: .infinity, maxHeight: .infinity)`
- 所有一级页面通过同一个 Shell 渲染

---

## 19. 最终结论

AcMind 的主界面不再按“每个页面单独设计”推进，而是统一为：

```text
固定窗口尺寸
固定三段式骨架
固定 Sidebar
固定 Top Bar
固定 Content Area
固定 Status Bar
固定 Card Size
固定 Token System
```

这样可以保证：

1. 所有页面大小一致。
2. 视觉系统不漂移。
3. SwiftUI 实现可控。
4. Codex / Trae 可以按组件系统稳定落地。
5. 后续扩展新页面时不会破坏主界面完成度。
