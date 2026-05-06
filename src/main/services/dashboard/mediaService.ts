import { exec } from 'node:child_process';
import { promisify } from 'node:util';
import { readFile, unlink, writeFile } from 'node:fs/promises';
import path from 'node:path';
import os from 'node:os';
import type { MediaInfo, MediaPlaybackState } from '../../../shared/types';

const execAsync = promisify(exec);

const EMPTY_MEDIA: MediaInfo = {
  source: null,
  trackName: '',
  artist: '',
  album: '',
  duration: 0,
  position: 0,
  state: 'stopped',
  artworkDataUrl: null,
};

function isMacOS(): boolean {
  return process.platform === 'darwin';
}

function parseState(raw: string): MediaPlaybackState {
  const lower = raw.toLowerCase().trim();
  if (lower === 'playing') return 'playing';
  if (lower === 'paused') return 'paused';
  if (lower === 'stopped') return 'stopped';
  return 'unknown';
}

function buildGetInfoScript(app: string): string {
  return `
tell application "System Events"
  set isRunning to (name of processes) contains "${app}"
end tell
if isRunning then
  tell application "${app}"
    set tName to name of current track
    set tArtist to artist of current track
    set tAlbum to album of current track
    set tDuration to duration of current track
    set tPosition to player position
    set tState to player state as text
    return tName & "|||" & tArtist & "|||" & tAlbum & "|||" & tDuration & "|||" & tPosition & "|||" & tState
  end tell
else
  return "|||"
end if`;
}

function buildArtworkScript(app: string, tmpPath: string): string {
  return `
tell application "${app}"
  if player state is not stopped then
    try
      set artRaw to raw data of artwork 1 of current track
      set fp to open for access POSIX file "${tmpPath}" with write permission
      write artRaw to fp
      close access fp
      return "ok"
    on error
      return "error"
    end try
  end if
end tell
return "no_art"`;
}

async function tryGetFromApp(app: string): Promise<MediaInfo | null> {
  try {
    const { stdout } = await execAsync(`osascript -e '${buildGetInfoScript(app).replace(/'/g, "'\\''")}'`, { timeout: 3000 });
    const trimmed = stdout.trim();
    if (!trimmed || trimmed === '|||') return null;

    const [trackName, artist, album, durationStr, positionStr, stateStr] = trimmed.split('|||');
    if (!trackName) return null;

    return {
      source: app,
      trackName: trackName.trim(),
      artist: (artist || '').trim(),
      album: (album || '').trim(),
      duration: parseFloat(durationStr) || 0,
      position: parseFloat(positionStr) || 0,
      state: parseState(stateStr || 'stopped'),
      artworkDataUrl: null,
    };
  } catch {
    return null;
  }
}

async function tryGetArtwork(app: string, trackName: string): Promise<string | null> {
  try {
    const tmpPath = path.join(os.tmpdir(), `acmind-artwork-${Date.now()}.jpg`);
    const script = buildArtworkScript(app, tmpPath);
    const { stdout } = await execAsync(`osascript -e '${script.replace(/'/g, "'\\''")}'`, { timeout: 5000 });
    const result = stdout.trim();

    if (result === 'ok') {
      try {
        const data = await readFile(tmpPath);
        await unlink(tmpPath);
        return `data:image/jpeg;base64,${data.toString('base64')}`;
      } catch {
        return null;
      }
    }
    return null;
  } catch {
    return null;
  }
}

export async function getMediaInfo(): Promise<MediaInfo> {
  if (!isMacOS()) return EMPTY_MEDIA;

  // Try Apple Music first, then Spotify
  const apps = ['Music', 'Spotify'];
  for (const app of apps) {
    const info = await tryGetFromApp(app);
    if (info) {
      // Try to get artwork
      const artwork = await tryGetArtwork(app, info.trackName);
      return { ...info, artworkDataUrl: artwork };
    }
  }

  return EMPTY_MEDIA;
}

export async function mediaControl(action: 'playpause' | 'next' | 'previous'): Promise<void> {
  if (!isMacOS()) return;

  const apps = ['Music', 'Spotify'];
  for (const app of apps) {
    try {
      const script = `tell application "${app}" to ${action === 'playpause' ? 'playpause' : action === 'next' ? 'next track' : 'previous track'}`;
      await execAsync(`osascript -e '${script}'`, { timeout: 3000 });
      return; // Send to first available app
    } catch {
      continue;
    }
  }
}
