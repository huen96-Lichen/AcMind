// AcMind Strategy System Tests
// Phase 8.1-8.6: 完整测试覆盖

import { describe, it, expect } from 'vitest';
import type { CaptureRecord, SourceType, ProviderConfig } from '../../../shared/types';
import { strategyRegistry } from './strategyRegistry';
import { strategyProcessor } from './strategyProcessor';
import { promptProfileRegistry, renderTemplate } from './promptProfile';
import { modelRouter } from './modelRouter';
import { outputValidator } from './outputValidator';
import { qualityFallback } from './qualityFallback';
import type { StrategyInput, ProcessedContent } from './types';
import type { ModelTier, RoutingContext } from './modelRouter';

// ---------------------------------------------------------------------------
// Helper: create a minimal CaptureRecord
// ---------------------------------------------------------------------------

function makeCaptureRecord(overrides: Partial<CaptureRecord> = {}): CaptureRecord {
  return {
    id: 'test-id',
    source_type: 'manual_text',
    raw_text: '测试内容',
    created_at: Date.now(),
    original_id: 'test-original-id',
    ...overrides,
  };
}

function makeProviders(overrides: Partial<ProviderConfig>[] = []): ProviderConfig[] {
  const defaults: ProviderConfig[] = [
    { id: 'local', name: 'Local Model', tier: 'local_light', enabled: true, configured: true },
    { id: 'cloud-std', name: 'Cloud Standard', tier: 'cloud_standard', enabled: true, configured: true },
    { id: 'cloud-adv', name: 'Cloud Advanced', tier: 'cloud_advanced', enabled: true, configured: true },
  ];
  return defaults.map((d, i) => ({ ...d, ...(overrides[i] ?? {}) }));
}

// ===========================================================================
// Phase 8.1: Strategy Registry
// ===========================================================================

describe('Phase 8.1 - StrategyRegistry', () => {
  it('should have strategies for all source_types', () => {
    const sourceTypes: SourceType[] = [
      'manual_text', 'clipboard_text', 'screenshot', 'webpage',
      'file', 'image', 'audio', 'video', 'pdf', 'docx', 'unknown_file',
    ];
    for (const sourceType of sourceTypes) {
      expect(strategyRegistry.hasStrategy(sourceType)).toBe(true);
    }
  });

  it('should return correct strategy for each source_type', () => {
    expect(strategyRegistry.getStrategy('manual_text').name).toBe('manual_text');
    expect(strategyRegistry.getStrategy('clipboard_text').name).toBe('clipboard_text');
    expect(strategyRegistry.getStrategy('screenshot').name).toBe('screenshot');
    expect(strategyRegistry.getStrategy('webpage').name).toBe('webpage');
    expect(strategyRegistry.getStrategy('file').name).toBe('file');
    expect(strategyRegistry.getStrategy('image').name).toBe('image');
    expect(strategyRegistry.getStrategy('audio').name).toBe('audio');
    expect(strategyRegistry.getStrategy('video').name).toBe('video');
    expect(strategyRegistry.getStrategy('pdf').name).toBe('pdf');
    expect(strategyRegistry.getStrategy('docx').name).toBe('docx');
    expect(strategyRegistry.getStrategy('unknown_file').name).toBe('unknown_file');
  });

  it('should return unknown_file strategy as fallback for unregistered types', () => {
    // @ts-expect-error Testing unregistered type
    const strategy = strategyRegistry.getStrategy('nonexistent');
    expect(strategy.name).toBe('unknown_file');
  });
});

// ===========================================================================
// Phase 8.1: Individual Strategy Tests
// ===========================================================================

describe('Phase 8.1 - ManualTextStrategy', () => {
  it('should build prompt with user content', () => {
    const input: StrategyInput = { source_type: 'manual_text', content: '今天学习了 TypeScript 的泛型' };
    const prompt = strategyProcessor.buildPrompt(input);
    expect(prompt).toContain('用户主动输入');
    expect(prompt).toContain('今天学习了 TypeScript 的泛型');
    expect(prompt).toContain('保留用户原意');
  });

  it('should post-process AI output correctly', () => {
    const input: StrategyInput = { source_type: 'manual_text', content: '原始内容' };
    const raw = {
      title: 'TypeScript 学习笔记', summary: '学习了泛型',
      tags: ['TypeScript', '学习'], body_markdown: '# TypeScript 学习笔记\n\n学习了泛型',
      suggested_folder: 'Inbox/学习', quality_flags: [],
    };
    const result = strategyProcessor.postProcess(raw, input);
    expect(result.title).toBe('TypeScript 学习笔记');
    expect(result.summary).toBe('学习了泛型');
    expect(result.tags).toEqual(['TypeScript', '学习']);
  });
});

describe('Phase 8.1 - ClipboardTextStrategy', () => {
  it('should build prompt for clipboard content', () => {
    const input: StrategyInput = { source_type: 'clipboard_text', content: '从网页复制的一段文字' };
    const prompt = strategyProcessor.buildPrompt(input);
    expect(prompt).toContain('剪贴板');
    expect(prompt).toContain('摘录');
  });
});

describe('Phase 8.1 - WebpageStrategy', () => {
  it('should build prompt with source_url', () => {
    const input: StrategyInput = { source_type: 'webpage', content: '网页正文', source_url: 'https://example.com/article' };
    const prompt = strategyProcessor.buildPrompt(input);
    expect(prompt).toContain('https://example.com/article');
  });

  it('should preserve source_url in postProcess output', () => {
    const input: StrategyInput = { source_type: 'webpage', content: '网页正文', source_url: 'https://example.com/article' };
    const raw = { title: '示例文章', summary: '这是一篇示例文章', tags: ['网页'], body_markdown: '---\ntitle: "示例文章"\n---\n\n正文内容', suggested_folder: 'Inbox/Web', quality_flags: [] };
    const result = strategyProcessor.postProcess(raw, input);
    expect(result.body_markdown).toContain('https://example.com/article');
  });

  it('should generate placeholder when content is empty', () => {
    const input: StrategyInput = { source_type: 'webpage', content: '', source_url: 'https://example.com' };
    const result = strategyProcessor.postProcess({}, input);
    expect(result.quality_flags).toContain('placeholder');
    expect(result.summary).toContain('等待后续处理');
  });
});

describe('Phase 8.1 - ScreenshotStrategy', () => {
  it('should generate placeholder when no OCR text', () => {
    const input: StrategyInput = { source_type: 'screenshot', content: '', raw_file_path: '/path/to/screenshot.png' };
    const result = strategyProcessor.postProcess({}, input);
    expect(result.quality_flags).toContain('needs_ocr');
    expect(result.quality_flags).toContain('placeholder');
    expect(result.summary).toContain('等待 OCR');
    expect(result.body_markdown).not.toContain('OCR 提取');
  });

  it('should process OCR text when available', () => {
    const input: StrategyInput = { source_type: 'screenshot', content: '', raw_file_path: '/path/to/screenshot.png', extracted_text: '截图中的文字内容' };
    const prompt = strategyProcessor.buildPrompt(input);
    expect(prompt).toContain('截图中的文字内容');
    expect(prompt).toContain('OCR');
  });
});

describe('Phase 8.1 - AudioStrategy', () => {
  it('should generate placeholder when no transcript', () => {
    const input: StrategyInput = { source_type: 'audio', content: '', raw_file_path: '/path/to/audio.mp3' };
    const result = strategyProcessor.postProcess({}, input);
    expect(result.quality_flags).toContain('needs_transcription');
    expect(result.quality_flags).toContain('placeholder');
    expect(result.summary).toContain('等待转写');
  });

  it('should process transcript when available', () => {
    const input: StrategyInput = { source_type: 'audio', content: '', raw_file_path: '/path/to/audio.mp3', transcript_text: '音频转写文本内容' };
    const prompt = strategyProcessor.buildPrompt(input);
    expect(prompt).toContain('音频转写文本内容');
  });
});

describe('Phase 8.1 - VideoStrategy', () => {
  it('should generate placeholder when no transcript', () => {
    const input: StrategyInput = { source_type: 'video', content: '', raw_file_path: '/path/to/video.mp4' };
    const result = strategyProcessor.postProcess({}, input);
    expect(result.quality_flags).toContain('needs_transcription');
    expect(result.quality_flags).toContain('placeholder');
  });
});

describe('Phase 8.1 - FileStrategy', () => {
  it('should process .txt files with content', () => {
    const input: StrategyInput = { source_type: 'file', content: '文本文件内容', raw_file_path: '/path/to/file.txt', file_ext: '.txt' };
    const prompt = strategyProcessor.buildPrompt(input);
    expect(prompt).toContain('文本文件内容');
  });

  it('should generate placeholder for non-text files', () => {
    const input: StrategyInput = { source_type: 'file', content: '', raw_file_path: '/path/to/file.zip', file_ext: '.zip' };
    const result = strategyProcessor.postProcess({}, input);
    expect(result.quality_flags).toContain('placeholder');
    expect(result.quality_flags).toContain('incomplete');
  });
});

describe('Phase 8.1 - PdfStrategy', () => {
  it('should generate placeholder when no parsed content', () => {
    const input: StrategyInput = { source_type: 'pdf', content: '', raw_file_path: '/path/to/doc.pdf' };
    const result = strategyProcessor.postProcess({}, input);
    expect(result.quality_flags).toContain('placeholder');
    expect(result.summary).toContain('等待解析');
  });

  it('should process parsed markdown when available', () => {
    const input: StrategyInput = { source_type: 'pdf', content: '', raw_file_path: '/path/to/doc.pdf', parsed_markdown: '# PDF 标题\n\nPDF 正文内容' };
    const prompt = strategyProcessor.buildPrompt(input);
    expect(prompt).toContain('PDF 标题');
  });
});

describe('Phase 8.1 - DocxStrategy', () => {
  it('should generate placeholder when no parsed content', () => {
    const input: StrategyInput = { source_type: 'docx', content: '', raw_file_path: '/path/to/doc.docx' };
    const result = strategyProcessor.postProcess({}, input);
    expect(result.quality_flags).toContain('placeholder');
  });
});

describe('Phase 8.1 - ImageStrategy', () => {
  it('should generate placeholder when no OCR text', () => {
    const input: StrategyInput = { source_type: 'image', content: '', raw_file_path: '/path/to/image.png' };
    const result = strategyProcessor.postProcess({}, input);
    expect(result.quality_flags).toContain('needs_ocr');
    expect(result.quality_flags).toContain('placeholder');
  });
});

describe('Phase 8.1 - UnknownFileStrategy', () => {
  it('should generate direct output without AI', () => {
    const input: StrategyInput = { source_type: 'unknown_file', content: '', raw_file_path: '/path/to/file.xyz', file_ext: '.xyz' };
    const directOutput = strategyProcessor.generateDirectOutput(input);
    expect(directOutput).not.toBeNull();
    expect(directOutput!.quality_flags).toContain('fallback_used');
    expect(directOutput!.quality_flags).toContain('placeholder_generated');
  });
});

// ===========================================================================
// Phase 8.2: Prompt Profile System
// ===========================================================================

describe('Phase 8.2 - PromptProfileRegistry', () => {
  it('should have profiles for all source_types', () => {
    const sourceTypes: SourceType[] = [
      'manual_text', 'clipboard_text', 'screenshot', 'webpage',
      'file', 'image', 'audio', 'video', 'pdf', 'docx',
    ];
    for (const sourceType of sourceTypes) {
      const profile = promptProfileRegistry.getProfile(sourceType);
      expect(profile).toBeDefined();
      expect(profile.source_type).toBe(sourceType);
    }
  });

  it('should return default profile for unknown source_type', () => {
    // @ts-expect-error Testing unregistered type
    const profile = promptProfileRegistry.getProfile('nonexistent');
    expect(profile.profile_id).toBe('acmind.default.v1');
    expect(profile.source_type).toBe('default');
  });

  it('each profile should have required fields', () => {
    const profiles = promptProfileRegistry.getAllProfiles();
    for (const profile of profiles) {
      expect(profile.profile_id).toBeTruthy();
      expect(profile.name).toBeTruthy();
      expect(profile.version).toBeTruthy();
      expect(profile.system_prompt).toBeTruthy();
      expect(profile.user_prompt_template).toBeTruthy();
      expect(profile.output_schema).toBeDefined();
      expect(profile.constraints.length).toBeGreaterThan(0);
    }
  });

  it('should support profile versioning via getProfileById', () => {
    const profile = promptProfileRegistry.getProfileById('acmind.manual_text.v1');
    expect(profile).toBeDefined();
    expect(profile!.version).toBe('1.0.0');
  });

  it('should build full prompt with template variables', () => {
    const { systemPrompt, userPrompt, profileId } = promptProfileRegistry.buildFullPrompt(
      'manual_text',
      { content: '测试内容' },
    );
    expect(systemPrompt).toBeTruthy();
    expect(userPrompt).toContain('测试内容');
    expect(userPrompt).toContain('输出格式');
    expect(userPrompt).toContain('约束条件');
    expect(profileId).toBe('acmind.manual_text.v1');
  });

  it('webpage profile should include source_url in prompt', () => {
    const { userPrompt } = promptProfileRegistry.buildFullPrompt(
      'webpage',
      { content: '正文', source_url: 'https://example.com' },
    );
    expect(userPrompt).toContain('https://example.com');
    expect(userPrompt).toContain('source_url');
  });

  it('should render template variables correctly', () => {
    const result = renderTemplate('Hello {{name}}, your age is {{age}}', { name: 'World', age: '25' });
    expect(result).toBe('Hello World, your age is 25');
  });

  it('should handle missing template variables gracefully', () => {
    const result = renderTemplate('Hello {{name}}', {});
    expect(result).toBe('Hello ');
  });
});

// ===========================================================================
// Phase 8.3: Model Router
// ===========================================================================

describe('Phase 8.3 - ModelRouter', () => {
  it('should route manual_text to cloud_standard by default', () => {
    const input: StrategyInput = { source_type: 'manual_text', content: '这是一段中等长度的文本内容，需要进行整理和归纳。包含足够的信息量以便正确路由。'.repeat(10) };
    const decision = modelRouter.route({
      sourceType: 'manual_text', input, defaultTier: 'cloud_standard',
      privacyMode: false, allowCloud: true, availableProviders: makeProviders(),
    });
    expect(decision.tier).toBe('cloud_standard');
    expect(decision.provider).not.toBeNull();
  });

  it('should route placeholder types to local_light', () => {
    const input: StrategyInput = { source_type: 'audio', content: '' };
    const decision = modelRouter.route({
      sourceType: 'audio', input, defaultTier: 'cloud_standard',
      privacyMode: false, allowCloud: true, availableProviders: makeProviders(),
    });
    expect(decision.tier).toBe('local_light');
  });

  it('should prefer local_light in privacy mode', () => {
    const input: StrategyInput = { source_type: 'manual_text', content: '敏感内容' };
    const decision = modelRouter.route({
      sourceType: 'manual_text', input, defaultTier: 'cloud_standard',
      privacyMode: true, allowCloud: true, availableProviders: makeProviders(),
    });
    expect(decision.tier).toBe('local_light');
    expect(decision.needsPrivacyConfirmation).toBeFalsy();
  });

  it('should set needsPrivacyConfirmation when local not available in privacy mode', () => {
    const providers = makeProviders([{ enabled: false }]);
    const input: StrategyInput = { source_type: 'manual_text', content: '敏感内容' };
    const decision = modelRouter.route({
      sourceType: 'manual_text', input, defaultTier: 'cloud_standard',
      privacyMode: true, allowCloud: true, availableProviders: providers,
    });
    expect(decision.needsPrivacyConfirmation).toBe(true);
  });

  it('should block cloud when allowCloud is false', () => {
    const input: StrategyInput = { source_type: 'manual_text', content: '内容' };
    const decision = modelRouter.route({
      sourceType: 'manual_text', input, defaultTier: 'cloud_standard',
      privacyMode: false, allowCloud: false, availableProviders: makeProviders(),
    });
    expect(decision.tier).toBe('local_light');
  });

  it('should suggest upgrade for long text', () => {
    const longContent = 'a'.repeat(6000);
    const input: StrategyInput = { source_type: 'manual_text', content: longContent };
    const decision = modelRouter.route({
      sourceType: 'manual_text', input, defaultTier: 'cloud_standard',
      privacyMode: false, allowCloud: true, availableProviders: makeProviders(),
    });
    expect(decision.upgradeSuggestion).toBeDefined();
    expect(decision.upgradeSuggestion!.suggestedTier).toBe('cloud_advanced');
  });

  it('should route complex content to cloud_advanced', () => {
    const input: StrategyInput = { source_type: 'manual_text', content: 'a'.repeat(6000) };
    const decision = modelRouter.route({
      sourceType: 'manual_text', input, defaultTier: 'cloud_standard',
      privacyMode: false, allowCloud: true, availableProviders: makeProviders(),
      taskComplexity: 0.8,
    });
    expect(decision.tier).toBe('cloud_advanced');
  });

  it('should fallback to lower tier when provider unavailable', () => {
    // Disable both cloud_advanced and cloud_standard to trigger fallbackToLowerTier
    const providers = makeProviders([{}, { enabled: false }, { enabled: false }]);
    const input: StrategyInput = { source_type: 'manual_text', content: 'a'.repeat(6000) };
    const decision = modelRouter.route({
      sourceType: 'manual_text', input, defaultTier: 'cloud_advanced',
      privacyMode: false, allowCloud: true, availableProviders: providers,
      taskComplexity: 0.8,
    });
    // Should fallback to local_light since both cloud tiers are disabled
    expect(decision.tier).toBe('local_light');
  });

  it('should return null provider when no providers available', () => {
    const input: StrategyInput = { source_type: 'manual_text', content: '内容' };
    const decision = modelRouter.route({
      sourceType: 'manual_text', input, defaultTier: 'cloud_standard',
      privacyMode: false, allowCloud: true, availableProviders: [],
    });
    expect(decision.provider).toBeNull();
  });
});

// ===========================================================================
// Phase 8.4: Output Validator
// ===========================================================================

describe('Phase 8.4 - OutputValidator', () => {
  it('should pass valid output', () => {
    const raw = {
      title: '有效标题', summary: '这是一个有效的摘要内容',
      tags: ['tag1', 'tag2'], body_markdown: '# 正文\n\n内容',
      suggested_folder: 'Inbox', quality_flags: [],
    };
    const input: StrategyInput = { source_type: 'manual_text', content: '原始内容' };
    const result = outputValidator.validate(raw, input);
    expect(result.valid).toBe(true);
    expect(result.flags).toEqual([]);
    expect(result.wasFixed).toBe(false);
  });

  it('should fix missing title', () => {
    const raw = { title: '', summary: '摘要', tags: [], body_markdown: '正文', suggested_folder: 'Inbox', quality_flags: [] };
    const input: StrategyInput = { source_type: 'manual_text', content: '原始内容' };
    const result = outputValidator.validate(raw, input);
    expect(result.flags).toContain('title_missing');
    expect(result.content.title).toBeTruthy();
    expect(result.wasFixed).toBe(true);
  });

  it('should fix missing summary', () => {
    const raw = { title: '标题', summary: '', tags: [], body_markdown: '正文', suggested_folder: 'Inbox', quality_flags: [] };
    const input: StrategyInput = { source_type: 'manual_text', content: '原始内容' };
    const result = outputValidator.validate(raw, input);
    expect(result.flags).toContain('summary_missing');
    expect(result.content.summary).toBe('等待后续处理');
  });

  it('should fix invalid tags', () => {
    // Use an array with non-string elements to trigger tags_invalid
    // extractTags filters out non-strings, so validTags.length !== tags.length
    const raw = { title: '标题', summary: '这是一个有效的摘要', tags: [123, null, undefined, 'valid'], body_markdown: '正文', suggested_folder: 'Inbox', quality_flags: [] };
    const input: StrategyInput = { source_type: 'manual_text', content: '原始内容' };
    const result = outputValidator.validate(raw, input);
    expect(result.flags).toContain('tags_invalid');
    expect(Array.isArray(result.content.tags)).toBe(true);
    expect(result.content.tags).toEqual(['valid']);
  });

  it('should fix empty body_markdown', () => {
    const raw = { title: '标题', summary: '摘要', tags: [], body_markdown: '', suggested_folder: 'Inbox', quality_flags: [] };
    const input: StrategyInput = { source_type: 'manual_text', content: '原始内容' };
    const result = outputValidator.validate(raw, input);
    expect(result.flags).toContain('body_empty');
    expect(result.content.body_markdown).toBeTruthy();
  });

  it('should strip YAML frontmatter from body_markdown', () => {
    const raw = { title: '标题', summary: '摘要', tags: [], body_markdown: '---\ntitle: "test"\n---\n\n正文', suggested_folder: 'Inbox', quality_flags: [] };
    const input: StrategyInput = { source_type: 'manual_text', content: '原始内容' };
    const result = outputValidator.validate(raw, input);
    expect(result.flags).toContain('markdown_invalid');
    expect(result.content.body_markdown).not.toContain('---');
    expect(result.content.body_markdown).toContain('正文');
  });

  it('should detect placeholder patterns', () => {
    const raw = { title: '标题', summary: '摘要', tags: [], body_markdown: '这里是内容', suggested_folder: 'Inbox', quality_flags: [] };
    const input: StrategyInput = { source_type: 'manual_text', content: '原始内容' };
    const result = outputValidator.validate(raw, input);
    expect(result.flags).toContain('placeholder_generated');
  });

  it('should truncate overly long title', () => {
    const raw = { title: 'a'.repeat(200), summary: '摘要', tags: [], body_markdown: '正文', suggested_folder: 'Inbox', quality_flags: [] };
    const input: StrategyInput = { source_type: 'manual_text', content: '原始内容' };
    const result = outputValidator.validate(raw, input);
    expect(result.flags).toContain('title_too_long');
    expect(result.content.title.length).toBeLessThanOrEqual(121); // 120 + '…'
  });

  it('should truncate too many tags', () => {
    const tags = Array.from({ length: 20 }, (_, i) => `tag${i}`);
    const raw = { title: '标题', summary: '摘要', tags, body_markdown: '正文', suggested_folder: 'Inbox', quality_flags: [] };
    const input: StrategyInput = { source_type: 'manual_text', content: '原始内容' };
    const result = outputValidator.validate(raw, input);
    expect(result.flags).toContain('tags_too_many');
    expect(result.content.tags.length).toBeLessThanOrEqual(15);
  });

  it('should handle completely empty raw input', () => {
    const input: StrategyInput = { source_type: 'manual_text', content: '原始内容' };
    const result = outputValidator.validate({}, input);
    expect(result.flags).toContain('title_missing');
    expect(result.flags).toContain('summary_missing');
    expect(result.flags).toContain('body_empty');
    expect(result.wasFixed).toBe(true);
    expect(result.content.title).toBeTruthy();
  });
});

// ===========================================================================
// Phase 8.5: Quality Fallback
// ===========================================================================

describe('Phase 8.5 - QualityFallback', () => {
  it('should assess good quality content', () => {
    const content: ProcessedContent = {
      title: '好标题', summary: '好摘要',
      tags: ['tag1'], body_markdown: '# 正文\n\n内容',
      suggested_folder: 'Inbox', quality_flags: [],
    };
    const input: StrategyInput = { source_type: 'manual_text', content: '原始' };
    const assessment = qualityFallback.assess(content, input);
    expect(assessment.level).toBe('good');
    expect(assessment.score).toBeGreaterThanOrEqual(80);
    expect(assessment.shouldRegenerate).toBe(false);
  });

  it('should assess critical quality for missing title and body', () => {
    const content: ProcessedContent = {
      title: '', summary: '摘要',
      tags: [], body_markdown: '',
      suggested_folder: 'Inbox', quality_flags: ['title_missing', 'body_empty'],
    };
    const input: StrategyInput = { source_type: 'manual_text', content: '原始' };
    const assessment = qualityFallback.assess(content, input);
    expect(assessment.level).toBe('critical');
    expect(assessment.shouldRegenerate).toBe(true);
    expect(assessment.regenerationSuggestion).toBeDefined();
  });

  it('should assess poor quality for model_unavailable', () => {
    const content: ProcessedContent = {
      title: '标题', summary: '摘要',
      tags: [], body_markdown: '正文',
      suggested_folder: 'Inbox', quality_flags: ['model_unavailable'],
    };
    const input: StrategyInput = { source_type: 'manual_text', content: '原始' };
    const assessment = qualityFallback.assess(content, input);
    expect(assessment.shouldRegenerate).toBe(true);
    expect(assessment.regenerationSuggestion!.suggestedTier).toBe('cloud_standard');
  });

  it('should generate fallback content', () => {
    const input: StrategyInput = { source_type: 'audio', content: '', raw_file_path: '/path/to/audio.mp3' };
    const fallback = qualityFallback.generateFallback(input);
    expect(fallback.title).toContain('音频记录');
    expect(fallback.quality_flags).toContain('fallback_used');
    expect(fallback.quality_flags).toContain('placeholder_generated');
    expect(fallback.body_markdown).toContain('占位记录');
    expect(fallback.tags).toContain('音频');
  });

  it('shouldAutoFallback should return true for unknown_file', () => {
    const input: StrategyInput = { source_type: 'unknown_file', content: '' };
    expect(qualityFallback.shouldAutoFallback(input)).toBe(true);
  });

  it('shouldAutoFallback should return true when no content available', () => {
    const input: StrategyInput = { source_type: 'screenshot', content: '' };
    expect(qualityFallback.shouldAutoFallback(input)).toBe(true);
  });

  it('shouldAutoFallback should return false when content exists', () => {
    const input: StrategyInput = { source_type: 'manual_text', content: '有内容' };
    expect(qualityFallback.shouldAutoFallback(input)).toBe(false);
  });

  it('should suggest higher tier for unsupported_inference', () => {
    const content: ProcessedContent = {
      title: '标题', summary: '摘要',
      tags: [], body_markdown: '正文',
      suggested_folder: 'Inbox', quality_flags: ['unsupported_inference', 'low_quality'],
    };
    const input: StrategyInput = { source_type: 'manual_text', content: '原始' };
    const assessment = qualityFallback.assess(content, input);
    expect(assessment.shouldRegenerate).toBe(true);
    expect(assessment.regenerationSuggestion!.reason).toContain('Prompt Profile');
  });
});

// ===========================================================================
// Phase 8.1-8.6: StrategyProcessor Integration
// ===========================================================================

describe('StrategyProcessor - Integration', () => {
  it('should build StrategyInput from CaptureRecord', () => {
    const record = makeCaptureRecord({
      source_type: 'webpage', raw_text: '网页正文',
      raw_url: 'https://example.com', raw_file_path: undefined,
      metadata: { domain: 'example.com' },
    });
    const input = strategyProcessor.buildStrategyInput(record);
    expect(input.source_type).toBe('webpage');
    expect(input.content).toBe('网页正文');
    expect(input.source_url).toBe('https://example.com');
  });

  it('should prepare processing with routing for manual_text', () => {
    const record = makeCaptureRecord({ source_type: 'manual_text', raw_text: '我的想法'.repeat(50) });
    const result = strategyProcessor.prepareProcessing(record, {
      availableProviders: makeProviders(),
    });
    expect(result.strategyName).toBe('manual_text');
    expect(result.directOutput).toBeNull();
    expect(result.prompt).toContain('我的想法');
    expect(result.routingDecision.tier).toBe('cloud_standard');
    expect(result.profileId).toBe('acmind.manual_text.v1');
  });

  it('should prepare processing for unknown_file with direct output', () => {
    const record = makeCaptureRecord({
      source_type: 'unknown_file', raw_text: '',
      raw_file_path: '/path/to/file.xyz', metadata: { extension: '.xyz' },
    });
    const result = strategyProcessor.prepareProcessing(record);
    expect(result.strategyName).toBe('unknown_file');
    expect(result.directOutput).not.toBeNull();
    expect(result.prompt).toBe('');
  });

  it('should processAiOutput with validation and quality assessment', () => {
    const input: StrategyInput = { source_type: 'manual_text', content: '原始内容' };
    const raw = { title: '标题', summary: '摘要', tags: ['tag'], body_markdown: '正文', suggested_folder: 'Inbox', quality_flags: [] };
    const result = strategyProcessor.processAiOutput(raw, input, {
      model_tier: 'cloud_standard', provider: 'openai', model_name: 'gpt-4o',
      prompt_profile_id: 'acmind.manual_text.v1', prompt_profile_version: '1.0.0',
      status: 'success',
    });
    expect(result.content.title).toBe('标题');
    expect(result.modelCall.status).toBe('success');
    expect(result.modelCall.model_tier).toBe('cloud_standard');
    expect(result.qualityScore).toBeGreaterThanOrEqual(80);
    expect(result.usedFallback).toBe(false);
  });

  it('should use fallback when quality is critical', () => {
    const input: StrategyInput = { source_type: 'manual_text', content: '原始内容' };
    // Strategy postProcess fills in empty fields, so we pass critical quality_flags directly
    // to ensure the quality assessment reaches 'critical' level
    const raw = { title: '', summary: '', tags: 'invalid', body_markdown: '', suggested_folder: '', quality_flags: ['model_unavailable', 'body_empty', 'title_missing'] };
    const result = strategyProcessor.processAiOutput(raw, input, {
      model_tier: 'cloud_standard', provider: 'openai', model_name: 'gpt-4o',
      prompt_profile_id: 'acmind.manual_text.v1', prompt_profile_version: '1.0.0',
      status: 'success',
    });
    expect(result.usedFallback).toBe(true);
    expect(result.modelCall.status).toBe('fallback');
    expect(result.content.quality_flags).toContain('fallback_used');
  });

  it('should handle AI failure gracefully via contentPipeline', async () => {
    const record = makeCaptureRecord({ source_type: 'manual_text', raw_text: '测试内容' });
    const failingAiFn = async () => { throw new Error('AI service unavailable'); };
    const { contentPipeline } = await import('../pipeline/contentPipelineService');
    const result = await contentPipeline.processWithStrategy(record, failingAiFn);
    expect(result).toBeDefined();
    expect(result.title).toBeDefined();
    expect(result.summary).toBeDefined();
    expect(result.body_markdown).toBeDefined();
  });
});

// ===========================================================================
// Unified Output Structure (all source_types)
// ===========================================================================

describe('Unified Output Structure', () => {
  it('all strategies should produce ProcessedContent with required fields', () => {
    const sourceTypes: SourceType[] = [
      'manual_text', 'clipboard_text', 'screenshot', 'webpage',
      'file', 'image', 'audio', 'video', 'pdf', 'docx', 'unknown_file',
    ];

    for (const sourceType of sourceTypes) {
      const input: StrategyInput = {
        source_type: sourceType, content: '', raw_file_path: '/test/path',
        source_url: sourceType === 'webpage' ? 'https://example.com' : undefined,
      };
      const result = strategyProcessor.postProcess({}, input);

      expect(result).toHaveProperty('title');
      expect(result).toHaveProperty('summary');
      expect(result).toHaveProperty('tags');
      expect(result).toHaveProperty('body_markdown');
      expect(result).toHaveProperty('suggested_folder');
      expect(result).toHaveProperty('quality_flags');

      expect(typeof result.title).toBe('string');
      expect(typeof result.summary).toBe('string');
      expect(Array.isArray(result.tags)).toBe(true);
      expect(typeof result.body_markdown).toBe('string');
      expect(typeof result.suggested_folder).toBe('string');
      expect(Array.isArray(result.quality_flags)).toBe(true);
      expect(result.title.length).toBeGreaterThan(0);
    }
  });
});
