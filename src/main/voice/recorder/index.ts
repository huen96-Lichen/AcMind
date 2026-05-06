import { spawn, type ChildProcess } from 'child_process'
import { platform } from 'os'
import { existsSync } from 'fs'
import { join, dirname } from 'path'
import { promisify } from 'util'
import { exec as execCb } from 'child_process'
import { mkdir, unlink, stat } from 'fs/promises'

const exec = promisify(execCb)

// ─── Types ────────────────────────────────────────────────────

export interface RecordingResult {
  /** Path to the recorded WAV file */
  filePath: string
  /** Duration in milliseconds */
  durationMs: number
}

export interface RecorderAvailability {
  available: boolean
  command: string | null
  message: string
}

// ─── AudioRecorder ────────────────────────────────────────────

/**
 * Cross-platform audio recorder using sox (macOS/Linux) or arecord (Linux).
 *
 * Records 16kHz mono 16-bit PCM WAV to a temporary file.
 * The caller is responsible for cleaning up the file after use.
 */
export class AudioRecorder {
  private process: ChildProcess | null = null
  private outputPath: string | null = null
  private startedAt: number = 0

  /**
   * Start recording audio to `outputPath`.
   * The file will be overwritten if it exists.
   */
  async start(outputPath: string): Promise<void> {
    if (this.process) {
      throw new Error('Recording is already in progress')
    }

    // Ensure parent directory exists
    const dir = dirname(outputPath)
    await mkdir(dir, { recursive: true })

    this.outputPath = outputPath
    this.startedAt = Date.now()

    const plat = platform()
    let cmd: string
    let args: string[]

    if (plat === 'darwin') {
      // macOS: prefer sox (installed via brew)
      if (await commandExists('sox')) {
        cmd = 'sox'
        args = [
          '-r', '16000',
          '-c', '1',
          '-e', 'signed',
          '-b', '16',
          '-d',          // default audio device
          outputPath,
        ]
      } else if (await commandExists('rec')) {
        // sox is sometimes installed as 'rec' for recording
        cmd = 'rec'
        args = [
          '-r', '16000',
          '-c', '1',
          '-e', 'signed',
          '-b', '16',
          outputPath,
        ]
      } else {
        throw new Error(
          'No recording tool found. Install sox: brew install sox'
        )
      }
    } else if (plat === 'linux') {
      if (await commandExists('sox')) {
        cmd = 'sox'
        args = [
          '-r', '16000',
          '-c', '1',
          '-e', 'signed',
          '-b', '16',
          '-d',
          outputPath,
        ]
      } else if (await commandExists('arecord')) {
        cmd = 'arecord'
        args = [
          '-r', '16000',
          '-c', '1',
          '-f', 'S16_LE',
          outputPath,
        ]
      } else {
        throw new Error(
          'No recording tool found. Install sox: sudo apt install sox'
        )
      }
    } else {
      throw new Error(`Unsupported platform: ${plat}`)
    }

    return new Promise<void>((resolve, reject) => {
      let settled = false
      const finish = (fn: () => void): void => {
        if (settled) return
        settled = true
        fn()
      }

      this.process = spawn(cmd, args, {
        stdio: ['ignore', 'ignore', 'pipe'],
      })

      let stderr = ''
      this.process.stderr?.on('data', (chunk: Buffer) => {
        stderr += chunk.toString()
      })

      this.process.on('error', (err) => {
        finish(() => {
          this.process = null
          this.outputPath = null
          reject(new Error(`Failed to start recording: ${err.message}`))
        })
      })

      this.process.on('exit', (code, signal) => {
        if (settled) {
          return
        }

        finish(() => {
          this.process = null
          this.outputPath = null
          const detail = stderr.trim()
          const suffix = [code !== null ? `code ${code}` : null, signal ? `signal ${signal}` : null]
            .filter(Boolean)
            .join(', ')
          reject(new Error(
            detail
              ? `Recording process exited before it became ready (${suffix}): ${detail}`
              : `Recording process exited before it became ready${suffix ? ` (${suffix})` : ''}`,
          ))
        })
      })

      // Give the process a moment to fail fast if device is unavailable.
      setTimeout(() => {
        if (!settled && this.process && !this.process.killed) {
          finish(resolve)
        }
      }, 200)
    })
  }

  /**
   * Stop recording and return the result.
   * Sends SIGTERM, waits up to 3s, then SIGKILL.
   */
  async stop(): Promise<RecordingResult> {
    if (!this.process || !this.outputPath) {
      throw new Error('No recording in progress')
    }

    const filePath = this.outputPath
    const durationMs = Date.now() - this.startedAt

    // Gracefully terminate the recording process
    await killProcess(this.process, 3000)

    this.process = null
    this.outputPath = null

    // Verify the file was created
    if (!existsSync(filePath)) {
      throw new Error('Recording file was not created')
    }

    const fileStat = await stat(filePath)
    if (fileStat.size === 0) {
      // Clean up empty file
      try { await unlink(filePath) } catch { /* ignore */ }
      throw new Error('Recording produced an empty file')
    }

    return { filePath, durationMs }
  }

  /** Whether a recording is currently in progress */
  isRecording(): boolean {
    return this.process !== null && !this.process.killed
  }
}

// ─── Singleton ────────────────────────────────────────────────

export const audioRecorder = new AudioRecorder()

// ─── Helpers ──────────────────────────────────────────────────

async function commandExists(cmd: string): Promise<boolean> {
  try {
    await exec(`command -v ${cmd}`)
    return true
  } catch {
    return false
  }
}

export async function getRecorderAvailability(): Promise<RecorderAvailability> {
  const plat = platform()
  if (plat === 'darwin') {
    if (await commandExists('sox')) {
      return { available: true, command: 'sox', message: 'sox is available for microphone recording.' }
    }
    if (await commandExists('rec')) {
      return { available: true, command: 'rec', message: 'rec is available for microphone recording.' }
    }
    return {
      available: false,
      command: null,
      message: 'No recording tool found. Install sox: brew install sox',
    }
  }

  if (plat === 'linux') {
    if (await commandExists('sox')) {
      return { available: true, command: 'sox', message: 'sox is available for microphone recording.' }
    }
    if (await commandExists('arecord')) {
      return { available: true, command: 'arecord', message: 'arecord is available for microphone recording.' }
    }
    return {
      available: false,
      command: null,
      message: 'No recording tool found. Install sox: sudo apt install sox',
    }
  }

  return {
    available: false,
    command: null,
    message: `Unsupported platform: ${plat}`,
  }
}

function killProcess(proc: ChildProcess, timeoutMs: number): Promise<void> {
  return new Promise<void>((resolve) => {
    const timer = setTimeout(() => {
      proc.kill('SIGKILL')
      resolve()
    }, timeoutMs)

    proc.on('exit', () => {
      clearTimeout(timer)
      resolve()
    })

    proc.kill('SIGTERM')
  })
}
