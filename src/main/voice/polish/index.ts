import type { VoiceDictionaryEntry, VoicePolishMode, VoicePolishRequest, VoicePolishResult } from '../../../shared/types';

const OPENLESS_PRINCIPLE =
  'Voice polish only rewrites the user transcript into clearer written text. It must not answer questions, execute tasks, or add new facts.';

export function getOpenLessVoicePrinciple(): string {
  return OPENLESS_PRINCIPLE;
}

export function polishTranscriptLocally(request: VoicePolishRequest): VoicePolishResult {
  const mode: VoicePolishMode = request.mode ?? 'light';
  const rawTranscript = request.transcript.trim();
  const dictionary = request.dictionary?.filter((entry) => entry.enabled) ?? [];
  const { text, usedDictionary } = applyDictionary(rawTranscript, dictionary);
  const finalText = applyMode(text, mode);

  return {
    rawTranscript,
    finalText,
    mode,
    usedDictionary,
    warning: 'No LLM provider was invoked. This is a local deterministic polish result.',
  };
}

function applyDictionary(text: string, dictionary: VoiceDictionaryEntry[]): { text: string; usedDictionary: string[] } {
  let result = text;
  const used = new Set<string>();

  for (const entry of dictionary) {
    const phrase = entry.phrase.trim();
    if (!phrase) {
      continue;
    }
    const escaped = phrase.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
    const pattern = new RegExp(escaped, 'gi');
    if (pattern.test(result)) {
      used.add(phrase);
      result = result.replace(pattern, phrase);
    }
  }

  return { text: result, usedDictionary: [...used] };
}

function applyMode(text: string, mode: VoicePolishMode): string {
  const normalized = normalizeWhitespace(text);
  if (mode === 'raw') {
    return normalized;
  }

  const sentence = ensureTerminalPunctuation(normalized);
  if (mode === 'structured') {
    return structureLoosePrompt(sentence);
  }
  if (mode === 'formal') {
    return sentence.replace(/^我想/, '我希望').replace(/^帮我/, '请帮助我');
  }
  return sentence;
}

function normalizeWhitespace(text: string): string {
  return text.replace(/\s+/g, ' ').replace(/\s+([，。！？、；：,.!?;:])/g, '$1').trim();
}

function ensureTerminalPunctuation(text: string): string {
  if (!text) {
    return text;
  }
  return /[。！？.!?]$/.test(text) ? text : `${text}。`;
}

function structureLoosePrompt(text: string): string {
  const clauses = text
    .replace(/[。！？.!?]$/g, '')
    .split(/[，,；;]/)
    .map((item) => item.trim())
    .filter(Boolean);

  if (clauses.length <= 1) {
    return text;
  }

  const [lead, ...items] = clauses;
  return `${lead}：\n\n${items.map((item) => `- ${ensureTerminalPunctuation(item)}`).join('\n')}`;
}
