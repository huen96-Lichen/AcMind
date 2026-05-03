import { describe, expect, it } from 'vitest';
import type { DistilledOutput, SourceItem } from '../../../shared/types';
import { markdownBuilder } from './markdownBuilder';

describe('markdownBuilder', () => {
  const sourceItem: SourceItem = {
    id: 'src-1',
    type: 'text',
    source: 'manual',
    contentPath: '/tmp/src-1.txt',
    previewText: '这是原始收集内容，用于测试。',
    sourceApp: 'AcMind',
    createdAt: 1714442400,
    status: 'inbox',
  };

  const distilledOutput: DistilledOutput = {
    id: 'do-1',
    sourceItemId: 'src-1',
    taskId: 'task-1',
    suggestedTitle: 'Acore 母品牌与产品体系说明',
    summary: '这是一句总结。',
    category: '产品规范',
    tags: ['AcMind', 'Obsidian'],
    contentMarkdown: '# 正文\n\n这里是正文。',
    confidence: 0.92,
    reviewStatus: 'accepted',
    createdAt: 1714442400,
  };

  it('renders the default AcMind structure', () => {
    const markdown = markdownBuilder.build(distilledOutput, sourceItem);

    expect(markdown).toContain('schema_version: "0.2"');
    expect(markdown).toContain('title: Acore 母品牌与产品体系说明');
    expect(markdown).toContain('summary: 这是一句总结。');
    expect(markdown).toContain('tags:');
    expect(markdown).toContain('> 这是一句总结。');
    expect(markdown).toContain('# Acore 母品牌与产品体系说明');
    expect(markdown).toContain('这里是正文。');
    expect(markdown).not.toContain('原始内容');
  });

  it('replaces schema_version and category placeholders in spec-style templates', () => {
    const markdown = markdownBuilder.buildFromFields(
      {
        schema_version: '0.2',
        title: '示例标题',
        summary: '示例摘要',
        tags: ['甲', '乙'],
        category: '个人复盘',
        source: 'manual',
        captured_at: '2026-05-01 03:55',
        project: '默认',
        status: 'exported',
        confidence: 0.7,
        body: '正文内容',
      },
      `---
schema_version: "{{schema_version}}"
title: "{{title}}"
category: "{{category}}"
---

# {{title}}

{{body}}`,
    );

    expect(markdown).toContain('schema_version: "0.2"');
    expect(markdown).toContain('category: "个人复盘"');
    expect(markdown).toContain('# 示例标题');
    expect(markdown).toContain('正文内容');
  });
});
