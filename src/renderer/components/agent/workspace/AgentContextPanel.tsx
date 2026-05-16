import { AgentContextInfo, AgentToolAction } from '../types';

interface AgentContextPanelProps {
  context: AgentContextInfo;
  tools: AgentToolAction[];
  messageCount: number;
  onToolClick: (toolId: string) => void;
  onDistillClick?: () => void;
}

const cardStyle: React.CSSProperties = {
  background: 'var(--color-bg)',
  border: '1px solid var(--color-border)',
  borderRadius: 10,
  padding: '14px',
  marginBottom: 12,
  boxShadow: '0 1px 3px rgba(0,0,0,0.04)',
};

const labelStyle: React.CSSProperties = {
  fontSize: 12,
  color: 'var(--color-text-secondary)',
  fontWeight: 500,
};

const valueStyle: React.CSSProperties = {
  fontSize: 13,
  color: 'var(--color-text)',
  fontWeight: 400,
};

const rowStyle: React.CSSProperties = {
  display: 'flex',
  justifyContent: 'space-between',
  padding: '4px 0',
};

const headerStyle: React.CSSProperties = {
  fontSize: 13,
  fontWeight: 600,
  marginBottom: 10,
};

const defaultTools: AgentToolAction[] = [
  { id: 'distill', name: '知识蒸馏', icon: '🧪', description: 'AI 蒸馏为结构化笔记', enabled: true },
  { id: 'inbox', name: '发送到收集箱', icon: '📥', description: '保存到收集箱', enabled: true },
  { id: 'save-project', name: '保存到项目', icon: '💾', description: '关联到当前项目', enabled: true },
  { id: 'export-md', name: '生成 Markdown', icon: '📝', description: '导出为 Markdown 文件', enabled: true },
  { id: 'sync-schedule', name: '同步到日程', icon: '📅', description: '创建日程提醒', enabled: true },
];

const AgentContextPanel: React.FC<AgentContextPanelProps> = ({
  context,
  tools,
  messageCount,
  onToolClick,
  onDistillClick,
}) => {
  const displayTools = tools.length > 0 ? tools : defaultTools;

  const handleToolClick = (toolId: string) => {
    if (toolId === 'distill' && onDistillClick) {
      onDistillClick();
    } else {
      onToolClick(toolId);
    }
  };

  return (
    <div style={{ display: 'flex', flexDirection: 'column', height: '100%', overflowY: 'auto', padding: '16px' }}>
      <div style={cardStyle}>
        <div style={rowStyle}>
          <span style={labelStyle}>会话</span>
          <span style={valueStyle}>{context.sessionId || '新建会话'}</span>
        </div>
        <div style={rowStyle}>
          <span style={labelStyle}>模型</span>
          <span style={valueStyle}>{context.modelName || '未选择'}</span>
        </div>
        <div style={rowStyle}>
          <span style={labelStyle}>提供者</span>
          <span style={valueStyle}>{context.providerName || '未配置'}</span>
        </div>
        <div style={rowStyle}>
          <span style={labelStyle}>消息数</span>
          <span style={valueStyle}>{messageCount}</span>
        </div>
      </div>

      <div style={cardStyle}>
        <div style={headerStyle}>任务进度</div>
        <div style={{ fontSize: 12, color: 'var(--color-text-secondary)', marginBottom: 8 }}>
          等待任务...
        </div>
        <div style={{ background: 'var(--color-border)', height: 4, borderRadius: 2, overflow: 'hidden' }}>
          <div style={{ width: '0%', height: '100%', background: 'var(--color-accent)', borderRadius: 2 }} />
        </div>
      </div>

      <div style={cardStyle}>
        <div style={headerStyle}>可用工具</div>
        {displayTools.map((tool) => (
          <div
            key={tool.id}
            onClick={() => tool.enabled !== false && handleToolClick(tool.id)}
            style={{
              display: 'flex',
              alignItems: 'center',
              gap: 10,
              padding: '8px 10px',
              borderRadius: 8,
              cursor: tool.enabled !== false ? 'pointer' : 'default',
              opacity: tool.enabled !== false ? 1 : 0.5,
              transition: 'background 0.15s',
            }}
            onMouseEnter={(e) => {
              if (tool.enabled !== false) {
                (e.currentTarget as HTMLDivElement).style.background = 'var(--color-bg-hover)';
              }
            }}
            onMouseLeave={(e) => {
              (e.currentTarget as HTMLDivElement).style.background = 'transparent';
            }}
          >
            <span style={{ fontSize: 18 }}>{tool.icon}</span>
            <div>
              <div style={{ fontSize: 13, fontWeight: 500, color: 'var(--color-text)' }}>{tool.name}</div>
              <div style={{ fontSize: 11, color: 'var(--color-text-secondary)', marginTop: 1 }}>
                {tool.description}
              </div>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
};

export default AgentContextPanel;
