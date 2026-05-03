# 带原始内容 Markdown 模板

适合需要回溯原始输入、重新蒸馏、人工校对的场景。

```markdown
---
schema_version: "{{schema_version}}"
title: "{{title}}"
summary: "{{summary}}"
tags: {{tags}}
category: "{{category}}"
source: "{{source}}"
captured_at: "{{captured_at}}"
project: "{{project}}"
status: "{{status}}"
confidence: {{confidence}}
---

> {{summary}}

# {{title}}

{{body}}

---

## 原始内容

{{raw_content}}
```
