import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { afterEach, describe, expect, it } from 'vitest';
import { safeWrite } from './safeWrite';

describe('safeWrite', () => {
  let tmpDir: string | null = null;

  afterEach(() => {
    if (tmpDir) {
      fs.rmSync(tmpDir, { recursive: true, force: true });
      tmpDir = null;
    }
  });

  it('refuses to write empty markdown content', () => {
    tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'pinmind-safe-write-'));
    const target = path.join(tmpDir, 'empty.md');

    expect(() => safeWrite(target, '   \n\t')).toThrow('Refusing to write empty Markdown content');
    expect(fs.existsSync(target)).toBe(false);
  });

  it('writes non-empty markdown content', () => {
    tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'pinmind-safe-write-'));
    const target = path.join(tmpDir, 'note.md');

    safeWrite(target, '# 标题\n\n正文');

    expect(fs.readFileSync(target, 'utf8')).toContain('正文');
  });
});
