# AcMind Obsidian 兼容规则 v0.2

## 1. 基本原则

AcMind 导出的 Markdown 必须满足：

- Obsidian 可直接打开
- YAML frontmatter 合法
- 标签格式稳定
- 文件名安全
- 不依赖 AcMind 也能阅读
- 不依赖 AI 也能手动维护

---

## 2. frontmatter 规则

默认使用 YAML frontmatter。

推荐：

```yaml
---
schema_version: "0.2"
title: "示例标题"
summary: "一句话总结"
tags:
  - AcMind
  - Obsidian
category: "产品规范"
source: "manual"
captured_at: "2026-04-30 10:34"
project: "默认"
status: "collected"
confidence: 0.5
---
```

---

## 3. 标签规则

默认推荐使用 frontmatter 标签。

```yaml
tags:
  - AcMind
  - Obsidian
```

正文中不强制添加 `#标签`。

如果用户想在正文中加标签，也可以手动添加：

```markdown
#AcMind #Obsidian
```

但不要同时制造大量重复标签。

---

## 4. 双链规则

用户可以在正文中手动添加双链：

```markdown
[[AcMind]]
[[Obsidian]]
[[Markdown]]
```

模型可以建议双链，但不应该默认过度添加。

推荐原则：

- 核心概念可以加双链
- 临时词汇不要强行加双链
- 不要让一篇文档变成满屏链接

---

## 5. 文件名规则

推荐文件名：

```text
YYYY-MM-DD HH-mm - 标题.md
```

示例：

```text
2026-04-30 10-34 - AcMind 默认输出规范.md
```

文件名中必须清洗以下字符：

```text
/ \ : * ? " < > |
```

---

## 6. 正文结构规则

默认结构：

```markdown
> 一句话总结

# 标题

正文内容
```

如果保留原始内容，放在底部：

```markdown
---

## 原始内容

原始输入内容
```

---

## 7. 不推荐做法

不推荐：

- 在正文中重复大量 frontmatter 信息
- 每句话都加双链
- 每篇文档生成十几个标签
- 分类写成多层复杂路径
- 让模型直接输出最终 Markdown 并绕过字段层
