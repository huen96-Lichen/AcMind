/**
 * AgentChatSettings — Agent 对话设置组件
 *
 * 设置项：
 * - enabled: 启用 Agent 对话
 * - mockMode: Mock 模式
 * - defaultProviderId: 默认 Provider
 * - defaultModelId: 默认模型
 * - systemPrompt: 系统 Prompt
 * - maxContextMessages: 最大上下文消息数
 * - streamEnabled: 启用流式响应
 * - timeoutMs: 超时时间
 */

import { useState, useCallback } from 'react';
import type { AppSettings, ProviderConfig } from '../../../../shared/types';
import { Button } from '../../../design-system/components';
import { SettingGroupCard } from '../../../design-system/primitives';

interface AgentChatSettingsProps {
  settings: AppSettings;
  onUpdate: (patch: Partial<AppSettings>) => Promise<AppSettings | null>;
  providers: ProviderConfig[];
}

export function AgentChatSettings({ settings, onUpdate, providers }: AgentChatSettingsProps): JSX.Element {
  const agentChat = settings.agentChat;
  const [saving, setSaving] = useState(false);
  const [savedAt, setSavedAt] = useState<number | null>(null);

  const handleUpdate = useCallback(async (patch: Partial<AppSettings['agentChat']>) => {
    setSaving(true);
    try {
      const result = await onUpdate({
        agentChat: {
          ...agentChat,
          ...patch,
        },
      });
      if (result) {
        setSavedAt(Date.now());
      }
    } finally {
      setSaving(false);
    }
  }, [agentChat, onUpdate]);

  const enabledProviders = providers.filter(p => p.enabled);

  return (
    <div className="flex flex-col gap-5">
      <div className="mt-7">
        <h3 className="acmind-page-title">Agent 对话</h3>
        <p className="mt-1 text-[13px]" style={{ color: 'var(--pm-text-secondary)' }}>
          配置 AI 对话助手的行为和模型参数。
        </p>
      </div>

      {/* Basic Settings */}
      <SettingGroupCard title="基本设置" description="启用或禁用 Agent 对话功能。" icon="settings">
        <SettingsRow label="启用 Agent 对话" description="开启后可以在首页和独立页面使用 AI 对话功能。">
          <Toggle
            checked={agentChat.enabled}
            onChange={(checked) => handleUpdate({ enabled: checked })}
          />
        </SettingsRow>

        <SettingsRow label="Mock 模式" description="开启后使用模拟响应，无需配置 LLM 即可测试功能。">
          <Toggle
            checked={agentChat.mockMode}
            onChange={(checked) => handleUpdate({ mockMode: checked })}
          />
        </SettingsRow>
      </SettingGroupCard>

      {/* Model Settings */}
      <SettingGroupCard title="模型设置" description="配置默认使用的 AI 模型。" icon="ai-workspace">
        <SettingsRow label="默认 Provider" description="选择默认使用的模型提供商。">
          <select
            value={agentChat.defaultProviderId ?? ''}
            onChange={(e) => handleUpdate({ defaultProviderId: e.target.value || null })}
            className="pm-ds-input min-w-[220px]"
            disabled={enabledProviders.length === 0}
          >
            <option value="">{enabledProviders.length === 0 ? '无可用 Provider' : '自动选择'}</option>
            {enabledProviders.map((provider) => (
              <option key={provider.id} value={provider.id}>
                {provider.name} ({provider.modelId})
              </option>
            ))}
          </select>
        </SettingsRow>

        <SettingsRow label="默认模型 ID" description="手动指定模型 ID（留空使用 Provider 默认）。">
          <input
            type="text"
            value={agentChat.defaultModelId ?? ''}
            onChange={(e) => handleUpdate({ defaultModelId: e.target.value || null })}
            placeholder="例如: gpt-4o, llama3.1:8b"
            className="pm-ds-input min-w-[220px]"
          />
        </SettingsRow>
      </SettingGroupCard>

      {/* Behavior Settings */}
      <SettingGroupCard title="行为设置" description="配置对话行为和响应方式。" icon="sb-inbox">
        <SettingsRow label="系统 Prompt" description="设置 AI 助手的系统级指令。">
          <textarea
            value={agentChat.systemPrompt ?? ''}
            onChange={(e) => handleUpdate({ systemPrompt: e.target.value })}
            placeholder="你是一个有帮助的 AI 助手..."
            rows={4}
            className="pm-ds-input w-full max-w-[500px] resize-none"
          />
        </SettingsRow>

        <SettingsRow label="最大上下文消息数" description="限制发送给模型的历史消息数量（减少 Token 消耗）。">
          <input
            type="number"
            min={1}
            max={50}
            value={agentChat.maxContextMessages}
            onChange={(e) => handleUpdate({ maxContextMessages: parseInt(e.target.value, 10) || 10 })}
            className="pm-ds-input w-[100px]"
          />
        </SettingsRow>

        <SettingsRow label="启用流式响应" description="开启后逐字显示 AI 回复（推荐开启）。">
          <Toggle
            checked={agentChat.streamEnabled}
            onChange={(checked) => handleUpdate({ streamEnabled: checked })}
          />
        </SettingsRow>

        <SettingsRow label="超时时间 (ms)" description="模型响应的最大等待时间。">
          <input
            type="number"
            min={5000}
            max={300000}
            step={1000}
            value={agentChat.timeoutMs}
            onChange={(e) => handleUpdate({ timeoutMs: parseInt(e.target.value, 10) || 60000 })}
            className="pm-ds-input w-[120px]"
          />
        </SettingsRow>
      </SettingGroupCard>

      {/* Schedule Commands (日程指令快捷入口) */}
      <SettingGroupCard title="日程指令" description="Agent 支持的提醒和定时任务指令。" icon="clock">
        <div className="flex flex-col gap-3">
          <div className="text-[12px]" style={{ color: 'var(--pm-text-secondary)' }}>
            你可以直接对 Agent 说出以下指令来创建提醒和定时任务：
          </div>
          <div className="flex flex-wrap gap-2">
            {[
              { example: '一个小时后提醒我开会', desc: '创建一次性提醒' },
              { example: '每天早上 7 点给我发邮件', desc: '创建邮件定时任务' },
              { example: '每天 1 点整理 Obsidian 库', desc: '创建 Obsidian 自动整理' },
              { example: '每周三提醒我复盘', desc: '创建周期性提醒' },
              { example: '查询今天任务', desc: '查看今日日程' },
              { example: '取消明天的提醒', desc: '管理已有提醒' },
            ].map((item) => (
              <div
                key={item.example}
                className="flex flex-col rounded-[8px] border border-[color:var(--pm-border-subtle)] bg-[color:var(--pm-bg-subtle)] px-3 py-2"
              >
                <span className="text-[12px] font-medium" style={{ color: 'var(--pm-text-primary)' }}>
                  "{item.example}"
                </span>
                <span className="text-[10px]" style={{ color: 'var(--pm-text-tertiary)' }}>
                  {item.desc}
                </span>
              </div>
            ))}
          </div>
          <div className="flex items-center gap-2 rounded-[8px] border border-[color:var(--pm-border-subtle)] bg-[rgba(0,0,0,0.015)] px-3 py-2">
            <span className="text-[11px]" style={{ color: 'var(--pm-text-tertiary)' }}>
              提示：日程任务创建后可在「工作台 → 日程管家」中查看和管理。
            </span>
          </div>
        </div>
      </SettingGroupCard>

      {/* Save Feedback */}
      {savedAt && (
        <div className="flex items-center gap-2 rounded-[8px] border border-[color:var(--pm-status-success)] bg-[rgba(22,163,74,0.06)] px-3 py-2.5">
          <span className="text-[12px] font-medium text-[color:var(--pm-status-success)]">
            设置已自动保存
          </span>
        </div>
      )}

      {/* Save Button */}
      <div className="flex items-center justify-end gap-3 pt-2">
        {saving && (
          <span className="text-[11px] text-[color:var(--pm-text-tertiary)]">
            保存中...
          </span>
        )}
      </div>
    </div>
  );
}

// Helper components

interface SettingsRowProps {
  label: string;
  description?: string;
  children: React.ReactNode;
}

function SettingsRow({ label, description, children }: SettingsRowProps): JSX.Element {
  return (
    <div className="settings-row">
      <div className="settings-row-copy">
        <div className="settings-row-title">{label}</div>
        {description && (
          <div className="settings-row-description">{description}</div>
        )}
      </div>
      <div className="settings-row-control">{children}</div>
    </div>
  );
}

interface ToggleProps {
  checked: boolean;
  onChange: (checked: boolean) => void;
  disabled?: boolean;
}

function Toggle({ checked, onChange, disabled }: ToggleProps): JSX.Element {
  return (
    <button
      type="button"
      onClick={() => onChange(!checked)}
      disabled={disabled}
      className={`relative inline-flex h-6 w-11 items-center rounded-full transition-colors ${
        checked ? 'bg-accent' : 'bg-surface-muted'
      } ${disabled ? 'opacity-50 cursor-not-allowed' : 'cursor-pointer'}`}
    >
      <span
        className={`inline-block h-4 w-4 transform rounded-full bg-white transition-transform ${
          checked ? 'translate-x-6' : 'translate-x-1'
        }`}
      />
    </button>
  );
}
