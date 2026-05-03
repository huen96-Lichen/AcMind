import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import path from 'node:path';
import { randomUUID } from 'node:crypto';
import type { VoiceDictionaryEntry } from '../../../shared/types';

export class VoiceDictionaryStore {
  private filePath: string | null = null;

  init(storageRoot: string): void {
    const dir = path.join(storageRoot, 'voice');
    mkdirSync(dir, { recursive: true });
    this.filePath = path.join(dir, 'dictionary.json');
    if (!existsSync(this.filePath)) {
      writeFileSync(this.filePath, JSON.stringify([], null, 2), 'utf8');
    }
  }

  list(): VoiceDictionaryEntry[] {
    const filePath = this.requireFilePath();
    try {
      const raw = readFileSync(filePath, 'utf8');
      const parsed = JSON.parse(raw) as VoiceDictionaryEntry[];
      return Array.isArray(parsed) ? parsed : [];
    } catch {
      return [];
    }
  }

  add(phrase: string, note?: string): VoiceDictionaryEntry {
    const entry: VoiceDictionaryEntry = {
      id: randomUUID(),
      phrase: phrase.trim(),
      note,
      enabled: true,
      hits: 0,
      createdAt: Math.floor(Date.now() / 1000),
    };
    const next = [...this.list().filter((item) => item.phrase !== entry.phrase), entry];
    this.write(next);
    return entry;
  }

  remove(id: string): void {
    const next = this.list().filter((item) => item.id !== id);
    this.write(next);
  }

  toggle(id: string, enabled: boolean): void {
    const entries = this.list();
    const entry = entries.find((item) => item.id === id);
    if (entry) {
      entry.enabled = enabled;
      this.write(entries);
    }
  }

  private write(entries: VoiceDictionaryEntry[]): void {
    writeFileSync(this.requireFilePath(), JSON.stringify(entries, null, 2), 'utf8');
  }

  private requireFilePath(): string {
    if (!this.filePath) {
      throw new Error('VoiceDictionaryStore is not initialized');
    }
    return this.filePath;
  }
}

export const voiceDictionaryStore = new VoiceDictionaryStore();
