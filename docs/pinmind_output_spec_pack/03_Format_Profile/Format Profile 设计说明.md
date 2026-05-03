# PinMind Format Profile 设计说明

## 1. 什么是 Format Profile

Format Profile 是 PinMind 用来控制 Markdown 输出样式的一套配置。

它只负责“如何渲染”，不负责“内容是什么”。

标准字段层决定：

- 标题是什么
- 总结是什么
- 标签是什么
- 分类是什么
- 正文是什么

Format Profile 决定：

- frontmatter 如何写
- 标签如何渲染
- 日期如何显示
- 文件名如何生成
- 是否展示原始内容
- 正文标题如何拼接

---

## 2. 默认策略

默认只提供一个官方推荐 Profile：

```text
PinMind Default Markdown
```

普通用户不需要管理多个 Profile。

高级用户可以在设置中创建多个 Profile。

---

## 3. 可以配置的内容

Format Profile 可以配置：

- 文件命名规则
- frontmatter 字段映射
- 标签格式
- 日期格式
- 标题层级
- 总结显示方式
- 正文拼接方式
- 原始内容是否展示
- 属性区字段顺序
- 导出路径规则

---

## 4. 不应该配置的内容

Format Profile 不应该配置：

- 模型理解逻辑
- 内容总结逻辑
- 内容分类逻辑
- 标签生成逻辑
- 项目判断逻辑
- 来源判断逻辑
- 置信度计算逻辑
- 状态流转逻辑

这些属于标准字段层或系统流程层。

---

## 5. 默认 Profile 行为

默认 Profile 应该：

- 使用 YAML frontmatter
- 使用英文 key
- 使用 `YYYY-MM-DD HH:mm` 时间格式
- 使用 frontmatter 标签
- 正文前显示一句话总结
- 默认不展示 `raw_content`
- 文件名使用 `YYYY-MM-DD HH-mm - 标题.md`

---

## 6. 批量迁移原则

更换 Profile 时：

- 只重新渲染 Markdown
- 不改变标准字段
- 不改变内容语义
- 不覆盖用户手写内容
- 必须支持预览、备份和日志
