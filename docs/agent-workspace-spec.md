# Agent 工作台规格文档

## 1. 目标布局

三栏 ChatGPT 风格工作台：

```
┌──────────────┬────────────────────────────┬──────────────┐
│   左栏 260px │      中栏 flex: 1          │  右栏 280px  │
│              │                            │              │
│ ┌──────────┐ │ ┌────────────────────────┐ │ ┌──────────┐ │
│ │ Logo     │ │ │ HeaderBar (固定)       │ │ │ 上下文   │ │
│ │ +新对话  │ │ ├────────────────────────┤ │ │ 摘要卡   │ │
│ ├──────────┤ │ │                        │ │ ├──────────┤ │
│ │ 项目列表 │ │ │   MessageList          │ │ │ 任务进度 │ │
│ │ (滚动)   │ │ │   (独立滚动)           │ │ │ (滚动)   │ │
│ │          │ │ │                        │ │ │          │ │
│ │ 历史对话 │ │ │                        │ │ │ 可用工具 │ │
│ │ (滚动)   │ │ │                        │ │ │          │ │
│ │          │ │ ├────────────────────────┤ │ │          │ │
│ │ 程序入口 │ │ │ Composer (固定)        │ │ │          │ │
│ └──────────┘ │ └────────────────────────┘ │ └──────────┘ │
└──────────────┴────────────────────────────┴──────────────┘
```

## 2. 当前问题（已修复）

| 问题 | 原因 | 修复方案 |
|------|------|----------|
| 输入框被消息流挤出视口 | 中栏 `overflowY: 'auto'` 导致整体滚动 | 改为 `overflow: 'hidden'`，仅消息流滚动 |
| textarea 不能自动增高 | 固定 `rows={1}` 无动态调整 | 添加 `onInput` 自动计算行数 |
| 右栏 hover 无效果 | 使用了未定义的 `--color-bg-hover` | 在 styles.css 补充变量定义 |
| 暗色模式 hover 颜色缺失 | 同上 | dark 模式下同步定义 |

## 3. 固定骨架和可编辑区域

### 固定骨架（不可改）
- `App.tsx`: 全局路由和主壳
- `Sidebar.tsx`: 全局导航栏
- `styles.css`: `.app-container`、`.main-content`、`.sidebar` 等全局壳层样式
- 路由结构：`/agent` → `AgentPage`

### 可编辑区域
- `AgentPage.tsx`: Agent 页面入口，三栏接线层
- `components/agent/workspace/*`: 所有工作台子组件
- `components/agent/types.ts`: 类型定义
- `.page-content` 的 inline style 覆盖（padding: 0, maxWidth: none）

## 4. 组件拆分方案

| 组件 | 文件 | 职责 |
|------|------|------|
| AgentWorkspaceLayout | workspace/AgentWorkspaceLayout.tsx | 三栏壳层，空间分配 |
| AgentProjectSidebar | workspace/AgentProjectSidebar.tsx | 左栏：项目/历史/程序 |
| AgentHeaderBar | workspace/AgentHeaderBar.tsx | 中栏顶部：项目名/模型/状态 |
| AgentMessageList | workspace/AgentMessageList.tsx | 消息流容器，独立滚动 |
| AgentMessageItem | workspace/AgentMessageItem.tsx | 单条消息渲染 |
| AgentComposer | workspace/AgentComposer.tsx | 底部输入区，固定定位 |
| AgentContextPanel | workspace/AgentContextPanel.tsx | 右栏：上下文/进度/工具 |

## 5. 布局规则

### 左栏
- 宽度固定 260px
- 顶部 logo + "新建对话" 按钮：`flexShrink: 0`，始终可见
- 中部列表区：`flex: 1; overflowY: auto`，独立滚动
- 项目列表 → 历史对话 → 程序入口，顺序固定

### 中栏
- `flex: 1; display: flex; flex-direction: column; overflow: hidden`
- HeaderBar：`flexShrink: 0`
- MessageList：`flex: 1; overflowY: auto`（唯一滚动区）
- Composer：`flexShrink: 0`，固定在底部

### 右栏
- 宽度固定 280px
- `overflowY: auto`，独立滚动
- 不影响中栏布局

## 6. 风险点

| 风险 | 影响 | 缓解措施 |
|------|------|----------|
| 项目/历史数据为空 | 左栏显示空状态 | 已有空态占位 |
| 工具功能未接入 | 右栏工具卡为占位 | console.log 占位，结构已定 |
| 小屏下三栏拥挤 | 信息密度高 | 中栏 min-width 约束，后续可加响应式 |
| textarea 自动增高溢出 | composer 撑高中栏 | maxHeight 约束 6 行 |

## 7. 验收标准

### 结构验收
- 页面为三栏工作台布局
- 左/中/右栏职责清晰
- 组件拆分合理，无单文件膨胀

### 布局验收
- 默认视图下输入框完整可见
- 历史对话和新建对话入口始终可见
- 中栏 header 和 composer 固定，仅消息流滚动
- 三栏各自独立滚动

### 功能验收
- AI 对话正常工作
- 知识蒸馏能力保留（通过右栏工具卡触发）
- 消息发送/接收/展示正常

### 构建验收
- `npm run build:vite` 通过
- 无新增 TypeScript 错误
