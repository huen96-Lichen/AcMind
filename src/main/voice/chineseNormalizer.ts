import { Converter } from '../vendor/opencc-js/dist/esm/t2cn.js';

const convertTraditionalToSimplified = Converter({ from: 'tw', to: 'cn' });

/**
 * Convert Chinese transcript text to simplified Chinese.
 * Keeps non-Chinese text intact.
 */
export function toSimplifiedChinese(text: string): string {
  if (!text) return text;
  return convertTraditionalToSimplified(text);
}
