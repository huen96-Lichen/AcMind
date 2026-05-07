# AcMind 工作日志

## 2026-05-07 — 迁移边界冻结：Electron → Swift 目标架构

### 完成事项

1. **项目全面扫描**
   - Electron 端：300+ 文件，34 个视图路由，~326 个 IPC handler，22+ 张 SQLite 表
   - Swift 端：42 个 Swift 文件，5 个原生视图，13 个 WebView 页面映射
   - 识别关键差距：存储层（JSON vs SQLite）、AI 蒸馏（Mock）、知识库/语音（空壳）

2. **迁移边界冻结**
   - 创建 [Swift 迁移总表](./superpowers/plans/2026-05-07-swift-migration-plan.md)
   - 明确 Swift 架构唯一主线：App Shell → Features → AcMindKit → Platform
   - 画出 25 个 Electron 模块到 Swift 模块的完整映射表
   - 标出三类边界：必须原生(✅) / 可过渡(🔄) / 最后再删(⏳)

3. **目标导航收敛**
   - 冻结 6 项导航：Agent / Inbox / Schedule / Workbench / Tools / Settings
   - 旧导航（工作台/暂存池/整理/知识库/工具台/设置）→ 新导航映射关系

4. **优先级表制定**
   - P1：存储层重写 + 核心链路（AI 蒸馏/导出）
   - P2：导航六件套原生实现
   - P3：过渡模块填充（Knowledge/Voice/Search）
   - P4：清理收尾，移除 Electron 依赖

5. **Electron 保留清单**
   - File Converter、Import/Vault、Projects/Datasets、VaultKeeper、Onboarding、Error/Retry/Diagnostics
   - 通过 WebViewBridge 在 Swift 壳内运行，P4 阶段处理

6. **文档同步更新**
   - `docs/ACMIND_PRODUCT_BOUNDARY.md` — 增加迁移边界章节 + 目标导航
   - `docs/ARCHITECTURE.md` — 增加 Swift 目标架构 + 模块映射
   - `docs/PROJECT_HANDOVER.md` — 增加迁移状态 + Swift 进展
   - `docs/WORKLOG.md` — 本条记录

### 修改文件清单

- `docs/superpowers/plans/2026-05-07-swift-migration-plan.md` — 新建（迁移总表）
- `docs/ACMIND_PRODUCT_BOUNDARY.md` — 增加迁移边界 + 目标导航
- `docs/ARCHITECTURE.md` — 增加 Swift 目标架构 + 模块映射
- `docs/PROJECT_HANDOVER.md` — 增加迁移状态 + Swift 进展
- `docs/WORKLOG.md` — 本条记录

---

## 2026-05-05 — Phase 2: 整理链路打通（Distill → Export）

### 完成事项

1. **useSourceItems.updateItem 接入真实 IPC**
   - 从乐观更新占位改为调用 `sourceItems.update` IPC

2. **DistillPage 整理页**
   - `handleDistill` / `handleRetry` 调用真实 `distill.run` IPC
   - 新增整理进度 UI（spinner + 状态文案）
   - 新增批量整理（"全部整理"按钮）
   - `distilling` 状态条目显示在待整理标签页
   - 错误状态 + 单条重试按钮

3. **StagingPoolPage 暂存池**
   - 新增单条"送入整理"按钮
   - 新增批量"送入整理"按钮（表头）
   - 逐条追踪 distilling 状态
   - "标记待整理"替换为直接"送入整理"流程

4. **Sidebar 导航修正**
   - "整理"导航从 `capture-inbox` 改为 `distill`（指向 DistillPage）

5. **状态流全链路贯通**
   - inbox → distilling → distilled → exported 在 UI 层完整串联

### 修改文件清单

- `src/renderer/hooks/useSourceItems.ts` — updateItem 接入真实 IPC
- `src/renderer/pages/distill/DistillPage.tsx` — 整理逻辑 + 进度 UI + 批量整理
- `src/renderer/pages/staging-pool/StagingPoolPage.tsx` — 送入整理按钮 + distilling 状态追踪
- `src/renderer/components/layout/Sidebar.tsx` — 导航路由修正
- `CHANGELOG.md` — 新增 0.13.0 记录
- `docs/ACMIND_PHASE_2_DISTILL_EXPORT.md` — 新建

---

## 2026-05-05 — Phase 1: 核心收集主链路固定

### 完成事项

1. **数据结构统一**
   - SourceItem.type 扩展：新增 file/webpage/audio/video/screenshot
   - SourceItem.source 扩展：新增 file_import/url_paste
   - 新增字段：filePath/thumbnailPath/updatedAt/fileSize/mimeType

2. **数据库迁移 v21**
   - source_items 表新增 5 列

3. **数据源统一**
   - 废弃 pinPool，暂存池改用 sourceItems
   - 工作台移除 usePinPool 依赖
   - 剪贴板自动监听改为写入 sourceItems

4. **收集入口统一**
   - 所有入口统一写入 sourceItems
   - 新增通用文件导入（任意文件类型）
   - 新增 URL 保存入口

5. **暂存池页面重构**
   - 基于 sourceItems 的完整暂存池
   - 类型筛选 + 搜索 + 详情面板 + 操作按钮
   - 空状态引导

6. **IPC 通道扩展**
   - 新增 sourceItems.importFile/saveUrl/update

### 修改文件清单

- `src/shared/types.ts` — SourceItem 类型扩展 + IPC 通道
- `src/main/storage.ts` — DB 迁移 v21 + importFileAsSourceItem/saveUrlAsSourceItem
- `src/main/ipc.ts` — 3 个新 IPC handler
- `src/preload/index.ts` — 3 个新 preload API
- `src/main/captureService.ts` — 剪贴板改写 + importFile/saveUrl
- `src/renderer/pages/staging-pool/StagingPoolPage.tsx` — 完全重构
- `src/renderer/pages/daily-flow/DailyKnowledgeFlowPage.tsx` — 移除 pinPool
- `src/renderer/hooks/useSourceItems.ts` — 扩展方法
- `src/renderer/components/inbox/SourceItemDetail.tsx` — 新类型映射
- `src/renderer/components/inbox/SourceItemCard.tsx` — 新类型映射
- `CHANGELOG.md` — 新增 0.12.0 记录
- `docs/ACMIND_PHASE_1_CAPTURE_INBOX.md` — 新建

---

## 2026-05-05 — Phase 0.5: Acore 产品线收束与产品边界统一

### 完成事项

1. **品牌命名统一**
   - 确认用户可见文案已全部使用 AcMind
   - PinMind 仅保留迁移代码（preload 兼容别名、DB 迁移逻辑）
   - PinStack/VaultKeeper 仅出现在内部模块名和注释中

2. **导航收束**
   - Sidebar 从 8 项减为 6 项
   - 移除 Agent 和定时任务一级入口
   - TopBar viewTitle 映射同步更新
   - App.tsx VIEW_LABELS 同步更新

3. **首页表达统一**
   - 标题：首页 → 工作台
   - 副标题：今天要处理什么？ → 个人桌面 AI 信息中枢 — 从碎片收集到知识沉淀

4. **CSS 类名统一**
   - `pinstack-*` → `acmind-*`（CaptureHub.tsx、CaptureOverlay.tsx、CaptureLauncher.tsx）
   - localStorage key：`pinstack.quicknote` → `acmind.quicknote`
   - 注释中的 PinStack 引用更新

5. **AI 助手中性化**
   - 默认 systemPrompt 移除"小龙虾"人格
   - 用户可在设置中自定义 AI 助手名称和人设

6. **文档更新**
   - 新建 `docs/ACORE_PRODUCT_MAP.md`
   - 新建 `docs/ACMIND_PRODUCT_BOUNDARY.md`
   - 新建 `docs/PROJECT_HANDOVER.md`
   - 新建 `docs/WORKLOG.md`
   - 更新 `CHANGELOG.md`

### 修改文件清单

- `src/renderer/components/layout/Sidebar.tsx` — 导航项调整
- `src/renderer/components/layout/TopBar.tsx` — viewTitle 映射更新
- `src/renderer/App.tsx` — VIEW_LABELS 更新
- `src/renderer/pages/daily-flow/DailyKnowledgeFlowPage.tsx` — 首页文案
- `src/renderer/CaptureHub.tsx` — CSS 类名替换
- `src/renderer/CaptureOverlay.tsx` — CSS 类名替换
- `src/renderer/CaptureLauncher.tsx` — CSS 类名替换
- `src/renderer/pages/dashboard-widget/DashboardWidgetPage.tsx` — localStorage key
- `src/main/widgetWindowController.ts` — 注释更新
- `src/main/permissions.ts` — 临时文件名更新
- `src/shared/types.ts` — AI 助手默认 systemPrompt
- `CHANGELOG.md` — 新增 0.11.0 记录
- `docs/ACORE_PRODUCT_MAP.md` — 新建
- `docs/ACMIND_PRODUCT_BOUNDARY.md` — 新建
- `docs/PROJECT_HANDOVER.md` — 新建
- `docs/WORKLOG.md` — 新建
