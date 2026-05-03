# PinMind 默认输出规范包 v0.2

本规范包用于定义 PinMind 从「用户收集内容」到「导出 Obsidian Markdown」的默认输出体系。

## 核心目标

PinMind 的默认体验应该尽量简单：

- 用户负责收集
- 系统负责清洗、结构化、格式化和导出
- 用户最终在 Obsidian 中看到统一、直观、可批量维护的 Markdown 内容
- 即使没有 AI，用户也可以手动维护这些文档

## 总原则

> PinMind 的默认输出系统采用“三层分离”设计：
> **标准字段层负责语义，Format Profile 层负责渲染，Markdown 文件层负责长期存储。**
> 模型永远只输出标准字段，模板永远只处理字段渲染，迁移永远只改变格式，不改变语义。

## 文件结构

```text
00_总览/
  README.md
01_规范/
  PinMind 默认输出与 Format Profile 规范 v0.2.md
  标准字段字典 v0.2.md
  Obsidian 兼容规则 v0.2.md
02_模板/
  默认 Markdown 模板.md
  带原始内容 Markdown 模板.md
  人工最小维护模板.md
03_Format_Profile/
  Format Profile 设计说明.md
  pinmind-default.profile.json
04_人工维护/
  人工维护速查表.md
  标签与分类维护建议.md
05_开发交付/
  Trae 执行说明.md
  TypeScript 类型建议.ts
06_Codex核验/
  Codex 核验清单.md
```

## 推荐使用方式

1. 把整个文件夹放入 PinMind 项目的高优先级规范目录。
2. 先让 Trae 阅读 `01_规范/PinMind 默认输出与 Format Profile 规范 v0.2.md`。
3. 再让 Trae 按 `05_开发交付/Trae 执行说明.md` 分 P0/P1/P2 落地。
4. 每轮完成后，让 Codex 按 `06_Codex核验/Codex 核验清单.md` 做核验。
5. 用户日常维护时，只需要看 `04_人工维护/人工维护速查表.md`。

