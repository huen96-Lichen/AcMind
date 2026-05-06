import type { BrowserWindow } from 'electron'
import type {
  DictationSessionPhase,
  DictationCapsulePayload,
  VoicePolishMode,
  VoiceDictionaryEntry,
} from '../../shared/types'
import { audioRecorder } from './recorder'
import { polishTranscriptLocally, polishTranscriptWithLLM } from './polish'
import { insertText } from './insertion'
import { getDictationHistoryStore } from './history'
import { asrProvider } from './asr'
import { voiceDictionaryStore } from './dictionary'
import { logger } from '../logger'
import { settings } from '../settings'
import { normalizeTranscriptionLanguage } from '../../shared/transcriptionLanguage'
import { getFrontmostApp } from '../sourceApp'
import { toSimplifiedChinese } from './chineseNormalizer'
import path from 'node:path'
import os from 'node:os'

export class DictationCoordinator {
  private phase: DictationSessionPhase = 'idle'
  private sessionId = 0
  private startedAt = 0
  private cancelled = false
  private translationModifier = false
  private dictationWindow: BrowserWindow | null = null
  private tempAudioPath: string
  private levelInterval: ReturnType<typeof setInterval> | null = null
  private idleTimeout: ReturnType<typeof setTimeout> | null = null

  private lastFrontApp: string = ''

  constructor(storageDir: string) {
    this.tempAudioPath = path.join(storageDir, 'tmp', 'dictation')
  }

  /**
   * Record the current frontmost app for later text insertion.
   * Call this before beginSession to ensure text goes to the right app.
   */
  async recordTargetApp(): Promise<void> {
    try {
      const app = await getFrontmostApp()
      this.lastFrontApp = app ?? ''
      logger.info('app', 'voice', 'coordinator', 'Recorded target app', { app: this.lastFrontApp })
    } catch {
      this.lastFrontApp = ''
    }
  }

  setDictationWindow(win: BrowserWindow | null): void {
    this.dictationWindow = win
  }

  private emit(payload: Partial<DictationCapsulePayload>): void {
    if (this.dictationWindow && !this.dictationWindow.isDestroyed()) {
      this.dictationWindow.webContents.send('dictation:state', {
        state: this.phase,
        level: 0,
        elapsedMs: this.startedAt ? Date.now() - this.startedAt : 0,
        message: '',
        insertedChars: 0,
        translation: this.translationModifier,
        previewText: '',
        ...payload,
      })
    }
  }

  async beginSession(): Promise<void> {
    if (this.phase !== 'idle') return
    this.sessionId++
    this.cancelled = false
    this.translationModifier = false
    this.startedAt = Date.now()

    this.phase = 'starting'
    this.emit({})

    try {
      const fs = await import('node:fs')
      fs.mkdirSync(this.tempAudioPath, { recursive: true })
      const audioFile = path.join(this.tempAudioPath, `session-${this.sessionId}-${Date.now()}.wav`)

      await audioRecorder.start(audioFile)
      this.phase = 'listening'
      this.emit({})

      this.levelInterval = setInterval(() => {
        if (this.phase === 'listening') {
          this.emit({ level: 0.3 + Math.random() * 0.4 })
        }
      }, 100)
    } catch (err) {
      this.phase = 'error'
      const msg = err instanceof Error ? err.message : String(err)
      this.emit({ message: `Recording failed: ${msg}` })
      this.scheduleIdle(3000)
    }
  }

  async endSession(): Promise<void> {
    if (this.phase !== 'listening' && this.phase !== 'starting') return
    if (this.levelInterval) {
      clearInterval(this.levelInterval)
      this.levelInterval = null
    }

    this.phase = 'transcribing'
    this.emit({ level: 0, message: 'Transcribing...' })

    try {
      const { durationMs, filePath } = await audioRecorder.stop()
      if (this.cancelled) {
        this.resetToIdle()
        return
      }

      const asrStatus = asrProvider.getStatus()
      if (!asrStatus.configured) {
        logger.warn('app', 'voice', 'coordinator', 'ASR not configured, transcription will fail after recording', {
          message: asrStatus.message,
        })
      }

      const asrResult = await asrProvider.transcribe(filePath, {
        language: this.getLanguage(),
        translate: this.translationModifier,
      })
      if (this.cancelled) {
        this.resetToIdle()
        return
      }

      logger.info('app', 'voice', 'coordinator', 'ASR result received', {
        success: asrResult.success,
        engine: asrResult.engine,
        textLength: asrResult.text?.trim().length ?? 0,
        preview: asrResult.text?.trim().slice(0, 120) ?? '',
        error: asrResult.error,
      })

      if (!asrResult.success || !asrResult.text.trim()) {
        this.phase = 'error'
        this.emit({ message: asrResult.error || 'No speech detected' })
        this.scheduleIdle(3000)
        return
      }

      const rawTranscript = toSimplifiedChinese(asrResult.text.trim())
      logger.info('app', 'voice', 'coordinator', 'Raw transcript ready', {
        length: rawTranscript.length,
        preview: rawTranscript.slice(0, 120),
      })

      this.phase = 'polishing'
      this.emit({ message: 'Polishing...', previewText: rawTranscript })

      const s = settings.load()
      const mode: VoicePolishMode = this.translationModifier
        ? 'raw'
        : (s.dictation?.defaultMode ?? 'light')
      let dictionary: VoiceDictionaryEntry[] = []
      try {
        dictionary = voiceDictionaryStore.list().filter((e) => e.enabled)
      } catch (error) {
        logger.warn('app', 'voice', 'coordinator', 'Voice dictionary unavailable, continuing without it', {
          error: error instanceof Error ? error.message : String(error),
        })
      }
      const frontApp = this.getFrontApp()

      let finalText: string
      let polishFailed = false

      if (mode === 'raw' || !s.ai?.apiKey) {
        const localResult = polishTranscriptLocally({
          transcript: rawTranscript,
          mode,
          dictionary,
        })
        finalText = localResult.finalText
      } else {
        try {
          const llmResult = await polishTranscriptWithLLM({
            transcript: rawTranscript,
            mode,
            dictionary,
            workingLanguages: s.dictation?.workingLanguages,
            frontApp,
            translationTarget: s.dictation?.translationTargetLanguage,
            isTranslation: this.translationModifier,
            apiEndpoint: s.ai?.apiEndpoint ?? 'https://api.openai.com/v1/',
            apiKey: s.ai.apiKey,
            model: s.ai?.model,
          })
          finalText = llmResult.finalText
          polishFailed = !!llmResult.warning
        } catch {
          const localResult = polishTranscriptLocally({
            transcript: rawTranscript,
            mode,
            dictionary,
          })
          finalText = localResult.finalText
          polishFailed = true
        }
      }

      finalText = toSimplifiedChinese(finalText)

      if (this.cancelled) {
        this.resetToIdle()
        return
      }

      this.phase = 'inserting'
      this.emit({ message: 'Inserting...', previewText: finalText })

      const insertResult = await insertText(finalText, {
        restoreClipboard: s.dictation?.restoreClipboard ?? true,
      })

      try {
        const store = getDictationHistoryStore(
          path.join(os.homedir(), 'Library/Application Support/AcMind')
        )
        store.append({
          rawTranscript,
          finalText,
          mode,
          durationMs,
          frontApp,
          polishFailed,
        })
      } catch {
        // history write failure is non-critical
      }

      this.phase = 'done'
      this.emit({
        message:
          insertResult.status === 'inserted'
            ? `Inserted ${insertResult.insertedChars} chars`
            : 'Copied to clipboard',
        insertedChars: insertResult.insertedChars,
      })
      this.scheduleIdle(2000)
    } catch (err) {
      this.phase = 'error'
      const msg = err instanceof Error ? err.message : String(err)
      this.emit({ message: `Failed: ${msg}` })
      this.scheduleIdle(3000)
    }
  }

  cancelSession(): void {
    if (this.phase === 'inserting') return
    this.cancelled = true
    if (this.phase === 'listening' || this.phase === 'starting') {
      audioRecorder.stop().catch(() => {})
      if (this.levelInterval) {
        clearInterval(this.levelInterval)
        this.levelInterval = null
      }
    }
    this.phase = 'cancelled'
    this.emit({ message: 'Cancelled' })
    this.scheduleIdle(1500)
  }

  setTranslationModifier(active: boolean): void {
    this.translationModifier = active
  }

  getPhase(): DictationSessionPhase {
    return this.phase
  }

  private resetToIdle(): void {
    this.phase = 'idle'
    this.startedAt = 0
    this.emit({})
  }

  private scheduleIdle(ms: number): void {
    if (this.idleTimeout) clearTimeout(this.idleTimeout)
    this.idleTimeout = setTimeout(() => this.resetToIdle(), ms)
  }

  private getLanguage(): string | undefined {
    const s = settings.load()
    return normalizeTranscriptionLanguage(s.dictation?.workingLanguages?.[0], 'zh')
  }

  private getFrontApp(): string {
    return this.lastFrontApp
  }
}

export const dictationCoordinator = new DictationCoordinator(
  path.join(os.homedir(), 'Library/Application Support/AcMind')
)
