> ⚠️ 历史文档，路径和内容可能已过时，仅供参考。

# AcMind V2.1 交接文档

日期：2026-04-30
版本：0.2.2
适用范围：换电脑后继续推进 AcMind V2.1 开发

---

## 1. 项目定位

AcMind 是一个**本地优先的 AI 记忆蒸馏器**（Local-first AI Memory Distiller），基于 Electron + React + TypeScript 技术栈。

核心主链路：

```
收集 → 蒸馏 → 审阅 → 导出 Obsidian → 搜索
```

---

## 2. 当前已完成的功能模块

### Phase 0-5：MVP 核心闭环

| 模块 | 状态 | 说明 |
|------|------|------|
| CaptureItem 收集箱 | ✅ 完成 | 文本/链接/图片三种碎片类型 |
| SourceItem 桥接 | ✅ 完成 | CaptureItem 幂等桥接到 SourceItem |
| AI 蒸馏 | ✅ 完成 | 本地 Ollama 模型（gemma4:e4b），支持 rename/summarize/classify/tag/valueScore/cleanSuggest |
| 审阅编辑 | ✅ 完成 | EditPage 两栏布局，支持编辑/接受/拒绝 |
| Obsidian 导出 | ✅ 完成 | Markdown 模板 + Frontmatter + 原子写入 + 冲突处理 |
| 关键词搜索 | ✅ 完成 | FTS 全文检索 |
| 设置系统 | ✅ 封版 | 5 大分组、12 个分类，logLevel 运行时同步 |
| 日志系统 | ✅ 完成 | 多通道、多级别 |

### Phase 6：稳定性增强

| 模块 | 状态 | 说明 |
|------|------|------|
| 统一错误模型 | ✅ 完成 | ErrorRecord + ErrorService，10 种错误类型 |
| 统一重试机制 | ✅ 完成 | retryService，支持自动/手动重试 |
| 处理历史 | ✅ 完成 | content_state_history 表，完整状态转换追踪 |
| 高级控制面板 | ✅ 完成 | 本地模型运行时状态、批量 processedAt 查询 |
| VaultKeeper 导入 | ✅ 完成 | 从 Obsidian 仓库反向导入 |
| 文档解析器 | ✅ 完成 | PDF/DOCX/网页解析（markitdown 集成） |
| 调度器 | ✅ 完成 | node-cron 定时任务 |
| OutputSpec 服务 | ✅ 完成 | 模板包驱动，Format Profile + Tag Rules + Category Rules |

### Phase 7.1：统一 Capture Adapter 架构（本次完成）

| 模块 | 状态 | 说明 |
|------|------|------|
| CaptureRecord 类型 | ✅ 完成 | 统一捕获记录，含 original_id / source_type / created_at |
| CaptureAdapter 接口 | ✅ 完成 | 泛型接口 `CaptureAdapter<TInput>` |
| CaptureAdapterRegistry | ✅ 完成 | 单例注册中心，统一入口 `capture(input)` |
| ManualTextAdapter | ✅ 完成 | 手动文本入口 |
| ClipboardTextAdapter | ✅ 完成 | 剪贴板文本入口 |
| ScreenshotAdapter | ✅ 完成 | 截图入口 |
| WebpageAdapter | ✅ 完成 | 网页入口 |
| FileAdapter | ✅ 完成 | 文件入口（PDF/DOCX/TXT 等） |
| ImageAdapter | ✅ 完成 | 图片入口 |
| AudioAdapter | ✅ 骨架 | 音频入口（结构完整，待集成 Whisper） |
| VideoAdapter | ✅ 骨架 | 视频入口（结构完整，待集成） |
| processCaptureRecord() | ✅ 完成 | Pipeline 新入口，支持 CaptureRecord → 全链路 |
| CaptureService 迁移 | ✅ 完成 | captureText() 和 handleNewClipboardContent() 已迁移 |
| IPC 通道 | ✅ 完成 | CAPTURE_RECORD + CAPTURE_GET_AVAILABLE_TYPES |
| Preload API | ✅ 完成 | window.acmind.capture.record() + getAvailableTypes() |

---

## 3. Phase 7.1 架构详解

### 3.1 核心数据流

```
任意入口
  → CaptureAdapter.capture(input)     // 只负责采集+标准化
  → CaptureRecord                      // 统一中间表示
  → captureRegistry.capture(input)     // 注册中心路由
  → contentPipeline.processCaptureRecord(record)  // 进入统一管线
  → 去重检查 (original_id)
  → 创建 SourceItem (captured)
  → 自动整理 (processing → structured)
  → Markdown 生成 + Obsidian 写入 (exporting → exported)
```

### 3.2 CaptureRecord 结构

```typescript
interface CaptureRecord {
  original_id: string;       // SHA-256 去重哈希
  source_type: SourceType;   // 来源类型
  created_at: string;        // ISO 8601 时间戳
  raw_text?: string;         // 原始文本
  raw_file_path?: string;    // 原始文件路径
  raw_url?: string;          // 原始 URL
  title?: string;            // 标题
  preview_text?: string;     // 预览文本
  source_app?: string;       // 来源应用
  metadata: Record<string, unknown>;  // 扩展元数据
}
```

### 3.3 SourceType 枚举

```typescript
type SourceType =
  | 'manual_text'     // 手动输入
  | 'clipboard_text'  // 剪贴板文本
  | 'screenshot'      // 截图
  | 'webpage'         // 网页
  | 'file'            // 文件（PDF/DOCX 等）
  | 'image'           // 图片
  | 'audio'           // 音频（骨架）
  | 'video';          // 视频（骨架）
```

### 3.4 CaptureAdapter 职责边界

**必须做**：
- 从特定来源采集原始内容
- 标准化为 CaptureRecord

**禁止做**：
- Markdown 生成
- Obsidian 写入
- UI 展示
- AI 处理

### 3.5 新增文件清单

```
src/main/services/capture/
  ├── index.ts                // Barrel export
  ├── captureRegistry.ts      // 注册中心（单例）
  ├── manualTextAdapter.ts    // 手动文本
  ├── clipboardTextAdapter.ts // 剪贴板文本
  ├── screenshotAdapter.ts    // 截图
  ├── webpageAdapter.ts       // 网页
  ├── fileAdapter.ts          // 文件
  ├── imageAdapter.ts         // 图片
  ├── audioAdapter.ts         // 音频（骨架）
  └── videoAdapter.ts         // 视频（骨架）
```

### 3.6 修改文件清单

| 文件 | 改动内容 |
|------|---------|
| `src/shared/types.ts` | 新增 SourceType / CaptureRecord / CaptureAdapter 类型 + 2 个 IPC 通道 |
| `src/main/services/pipeline/contentPipelineService.ts` | 新增 processCaptureRecord() + createSourceItemFromCaptureRecord() + extractContentText() + mapSourceTypeToLegacy/ItemType |
| `src/main/captureService.ts` | captureText() 和 handleNewClipboardContent() 迁移到 adapter + 新增 captureRecordToSourceItem() 桥接方法 |
| `src/main/index.ts` | bootstrap 中注册 8 个 adapter |
| `src/main/ipc.ts` | 新增 CAPTURE_RECORD / CAPTURE_GET_AVAILABLE_TYPES handler |
| `src/preload/index.ts` | capture 命名空间下新增 record() / getAvailableTypes() |

### 3.7 向后兼容策略

- `CaptureService.captureText()` 保持原有签名不变，内部委托给 `manualTextAdapter`
- `ContentPipelineService.processText()` 保持不变，新增 `processCaptureRecord()` 作为推荐入口
- `CaptureRecord` 通过 `captureRecordToSourceItem()` 桥接为旧版 `SourceItem` 存储
- `SourceType` 通过 `mapSourceTypeToLegacy()` 映射为旧版 `SourceItem.source` 字段
- Preload API 中 `capture.screenshot()` 等旧方法不受影响

---

## 4. 状态机

### 4.1 状态定义

```
正常流程：captured → processing → structured → exporting → exported
失败分支：captured → capture_failed → captured (重试)
           processing → process_failed → processing/captured
           exporting → export_failed/conflict_pending/permission_required → exporting/structured
```

### 4.2 状态机文件

- `src/main/services/pipeline/contentStateMachine.ts` — 状态机实现
- `src/main/services/pipeline/contentStateMachine.test.ts` — 状态机测试

---

## 5. 项目目录结构

```
src/
├── main/                           # Electron 主进程
│   ├── index.ts                    # 主进程入口（bootstrap）
│   ├── ipc.ts                      # IPC 通道注册（~2500 行）
│   ├── captureService.ts           # 捕获服务（已迁移到 adapter）
│   ├── clipboardWatcher.ts         # 剪贴板监控
│   ├── sourceApp.ts                # 源应用检测
│   ├── sourceClassifier.ts         # 源应用分类
│   ├── storage.ts                  # SQLite 数据库（better-sqlite3）
│   ├── settings.ts                 # 设置管理
│   ├── logger.ts                   # 日志系统
│   ├── errorService.ts             # 统一错误服务
│   ├── errors.ts                   # 错误定义
│   ├── retryService.ts             # 重试服务
│   ├── tray.ts                     # 系统托盘
│   ├── shortcutManager.ts          # 快捷键管理
│   ├── permissions.ts              # 权限管理
│   ├── permissionCoordinator.ts    # 权限协调器
│   ├── appScope.ts                 # 应用作用域
│   ├── capsuleController.ts        # 胶囊控制器
│   ├── dashboardWindowController.ts # 仪表盘窗口
│   ├── windowFactory.ts            # 窗口工厂
│   └── services/
│       ├── capture/                # ★ Phase 7.1 新增：统一捕获适配器
│       │   ├── index.ts
│       │   ├── captureRegistry.ts
│       │   ├── manualTextAdapter.ts
│       │   ├── clipboardTextAdapter.ts
│       │   ├── screenshotAdapter.ts
│       │   ├── webpageAdapter.ts
│       │   ├── fileAdapter.ts
│       │   ├── imageAdapter.ts
│       │   ├── audioAdapter.ts
│       │   └── videoAdapter.ts
│       ├── pipeline/               # 内容处理管线
│       │   ├── index.ts
│       │   ├── contentStateMachine.ts
│       │   ├── contentPipelineService.ts
│       │   ├── contentStateMachine.test.ts
│       │   └── contentPipelineService.test.ts
│       ├── aiHub/                  # AI 任务中心
│       ├── distiller/              # 蒸馏引擎
│       ├── exporter/               # Obsidian 导出器
│       ├── importer/               # VaultKeeper 导入器
│       ├── parser/                 # 文档解析器
│       ├── localModel/             # 本地模型
│       ├── outputSpec/             # 输出规范服务
│       ├── scheduler/              # 调度器
│       └── search/                 # 搜索
├── preload/
│   └── index.ts                    # contextBridge API
├── renderer/                       # React 渲染进程
│   ├── App.tsx                     # 应用根组件
│   ├── CaptureHub.tsx              # 捕获中心
│   ├── CaptureLauncher.tsx         # 捕获启动器
│   ├── CaptureOverlay.tsx          # 捕获覆盖层
│   ├── components/                 # UI 组件
│   ├── hooks/                      # 自定义 Hooks
│   ├── pages/                      # 页面
│   └── services/                   # 渲染进程服务
└── shared/                         # 主进程/渲染进程共享
    ├── types.ts                    # ★ 核心类型定义（~900 行）
    ├── outputSpec.ts               # 输出规范
    ├── defaultSettings.ts          # 默认设置
    ├── markdownSpec.ts             # Markdown 规范
    ├── tagNormalizer.ts            # 标签规范化
    └── ai/                         # AI 共享
```

---

## 6. 关键类型系统

### 6.1 数据模型关系

```
CaptureItem (碎片收集箱)
  ↓ bridgeCaptureItemToSourceItem()
SourceItem (源内容)
  ↓ AI 蒸馏
AiTask (AI 处理任务)
  ↓
DistilledOutput (蒸馏结果)
  ↓ 审阅
KnowledgeCard (知识卡片)
  ↓ 导出
ExportRecord (导出记录)
```

### 6.2 新增 Phase 7.1 数据流

```
任意来源
  ↓ CaptureAdapter.capture()
CaptureRecord (统一捕获记录)
  ↓ processCaptureRecord()
SourceItem (桥接到现有存储)
  ↓ 继续走现有管线...
```

### 6.3 核心类型文件

- `src/shared/types.ts` — 所有核心类型定义（~900 行），包含 SourceItem / CaptureItem / AiTask / DistilledOutput / ExportRecord / CaptureRecord / CaptureAdapter 等

---

## 7. 构建与验证

### 7.1 验证命令

```bash
npm run typecheck    # TypeScript 类型检查（tsc --noEmit）
npm run build        # 完整构建（esbuild + vite）
npm test             # 单元测试（vitest）
```

### 7.2 当前验证状态

| 命令 | 状态 | 说明 |
|------|------|------|
| `npm run typecheck` | ✅ 通过 | 0 错误 |
| `npm run build` | ⚠️ VM 环境限制 | esbuild 二进制架构不兼容（非代码问题），在本地 Mac 应正常 |
| `npm test` | ✅ 通过 | 109/109（上次验证） |

### 7.3 构建工具链

- **主进程/preload**: esbuild（bundle → CJS）
- **渲染进程**: Vite + React
- **样式**: Tailwind CSS + PostCSS
- **测试**: Vitest
- **类型检查**: TypeScript strict mode
- **数据库**: better-sqlite3（schema version 12，13+ 张表）

---

## 8. IPC 通道总览

IPC 通道定义在 `src/shared/types.ts` 的 `IPC_CHANNELS` 常量中。当前约 90+ 个通道。

### Phase 7.1 新增通道

| 通道名 | 用途 |
|--------|------|
| `capture.record` | 统一捕获入口（CaptureInput → CaptureRecord → Pipeline） |
| `capture.getAvailableTypes` | 获取已注册的 adapter 类型列表 |

### Preload API 新增

```typescript
window.acmind.capture.record(input)        // 统一捕获
window.acmind.capture.getAvailableTypes()  // 获取可用类型
```

---

## 9. 半成品与待判断功能

以下功能有代码骨架但未完全闭环，需要判断保留还是删除：

| 功能 | 文件 | 状态 |
|------|------|------|
| 录屏链路 | `useRecording.ts`, `ipc.ts` | stub，capture.getRecordingState 等未真正闭环 |
| 语音转写 | `whisperService.ts`, `useVoiceRecorder.ts`, `VoiceCapturePanel.tsx` | UI 和服务存在，链路未收口 |
| 语音润色 | `polishService.ts` | 局部规则 + AI 占位 |
| 抠图 | `ipc.ts` cutout.processFromRecord | 原样返回数据的占位 |
| VaultKeeper 任务 | `ipc.ts` vk.task.create | 只记日志的占位 |
| 训练/模型/数据集 | `src/shared/types.ts` TrainingRun/ModelVersion 等 | 类型定义完整，无实际实现 |

---

## 10. 下一步建议

### Phase 7.2：多入口集成（建议优先）

现在 adapter 架构已就位，可以开始将更多入口接入统一管线：

1. **网页导入入口** — 使用 `webpageAdapter`，集成 `webParser.ts` 的 readability 解析
2. **文件导入入口** — 使用 `fileAdapter`，集成 `documentImporter.ts` 的 PDF/DOCX 解析
3. **截图入口** — 使用 `screenshotAdapter`，替换 `captureService.captureScreenshot()` 中的直接 SourceItem 创建
4. **渲染层迁移** — 将 `useContentPipeline` hook 迁移到使用 `capture.record()` API

### Phase 7.3：Adapter 增强

- 为 Audio/Video adapter 集成 Whisper STT
- 为 Webpage adapter 集成 readability + markitdown
- 为 File adapter 集成 PDF/DOCX 解析器
- 添加 adapter 级别的验证和错误处理

### 清理工作

- 删除或明确标记半成品功能（录屏/语音/抠图/VaultKeeper 任务）
- 更新 `src/shared/types.test.ts` 中的 IPC 通道数断言（可能因新增通道而过期）
- 考虑将 `CaptureService` 中的旧路径完全迁移到 adapter

---

## 11. 硬约束（不要改回去）

1. **Markdown 规范来源**：`acmind_output_spec_pack/` 模板包
2. **所有数据必须经过主链路**：SourceItem → AiTask → DistilledOutput → ExportRecord
3. **不允许**：mock 冒充真实模型、toast-only 按钮、只存在 renderer state 的结果、直接写 Markdown 但不创建 ExportRecord
4. **CaptureAdapter 不负责**：Markdown 生成、Obsidian 写入、UI 展示、AI 处理
5. **所有入口必须统一进入**：CaptureRecord → 状态机 → 自动整理 → Markdown → Obsidian → 输出历史

---

## 12. 需要重点检查的文件

### 核心文件（改动频繁）

- `src/shared/types.ts` — 类型定义
- `src/main/ipc.ts` — IPC 通道注册
- `src/main/index.ts` — 主进程入口（bootstrap）
- `src/main/storage.ts` — 数据库层
- `src/preload/index.ts` — Renderer API 暴露

### Phase 7.1 新增/重点改动

- `src/main/services/capture/captureRegistry.ts` — adapter 注册中心
- `src/main/services/capture/manualTextAdapter.ts` — 手动文本 adapter（参考实现）
- `src/main/services/pipeline/contentPipelineService.ts` — 管线服务（新增 processCaptureRecord）
- `src/main/captureService.ts` — 捕获服务（已迁移到 adapter）

### 渲染层

- `src/renderer/App.tsx` — 应用根组件
- `src/renderer/hooks/useContentPipeline.ts` — 管线 Hook
- `src/renderer/hooks/useCaptureItems.ts` — 捕获项 Hook
- `src/renderer/components/capture-inbox/AddCaptureItemDialog.tsx` — 新增碎片对话框

---

## 13. 开发环境注意

- **Node.js**: 项目使用 ES2022 target + ESNext modules
- **TypeScript**: strict mode 开启，noEmit（编译由 esbuild/Vite 完成）
- **数据库**: better-sqlite3，schema 版本 12
- **测试**: vitest，测试配置在 `vitest.config.ts` 和 `tsconfig.test.ts`
- **Electron**: ^35.1.4
- **React**: ^18.3.1
