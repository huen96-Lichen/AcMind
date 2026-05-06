import type { VoiceDictionaryEntry, VoicePolishMode, VoicePolishRequest, VoicePolishResult } from '../../../shared/types'

const OPENLESS_PRINCIPLE =
  'Voice polish only rewrites the user transcript into clearer written text. It must not answer questions, execute tasks, or add new facts.'

export function getOpenLessVoicePrinciple(): string {
  return OPENLESS_PRINCIPLE
}

export function polishTranscriptLocally(request: VoicePolishRequest): VoicePolishResult {
  const mode: VoicePolishMode = request.mode ?? 'light'
  const rawTranscript = request.transcript.trim()
  const dictionary = request.dictionary?.filter((entry) => entry.enabled) ?? []
  const { text, usedDictionary } = applyDictionary(rawTranscript, dictionary)
  const finalText = applyMode(text, mode)

  return {
    rawTranscript,
    finalText,
    mode,
    usedDictionary,
    warning: 'No LLM provider was invoked. This is a local deterministic polish result.',
  }
}

// ─── LLM-based Polish (OpenLess-inspired) ─────────────────────

export interface PolishWithLLMRequest {
  transcript: string
  mode: VoicePolishMode
  dictionary?: VoiceDictionaryEntry[]
  workingLanguages?: string[]
  frontApp?: string
  translationTarget?: string
  isTranslation?: boolean
  apiEndpoint: string
  apiKey: string
  model?: string
}

/**
 * Polish a voice transcript using an OpenAI-compatible LLM endpoint.
 *
 * Builds a system prompt based on mode, injects dictionary hot words and
 * context (working languages, front app), calls /chat/completions, then
 * cleans the output by stripping think blocks, markdown fences, and
 * common Chinese preamble phrases.
 *
 * On failure, returns the original transcript with a `polishFailed` warning.
 */
export async function polishTranscriptWithLLM(request: PolishWithLLMRequest): Promise<VoicePolishResult> {
  const {
    transcript,
    mode,
    dictionary,
    workingLanguages,
    frontApp,
    translationTarget,
    isTranslation,
    apiEndpoint,
    apiKey,
    model,
  } = request

  const rawTranscript = transcript.trim()
  if (!rawTranscript) {
    return {
      rawTranscript: '',
      finalText: '',
      mode,
      usedDictionary: [],
    }
  }

  // Build system prompt based on mode
  const systemPrompt = buildSystemPrompt(mode, {
    workingLanguages,
    frontApp,
    translationTarget,
    isTranslation,
    dictionary,
  })

  try {
    const url = `${apiEndpoint.replace(/\/+$/, '')}/chat/completions`
    const controller = new AbortController()
    const timeout = setTimeout(() => controller.abort(), 30_000)

    const response = await fetch(url, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${apiKey}`,
      },
      body: JSON.stringify({
        model: model || 'gpt-4o-mini',
        messages: [
          { role: 'system', content: systemPrompt },
          { role: 'user', content: rawTranscript },
        ],
        temperature: 0.3,
        max_tokens: 2048,
      }),
      signal: controller.signal,
    })

    clearTimeout(timeout)

    if (!response.ok) {
      const body = await response.text().catch(() => '')
      throw new Error(`LLM API returned ${response.status}: ${body.slice(0, 200)}`)
    }

    const data = await response.json() as {
      choices?: Array<{ message?: { content?: string } }>
    }

    const content = data.choices?.[0]?.message?.content?.trim() ?? ''
    const finalText = cleanLLMOutput(content)

    // Determine which dictionary entries were used
    const usedDictionary = detectUsedDictionary(finalText, dictionary ?? [])

    return {
      rawTranscript,
      finalText,
      mode,
      usedDictionary,
    }
  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : String(err)
    return {
      rawTranscript,
      finalText: rawTranscript,
      mode,
      usedDictionary: [],
      warning: `polishFailed: ${message}`,
    }
  }
}

// ─── System Prompt Builder ────────────────────────────────────

interface PromptContext {
  workingLanguages?: string[]
  frontApp?: string
  translationTarget?: string
  isTranslation?: boolean
  dictionary?: VoiceDictionaryEntry[]
}

const MODE_INSTRUCTIONS: Record<VoicePolishMode, string> = {
  raw: 'Return the transcript exactly as-is. Do not modify anything.',
  light: '去口癖、补标点、保留原意。Remove filler words (嗯、啊、那个、就是、然后口头禅), add proper punctuation, keep the original meaning intact. Output only the polished text.',
  structured: '按语义归类成 2-4 个主题，使用双层格式。Group the content into 2-4 thematic sections with a clear hierarchy. Use headings and bullet points. Output only the structured text.',
  formal: '适合工作沟通和邮件。Rewrite in a professional tone suitable for work communication and email. Keep it concise and clear. Output only the polished text.',
}

function buildSystemPrompt(mode: VoicePolishMode, ctx: PromptContext): string {
  const parts: string[] = []

  // Core principle
  parts.push(OPENLESS_PRINCIPLE)
  parts.push('')

  // Mode instruction
  parts.push(`Polish mode: ${mode}`)
  parts.push(MODE_INSTRUCTIONS[mode])
  parts.push('')

  // Context header
  const contextLines: string[] = []
  if (ctx.workingLanguages?.length) {
    contextLines.push(`Working languages: ${ctx.workingLanguages.join(', ')}`)
  }
  if (ctx.frontApp) {
    contextLines.push(`Current application: ${ctx.frontApp}`)
  }
  if (ctx.isTranslation && ctx.translationTarget) {
    contextLines.push(`Translation target: ${ctx.translationTarget}`)
    parts.push(`IMPORTANT: Translate the transcript to ${ctx.translationTarget}. Keep the translation natural and accurate.`)
    parts.push('')
  }
  if (contextLines.length) {
    parts.push(`Context:\n${contextLines.map((l) => `- ${l}`).join('\n')}`)
    parts.push('')
  }

  // Dictionary hot words
  const enabledDict = ctx.dictionary?.filter((e) => e.enabled) ?? []
  if (enabledDict.length) {
    parts.push(
      `Hot words / Dictionary (use these exact spellings when they appear in the transcript):\n` +
      enabledDict.map((e) => `- ${e.phrase}`).join('\n')
    )
    parts.push('')
  }

  // Output constraint
  parts.push('Output ONLY the polished text. No preamble, no explanation, no markdown code fences.')

  return parts.join('\n')
}

// ─── Output Cleaning ──────────────────────────────────────────

/**
 * Strip common LLM artifacts from the response:
 * - `<think...>` / `</think` blocks (DeepSeek style)
 * - Markdown code fences (```...```)
 * - Chinese preamble phrases
 * - Leading/trailing whitespace
 */
function cleanLLMOutput(text: string): string {
  let result = text

  // Remove <think...>...</think|</think > blocks (including multiline)
  result = result.replace(/<think[\s\S]*?<\/think\s*>/gi, '')

  // Remove unclosed <think...> blocks
  result = result.replace(/<think[\s\S]*/gi, '')

  // Remove markdown code fences
  result = result.replace(/^```(?:\w*)\n?/gm, '')
  result = result.replace(/\n?```$/gm, '')

  // Remove common Chinese preamble phrases (each on its own line)
  const preambles = [
    /^根据您给的内容[，,：:]?\s*/m,
    /^以下是[为为您]?整理[的到的]内容[：:]\s*/m,
    /^好的[，,]?\s*(以下[是为您])?/m,
    /^整理如下[：:]\s*/m,
    /^这是[为您]?整理[的到的]结果[：:]\s*/m,
    /^没问题[，,]?\s*/m,
  ]
  for (const pat of preambles) {
    result = result.replace(pat, '')
  }

  return result.trim()
}

// ─── Dictionary Detection ─────────────────────────────────────

function detectUsedDictionary(text: string, dictionary: VoiceDictionaryEntry[]): string[] {
  if (!dictionary.length) return []

  const used: string[] = []
  for (const entry of dictionary) {
    const phrase = entry.phrase.trim()
    if (!phrase) continue
    if (text.includes(phrase)) {
      used.push(phrase)
    }
  }
  return used
}

// ─── Local Polish Helpers (unchanged) ─────────────────────────

function applyDictionary(text: string, dictionary: VoiceDictionaryEntry[]): { text: string; usedDictionary: string[] } {
  let result = text
  const used = new Set<string>()

  for (const entry of dictionary) {
    const phrase = entry.phrase.trim()
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
