/**
 * VoiceDictionaryPage — 语音词典管理 + ASR 状态 + AI Polish 测试
 *
 * 功能：
 * - 词典条目 CRUD（添加/删除/启用/禁用）
 * - ASR Provider 状态展示
 * - AI Polish 模式测试
 */

import { useState, useCallback, useEffect } from 'react';
import { PinStackIcon } from '../../design-system/icons';
import {
  PageShell,
  PageHeader,
  Section,
  Button,
  Card,
  StatusBadge,
  EmptyState,
  ErrorState,
  LoadingState,
  Input,
} from '../../design-system/components';
import { useVoiceDictionary } from '../../hooks/useVoiceDictionary';
import type { VoiceDictionaryEntry, VoicePolishMode } from '../../../shared/types';

// ── Main Page ────────────────────────────────────────────────────

export function VoiceDictionaryPage(): JSX.Element {
  const [asrStatus, setAsrStatus] = useState<{ provider: string; configured: boolean; message: string } | null>(null);

  useEffect(() => {
    void window.acmind.asr.getStatus().then((res) => {
      if (res.success) setAsrStatus(res.status);
    });
  }, []);

  return (
    <PageShell>
      <PageHeader
        title="语音设置"
        description="管理语音词典、查看 ASR 状态、测试 AI 润色"
      />

      {/* ASR Status */}
      <Section title="ASR 引擎状态">
        <Card variant="elevated">
          <div className="flex items-center gap-3">
            <PinStackIcon name={asrStatus?.configured ? 'status-success' : 'status-waiting'} size={20} />
            <div>
              <div className="text-[13px] font-medium">
                {asrStatus?.configured ? `已配置: ${asrStatus.provider}` : '未配置'}
              </div>
              <div className="text-[12px] text-[color:var(--pm-text-tertiary)]">
                {asrStatus?.message ?? '正在检查...'}
              </div>
            </div>
          </div>
        </Card>
      </Section>

      {/* Dictionary */}
      <DictionarySection />

      {/* Polish Test */}
      <PolishTestSection />
    </PageShell>
  );
}

// ── Dictionary Section ───────────────────────────────────────────

function DictionarySection(): JSX.Element {
  const { entries, loading, error, refresh, add, remove, toggle } = useVoiceDictionary();
  const [newPhrase, setNewPhrase] = useState('');
  const [newNote, setNewNote] = useState('');

  const handleAdd = useCallback(async () => {
    if (!newPhrase.trim()) return;
    const ok = await add(newPhrase.trim(), newNote.trim() || undefined);
    if (ok) {
      setNewPhrase('');
      setNewNote('');
    }
  }, [newPhrase, newNote, add]);

  const handleKeyDown = useCallback((e: React.KeyboardEvent) => {
    if (e.key === 'Enter') {
      void handleAdd();
    }
  }, [handleAdd]);

  if (loading) return <LoadingState title="加载中" description="正在加载词典..." />;
  if (error) return <ErrorState title="加载失败" reason={error} suggestion="请重试" action={{ label: '重试', onClick: refresh }} />;

  return (
    <Section title={`语音词典 (${entries.length})`}>
      {/* Add form */}
      <div className="flex gap-2 mb-4">
        <Input
          placeholder="添加短语（如：产品名、专有名词）"
          value={newPhrase}
          onChange={(e) => setNewPhrase(e.target.value)}
          onKeyDown={handleKeyDown}
          className="flex-1"
        />
        <Input
          placeholder="备注（可选）"
          value={newNote}
          onChange={(e) => setNewNote(e.target.value)}
          onKeyDown={handleKeyDown}
          className="w-40"
        />
        <Button variant="primary" onClick={handleAdd}>
          添加
        </Button>
      </div>

      {entries.length === 0 ? (
        <EmptyState
          icon={<PinStackIcon name="sb-ai-process" size={32} style={{ color: 'var(--pm-text-tertiary)' }} />}
          title="词典为空"
          description="添加专有名词、产品名等，帮助 ASR 更准确地转写"
        />
      ) : (
        <div className="flex flex-col gap-2">
          {entries.map((entry) => (
            <DictionaryEntryRow
              key={entry.id}
              entry={entry}
              onToggle={(enabled) => void toggle(entry.id, enabled)}
              onDelete={() => void remove(entry.id)}
            />
          ))}
        </div>
      )}
    </Section>
  );
}

function DictionaryEntryRow({
  entry,
  onToggle,
  onDelete,
}: {
  entry: VoiceDictionaryEntry;
  onToggle: (enabled: boolean) => void;
  onDelete: () => void;
}): JSX.Element {
  return (
    <Card variant="interactive">
      <div className="flex items-center gap-3">
        <button
          className="w-5 h-5 rounded border flex items-center justify-center shrink-0"
          style={{
            borderColor: entry.enabled ? 'var(--pm-accent)' : 'var(--pm-border-default)',
            backgroundColor: entry.enabled ? 'var(--pm-accent)' : 'transparent',
          }}
          onClick={() => onToggle(!entry.enabled)}
        >
          {entry.enabled && (
            <PinStackIcon name="status-success" size={12} style={{ color: 'white' }} />
          )}
        </button>
        <div className="flex-1 min-w-0">
          <div className="text-[13px] font-medium">{entry.phrase}</div>
          {entry.note && (
            <div className="text-[11px] text-[color:var(--pm-text-tertiary)]">{entry.note}</div>
          )}
        </div>
        <div className="flex items-center gap-2 shrink-0">
          <StatusBadge
            tone={entry.enabled ? 'success' : 'neutral'}
            label={entry.enabled ? '启用' : '禁用'}
            dot={false}
          />
          {entry.hits > 0 && (
            <StatusBadge tone="info" label={`${entry.hits} 次命中`} dot={false} />
          )}
          <Button variant="ghost" size="sm" onClick={onDelete}>
            <PinStackIcon name="close" size={14} />
          </Button>
        </div>
      </div>
    </Card>
  );
}

// ── Polish Test Section ──────────────────────────────────────────

function PolishTestSection(): JSX.Element {
  const [input, setInput] = useState('');
  const [mode, setMode] = useState<VoicePolishMode>('light');
  const [result, setResult] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  const handlePolish = useCallback(async () => {
    if (!input.trim()) return;
    setLoading(true);
    try {
      const res = await window.acmind.voice.polishTranscript({
        transcript: input,
        mode,
      });
      if (res.success && res.result) {
        setResult(res.result.finalText);
      } else {
        setResult('润色失败');
      }
    } catch {
      setResult('润色失败');
    } finally {
      setLoading(false);
    }
  }, [input, mode]);

  const MODES: Array<{ key: VoicePolishMode; label: string; desc: string }> = [
    { key: 'raw', label: '原始', desc: '仅规范化空白' },
    { key: 'light', label: '轻润色', desc: '补标点、规范格式' },
    { key: 'structured', label: '结构化', desc: '拆分从句为列表' },
    { key: 'formal', label: '正式', desc: '替换口语化表达' },
  ];

  return (
    <Section title="AI 润色测试">
      <div className="flex flex-col gap-3">
        <textarea
          className="w-full h-24 p-3 rounded-lg border border-[color:var(--pm-border-default)] bg-[color:var(--pm-surface-raised)] text-[13px] resize-none focus:outline-none focus:border-[color:var(--pm-accent)]"
          placeholder="输入转写文本进行润色测试..."
          value={input}
          onChange={(e) => setInput(e.target.value)}
        />
        <div className="flex items-center gap-2">
          <div className="flex gap-1">
            {MODES.map((m) => (
              <Button
                key={m.key}
                variant={mode === m.key ? 'primary' : 'ghost'}
                size="sm"
                onClick={() => setMode(m.key)}
                title={m.desc}
              >
                {m.label}
              </Button>
            ))}
          </div>
          <div className="flex-1" />
          <Button variant="primary" onClick={handlePolish} busy={loading}>
            润色
          </Button>
        </div>
        {result && (
          <Card variant="elevated">
            <div className="text-[11px] font-medium text-[color:var(--pm-text-tertiary)] mb-2">润色结果</div>
            <div className="text-[13px] text-[color:var(--pm-text-primary)] whitespace-pre-wrap">{result}</div>
          </Card>
        )}
      </div>
    </Section>
  );
}
