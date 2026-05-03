// AcMind Frontmatter Parser
// Parses YAML frontmatter from Markdown files (Obsidian format)

export class FrontmatterParser {
  /**
   * Parse frontmatter and content from a Markdown string.
   */
  parseFile(content: string): {
    frontmatter: Record<string, unknown>;
    content: string;
    hasFrontmatter: boolean;
  } {
    const match = content.match(/^---\r?\n([\s\S]*?)\r?\n---\r?\n?([\s\S]*)$/);
    if (!match) {
      return { frontmatter: {}, content, hasFrontmatter: false };
    }
    try {
      const frontmatter = this.parseYaml(match[1]) as Record<string, unknown>;
      return { frontmatter, content: match[2], hasFrontmatter: true };
    } catch {
      return { frontmatter: {}, content, hasFrontmatter: false };
    }
  }

  /**
   * Extract title from frontmatter. Priority: title > aliases[0] > fileName
   */
  extractTitle(frontmatter: Record<string, unknown>, fileName: string): string {
    if (typeof frontmatter.title === 'string' && frontmatter.title.trim()) {
      return frontmatter.title.trim();
    }
    if (Array.isArray(frontmatter.aliases) && frontmatter.aliases.length > 0) {
      return String(frontmatter.aliases[0]).trim();
    }
    if (typeof frontmatter.aliases === 'string' && frontmatter.aliases.trim()) {
      return frontmatter.aliases.trim();
    }
    return fileName.replace(/\.md$/, '');
  }

  /**
   * Extract tags from frontmatter. Supports both array and comma-separated formats.
   */
  extractTags(frontmatter: Record<string, unknown>): string[] {
    const raw = frontmatter.tags;
    if (Array.isArray(raw)) {
      return raw.map(t => String(t).trim()).filter(Boolean);
    }
    if (typeof raw === 'string') {
      return raw.split(/[,，]/).map(t => t.trim()).filter(Boolean);
    }
    return [];
  }

  /**
   * Extract category from frontmatter.
   */
  extractCategory(frontmatter: Record<string, unknown>): string | undefined {
    if (typeof frontmatter.category === 'string' && frontmatter.category.trim()) {
      return frontmatter.category.trim();
    }
    return undefined;
  }

  /**
   * Simple YAML parser for basic key-value pairs, arrays, and strings.
   * Not a full YAML parser - handles the most common Obsidian frontmatter patterns.
   */
  private parseYaml(yaml: string): Record<string, unknown> {
    const result: Record<string, unknown> = {};
    const lines = yaml.split('\n');
    let currentKey = '';
    let currentArray: unknown[] = [];
    let inArray = false;

    for (const line of lines) {
      const trimmed = line.trim();
      if (!trimmed || trimmed.startsWith('#')) continue;

      if (inArray) {
        if (trimmed.startsWith('- ')) {
          currentArray.push(trimmed.slice(2).trim().replace(/^["']|["']$/g, ''));
        } else {
          // End of array
          result[currentKey] = currentArray;
          inArray = false;
          currentArray = [];
          // Fall through to process this line as a new key-value
          const kvMatch = trimmed.match(/^([^:]+):\s*(.*)$/);
          if (kvMatch) {
            currentKey = kvMatch[1].trim();
            const value = kvMatch[2].trim();
            if (value === '') {
              inArray = true;
            } else {
              result[currentKey] = this.parseValue(value);
            }
          }
        }
      } else {
        const kvMatch = trimmed.match(/^([^:]+):\s*(.*)$/);
        if (kvMatch) {
          currentKey = kvMatch[1].trim();
          const value = kvMatch[2].trim();
          if (value === '') {
            inArray = true;
          } else {
            result[currentKey] = this.parseValue(value);
          }
        }
      }
    }

    if (inArray) {
      result[currentKey] = currentArray;
    }

    return result;
  }

  private parseValue(value: string): unknown {
    // Remove surrounding quotes
    if ((value.startsWith('"') && value.endsWith('"')) || (value.startsWith("'") && value.endsWith("'"))) {
      return value.slice(1, -1);
    }
    // Boolean
    if (value === 'true') return true;
    if (value === 'false') return false;
    // Number
    const num = Number(value);
    if (!isNaN(num) && value !== '') return num;
    return value;
  }
}

export const frontmatterParser = new FrontmatterParser();
