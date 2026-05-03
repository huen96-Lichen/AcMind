import { describe, expect, it, vi, beforeEach } from 'vitest';
import path from 'node:path';
import fs from 'node:fs';
import os from 'node:os';

// Mock logger
vi.mock('../../logger', () => ({
  logger: { info: vi.fn(), warn: vi.fn(), error: vi.fn(), debug: vi.fn() },
}));

import { outputSpecService } from './outputSpecService';

describe('outputSpecService', () => {
  let tmpDir: string;

  beforeEach(() => {
    tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'spec-test-'));
    vi.clearAllMocks();
  });

  describe('fallback defaults (no spec pack)', () => {
    it('initializes with fallback defaults when path is empty', () => {
      outputSpecService.init('');
      expect(outputSpecService.isLoaded()).toBe(true);
    });

    it('initializes with fallback defaults when path does not exist', () => {
      outputSpecService.init('/non/existent/path');
      expect(outputSpecService.isLoaded()).toBe(true);
    });

    it('returns default template from fallback', () => {
      outputSpecService.init('');
      const template = outputSpecService.getDefaultTemplate();
      expect(template).toContain('{{frontmatter}}');
      expect(template).toContain('{{title}}');
      expect(template).toContain('{{summary}}');
      expect(template).toContain('{{body}}');
    });

    it('returns with-raw-content template when profile requests it', () => {
      outputSpecService.init('');
      // The default profile has show_raw_content: false, so getDefaultTemplate returns 'default'
      const template = outputSpecService.getDefaultTemplate();
      expect(template).not.toContain('## 原始内容');

      // Explicitly get the with-raw-content template
      const rawTemplate = outputSpecService.getTemplate('with-raw-content');
      expect(rawTemplate).toContain('## 原始内容');
      expect(rawTemplate).toContain('{{raw_content}}');
    });

    it('returns tag rules from fallback', () => {
      outputSpecService.init('');
      const rules = outputSpecService.getTagRules();
      expect(rules.maxTagsPerItem).toBe(8);
      expect(rules.preferChinese).toBe(true);
    });

    it('returns category rules from fallback', () => {
      outputSpecService.init('');
      const rules = outputSpecService.getCategoryRules();
      expect(rules.singleCategoryOnly).toBe(true);
      expect(rules.recommendedCategories).toContain('未分类');
      expect(rules.recommendedCategories).toContain('技术文档');
    });

    it('returns active profile from fallback', () => {
      outputSpecService.init('');
      const profile = outputSpecService.getActiveProfile();
      expect(profile.id).toBe('acmind-default');
      expect(profile.frontmatter_style).toBe('yaml');
      expect(profile.filename_pattern).toContain('{{title}}');
    });

    it('returns spec pack info', () => {
      outputSpecService.init('');
      const info = outputSpecService.getSpecPackInfo();
      expect(info.loaded).toBe(true);
      expect(info.profileCount).toBeGreaterThanOrEqual(1);
      expect(info.templateCount).toBeGreaterThanOrEqual(1);
      expect(info.activeProfileId).toBe('acmind-default');
    });
  });

  describe('loading from spec pack directory', () => {
    it('loads profile from .profile.json file', () => {
      const profileDir = path.join(tmpDir, '03_Format_Profile');
      fs.mkdirSync(profileDir, { recursive: true });

      fs.writeFileSync(path.join(profileDir, 'test.profile.json'), JSON.stringify({
        id: 'test-profile',
        name: 'Test Profile',
        schema_version: '0.2',
        frontmatter_style: 'yaml',
        field_mapping: {
          schema_version: 'schema_version',
          title: 'title',
          summary: 'summary',
          tags: 'tags',
          category: 'category',
          source: 'source',
          captured_at: 'captured_at',
          project: 'project',
          status: 'status',
          confidence: 'confidence',
        },
        filename_pattern: '{{title}}.md',
        date_format: 'YYYY-MM-DD HH:mm',
        filename_date_format: 'YYYY-MM-DD HH-mm',
        show_summary_quote: false,
        show_raw_content: false,
        title_heading_level: 2,
        sanitize_filename: true,
        forbidden_filename_chars: [],
        default_values: {},
      }));

      outputSpecService.init(tmpDir);

      const profile = outputSpecService.getProfile('test-profile');
      expect(profile.id).toBe('test-profile');
      expect(profile.title_heading_level).toBe(2);
    });

    it('loads template from markdown code block in .md file', () => {
      const templateDir = path.join(tmpDir, '02_模板');
      fs.mkdirSync(templateDir, { recursive: true });

      fs.writeFileSync(path.join(templateDir, '默认 Markdown 模板.md'), `
# 默认 Markdown 模板

这是说明文档。

\`\`\`markdown
---
title: "{{title}}"
custom_field: "hello"
---

# {{title}}

{{body}}
\`\`\`
`);

      outputSpecService.init(tmpDir);

      const template = outputSpecService.getTemplate('default');
      expect(template).toContain('custom_field: "hello"');
      expect(template).toContain('{{title}}');
      // Should NOT contain the documentation text
      expect(template).not.toContain('这是说明文档');
    });
  });

  describe('template consistency', () => {
    it('all fallback templates use {{frontmatter}} placeholder', () => {
      outputSpecService.init('');

      const templateNames = ['default', 'with-raw-content', 'manual-minimal'] as const;
      for (const name of templateNames) {
        const template = outputSpecService.getTemplate(name);
        expect(template, `Template "${name}" should use {{frontmatter}}`).toContain('{{frontmatter}}');
      }
    });

    it('all fallback templates contain standard placeholders', () => {
      outputSpecService.init('');

      const templateNames = ['default', 'with-raw-content', 'manual-minimal'] as const;
      for (const name of templateNames) {
        const template = outputSpecService.getTemplate(name);
        expect(template, `Template "${name}" should contain {{title}}`).toContain('{{title}}');
        expect(template, `Template "${name}" should contain {{summary}}`).toContain('{{summary}}');
        expect(template, `Template "${name}" should contain {{body}}`).toContain('{{body}}');
      }
    });
  });
});
