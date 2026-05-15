# NotchV2 Today Page Reference Params

> 生成时间：2026-05-14  
> 参考基准：当前代码中的 880 版「今日」展开态。  
> 说明：本文只记录当前可复用的布局参数，不修改任何 UI 代码。

## 1. Container

### 1.1 展开态外层容器参数

| 参数 | 值 | 说明 |
|---|---:|---|
| `expandedWidth` | `880` | 代码写死 |
| `expandedHeight` | `440` | 代码写死 |
| `cornerRadius` | `top = 20`, `bottom = 32` | 代码写死 |
| `backgroundColor` | `#050607` | `NotchV2DesignTokens.rootBackground` |
| `borderColor` | `white.opacity(0.075)` | 代码写死 |
| `borderWidth` | `1` | 代码写死 |
| `shadow` | `black.opacity(0.55), radius 28, x 0, y 16` | 代码写死 |
| `clipShape` | `NotchShape(topCornerRadius: 20, bottomCornerRadius: 32)` | 代码写死 |

### 1.2 位置关系

- 展开态窗口顶边贴近屏幕顶部。
- 顶部菜单栏包含在展开态中。
- 内容从顶部菜单栏下方开始。
- 这是一个紧凑版展开态，不是三栏大母版。

### 1.3 外层边距

| 参数 | 值 | 说明 |
|---|---:|---|
| `contentLeft` | `32` | 代码写死 |
| `contentRight` | `32` | 代码写死 |
| `contentTop` | `32` | 代码写死 |
| `contentBottom` | `12` | 代码写死 |

补充：

- 当前 880 版页面内容主要依赖卡片内部布局，而不是大面积三栏栅格。
- 当前底部留白较小，属于紧凑工作台风格。

## 2. Top Bar

### 2.1 顶部菜单栏参数

| 参数 | 值 | 说明 |
|---|---:|---|
| `topBarHeight` | `36` | 代码写死 |
| `topBarWidth` | `880` | 代码写死 |
| `topBarPaddingHorizontal` | `56` | 代码写死 |
| `topBarItemSpacing` | 左侧入口间距约 `28~32` | 代码+推算 |
| `topBarBackground` | `black` | 代码写死 |
| `topBarCornerRadius` | `0` | 顶栏本体无圆角 |
| `activeIndicatorWidth` | `34`，`AI` 为 `24` | 代码写死 |
| `activeIndicatorHeight` | `2` | 代码写死 |
| `activeIndicatorOffsetY` | `7` | 代码写死 |

### 2.2 左侧页面入口区域

- `今日`：`32 × 24`
- `音乐`：`32 × 24`
- `AI`：`28 × 24`
- `日程`：`32 × 24`

文字颜色：

- 选中态：`primaryText = white.opacity(0.92)`
- 未选中态：`white.opacity(0.55)`

### 2.3 中间刘海避让区

| 参数 | 值 |
|---|---:|
| `width` | `160` |
| `height` | `30` |
| `x / y` | `440 / 15` |

说明：

- 顶栏 debug 覆盖层里仍保留更大的调试参考，但当前实际生效的是 `160 × 30` 的黑色避让块。

### 2.4 右侧状态区域

- 电量：绿色电池条 `18 × 9`，整体区域约 `72 × 22`
- 设置：齿轮图标 `16`
- 收起按钮：`24 × 24`

右侧布局：

- 电量块：`x = 48`
- 设置块：`x = 140`
- 收起按钮：`x = 208`

## 3. Today Grid

### 3.1 今日页整体布局

当前「今日」页不是统一三栏布局，而是一个紧凑型的卡片拼接布局。

| 参数 | 值 | 说明 |
|---|---:|---|
| `contentLeft` | `32` | 代码写死 |
| `contentRight` | `32` | 代码写死 |
| `contentTop` | `32` | 代码写死 |
| `contentBottom` | `12` | 代码写死 |
| `contentWidth` | `816` | `880 - 32 - 32` |

### 3.2 卡片位置

| 区块 | x | y | 宽 | 高 |
|---|---:|---:|---:|---:|
| 左侧时间线卡 | `134` | `183` | `160` | `354` |
| 当前播放卡 | `428` | `65` | `396` | `118` |
| 快捷入口卡 | `428` | `181` | `396` | `82` |
| 任务卡 | `428` | `299` | `396` | `122` |
| 右侧 Agent 卡 | `732` | `183` | `180` | `354` |

说明：

- 当前页面使用的是绝对位置感很强的紧凑布局。
- 左右两侧卡片高度较高，中间三张卡片承载主要信息密度。

## 4. Left Column

### 4.1 左侧「日程」卡片参数

| 参数 | 值 |
|---|---:|
| `cardX` | `134` |
| `cardY` | `183` |
| `cardWidth` | `160` |
| `cardHeight` | `354` |
| `cardCornerRadius` | `24` |
| `cardPaddingTop` | `16` |
| `cardPaddingLeft` | `16` |
| `cardPaddingRight` | `16` |
| `cardPaddingBottom` | `16` |

### 4.2 文字层级

| 参数 | 值 |
|---|---:|
| `titleFontSize` | `14` |
| `titleFontWeight` | `.semibold` |
| `subtitleFontSize` | `10` |
| `subtitleColor` | `secondaryText = white.opacity(0.68)` |
| `timelineTimeFontSize` | `9` |
| `timelineTimeColor` | `accentPurple` |
| `timelineTitleFontSize` | `12` |
| `timelineTitleColor` | `primaryText` |
| `timelineRowGap` | `8` |
| `timeToTitleGap` | `8` |

### 4.3 时间线

时间线当前为四行列表：

- `09:00 产品设计评审`
- `11:00 需求沟通同步`
- `16:30 音乐联动评估`
- `18:30 健身锻炼`

说明：

- 时间左对齐。
- 每行是一个横向状态块，不是绝对坐标定位。

## 5. Center Column

### 5.1 当前播放 / 音乐卡片

| 参数 | 值 |
|---|---:|
| `musicCardX` | `428` |
| `musicCardY` | `65` |
| `musicCardWidth` | `396` |
| `musicCardHeight` | `118` |
| `musicCardCornerRadius` | `24` |
| `musicCardPadding` | `16` |
| `albumSize` | `176 × 176` |
| `albumCornerRadius` | `34` |

### 5.2 快捷入口卡片

| 参数 | 值 |
|---|---:|
| `quickCardX` | `428` |
| `quickCardY` | `181` |
| `quickCardWidth` | `396` |
| `quickCardHeight` | `82` |
| `quickCardPadding` | `16` |

### 5.3 任务卡片

| 参数 | 值 |
|---|---:|
| `taskCardX` | `428` |
| `taskCardY` | `299` |
| `taskCardWidth` | `396` |
| `taskCardHeight` | `122` |
| `taskCardPadding` | `16` |

## 6. Right Column

### 6.1 右侧 Agent 卡片

| 参数 | 值 |
|---|---:|
| `rightCardX` | `732` |
| `rightCardY` | `183` |
| `rightCardWidth` | `180` |
| `rightCardHeight` | `354` |
| `rightCardCornerRadius` | `24` |
| `rightCardPadding` | `16` |

说明：

- 右栏当前是单卡结构，不是三张状态卡堆叠。
- 这是 880 版紧凑布局的一部分。

## 7. Tokens

### 7.1 颜色

| Token | 值 |
|---|---|
| `background` | `#050607` |
| `cardBackground` | `#0B0C0E` |
| `cardBorder` | `white.opacity(0.085)` |
| `primaryText` | `white.opacity(0.96)` |
| `secondaryText` | `white.opacity(0.68)` |
| `tertiaryText` | `white.opacity(0.46)` |
| `purpleAccent` | `#B232FF` |
| `greenStatus` | `#35F76A` |

### 7.2 圆角

| Token | 值 |
|---|---:|
| `containerRadius` | `20 / 32` |
| `cardRadius` | `24` |
| `innerCardRadius` | `14` |
| `buttonRadius` | `12` |

### 7.3 间距

| Token | 值 |
|---|---:|
| `pagePaddingHorizontal` | `32` |
| `pagePaddingTop` | `32` |
| `pagePaddingBottom` | `12` |
| `columnGap` | `16` |
| `cardGap` | `20` |
| `sectionGap` | `24` |
| `rowGap` | `16` |
| `innerPadding` | `16` |

### 7.4 字体

| Token | 值 |
|---|---:|
| `largeTitle` | `20` |
| `title` | `14` |
| `body` | `14` |
| `caption` | `10` |
| `micro` | `8` |

### 7.5 按钮

| Token | 值 |
|---|---:|
| `primaryButtonHeight` | `24` |
| `secondaryButtonHeight` | `24` |
| `buttonPaddingHorizontal` | `12` |
| `iconButtonSize` | `24` |

## 8. Reuse Rules for Music / AI / Schedule

- 当前代码里，音乐页和 AI 页仍是旧的紧凑 HStack 风格，不是大三栏母版。
- 如果后续要统一复用，建议直接继承这里这份 880 紧凑壳子的节奏，再逐步抽共用 token。
- 当前「今日」页适合作为 880 版布局基准，但不适合作为更宽的大母版。

## 9. Reference Struct

```swift
struct NotchV2TodayReferenceLayout {
    static let expandedWidth: CGFloat = 880
    static let expandedHeight: CGFloat = 440
    static let topBarHeight: CGFloat = 36
    static let contentPaddingHorizontal: CGFloat = 32
    static let contentTopPadding: CGFloat = 32
    static let contentBottomPadding: CGFloat = 12
    static let leftColumnWidth: CGFloat = 160
    static let centerColumnWidth: CGFloat = 396
    static let rightColumnWidth: CGFloat = 180
    static let columnGap: CGFloat = 16
    static let cardGap: CGFloat = 20
    static let cardRadius: CGFloat = 24
}
```
