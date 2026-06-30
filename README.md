# AcMind

AcMind 是一个开源、local-first 的 macOS 工作区，面向持续桌面交互、信息采集、语音输入、系统监控和 AI 辅助整理。

英文版 | [简体中文](README.zh-CN.md)

![Platform](https://img.shields.io/badge/platform-macOS%2014%2B-lightgrey)
![Language](https://img.shields.io/badge/language-Swift-blue)
![License](https://img.shields.io/badge/license-MIT-green)
![Status](https://img.shields.io/badge/status-active%20development-orange)

![AcMind current workspace screenshot](docs/screenshots/acwork-phase1/1500x920-workspace-populated.png)

## 概览

AcMind 不是一个单纯的聊天壳，而是一个桌面工作区。它把采集、抽取、整理、监控和持续交互放进同一个 macOS 应用里，让用户可以持续工作，而不必在互不相连的工具之间反复切换。

当前仓库包含：

- 原生 macOS 工作台体验
- 随身窗口 / 灵动大陆风格的常驻表面
- 桌面胶囊入口
- 全局快捷键和热角
- 语音输入和 ASR 路由
- 剪贴板、截图、文档和网页采集流程
- AI 蒸馏和导出流水线
- 系统监控表面
- 本地和云端模型路由
- 面向智能体的工具和日程相关表面

## 为什么是 AcMind

AcMind 面向希望在一个地方完成这些事情的知识工作者和重度用户：

- 快速捕获内容
- 不离开工作流就查看系统状态
- 把原始输入变成结构化笔记
- 保持一个可重复使用的常驻桌面表面
- 在需要时把工作在本地和云端 AI 提供方之间切换

这个项目追求的是“像一套真正的系统工具”：克制、直接、好用，并尽量减少打断。

## 当前状态

该仓库已经可以通过 SwiftPM 和 Xcode 从源码构建。

- `swift package resolve` 可用
- `swift build` 可用
- `xcodebuild ... build` 在关闭签名的情况下可为 `AcMind` scheme 成功构建
- `swift test` 目前在多个 suite 上仍有文档化的已知失败，因此整个测试套件还不是绿色
- 这个检查点里还没有公开发布标签

这意味着这个仓库是可信且可复现的，但还没有达到发布级打磨状态。

## 功能

本仓库对功能成熟度的口径保持保守，只会把已经稳定可用的内容写成“已实现”。

| 功能区域 | 状态 | 备注 |
|---|---|---|
| Native macOS workbench | 已实现 | 主工作台外壳与导航已在应用目标和功能视图中实现。 |
| Dynamic continent / companion window | 已实现 | 常驻随身窗口以及折叠 / 展开状态已经实现。 |
| Desktop capsule | 已实现 | 已有轻量悬浮入口。 |
| Global shortcuts | 已实现 | 全局热键注册与持久化已实现。 |
| Hot corners | 已实现 | 角落触发动作和浮层已存在。 |
| Clipboard collection | 已实现 | 剪贴板采集和固定流程已接通。 |
| System monitoring | 已实现 | CPU、内存、磁盘、网络、电池和进程视图已实现。 |
| Obsidian export | 已实现 | 导出流程已对接到 Obsidian 库 / 本地笔记流程。 |
| Voice input | 进行中 | 语音输入界面、录音和权限处理已具备，但仍依赖系统权限和提供方配置。 |
| ASR | 进行中 | 已接入多个语音识别提供方，但结果仍取决于所选后端和环境。 |
| Screenshot capture | 进行中 | 截图导出和预览工具已具备，但流程仍在继续打磨。 |
| Document processing | 进行中 | PDF / DOCX / 网页采集与整理路径已存在，但流水线仍在演进。 |
| AI distillation | 进行中 | 文稿整理与结构化输出支持已实现，但流程仍在持续打磨。 |
| Local AI provider support | 进行中 | 已有本地提供方路由，包括面向 Ollama 的路径。 |
| OpenAI-compatible provider support | 进行中 | 已有兼容 OpenAI 的路由，但仍需要用户配置和凭据。 |
| Agent functionality | 进行中 | 与智能体相关的模型、服务和界面已接入，但这一块仍在成熟过程中。 |
| Scheduling | 进行中 | 日程相关模型和服务已存在，但仍被视作持续演进的集成点。 |
| Automation | 规划中 | 本检查点不对外单独宣称自动化产品。 |

## 截图

Hero screenshot:

![AcMind workbench screenshot](docs/screenshots/acwork-phase1/1500x920-workspace-populated.png)

当前界面截图统一保存在 `docs/screenshots/`。

## 需求

- macOS 14.0 或更高版本
- Xcode 17.x 或更高版本
- 通过 Xcode 提供的 Swift 6 toolchain
- 可选：本地 AI 后端，例如 Ollama，如果你想使用本地模型路由
- 可选：本地保存的提供方凭据，用于云端功能

当前实现使用到的权限包括：

- 麦克风，用于语音输入
- Speech Recognition，用于 ASR 驱动的语音工作流
- 辅助功能，用于文本注入和系统交互
- 屏幕录制，用于截图和采集工作流
- 完整磁盘访问，用于文件较多、需要更广文件系统可见性的工作流
- 通知，用于面向用户的系统反馈

API key 会通过应用的密钥存储保存在本地；同时支持基于 Keychain 的存储，而在用户选择对应偏好时，也存在一个本地设置明文回退路径。

## 从源码构建

Swift package 验证：

```bash
swift package resolve
swift build
swift test
```

重要说明：`swift test` 目前在多个 suite 上仍有文档化的已知失败。在基线文档另行说明之前，不要把这个套件视为通过。

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

要定位构建出来的 app bundle，请查看 build settings，而不要硬编码 DerivedData 路径：

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

Bundle 路径是 `"$TARGET_BUILD_DIR/$FULL_PRODUCT_NAME"`，在 Xcode 的构建输出目录里会解析成 `AcMind.app`。

## 运行应用

推荐的本地流程：

1. 在 Xcode 中打开 `AcMind.xcodeproj`。
2. 选择 `AcMind` scheme。
3. 选择本机 Mac 作为目标设备。
4. 如果你需要签名版开发构建，就配置签名。
5. 构建并运行。

如果你走命令行，先完成构建，再按照上面的 build settings 路径打开 bundle。`swift build` 只会验证 package 目标，不会生成 `./.build/debug/AcMind.app`。

## 权限与隐私

AcMind 是 local-first，但并不意味着在任何配置下都完全离线。哪些数据会离开设备，取决于你选择的提供方和工作流。

- 语音输入需要麦克风和语音识别权限。
- 文本注入和部分桌面交互依赖辅助功能权限。
- 截图采集需要屏幕录制权限。
- 某些文件型工作流需要更广泛的文件访问权限。
- 全局快捷键通过已注册的 hotkey 处理，不是键盘记录器。
- 云端提供方会收到你明确路由给它们的 prompt、文件或采集数据。
- 本地模型工作流保持在设备上，但它们的输出和缓存仍会落在本地存储中。
- API 凭据会保存在本地，优先放入 Keychain。
- 在已审计代码中没有发现显式的遥测管线。

你可以在 系统设置 → 隐私与安全性 中撤销权限。要清理本地数据，可以删除应用保存的设置、vault 数据和密钥材料。

## 项目架构

AcMind 大致分成这些层：

- `App/`：应用生命周期、顶层编排和窗口路由
- `Features/`：面向用户的表面，例如 companion、原生工作区、侧边栏和各类专门面板
- `AcMindKit/`：可复用的核心模型、服务和基础设施
- `Design/`：视觉与交互系统材料
- `Resources/`：应用资源
- `Vendor/`：直接参与编译的本地第三方源码
- `docs/`：长期维护的架构、隐私、构建说明与一张当前界面截图

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
- 智能体服务
- 日程相关服务
- 导出和蒸馏辅助

如果其他 Swift macOS 项目也需要“壳层 + 可复用服务层”的拆分，`AcMindKit` 是最值得先研究的部分。

## 已知限制

- `swift test` 目前在多个 suite 上仍有已记录的已知失败。
- `swift build` 不会生成 `./.build/debug/AcMind.app`；应用包请用 Xcode 构建。
- 部分功能仍依赖 macOS 权限或外部提供方配置。
- 若干区域仍在演进中，尤其是智能体、日程、自动化以及部分采集流水线。
- 这个仓库还没有进入公开发布里程碑。

请参考 [`docs/testing-and-build-baseline.md`](docs/testing-and-build-baseline.md) 获取已验证的构建和测试基线，参考 [`docs/privacy-and-permissions.md`](docs/privacy-and-permissions.md) 获取当前的权限和数据流说明。

## 路线图

近期路线图以务实推进为主。当前规划视图见 [`ROADMAP.md`](ROADMAP.md)。

1. 稳定当前的 UI 和布局测试面。
2. 让社区文件和 GitHub Actions 持续对齐当前的发布基线。
3. 继续收紧关于权限、密钥和本地数据处理的隐私与安全文档。
4. 持续减少源码、截图和交接说明之间的文档漂移。
5. 在周边卫生条件就绪后准备第一个公开 alpha。

版本变化统一记录在 [`CHANGELOG.md`](CHANGELOG.md)。

## 贡献

欢迎对正确性、可读性、可复现性和安全性有帮助的贡献。请先看 [`CONTRIBUTING.md`](CONTRIBUTING.md) 了解基线工作流和验证要求。

- 用 GitHub issue 提交 bug 或功能请求。
- 用 pull request 提交聚焦的变更。
- 变更范围尽量小而明确，尤其是构建、测试和文档更新。
- 当新增或修改某个功能表面时，如果它能帮助说明当前状态，就同步更新相关截图或说明。

## 安全

Please do not report security issues as public issues. See [`SECURITY.md`](SECURITY.md) for the private reporting path and current security limitations.

Private vulnerability reporting through GitHub Security Advisories is the preferred path once the repository enables it. Until then, keep vulnerability discussions private and avoid posting secrets, credentials, or exploit details in public threads.

## 许可

MIT
