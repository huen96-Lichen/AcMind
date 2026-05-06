# AcMind + Hermes Agent 整合方案

## 概述

将 Hermes Agent 作为 AcMind 的后端 AI Agent 引擎，替换或增强现有的 Agent 功能。

## 方案一：API 服务集成（推荐）

将 Hermes 作为独立服务运行，AcMind 通过 API 与其通信。

### 步骤 1：在本地启动 Hermes MCP 服务

```bash
# 进入项目目录
cd "/Volumes/White Atlas/03_Projects/AcMind/GitHub/hermes-agent-main"

# 安装依赖
pip install -e .

# 启动 MCP 服务
python mcp_serve.py
```

### 步骤 2：配置 AcMind 连接到 Hermes

在 AcMind 的设置中添加：
- **MCP Server URL**: `http://localhost:8000/sse`
- **API 类型**: MCP (Model Context Protocol)

## 方案二：直接代码集成

将 Hermes 的核心模块集成到 AcMind 代码库中。

### 核心集成点

1. **Agent 核心** (`agent/` 目录)
   - `context_engine.py` - 上下文管理
   - `prompt_builder.py` - 提示词构建
   - `skill_commands.py` - 技能系统

2. **工具系统** (`environments/` 目录)
   - 浏览器自动化
   - 文件操作
   - 代码执行

3. **记忆系统** (`agent/memory_manager.py`)
   - 跨会话记忆
   - 用户建模

### 集成步骤

```bash
# 1. 复制核心模块到 AcMind
cp -r hermes-agent-main/agent AcMind/src/
cp -r hermes-agent-main/environments AcMind/src/
cp -r hermes-agent-main/hermes_cli AcMind/src/

# 2. 安装依赖
pip install openai anthropic python-dotenv fire httpx rich tenacity pyyaml requests jinja2 pydantic

# 3. 配置 API Keys
cp hermes-agent-main/.env.example AcMind/.env
# 编辑 .env 文件，添加你的 API Keys
```

## 方案三：CLI 包装器

保持 Hermes 独立运行，AcMind 通过子进程调用。

```python
# AcMind 中调用 Hermes 示例
import subprocess
import json

def ask_hermes(prompt: str) -> str:
    result = subprocess.run(
        ["hermes", "--oneshot", prompt],
        capture_output=True,
        text=True
    )
    return result.stdout
```

## 快速启动命令

```bash
# 1. 安装 Hermes
cd "/Volumes/White Atlas/03_Projects/AcMind/GitHub/hermes-agent-main"
curl -fsSL https://raw.githubusercontent.com/NousResearch/hermes-agent/main/scripts/install.sh | bash

# 2. 配置
hermes setup

# 3. 选择模型
hermes model

# 4. 启动交互式 CLI
hermes

# 5. 或启动网关服务（支持 Telegram/Discord/Slack）
hermes gateway
```

## AcMind 界面改造建议

将 AcMind 的 Agent 界面连接到 Hermes：

1. **输入框** → 发送到 Hermes API
2. **快捷指令** → 映射到 Hermes 的 `/skills` 命令
3. **会话历史** → 使用 Hermes 的 FTS5 搜索
4. **知识库** → 集成 Hermes 的记忆系统

## 配置文件示例

创建 `acmind-hermes-config.yaml`：

```yaml
# AcMind Hermes 集成配置
hermes:
  base_path: "/Volumes/White Atlas/03_Projects/AcMind/GitHub/hermes-agent-main"
  model: "anthropic:claude-3-5-sonnet-20241022"
  
  # 工具配置
  tools:
    - browser
    - file_operations
    - code_execution
    - web_search
  
  # 记忆配置
  memory:
    enabled: true
    cross_session: true
    
  # 技能配置
  skills:
    auto_create: true
    hub_enabled: true
```

## 下一步行动

1. ✅ Hermes 项目已在 `/Volumes/White Atlas/03_Projects/AcMind/GitHub/hermes-agent-main`
2. ⏳ 运行 `hermes setup` 完成初始化
3. ⏳ 配置 API Keys (OpenAI/Anthropic 等)
4. ⏳ 修改 AcMind 代码连接 Hermes
5. ⏳ 测试集成效果

## 参考文档

- [Hermes 官方文档](https://hermes-agent.nousresearch.com/docs/)
- [MCP 协议](https://modelcontextprotocol.io/)
