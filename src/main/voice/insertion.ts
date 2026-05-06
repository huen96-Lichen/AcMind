import { clipboard } from 'electron'
import { platform } from 'os'
import { promisify } from 'util'
import { exec as execCb } from 'child_process'

const exec = promisify(execCb)

// ─── Types ────────────────────────────────────────────────────

export interface InsertTextOptions {
  /** Whether to restore the previous clipboard content after pasting */
  restoreClipboard?: boolean
}

export interface InsertTextResult {
  status: 'inserted' | 'copied-fallback'
  insertedChars: number
}

// ─── Insert Text at Cursor ────────────────────────────────────

/**
 * Insert text at the current cursor position by simulating Cmd+V (macOS)
 * or Ctrl+V (Linux).
 *
 * Strategy:
 *  1. Save current clipboard (if restoreClipboard)
 *  2. Write text to clipboard
 *  3. Simulate paste via robotjs > osascript (macOS) > xdotool (Linux)
 *  4. Restore clipboard after 750ms (if restoreClipboard)
 *  5. Fallback: if paste simulation fails, just copy to clipboard
 */
export async function insertText(
  text: string,
  options?: InsertTextOptions,
): Promise<InsertTextResult> {
  const { restoreClipboard = true } = options ?? {}

  if (!text) {
    return { status: 'copied-fallback', insertedChars: 0 }
  }

  // Step 1: Save current clipboard
  let previousClipboard: string | undefined
  if (restoreClipboard) {
    try {
      previousClipboard = clipboard.readText()
    } catch {
      // clipboard may not be available in some contexts
    }
  }

  // Step 2: Write text to clipboard
  clipboard.writeText(text)

  // Step 3: Simulate paste
  let pasted = false
  try {
    pasted = await simulatePaste()
  } catch {
    pasted = false
  }

  // Step 4: Restore clipboard after delay
  if (restoreClipboard && previousClipboard !== undefined) {
    setTimeout(() => {
      try {
        clipboard.writeText(previousClipboard)
      } catch {
        // ignore
      }
    }, 750)
  }

  if (pasted) {
    return { status: 'inserted', insertedChars: text.length }
  }

  // Fallback: text is already in clipboard
  return { status: 'copied-fallback', insertedChars: text.length }
}

// ─── Paste Simulation ─────────────────────────────────────────

async function simulatePaste(): Promise<boolean> {
  const plat = platform()

  // Try robotjs first (works on both macOS and Linux)
  try {
    // robotjs is an optional dependency — use dynamic require
    const robotjs = await import('robotjs')
    robotjs.keyTap('v', plat === 'darwin' ? 'command' : 'control')
    return true
  } catch {
    // robotjs not available, fall through to platform-specific methods
  }

  if (plat === 'darwin') {
    return pasteViaOsascript()
  }

  if (plat === 'linux') {
    return pasteViaXdotool()
  }

  return false
}

/**
 * macOS: Use osascript to simulate Cmd+V via System Events.
 * Requires Accessibility permission.
 */
async function pasteViaOsascript(): Promise<boolean> {
  try {
    await exec(
      `osascript -e 'tell application "System Events" to keystroke "v" using command down'`
    )
    return true
  } catch {
    return false
  }
}

/**
 * Linux: Use xdotool to simulate Ctrl+V.
 * Requires xdotool to be installed.
 */
async function pasteViaXdotool(): Promise<boolean> {
  try {
    await exec('xdotool key ctrl+v')
    return true
  } catch {
    return false
  }
}
