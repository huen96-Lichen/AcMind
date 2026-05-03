# AcMind WORKLOG

工作记录，按日期追加。

## 2026-05-01

### Phase 11：个人知识流日常使用闭环

**目标**：让 AcMind 从后台处理器变成每日知识流仪表盘，用户打开即可知道今天知识流发生了什么。

**新增文件**：
1. `src/shared/daily-flow-types.ts` — Phase 11 类型定义
   - STATUS_LABEL_MAP / SOURCE_TYPE_LABEL_MAP 状态映射
   - DailyFlowSummary / DailyFlowItem / AttentionItem / RecentOutputItem / WeeklyFlowSummary 类型
   - DailyFlowAction / DailyFlowFilter 类型
2. `src/renderer/hooks/useDailyKnowledgeFlow.ts` — 数据聚合 hook
   - 从 CaptureItem / SourceItem / ExportRecord / ErrorRecord 聚合今日数据
   - 今日统计 / 今日列表 / 需要处理 / 最近输出 / 本周回顾 / 高价值内容
   - 筛选与搜索支持
3. `src/renderer/pages/daily-flow/DailyKnowledgeFlowPage.tsx` — 今日知识流页面
   - 顶部 4 统计卡（今日收集/已整理/已进入 Obsidian/需要处理）
   - 今日知识流列表（带筛选标签和搜索）
   - 需要处理区（失败/等待内容聚合）
   - 最近进入 Obsidian 区（最近 10 条输出）
   - 本周回顾区（统计/高频标签/高价值内容）
   - 完整空状态设计

**修改文件**：
1. `src/renderer/App.tsx`
   - 新增 'daily-flow' 路由，设为默认首页
   - onboarding 完成后导航到 daily-flow
2. `src/renderer/components/layout/Sidebar.tsx`
   - 新增"今日"导航项（置顶）
3. `src/renderer/version.ts` — 版本号 0.4.0

**验证**：
- `tsc --noEmit` 零错误
- `npm run build` 因环境缺少 esbuild 二进制失败（Exec format error），非代码问题

**已知限制**：
1. 高价值内容判断基于简单规则（quality_flags / tags），不做模型推荐
2. 本周回顾的"值得回看"仅限本周数据，不做跨周推荐

**Phase 11 Round 2 修复**：
1. `handleFlowAction` 接入真实业务逻辑：
   - `open_obsidian_file` → `window.acmind.app.openPath(output_path)`
   - `open_detail` → dispatch `acmind:navigate` 到 edit 页
   - `retry` → `window.acmind.distill.bridgeAndRun(id, ['summarize'])`
   - `open_source` → dispatch `acmind:navigate` 到 capture-inbox
   - `configure_settings` → dispatch `acmind:navigate` 到 settings
   - `ignore` → `window.acmind.errors.dismiss(errorId)` 关闭关联错误记录
2. 数据口径对齐：`daily-flow-types.ts` 顶部增加口径映射表
   - CaptureRecord → CaptureItem（capture_items 表）
   - SourceItem → SourceItem（source_items 表）
   - OutputHistory → ExportRecord（export_records 表）
   - ErrorLog → ErrorRecord（error_records 表）
3. 高价值内容 UI 标注：
   - 每条高价值卡片增加"规则推荐"标签
   - 本周回顾标题改为"基于规则自动筛选"
   - hook 返回 `reason_source: 'rule'` 字段
4. `AttentionItem` 增加 `error_id` 字段，支持 ignore 操作
5. `useDailyKnowledgeFlow` 暴露 `dismissError` 方法

### Phase 10：语音输入与录音工作流产品化

**目标**：让 AcMind 支持低摩擦语音输入，形成录音→转写→整理→Obsidian 完整链路。

**新增文件**：
1. `src/main/services/capture/voiceWatchService.ts` — 语音监听文件夹服务
   - 监听本地/iCloud 文件夹新增音频文件
   - 延迟处理（等待 iCloud 同步完成）
   - 文件去重（file_fingerprint）
   - 自动创建 audio CaptureRecord
   - 提交转写任务
2. `src/main/services/capture/audioTranscriptionService.ts` — 音频转写服务
   - 提交转写 job 到 VaultKeeper
   - 追踪转写状态
   - 回填 transcript_text 到 CaptureRecord
   - 支持重试转写
   - 处理无转写引擎的情况（不伪造 transcript）

**修改文件**：
1. `src/shared/types.ts`
   - IPC_CHANNELS 新增 6 个语音相关通道
   - CaptureItemType 新增 'audio'
   - CaptureItemStatus 新增 'transcribing' | 'transcribed'
2. `src/main/services/strategy/strategies/audioStrategy.ts` — 重写
   - 使用 voice_note_zh_v1 Prompt Profile
   - 没有 transcript_text 不进入 AI 整理
   - 无转写时生成占位记录
   - 有转写时使用语音专用 Prompt 整理
3. `src/main/services/strategy/promptProfile.ts`
   - 新增 voice_note_zh_v1 Prompt Profile
4. `src/main/ipc.ts`
   - 新增 6 个语音 IPC handler
5. `src/preload/index.ts`
   - 新增 voice API 暴露给渲染进程
6. `src/main/captureService.ts`
   - 初始化和停止 voiceWatchService
7. `src/main/services/pipeline/contentPipelineService.ts`
   - buildNonTextStructured 增强 audio 处理
   - exportToVault 传递 audio 特有 frontmatter 字段
8. `src/main/services/exporter/standardFields.ts`
   - 新增 transcript_status / audio_file / quality_flags 字段
9. `src/main/services/exporter/markdownBuilder.ts`
   - buildFromFields 支持 audio 特有字段
10. `src/renderer/pages/settings/SettingsPage.tsx`
    - 新增"语音输入"设置分类
    - VoiceInputSettingsPanel 组件
11. `src/renderer/components/capture-inbox/CaptureItemCard.tsx`
    - 支持 audio 类型显示
    - 新增 transcribing/transcribed 状态
12. `src/renderer/components/capture-inbox/CaptureItemDetail.tsx`
    - 支持 audio 类型详情展示
    - 转写状态、打开录音、重试转写按钮
13. `src/renderer/version.ts` — 版本号 0.3.0

**验证**：
- 待 typecheck 和 build 验证

**已知限制**：
1. 转写引擎尚未接入（Whisper API / 本地 Whisper），当前为 stub
2. 长录音（>100MB）暂不支持完整自动转写
3. 不做实时语音输入法、不做完整说话人分离

## 2026-04-29

### Settings 页面封版

**状态**：Settings 页面本阶段封版，不再主动改动视觉和结构，仅保留 P3 polish 项。

**已完成事项**：
1. **信息架构完成** — 5 大分组、12 个设置分类，层级清晰
2. **RightInspector 已在 Settings 场景隐藏** — 避免右侧面板干扰设置页布局
3. **storageRoot 重复展示已收敛** — 路径与存储分组中不再重复展示 storageRoot
4. **logLevel 运行时同步已修复** — 修改日志级别后立即生效，无需重启
5. **tab 参数持续同步已修复** — Settings 页 tab 切换状态与 URL 参数保持同步
6. **组件级对齐与 Switch 偏移已修复** — 设置项组件对齐统一，Switch 控件位置正确
7. **后续只保留 P3 polish 项** — 不进入当前迭代，除非发现明确功能 bug

**下一阶段重点**：AcMind 主链路 — 收集箱 → AI 处理 → 二级整理 → 导出 Obsidian

### Phase 2：审阅页产品化（第一轮）

**目标**：将 EditPage 从"工作流页"产品化为"审阅页"

**修改文件**：
1. `src/renderer/pages/edit/EditPage.tsx`（重写）
   - 三栏布局→两栏：审阅编辑区（默认全屏）+ 可折叠原文面板/导出预览面板
   - 审阅编辑区改为单页滚动：摘要→标题→分类→标签→正文→置信度→保存
   - 审阅状态指示器（待审阅/已确认/已编辑/已拒绝），header 右侧 badge
   - 标题编辑 ref guard 防止重载覆盖（Phase 1 遗留修复）
   - 蒸馏中/加载中/空状态/错误状态完整覆盖
   - 导出按钮直接在 header，按 record.status 分支提示
2. `src/main/services/exporter/markdownBuilder.ts`
   - 默认模板从 7 段精简为 4 段（摘要/来源/正文/标签）
   - 移除硬编码 `DEFAULT_DISTILLED_LINKS`
3. `package.json` / `src/renderer/version.ts` — 版本号 0.2.2
4. `CHANGELOG.md` / `WORKLOG.md` — 同步更新

**验证**：
- `tsc --noEmit` 零错误
- `vitest run` 109/109 通过

### Phase 1 封板阻塞项修复

**目标**：修复三个封板阻塞项

**修改文件**：
1. `src/shared/types.ts`
   - `AiTask` 接口新增 `updatedAt: number` 字段
2. `src/main/storage.ts`
   - schema v9 迁移：`ai_tasks` 表新增 `updated_at INTEGER NOT NULL DEFAULT (unixepoch())`
   - backfill 已有行的 `updated_at = created_at`
   - `stmtInsertAiTask` / `insertAiTask` 写入 `updated_at`
   - `stmtUpdateAiTask` / `updateAiTask` 自动设置 `updated_at = now()`
3. `src/main/services/distiller/distillPipeline.ts`
   - 创建 AiTask 时设置 `updatedAt = now`
4. `src/main/services/aiHub/taskQueue.test.ts`
   - `makeTask` helper 新增 `updatedAt` 字段
5. `src/renderer/pages/edit/EditPage.tsx`
   - `loadDistilledOutput` 从依赖数组移除 `titleDraft`（消除反馈循环）
   - 新增 `distilledOutputRef` 防止 AI 建议值覆盖用户正在编辑的标题
6. `package.json` / `src/renderer/version.ts`
   - 版本号统一为 `0.2.1`
7. `PROJECT_HANDOVER.md`（新增）
   - 项目交接文档：架构、数据模型、IPC 通道、已知限制
8. `CHANGELOG.md` / `WORKLOG.md` — 同步更新

**验证**：
- `tsc --noEmit` 零错误
- `vitest run` 109/109 通过

### Phase 1：导出 false-success 修复

**目标**：修复 `exportSingle()` 返回 `status=failed` 时前端仍 toast 成功的问题

**根因**：`obsidianExporter.exportSingle()` 失败时返回 `status=failed` 的 ExportRecord 而非抛异常，但 `EditPage.handleExport` 无条件 toast 成功

**修改文件**：
1. `src/shared/types.ts`
   - `ExportRecord` 接口新增 `error?: string` 字段
2. `src/main/storage.ts`
   - schema v8 迁移：`export_records` 表新增 `error TEXT` 列
   - `stmtInsertExportRecord` 和 `insertExportRecord` 写入 `error` 字段
3. `src/main/services/exporter/obsidianExporter.ts`
   - `createExportRecord` 写入 `error` 字段到 ExportRecord
4. `src/renderer/pages/edit/EditPage.tsx`
   - `handleExport` 按 `record.status` 分支处理：success→成功提示，conflict→冲突提示，failed→错误提示（含友好化）
5. `src/renderer/pages/export/ExportPage.tsx`
   - `handleExportSelected` 汇总批量导出结果，有失败时展示首条错误
6. `src/main/services/exporter/exportStatus.test.ts`（新增）
   - 11 个回归测试：ExportRecord 类型验证、status 分支逻辑、批量结果汇总
7. `CHANGELOG.md` / `WORKLOG.md` — 同步更新

**验证**：
- `tsc --noEmit` 零错误
- `vitest run` 109/109 通过（含 11 个新增测试）

### Phase 1：真闭环修复（第三轮）— 遗留问题清零

**目标**：修复前两轮发现的 5 个遗留问题

**修改文件**：
1. `src/renderer/pages/capture-inbox/CaptureInboxPage.tsx`
   - 数据源从 `useCaptureItems`（capture_items）改为 `useSourceItems`（source_items）
   - 文本输入直接调用 `sourceItems.createText` 写入 source_items
   - 蒸馏直接调用 `distill.run` 而非 `bridgeAndRun`
   - 移除来源筛选（sourceFilter），改用状态筛选（适配 SourceItem.status）
2. `src/renderer/components/inbox/SourceItemCard.tsx`
   - 新增 `onDistill`/`onDelete` props
   - `inbox` 状态显示"蒸馏"按钮
   - `distilling` 状态显示"蒸馏中…"
   - `distilled` 状态显示"查看结果"导航按钮
   - 通用"删除"按钮
3. `src/renderer/context/SelectedItemContext.tsx`
   - 类型从 `CaptureItem` 改为 `any`，支持 SourceItem 和 CaptureItem
4. `src/main/services/distiller/distillPipeline.ts`
   - `confidence` 从 AI 输出读取，0.8 作为 fallback
5. `src/main/services/aiHub/taskQueue.ts`
   - 注释从 "Priority-based" 改为 "FIFO"
6. `src/renderer/pages/edit/EditPage.tsx`
   - 导出错误友好提示（路径不存在/权限不足/未配置）
7. `src/renderer/pages/export/ExportPage.tsx`
   - 导出错误友好提示（同上）
8. `CHANGELOG.md` / `WORKLOG.md` — 同步更新

**验证**：
- `tsc --noEmit` 零错误
- `vitest run` 98/98 通过

### Phase 1：真闭环修复（第二轮）

**目标**：消除伪完成风险，确保主链路真实闭环

**修改文件**：
1. `src/renderer/pages/capture-inbox/CaptureInboxPage.tsx`
   - `handleCreate` 创建 CaptureItem 后立即调用 `sourceItems.ensureFromCapture` 桥接到 source_items
2. `src/renderer/components/capture-inbox/CaptureItemCard.tsx`
   - `failed` 状态新增"重试"按钮（重置状态后重新蒸馏）
   - `archived` 状态新增"查看结果"按钮（导航到编辑页）
3. `src/renderer/pages/edit/EditPage.tsx`
   - `handleExport` 导出前检查 `settings.vault.vaultPath` 是否已设置
4. `src/renderer/pages/export/ExportPage.tsx`
   - `handleExportSelected` 导出前检查 vault path
5. `src/renderer/components/inbox/SourceItemDetail.tsx`
   - `DEFAULT_DISTILL_OPERATIONS` 从 6 个精简为 `['summarize']`
6. `CHANGELOG.md` / `WORKLOG.md` — 同步更新

**验证**：
- `tsc --noEmit` 零错误
- `vitest run` 98/98 通过

### Phase 1：最短蒸馏闭环打通（第一轮）

**目标**：手动输入 → 保存 → 蒸馏 → 审阅编辑 → 导出 Markdown → 记录导出

**修改文件**：
1. `src/main/services/distiller/distillPipeline.ts`
   - 引入 `mockDistiller`，无 AI Provider 时自动 fallback 到 mock
   - 移除 `useMock → failed` 直接失败逻辑，改为入队执行
   - `executeTask()` 检测 `useMock` 标记走 mock 路径
2. `src/main/services/distiller/mockDistiller.ts`
   - summarize 操作返回完整结构化结果（含 contentMarkdown）
   - 新增 mockTitle/mockSummary/mockContentMarkdown 辅助函数
   - 所有日志标注 `[Mock Fallback]`
3. `src/main/services/exporter/obsidianExporter.ts`
   - Phase 1 宽松策略：允许 pending 状态的蒸馏结果直接导出
4. `src/main/storage.ts`
   - 注释掉 v7 迁移中硬编码的开发者 Obsidian vault 路径
5. `src/shared/markdownSpec.ts`
   - `DEFAULT_OBSIDIAN_DOCUMENTS_ROOT` 改为空字符串
6. `CHANGELOG.md` / `WORKLOG.md` — 同步更新

**验证**：
- `tsc --noEmit` 零错误
- `vitest run` 98/98 通过
- 完整业务链路已验证可通（代码审查级）

**已知使用 Mock/Fallback 的地方**：
- 蒸馏执行：无 AI Provider 时使用 mockDistiller（所有操作）
- AI 蒸馏工作台（DistillationWorkbench）：使用模板 fallback（renderer 端）
- 规则蒸馏引擎（ruleBasedDistiller.ts）：纯文本分析，未被工作台直接引用

## 2026-04-28

### 蒸馏闭环与训练仓骨架推进

- 打通 `CaptureItem -> SourceItem` 幂等桥接，收集箱蒸馏入口改为真实运行时入口，不再走 Markdown 导出假动作
- 将 `EditPage` 收敛到 `SourceItem` 视角，保留旧入口兼容，同时让审阅后的导出走 canonical `KnowledgeCard`
- 新增 `review_events`、`knowledge_cards`、`knowledge_edges`、`training_examples`、`dataset_snapshots`、`training_runs`、`eval_runs`、`model_versions` 数据模型和对应 IPC/preload 面
- 新增只读知识图谱页，接入侧边栏与主路由
- 在 `AI Console` 增加训练侧 tab，用于数据集快照、训练运行、模型版本的展示与基础操作
- 新增独立 `training/` 目录和 `acmind-trainer` CLI 骨架，支持 snapshot validate / train / eval / package 的 stub 流程
- 补齐训练样本示例与 trainer contract 文档

### 验证
- `npm run typecheck` 通过
- `npm test` 通过
- `npm run build` 通过
- `npm run trainer:validate` 通过

### 今日工作台 UI 结构性重构（阶段 1）

- 统一全局视觉 token：新增暖白底 / 卡片 / 圆角 / 阴影 / 字体层级变量，整体字体栈切换为 Apple-ish 风格
- 收口壳层基础样式：Sidebar / TopBar / BottomRuntimeBar / AppShell 使用更统一的玻璃感与层级
- 重做今日工作台列表：标题压到 14px 级别，列表行支持语义标题、摘要、标签、来源、状态和时间
- 修复今日工作台状态链路：`selectedId -> selectedItem -> detail panel` 绑定到可见列表，筛选/删除后自动纠偏
- 重做详情面板：增加 Tabs、内容预览、信息卡、AI 建议、快捷操作、输出信息
- 补通导航链路：今日工作台“编辑内容”可携带 `id` 跳转到二级整理页
- 更新 `AppShell` 的主布局宽度为设计稿更接近的 sidebar / detail 宽度

### 验证
- `npm run typecheck` 通过
- `npm run build` 通过

### 今日工作台 UI 结构性重构（阶段 2）

- 继续统一全局视觉语言：Settings / AI Console / Export / Right Inspector / Capsule 保持同一套暖白轻玻璃 token
- Settings 页收口剩余的旧字号与旧灰色说明，补强 AI 模型管理、路径与存储、外观、隐私、高级设置的层级一致性
- 详情侧栏补齐交互闭环：增加摘要复制、输出详情、AI 建议、快捷操作等内容中心入口
- Export 页的“查看日志”入口改为真实导航，减少死按钮
- Capsule 捕获胶囊沿用同一套圆角、阴影、按钮与输入态语言，尽量贴近设计稿

### 验证
- `npm run typecheck` 通过
- `npm run build` 通过
- `npm exec vitest run` 通过（98/98）

### 快速捕获胶囊 UI 收口（阶段 3）

- 将 `CapsuleExpanded` 重排为更高信息密度的单面板工作流：标题栏、输入区、来源/输出/AI 信息区、快速标签、主操作区
- 保留原有保存逻辑，但补齐“直接 AI 整理”的明确快捷动作，减少低效切换
- 胶囊视觉语言继续对齐设计稿：更紧凑的间距、更轻的边框、更统一的按钮和 pill 样式

### 验证
- `npm run typecheck` 通过
- `npm run build` 通过
- `npm exec vitest run` 通过（98/98）

### 二级整理页 UI 密度收口（阶段 4）

- 压缩 `EditPage` 顶部工具栏、状态条和三栏工作区的留白，让内容密度更接近设计稿
- 将状态条改为更紧凑的标签化信息，增加来源 / 域名 / 标签 / 备注的快速扫读能力
- 压缩三栏内的卡片标题、段落间距、预览区高度和 Markdown 预览区域，让编辑页更像高密度工作台

### 验证
- `npm run typecheck` 通过
- `npm run build` 通过
- `npm exec vitest run` 通过（98/98）

### 设置系统收口（dead settings cleanup）

- 移除 `SettingsPage` 中未持久化、也未被 runtime 消费的「默认输出」本地状态，避免与 `capsule.quickCapture.defaultDestination` 重复
- 将 AI 区域的「回退行为」改为说明性文案，明确实际回退逻辑由 `tierRouter` 自动处理，不再暴露不存在的独立开关
- 保留真实可保存的 `defaultTier`、provider 列表、`launchAtLogin` 和 `capsule.quickCapture.defaultDestination` 配置入口，确保 UI 只保留真实设置

### 验证
- `npm run typecheck` 通过
- `npm run build` 通过
- `npm exec vitest run` 通过（98/98）

### AI 控制台假运行态收口

- 将 AI 控制台右侧的「今日消耗」改为真实可解释的「运行概览」，只展示现有任务与可用模型数量，不再伪造计费数据
- 移除本地 `mockMode` 假开关，改为说明运行时在无可用 provider 时会自动降级，不提供独立 Mock 切换
- 将硬编码的「回退策略」卡片改为说明卡，明确 fallback 由 `tierRouter` 自动处理，没有独立的排队 / 跳过开关
- 将「最近错误」改名为「示例错误」，并在注释中标明它只用于展示错误状态样式，不代表真实日志

### 验证
- `npm run typecheck` 通过
- `npm run build` 通过
- `npm exec vitest run` 通过（98/98）

### 产品落地补闭环 (0428 P0 阻塞项)

#### 1. EditPage 二级整理页真实闭环
- 完全重写 `EditPage.tsx`，从 100% mock 数据改为真实 IPC 驱动
- 接入 `captureItems.get/update/exportMarkdown` 和 `distilledOutputs.list`
- 实现所有按钮真实行为：返回收集箱、重新整理、编辑内容、保存草稿、导出 Obsidian、复制 Markdown、浏览器打开
- 可编辑字段：标题（铅笔图标切换）、备注（textarea）、标签（添加/移除）
- 完整状态管理：加载态、错误态（含重试）、未找到态、尚未蒸馏态
- App.tsx 路由更新：`edit` case 渲染真实组件，支持 `?view=edit&id=xxx`

#### 2. 补齐空路由页面
- 新增 `TemplatesPage.tsx`：模板管理页，3 个内置模板卡片，预览/使用按钮，空状态
- 新增 `LogsPage.tsx`：运行日志页，4 个频道标签页，读取真实日志，加载/空/错误态完整
- 新增 `HelpPage.tsx`：帮助与文档页，5 个 FAQ 手风琴，版本信息
- App.tsx 新增 `templates` / `logs` / `help` 三个路由 case

#### 3. useRecording.ts 旧接口清理
- 移除所有 7 处注释掉的旧 API 调用（TODO 标记）
- 添加 JSDoc 状态说明（哪些可用、哪些不可用、阻塞项列表）
- `stopRecording` 从空操作改为实际停止 MediaRecorder
- 保留 `startRecording` 的 getDisplayMedia 逻辑，添加行内限制注释

#### 4. AI 设置页 Mock 数据标注
- SettingsPage AI 模型区域添加「演示数据」黄色警告横幅
- AiModelCardView 每张卡片添加灰色「演示数据」徽章
- 回退策略区域添加说明文字
- AiConsolePage MOCK_ERRORS 添加 mock 数据标注注释

#### 5. 版本号更新
- `package.json`: 0.1.0 → 0.2.0
- `src/renderer/version.ts`: 0.1.0 → 0.2.0
- `CHANGELOG.md`: 新增 [0.2.0] 版本记录
- `WORKLOG.md`: 新增本日工作记录

### 验证
- `npm run typecheck` 通过（零错误）
- `npm run build` 因环境缺少 esbuild 二进制文件失败（非代码问题）

---

## 2026-04-27

### Capture Inbox v0.1 修复
- 补齐图片收集链路：renderer 发送 base64 / mime / 原始文件名，main 侧写入磁盘后再入库。
- 新增 `captureItems.readImage` IPC，用于详情页和列表缩略图读取真实图片内容。
- 修复 Markdown 导出：文件名增加日期前缀，重复文件自动加序号，图片附件复制到导出目录。
- frontmatter 对齐 Obsidian 输出规范，补充 `title / created / updated / source_type / source_id / status / tags / summary`。
- 更新交接文档的 Capture Inbox 验收状态。
- 新增 `CHANGELOG.md` 与 `WORKLOG.md`。

### 验证
- `npm run typecheck` 通过
- `npm run build` 通过
