# Electron 退役指南

> **状态**：执行中 | **目标完成日期**：2025 Q2  
> **前置条件**：Task 1-13 全部完成，Swift 主链路稳定

---

## 一、退役策略总览

Electron 代码 **保留为参考实现**，不删除源码，但从生产构建中完全剥离。

| 阶段 | 动作 | 产出 |
|------|------|------|
| P1 | Electron 代码归档为参考 | `src/` → `src.legacy/` |
| P2 | 生产构建移除 Electron 依赖 | Package.swift 独立可构建 |
| P3 | 打包/签名/发布切到 Xcode | `scripts/build.sh` 完整链路 |
| P4 | 旧数据迁移工具就绪 | `DataMigrationService` |
| P5 | CI/CD 切到 Swift | GitHub Actions 更新 |

---

## 二、Electron 代码归档方案

### 2.1 保留为参考的目录

```
src.legacy/                    # 重命名后的 Electron 参考代码
├── main/                      # 主进程（IPC、服务、窗口管理）
│   ├── index.ts               # 入口：窗口创建、IPC 注册
│   ├── services/              # 业务服务（AI、采集、蒸馏、导出、搜索）
│   └── voice/                 # 语音模块
├── preload/
│   └── index.ts               # contextBridge IPC 定义（API 契约参考）
├── renderer/                  # React UI（组件设计参考）
│   ├── components/
│   ├── pages/
│   └── design-system/
├── shared/                    # 类型定义（与 Swift Models 对齐参考）
│   └── types.ts
└── modules/                   # 模块 README（架构文档参考）
```

### 2.2 可安全删除的构建产物

```
dist/                          # Electron 构建输出（esbuild + Vite）
node_modules/                  # Node.js 依赖
main.js                        # Electron 入口（require('./dist/main/index.cjs')）
package-lock.json              # 锁文件（保留 package.json 作为参考）
```

### 2.3 保留的配置文件（作为参考）

| 文件 | 保留原因 |
|------|----------|
| `package.json` | 记录 Electron 依赖版本、IPC 通道定义、构建脚本 |
| `vite.config.ts` | 多窗口构建配置参考 |
| `tsconfig.json` | TypeScript 配置参考 |
| `tailwind.config.ts` | 设计系统 token 参考 |
| `eslint.config.mjs` | 代码规范参考 |

### 2.4 Electron → Swift 功能映射表

| Electron 模块 | Swift 原生替代 | 状态 |
|---------------|---------------|------|
| `src/main/services/aiHub/` | `AcMindKit/Services/AI/` | ✅ 已迁移 |
| `src/main/services/capture/` | `AcMindKit/Services/Capture/` | ✅ 已迁移 |
| `src/main/services/distiller/` | `AcMindKit/Services/Workflow/DistillService.swift` | ✅ 已迁移 |
| `src/main/services/exporter/` | `AcMindKit/Services/Workflow/ExportService.swift` | ✅ 已迁移 |
| `src/main/services/search/` | `AcMindKit/Services/Knowledge/` | ✅ 已迁移 |
| `src/main/services/vaultkeeper/` | `AcMindKit/Services/Storage/` | ✅ 已迁移 |
| `src/main/services/chat/` | `App/ViewModels/AgentViewModel.swift` | ✅ 已迁移 |
| `src/main/services/dashboard/` | `Features/Native/Schedule/` | ✅ 已迁移 |
| `src/main/services/scheduler/` | `App/AppDelegate.swift` | ✅ 已迁移 |
| `src/main/services/importer/` | 待实现 | 🚧 Shelf 迁移后处理 |
| `src/main/services/parser/` | `AcMindKit/Services/Workflow/` | ✅ 已迁移 |
| `src/main/services/pipeline/` | `AcMindKit/Services/Workflow/` | ✅ 已迁移 |
| `src/main/services/strategy/` | `AcMindKit/Services/Workflow/` | ✅ 已迁移 |
| `src/main/voice/` | `AcMindKit/Services/Voice/` | ✅ 已迁移 |
| `src/preload/index.ts` | `Features/WebView/WebViewBridge.swift` | 🚧 仅 Shelf |
| `src/renderer/` | `Features/Native/` | ✅ 已迁移 |

---

## 三、IPC 通道迁移参考

Electron preload 暴露的 IPC 通道与 Swift 原生 API 的对应关系：

| IPC 通道 | Swift 替代 |
|----------|-----------|
| `source-items.*` | `StorageService` CRUD |
| `capture.*` | `CaptureService` |
| `clipboard.*` | `ClipboardService` |
| `distill.*` | `DistillService` |
| `export.*` | `ExportService` |
| `ai.*` | `AIRuntimeService` |
| `knowledge.*` | `KnowledgeService` |
| `voice.*` | `VoiceService` |
| `settings.*` | `SettingsService` |
| `search.*` | `KnowledgeService.searchVault()` |

---

## 四、数据迁移方案

### 4.1 Electron 数据位置

```
~/Library/Application Support/AcMind/
├── acmind.db          # Electron SQLite 数据库（better-sqlite3）
├── assets/            # 附件文件
├── vaults/            # Vault 目录
└── config.json        # 应用配置
```

### 4.2 Swift 数据位置

```
~/Library/Application Support/AcMind/
├── acmind-swift.db    # Swift GRDB 数据库
├── assets/            # 附件（共享）
└── vaults/            # Vault 目录（共享）
```

### 4.3 迁移策略

- **首次启动检测**：检查 `acmind.db` 是否存在
- **表级迁移**：逐表读取旧数据，写入新库
- **幂等设计**：重复运行不产生重复数据
- **迁移完成标记**：写入 `_migration.electron_imported = true`
- **旧库保留**：迁移成功后重命名为 `acmind.db.migrated`

详见 `AcMindKit/Services/Storage/DataMigrationService.swift`

---

## 五、构建链路切换

### 5.1 旧链路（Electron）

```
npm run build → esbuild + Vite → dist/ → electron-builder → AcMind.dmg
```

### 5.2 新链路（Swift 原生）

```
scripts/build.sh → swift package resolve → xcodebuild → AcMind.app → codesign → AcMind.dmg
```

### 5.3 签名 & 公证

- **开发签名**：`codesign --sign - --deep --force AcMind.app`
- **发布签名**：`codesign --sign "Developer ID Application: ..." --options runtime --deep AcMind.app`
- **公证**：`xcrun notarytool submit AcMind.dmg --apple-id ... --team-id ... --password ...`
- **DMG 打包**：`hdiutil create -volname AcMind -srcfolder AcMind.app AcMind.dmg`

---

## 六、回退方案

如果 Swift 版本出现严重问题：

1. `src.legacy/` 保留完整 Electron 源码
2. `git checkout` 到最后一个 Electron 发布 tag
3. `npm ci && npm run build && npm run package` 即可恢复

---

## 七、时间线

| 里程碑 | 日期 | 状态 |
|--------|------|------|
| Task 1-13 完成 | 2025-05-07 | ✅ |
| Electron 代码归档 | 2025-05-08 | 🚧 |
| Package.swift 独立构建 | 2025-05-08 | 🚧 |
| 原生构建链路就绪 | 2025-05-08 | 🚧 |
| 数据迁移工具就绪 | 2025-05-08 | 🚧 |
| CI/CD 切换 | 2025-05-08 | 🚧 |
| Shelf 原生迁移完成 | 2025-05-15 | ⏳ |
| WebView 完全移除 | 2025 Q2 | ⏳ |
| Electron 代码归档为只读 | 2025 Q3 | ⏳ |
