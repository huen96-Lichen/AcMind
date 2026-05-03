# AcMind 前端 UI 文案审计

说明
- 范围：`src/renderer` 下当前可见前端文案。
- 口径：按“页面 / 全局组件”分组，重复出现的共享文案尽量只列一次。
- 记法：每条都标注了文件路径和大致组件名；动态拼接文案保留了模板片段。

## 首页

- `[src/renderer/pages/daily-flow/DailyKnowledgeFlowPage.tsx](/Volumes/White Atlas/03_Projects/AcMindV2.0/src/renderer/pages/daily-flow/DailyKnowledgeFlowPage.tsx)` · `DailyKnowledgeFlowPage` · 页面标题/副标题：`每日知识流`、`工作台`、`查看今日收集、待整理内容、AI 处理状态和最近导出结果。`
- `[src/renderer/pages/daily-flow/DailyKnowledgeFlowPage.tsx](/Volumes/White Atlas/03_Projects/AcMindV2.0/src/renderer/pages/daily-flow/DailyKnowledgeFlowPage.tsx)` · `DailyKnowledgeFlowPage` · 加载态：`正在加载工作台`、`正在获取今日数据和待处理内容。`
- `[src/renderer/pages/daily-flow/DailyKnowledgeFlowPage.tsx](/Volumes/White Atlas/03_Projects/AcMindV2.0/src/renderer/pages/daily-flow/DailyKnowledgeFlowPage.tsx)` · `DailyKnowledgeFlowPage` · 错误态：`工作台加载失败`、`请检查应用状态后重试。`、`重新加载`
- `[src/renderer/pages/daily-flow/DailyKnowledgeFlowPage.tsx](/Volumes/White Atlas/03_Projects/AcMindV2.0/src/renderer/pages/daily-flow/DailyKnowledgeFlowPage.tsx)` · `DailyKnowledgeFlowPage` · 主按钮：`开始整理待处理内容`
- `[src/renderer/pages/daily-flow/DailyKnowledgeFlowPage.tsx](/Volumes/White Atlas/03_Projects/AcMindV2.0/src/renderer/pages/daily-flow/DailyKnowledgeFlowPage.tsx)` · `DailyKnowledgeFlowPage` · 概览区：`今日概览`、`今日知识收集和处理统计。`、`今日收集`、`待整理`、`AI 已处理`、`近期导出`
- `[src/renderer/pages/daily-flow/DailyKnowledgeFlowPage.tsx](/Volumes/White Atlas/03_Projects/AcMindV2.0/src/renderer/pages/daily-flow/DailyKnowledgeFlowPage.tsx)` · `DailyKnowledgeFlowPage` · 建议区：`下一步建议`、`根据当前状态推荐的操作。`、`优先`、`开始整理`、`AI 整理`、`查看记录`、`去收集`
- `[src/renderer/pages/daily-flow/DailyKnowledgeFlowPage.tsx](/Volumes/White Atlas/03_Projects/AcMindV2.0/src/renderer/pages/daily-flow/DailyKnowledgeFlowPage.tsx)` · `DailyKnowledgeFlowPage` · 建议文案：`整理待处理内容`、`有 X 条内容等待整理`、`启动 AI 整理`、`今日收集的内容还未进行 AI 处理`、`查看导出结果`、`最近有 X 条导出记录`、`开始收集内容`、`从剪贴板、文本或文件开始收集灵感`
- `[src/renderer/pages/daily-flow/DailyKnowledgeFlowPage.tsx](/Volumes/White Atlas/03_Projects/AcMindV2.0/src/renderer/pages/daily-flow/DailyKnowledgeFlowPage.tsx)` · `DailyKnowledgeFlowPage` · 问题区：`需要处理的问题`、`以下内容需要你关注或处理。`、`待处理超过 7 天`、`整理`
- `[src/renderer/pages/daily-flow/DailyKnowledgeFlowPage.tsx](/Volumes/White Atlas/03_Projects/AcMindV2.0/src/renderer/pages/daily-flow/DailyKnowledgeFlowPage.tsx)` · `DailyKnowledgeFlowPage` · 最近收集空态：`还没有收集内容`、`你可以复制文字、拖入文件，或从快捷入口收集灵感。`、`去收集箱`
- `[src/renderer/pages/daily-flow/DailyKnowledgeFlowPage.tsx](/Volumes/White Atlas/03_Projects/AcMindV2.0/src/renderer/pages/daily-flow/DailyKnowledgeFlowPage.tsx)` · `DailyKnowledgeFlowPage` · 最近导出空态：`还没有导出记录`、`整理内容后确认导出，文件会写入到你的知识库中。`、`去 AI 整理`
- `[src/renderer/pages/daily-flow/DailyKnowledgeFlowPage.tsx](/Volumes/White Atlas/03_Projects/AcMindV2.0/src/renderer/pages/daily-flow/DailyKnowledgeFlowPage.tsx)` · `DailyKnowledgeFlowPage` · 最近条目状态：`已处理`、`处理中`、`待处理`、`暂无预览`、`已导出`、`失败`、`冲突`

## 收集

- `[src/renderer/pages/capture-inbox/CaptureInboxPage.tsx](/Volumes/White Atlas/03_Projects/AcMindV2.0/src/renderer/pages/capture-inbox/CaptureInboxPage.tsx)` · `CaptureInboxPage` · 页面标题/副标题：`内容收集`、`收集箱`、`管理从剪贴板、文本、文件和快捷入口收集到的内容。`
- `[src/renderer/pages/capture-inbox/CaptureInboxPage.tsx](/Volumes/White Atlas/03_Projects/AcMindV2.0/src/renderer/pages/capture-inbox/CaptureInboxPage.tsx)` · `CaptureInboxPage` · 主按钮：`新增收集`
- `[src/renderer/pages/capture-inbox/CaptureInboxPage.tsx](/Volumes/White Atlas/03_Projects/AcMindV2.0/src/renderer/pages/capture-inbox/CaptureInboxPage.tsx)` · `CaptureInboxPage` · 快捷区：`快捷操作`、`先处理最常用的收集入口。`
- `[src/renderer/pages/capture-inbox/CaptureInboxPage.tsx](/Volumes/White Atlas/03_Projects/AcMindV2.0/src/renderer/pages/capture-inbox/CaptureInboxPage.tsx)` · `CaptureInboxPage` · 状态 badge：`需要处理`、`已进入 Obsidian`、`正在整理`
- `[src/renderer/pages/capture-inbox/CaptureInboxPage.tsx](/Volumes/White Atlas/03_Projects/AcMindV2.0/src/renderer/pages/capture-inbox/CaptureInboxPage.tsx)` · `CaptureInboxPage` · 排队控制：`继续任务`、`暂停任务`、`继续后续任务`、`暂停后续任务`
- `[src/renderer/pages/capture-inbox/CaptureInboxPage.tsx](/Volumes/White Atlas/03_Projects/AcMindV2.0/src/renderer/pages/capture-inbox/CaptureInboxPage.tsx)` · `CaptureInboxPage` · 收集按钮：`收集剪贴板`、`收集截图`、`导入文件`、`新增收集`
- `[src/renderer/pages/capture-inbox/CaptureInboxPage.tsx](/Volumes/White Atlas/03_Projects/AcMindV2.0/src/renderer/pages/capture-inbox/CaptureInboxPage.tsx)` · `CaptureInboxPage` · 搜索占位符：`搜索内容...`
- `[src/renderer/pages/capture-inbox/CaptureInboxPage.tsx](/Volumes/White Atlas/03_Projects/AcMindV2.0/src/renderer/pages/capture-inbox/CaptureInboxPage.tsx)` · `CaptureInboxPage` · 层级切换：`整理层级`、`本地轻量`、`云端标准`、`云端高级`、`这里只影响后续整理与重整，不会打断当前运行中的任务。`
- `[src/renderer/pages/capture-inbox/CaptureInboxPage.tsx](/Volumes/White Atlas/03_Projects/AcMindV2.0/src/renderer/pages/capture-inbox/CaptureInboxPage.tsx)` · `CaptureInboxPage` · 批量选择：`已选择 X 项`、`全选当前列表`、`清空选择`、`批量删除`、`用当前层级重整`、`删除前先暂停队列，避免正在处理的任务被打断。`
- `[src/renderer/pages/capture-inbox/CaptureInboxPage.tsx](/Volumes/White Atlas/03_Projects/AcMindV2.0/src/renderer/pages/capture-inbox/CaptureInboxPage.tsx)` · `CaptureInboxPage` · 错误/空态：`收集箱加载失败`、`请检查应用状态后重试。`、`重新加载`、`还没有待整理内容`、`你可以复制文字、拖入文件，或从快捷入口收集灵感。`、`新增收集`
- `[src/renderer/pages/capture-inbox/CaptureInboxPage.tsx](/Volumes/White Atlas/03_Projects/AcMindV2.0/src/renderer/pages/capture-inbox/CaptureInboxPage.tsx)` · `CaptureInboxPage` · Footer：`加载中...`、`共 X 条内容`
- `[src/renderer/pages/capture-inbox/CaptureInboxPage.tsx](/Volumes/White Atlas/03_Projects/AcMindV2.0/src/renderer/pages/capture-inbox/CaptureInboxPage.tsx)` · `CaptureInboxPage` · Toast：`笔记已收集并处理`、`处理失败: ...`、`内容「...」已收集`、`已删除`、`已删除 X 项，Y 项失败`
- `[src/renderer/components/capture-inbox/AddCaptureItemDialog.tsx](/Volumes/White Atlas/03_Projects/AcMindV2.0/src/renderer/components/capture-inbox/AddCaptureItemDialog.tsx)` · `AddCaptureItemDialog` · 标题/标签页：`新增碎片`、`文本`、`链接`、`图片`
- `[src/renderer/components/capture-inbox/AddCaptureItemDialog.tsx](/Volumes/White Atlas/03_Projects/AcMindV2.0/src/renderer/components/capture-inbox/AddCaptureItemDialog.tsx)` · `AddCaptureItemDialog` · 表单：`标题（可选）`、`文本内容 *`、`链接地址 *`、`网页正文`、`图片 *`、`备注（可选）`
- `[src/renderer/components/capture-inbox/AddCaptureItemDialog.tsx](/Volumes/White Atlas/03_Projects/AcMindV2.0/src/renderer/components/capture-inbox/AddCaptureItemDialog.tsx)` · `AddCaptureItemDialog` · 占位符：`网页标题（抓取时自动填充）`、`碎片标题`、`输入或粘贴文本内容...`、`https://...`、`粘贴网页正文内容...`、`点击选择图片，或粘贴 / 拖入图片`、`添加备注...`
- `[src/renderer/components/capture-inbox/AddCaptureItemDialog.tsx](/Volumes/White Atlas/03_Projects/AcMindV2.0/src/renderer/components/capture-inbox/AddCaptureItemDialog.tsx)` · `AddCaptureItemDialog` · 链接模式：`自动抓取`、`粘贴正文`、`系统将自动抓取网页正文并整理为笔记`
- `[src/renderer/components/capture-inbox/AddCaptureItemDialog.tsx](/Volumes/White Atlas/03_Projects/AcMindV2.0/src/renderer/components/capture-inbox/AddCaptureItemDialog.tsx)` · `AddCaptureItemDialog` · 按钮/错误：`取消`、`收集网页`、`添加碎片`、`抓取中...`、`收集中...`、`添加中...`、`请输入文本内容`、`请输入链接地址`、`请选择或粘贴图片`、`请选择图片文件`、`请拖入图片文件`、`网页收集失败`
- `[src/renderer/components/capture-inbox/CaptureItemCard.tsx](/Volumes/White Atlas/03_Projects/AcMindV2.0/src/renderer/components/capture-inbox/CaptureItemCard.tsx)` · `CaptureItemCard` · 状态：`待处理`、`已蒸馏`、`失败`、`已忽略`、`蒸馏中`、`正在转写`、`转写完成`
- `[src/renderer/components/capture-inbox/CaptureItemCard.tsx](/Volumes/White Atlas/03_Projects/AcMindV2.0/src/renderer/components/capture-inbox/CaptureItemCard.tsx)` · `CaptureItemCard` · 来源/标题：`Web Clipper`、`语音录音`、`文件导入`、`Electron`、`手动输入`、`图片捕获 · MM-DD HH:MM`、`语音录音 · MM-DD HH:MM`、`未命名捕获`
- `[src/renderer/components/capture-inbox/CaptureItemCard.tsx](/Volumes/White Atlas/03_Projects/AcMindV2.0/src/renderer/components/capture-inbox/CaptureItemCard.tsx)` · `CaptureItemCard` · 操作：`蒸馏`、`重试`、`查看结果`、`删除`、`重试蒸馏`、`查看蒸馏结果`
- `[src/renderer/components/capture-inbox/CaptureItemDetail.tsx](/Volumes/White Atlas/03_Projects/AcMindV2.0/src/renderer/components/capture-inbox/CaptureItemDetail.tsx)` · `CaptureItemDetail` · 空态/标题：`选择一条碎片查看详情`、`碎片详情`
- `[src/renderer/components/capture-inbox/CaptureItemDetail.tsx](/Volumes/White Atlas/03_Projects/AcMindV2.0/src/renderer/components/capture-inbox/CaptureItemDetail.tsx)` · `CaptureItemDetail` · 删除确认：`删除`、`确认删除？`、`删除中...`、`确认`、`取消`
- `[src/renderer/components/capture-inbox/CaptureItemDetail.tsx](/Volumes/White Atlas/03_Projects/AcMindV2.0/src/renderer/components/capture-inbox/CaptureItemDetail.tsx)` · `CaptureItemDetail` · 内容区：`标题`、`未命名碎片`、`链接地址`、`图片信息`、`转写内容`、`原文内容`、`复制原文`、`已复制 ✓`、`无链接`、`摘要`
- `[src/renderer/components/capture-inbox/CaptureItemDetail.tsx](/Volumes/White Atlas/03_Projects/AcMindV2.0/src/renderer/components/capture-inbox/CaptureItemDetail.tsx)` · `CaptureItemDetail` · 图片/语音：`加载图片中...`、`图片加载失败`、`语音录音`、`未知路径`、`打开录音`、`转写文本`、`正在转写中...`、`等待转写`、`重试转写`
- `[src/renderer/components/capture-inbox/CaptureItemDetail.tsx](/Volumes/White Atlas/03_Projects/AcMindV2.0/src/renderer/components/capture-inbox/CaptureItemDetail.tsx)` · `CaptureItemDetail` · 备注/状态：`备注`、`编辑`、`添加备注...`、`保存中...`、`保存`、`暂无备注`、`状态`、`待整理`、`已归档`、`已忽略`、`处理失败`、`正在转写`、`转写完成`
- `[src/renderer/components/capture-inbox/CaptureItemDetail.tsx](/Volumes/White Atlas/03_Projects/AcMindV2.0/src/renderer/components/capture-inbox/CaptureItemDetail.tsx)` · `CaptureItemDetail` · 元数据：`元数据`、`类型`、`状态`、`收集时间`、`更新时间`、`来源链接`、`文件路径`
- `[src/renderer/pages/capture/CapturePage.tsx](/Volumes/White Atlas/03_Projects/AcMindV2.0/src/renderer/pages/capture/CapturePage.tsx)` · `CapturePage` · 页面标题/副标题：`快速捕获`、`一键截图，或者回到主工作区继续整理。`
- `[src/renderer/pages/capture/CapturePage.tsx](/Volumes/White Atlas/03_Projects/AcMindV2.0/src/renderer/pages/capture/CapturePage.tsx)` · `CapturePage` · 主区域：`截图并保存`、`这里不保留占位按钮。点击后会直接执行截图，截图成功后会入库到收集箱。`
- `[src/renderer/pages/capture/CapturePage.tsx](/Volumes/White Atlas/03_Projects/AcMindV2.0/src/renderer/pages/capture/CapturePage.tsx)` · `CapturePage` · 按钮/状态：`开始截图`、`截图中...`、`截图已保存到收集箱`、`截图未完成，请检查权限`
- `[src/renderer/pages/capture/CapturePage.tsx](/Volumes/White Atlas/03_Projects/AcMindV2.0/src/renderer/pages/capture/CapturePage.tsx)` · `CapturePage` · 运行状态：`剪贴板`、`开启`、`关闭`、`屏幕录制`、`未知`、`存储`、`未加载`、`整理方式`
- `[src/renderer/pages/capture/CapturePage.tsx](/Volumes/White Atlas/03_Projects/AcMindV2.0/src/renderer/pages/capture/CapturePage.tsx)` · `CapturePage` · 导航按钮：`返回工作台`、`打开收件箱`、`打开设置`
- `[src/renderer/CaptureHub.tsx](/Volumes/White Atlas/03_Projects/AcMindV2.0/src/renderer/CaptureHub.tsx)` · `CaptureHubVkBar` · 快速工具：`快速工具`、`依赖 VaultKeeper 服务`、`转换`、`图片`、`打包`、`网页`、`转写`、`抠图`
- `[src/renderer/CaptureHub.tsx](/Volumes/White Atlas/03_Projects/AcMindV2.0/src/renderer/CaptureHub.tsx)` · `CaptureHubVkBar` · 占位/反馈：`输入文件路径…`、`输入图片地址或网页地址…`、`输入文件夹路径…`、`输入网页地址…`、`输入视频或音频文件路径…`、`执行`、`快捷工具未运行，请先在主面板启动`、`透明 PNG 抠图`、`点击后直接进入截图，截图完成即自动抠图并回写为新图片卡片。`、`开始抠图`、`快捷工具未运行，但抠图页仍可打开并执行本地抠图。`、`任务已提交`、`操作失败`
- `[src/renderer/CaptureHub.tsx](/Volumes/White Atlas/03_Projects/AcMindV2.0/src/renderer/CaptureHub.tsx)` · `CaptureHub` · 面板：`AcMind`、`轻量截图工作面板`、`桌面快捷捕获`、`固定尺寸截图`、`录屏中`
- `[src/renderer/CaptureHub.tsx](/Volumes/White Atlas/03_Projects/AcMindV2.0/src/renderer/CaptureHub.tsx)` · `CaptureHub` · 权限：`权限状态`、`屏幕录制：`、`刷新状态`、`打开系统设置`、`稍后处理`、`权限异常`、`权限正常`、`屏幕录制权限正常。`、`尚未获取权限状态。`、`当前运行实例可能与系统授权实例不一致。`
- `[src/renderer/CaptureHub.tsx](/Volumes/White Atlas/03_Projects/AcMindV2.0/src/renderer/CaptureHub.tsx)` · `CaptureHub` · 截图模式：`自由截图`、`固定尺寸`、`主操作`、`宽`、`高`、`锁定比例`、`当前尺寸：`、`待输入`、`尺寸建议`、`比例预设`、`常用尺寸`、`最近尺寸`
- `[src/renderer/CaptureHub.tsx](/Volumes/White Atlas/03_Projects/AcMindV2.0/src/renderer/CaptureHub.tsx)` · `CaptureHub` · 执行区：`执行`、`开始截图`、`录屏保存功能即将推出`
- `[src/renderer/CaptureOverlay.tsx](/Volumes/White Atlas/03_Projects/AcMindV2.0/src/renderer/CaptureOverlay.tsx)` · `CaptureOverlay` · 交互提示：`Escape` 取消、`Enter` 确认、`Cmd/Ctrl + C` 复制颜色值
- `[src/renderer/pages/capsule/CapsulePage.tsx](/Volumes/White Atlas/03_Projects/AcMindV2.0/src/renderer/pages/capsule/CapsulePage.tsx)` · `CapsulePage` · 状态路由：`visible_idle`、`visible_has_content`、`edge_hidden`、`edge_peek`、`expanded`、`recording_voice`、`capturing_screen`、`saving`、`success`、`error`
- `[src/renderer/pages/capsule/CapsuleCollapsed.tsx](/Volumes/White Atlas/03_Projects/AcMindV2.0/src/renderer/pages/capsule/CapsuleCollapsed.tsx)` · `CapsuleCollapsed` · 无文字面板，仅图标与徽标；交互无额外文案
- `[src/renderer/pages/capsule/CapsuleEdgeHidden.tsx](/Volumes/White Atlas/03_Projects/AcMindV2.0/src/renderer/pages/capsule/CapsuleEdgeHidden.tsx)` · `CapsuleEdgeHidden` · 无文字条，仅悬浮预览状态
- `[src/renderer/pages/capsule/CapsuleExpanded.tsx](/Volumes/White Atlas/03_Projects/AcMindV2.0/src/renderer/pages/capsule/CapsuleExpanded.tsx)` · `CapsuleExpanded` · 入口/模式：`网页链接`、`文字碎片`、`截图`、`语音`、`灵感`、`想法`、`待办`、`学习`、`项目`
- `[src/renderer/pages/capsule/CapsuleExpanded.tsx](/Volumes/White Atlas/03_Projects/AcMindV2.0/src/renderer/pages/capsule/CapsuleExpanded.tsx)` · `CapsuleExpanded` · AI 润色选项：`摘要提炼`、`精简重写`、`翻译为中文`、`提取关键信息`、`提取核心要点`、`去除冗余，更清晰`、`英文内容转中文`、`结构化提取数据`
- `[src/renderer/pages/capsule/CapsuleExpanded.tsx](/Volumes/White Atlas/03_Projects/AcMindV2.0/src/renderer/pages/capsule/CapsuleExpanded.tsx)` · `CapsuleExpanded` · 面板文案：`请输入有效的网页 URL`、`转换失败，请检查 URL 是否可访问`、`转换失败`、`转换出错`、`请输入内容`、`完成后可在二级整理页继续处理`
- `[src/renderer/pages/capsule/VoiceCapturePanel.tsx](/Volumes/White Atlas/03_Projects/AcMindV2.0/src/renderer/pages/capsule/VoiceCapturePanel.tsx)` · `VoiceCapturePanel` · 标题/状态：`语音转文字`、`点击开始录音`、`正在录音…`、`转写结果`、`未识别到语音内容…`
- `[src/renderer/pages/capsule/VoiceCapturePanel.tsx](/Volumes/White Atlas/03_Projects/AcMindV2.0/src/renderer/pages/capsule/VoiceCapturePanel.tsx)` · `VoiceCapturePanel` · 按钮：`取消`、`重录`、`使用此文本`
- `[src/renderer/pages/capsule/VoiceCapturePanel.tsx](/Volumes/White Atlas/03_Projects/AcMindV2.0/src/renderer/pages/capsule/VoiceCapturePanel.tsx)` · `VoiceCapturePanel` · 错误提示：`当前环境不支持语音识别，请使用 Chrome 浏览器`、`语音识别出错: ...`、`无法启动语音识别，请检查麦克风权限`

## 整理

- `[src/renderer/pages/distill/DistillPage.tsx](/Volumes/White Atlas/03_Projects/AcMindV2.0/src/renderer/pages/distill/DistillPage.tsx)` · `DistillPage` · 页面标题/副标题：`AI 工作区`、`AI 整理`、`将收集内容整理为结构化 Markdown，并确认导出到本地知识库。`
- `[src/renderer/pages/distill/DistillPage.tsx](/Volumes/White Atlas/03_Projects/AcMindV2.0/src/renderer/pages/distill/DistillPage.tsx)` · `DistillPage` · 视图切换：`视图切换`、`工作台和批量蒸馏使用同一套整理能力。`、`蒸馏工作台`、`批量蒸馏`
- `[src/renderer/pages/distill/DistillPage.tsx](/Volumes/White Atlas/03_Projects/AcMindV2.0/src/renderer/pages/distill/DistillPage.tsx)` · `DistillPage` · 批量分栏：`蒸馏队列`、`审阅与确认`
- `[src/renderer/pages/distill/DistillationWorkbench.tsx](/Volumes/White Atlas/03_Projects/AcMindV2.0/src/renderer/pages/distill/DistillationWorkbench.tsx)` · `DistillationWorkbench` · 说明性文案：`工作台`、`整理内容`、`自动整理`、`等待审阅`、`输出到知识库`（以当前实现为准）
- `[src/renderer/components/distill/DistillBatchPanel.tsx](/Volumes/White Atlas/03_Projects/AcMindV2.0/src/renderer/components/distill/DistillBatchPanel.tsx)` · `DistillBatchPanel` · 提示/标题：`规则模式`、`当前未配置可用的 AI 模型，批量整理将使用规则模板引擎（非真实 AI）。`、`如需真实 AI 整理，请先在 设置 中配置 AI 模型。`
- `[src/renderer/components/distill/DistillBatchPanel.tsx](/Volumes/White Atlas/03_Projects/AcMindV2.0/src/renderer/components/distill/DistillBatchPanel.tsx)` · `DistillBatchPanel` · 选择区：`待整理内容`、`请稍候`、`加载失败`、`请稍后重试`、`暂无可整理内容`、`先收集一些内容，再回来进行整理。`
- `[src/renderer/components/distill/DistillBatchPanel.tsx](/Volumes/White Atlas/03_Projects/AcMindV2.0/src/renderer/components/distill/DistillBatchPanel.tsx)` · `DistillBatchPanel` · 操作/选项：`全选`、`取消全选`、`默认蒸馏方案`、`已选「整理成可收藏笔记」：自动生成标题、摘要、分类、标签、价值判断和清理建议。`、`收起高级选项`、`展开高级选项`
- `[src/renderer/components/distill/DistillBatchPanel.tsx](/Volumes/White Atlas/03_Projects/AcMindV2.0/src/renderer/components/distill/DistillBatchPanel.tsx)` · `DistillBatchPanel` · 蒸馏项：`重命名`、`摘要`、`分类`、`打标签`、`价值评分`、`清理建议`
- `[src/renderer/components/distill/DistillBatchPanel.tsx](/Volumes/White Atlas/03_Projects/AcMindV2.0/src/renderer/components/distill/DistillBatchPanel.tsx)` · `DistillBatchPanel` · 整理层级：`本地轻量`、`云端标准`、`云端高级`
- `[src/renderer/components/distill/DistillBatchPanel.tsx](/Volumes/White Atlas/03_Projects/AcMindV2.0/src/renderer/components/distill/DistillBatchPanel.tsx)` · `DistillBatchPanel` · 进度/提交：`正在整理...`、`一键蒸馏 X 项`、`正在蒸馏...`
- `[src/renderer/components/distill/DistillReviewPanel.tsx](/Volumes/White Atlas/03_Projects/AcMindV2.0/src/renderer/components/distill/DistillReviewPanel.tsx)` · `DistillReviewPanel` · 加载/空态：`正在加载结果...`、`请稍候`、`加载结果失败`、`请稍后重试`、`暂无可审阅结果`、`先运行批量整理，生成可审阅的 AI 结果。`、`去一键蒸馏`
- `[src/renderer/components/distill/DistillReviewPanel.tsx](/Volumes/White Atlas/03_Projects/AcMindV2.0/src/renderer/components/distill/DistillReviewPanel.tsx)` · `DistillReviewPanel` · 操作反馈：`保存编辑失败，请稍后重试。`、`接受失败，请稍后重试。`、`已写入 Obsidian。`、`写入 Obsidian 失败，请先检查知识库设置。`
- `[src/renderer/components/distill/DistillReviewPanel.tsx](/Volumes/White Atlas/03_Projects/AcMindV2.0/src/renderer/components/distill/DistillReviewPanel.tsx)` · `DistillReviewPanel` · 编辑表单：`标题`、`摘要`、`分类`、`标签，用英文逗号分隔`、`正文 Markdown（不含 frontmatter）`、`取消`、`保存`
- `[src/renderer/components/distill/DistillReviewPanel.tsx](/Volumes/White Atlas/03_Projects/AcMindV2.0/src/renderer/components/distill/DistillReviewPanel.tsx)` · `DistillReviewPanel` · 原文/结果：`原文`、`（暂无预览内容）`、`正在加载原文...`、`整理结果`
- `[src/renderer/components/distill/DistillResultCard.tsx](/Volumes/White Atlas/03_Projects/AcMindV2.0/src/renderer/components/distill/DistillResultCard.tsx)` · `DistillResultCard` · 卡片信息：`来源：`、`价值评分`、`清理：`、`保留`、`合并`、`丢弃`
- `[src/renderer/components/distill/DistillResultCard.tsx](/Volumes/White Atlas/03_Projects/AcMindV2.0/src/renderer/components/distill/DistillResultCard.tsx)` · `DistillResultCard` · 操作按钮：`拒绝`、`编辑`、`接受`、`接受并写入 Obsidian`
- `[src/renderer/pages/edit/EditPage.tsx](/Volumes/White Atlas/03_Projects/AcMindV2.0/src/renderer/pages/edit/EditPage.tsx)` · `EditPage` · 错误/空态：`未找到该碎片或源条目`、`加载碎片失败`、`没有可保存的蒸馏结果`、`请先完成蒸馏并审阅`、`写入路径未设置，请先在设置中配置 Obsidian Vault 路径`
- `[src/renderer/pages/edit/EditPage.tsx](/Volumes/White Atlas/03_Projects/AcMindV2.0/src/renderer/pages/edit/EditPage.tsx)` · `EditPage` · 操作：`蒸馏任务已提交`、`内容已保存`、`审阅结果已保存`、`保存失败`、`没有可保存的蒸馏结果`
- `[src/renderer/pages/edit/EditPage.tsx](/Volumes/White Atlas/03_Projects/AcMindV2.0/src/renderer/pages/edit/EditPage.tsx)` · `EditPage` · 导出：`已写入 Obsidian: ...`、`请先完成蒸馏并审阅`、`写入路径未设置，请先在设置中配置 Obsidian Vault 路径`

## 资料库

- `[src/renderer/pages/search/index.tsx](/Volumes/White Atlas/03_Projects/AcMindV2.0/src/renderer/pages/search/index.tsx)` · `SearchPage` · 页面标题/副标题：`知识检索`、`搜索`、`搜索收集内容、整理结果、标签和导出记录。`
- `[src/renderer/pages/search/index.tsx](/Volumes/White Atlas/03_Projects/AcMindV2.0/src/renderer/pages/search/index.tsx)` · `SearchPage` · 操作：`重建索引`、`重建中...`
- `[src/renderer/pages/search/index.tsx](/Volumes/White Atlas/03_Projects/AcMindV2.0/src/renderer/pages/search/index.tsx)` · `SearchPage` · 索引状态：`已索引 X 条`、`索引为空`、`索引未初始化`
- `[src/renderer/pages/search/index.tsx](/Volumes/White Atlas/03_Projects/AcMindV2.0/src/renderer/pages/search/index.tsx)` · `SearchPage` · 搜索入口：`搜索入口`、`输入关键词后回车开始检索。`、`输入关键词搜索知识库...`
- `[src/renderer/pages/search/index.tsx](/Volumes/White Atlas/03_Projects/AcMindV2.0/src/renderer/pages/search/index.tsx)` · `SearchPage` · 结果区：`搜索结果`、`正在搜索知识库内容。`、`找到 X 条结果。`、`等待输入关键词。`
- `[src/renderer/pages/search/index.tsx](/Volumes/White Atlas/03_Projects/AcMindV2.0/src/renderer/pages/search/index.tsx)` · `SearchPage` · 空态/加载：`搜索知识库`、`输入关键词，搜索收集内容、整理结果、标签和导出记录。`、`正在搜索知识库`、`正在读取全文索引并匹配结果。`、`未找到相关结果`、`尝试更换关键词，或重建索引后重试。`
- `[src/renderer/components/search/SearchResultCard.tsx](/Volumes/White Atlas/03_Projects/AcMindV2.0/src/renderer/components/search/SearchResultCard.tsx)` · `SearchResultCard` · 类型/来源 badge：`源项目`、`蒸馏输出`、`向量`、`关键词`、`混合`
- `[src/renderer/components/search/SearchResultCard.tsx](/Volumes/White Atlas/03_Projects/AcMindV2.0/src/renderer/components/search/SearchResultCard.tsx)` · `SearchResultCard` · 相对时间：`刚刚`、`昨天`、`X 分钟前`、`X 小时前`、`X 天前`
- `[src/renderer/pages/import/ImportPage.tsx](/Volumes/White Atlas/03_Projects/AcMindV2.0/src/renderer/pages/import/ImportPage.tsx)` · `ImportPage` · 页面标题/副标题：`知识输出`、`导出记录`、`查看已导出的 Markdown 文件、来源内容和 Obsidian 写入位置。`
- `[src/renderer/pages/import/ImportPage.tsx](/Volumes/White Atlas/03_Projects/AcMindV2.0/src/renderer/pages/import/ImportPage.tsx)` · `ImportPage` · 筛选：`筛选`、`按时间、来源和状态查看已写入结果。`、`全部`、`今日`、`本周`、`文本`、`截图`、`网页`、`失败`
- `[src/renderer/pages/import/ImportPage.tsx](/Volumes/White Atlas/03_Projects/AcMindV2.0/src/renderer/pages/import/ImportPage.tsx)` · `ImportPage` · 操作/反馈：`刷新`、`无法打开文件`、`打开失败: ...`、`重试失败: ...`、`显示失败: ...`、`正在重新写入 Obsidian`
- `[src/renderer/pages/import/ImportPage.tsx](/Volumes/White Atlas/03_Projects/AcMindV2.0/src/renderer/pages/import/ImportPage.tsx)` · `ImportPage` · 空态/加载：`导出记录加载失败`、`请稍后重试，或检查 Obsidian 设置。`、`正在加载写入结果`、`正在读取 Obsidian 写入记录和来源链路。`、`还没有导出记录`、`完成 AI 整理并确认导出后，Markdown 文件会出现在这里。`、`去收集箱`
- `[src/renderer/components/export/ResultCard.tsx](/Volumes/White Atlas/03_Projects/AcMindV2.0/src/renderer/components/export/ResultCard.tsx)` · `ResultCard` · 状态：`已进入 Obsidian`、`写入失败`、`文件冲突`
- `[src/renderer/components/export/ResultCard.tsx](/Volumes/White Atlas/03_Projects/AcMindV2.0/src/renderer/components/export/ResultCard.tsx)` · `ResultCard` · 动作：`打开 Obsidian 文件`、`重试写入 Obsidian`、`重新写入`、`查看原文`、`重新生成`、`在文件管理器中显示`
- `[src/renderer/components/export/ExportHistory.tsx](/Volumes/White Atlas/03_Projects/AcMindV2.0/src/renderer/components/export/ExportHistory.tsx)` · `ExportHistory` · 空态/状态：`正在加载历史...`、`加载历史失败：...`、`暂无写入历史`、`成功写入 Obsidian 的内容会在这里显示。`
- `[src/renderer/components/export/ExportHistory.tsx](/Volumes/White Atlas/03_Projects/AcMindV2.0/src/renderer/components/export/ExportHistory.tsx)` · `ExportHistory` · 行操作：`在 Obsidian 中打开`、`重试写入`
- `[src/renderer/components/export/VaultConfigPanel.tsx](/Volumes/White Atlas/03_Projects/AcMindV2.0/src/renderer/components/export/VaultConfigPanel.tsx)` · `VaultConfigPanel` · 设置：`知识库路径`、`选择或输入知识库路径`、`默认文件夹`、`AcMind`、`路径规则`、`分类 / 日期`、`分类 / 标题`、`平铺`、`冲突策略`、`重命名`、`跳过`、`覆盖`
- `[src/renderer/components/export/VaultConfigPanel.tsx](/Volumes/White Atlas/03_Projects/AcMindV2.0/src/renderer/components/export/VaultConfigPanel.tsx)` · `VaultConfigPanel` · 开关/按钮：`自动 frontmatter`、`写入时自动补充 YAML frontmatter`、`选择`、`校验路径`、`正在校验...`、`保存配置`、`保存中...`
- `[src/renderer/components/export/VaultConfigPanel.tsx](/Volumes/White Atlas/03_Projects/AcMindV2.0/src/renderer/components/export/VaultConfigPanel.tsx)` · `VaultConfigPanel` · 错误/加载：`正在加载知识库配置...`、`加载知识库配置失败。`、`校验失败`
- `[src/renderer/pages/history/ProcessingHistoryPage.tsx](/Volumes/White Atlas/03_Projects/AcMindV2.0/src/renderer/pages/history/ProcessingHistoryPage.tsx)` · `ProcessingHistoryPage` · 页面标题/副标题：`处理历史`、`追踪自动知识流的执行记录`
- `[src/renderer/pages/history/ProcessingHistoryPage.tsx](/Volumes/White Atlas/03_Projects/AcMindV2.0/src/renderer/pages/history/ProcessingHistoryPage.tsx)` · `ProcessingHistoryPage` · 筛选：`筛选`、`按状态和时间范围查看处理记录。`、`全部`、`已进入 Obsidian`、`正在整理`、`失败`、`需要处理`、`今日`、`本周`
- `[src/renderer/pages/history/ProcessingHistoryPage.tsx](/Volumes/White Atlas/03_Projects/AcMindV2.0/src/renderer/pages/history/ProcessingHistoryPage.tsx)` · `ProcessingHistoryPage` · 操作：`刷新`、`打开文件`、`查看原文`、`查看错误`、`重试`、`重新生成`、`重新生成中...`、`手动回填`、`回填中...`、`重新提交 VK`
- `[src/renderer/pages/history/ProcessingHistoryPage.tsx](/Volumes/White Atlas/03_Projects/AcMindV2.0/src/renderer/pages/history/ProcessingHistoryPage.tsx)` · `ProcessingHistoryPage` · 展开信息：`详情`、`收起`、`内容 ID`、`Original ID`、`来源类型`、`来源应用`、`收集时间`、`处理时间`、`导出时间`、`输出路径`、`重试次数`、`错误数量`、`最近错误`
- `[src/renderer/pages/history/ProcessingHistoryPage.tsx](/Volumes/White Atlas/03_Projects/AcMindV2.0/src/renderer/pages/history/ProcessingHistoryPage.tsx)` · `ProcessingHistoryPage` · 模型/VK：`模型调用信息`、`模型层级`、`Provider`、`模型名称`、`Prompt Profile`、`调用状态`、`质量评分`、`降级处理`、`VaultKeeper 处理信息`、`Job ID`、`任务类型`、`处理状态`、`提交时间`、`完成时间`、`错误信息`、`关联错误记录`
- `[src/renderer/pages/errors/ErrorReviewPage.tsx](/Volumes/White Atlas/03_Projects/AcMindV2.0/src/renderer/pages/errors/ErrorReviewPage.tsx)` · `ErrorReviewPage` · 错误类型：`捕获失败`、`处理失败`、`导出失败`、`权限不足`、`冲突待处理`、`模板缺失`、`仓库未配置`、`模型不可用`、`VaultKeeper 不可用`、`外部任务失败`、`外部结果无效`、`结果回填失败`、`未知错误`
- `[src/renderer/pages/errors/ErrorReviewPage.tsx](/Volumes/White Atlas/03_Projects/AcMindV2.0/src/renderer/pages/errors/ErrorReviewPage.tsx)` · `ErrorReviewPage` · 阶段/状态：`内容捕获`、`剪贴板捕获`、`管道捕获`、`自动整理`、`管道导出`、`重试导出`、`AI 蒸馏`、`Obsidian 导出`、`批量导出`、`待处理`、`已解决`、`已忽略`
- `[src/renderer/pages/errors/ErrorReviewPage.tsx](/Volumes/White Atlas/03_Projects/AcMindV2.0/src/renderer/pages/errors/ErrorReviewPage.tsx)` · `ErrorReviewPage` · 动作：`重试整理`、`重试写入`、`去设置权限`、`处理冲突`、`检查模型设置`、`检查模板包`、`重试捕获`、`配置仓库`、`查看详情`
- `[src/renderer/pages/errors/ErrorReviewPage.tsx](/Volumes/White Atlas/03_Projects/AcMindV2.0/src/renderer/pages/errors/ErrorReviewPage.tsx)` · `ErrorReviewPage` · 卡片状态：`可重试`、`已重试 X 次`、`标记为已解决`、`忽略此错误`、`详情`、`重试中...`

## AI

- `[src/renderer/pages/distill/DistillPage.tsx](/Volumes/White Atlas/03_Projects/AcMindV2.0/src/renderer/pages/distill/DistillPage.tsx)` · `DistillPage` · 可见 AI 工作区入口已列于“整理”页；这里补充其独立页签文案：`蒸馏工作台`、`批量蒸馏`
- `[src/renderer/pages/settings/components/AddProviderDialog.tsx](/Volumes/White Atlas/03_Projects/AcMindV2.0/src/renderer/pages/settings/components/AddProviderDialog.tsx)` · `AddProviderDialog` · 标题/按钮：`新增模型来源`、`编辑模型来源`、`取消`、`新增`、`更新`、`保存中...`
- `[src/renderer/pages/settings/components/AddProviderDialog.tsx](/Volumes/White Atlas/03_Projects/AcMindV2.0/src/renderer/pages/settings/components/AddProviderDialog.tsx)` · `AddProviderDialog` · 表单：`名称 *`、`类型 *`、`整理方式 *`、`接口地址 *`、`API 密钥 (可选)`、`模型 ID *`
- `[src/renderer/pages/settings/components/AddProviderDialog.tsx](/Volumes/White Atlas/03_Projects/AcMindV2.0/src/renderer/pages/settings/components/AddProviderDialog.tsx)` · `AddProviderDialog` · 选项/占位符：`Ollama（本地）`、`OpenAI 兼容（云端）`、`本地轻量`、`云端标准`、`云端高级`、`http://localhost:11434`、`本地模型可留空`、`sk-...`、`例如：本地模型`、`例如：llama3 / gpt-4o-mini`
- `[src/renderer/pages/settings/components/AddProviderDialog.tsx](/Volumes/White Atlas/03_Projects/AcMindV2.0/src/renderer/pages/settings/components/AddProviderDialog.tsx)` · `AddProviderDialog` · 校验错误：`名称不能为空`、`接口地址不能为空`、`模型 ID 不能为空`、`云端模型需要填写 API 密钥`
- `[src/renderer/pages/settings/components/ProviderCard.tsx](/Volumes/White Atlas/03_Projects/AcMindV2.0/src/renderer/pages/settings/components/ProviderCard.tsx)` · `ProviderCard` · 信息：`本地`、`云端`、`已停用`、`已启用`、`模型`、`接口地址`
- `[src/renderer/pages/settings/components/ProviderCard.tsx](/Volumes/White Atlas/03_Projects/AcMindV2.0/src/renderer/pages/settings/components/ProviderCard.tsx)` · `ProviderCard` · 操作：`停用`、`启用`、`测试连接`、`编辑`、`删除`
- `[src/renderer/pages/settings/components/AdvancedControlPanel.tsx](/Volumes/White Atlas/03_Projects/AcMindV2.0/src/renderer/pages/settings/components/AdvancedControlPanel.tsx)` · `AdvancedControlPanel` · 模块标题：`自动化开关`、`Vault 状态`、`模板包状态`、`模型状态`、`VaultKeeper 状态`、`最近错误`、`快捷入口`、`开发者日志`
- `[src/renderer/pages/settings/components/AdvancedControlPanel.tsx](/Volumes/White Atlas/03_Projects/AcMindV2.0/src/renderer/pages/settings/components/AdvancedControlPanel.tsx)` · `AdvancedControlPanel` · 开关：`自动捕获`、`复制文本后自动放入收集箱`、`自动整理`、`捕获后自动提交 AI 蒸馏处理`、`自动写入 Obsidian`、`整理完成后自动写入知识库`
- `[src/renderer/pages/settings/components/AdvancedControlPanel.tsx](/Volumes/White Atlas/03_Projects/AcMindV2.0/src/renderer/pages/settings/components/AdvancedControlPanel.tsx)` · `AdvancedControlPanel` · 状态/校验：`检查中...`、`验证通过`、`验证未通过`、`未配置仓库路径`、`检查失败`、`已加载`、`未加载（使用内置默认值）`、`可用`、`不可达`、`未知`、`未启用`
- `[src/renderer/pages/settings/components/AdvancedControlPanel.tsx](/Volumes/White Atlas/03_Projects/AcMindV2.0/src/renderer/pages/settings/components/AdvancedControlPanel.tsx)` · `AdvancedControlPanel` · 字段：`仓库路径`、`未配置`、`配置模型`、`实际模型`、`连接状态`、`模型状态`、`回退原因`、`最近错误`、`检查时间`、`模板包路径`、`Profile 数量`、`模板数量`、`Schema 版本`
- `[src/renderer/pages/settings/components/AdvancedControlPanel.tsx](/Volumes/White Atlas/03_Projects/AcMindV2.0/src/renderer/pages/settings/components/AdvancedControlPanel.tsx)` · `AdvancedControlPanel` · VaultKeeper：`连接方式`、`HTTP`、`STDIO`、`未连接`、`支持任务类型`、`无`、`错误信息`、`失败任务`、`刷新 VaultKeeper 状态`、`重试`
- `[src/renderer/pages/settings/components/AdvancedControlPanel.tsx](/Volumes/White Atlas/03_Projects/AcMindV2.0/src/renderer/pages/settings/components/AdvancedControlPanel.tsx)` · `AdvancedControlPanel` · 最近错误/快捷入口：`没有待处理的错误，系统运行正常。`、`查看全部错误`、`处理历史`、`查看自动知识流的完整执行记录`、`错误回看`、`查看和处理自动化流程中的失败内容`、`刷新状态`、`重新检查 Vault、模板包和模型状态`
- `[src/renderer/pages/settings/components/AdvancedControlPanel.tsx](/Volumes/White Atlas/03_Projects/AcMindV2.0/src/renderer/pages/settings/components/AdvancedControlPanel.tsx)` · `AdvancedControlPanel` · 日志入口：`收起日志`、`展开日志设置`、`日志级别可在「高级 → 错误日志」中调整。`、`当前级别：`

## 设置

- `[src/renderer/pages/settings/SettingsPage.tsx](/Volumes/White Atlas/03_Projects/AcMindV2.0/src/renderer/pages/settings/SettingsPage.tsx)` · `SettingsPage` · 页面标题/副标题：`设置`、`管理应用偏好和模型配置`
- `[src/renderer/pages/settings/SettingsPage.tsx](/Volumes/White Atlas/03_Projects/AcMindV2.0/src/renderer/pages/settings/SettingsPage.tsx)` · `SettingsPage` · 保存状态：`已保存`、`设置已自动保存`、`所有更改已成功保存到本地`、`保存中...`、`保存设置`
- `[src/renderer/pages/settings/SettingsPage.tsx](/Volumes/White Atlas/03_Projects/AcMindV2.0/src/renderer/pages/settings/SettingsPage.tsx)` · `SettingsPage` · 分组：`基础设置`、`知识库`、`AI`、`捕获`、`高级`
- `[src/renderer/pages/settings/SettingsPage.tsx](/Volumes/White Atlas/03_Projects/AcMindV2.0/src/renderer/pages/settings/SettingsPage.tsx)` · `SettingsPage` · 类目：`通用`、`外观`、`隐私与本地优先`、`Obsidian`、`路径与存储`、`导出规则`、`模型管理`、`默认层级与回退策略`、`捕获入口`、`日志`、`数据维护`、`开发者选项`
- `[src/renderer/pages/settings/SettingsPage.tsx](/Volumes/White Atlas/03_Projects/AcMindV2.0/src/renderer/pages/settings/SettingsPage.tsx)` · `SettingsPage` · 通用设置说明：`启动偏好与捕获行为。`、`应用启动方式。`、`内容捕获的触发与处理方式。`、`成功捕获时弹出 Toast。`、`捕获后自动提交蒸馏。`、`整理完成后自动写入知识库。`
- `[src/renderer/pages/settings/SettingsPage.tsx](/Volumes/White Atlas/03_Projects/AcMindV2.0/src/renderer/pages/settings/SettingsPage.tsx)` · `SettingsPage` · 开关：`开机启动`、`最小化到菜单栏`、`后台监听剪贴板`、`自动捕获`、`捕获后提示`、`自动 AI 处理`、`自动导出到 Obsidian`
- `[src/renderer/pages/settings/SettingsPage.tsx](/Volumes/White Atlas/03_Projects/AcMindV2.0/src/renderer/pages/settings/SettingsPage.tsx)` · `SettingsPage` · AI 模型页：`AI 模型`、`管理 AI 模型来源，启停状态实时同步。`、`新增模型来源`、`模型来源`、`与 AI Console 共享同一份配置。`、`正在加载模型来源...`、`还没有模型来源`、`添加第一个来源`
- `[src/renderer/pages/settings/SettingsPage.tsx](/Volumes/White Atlas/03_Projects/AcMindV2.0/src/renderer/pages/settings/SettingsPage.tsx)` · `SettingsPage` · 默认层级页：`默认模型层级`、`新任务默认使用的模型强度。`、`默认处理策略`、`本地轻量，隐私优先`、`云端标准，效果均衡`、`云端强力，复杂内容优先`、`模型不可用时自动尝试可用层级。`
- `[src/renderer/pages/settings/SettingsPage.tsx](/Volumes/White Atlas/03_Projects/AcMindV2.0/src/renderer/pages/settings/SettingsPage.tsx)` · `SettingsPage` · 路径与存储：`本地数据目录`、`AcMind 所有数据的存储位置。`、`当前路径`、`打开`、`更改路径`、`扫描行为`、`剪贴板监听的频率与范围。`、`轮询间隔`、`剪贴板检查频率（毫秒）。`、`扫描范围`、`全部应用`、`指定应用`、`扫描范围为"指定应用"时生效。`
- `[src/renderer/pages/settings/SettingsPage.tsx](/Volumes/White Atlas/03_Projects/AcMindV2.0/src/renderer/pages/settings/SettingsPage.tsx)` · `SettingsPage` · Obsidian：`Vault 路径`、`选择并校验 Obsidian 知识库目录。`、`知识库路径`、`选择`、`校验`、`写入位置`、`笔记在知识库中的存放位置。`、`默认文件夹`、`文件规则`、`文件命名、冲突与元数据策略。`、`路径规则`、`Markdown 文件的落盘路径。`、`冲突策略`、`文件名冲突时的处理方式。`、`自动 frontmatter`、`导出时自动生成 YAML frontmatter。`
- `[src/renderer/pages/settings/SettingsPage.tsx](/Volumes/White Atlas/03_Projects/AcMindV2.0/src/renderer/pages/settings/SettingsPage.tsx)` · `SettingsPage` · 导出规则（只读）：`导出规则`、`只读预览 · 主要配置在「Obsidian」中完成`、`如需修改，请前往「知识库 → Obsidian」。`
- `[src/renderer/pages/settings/SettingsPage.tsx](/Volumes/White Atlas/03_Projects/AcMindV2.0/src/renderer/pages/settings/SettingsPage.tsx)` · `SettingsPage` · 主题与外观：`外观`、`主题与外观偏好。`、`主题模式`、`暂未开放切换。`、`暂未开放 · 跟随系统`、`桌面灵感胶囊`、`屏幕边缘的快捷捕获入口。详细配置在「捕获入口」。`
- `[src/renderer/pages/settings/SettingsPage.tsx](/Volumes/White Atlas/03_Projects/AcMindV2.0/src/renderer/pages/settings/SettingsPage.tsx)` · `SettingsPage` · 隐私页：`macOS 权限状态。`、`暂无权限信息`、`刷新后会显示屏幕录制、辅助功能和磁盘访问状态。`
- `[src/renderer/pages/settings/SettingsPage.tsx](/Volumes/White Atlas/03_Projects/AcMindV2.0/src/renderer/pages/settings/SettingsPage.tsx)` · `SettingsPage` · 日志页：`日志级别与运行时配置。`、`控制日志输出的详细程度。`、`日志级别`、`修改后立即生效。`、`设置变更会直接写入本地，无需手动保存。`
- `[src/renderer/pages/settings/SettingsPage.tsx](/Volumes/White Atlas/03_Projects/AcMindV2.0/src/renderer/pages/settings/SettingsPage.tsx)` · `SettingsPage` · 高级页：`数据库维护和备份功能正在开发中。`、`开发中`、`后续版本提供。`、`开发者工具和调试选项正在开发中。`、`后续版本提供。当前可在 AI 控制台查看运行时信息。`
- `[src/renderer/pages/settings/SettingsPage.tsx](/Volumes/White Atlas/03_Projects/AcMindV2.0/src/renderer/pages/settings/SettingsPage.tsx)` · `SettingsPage` · 其他设置值：`开机启动`、`最小化到菜单栏`、`本地优先`、`已配置`、`未配置`、`即将推出`
- `[src/renderer/pages/onboarding/OnboardingPage.tsx](/Volumes/White Atlas/03_Projects/AcMindV2.0/src/renderer/pages/onboarding/OnboardingPage.tsx)` · `OnboardingPage` · 步骤：`开始`、`权限`、`模型`、`知识库`、`试运行`、`完成`
- `[src/renderer/pages/onboarding/OnboardingPage.tsx](/Volumes/White Atlas/03_Projects/AcMindV2.0/src/renderer/pages/onboarding/OnboardingPage.tsx)` · `OnboardingPage` · 首屏：`把信息丢进来，剩下交给 AcMind`、`这次只配置最少的东西：权限、模型、知识库输出位置。完成后，你就可以复制内容、截图，然后一键整理成可收藏笔记。`
- `[src/renderer/pages/onboarding/OnboardingPage.tsx](/Volumes/White Atlas/03_Projects/AcMindV2.0/src/renderer/pages/onboarding/OnboardingPage.tsx)` · `OnboardingPage` · 卡片：`丢进来`、`一键整理`、`送进知识库`
- `[src/renderer/pages/onboarding/OnboardingPage.tsx](/Volumes/White Atlas/03_Projects/AcMindV2.0/src/renderer/pages/onboarding/OnboardingPage.tsx)` · `OnboardingPage` · 权限页：`确认 AcMind 能捕获内容`、`剪贴板用于自动收集文本，屏幕录制用于截图。缺权限时可以稍后补，但首次体验会不完整。`、`刷新权限`、`继续`、`暂无权限回报`、`可以先继续，之后在设置里重新检查。`、`有权限需要处理。你可以先继续，之后在「设置」里打开系统设置。`
- `[src/renderer/pages/onboarding/OnboardingPage.tsx](/Volumes/White Atlas/03_Projects/AcMindV2.0/src/renderer/pages/onboarding/OnboardingPage.tsx)` · `OnboardingPage` · AI 页：`选择 AcMind 用哪种方式整理内容`、`新手推荐本地 Ollama。没有本地模型时，也可以先保存默认配置，后续在设置里更换。`、`本地 Ollama`、`云端兼容 API`、`隐私最好，适合默认整理。`、`效果通常更强，需要 API 密钥。`、`已安装模型`、`刷新模型`、`本地模式会自动使用已经安装好的 Ollama 模型，不需要再填写服务地址。`
- `[src/renderer/pages/onboarding/OnboardingPage.tsx](/Volumes/White Atlas/03_Projects/AcMindV2.0/src/renderer/pages/onboarding/OnboardingPage.tsx)` · `OnboardingPage` · 知识库页：`选择笔记最终送到哪里`、`选择你的知识库文件夹。AcMind 会默认写入收件箱文件夹，避免打乱现有笔记结构。`、`知识库路径`、`选择或粘贴知识库文件夹路径`、`默认输出规则`、`写入收件箱，自动带上标题、摘要、标签和基础信息。`
- `[src/renderer/pages/onboarding/OnboardingPage.tsx](/Volumes/White Atlas/03_Projects/AcMindV2.0/src/renderer/pages/onboarding/OnboardingPage.tsx)` · `OnboardingPage` · 试运行页：`生成一条测试笔记`、`这会把一条测试内容放进收件箱。完成后你可以在首页点击一键整理，再送入知识库。`、`生成测试笔记`、`写入入口`、`中文内容`、`下一步动作`、`如果按钮提示接口未加载，请完全退出并重新打开 AcMind，再重试一次。`
- `[src/renderer/pages/onboarding/OnboardingPage.tsx](/Volumes/White Atlas/03_Projects/AcMindV2.0/src/renderer/pages/onboarding/OnboardingPage.tsx)` · `OnboardingPage` · 完成页：`现在可以开始蒸馏你的信息了`、`下一步进入首页：复制文本或截图，点一键整理，确认后送进知识库。`、`进入 AcMind`
- `[src/renderer/pages/onboarding/OnboardingPage.tsx](/Volumes/White Atlas/03_Projects/AcMindV2.0/src/renderer/pages/onboarding/OnboardingPage.tsx)` · `OnboardingPage` · 侧栏：`AcMind`、`本地知识整理器`、`跳过设置`、`跳过后会直接进入 AcMind，后续可以在设置里继续补全。`、`取消`、`确认跳过`、`跳过中...`
- `[src/renderer/pages/onboarding/OnboardingPage.tsx](/Volumes/White Atlas/03_Projects/AcMindV2.0/src/renderer/pages/onboarding/OnboardingPage.tsx)` · `OnboardingPage` · 状态：`准备就绪`、`权限状态已刷新`、`模型来源已保存`、`知识库输出位置已保存`、`测试笔记已放入收件箱，可以继续一键蒸馏`、`布置已完成`

## 全局组件

- `[src/renderer/App.tsx](/Volumes/White Atlas/03_Projects/AcMindV2.0/src/renderer/App.tsx)` · `App` · 启动态：`正在启动 AcMind`、`正在读取本地设置、工作区和导航状态。`
- `[src/renderer/App.tsx](/Volumes/White Atlas/03_Projects/AcMindV2.0/src/renderer/App.tsx)` · `App` · 路由不可用：`页面不可用`、`当前路由没有对应页面，请返回主工作区。`
- `[src/renderer/components/layout/TopBar.tsx](/Volumes/White Atlas/03_Projects/AcMindV2.0/src/renderer/components/layout/TopBar.tsx)` · `TopBar` · 导航标题：`工作台`、`收集箱`、`AI 整理`、`导出记录`、`搜索`、`设置`、`快速捕获`、`二级整理`、`错误回看`、`处理历史`、`AcMind`
- `[src/renderer/components/layout/TopBar.tsx](/Volumes/White Atlas/03_Projects/AcMindV2.0/src/renderer/components/layout/TopBar.tsx)` · `TopBar` · 搜索/设置：`搜索内容、标签、来源...`、`⌘K`、`菜单`、`设置`、`个人空间`、`设置你的空间`、`当前：本地轻量`、`未配置模型`
- `[src/renderer/components/layout/Sidebar.tsx](/Volumes/White Atlas/03_Projects/AcMindV2.0/src/renderer/components/layout/Sidebar.tsx)` · `Sidebar` · 导航：`工作台`、`收集箱`、`AI 整理`、`导出记录`、`搜索`、`设置`、`AcMind`
- `[src/renderer/components/layout/Sidebar.tsx](/Volumes/White Atlas/03_Projects/AcMindV2.0/src/renderer/components/layout/Sidebar.tsx)` · `Sidebar` · 个人卡片：`设置你的空间`、`我的第二大脑`、`点击完成初始化`、`本地优先`、`已配置`、`未配置`
- `[src/renderer/components/layout/RightInspector.tsx](/Volumes/White Atlas/03_Projects/AcMindV2.0/src/renderer/components/layout/RightInspector.tsx)` · `RightInspector` · 面板标题：`详情面板`、`选择一条内容查看详情`、`当前内容将写入 知识库`、`左侧内容队列中的记录会在这里展开`
- `[src/renderer/components/layout/RightInspector.tsx](/Volumes/White Atlas/03_Projects/AcMindV2.0/src/renderer/components/layout/RightInspector.tsx)` · `RightInspector` · 选项卡：`详情`、`AI 处理结果`、`元数据`、`日志`
- `[src/renderer/components/layout/RightInspector.tsx](/Volumes/White Atlas/03_Projects/AcMindV2.0/src/renderer/components/layout/RightInspector.tsx)` · `RightInspector` · 详情页：`内容预览`、`图片内容预览`、`信息`、`AI 建议`、`可能标题`、`推荐标签`、`快捷操作`、`去整理`、`整理后输出`、`打开来源`、`复制摘要`、`输出信息`
- `[src/renderer/components/layout/RightInspector.tsx](/Volumes/White Atlas/03_Projects/AcMindV2.0/src/renderer/components/layout/RightInspector.tsx)` · `RightInspector` · 结果页：`AI 处理结果`、`摘要`、`状态`、`结果会在二级整理页中继续完善`
- `[src/renderer/components/layout/RightInspector.tsx](/Volumes/White Atlas/03_Projects/AcMindV2.0/src/renderer/components/layout/RightInspector.tsx)` · `RightInspector` · 元数据/日志：`元数据`、`日志`、`暂无日志记录。`
- `[src/renderer/components/layout/PersonalSpacePanel.tsx](/Volumes/White Atlas/03_Projects/AcMindV2.0/src/renderer/components/layout/PersonalSpacePanel.tsx)` · `PersonalSpacePanel` · 标题/副标题：`设置你的空间`、`完成个人资料、工作空间和 Obsidian 连接`
- `[src/renderer/components/layout/PersonalSpacePanel.tsx](/Volumes/White Atlas/03_Projects/AcMindV2.0/src/renderer/components/layout/PersonalSpacePanel.tsx)` · `PersonalSpacePanel` · 个人资料：`个人资料`、`头像、名称和身份标签`、`头像将显示为姓名首字`、`点击后可上传图片或选择默认图标`、`更换头像`
- `[src/renderer/components/layout/PersonalSpacePanel.tsx](/Volumes/White Atlas/03_Projects/AcMindV2.0/src/renderer/components/layout/PersonalSpacePanel.tsx)` · `PersonalSpacePanel` · 字段：`显示名称`、`输入你的名称`、`个人简介`、`一句话介绍自己`、`工作空间名称`、`我的第二大脑`、`角色标签`、`添加标签`
- `[src/renderer/components/layout/PersonalSpacePanel.tsx](/Volumes/White Atlas/03_Projects/AcMindV2.0/src/renderer/components/layout/PersonalSpacePanel.tsx)` · `PersonalSpacePanel` · 工作空间：`工作空间`、`数据目录、Obsidian Vault 和 AI 层级`、`数据目录`
- `[src/renderer/components/layout/PersonalSpacePanel.tsx](/Volumes/White Atlas/03_Projects/AcMindV2.0/src/renderer/components/layout/PersonalSpacePanel.tsx)` · `PersonalSpacePanel` · Toast：`已保存`、`保存失败`、`数据目录已更新`、`选择目录失败`、`无法打开目录`、`打开目录失败`、`Vault 路径已更新`、`选择 Vault 失败`、`请先选择目录`、`写入测试通过`、`写入测试失败`
- `[src/renderer/components/shared/ToastViewport.tsx](/Volumes/White Atlas/03_Projects/AcMindV2.0/src/renderer/components/shared/ToastViewport.tsx)` · `ToastProvider` · 默认 toast 类型：`i`、`✓`、`!`、`✗`（图标字符）
- `[src/renderer/components/shared/EmptyState.tsx](/Volumes/White Atlas/03_Projects/AcMindV2.0/src/renderer/components/shared/EmptyState.tsx)` · `EmptyState` · 默认空态图标：`empty-inbox`
- `[src/renderer/design-system/components/index.tsx](/Volumes/White Atlas/03_Projects/AcMindV2.0/src/renderer/design-system/components/index.tsx)` · `SearchField` · 默认按钮/无障碍：`搜索`、`清除搜索内容`
- `[src/renderer/design-system/components/index.tsx](/Volumes/White Atlas/03_Projects/AcMindV2.0/src/renderer/design-system/components/index.tsx)` · `PageHeader` / `Section` / `EmptyState` / `LoadingState` / `ErrorState` · 文案容器：这些组件本身不写死业务文案，承载各页传入的标题、描述、错误原因和操作按钮。
- `[src/renderer/components/layout/BottomRuntimeBar.tsx](/Volumes/White Atlas/03_Projects/AcMindV2.0/src/renderer/components/layout/BottomRuntimeBar.tsx)` · `BottomRuntimeBar` · 底部状态：`数据目录`、`本地数据已保护`（该组件已废弃但仍有文案）
- `[src/renderer/components/layout/AppShell.tsx](/Volumes/White Atlas/03_Projects/AcMindV2.0/src/renderer/components/layout/AppShell.tsx)` · `AppShell` · 无固定文案，负责壳层布局与个人空间/侧栏状态

## 备注

- 已按可见 UI 文案做人工归类，像 `AcMind`、`工作台` 这类在多处重复出现的标题仅在首个相关位置展开。
- 如果你要，我可以继续把这份清单再细化成“逐文件 CSV 风格”版本，便于直接交给设计或本地化。
