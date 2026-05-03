# AcMind 当前问题修复任务清单

> 目标：修复目前扫描和验证中已经能发现的问题，先恢复编译与测试，再修正明显的运行时/产品逻辑缺陷。

## 0. 修复原则

- 先修复会阻塞 `typecheck`、`test`、`build` 的问题。
- 再修复会误导用户的运行时逻辑问题。
- 每个任务都要补最小回归测试，避免“修了一个点，旁边又坏掉”。

## 1. 阻塞项

- [ ] 修复 PDF 解析器的编译错误
  - 文件：[`src/main/services/parser/pdfParser.ts`](/Volumes/White%20Atlas/03_Projects/AcMindV2.0/src/main/services/parser/pdfParser.ts)
  - 问题：`textResult.pages` 可能为 `undefined`，但代码直接访问了 `length` 和 `map()`，导致 `tsc` 报错。
  - 处理方式：先把 `pages` 安全归一化，再生成 `sections` 和 `pageCount`。
  - 验收：`npm run typecheck` 通过。

- [ ] 修复调度器的 `crypto.randomUUID()` 导入问题
  - 文件：[`src/main/services/scheduler/schedulerService.ts`](/Volumes/White%20Atlas/03_Projects/AcMindV2.0/src/main/services/scheduler/schedulerService.ts)
  - 问题：文件直接使用 `crypto.randomUUID()`，但没有显式导入 `node:crypto`。
  - 处理方式：补充正确导入，或改成明确的 `randomUUID` 导入。
  - 验收：调度器能正常创建任务，`typecheck` 不再因该文件失败。

- [ ] 同步更新 IPC 通道测试基线
  - 文件：[`src/shared/types.test.ts`](/Volumes/White%20Atlas/03_Projects/AcMindV2.0/src/shared/types.test.ts)
  - 问题：测试里硬编码的 IPC 总数已经过期，当前实际值是 99，测试仍写 86。
  - 处理方式：改成按当前分组动态计算，或明确维护预期总数。
  - 验收：`npm test` 通过。

## 2. 运行时正确性

- [ ] 修复自动化页面显示的 `nextRunAt` 误差
  - 文件：[`src/main/services/scheduler/schedulerService.ts`](/Volumes/White%20Atlas/03_Projects/AcMindV2.0/src/main/services/scheduler/schedulerService.ts)
  - 文件：[`src/renderer/pages/automation/index.tsx`](/Volumes/White%20Atlas/03_Projects/AcMindV2.0/src/renderer/pages/automation/index.tsx)
  - 问题：`computeNextRun()` 只是基于分钟字段的启发式估算，不是完整 cron 解析；UI 会展示一个可能不准确的“下次运行”时间。
  - 处理方式：要么接入真正的 next-run 计算，要么在 UI 中明确标注为“估算值”。
  - 验收：同一 cron 表达式在 UI 与实际调度行为一致，或清楚区分估算/真实值。

- [ ] 修复搜索模块的向量索引闭环
  - 文件：[`src/main/services/search/vectorSearch.ts`](/Volumes/White%20Atlas/03_Projects/AcMindV2.0/src/main/services/search/vectorSearch.ts)
  - 文件：[`src/main/services/search/embeddingService.ts`](/Volumes/White%20Atlas/03_Projects/AcMindV2.0/src/main/services/search/embeddingService.ts)
  - 文件：[`src/main/ipc.ts`](/Volumes/White%20Atlas/03_Projects/AcMindV2.0/src/main/ipc.ts)
  - 问题：`vectorSearch.upsert()` 直接 `throw`，没有真实入库路径；当前 hybrid search 实际上只能依赖关键词搜索。
  - 处理方式：补齐 embedding 生成、入库、更新、删除的完整流程，并在 source item / distilled output 变更时维护索引。
  - 验收：`search_embeddings` 能被稳定写入，向量检索结果可被实际查到。

- [ ] 修复 FTS5 索引 schema 设计问题
  - 文件：[`src/main/services/search/keywordSearch.ts`](/Volumes/White%20Atlas/03_Projects/AcMindV2.0/src/main/services/search/keywordSearch.ts)
  - 问题：当前 FTS 表使用了 `content='search_fts_content'`，但仓库里没有对应的 content table；而代码又直接向 FTS 表插入数据，这种配置很容易造成索引行为和预期不一致。
  - 处理方式：明确选择“外部 content 模式”或“独立 FTS 表模式”，不要混用。
  - 验收：重建索引、搜索查询、统计状态都能稳定工作。

- [ ] 修复搜索状态统计的可信度
  - 文件：[`src/main/ipc.ts`](/Volumes/White%20Atlas/03_Projects/AcMindV2.0/src/main/ipc.ts)
  - 文件：[`src/renderer/pages/search/index.tsx`](/Volumes/White%20Atlas/03_Projects/AcMindV2.0/src/renderer/pages/search/index.tsx)
  - 问题：当前 `embeddingCount` / `ftsCount` 的展示依赖底层表是否存在和是否已初始化，但初始化与实际可用性不是一回事。
  - 处理方式：把“已初始化”“已索引数量”“可搜索状态”拆开，避免 UI 误报健康。
  - 验收：搜索页状态展示与实际结果一致。

## 3. 数据与迁移

- [ ] 审核新增表和迁移是否有遗漏
  - 文件：[`src/main/storage.ts`](/Volumes/White%20Atlas/03_Projects/AcMindV2.0/src/main/storage.ts)
  - 问题：主存储已经引入多个新增表和字段，但需要确认迁移、回填和读写路径全部覆盖。
  - 处理方式：逐表核对新增字段、迁移版本和回填逻辑。
  - 验收：从旧数据库升级到新版本不丢数据，不报错。

- [ ] 检查 scheduler 持久化字段与内存结构一致性
  - 文件：[`src/main/services/scheduler/schedulerService.ts`](/Volumes/White%20Atlas/03_Projects/AcMindV2.0/src/main/services/scheduler/schedulerService.ts)
  - 问题：`nextRunAt`、`lastRunAt`、`lastResult` 都会被写入数据库和内存，但要确认任务启停、手动运行、重启恢复时字段不会互相覆盖。
  - 处理方式：为创建、更新、触发、恢复四条路径补单测。
  - 验收：调度器重启后任务状态一致。

## 4. 测试补强

- [ ] 给 PDF 解析补回归测试
  - 文件：[`src/main/services/parser/pdfParser.test.ts`](/Volumes/White%20Atlas/03_Projects/AcMindV2.0/src/main/services/parser/pdfParser.test.ts)
  - 目标：覆盖无页面、单页、多页、加密/损坏 PDF 的分支。

- [ ] 给搜索模块补索引测试
  - 文件：[`src/main/services/search/*.test.ts`](/Volumes/White%20Atlas/03_Projects/AcMindV2.0/src/main/services/search/)
  - 目标：覆盖 FTS 重建、关键词查询、向量入库、hybrid 结果融合。

- [ ] 给调度器补任务生命周期测试
  - 文件：[`src/main/services/scheduler/schedulerService.test.ts`](/Volumes/White%20Atlas/03_Projects/AcMindV2.0/src/main/services/scheduler/schedulerService.test.ts)
  - 目标：覆盖 create / update / toggle / runNow / recover / cron trigger。

- [ ] 更新 IPC 相关测试与文档
  - 文件：[`src/shared/types.test.ts`](/Volumes/White%20Atlas/03_Projects/AcMindV2.0/src/shared/types.test.ts)
  - 文件：[`PROJECT_HANDOVER.md`](/Volumes/White%20Atlas/03_Projects/AcMindV2.0/PROJECT_HANDOVER.md)
  - 目标：保证通道总数、分组和实际实现一致。

## 5. 建议的修复顺序

1. 先修 `pdfParser.ts`。
2. 再修 `schedulerService.ts` 的 `crypto` 导入。
3. 同步修 `src/shared/types.test.ts`。
4. 然后处理 `scheduler nextRunAt` 逻辑。
5. 最后补搜索向量闭环和 FTS 结构修正。

## 6. 最小完成标准

- `npm run typecheck` 通过。
- `npm test` 通过。
- 搜索页、自动化页、解析导入页没有明显的“看起来能用但实际不闭环”的问题。
