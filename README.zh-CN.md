# AcMind

AcMind 是一个开源、local-first 的 macOS 工作台，用于持续桌面交互、信息采集、语音输入、系统监控和 AI 辅助整理。

[English](README.md) | 简体中文

![Platform](https://img.shields.io/badge/platform-macOS%2014%2B-lightgrey)
![Language](https://img.shields.io/badge/language-Swift-blue)
![License](https://img.shields.io/badge/license-MIT-green)
![Status](https://img.shields.io/badge/status-active%20development-orange)

![AcMind 当前工作台截图](docs/screenshots/acwork-phase1/1500x920-workspace-populated.png)

## 概览

AcMind 不是一个单纯的 AI 对话壳，而是把采集、整理、监控和常驻交互组合在一起的桌面工作台。它希望让用户在 macOS 上持续工作时，不必频繁在多个割裂工具之间来回切换。

当前仓库里可以看到的内容包括：

- 原生 macOS 工作台
- 灵动大陆 / 伴随式常驻面板
- 桌面胶囊入口
- 全局快捷键和热角
- 语音输入与 ASR 路由
- 剪贴板、截图、文档和网页采集流程
- AI 蒸馏与导出链路
- 系统状态监控
- 本地与云端模型路由
- 面向 Agent 的工具和日程相关界面

## 为什么做 AcMind

AcMind 主要面向需要高频使用 Mac 的知识工作者和重度工具用户。它希望把这些事情放在同一个地方：

- 快速采集信息
- 不离开工作流地查看系统状态
- 把原始输入整理成结构化笔记
- 保持一个始终可用的桌面入口
- 在本地模型和云端模型之间按需路由

这个项目想要呈现的是一台安静、直接、可靠的系统工具，而不是会主动打扰人的应用。

## 当前状态

这个仓库现在可以从源码构建，而且 SwiftPM 和 Xcode 两条路线都能验证。

- `swift package resolve` 可用
- `swift build` 可用
- `xcodebuild ... build` 在关闭签名的情况下可用
- `swift test` 目前存在文档化的已知失败，分布在多个测试套件中，因此测试集还不是绿色
- 这个 checkpoint 里还没有公开发布标签

换句话说，它是可信、可复现的，但还没有到公开发行级别的精修状态。

## 功能状态

这里的成熟度标记故意保持保守。

| 领域 | 状态 | 说明 |
|---|---|---|
| 原生 macOS 工作台 | Available | 主工作台壳层和导航已经实现。 |
| 灵动大陆 / 伴随窗口 | Available | 常驻式伴随面板及其展开 / 收起状态已经实现。 |
| 桌面胶囊 | Available | 已存在轻量浮动入口。 |
| 全局快捷键 | Available | 快捷键注册和持久化已经实现。 |
| 热角 | Available | 角落触发动作与覆盖层已经实现。 |
| 剪贴板采集 | Available | 剪贴板采集和 pin 工作流已存在。 |
| 系统监控 | Available | CPU、内存、磁盘、网络、电池和进程视图已经实现。 |
| Obsidian 导出 | Available | 已有导出到 Vault / 本地笔记工作流。 |
| 语音输入 | Beta | 语音入口、录音和权限处理已经存在，但依赖系统权限和提供方配置。 |
| ASR | Beta | 多个 ASR 提供方已经接入，但结果取决于后端与环境。 |
| 截图采集 | Beta | 截图导出和预览工具已经存在，但更像工作流能力而不是完全打磨好的终端功能。 |
| 文档处理 | Beta | PDF / DOCX / Web 采集和蒸馏路径已经存在，但流程还在持续演进。 |
| AI 蒸馏 | Beta | Markdown 蒸馏与结构化输出助手已经实现，但仍在持续调整。 |
| 本地 AI 提供方支持 | Beta | 已有本地路由，包含偏 Ollama 的路径。 |
| OpenAI-compatible 提供方支持 | Beta | 已有兼容路由，但需要用户自行配置和提供凭据。 |
| Agent 功能 | Beta | 与 Agent 相关的模型、服务和界面已经存在，但这个区域还在成熟过程中。 |
| 日程 | Beta | 与日程相关的模型和服务已经存在，但仍应视为演进中的集成点。 |
| 自动化 | Planned | 这个 checkpoint 里不对独立的自动化产品能力做已完成声明。 |

## 截图

Hero 截图：

![AcMind 工作台截图](docs/screenshots/acwork-phase1/1500x920-workspace-populated.png)

更多当前导出和参考图位于 `docs/screenshots/` 与 `docs/refactor/` 下。

## 运行要求

- macOS 14.0 或更高版本
- Xcode 17.x 或更高版本
- 通过 Xcode 提供的 Swift 6 工具链
- 可选：本地 AI 后端，例如 Ollama，用于本地模型路由
- 可选：云端功能所需的本地存储凭据

当前实现会用到的权限包括：

- 麦克风，用于语音输入
- 语音识别，用于 ASR 驱动的语音工作流
- 辅助功能，用于文本注入和系统交互
- 屏幕录制，用于截图和采集流程
- 完全磁盘访问，用于需要更广文件系统可见性的文件型工作流
- 通知，用于系统反馈

API key 会通过应用的 secret 存储保存在本地，优先使用 Keychain；如果用户选择了相应偏好，也会有明文本地设置回退。

## 从源码构建

Swift 包验证：

```bash
swift package resolve
swift build
swift test
```

重要提示：`swift test` 目前存在文档化的已知失败，分布在多个测试套件中。除非基线文档明确更新，否则不要把测试集写成“全部通过”。

Xcode 应用构建：

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

如果想定位生成出来的 app bundle，不要硬编码 DerivedData 路径，而是查看 build settings：

```bash
xcodebuild \
  -project AcMind.xcodeproj \
  -scheme AcMind \
  -configuration Debug \
  -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  -showBuildSettings | rg 'TARGET_BUILD_DIR|FULL_PRODUCT_NAME'
```

bundle 路径就是 `"$TARGET_BUILD_DIR/$FULL_PRODUCT_NAME"`，在 Xcode 的构建输出里对应 `AcMind.app`。

## 运行 App

推荐的本地流程：

1. 在 Xcode 中打开 `AcMind.xcodeproj`。
2. 选择 `AcMind` scheme。
3. 选择本机 Mac 作为目标设备。
4. 如果你需要签名版开发构建，就配置签名。
5. 构建并运行。

如果你走命令行，先完成构建，再按照上面的 build settings 路径打开 bundle。`swift build` 只会验证 Swift Package 目标，不会生成 `./.build/debug/AcMind.app`。

## 权限与隐私

AcMind 是 local-first，但并不意味着在任何配置下都完全离线。哪些数据会离开设备，取决于你启用的提供方和工作流。

- 语音输入需要麦克风和语音识别权限。
- 文本注入和部分桌面交互依赖辅助功能权限。
- 截图采集需要屏幕录制权限。
- 某些文件型工作流需要更广泛的文件访问权限。
- 全局快捷键通过已注册的 hotkey 实现，不是键盘记录器。
- 云端提供方会收到你明确路由给它们的 prompt、文件或采集数据。
- 本地模型工作流保持在设备上，但输出和缓存仍会落在本地存储中。
- API 凭据会保存在本地，优先放入 Keychain。
- 在已审计代码中没有看到显式的遥测管线。

用户可以在 系统设置 → 隐私与安全性 中撤销权限。删除本地数据时，可以清理应用保存的设置、Vault 数据和密钥材料。

## 项目架构

AcMind 大致分成这些层：

- `App/`：应用生命周期、顶层编排和窗口路由
- `Features/`：面向用户的表面，例如 companion、原生工作台、侧边栏和各类专门面板
- `AcMindKit/`：可复用的核心模型、服务和基础设施
- `Design/`：视觉和交互系统材料
- `Resources/`：应用资源
- `Vendor/`：第三方源码和依赖
- `docs/`：架构说明、截图、审计和交接材料

这个架构的关键点是，同一套壳层和服务层支撑多个表面，而不是每个表面都重新发明一套应用结构。

## AcMindKit

`AcMindKit` 是可复用的核心层，里面包含应用的服务和模型层，例如：

- 存储与迁移
- 权限
- 快捷键
- 语音与 ASR 路由
- 剪贴板与采集流程
- 系统状态读取与格式化
- AI 提供方路由
- Agent 服务
- 日程相关服务
- 导出和蒸馏辅助

如果其他 Swift macOS 项目也需要“壳层 + 可复用服务层”的拆分，`AcMindKit` 是最值得先研究的部分。

## 已知限制

- `swift test` 目前在多个测试套件中存在文档化的已知失败。
- `swift build` 不会生成 `./.build/debug/AcMind.app`，app bundle 需要通过 Xcode 构建。
- 部分功能依赖 macOS 权限或外部提供方配置。
- 一些区域仍在演进中，尤其是 Agent、日程、自动化和部分采集管线。
- 这个仓库还没有进入公开发布里程碑。

## 路线图

近期路线图保持务实。详细版本见 [`ROADMAP.md`](ROADMAP.md)。

1. 稳定当前的 UI 和布局测试面。
2. 让社区文件和 GitHub Actions 持续对齐当前的发布基线。
3. 继续收紧关于权限、密钥和本地数据处理的隐私与安全文档。
4. 持续减少源码、截图和交接文档之间的文档漂移。
5. 在周边卫生条件就绪后准备第一个公开 alpha。

草拟的 alpha 发布说明见 [`CHANGELOG.md`](CHANGELOG.md) 和 [`docs/releases/v0.1.0-alpha.md`](docs/releases/v0.1.0-alpha.md)。

## 贡献

欢迎对正确性、可读性、可复现性和安全性有帮助的贡献。请先看 [`CONTRIBUTING.md`](CONTRIBUTING.md) 了解基线工作流和验证要求。

- 用 GitHub issue 提交 bug 或功能请求。
- 用 pull request 提交聚焦的变更。
- 变更范围尽量小而明确，尤其是构建、测试和文档更新。
- 当新增或修改某个功能表面时，如果它能帮助说明当前状态，就同步更新相关截图或说明。

## 安全

不要通过公开 issue 报告安全问题。请查看 [`SECURITY.md`](SECURITY.md) 了解私密报告流程和当前安全限制。

等仓库启用 GitHub Security Advisories 后，优先通过私密漏洞报告方式提交。当前阶段请保持漏洞讨论私密，不要在公开线程里贴出密钥、凭据或利用细节。

## 许可证

MIT
