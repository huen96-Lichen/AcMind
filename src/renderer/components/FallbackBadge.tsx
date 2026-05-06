/**
 * FallbackBadge — indicates that an AI result was produced by fallback/placeholder logic,
 * not by a real AI provider. Helps users distinguish real AI output from degraded results.
 */
export function FallbackBadge() {
  return (
    <span
      style={{
        display: 'inline-flex',
        alignItems: 'center',
        gap: 4,
        padding: '2px 8px',
        borderRadius: 4,
        fontSize: 11,
        fontWeight: 500,
        color: '#92400e',
        backgroundColor: '#fef3c7',
        border: '1px solid #fcd34d',
        lineHeight: '16px',
      }}
    >
      ⚠ AI 兜底结果
    </span>
  );
}
