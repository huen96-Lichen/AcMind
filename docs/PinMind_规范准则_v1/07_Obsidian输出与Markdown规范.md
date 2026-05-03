# AcMind Obsidian 输出与 Markdown 规范 v1

## 1. 设计目标

AcMind 的核心价值之一，是把碎片信息沉淀到 Obsidian。

所以 Markdown 输出必须：

- 稳定
- 可读
- 可搜索
- 可双链
- 可长期保存
- 可被 AI 再次处理
- 不破坏 Obsidian 语法

## 2. 输出原则

必须遵守：

- 原文保留
- AI 整理结果单独生成
- 不覆盖旧文件
- frontmatter 稳定
- tags 稳定
- 标题清晰
- 来源可追踪
- 文件路径可控

## 3. 推荐输出模板

```md
---
title:
created:
updated:
source_type:
source_id:
status:
tags:
summary:
---

# 标题

## 摘要

## 正文整理

## 关键观点

## 可行动项

## 原始来源

## 关联链接
```

## 4. Frontmatter 字段

推荐字段：

```yaml
title: ""
created: "2026-04-27"
updated: "2026-04-27"
source_type: "clipboard"
source_id: ""
status: "distilled"
tags: []
summary: ""
```

## 5. 文件命名规范

建议默认命名：

```txt
YYYY-MM-DD_标题.md
```

例如：

```txt
2026-04-27_AcMind项目推进约束.md
```

如果重名：

```txt
2026-04-27_AcMind项目推进约束.md
2026-04-27_AcMind项目推进约束 - 2.md
2026-04-27_AcMind项目推进约束 - 3.md
```

禁止直接覆盖旧文件。

## 6. 目录建议

早期可以输出到：

```txt
99_Inbox/AcMind/
```

或：

```txt
99_未归纳/AcMind/
```

等稳定后再由 AI 或用户整理到正式目录。

## 7. 必须保护的 Obsidian 语法

不能破坏：

- YAML frontmatter
- `[[双链]]`
- `#标签`
- 代码块
- 表格
- 引用块
- 图片链接
- 本地附件路径
- Markdown 标题层级

## 8. 原文保留策略

建议保留两份：

1. AcMind 本地 data/sources 中保存原始内容
2. Markdown 文件中可以选择性保留“原始来源”摘要或全文

对于长文本，不一定要把全文塞进 Obsidian 正文，可以保留引用路径。

## 9. AI 输出必须可预览

流程必须是：

```txt
AI 生成 Markdown
↓
用户预览
↓
用户确认
↓
写入 Obsidian
```

禁止：

```txt
AI 生成后直接覆盖 Obsidian 文件
```

## 10. 输出成功反馈

输出成功后 UI 必须显示：

- 文件名
- 文件路径
- 输出时间
- 打开文件位置按钮
- 如果可能，提供在 Obsidian 中打开的入口

## 11. 输出失败反馈

输出失败必须显示用户能理解的信息：

```txt
导出失败：当前 Obsidian Vault 路径不存在，请重新选择路径。
```

同时日志记录技术细节。

## 12. Markdown 风格

建议：

- 一级标题只用一个
- 二级标题分区清楚
- 列表简洁
- 不要堆砌过长段落
- 关键观点独立列出
- 可行动项明确
- 保持 AI 可二次处理的结构
