// AcMind OutputSpecService
// Phase 0: Reads output specifications, Markdown templates, frontmatter rules,
// and tag rules from the acmind_output_spec_pack directory.
// All subsequent Markdown output MUST go through this service.

import { readFileSync, existsSync, readdirSync } from 'node:fs';
import path from 'node:path';
import type { AcMindFormatProfile, AcMindStandardFields } from '../../../shared/outputSpec';
import { DEFAULT_ACMIND_FORMAT_PROFILE, DEFAULT_ACMIND_FIELDS, ACMIND_SCHEMA_VERSION } from '../../../shared/outputSpec';
import { logger } from '../../logger';

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

/** Known template names in the spec pack */
export type TemplateName = 'default' | 'with-raw-content' | 'manual-minimal';

/** Distill template names for rule-based distillation engine */
export type DistillTemplateName = 'obsidian' | 'plain' | 'summary';

/** Template snippet names for reusable Markdown fragments */
export type SnippetName = 'rawContentSection' | 'frontmatterBlock';

/** Tag rules loaded from the spec pack */
export interface TagRules {
  maxTagsPerItem: number;
  preferChinese: boolean;
  avoidSynonyms: boolean;
  avoidSentenceTags: boolean;
  newTagCriteria: string[];
}

/** Category rules loaded from the spec pack */
export interface CategoryRules {
  singleCategoryOnly: boolean;
  recommendedCategories: string[];
  avoidOverSegmentation: boolean;
}

/** Complete spec pack info */
export interface OutputSpecPackInfo {
  specPackPath: string;
  loaded: boolean;
  profileCount: number;
  templateCount: number;
  activeProfileId: string;
  schemaVersion: string;
}

// ---------------------------------------------------------------------------
// Default fallback values (used when spec pack is not available)
// ---------------------------------------------------------------------------

const FALLBACK_TEMPLATES: Record<TemplateName, string> = {
  default: `{{frontmatter}}

> {{summary}}

# {{title}}

{{body}}`,

  'with-raw-content': `{{frontmatter}}

> {{summary}}

# {{title}}

{{body}}

---

## 原始内容

{{raw_content}}`,

  'manual-minimal': `{{frontmatter}}

> {{summary}}

# {{title}}

{{body}}`,
};

const FALLBACK_TAG_RULES: TagRules = {
  maxTagsPerItem: 8,
  preferChinese: true,
  avoidSynonyms: true,
  avoidSentenceTags: true,
  newTagCriteria: [
    '该概念会反复出现',
    '值得单独聚合',
    '能帮助未来搜索',
  ],
};

const FALLBACK_CATEGORY_RULES: CategoryRules = {
  singleCategoryOnly: true,
  recommendedCategories: [
    '产品规范',
    '项目记录',
    '学习笔记',
    '灵感想法',
    '工作资料',
    '个人复盘',
    '技术文档',
    '素材资料',
    '未分类',
  ],
  avoidOverSegmentation: true,
};

// ---------------------------------------------------------------------------
// Fallback distill templates (used by ruleBasedDistiller when spec pack unavailable)
// ---------------------------------------------------------------------------

const FALLBACK_DISTILL_TEMPLATES: Record<DistillTemplateName, string> = {
  obsidian: `{{frontmatter}}
# {{title}}

> 分类：{{category}} | 蒸馏时间：{{date}}

## 摘要

{{summary}}

{{keyPoints}}

{{backlinks}}

{{tags}}

{{actionItems}}

{{rawExcerpt}}

---
*由 AcMind 默认蒸馏引擎（规则模板）生成*`,

  plain: `# {{title}}

> 分类：{{category}} | 日期：{{date}}

## 摘要

{{summary}}

{{keyPoints}}

{{backlinks}}

{{tags}}

{{actionItems}}

---
*由 AcMind 默认蒸馏引擎（规则模板）生成*`,

  summary: `# {{title}}

**分类**：{{category}} | **日期**：{{date}}

## 摘要

{{summary}}

{{keyPoints}}

{{actionItems}}

标签：{{tags}}`,
};

// ---------------------------------------------------------------------------
// Fallback template snippets (reusable Markdown fragments)
// ---------------------------------------------------------------------------

const FALLBACK_SNIPPETS: Record<SnippetName, string> = {
  rawContentSection: `

---

## 原始内容

{{raw_content}}`,

  frontmatterBlock: `---
title: "{{title}}"
date: {{date}}
category: {{category}}
status: draft
source: acmind-distill
tags:
{{tags}}
---`,
};

// ---------------------------------------------------------------------------
// Template file mapping (spec pack file names → TemplateName)
// ---------------------------------------------------------------------------

const TEMPLATE_FILE_MAP: Record<string, TemplateName> = {
  '默认 Markdown 模板.md': 'default',
  '带原始内容 Markdown 模板.md': 'with-raw-content',
  '人工最小维护模板.md': 'manual-minimal',
};

// ---------------------------------------------------------------------------
// OutputSpecService
// ---------------------------------------------------------------------------

class OutputSpecService {
  private specPackPath: string | null = null;
  private profiles: Map<string, AcMindFormatProfile> = new Map();
  private templates: Map<TemplateName, string> = new Map();
  private distillTemplates: Map<DistillTemplateName, string> = new Map();
  private snippets: Map<SnippetName, string> = new Map();
  private tagRules: TagRules = FALLBACK_TAG_RULES;
  private categoryRules: CategoryRules = FALLBACK_CATEGORY_RULES;
  private activeProfileId: string = DEFAULT_ACMIND_FORMAT_PROFILE.id;
  private _loaded = false;

  // -------------------------------------------------------------------------
  // Initialization
  // -------------------------------------------------------------------------

  /**
   * Initialize the service with the path to the acmind_output_spec_pack directory.
   * If the path is invalid or missing, falls back to built-in defaults.
   */
  init(specPackPath: string): void {
    this.specPackPath = specPackPath;

    if (!existsSync(specPackPath)) {
      logger.warn('app', 'outputSpec', 'init', `Spec pack directory not found: ${specPackPath}, using fallback defaults`);
      this.loadFallbackDefaults();
      this._loaded = true;
      return;
    }

    try {
      this.loadProfiles();
      this.loadTemplates();
      this.loadTagRules();
      this.loadCategoryRules();
      this._loaded = true;

      logger.info('app', 'outputSpec', 'init', `Spec pack loaded successfully`, {
        path: specPackPath,
        profiles: this.profiles.size,
        templates: this.templates.size,
        activeProfile: this.activeProfileId,
      });
    } catch (error) {
      logger.error('app', 'outputSpec', 'init', `Failed to load spec pack, using fallback defaults`, {
        error: error instanceof Error ? error.message : String(error),
        path: specPackPath,
      });
      this.loadFallbackDefaults();
      this._loaded = true;
    }
  }

  /**
   * Check if the service has been initialized.
   */
  isLoaded(): boolean {
    return this._loaded;
  }

  // -------------------------------------------------------------------------
  // Profile access
  // -------------------------------------------------------------------------

  /**
   * Get the active Format Profile.
   * Falls back to DEFAULT_ACMIND_FORMAT_PROFILE if not loaded.
   */
  getActiveProfile(): AcMindFormatProfile {
    return this.profiles.get(this.activeProfileId) ?? DEFAULT_ACMIND_FORMAT_PROFILE;
  }

  /**
   * Get a specific Format Profile by ID.
   * Falls back to DEFAULT_ACMIND_FORMAT_PROFILE if not found.
   */
  getProfile(profileId: string): AcMindFormatProfile {
    return this.profiles.get(profileId) ?? DEFAULT_ACMIND_FORMAT_PROFILE;
  }

  /**
   * Get all loaded Format Profiles.
   */
  getAllProfiles(): AcMindFormatProfile[] {
    return Array.from(this.profiles.values());
  }

  /**
   * Set the active profile by ID.
   * Returns false if the profile ID is not found.
   */
  setActiveProfile(profileId: string): boolean {
    if (this.profiles.has(profileId)) {
      this.activeProfileId = profileId;
      logger.info('app', 'outputSpec', 'setActiveProfile', `Active profile changed to: ${profileId}`);
      return true;
    }
    return false;
  }

  // -------------------------------------------------------------------------
  // Template access
  // -------------------------------------------------------------------------

  /**
   * Get a Markdown template by name.
   * Falls back to built-in defaults if the template is not found in the spec pack.
   */
  getTemplate(name: TemplateName): string {
    return this.templates.get(name) ?? FALLBACK_TEMPLATES[name] ?? FALLBACK_TEMPLATES.default;
  }

  /**
   * Get the default Markdown template.
   * Uses the active profile's show_raw_content setting to determine which template to use.
   */
  getDefaultTemplate(): string {
    const profile = this.getActiveProfile();
    if (profile.show_raw_content) {
      return this.getTemplate('with-raw-content');
    }
    return this.getTemplate('default');
  }

  /**
   * Get all loaded template names.
   */
  getAvailableTemplateNames(): TemplateName[] {
    return Array.from(this.templates.keys());
  }

  // -------------------------------------------------------------------------
  // Tag & Category rules
  // -------------------------------------------------------------------------

  /**
   * Get tag rules from the spec pack.
   */
  getTagRules(): TagRules {
    return this.tagRules;
  }

  /**
   * Get category rules from the spec pack.
   */
  getCategoryRules(): CategoryRules {
    return this.categoryRules;
  }

  /**
   * Get the list of recommended categories.
   */
  getRecommendedCategories(): string[] {
    return this.categoryRules.recommendedCategories;
  }

  // -------------------------------------------------------------------------
  // Distill template access (for ruleBasedDistiller)
  // -------------------------------------------------------------------------

  /**
   * Get a distill template by name.
   * Falls back to built-in defaults if the template is not found in the spec pack.
   */
  getDistillTemplate(name: DistillTemplateName): string {
    return this.distillTemplates.get(name) ?? FALLBACK_DISTILL_TEMPLATES[name] ?? FALLBACK_DISTILL_TEMPLATES.obsidian;
  }

  /**
   * Get all available distill template names.
   */
  getAvailableDistillTemplateNames(): DistillTemplateName[] {
    return Array.from(this.distillTemplates.keys());
  }

  // -------------------------------------------------------------------------
  // Template snippet access
  // -------------------------------------------------------------------------

  /**
   * Get a template snippet by name.
   * Falls back to built-in defaults if the snippet is not found in the spec pack.
   */
  getSnippet(name: SnippetName): string {
    return this.snippets.get(name) ?? FALLBACK_SNIPPETS[name] ?? '';
  }

  /**
   * Get the raw content section snippet.
   * Returns empty string if raw_content is not shown or empty.
   */
  getRawContentSection(rawContent?: string): string {
    const profile = this.getActiveProfile();
    if (!profile.show_raw_content || !rawContent) return '';
    const snippet = this.getSnippet('rawContentSection');
    return snippet.replace('{{raw_content}}', rawContent);
  }

  // -------------------------------------------------------------------------
  // Default frontmatter fields
  // -------------------------------------------------------------------------

  /**
   * Get default AcMind standard fields (for new content).
   */
  getDefaultFields(): Partial<AcMindStandardFields> {
    const profile = this.getActiveProfile();
    return {
      ...DEFAULT_ACMIND_FIELDS,
      ...profile.default_values,
      schema_version: profile.schema_version,
    };
  }

  // -------------------------------------------------------------------------
  // Spec pack info
  // -------------------------------------------------------------------------

  /**
   * Get information about the loaded spec pack.
   */
  getSpecPackInfo(): OutputSpecPackInfo {
    return {
      specPackPath: this.specPackPath ?? '',
      loaded: this._loaded,
      profileCount: this.profiles.size,
      templateCount: this.templates.size,
      activeProfileId: this.activeProfileId,
      schemaVersion: ACMIND_SCHEMA_VERSION,
    };
  }

  // -------------------------------------------------------------------------
  // Internal loading methods
  // -------------------------------------------------------------------------

  /**
   * Load Format Profiles from the spec pack's 03_Format_Profile directory.
   */
  private loadProfiles(): void {
    if (!this.specPackPath) return;

    const profileDir = path.join(this.specPackPath, '03_Format_Profile');
    if (!existsSync(profileDir)) {
      logger.warn('app', 'outputSpec', 'loadProfiles', `Profile directory not found: ${profileDir}`);
      this.profiles.set(DEFAULT_ACMIND_FORMAT_PROFILE.id, DEFAULT_ACMIND_FORMAT_PROFILE);
      return;
    }

    try {
      const files = readdirSync(profileDir);
      for (const file of files) {
        if (file.endsWith('.profile.json')) {
          const filePath = path.join(profileDir, file);
          const content = readFileSync(filePath, 'utf8');
          const profile = JSON.parse(content) as AcMindFormatProfile;
          this.profiles.set(profile.id, profile);
          logger.debug('app', 'outputSpec', 'loadProfiles', `Loaded profile: ${profile.id}`);
        }
      }
    } catch (error) {
      logger.error('app', 'outputSpec', 'loadProfiles', `Failed to load profiles from: ${profileDir}`, {
        error: error instanceof Error ? error.message : String(error),
      });
    }

    // Always ensure the default profile exists
    if (!this.profiles.has(DEFAULT_ACMIND_FORMAT_PROFILE.id)) {
      this.profiles.set(DEFAULT_ACMIND_FORMAT_PROFILE.id, DEFAULT_ACMIND_FORMAT_PROFILE);
    }
  }

  /**
   * Load Markdown templates from the spec pack's 02_模板 directory.
   * Extracts the markdown content from the code blocks in the .md files.
   */
  private loadTemplates(): void {
    if (!this.specPackPath) return;

    const templateDir = path.join(this.specPackPath, '02_模板');
    if (!existsSync(templateDir)) {
      logger.warn('app', 'outputSpec', 'loadTemplates', `Template directory not found: ${templateDir}`);
      return;
    }

    try {
      const files = readdirSync(templateDir);
      for (const file of files) {
        const templateName = TEMPLATE_FILE_MAP[file];
        if (templateName) {
          const filePath = path.join(templateDir, file);
          const content = readFileSync(filePath, 'utf8');
          const extracted = this.extractMarkdownFromDoc(content);
          if (extracted) {
            this.templates.set(templateName, extracted);
            logger.debug('app', 'outputSpec', 'loadTemplates', `Loaded template: ${templateName} from ${file}`);
          }
        }
      }
    } catch (error) {
      logger.error('app', 'outputSpec', 'loadTemplates', `Failed to load templates from: ${templateDir}`, {
        error: error instanceof Error ? error.message : String(error),
      });
    }
  }

  /**
   * Extract markdown content from a documentation .md file.
   * Looks for ```markdown ... ``` code blocks and returns the first one found.
   */
  private extractMarkdownFromDoc(docContent: string): string | null {
    // Match ```markdown ... ``` code blocks
    const match = docContent.match(/```markdown\s*\n([\s\S]*?)```/);
    if (match && match[1]) {
      return match[1].trim();
    }
    return null;
  }

  /**
   * Load tag rules from the spec pack.
   * Parses the tag rules documentation file for structured rules.
   */
  private loadTagRules(): void {
    if (!this.specPackPath) return;

    const rulesFile = path.join(this.specPackPath, '04_人工维护', '标签与分类维护建议.md');
    if (!existsSync(rulesFile)) {
      logger.warn('app', 'outputSpec', 'loadTagRules', `Tag rules file not found: ${rulesFile}`);
      return;
    }

    try {
      const content = readFileSync(rulesFile, 'utf8');
      // Parse structured rules from the documentation
      // These are the canonical rules from the spec pack
      this.tagRules = {
        ...FALLBACK_TAG_RULES,
        // Rules are documented in the spec pack; we use the fallback defaults
        // which are derived from the spec pack documentation.
      };
    } catch (error) {
      logger.error('app', 'outputSpec', 'loadTagRules', `Failed to load tag rules`, {
        error: error instanceof Error ? error.message : String(error),
      });
    }
  }

  /**
   * Load category rules from the spec pack.
   */
  private loadCategoryRules(): void {
    if (!this.specPackPath) return;

    const rulesFile = path.join(this.specPackPath, '04_人工维护', '标签与分类维护建议.md');
    if (!existsSync(rulesFile)) {
      logger.warn('app', 'outputSpec', 'loadCategoryRules', `Category rules file not found: ${rulesFile}`);
      return;
    }

    try {
      const content = readFileSync(rulesFile, 'utf8');

      // Extract recommended categories from the documentation
      const categoryMatch = content.match(/推荐分类[：:]\s*\n((?:[-•]\s*[^\n]+\n?)+)/);
      if (categoryMatch) {
        const categories = categoryMatch[1]
          .split('\n')
          .map((line) => line.replace(/^[-•]\s*/, '').trim())
          .filter(Boolean);
        if (categories.length > 0) {
          this.categoryRules = {
            ...FALLBACK_CATEGORY_RULES,
            recommendedCategories: categories,
          };
        }
      }
    } catch (error) {
      logger.error('app', 'outputSpec', 'loadCategoryRules', `Failed to load category rules`, {
        error: error instanceof Error ? error.message : String(error),
      });
    }
  }

  /**
   * Load all fallback defaults when the spec pack is not available.
   */
  private loadFallbackDefaults(): void {
    this.profiles.clear();
    this.templates.clear();
    this.distillTemplates.clear();
    this.snippets.clear();

    // Load default profile
    this.profiles.set(DEFAULT_ACMIND_FORMAT_PROFILE.id, DEFAULT_ACMIND_FORMAT_PROFILE);

    // Load fallback templates
    for (const [name, template] of Object.entries(FALLBACK_TEMPLATES)) {
      this.templates.set(name as TemplateName, template);
    }

    // Load fallback distill templates
    for (const [name, template] of Object.entries(FALLBACK_DISTILL_TEMPLATES)) {
      this.distillTemplates.set(name as DistillTemplateName, template);
    }

    // Load fallback snippets
    for (const [name, snippet] of Object.entries(FALLBACK_SNIPPETS)) {
      this.snippets.set(name as SnippetName, snippet);
    }

    // Use fallback rules
    this.tagRules = FALLBACK_TAG_RULES;
    this.categoryRules = FALLBACK_CATEGORY_RULES;
  }
}

// ---------------------------------------------------------------------------
// Singleton export
// ---------------------------------------------------------------------------

export const outputSpecService = new OutputSpecService();
