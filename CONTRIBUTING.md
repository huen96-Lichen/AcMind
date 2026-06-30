# 参与贡献

AcMind 仍处于预发布阶段。欢迎贡献，但应把它看作一个持续演进中的 macOS 工作区，而不是一个已经完成的公开产品。

如果你准备做较大的改动，请先开一个 issue，这样可以在代码落地前先对齐范围、实现路径和文档影响。

## 贡献流程

issue
→ 分支
→ 实现
→ 本地验证
→ pull request
→ review

请尽量让变更保持聚焦。小而可审查的 pull request，通常比混合了行为、文档和清理的大型重构更容易验证。

## 干净克隆环境配置

从全新的克隆开始，请使用 `docs/testing-and-build-baseline.md` 里记录的已验证基线命令：

```bash
swift package reset
swift package resolve
swift build
swift test
```

要用 Xcode 验证应用 bundle，请执行：

```bash
xcodebuild \
  -project AcMind.xcodeproj \
  -scheme AcMind \
  -configuration Debug \
  -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  build
```

可移植的 app 路径来自 Xcode build settings，而不是 `.build/debug/AcMind.app`。

## 已知测试基线

`docs/testing-and-build-baseline.md` 记录了当前基线。以本文撰写时为准，`swift test` 在多个 suite 上仍会报告文档化的已知失败，包括 `ToolWorkspaceStateTests` 和其他已记录的 suite，因此在这些 suite 更新之前，完整测试流程应保持可见的失败状态。

不要隐藏这些失败、静默跳过它们，也不要引入新的、无法解释的失败。如果你的改动影响了某个失败测试或预期的界面文本，请在同一个改动里更新基线文档。

## 代码风格与文档

- 让代码变更保持窄范围。
- 遵循仓库里已有的 Swift 风格和命名模式。
- 不要提交个人数据、凭据、包含私密内容的截图或机器专属绝对路径。
- 如果行为发生变化，请在同一个 pull request 里更新相关文档。
- 如果 UI 表面发生变化，请附上更新后的截图，或者说明为什么不需要。
- 把注释、文档和 README 文件当成变更的一部分，而不是事后补丁。

## 验证要求

在打开 pull request 之前，运行与你这次改动相关的已验证命令，并把结果记录在 PR 描述里。

至少要确认 `docs/testing-and-build-baseline.md` 中与你工作相关的命令。对于面向应用的改动，请包含 Xcode 构建命令。对于纯源码改动，至少要确认 Swift package 的解析和构建。

常规源码贡献不需要 Developer ID 凭据、公证凭据，或其他仅发布阶段才需要的签名材料。

## Pull Request 流程

- 关联 issue（如果有）。
- 简述改了什么，以及为什么改。
- 列出你执行过的命令。
- 说明仍然存在的已知失败或限制。
- 如果包含文档或截图更新，请明确写出来。
