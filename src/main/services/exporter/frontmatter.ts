// AcMind YAML Frontmatter Generator
// Generates and parses YAML frontmatter blocks for Obsidian notes

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

export interface FrontmatterData {
  title?: string;
  created?: string;
  updated?: string;
  source_type?: string;
  source_id?: string;
  status?: string;
  tags?: string[];
  summary?: string;
  category?: string;
  value_score?: number;
  [key: string]: unknown;
}

// ---------------------------------------------------------------------------
// YAML escaping helpers
// ---------------------------------------------------------------------------

/**
 * Escape a string value for safe YAML inclusion.
 * Uses double quotes when the value contains special characters.
 */
function escapeYamlValue(value: unknown): string {
  if (value === null || value === undefined) {
    return 'null';
  }

  if (typeof value === 'boolean') {
    return value ? 'true' : 'false';
  }

  if (typeof value === 'number') {
    return String(value);
  }

  const str = String(value);

  // Check if the value needs quoting
  const needsQuoting =
    str === '' ||
    str === 'true' ||
    str === 'false' ||
    str === 'null' ||
    str === 'yes' ||
    str === 'no' ||
    str === 'on' ||
    str === 'off' ||
    /^[\d.]+$/.test(str) || // looks like a number
    /[:#{}[\],&*?|>!%@`'"\n\r]/.test(str) || // contains special chars
    str.startsWith('-') || // starts with dash
    str.startsWith(' ') || // starts with space
    str.endsWith(' '); // ends with space

  if (!needsQuoting) {
    return str;
  }

  // Use double-quoted string with proper escaping
  const escaped = str
    .replace(/\\/g, '\\\\')
    .replace(/"/g, '\\"')
    .replace(/\n/g, '\\n')
    .replace(/\r/g, '\\r')
    .replace(/\t/g, '\\t');

  return `"${escaped}"`;
}

/**
 * Format a YAML key (already assumed to be safe).
 */
function formatYamlKey(key: string): string {
  // Keys with special characters need quoting
  if (/[:#{}[\],&*?|>!%@`'" \n\r]/.test(key) || /^\d/.test(key)) {
    return `"${key.replace(/\\/g, '\\\\').replace(/"/g, '\\"')}"`;
  }
  return key;
}

// ---------------------------------------------------------------------------
// FrontmatterGenerator
// ---------------------------------------------------------------------------

class FrontmatterGenerator {
  /**
   * Generate a YAML frontmatter block from a data object.
   * Returns the complete frontmatter string including delimiters.
   */
  generate(data: Record<string, unknown>): string {
    const lines: string[] = ['---'];

    for (const [key, value] of Object.entries(data)) {
      if (value === undefined || value === null) continue;

      const formattedKey = formatYamlKey(key);

      if (Array.isArray(value)) {
        if (value.length === 0) {
          lines.push(`${formattedKey}: []`);
        } else {
          lines.push(`${formattedKey}:`);
          for (const item of value) {
            lines.push(`  - ${escapeYamlValue(item)}`);
          }
        }
      } else if (typeof value === 'object') {
        // Nested object - format as YAML mapping
        const obj = value as Record<string, unknown>;
        const entries = Object.entries(obj).filter(([, v]) => v !== undefined && v !== null);
        if (entries.length === 0) continue;

        lines.push(`${formattedKey}:`);
        for (const [subKey, subValue] of entries) {
          lines.push(`  ${formatYamlKey(subKey)}: ${escapeYamlValue(subValue)}`);
        }
      } else {
        lines.push(`${formattedKey}: ${escapeYamlValue(value)}`);
      }
    }

    lines.push('---');
    return lines.join('\n');
  }

  /**
   * Parse a YAML frontmatter block from a string.
   * Extracts the content between --- delimiters and parses key-value pairs.
   */
  parse(frontmatterStr: string): Record<string, unknown> {
    const result: Record<string, unknown> = {};

    // Extract content between --- delimiters
    const match = frontmatterStr.match(/^---\n([\s\S]*?)\n---/);
    if (!match) {
      return result;
    }

    const content = match[1];
    const lines = content.split('\n');

    let currentKey = '';
    let isArray = false;
    let isObject = false;
    let currentArray: unknown[] = [];
    let currentObject: Record<string, unknown> = {};

    for (const line of lines) {
      // Array item
      if (/^\s+-\s+/.test(line)) {
        if (!isArray) {
          // Start of a new array
          isArray = true;
          isObject = false;
          currentArray = [];
        }
        const value = line.replace(/^\s+-\s+/, '').trim();
        currentArray.push(this.parseYamlValue(value));
        continue;
      }

      // Nested object property
      if (/^\s{2,}/.test(line) && isObject) {
        const kvMatch = line.trim().match(/^([^:]+):\s*(.*)/);
        if (kvMatch) {
          currentObject[kvMatch[1].trim()] = this.parseYamlValue(kvMatch[2].trim());
        }
        continue;
      }

      // Flush previous array/object
      if (isArray && currentKey) {
        result[currentKey] = currentArray;
        currentArray = [];
        isArray = false;
      }
      if (isObject && currentKey) {
        result[currentKey] = currentObject;
        currentObject = {};
        isObject = false;
      }

      // Key-value pair
      const kvMatch = line.match(/^([^:]+):\s*(.*)/);
      if (kvMatch) {
        currentKey = kvMatch[1].trim();
        const rawValue = kvMatch[2].trim();

        if (rawValue === '' || rawValue === '|' || rawValue === '>') {
          // Could be start of multi-line value or nested structure
          // For now, treat as object start if next lines are indented
          isObject = true;
          currentObject = {};
        } else if (rawValue === '[]') {
          result[currentKey] = [];
        } else {
          result[currentKey] = this.parseYamlValue(rawValue);
        }
      }
    }

    // Flush final array/object
    if (isArray && currentKey) {
      result[currentKey] = currentArray;
    }
    if (isObject && currentKey) {
      result[currentKey] = currentObject;
    }

    return result;
  }

  /**
   * Parse a single YAML value string into its appropriate type.
   */
  private parseYamlValue(value: string): unknown {
    // Remove surrounding quotes
    if ((value.startsWith('"') && value.endsWith('"')) ||
        (value.startsWith("'") && value.endsWith("'"))) {
      return value.slice(1, -1)
        .replace(/\\n/g, '\n')
        .replace(/\\r/g, '\r')
        .replace(/\\t/g, '\t')
        .replace(/\\"/g, '"')
        .replace(/\\\\/g, '\\');
    }

    // Boolean
    if (value === 'true') return true;
    if (value === 'false') return false;

    // Null
    if (value === 'null' || value === '~') return null;

    // Number
    if (/^-?\d+$/.test(value)) return parseInt(value, 10);
    if (/^-?\d+\.\d+$/.test(value)) return parseFloat(value);

    // String
    return value;
  }
}

// ---------------------------------------------------------------------------
// Singleton export
// ---------------------------------------------------------------------------

export const frontmatterGenerator = new FrontmatterGenerator();
