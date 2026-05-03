// ============================================================
// PinMind AI 蒸馏工作台 v2.0 — 子视图页面
// ============================================================
// 作为 DistillPage 的子视图，提供 "输入 → 配置 → 输出" 体验。
// 使用 PinMind Native Workspace 设计系统组件。
// ============================================================

import { useState, useCallback, useRef } from 'react';
import { ScrollContainer } from '../../components/shared/ScrollContainer';
import {
  Card,
  Button,
  StatusBadge,
  EmptyState,
  LoadingState,
  ErrorState,
  Section,
} from '../../design-system';
import { PinStackIcon } from '../../design-system/icons';
import { distillWithRules } from '../../services/ruleBasedDistiller';
import type { DistillConfig, DistillResult } from '../../services/ruleBasedDistiller';

// ─── Types ───────────────────────────────────────────────────────────────────

type WorkbenchState = 'idle' | 'ready' | 'processing' | 'success' | 'error';

// ─── Component ───────────────────────────────────────────────────────────────

export function DistillationWorkbench(): JSX.Element {
  // ---- 状态 ----
  const [inputText, setInputText] = useState('');
  const [format, setFormat] = useState<DistillConfig['format']>('obsidian');
  const [includeFrontmatter, setIncludeFrontmatter] = useState(true);
  const [includeBacklinks, setIncludeBacklinks] = useState(true);
  const [includeTags, setIncludeTags] = useState(true);
  const [includeActionItems, setIncludeActionItems] = useState(false);
  const [state, setState] = useState<WorkbenchState>('idle');
  const [result, setResult] = useState<DistillResult | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [processingTimer, setProcessingTimer] = useState<ReturnType<typeof setTimeout> | null>(null);
  const [savedFilePath, setSavedFilePath] = useState<string | null>(null);
  const [isSaving, setIsSaving] = useState(false);

  const textareaRef = useRef<HTMLTextAreaElement>(null);

  // ---- 派生状态 ----
  const hasInput = inputText.trim().length > 0;
  const canDistill = hasInput && state !== 'processing';

  // ---- 输入变化 ----
  const handleInputChange = useCallback((e: React.ChangeEvent<HTMLTextAreaElement>) => {
    const text = e.target.value;
    setInputText(text);
    if (text.trim().length === 0) {
      setState('idle');
      setResult(null);
      setError(null);
    } else if (state === 'idle' || state === 'success' || state === 'error') {
      setState('ready');
    }
  }, [state]);

  // ---- 从剪贴板粘贴 ----
  const handlePasteFromClipboard = useCallback(async () => {
    try {
      const text = await navigator.clipboard.readText();
      if (text) {
        setInputText(text);
        setState('ready');
        setResult(null);
        setError(null);
      }
    } catch {
      // Fallback: focus textarea for manual paste
      textareaRef.current?.focus();
    }
  }, []);

  // ---- 开始蒸馏 ----
  const handleDistill = useCallback(() => {
    if (!canDistill) return;

    setState('processing');
    setError(null);
    setResult(null);
    setSavedFilePath(null);

    // 模拟处理延迟（让用户感受到处理过程）
    const timer = setTimeout(async () => {
      try {
        const config: DistillConfig = {
          format,
          includeFrontmatter,
          includeBacklinks,
          includeTags,
          includeActionItems,
        };
        const distillResult = await distillWithRules(inputText, config);
        setResult(distillResult);
        setState('success');
      } catch (err) {
        const message = err instanceof Error ? err.message : '蒸馏失败，请稍后重试。';
        setError(message);
        setState('error');
      }
    }, 600 + Math.random() * 600);

    setProcessingTimer(timer);
  }, [canDistill, inputText, format, includeFrontmatter, includeBacklinks, includeTags, includeActionItems]);

  // ---- 清空 ----
  const handleClear = useCallback(() => {
    if (processingTimer) clearTimeout(processingTimer);
    setInputText('');
    setResult(null);
    setError(null);
    setState('idle');
  }, [processingTimer]);

  // ---- 复制结果 ----
  const handleCopyResult = useCallback(async () => {
    if (!result) return;
    try {
      await navigator.clipboard.writeText(result.markdown);
      window.dispatchEvent(new CustomEvent('pinmind:toast', {
        detail: { message: '已复制到剪贴板', type: 'success' },
      }));
    } catch {
      // Fallback
      const textarea = document.createElement('textarea');
      textarea.value = result.markdown;
      textarea.style.position = 'fixed';
      textarea.style.opacity = '0';
      document.body.appendChild(textarea);
      textarea.select();
      document.execCommand('copy');
      document.body.removeChild(textarea);
      window.dispatchEvent(new CustomEvent('pinmind:toast', {
        detail: { message: '已复制到剪贴板', type: 'success' },
      }));
    }
  }, [result]);

  // ---- 重试 ----
  const handleRetry = useCallback(() => {
    handleDistill();
  }, [handleDistill]);

  // ---- 清空输出 ----
  const handleClearOutput = useCallback(() => {
    setResult(null);
    setError(null);
    setSavedFilePath(null);
    setState(hasInput ? 'ready' : 'idle');
  }, [hasInput]);

  // ---- 保存到文件 ----
  const handleSaveToFile = useCallback(async () => {
    if (!result) return;
    setIsSaving(true);
    try {
      const response = await window.pinmind.workbench.saveMarkdown({ content: result.markdown });
      if (response.success && response.filePath) {
        setSavedFilePath(response.filePath);
        window.dispatchEvent(new CustomEvent('pinmind:toast', {
          detail: { message: `已保存到 ${response.filePath}`, type: 'success' },
        }));
      } else {
        window.dispatchEvent(new CustomEvent('pinmind:toast', {
          detail: { message: `保存失败: ${response.error || '未知错误'}`, type: 'error' },
        }));
      }
    } catch (err) {
      const message = err instanceof Error ? err.message : '保存失败';
      window.dispatchEvent(new CustomEvent('pinmind:toast', {
        detail: { message: `保存失败: ${message}`, type: 'error' },
      }));
    } finally {
      setIsSaving(false);
    }
  }, [result]);

  // ---- 在 Finder 中显示 ----
  const handleRevealInFinder = useCallback(async () => {
    if (!savedFilePath) return;
    try {
      await window.pinmind.workbench.revealInFinder(savedFilePath);
    } catch (err) {
      const message = err instanceof Error ? err.message : '打开失败';
      window.dispatchEvent(new CustomEvent('pinmind:toast', {
        detail: { message: `打开失败: ${message}`, type: 'error' },
      }));
    }
  }, [savedFilePath]);

  // ---- 渲染 ----
  return (
    <div className="flex flex-col h-full">
      {/* 三栏布局 — lg 以上水平排列，lg 以下垂直堆叠 */}
      <div className="flex flex-col lg:flex-row flex-1 min-h-0 overflow-auto lg:overflow-hidden gap-3 p-3">

        {/* ═══ 左栏：原始材料 (34%) ═══ */}
        <Card
          variant="base"
          as="div"
          padding={0}
          className="flex flex-col min-h-0 lg:w-[34%] max-h-[40vh] lg:max-h-none shrink-0"
        >
          {/* 栏标题 */}
          <Section
            title="原始材料"
            compact
            action={
              hasInput && state !== 'processing' ? (
                <Button variant="ghost" size="sm" onClick={handleClear}>
                  清空
                </Button>
              ) : undefined
            }
            className="shrink-0"
          >
            {/* 文本输入区 */}
            <div className="flex-1 min-h-0 flex flex-col gap-3">
              <textarea
                ref={textareaRef}
                value={inputText}
                onChange={handleInputChange}
                disabled={state === 'processing'}
                placeholder="在此粘贴或输入需要蒸馏的原始材料..."
                className="pm-ds-input flex-1 resize-none text-[13px] leading-[1.7]"
                style={{
                  minHeight: 120,
                  borderRadius: 10,
                  padding: 16,
                }}
              />

              {/* 底部信息栏 */}
              <div className="flex items-center justify-between shrink-0">
                <span className="text-[12px]" style={{ color: 'var(--pm-text-tertiary)' }}>
                  {inputText.length} 字符
                </span>
                <Button
                  variant="ghost"
                  size="sm"
                  onClick={handlePasteFromClipboard}
                  disabled={state === 'processing'}
                  leadingIcon={<PinStackIcon name="copy" size={12} />}
                >
                  从剪贴板粘贴
                </Button>
              </div>
            </div>
          </Section>
        </Card>

        {/* ═══ 中栏：蒸馏配置 (24%) ═══ */}
        <Card
          variant="base"
          as="div"
          padding={0}
          className="flex flex-col min-h-0 lg:w-[24%] max-h-[40vh] lg:max-h-none shrink-0"
        >
          <Section title="蒸馏配置" compact className="shrink-0">
            <ScrollContainer className="flex-1 min-h-0" bottomPadding={16}>
              <div className="space-y-5">
                {/* 引擎状态指示器 — Mock/规则模式明确标记 */}
                <Card variant="base" padding={12} className="flex flex-col gap-1.5">
                  <div className="flex items-center gap-2">
                    <StatusBadge tone="mock" label="规则模式" dot />
                    <span className="text-[12px] font-medium" style={{ color: 'var(--pm-text-primary)' }}>
                      默认蒸馏引擎
                    </span>
                  </div>
                  <p className="text-[11px] leading-relaxed" style={{ color: 'var(--pm-text-tertiary)' }}>
                    基于规则模板生成，暂未接入 AI 模型
                  </p>
                </Card>

                {/* 输出格式 */}
                <div>
                  <label className="text-[11px] font-medium uppercase tracking-wider block mb-2" style={{ color: 'var(--pm-text-tertiary)' }}>
                    输出格式
                  </label>
                  <div className="space-y-1">
                    {([
                      { value: 'obsidian' as const, label: 'Obsidian 笔记' },
                      { value: 'markdown' as const, label: '纯 Markdown' },
                      { value: 'summary' as const, label: '摘要卡片' },
                    ]).map((opt) => (
                      <Button
                        key={opt.value}
                        variant={format === opt.value ? 'primary' : 'plain'}
                        size="sm"
                        onClick={() => setFormat(opt.value)}
                        disabled={state === 'processing'}
                        className="w-full justify-start"
                      >
                        {opt.label}
                      </Button>
                    ))}
                  </div>
                </div>

                {/* 选项 */}
                <div>
                  <label className="text-[11px] font-medium uppercase tracking-wider block mb-2" style={{ color: 'var(--pm-text-tertiary)' }}>
                    选项
                  </label>
                  <div className="space-y-2">
                    <CheckboxOption
                      label="生成 frontmatter"
                      checked={includeFrontmatter}
                      onChange={setIncludeFrontmatter}
                      disabled={state === 'processing'}
                    />
                    <CheckboxOption
                      label="生成双链建议"
                      checked={includeBacklinks}
                      onChange={setIncludeBacklinks}
                      disabled={state === 'processing'}
                    />
                    <CheckboxOption
                      label="生成标签建议"
                      checked={includeTags}
                      onChange={setIncludeTags}
                      disabled={state === 'processing'}
                    />
                    <CheckboxOption
                      label="生成行动项"
                      checked={includeActionItems}
                      onChange={setIncludeActionItems}
                      disabled={state === 'processing'}
                    />
                  </div>
                </div>
              </div>
            </ScrollContainer>
          </Section>

          {/* 底部操作区 */}
          <div className="shrink-0 p-4 pt-0 space-y-2">
            {/* 主按钮：开始蒸馏 */}
            <Button
              variant="primary"
              size="lg"
              onClick={handleDistill}
              disabled={!canDistill}
              busy={state === 'processing'}
              className="w-full"
            >
              {state === 'processing' ? '正在蒸馏...' : '开始蒸馏'}
            </Button>

            {/* 次要按钮 */}
            <div className="flex gap-2">
              <Button
                variant="ghost"
                size="sm"
                onClick={handleClear}
                disabled={state === 'processing'}
                className="flex-1"
              >
                清空
              </Button>
              <Button
                variant="ghost"
                size="sm"
                onClick={handleCopyResult}
                disabled={!result}
                className="flex-1"
              >
                复制结果
              </Button>
            </div>
          </div>
        </Card>

        {/* ═══ 右栏：蒸馏结果 (42%) ═══ */}
        <Card
          variant="base"
          as="div"
          padding={0}
          className="flex flex-col min-h-0 lg:w-[42%] max-h-[40vh] lg:max-h-none"
        >
          <Section
            title="蒸馏结果"
            compact
            action={
              state === 'success' && result ? (
                <StatusBadge tone="success" label={`耗时 ${result.processingTimeMs}ms`} dot={false} />
              ) : undefined
            }
            className="shrink-0"
          >
            <div className="flex-1 min-h-0 flex flex-col">
              {/* idle 空状态 */}
              {state === 'idle' && (
                <div className="flex-1 flex items-center justify-center">
                  <EmptyState
                    icon={<PinStackIcon name="spark" size={28} style={{ color: 'var(--pm-text-tertiary)', opacity: 0.5 }} />}
                    title="等待蒸馏结果"
                    description="在左侧输入或粘贴原始材料，配置参数后点击「开始蒸馏」"
                  />
                </div>
              )}

              {/* ready 空状态 */}
              {state === 'ready' && (
                <div className="flex-1 flex items-center justify-center">
                  <EmptyState
                    icon={<PinStackIcon name="spark" size={28} style={{ color: 'var(--pm-brand-primary)', opacity: 0.7 }} />}
                    title="已就绪"
                    description="点击「开始蒸馏」处理输入内容"
                  />
                </div>
              )}

              {/* processing 加载状态 */}
              {state === 'processing' && (
                <div className="flex-1 flex items-center justify-center">
                  <LoadingState
                    title="正在蒸馏..."
                    description="正在分析材料结构、提取重点并生成 Markdown"
                  />
                </div>
              )}

              {/* success 结果展示 */}
              {state === 'success' && result && (
                <>
                  <ScrollContainer className="flex-1 min-h-0 p-4" bottomPadding={16}>
                    <pre
                      className="text-[13px] leading-relaxed whitespace-pre-wrap break-words font-mono"
                      style={{ color: 'var(--pm-text-primary)', tabSize: 2 }}
                    >
                      {result.markdown}
                    </pre>
                  </ScrollContainer>

                  {/* 底部操作栏 */}
                  <div
                    className="shrink-0 px-4 py-3 flex items-center justify-between"
                    style={{ borderTop: '1px solid var(--pm-border-subtle)' }}
                  >
                    <div className="flex items-center gap-2">
                      <span className="text-[11px]" style={{ color: 'var(--pm-text-tertiary)' }}>
                        {result.markdown.length} 字符
                      </span>
                      {savedFilePath && (
                        <Button variant="plain" size="sm" onClick={handleRevealInFinder}>
                          在 Finder 中显示
                        </Button>
                      )}
                    </div>
                    <div className="flex items-center gap-2">
                      <Button
                        variant="secondary"
                        size="sm"
                        onClick={handleSaveToFile}
                        disabled={isSaving}
                        leadingIcon={<PinStackIcon name="save" size={12} />}
                      >
                        {isSaving ? '保存中...' : '保存为 .md'}
                      </Button>
                      <Button
                        variant="secondary"
                        size="sm"
                        onClick={handleCopyResult}
                        leadingIcon={<PinStackIcon name="copy" size={12} />}
                      >
                        复制 Markdown
                      </Button>
                    </div>
                  </div>
                </>
              )}

              {/* error 错误状态 */}
              {state === 'error' && (
                <div className="flex-1 flex items-center justify-center">
                  <ErrorState
                    title="蒸馏失败"
                    reason={error || '未知错误，请稍后重试。'}
                    suggestion="请检查输入内容后重试"
                    action={{
                      label: '重试',
                      onClick: handleRetry,
                    }}
                  />
                </div>
              )}
            </div>
          </Section>
        </Card>
      </div>
    </div>
  );
}

// ─── Checkbox 子组件 ────────────────────────────────────────────────────────

interface CheckboxOptionProps {
  label: string;
  checked: boolean;
  onChange: (checked: boolean) => void;
  disabled?: boolean;
}

function CheckboxOption({ label, checked, onChange, disabled }: CheckboxOptionProps): JSX.Element {
  return (
    <label
      className={`flex items-center gap-2 cursor-pointer select-none ${
        disabled ? 'opacity-60 cursor-not-allowed' : ''
      }`}
    >
      <input
        type="checkbox"
        checked={checked}
        onChange={(e) => onChange(e.target.checked)}
        disabled={disabled}
        className="w-4 h-4 rounded accent-[color:var(--pm-brand-primary)]"
      />
      <span className="text-[13px]" style={{ color: 'var(--pm-text-primary)' }}>{label}</span>
    </label>
  );
}
