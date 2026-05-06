import { readdirSync, existsSync, readFileSync } from 'node:fs';
import path from 'node:path';
import type { ScannedGitRepo } from '../../../shared/types';

export class GitRepoScanner {
  /**
   * 扫描指定目录的直接子目录，识别 Git 仓库。
   * 深度限制 1 层，排除隐藏目录。
   */
  scan(baseDir: string): ScannedGitRepo[] {
    const results: ScannedGitRepo[] = [];

    // 如果 baseDir 本身就是 Git 仓库，直接返回
    if (existsSync(path.join(baseDir, '.git'))) {
      results.push({
        name: path.basename(baseDir),
        localPath: baseDir,
        description: this.extractDescription(baseDir),
        alreadyImported: false,
      });
      return results;
    }

    let entries;
    try {
      entries = readdirSync(baseDir, { withFileTypes: true });
    } catch {
      return results;
    }

    for (const entry of entries) {
      if (!entry.isDirectory()) continue;
      if (entry.name.startsWith('.')) continue;

      const childPath = path.join(baseDir, entry.name);
      const gitPath = path.join(childPath, '.git');

      if (!existsSync(gitPath)) continue;

      results.push({
        name: entry.name,
        localPath: childPath,
        description: this.extractDescription(childPath),
        alreadyImported: false, // 由 IPC handler 层设置
      });
    }

    return results;
  }

  /**
   * 从 package.json 或 README.md 提取项目描述。
   */
  private extractDescription(dirPath: string): string {
    // 优先读 package.json
    const pkgPath = path.join(dirPath, 'package.json');
    try {
      const raw = readFileSync(pkgPath, 'utf-8');
      const pkg = JSON.parse(raw);
      if (pkg.description && typeof pkg.description === 'string' && pkg.description.trim()) {
        return pkg.description.trim().slice(0, 200);
      }
    } catch {
      // JSON 解析失败或文件不存在，继续尝试 README
    }

    // 其次读 README.md
    const readmeNames = ['README.md', 'README.txt', 'README'];
    for (const name of readmeNames) {
      const readmePath = path.join(dirPath, name);
      try {
        const raw = readFileSync(readmePath, 'utf-8');
        const lines = raw.split('\n');
        for (const line of lines) {
          const trimmed = line.trim();
          if (!trimmed) continue;
          // 跳过标题行（# 开头）
          if (trimmed.startsWith('#')) continue;
          // 跳过 badge 链接行（[![ 开头）
          if (trimmed.startsWith('[![')) continue;
          // 跳过 HTML 标签行
          if (trimmed.startsWith('<')) continue;
          return trimmed.slice(0, 200);
        }
      } catch {
        continue;
      }
    }

    return '';
  }
}

export const gitRepoScanner = new GitRepoScanner();
