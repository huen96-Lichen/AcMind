/**
 * AgentChatPage — AcMind 的沉浸式 Agent 入口
 *
 * 默认布局：
 * - 左侧：一级导航（由 AppShell 负责）
 * - 中间：完整对话区
 * - 底部：强存在感输入区
 * - 辅助信息：历史 / 任务 / 模型状态按需打开
 */

import { useCallback, useEffect, useMemo, useState } from 'react';
import { PageShell } from '../../design-system/components';
import { AcMindIcon } from '../../design-system/icons';
import { useAgentTasks } from '../../hooks/useAgentTasks';
import { useChat } from '../../hooks/useChat';
import { useSourceItems } from '../../hooks/useSourceItems';
import type {
  AgentActionProposal,
  AppSettings,
  ChatMessage,
  ChatSessionMetadata,
  ProviderConfig,
} from '../../../shared/types';
import { AgentTopbar } from '../../components/agent-chat/AgentTopbar';
import { ChatCanvas } from '../../components/agent-chat/ChatCanvas';
import { ChatComposer } from '../../components/agent-chat/ChatComposer';
import { ConversationDrawer } from '../../components/agent-chat/ConversationDrawer';
import { PermissionConfirmDialog } from '../../components/agent-chat/PermissionConfirmDialog';
import { TaskDrawer } from '../../components/agent-chat/TaskDrawer';

const AGENT_QUICK_COMMANDS = [
  { label: '整理今天收集的内容', value: '整理今天收集的内容' },
  { label: '查看待确认内容', value: '查看待确认内容' },
  { label: '搜索我的知识库', value: '搜索我的知识库' },
  { label: '导入文件并整理', value: '导入文件并整理' },
  { label: '打开自动工具', value: '打开自动工具' },
];

type AgentRuntimeSkill = {
  name: string;
  description: string;
  category: string;
  requiresConfirmation: boolean;
};

type ParsedAgentCommand =
  | { kind: 'new'; title?: string }
  | { kind: 'reset'; title?: string }
  | { kind: 'model'; value?: string }
  | { kind: 'search'; query?: string }
  | { kind: 'compact' }
  | { kind: 'tasks' }
  | { kind: 'skills'; value?: string }
  | { kind: 'task'; name: string; runNow: boolean }
  | {
      kind: 'navigate';
      view: 'agent' | 'workbench' | 'auto-tools' | 'settings' | 'search' | 'agent-tasks' | 'knowledge-cards' | 'import';
      tab?: string;
    }
  | { kind: 'help' }
  | { kind: 'unknown'; raw: string };

function parseAgentCommand(input: string): ParsedAgentCommand | null {
  const trimmed = input.trim();
  if (!trimmed.startsWith('/')) return null;

  const parts = trimmed.split(/\s+/);
  const command = parts[0].slice(1).toLowerCase();
  const rest = parts.slice(1).join(' ').trim();

  switch (command) {
    case '':
    case 'help':
    case 'h':
    case '?':
      return { kind: 'help' };
    case 'new':
      return { kind: 'new', title: rest || undefined };
    case 'reset':
      return { kind: 'reset', title: rest || undefined };
    case 'model':
      return { kind: 'model', value: rest || undefined };
    case 'search':
      return { kind: 'search', query: rest || undefined };
    case 'compact':
      return { kind: 'compact' };
    case 'tasks':
      return { kind: 'tasks' };
    case 'skills':
      return { kind: 'skills', value: rest || undefined };
    case 'task':
      return { kind: 'task', name: rest || '未命名任务', runNow: false };
    case 'run':
      return { kind: 'task', name: rest || '未命名任务', runNow: true };
    case 'agent':
      return { kind: 'navigate', view: 'agent' };
    case 'workbench':
      return { kind: 'navigate', view: 'workbench' };
    case 'tools':
    case 'auto-tools':
      return { kind: 'navigate', view: 'auto-tools' };
    case 'settings':
      return { kind: 'navigate', view: 'settings' };
    case 'kb':
    case 'knowledge':
      return { kind: 'navigate', view: 'knowledge-cards' };
    case 'import':
      return { kind: 'navigate', view: 'import' };
    default:
      return { kind: 'unknown', raw: trimmed };
  }
}

function guessSkillName(text: string): string | undefined {
  const lower = text.toLowerCase();
  if (text.includes('暂存') || lower.includes('inbox') || lower.includes('scan inbox')) return 'scan_inbox';
  if (text.includes('系统状态') || text.includes('检查') || lower.includes('status')) return 'check_acmind';
  if (text.includes('obsidian') || text.includes('知识库')) return 'scan_obsidian_inbox';
  if (text.includes('网页') || text.includes('抓取') || lower.includes('web')) return 'web_scraper';
  if (text.includes('文件') || text.includes('搜索') || lower.includes('file')) return 'file_search';
  if (text.includes('markdown') || text.includes('Markdown') || text.includes('文档')) return 'markdown_generator';
  return undefined;
}

function summarizeConversation(messages: ChatMessage[]): string {
  const recent = messages.filter((item) => item.role !== 'system').slice(-8);
  if (recent.length === 0) return '暂无上下文摘要';

  const lines: string[] = [];
  for (const message of recent) {
    const prefix = message.role === 'user' ? '用户' : 'Agent';
    const snippet = message.content.replace(/\s+/g, ' ').slice(0, 48);
    lines.push(`${prefix}: ${snippet}${message.content.length > 48 ? '…' : ''}`);
  }
  return lines.join('\n');
}

function formatProviderLabel(provider: ProviderConfig | null | undefined): string {
  if (!provider) return '未绑定 Provider';
  return `${provider.name} · ${provider.modelId}`;
}

function buildContextMetadata(
  contextItemIds: string[],
  source: 'desktop' | 'mobile' | 'web' | 'automation' = 'desktop',
  lastCommand?: string,
): ChatSessionMetadata {
  return {
    contextType: contextItemIds.length > 0 ? 'recent' : 'none',
    contextItemIds,
    source,
    lastCommand,
  };
}

export function AgentChatPage(): JSX.Element {
  const {
    sessions,
    currentSession,
    messages,
    sending,
    error,
    connectionStatus,
    createSession,
    switchSession,
    deleteSession,
    sendMessage,
    stopGeneration,
    attachedContext,
  } = useChat();

  const { tasks, createTask, runNow, cancelTask, loadTasks } = useAgentTasks();
  const { items: sourceItems } = useSourceItems();
  const [mockMode, setMockMode] = useState(false);
  const [providers, setProviders] = useState<ProviderConfig[]>([]);
  const [skills, setSkills] = useState<AgentRuntimeSkill[]>([]);
  const [agentSettings, setAgentSettings] = useState<AppSettings['agentChat'] | null>(null);
  const [historyOpen, setHistoryOpen] = useState(false);
  const [taskDrawerOpen, setTaskDrawerOpen] = useState(false);
  const [selectedTaskId, setSelectedTaskId] = useState<string | null>(null);
  const [composerValue, setComposerValue] = useState('');
  const [pendingAction, setPendingAction] = useState<AgentActionProposal | null>(null);

  const currentProvider = useMemo(
    () =>
      providers.find((provider) => provider.id === currentSession?.providerId) ??
      providers.find((provider) => provider.id === agentSettings?.defaultProviderId) ??
      null,
    [agentSettings?.defaultProviderId, currentSession?.providerId, providers],
  );

  const pendingSourceCount = useMemo(() => sourceItems.filter((item) => item.status === 'inbox').length, [sourceItems]);

  const loadRuntime = useCallback(async () => {
    try {
      const [settings, providerList, skillResult] = await Promise.all([
        window.acmind.settings.get(),
        window.acmind.providers.list(),
        window.acmind.agentChat.listSkills(),
      ]);
      setAgentSettings(settings.agentChat ?? null);
      setMockMode(settings.agentChat?.mockMode ?? false);
      setProviders(providerList);
      setSkills(skillResult.success ? skillResult.skills : []);
    } catch {
      setProviders([]);
      setSkills([]);
    }
  }, []);

  useEffect(() => {
    void loadRuntime();
  }, [loadRuntime]);

  useEffect(() => {
    if (!taskDrawerOpen) return;
    if (selectedTaskId && tasks.some((task) => task.id === selectedTaskId)) return;
    setSelectedTaskId(
      tasks.find((task) => task.status === 'pending' || task.status === 'running')?.id ?? tasks[0]?.id ?? null,
    );
  }, [selectedTaskId, taskDrawerOpen, tasks]);

  const openView = useCallback(
    (
      view: 'agent' | 'workbench' | 'auto-tools' | 'settings' | 'search' | 'agent-tasks' | 'knowledge-cards' | 'import',
      tab?: string,
    ) => {
      window.dispatchEvent(new CustomEvent('acmind:navigate', { detail: { view, tab } }));
    },
    [],
  );

  const ensureSession = useCallback(
    async (fallbackTitle: string, metadata?: ChatSessionMetadata) => {
      if (currentSession) return currentSession;
      const providerId = agentSettings?.defaultProviderId ?? undefined;
      const modelId = agentSettings?.defaultModelId ?? undefined;
      return createSession({
        title: fallbackTitle,
        metadata,
        providerId,
        modelId,
      });
    },
    [agentSettings?.defaultModelId, agentSettings?.defaultProviderId, createSession, currentSession],
  );

  const createSystemNote = useCallback(async (sessionId: string, content: string) => {
    await window.acmind.agentChat.createSystemMessage(sessionId, content);
  }, []);

  const handleNewSession = useCallback(async () => {
    setComposerValue('');
    await createSession({ title: '新对话', metadata: { contextType: 'none', source: 'desktop' } });
    setHistoryOpen(false);
    setTaskDrawerOpen(false);
    return true;
  }, [createSession]);

  const handleStop = useCallback(async () => {
    await stopGeneration();
  }, [stopGeneration]);

  const handleActionClick = useCallback(
    async (
      action: AgentActionProposal & {
        type: string;
        label: string;
        target?: string;
        params?: Record<string, unknown>;
        requiresConfirmation?: boolean;
      },
    ) => {
      switch (action.type) {
        case 'navigate':
          openView(
            (action.target as
              | 'agent'
              | 'workbench'
              | 'auto-tools'
              | 'settings'
              | 'search'
              | 'agent-tasks'
              | 'knowledge-cards'
              | 'import') ?? 'agent',
            action.params?.tab as string | undefined,
          );
          return;
        case 'create_task': {
          const session = await ensureSession('任务会话');
          if (!session) return;
          const name = (action.params?.name as string) || action.label;
          const skillName = guessSkillName(name);
          const task = await createTask({
            sessionId: session.id,
            name,
            skillName,
            inputParams: { source: 'agent', label: action.label, ...action.params },
          });
          if (task) {
            await createSystemNote(
              session.id,
              `已创建任务「${task.name}」${task.skillName ? `（技能：${task.skillName}）` : ''}。`,
            );
            await loadTasks();
            setTaskDrawerOpen(true);
            setSelectedTaskId(task.id);
          }
          return;
        }
        case 'run_skill': {
          const session = await ensureSession('技能会话');
          if (!session) return;
          const skillName =
            (action.params?.skillName as string) ||
            (action.target as string | undefined) ||
            guessSkillName(action.label);
          const name = (action.params?.name as string) || action.label;
          const task = await createTask({
            sessionId: session.id,
            name,
            skillName,
            inputParams: { source: 'agent', ...action.params },
          });
          if (task) {
            await runNow(task.id);
            await createSystemNote(
              session.id,
              `已触发技能任务「${task.name}」${skillName ? `（${skillName}）` : ''}。`,
            );
            await loadTasks();
            setTaskDrawerOpen(true);
            setSelectedTaskId(task.id);
          }
          return;
        }
        case 'distill':
          openView('workbench', 'distill');
          return;
        case 'export':
          openView('workbench', 'export');
          return;
        case 'scan':
          openView('workbench', 'overview');
          return;
        default:
          return;
      }
    },
    [createSystemNote, createTask, ensureSession, loadTasks, openView, runNow],
  );

  const handleActionConfirm = useCallback(
    async (
      action: AgentActionProposal & {
        type: string;
        label: string;
        target?: string;
        params?: Record<string, unknown>;
        requiresConfirmation?: boolean;
      },
    ) => {
      const ok = window.confirm(`执行操作「${action.label}」？`);
      if (!ok) return;
      await handleActionClick(action);
    },
    [handleActionClick],
  );

  const handleLocalCommand = useCallback(
    async (rawCommand: string): Promise<boolean> => {
      const parsed = parseAgentCommand(rawCommand);
      if (!parsed) return false;

      switch (parsed.kind) {
        case 'help': {
          const session = await ensureSession('命令帮助');
          if (!session) return true;
          await createSystemNote(
            session.id,
            [
              '可用命令：',
              '/new 新建会话',
              '/reset 重置当前会话',
              '/model <provider> 切换模型',
              '/search <query> 搜索知识库/历史',
              '/compact 压缩当前上下文',
              '/tasks 查看任务',
              '/skills 查看可用技能',
              '/task <name> 创建任务',
              '/run <name> 创建并执行任务',
              '/kb 打开知识库',
              '/import 打开导入页',
            ].join('\n'),
          );
          return true;
        }
        case 'new': {
          const title = parsed.title?.trim() || '新任务';
          const session = await createSession({
            title,
            metadata: buildContextMetadata(
              attachedContext.map((item) => item.id),
              'desktop',
              rawCommand,
            ),
            providerId: currentSession?.providerId ?? agentSettings?.defaultProviderId ?? undefined,
            modelId: currentSession?.modelId ?? agentSettings?.defaultModelId ?? undefined,
          });
          if (session) {
            await createSystemNote(session.id, `已创建新会话「${session.title}」。`);
            setComposerValue('');
          }
          return true;
        }
        case 'reset': {
          const title = parsed.title?.trim() || '重置后的任务';
          const session = await createSession({
            title,
            metadata: buildContextMetadata(
              attachedContext.map((item) => item.id),
              'desktop',
              rawCommand,
            ),
            providerId: currentSession?.providerId ?? agentSettings?.defaultProviderId ?? undefined,
            modelId: currentSession?.modelId ?? agentSettings?.defaultModelId ?? undefined,
          });
          if (session) {
            await createSystemNote(session.id, '已重置会话，当前开始新的任务线。');
            setComposerValue('');
          }
          return true;
        }
        case 'model': {
          const target = parsed.value?.trim();
          const session = await ensureSession('模型设置');
          if (!session) return true;

          if (!target) {
            await createSystemNote(
              session.id,
              [
                '当前模型状态：',
                formatProviderLabel(currentProvider),
                '',
                '可用模型：',
                ...providers.map((provider) => `- ${provider.name} (${provider.modelId})`),
                '',
                '提示：输入 /model <providerId 或 模型名> 切换当前会话模型。',
              ].join('\n'),
            );
            openView('settings', 'ai-models');
            return true;
          }

          const provider = providers.find(
            (item) => item.id === target || item.name.includes(target) || item.modelId.includes(target),
          );

          if (!provider) {
            await createSystemNote(session.id, `未找到模型来源「${target}」，请先到设置中添加 provider。`);
            openView('settings', 'ai-models');
            return true;
          }

          await window.acmind.agentChat.updateSession(session.id, {
            providerId: provider.id,
            modelId: provider.modelId,
            metadata: {
              ...(session.metadata ?? {}),
              lastCommand: rawCommand,
              lastModelId: provider.modelId,
            },
          });
          await switchSession(session.id);
          await createSystemNote(session.id, `已切换到「${provider.name} / ${provider.modelId}」。`);
          return true;
        }
        case 'search': {
          const session = await ensureSession('搜索');
          if (!session) return true;
          await createSystemNote(session.id, `已切换到搜索意图：${parsed.query || '帮助你搜索历史、工作台和知识库'}`);
          openView('search');
          return true;
        }
        case 'compact': {
          const session = await ensureSession('上下文压缩');
          if (!session) return true;
          const summary = summarizeConversation(messages);
          await window.acmind.agentChat.updateSession(session.id, {
            metadata: {
              ...(session.metadata ?? {}),
              summary,
              lastCommand: rawCommand,
              lastModelId: session.modelId ?? undefined,
            },
          });
          await switchSession(session.id);
          await createSystemNote(session.id, `已压缩上下文，摘要如下：\n${summary}`);
          return true;
        }
        case 'tasks': {
          setTaskDrawerOpen(true);
          setSelectedTaskId(
            tasks.find((task) => task.status === 'pending' || task.status === 'running')?.id ?? tasks[0]?.id ?? null,
          );
          return true;
        }
        case 'skills': {
          const session = await ensureSession('技能清单');
          if (!session) return true;
          const filtered = parsed.value
            ? skills.filter(
                (skill) => skill.name.includes(parsed.value || '') || skill.description.includes(parsed.value || ''),
              )
            : skills;
          const list =
            filtered.length > 0
              ? filtered
                  .map(
                    (skill) =>
                      `- ${skill.name} [${skill.category}]${skill.requiresConfirmation ? '（需确认）' : ''}: ${skill.description}`,
                  )
                  .join('\n')
              : '暂无可用技能。';
          await createSystemNote(session.id, [`当前可用技能：`, list].join('\n'));
          return true;
        }
        case 'task': {
          const session = await ensureSession('任务');
          if (!session) return true;
          const skillName = guessSkillName(parsed.name);
          const task = await createTask({
            sessionId: session.id,
            name: parsed.name,
            skillName,
            inputParams: {
              source: 'agent',
              command: rawCommand,
              prompt: parsed.name,
            },
          });
          if (task) {
            await createSystemNote(
              session.id,
              `已创建任务「${task.name}」${skillName ? `，匹配技能 ${skillName}` : ''}。`,
            );
            setTaskDrawerOpen(true);
            setSelectedTaskId(task.id);
            if (parsed.runNow) {
              await runNow(task.id);
              await createSystemNote(session.id, `任务「${task.name}」已开始执行。`);
            }
            await loadTasks();
          }
          return true;
        }
        case 'navigate': {
          openView(parsed.view, parsed.tab);
          return true;
        }
        case 'unknown': {
          const session = await ensureSession('命令');
          if (!session) return true;
          await createSystemNote(session.id, `未知命令：${parsed.raw}\n输入 /help 查看可用命令。`);
          return true;
        }
        default:
          return false;
      }
    },
    [
      agentSettings?.defaultModelId,
      agentSettings?.defaultProviderId,
      attachedContext,
      createSession,
      currentProvider,
      currentSession,
      createSystemNote,
      createTask,
      ensureSession,
      loadTasks,
      messages,
      openView,
      providers,
      runNow,
      skills,
      switchSession,
      tasks,
    ],
  );

  const handleCommandInput = useCallback(
    async (input: string): Promise<boolean> => {
      const handled = await handleLocalCommand(input);
      if (handled) return true;

      if (!currentSession) {
        const title = input.trim().slice(0, 20) || '新对话';
        const providerId = agentSettings?.defaultProviderId ?? undefined;
        const modelId = agentSettings?.defaultModelId ?? undefined;
        const session = await createSession({
          title,
          metadata: buildContextMetadata(
            attachedContext.map((item) => item.id),
            'desktop',
          ),
          providerId,
          modelId,
        });
        if (session) {
          setTimeout(() => {
            void sendMessage(input);
          }, 100);
          return true;
        }
        return false;
      }

      return sendMessage(input);
    },
    [
      agentSettings?.defaultModelId,
      agentSettings?.defaultProviderId,
      attachedContext,
      createSession,
      currentSession,
      handleLocalCommand,
      sendMessage,
    ],
  );

  const handleQuickCommand = useCallback(
    async (command: string): Promise<boolean> => {
      if (command === '打开自动工具') {
        openView('auto-tools');
        return true;
      }
      if (command === '查看待确认内容') {
        openView('workbench', 'review');
        return true;
      }
      if (command === '搜索我的知识库') {
        openView('search');
        return true;
      }
      if (command === '导入文件并整理') {
        openView('import');
        return true;
      }
      return handleCommandInput(command);
    },
    [handleCommandInput, openView],
  );

  const handleSelectSession = useCallback(
    async (sessionId: string) => {
      await switchSession(sessionId);
      setComposerValue('');
    },
    [switchSession],
  );

  const handleDeleteSession = useCallback(
    async (sessionId: string) => {
      const ok = window.confirm('确定要删除这个会话吗？此操作无法撤销。');
      if (!ok) return;
      await deleteSession(sessionId);
    },
    [deleteSession],
  );

  const handleSelectProvider = useCallback(
    async (providerId: string) => {
      const session = await ensureSession('模型会话');
      if (!session) return;
      const provider = providers.find((item) => item.id === providerId);
      if (!provider) return;

      await window.acmind.agentChat.updateSession(session.id, {
        providerId: provider.id,
        modelId: provider.modelId,
        metadata: {
          ...(session.metadata ?? {}),
          lastModelId: provider.modelId,
        },
      });
      await switchSession(session.id);
      await createSystemNote(session.id, `已切换到「${provider.name} / ${provider.modelId}」。`);
    },
    [createSystemNote, ensureSession, providers, switchSession],
  );

  const handleCapabilitySelect = useCallback((prompt: string) => {
    setComposerValue(prompt);
  }, []);

  const selectedTask = useMemo(() => tasks.find((task) => task.id === selectedTaskId) ?? null, [selectedTaskId, tasks]);

  return (
    <PageShell className="flex h-full min-h-0 min-w-0 overflow-hidden p-0">
      <div className="flex h-full min-h-0 min-w-0 flex-1 flex-col overflow-hidden bg-[radial-gradient(circle_at_top,rgba(255,107,43,0.07),transparent_30%),linear-gradient(180deg,#fcfcfd_0%,#f7f8fa_42%,#f4f5f7_100%)]">
        <AgentTopbar
          currentProvider={currentProvider}
          currentSessionTitle={currentSession?.title ?? '未创建'}
          pendingCount={pendingSourceCount}
          mockMode={mockMode}
          providers={providers}
          onOpenHistory={() => {
            setTaskDrawerOpen(false);
            setHistoryOpen(true);
          }}
          onOpenTasks={() => {
            setHistoryOpen(false);
            setSelectedTaskId(
              tasks.find((task) => task.status === 'pending' || task.status === 'running')?.id ?? tasks[0]?.id ?? null,
            );
            setTaskDrawerOpen(true);
          }}
          onOpenKnowledgeBase={() => openView('knowledge-cards')}
          onOpenModelSettings={() => openView('settings', 'ai-models')}
          onSelectProvider={handleSelectProvider}
        />

        {error ? (
          <div className="flex items-center gap-2 border-b border-[rgba(220,38,38,0.12)] bg-[rgba(254,226,226,0.8)] px-8 py-2 text-[13px] text-[color:var(--pm-danger)]">
            <AcMindIcon name="status-error" size={14} />
            <span>{error}</span>
          </div>
        ) : connectionStatus === 'error' ? (
          <div className="flex items-center gap-2 border-b border-[rgba(146,64,14,0.12)] bg-[rgba(254,243,199,0.8)] px-8 py-2 text-[13px] text-[color:var(--pm-warning)]">
            <AcMindIcon name="status-warning" size={14} />
            <span>Agent 服务连接异常，请检查本地配置。</span>
          </div>
        ) : null}

        <ChatCanvas
          messages={messages}
          mockMode={mockMode}
          onNewConversation={() => {
            void handleNewSession();
          }}
          onCapabilitySelect={handleCapabilitySelect}
          onActionClick={(action) => {
            void handleActionClick(action);
          }}
          onActionConfirm={(action) => {
            setPendingAction(action);
          }}
        />

        <ChatComposer
          value={composerValue}
          onValueChange={setComposerValue}
          onSend={async (content) => {
            const handled = await handleCommandInput(content);
            if (handled) {
              setComposerValue('');
            }
            return handled;
          }}
          onStop={handleStop}
          sending={sending}
          placeholder="输入 /help 查看命令，或直接说出你想做什么..."
          quickCommands={AGENT_QUICK_COMMANDS}
          onQuickCommandClick={async (command) => {
            const handled = await handleQuickCommand(command);
            if (handled) {
              setComposerValue('');
            }
          }}
        />
      </div>

      <ConversationDrawer
        open={historyOpen}
        sessions={sessions}
        currentSessionId={currentSession?.id ?? null}
        providers={providers}
        onClose={() => setHistoryOpen(false)}
        onNewConversation={() => {
          void handleNewSession();
        }}
        onSelectSession={(sessionId) => {
          void handleSelectSession(sessionId);
        }}
        onDeleteSession={(sessionId) => {
          void handleDeleteSession(sessionId);
        }}
      />

      <TaskDrawer
        open={taskDrawerOpen}
        tasks={tasks}
        sessions={sessions}
        selectedTaskId={selectedTask?.id ?? null}
        onClose={() => setTaskDrawerOpen(false)}
        onSelectTask={(taskId) => setSelectedTaskId(taskId)}
        onRunNow={(taskId) => {
          void runNow(taskId);
        }}
        onCancelTask={(taskId) => {
          void cancelTask(taskId);
        }}
        onOpenSession={(sessionId) => {
          void handleSelectSession(sessionId);
          setTaskDrawerOpen(false);
        }}
        onOpenTaskPage={() => {
          setTaskDrawerOpen(false);
          openView('agent-tasks');
        }}
      />

      {pendingAction ? (
        <PermissionConfirmDialog
          proposal={pendingAction}
          onConfirm={async () => {
            const action = pendingAction;
            setPendingAction(null);
            if (!action) return;
            await handleActionClick(
              action as AgentActionProposal & {
                type: string;
                label: string;
                target?: string;
                params?: Record<string, unknown>;
                requiresConfirmation?: boolean;
              },
            );
          }}
          onCancel={() => setPendingAction(null)}
        />
      ) : null}
    </PageShell>
  );
}
