# UI Shell Guideline

## 目标
- 统一所有页面壳层结构，减少布局分叉引发的裁切和跳动。
- 保持一级菜单在紧凑/展开两种模式下的几何一致性与视觉基线一致性。
- 当前实现以 `AppShell`、`ACWorkspaceShell`、`ACSettingsShell` 和 `ACSecondaryPageShell` 为主，不再新增平行壳层。

## 1. 壳层统一规则
- 壳层统一使用 `header + body` 双层结构。
- `header` 固定高度：`ACLayout.pageHeaderHeight`。
- `body` 必须为可扩展区域：`maxWidth/maxHeight = .infinity`，顶对齐。
- 内容区默认使用统一滚动容器（当前为 `ACShellScrollContainer`）：
  - 统一 `padding(.horizontal: ACLayout.pagePaddingX)`
  - 统一 `padding(.vertical: ACLayout.pagePaddingY)`
  - 统一 `padding(.bottom: ACLayout.pagePaddingBottom)`
- 页面差异仅通过 `maxWidth`、`alignment`、`spacing` 参数表达，不再创建平行骨架。

## 2. 一级菜单（Primary Rail）规则
- 紧凑/展开模式共用同一壳层结构，不允许分叉实现。
- 中段导航区为主弹性区（可滚动 + 更高布局优先级）。
- 底部状态区与功能按钮使用固定节奏，避免通过 `Spacer` 补齐高度。
- 导航项几何固定：
  - 行高固定：`ACLayout.primaryRailNavItemHeight`
  - 胶囊背景高度固定：`32`
  - 图标占位固定：`20x20`
- 状态变化（selected/hover）只改变颜色、透明度、阴影，不改变几何尺寸（避免 scale 导致视觉抖动）。

## 3. 图标与文本基线规则
- 一级菜单图标统一 `symbolRenderingMode(.monochrome)`。
- 图标 weight 与字号保持统一（基于 `ACLayout.iconL`/紧凑模式字号策略）。
- 文本可用轻微 baseline offset 做图文中心对齐，但要全局一致。

## 4. 新页面接入检查清单
- 是否复用统一 shell，而不是新建页面级容器分支。
- 是否使用统一滚动容器与统一内边距 token。
- 是否遵守一级菜单固定几何规则（行高/图标框/胶囊高）。
- 是否避免 hover/selected 的几何动画（scale/height/offset）。
- 是否在窗口宽度变化和两种菜单模式下无裁切。

## 5. 稳定性验证
- 每次壳层或导航改动后执行：
  - `xcodebuild -project AcMind.xcodeproj -scheme AcMind -configuration Debug build`
- 若涉及窗口尺寸行为，至少手测：
  - 紧凑/展开切换
  - 主工作区显示/收起切换
  - 小窗口高度下滚动与底部区显示
