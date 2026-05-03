import mammoth from 'mammoth';
import { logger } from '../../logger';
import type { ParseResult, ParsedDocument, ParsedSection } from './types';

/**
 * Parse a DOCX buffer into a structured ParsedDocument.
 *
 * Uses mammoth's built-in Markdown converter so headings, lists, and
 * basic formatting are preserved. Sections are derived from heading
 * boundaries in the Markdown output.
 */
export async function parseDocx(buffer: Buffer): Promise<ParseResult> {
  try {
    logger.info('app', 'docx', 'parse', 'Starting DOCX parsing', {
      size: buffer.length,
    });

    // Convert to Markdown (convertToMarkdown exists at runtime but not in types)
    const result = await (mammoth as any).convertToMarkdown({ buffer });

    if (result.messages?.length) {
      logger.info('app', 'docx', 'parse', 'Mammoth conversion messages', {
        messages: result.messages,
      });
    }

    const content = result.value.trim();

    if (!content) {
      logger.warn('app', 'docx', 'parse', 'DOCX contains no extractable text');
      return { success: false, error: 'DOCX contains no extractable text' };
    }

    // --- Title ---
    // Try to get title from document properties first
    const metadata = await mammoth.extractRawText({ buffer });
    const rawText = metadata.value.trim();
    const firstLine = rawText.split('\n')[0].trim();

    // Look for the first Markdown heading (## or #)
    const headingMatch = content.match(/^#{1,3}\s+(.+)$/m);
    const title = headingMatch?.[1]?.trim() || firstLine.slice(0, 200) || 'Untitled Document';

    // --- Sections ---
    // Split by Markdown headings (## or #)
    const sections: ParsedSection[] = [];
    const sectionRegex = /^(#{1,4})\s+(.+)$/gm;
    let lastIndex = 0;
    let match: RegExpExecArray | null;

    // If no headings found, create a single section
    const hasHeadings = /^#{1,4}\s+/m.test(content);

    if (hasHeadings) {
      while ((match = sectionRegex.exec(content)) !== null) {
        // Save previous section content (if any)
        if (match.index > lastIndex) {
          const prevContent = content.slice(lastIndex, match.index).trim();
          if (prevContent) {
            sections.push({ content: prevContent });
          }
        }

        const level = match[1].length; // number of # characters
        const heading = match[2].trim();

        // Find the end of this section (next heading or end of content)
        const nextMatch = sectionRegex.exec(content);
        const sectionEnd = nextMatch ? nextMatch.index : content.length;
        // Reset lastIndex since exec already advanced
        sectionRegex.lastIndex = nextMatch ? nextMatch.index : content.length;

        const sectionContent = content.slice(match.index + match[0].length, sectionEnd).trim();
        sections.push({ heading, level, content: sectionContent });
        lastIndex = sectionEnd;
      }

      // Capture any trailing content after the last heading
      if (lastIndex < content.length) {
        const trailing = content.slice(lastIndex).trim();
        if (trailing) {
          sections.push({ content: trailing });
        }
      }
    } else {
      sections.push({ content });
    }

    // --- Word count ---
    const wordCount = rawText.split(/\s+/).filter(Boolean).length;

    // --- Preview (first 500 chars) ---
    const previewText = content.slice(0, 500);

    const document: ParsedDocument = {
      title,
      content,
      previewText,
      sections,
      metadata: {
        sourceType: 'docx',
        wordCount,
      },
    };

    logger.info('app', 'docx', 'parse', 'DOCX parsed successfully', {
      title,
      wordCount,
      sectionCount: sections.length,
    });

    return { success: true, document };
  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : String(err);
    logger.error('app', 'docx', 'parse', 'Failed to parse DOCX', { error: message });
    return { success: false, error: `Failed to parse DOCX: ${message}` };
  }
}
