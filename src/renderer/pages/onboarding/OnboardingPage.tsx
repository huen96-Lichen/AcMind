import { useCallback, useEffect, useMemo, useState } from 'react';
import type { AppSettings, ProviderConfig, PermissionStatusSnapshot } from '../../../shared/types';
import { PinStackIcon } from '../../design-system/icons';

type OnboardingStep = 'welcome' | 'permissions' | 'ai' | 'vault' | 'test' | 'done';
type AiChoice = 'local' | 'cloud';
type LocalModelOption = { name: string; size: number; modifiedAt: string };

interface OnboardingPageProps {
  onComplete: () => void;
}

const STEPS: Array<{ key: OnboardingStep; label: string }> = [
  { key: 'welcome', label: '开始' },
  { key: 'permissions', label: '权限' },
  { key: 'ai', label: '模型' },
  { key: 'vault', label: '知识库' },
  { key: 'test', label: '试运行' },
  { key: 'done', label: '完成' },
];

const TEST_NOTE = `# PinMind 试运行笔记

这是一条由布置向导生成的测试内容。

目标：
- 确认 PinMind 可以把内容放进收件箱
- 后续可以一键整理成可收藏笔记
- 最终送入资料库，成为长期可用的知识资产
`;

export function OnboardingPage({ onComplete }: OnboardingPageProps): JSX.Element {
  const [step, setStep] = useState<OnboardingStep>('welcome');
  const [settings, setSettings] = useState<AppSettings | null>(null);
  const [permissions, setPermissions] = useState<PermissionStatusSnapshot | null>(null);
  const [aiChoice, setAiChoice] = useState<AiChoice>('local');
  const [localModels, setLocalModels] = useState<LocalModelOption[]>([]);
  const [localModelId, setLocalModelId] = useState('gemma3:4b');
  const [providerName, setProviderName] = useState('本地 Ollama');
  const [baseUrl, setBaseUrl] = useState('https://api.openai.com/v1');
  const [modelId, setModelId] = useState('gpt-4o-mini');
  const [apiKey, setApiKey] = useState('');
  const [vaultPath, setVaultPath] = useState('');
  const [status, setStatus] = useState<string>('准备就绪');
  const [busy, setBusy] = useState(false);
  const [scanningModels, setScanningModels] = useState(false);
  const [skipPromptOpen, setSkipPromptOpen] = useState(false);

  useEffect(() => {
    async function load(): Promise<void> {
      const [nextSettings, nextPermissions] = await Promise.all([
        window.pinmind.settings.get(),
        window.pinmind.permissions.getStatus('settings-return'),
      ]);
      setSettings(nextSettings);
      setVaultPath(nextSettings.vault.vaultPath);
      setPermissions(nextPermissions);
    }

    void load();
  }, []);

  useEffect(() => {
    async function loadLocalModels(): Promise<void> {
      setScanningModels(true);
      try {
        const models = await window.pinmind.providers.scanLocal();
        setLocalModels(models);
        if (models.length > 0) {
          setLocalModelId(models[0].name);
        }
      } catch {
        setLocalModels([]);
      } finally {
        setScanningModels(false);
      }
    }

    void loadLocalModels();
  }, []);

  const activeIndex = STEPS.findIndex((item) => item.key === step);
  const permissionItems = useMemo(() => permissions?.items ?? [], [permissions]);
  const blockingPermissions = permissionItems.filter((item) => item.blocking || item.needsAttention);
  const hasProvider = (settings?.providers?.length ?? 0) > 0;
  const hasVault = Boolean(settings?.vault.vaultPath || vaultPath);
  const selectedLocalModel = localModels.find((model) => model.name === localModelId) ?? localModels[0] ?? null;

  const goNext = useCallback(() => {
    const next = STEPS[Math.min(activeIndex + 1, STEPS.length - 1)];
    setStep(next.key);
    setStatus('准备就绪');
  }, [activeIndex]);

  const goToStep = useCallback((nextStep: OnboardingStep) => {
    setStep(nextStep);
    setStatus('准备就绪');
  }, []);

  const refreshPermissions = async () => {
    setBusy(true);
    try {
      const snapshot = await window.pinmind.permissions.refresh('manual-refresh');
      setPermissions(snapshot);
      setStatus('权限状态已刷新');
    } finally {
      setBusy(false);
    }
  };

  const saveAiChoice = async () => {
    if (!settings) return;
    setBusy(true);
    try {
      const provider: ProviderConfig = {
        id: aiChoice === 'local' ? 'default-ollama-local' : 'default-cloud-standard',
        name:
          aiChoice === 'local'
            ? `本地 Ollama · ${selectedLocalModel?.name ?? localModelId}`
            : providerName.trim() || '云端模型',
        type: aiChoice === 'local' ? 'ollama' : 'openai_compatible',
        tier: aiChoice === 'local' ? 'local_light' : 'cloud_standard',
        baseUrl: aiChoice === 'local' ? 'http://localhost:11434' : baseUrl.trim(),
        apiKey: apiKey.trim() || undefined,
        modelId: aiChoice === 'local' ? localModelId.trim() : modelId.trim(),
        enabled: true,
        capabilities: ['rename', 'summarize', 'classify', 'tag', 'valueScore', 'cleanSuggest'],
      };

      await window.pinmind.providers.add(provider);
      const providers = [provider, ...(settings.providers ?? []).filter((item) => item.id !== provider.id)];
      const updated = await window.pinmind.settings.update({
        providers,
        defaultTier: provider.tier,
      });
      setSettings(updated);
      setStatus('模型来源已保存');
      goNext();
    } catch (error) {
      setStatus(error instanceof Error ? error.message : '模型保存失败');
    } finally {
      setBusy(false);
    }
  };

  const pickVault = async () => {
    const path = await window.pinmind.vault.pickFolder();
    if (path) {
      setVaultPath(path);
      setStatus('已选择知识库');
    }
  };

  const saveVault = async () => {
    if (!settings) return;
    setBusy(true);
    try {
      const result = vaultPath ? await window.pinmind.vault.validatePath(vaultPath) : { valid: false, message: '请先选择知识库' };
      if (!result.valid) {
        setStatus(result.message);
        return;
      }
      const updated = await window.pinmind.settings.update({
        vault: {
          ...settings.vault,
          vaultPath,
          defaultFolder: settings.vault.defaultFolder || 'Inbox',
        },
      });
      setSettings(updated);
      setStatus('知识库输出位置已保存');
      goNext();
    } catch (error) {
      setStatus(error instanceof Error ? error.message : '知识库保存失败');
    } finally {
      setBusy(false);
    }
  };

  const createTestNote = async () => {
    setBusy(true);
    try {
      if (typeof window.pinmind.captureItems?.create !== 'function') {
        throw new Error('当前版本未加载试运行接口，请重新启动 PinMind 后再试。');
      }
      await window.pinmind.captureItems.create({
        type: 'text',
        title: 'PinMind 试运行笔记',
        rawText: TEST_NOTE,
        userNote: '布置向导生成的试运行内容',
      });
      setStatus('测试笔记已放入收件箱，可以继续整理');
      goNext();
    } catch (error) {
      setStatus(error instanceof Error ? error.message : '试运行失败，请稍后重试');
    } finally {
      setBusy(false);
    }
  };

  const finish = async () => {
    setBusy(true);
    try {
      await window.pinmind.settings.update({ hasCompletedOnboarding: true });
      onComplete();
    } finally {
      setBusy(false);
    }
  };

  const skipSetup = async () => {
    setBusy(true);
    try {
      await window.pinmind.settings.update({ hasCompletedOnboarding: true });
      onComplete();
    } finally {
      setBusy(false);
    }
  };

  if (!settings) {
    return (
      <div className="flex h-screen items-center justify-center bg-[color:var(--pm-bg-canvas)]">
        <span className="text-[13px] text-[color:var(--pm-text-tertiary)]">正在准备布置向导...</span>
      </div>
    );
  }

  return (
    <div className="flex min-h-screen items-center justify-center bg-[color:var(--pm-bg-canvas)] p-6">
      <main className="pinmind-window-panel grid w-full max-w-[980px] overflow-hidden lg:grid-cols-[260px_minmax(0,1fr)]">
        <aside className="border-r border-[color:var(--pm-border-subtle)] bg-white/60 p-5">
          <div className="mb-6 flex items-center gap-3">
            <span className="flex h-10 w-10 items-center justify-center rounded-[12px] bg-[color:var(--pm-brand-soft)] text-[color:var(--pm-brand-primary)]">
              <PinStackIcon name="ai-workspace" size={18} />
            </span>
            <div>
              <div className="text-[14px] font-semibold text-[color:var(--pm-text-primary)]">PinMind</div>
              <div className="text-[11px] text-[color:var(--pm-text-tertiary)]">本地知识整理器</div>
            </div>
          </div>
          <div className="flex flex-col gap-2">
            {STEPS.map((item, index) => (
              <button
                key={item.key}
                type="button"
                onClick={() => goToStep(item.key)}
                className={`flex items-center gap-2 rounded-[10px] px-3 py-2 text-[12px] ${
                  index <= activeIndex ? 'text-[color:var(--pm-text-primary)]' : 'text-[color:var(--pm-text-tertiary)]'
                }`}
                style={{
                  background: item.key === step ? 'var(--pm-brand-soft)' : 'transparent',
                }}
              >
                <span className="flex h-5 w-5 items-center justify-center rounded-full bg-white text-[10px]">{index + 1}</span>
                {item.label}
              </button>
            ))}
          </div>
          <div className="mt-auto border-t border-[color:var(--pm-border-subtle)] pt-4">
            {skipPromptOpen ? (
              <div className="flex flex-col gap-2">
                <p className="text-[11px] leading-5 text-[color:var(--pm-text-tertiary)]">
                  跳过后会直接进入 PinMind，后续可以在设置里继续补全。
                </p>
                <div className="flex gap-2">
                  <button
                    type="button"
                    className="pinmind-btn pinmind-btn-secondary motion-button text-[12px]"
                    onClick={() => setSkipPromptOpen(false)}
                  >
                    取消
                  </button>
                  <button
                    type="button"
                    className="pinmind-btn pinmind-btn-primary motion-button text-[12px]"
                    onClick={() => void skipSetup()}
                    disabled={busy}
                  >
                    {busy ? '跳过中...' : '确认跳过'}
                  </button>
                </div>
              </div>
            ) : (
              <button
                type="button"
                className="pinmind-btn pinmind-btn-ghost motion-button text-[12px]"
                onClick={() => setSkipPromptOpen(true)}
              >
                跳过设置
              </button>
            )}
          </div>
        </aside>

        <section className="flex min-h-[560px] flex-col p-7">
          {step === 'welcome' && (
            <StepFrame
              eyebrow="开始布置"
              title="把信息丢进来，剩下交给 PinMind"
              description="这次只配置最少的东西：权限、模型、知识库输出位置。完成后，你就可以复制内容、截图，然后一键整理成可收藏笔记。"
              status={status}
              actions={<PrimaryButton onClick={goNext}>开始布置</PrimaryButton>}
            >
              <div className="grid gap-3 md:grid-cols-3">
                <FeatureCard title="丢进来" body="复制文本或截图，自动进入收件箱。" />
                <FeatureCard title="一键整理" body="默认整理成标题、摘要、分类和标签。" />
                <FeatureCard title="送进知识库" body="确认后写入你的知识库。" />
              </div>
            </StepFrame>
          )}

          {step === 'permissions' && (
            <StepFrame
              eyebrow="权限检查"
              title="确认 PinMind 能捕获内容"
              description="剪贴板用于自动收集文本，屏幕录制用于截图。缺权限时可以稍后补，但首次体验会不完整。"
              status={status}
              actions={
                <>
                  <SecondaryButton onClick={refreshPermissions} disabled={busy}>{busy ? '刷新中...' : '刷新权限'}</SecondaryButton>
                  <PrimaryButton onClick={goNext}>继续</PrimaryButton>
                </>
              }
            >
              <div className="flex flex-col gap-2">
                {permissionItems.length === 0 ? (
                  <FeatureCard title="暂无权限回报" body="可以先继续，之后在设置里重新检查。" />
                ) : (
                  permissionItems.map((item) => (
                    <div key={item.key} className="pinmind-card-surface flex items-center justify-between gap-3 p-3">
                      <div>
                        <div className="text-[12px] font-semibold text-[color:var(--pm-text-primary)]">{item.title}</div>
                        <div className="mt-1 text-[11px] text-[color:var(--pm-text-tertiary)]">{item.message}</div>
                      </div>
                      <span className="pinmind-badge">{item.state}</span>
                    </div>
                  ))
                )}
                {blockingPermissions.length > 0 ? (
                  <p className="text-[11px] text-[color:var(--pm-status-warning)]">有权限需要处理。你可以先继续，之后在「设置」里打开系统设置。</p>
                ) : null}
              </div>
            </StepFrame>
          )}

          {step === 'ai' && (
            <StepFrame
              eyebrow="模型来源"
              title="选择 PinMind 用哪种方式整理内容"
              description="新手推荐本地 Ollama。没有本地模型时，也可以先保存默认配置，后续在设置里更换。"
              status={hasProvider ? '已经有模型来源，可直接继续或覆盖默认方案' : status}
              actions={
                <>
                  {hasProvider ? <SecondaryButton onClick={goNext}>沿用已有配置</SecondaryButton> : null}
                  <PrimaryButton
                    onClick={saveAiChoice}
                    disabled={
                      busy ||
                      (aiChoice === 'local' ? !localModelId.trim() : !baseUrl.trim() || !modelId.trim() || !apiKey.trim())
                    }
                  >
                    {busy ? '保存中...' : '保存模型方案'}
                  </PrimaryButton>
                </>
              }
            >
              <div className="grid gap-3 md:grid-cols-2">
                <ChoiceCard active={aiChoice === 'local'} title="本地 Ollama" body="隐私最好，适合默认整理。" onClick={() => {
                  setAiChoice('local');
                }} />
                <ChoiceCard active={aiChoice === 'cloud'} title="云端兼容 API" body="效果通常更强，需要 API 密钥。" onClick={() => {
                  setAiChoice('cloud');
                  setProviderName('云端模型');
                  setBaseUrl('https://api.openai.com/v1');
                  setModelId('gpt-4o-mini');
                }} />
              </div>
              {aiChoice === 'local' ? (
                <div className="grid gap-3">
                  <label className="block">
                    <span className="pinmind-field-label">已安装模型</span>
                    <div className="mt-1 flex flex-col gap-2 md:flex-row md:items-center">
                      <select
                        className="pinmind-field pinmind-field-select min-w-0 flex-1 px-3 text-[13px]"
                        value={localModelId}
                        onChange={(e) => setLocalModelId(e.target.value)}
                      >
                        {localModels.length === 0 ? (
                          <option value="gemma3:4b">gemma3:4b</option>
                        ) : null}
                        {localModels.map((model) => (
                          <option key={model.name} value={model.name}>
                            {model.name}
                          </option>
                        ))}
                      </select>
                      <button
                        type="button"
                        className="pinmind-btn pinmind-btn-secondary motion-button"
                        onClick={async () => {
                          setScanningModels(true);
                          try {
                            const models = await window.pinmind.providers.scanLocal();
                            setLocalModels(models);
                            if (models.length > 0) {
                              setLocalModelId((current) => models.some((model) => model.name === current) ? current : models[0].name);
                            }
                            setStatus(models.length > 0 ? '已刷新本地模型列表' : '未找到本地模型，请确认 Ollama 正在运行');
                          } finally {
                            setScanningModels(false);
                          }
                        }}
                        disabled={scanningModels}
                      >
                        {scanningModels ? '刷新中...' : '刷新模型'}
                      </button>
                    </div>
                  </label>
                  <div className="pinmind-card-surface p-3 text-[12px] leading-5 text-[color:var(--pm-text-secondary)]">
                    本地模式会自动使用已经安装好的 Ollama 模型，不需要再填写服务地址。
                  </div>
                </div>
              ) : (
                <div className="grid gap-3 md:grid-cols-2">
                  <Field label="名称" value={providerName} onChange={setProviderName} />
                  <Field label="模型 ID" value={modelId} onChange={setModelId} />
                  <Field label="接口地址" value={baseUrl} onChange={setBaseUrl} />
                  <Field label="API 密钥" value={apiKey} onChange={setApiKey} type="password" />
                </div>
              )}
            </StepFrame>
          )}

          {step === 'vault' && (
            <StepFrame
              eyebrow="知识库输出"
              title="选择笔记最终送到哪里"
              description="选择你的知识库文件夹。PinMind 会默认写入收件箱文件夹，避免打乱现有笔记结构。"
              status={hasVault ? '已选择知识库' : status}
              actions={
                <>
                  <SecondaryButton onClick={pickVault}>选择文件夹</SecondaryButton>
                  <PrimaryButton onClick={saveVault} disabled={busy || !vaultPath.trim()}>{busy ? '保存中...' : '保存并继续'}</PrimaryButton>
                </>
              }
            >
              <Field label="知识库路径" value={vaultPath} onChange={setVaultPath} placeholder="选择或粘贴知识库文件夹路径" />
              <FeatureCard title="默认输出规则" body="写入收件箱，自动带上标题、摘要、标签和基础信息。" />
            </StepFrame>
          )}

          {step === 'test' && (
            <StepFrame
              eyebrow="试运行"
              title="生成一条测试笔记"
              description="这会把一条测试内容放进收件箱。完成后你可以在首页点击一键整理，再送入知识库。"
              status={status}
              actions={<PrimaryButton onClick={createTestNote} disabled={busy}>{busy ? '生成中...' : '生成测试笔记'}</PrimaryButton>}
            >
              <div className="grid gap-4 lg:grid-cols-[minmax(0,1.2fr)_minmax(280px,0.8fr)]">
                <pre className="pinmind-card-surface min-h-[240px] whitespace-pre-wrap p-4 text-[12px] leading-6 text-[color:var(--pm-text-secondary)]">{TEST_NOTE}</pre>
                <div className="pinmind-card-surface flex min-h-[240px] flex-col gap-4 p-4">
                  <div>
                    <p className="pinmind-section-eyebrow">试运行检查</p>
                    <h3 className="mt-2 text-[16px] font-semibold text-[color:var(--pm-text-primary)]">这一步会验证什么</h3>
                  </div>
                  <div className="flex flex-1 flex-col gap-3">
                    <InfoRow title="写入入口" body="直接调用已注册的收件箱创建接口。" />
                    <InfoRow title="中文内容" body="生成内容会直接进入本地收件箱，便于后续整理。" />
                    <InfoRow title="下一步动作" body="完成后回到首页继续整理，再确认入库到资料库。" />
                  </div>
                  <div className="rounded-[12px] border border-[color:var(--pm-border-subtle)] bg-[rgba(248,246,241,0.8)] px-3 py-2 text-[11px] leading-5 text-[color:var(--pm-text-secondary)]">
                    如果按钮提示接口未加载，请完全退出并重新打开 PinMind，再重试一次。
                  </div>
                </div>
              </div>
            </StepFrame>
          )}

          {step === 'done' && (
            <StepFrame
              eyebrow="布置完成"
              title="现在可以开始整理你的信息了"
              description="下一步进入首页：复制文本或截图，点整理，确认后入库到资料库。"
              status="布置已完成"
              actions={<PrimaryButton onClick={finish} disabled={busy}>{busy ? '进入中...' : '进入 PinMind'}</PrimaryButton>}
            >
              <div className="grid gap-3 md:grid-cols-3">
                <FeatureCard title="1. 丢进来" body="复制、截图或稍后手动捕获。" />
                <FeatureCard title="2. 一键整理" body="默认生成可收藏笔记。" />
                <FeatureCard title="3. 送入知识库" body="确认后进入你的知识库。" />
              </div>
            </StepFrame>
          )}
        </section>
      </main>
    </div>
  );
}

function StepFrame({
  eyebrow,
  title,
  description,
  status,
  children,
  actions,
}: {
  eyebrow: string;
  title: string;
  description: string;
  status: string;
  children: React.ReactNode;
  actions: React.ReactNode;
}): JSX.Element {
  return (
    <div className="flex min-h-full flex-col">
      <div className="mb-6">
        <p className="pinmind-section-eyebrow">{eyebrow}</p>
        <h1 className="mt-2 text-[24px] font-semibold text-[color:var(--pm-text-primary)]">{title}</h1>
        <p className="mt-3 max-w-2xl text-[13px] leading-6 text-[color:var(--pm-text-secondary)]">{description}</p>
      </div>
      <div className="flex flex-1 flex-col gap-4">{children}</div>
      <div className="mt-6 flex items-center justify-between gap-4 border-t border-[color:var(--pm-border-subtle)] pt-4">
        <span className="text-[12px] text-[color:var(--pm-text-tertiary)]">{status}</span>
        <div className="flex flex-wrap justify-end gap-2">{actions}</div>
      </div>
    </div>
  );
}

function FeatureCard({ title, body }: { title: string; body: string }): JSX.Element {
  return (
    <div className="pinmind-card-surface p-4">
      <div className="text-[13px] font-semibold text-[color:var(--pm-text-primary)]">{title}</div>
      <div className="mt-2 text-[12px] leading-5 text-[color:var(--pm-text-secondary)]">{body}</div>
    </div>
  );
}

function InfoRow({ title, body }: { title: string; body: string }): JSX.Element {
  return (
    <div className="rounded-[12px] border border-[color:var(--pm-border-subtle)] bg-white/70 p-3">
      <div className="text-[12px] font-semibold text-[color:var(--pm-text-primary)]">{title}</div>
      <div className="mt-1 text-[11px] leading-5 text-[color:var(--pm-text-secondary)]">{body}</div>
    </div>
  );
}

function ChoiceCard({ active, title, body, onClick }: { active: boolean; title: string; body: string; onClick: () => void }): JSX.Element {
  return (
    <button
      type="button"
      onClick={onClick}
      className="pinmind-card-surface motion-button p-4 text-left"
      style={{
        borderColor: active ? 'var(--pm-brand-primary)' : undefined,
        background: active ? 'color-mix(in srgb, var(--pm-brand-soft) 58%, white 42%)' : undefined,
      }}
    >
      <div className="text-[13px] font-semibold text-[color:var(--pm-text-primary)]">{title}</div>
      <div className="mt-2 text-[12px] leading-5 text-[color:var(--pm-text-secondary)]">{body}</div>
    </button>
  );
}

function Field({
  label,
  value,
  onChange,
  placeholder,
  type = 'text',
}: {
  label: string;
  value: string;
  onChange: (value: string) => void;
  placeholder?: string;
  type?: string;
}): JSX.Element {
  return (
    <label className="block">
      <span className="pinmind-field-label">{label}</span>
      <input
        type={type}
        className="pinmind-field mt-1 w-full"
        value={value}
        placeholder={placeholder}
        onChange={(event) => onChange(event.target.value)}
      />
    </label>
  );
}

function PrimaryButton({ children, onClick, disabled }: { children: React.ReactNode; onClick: () => void; disabled?: boolean }): JSX.Element {
  return (
    <button type="button" className="pinmind-btn pinmind-btn-primary motion-button" onClick={onClick} disabled={disabled}>
      {children}
    </button>
  );
}

function SecondaryButton({ children, onClick, disabled }: { children: React.ReactNode; onClick: () => void; disabled?: boolean }): JSX.Element {
  return (
    <button type="button" className="pinmind-btn pinmind-btn-secondary motion-button" onClick={onClick} disabled={disabled}>
      {children}
    </button>
  );
}
