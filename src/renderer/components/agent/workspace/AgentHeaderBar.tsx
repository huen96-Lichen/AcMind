import React from 'react';

interface AgentHeaderBarProps {
  projectName?: string;
  modelName?: string;
  providerName?: string;
  isOnline?: boolean;
  onClearContext: () => void;
  onMoreActions?: () => void;
}

const containerStyle: React.CSSProperties = {
  padding: '12px 20px',
  borderBottom: '1px solid var(--color-border)',
  display: 'flex',
  alignItems: 'center',
  justifyContent: 'space-between',
  flexShrink: 0,
  background: 'var(--color-bg)',
};

const leftStyle: React.CSSProperties = {
  display: 'flex',
  alignItems: 'center',
  gap: 10,
  minWidth: 0,
};

const titleStyle: React.CSSProperties = {
  fontSize: 16,
  fontWeight: 600,
  margin: 0,
  whiteSpace: 'nowrap',
  overflow: 'hidden',
  textOverflow: 'ellipsis',
};

const modelBadgeStyle: React.CSSProperties = {
  background: '#ede9fe',
  color: '#8b5cf6',
  fontSize: 12,
  fontWeight: 600,
  padding: '3px 10px',
  borderRadius: 999,
  whiteSpace: 'nowrap',
};

const rightStyle: React.CSSProperties = {
  display: 'flex',
  alignItems: 'center',
  gap: 8,
  flexShrink: 0,
};

const onlineBadgeStyle: React.CSSProperties = {
  background: '#dcfce7',
  color: '#16a34a',
  fontSize: 12,
  fontWeight: 600,
  padding: '3px 10px',
  borderRadius: 999,
  whiteSpace: 'nowrap',
};

const offlineBadgeStyle: React.CSSProperties = {
  background: '#f3f4f6',
  color: '#6b7280',
  fontSize: 12,
  fontWeight: 600,
  padding: '3px 10px',
  borderRadius: 999,
  whiteSpace: 'nowrap',
};

const clearBtnStyle: React.CSSProperties = {
  fontSize: 12,
  color: 'var(--color-text-secondary)',
  background: 'transparent',
  border: '1px solid var(--color-border)',
  borderRadius: 6,
  padding: '4px 10px',
  cursor: 'pointer',
  whiteSpace: 'nowrap',
};

const moreBtnStyle: React.CSSProperties = {
  fontSize: 12,
  color: 'var(--color-text-secondary)',
  background: 'transparent',
  border: '1px solid var(--color-border)',
  borderRadius: 6,
  padding: '4px 8px',
  cursor: 'pointer',
  lineHeight: 1,
};

const AgentHeaderBar: React.FC<AgentHeaderBarProps> = ({
  projectName = 'AcMind Agent',
  modelName,
  isOnline = true,
  onClearContext,
  onMoreActions,
}) => {
  const statusBadge = isOnline ? (
    <span style={onlineBadgeStyle}>在线</span>
  ) : (
    <span style={offlineBadgeStyle}>离线</span>
  );

  return (
    <div style={containerStyle}>
      <div style={leftStyle}>
        <h2 style={titleStyle}>{projectName}</h2>
        {modelName && <span style={modelBadgeStyle}>{modelName}</span>}
      </div>
      <div style={rightStyle}>
        {statusBadge}
        <button style={clearBtnStyle} onClick={onClearContext}>
          清空上下文
        </button>
        {onMoreActions && (
          <button style={moreBtnStyle} onClick={onMoreActions}>
            ⋯
          </button>
        )}
      </div>
    </div>
  );
};

export default AgentHeaderBar;
