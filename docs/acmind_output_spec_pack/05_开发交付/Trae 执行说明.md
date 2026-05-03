# AcMind 默认输出规范 - Trae 执行说明

## 1. 任务目标

请基于本规范包，实现 AcMind 默认输出系统。

核心目标：

- 模型只输出标准字段
- 系统根据 Format Profile 渲染 Markdown
- 用户可以在 Obsidian 中长期维护
- 后续支持按 vault 或 project 批量迁移

---

## 2. P0 必须完成

### 2.1 建立标准字段类型

建立 `AcMindStandardFields` 类型，至少包含：

- `schema_version`
- `title`
- `summary`
- `tags`
- `category`
- `body`
- `raw_content`
- `source`
- `captured_at`
- `project`
- `status`
- `confidence`

---

### 2.2 建立状态枚举

状态必须固定为：

```ts
collected
cleaned
reviewing
reviewed
exported
failed
```

不要让状态变成自由文本。

---

### 2.3 建立默认值生成逻辑

当字段缺失时，系统应填充默认值：

```json
{
  "schema_version": "0.2",
  "tags": [],
  "category": "未分类",
  "source": "manual",
  "project": "默认",
  "status": "collected",
  "confidence": 0.5
}
```

---

### 2.4 建立 MarkdownRenderer

输入：

```text
AcMindStandardFields + FormatProfile
```

输出：

```text
Markdown 字符串
```

注意：模型不能直接绕过 renderer 输出最终 Markdown。

---

### 2.5 建立默认 Format Profile

使用 `03_Format_Profile/acmind-default.profile.json` 作为默认 Profile。

---

### 2.6 支持导出 `.md` 文件

导出文件名规则：

```text
YYYY-MM-DD HH-mm - 标题.md
```

必须清洗文件名危险字符：

```text
/ \ : * ? " < > |
```

---

## 3. P1 应该完成

1. 增加字段合法性校验
2. 增加文件名清洗逻辑
3. 增加 `raw_content` 可选保留
4. 增加 Profile 配置结构
5. 增加导出预览
6. 增加错误提示和日志

---

## 4. P2 后续完成

1. 支持多个 Format Profile
2. 支持按 project 迁移
3. 支持按 vault 迁移
4. 支持迁移前备份
5. 支持迁移日志
6. 支持迁移回滚

---

## 5. 验收标准

### P0 验收

- 可以从标准字段生成 Markdown
- Markdown frontmatter 合法
- 文件可以在 Obsidian 中打开
- 标签格式正确
- 文件名安全
- 状态为固定枚举
- 缺失字段会填默认值

### P1 验收

- 错误字段会被拦截
- 用户可以预览导出结果
- raw_content 可以选择是否展示
- Profile 配置可以读取

### P2 验收

- 可以批量迁移 project
- 可以批量迁移 vault
- 迁移前有备份
- 迁移后有日志
- 可以回滚

---

## 6. 不要做的事

不要：

- 让模型直接写最终 Markdown
- 把分类写成多个
- 把状态写成自然语言
- 在没有备份的情况下批量覆盖旧文件
- 让 Format Profile 参与内容理解
- 把字段语义写死在模板里
