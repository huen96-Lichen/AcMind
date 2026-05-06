/**
 * PermissionConfirmDialog — 操作权限确认对话框
 *
 * 功能：
 * - 显示操作的风险等级（safe/confirm/danger）
 * - 显示操作描述
 * - 提供确认/取消按钮
 */

import { useState } from 'react';
import type { AgentActionProposal } from '../../../shared/types';
import { Button } from '../../design-system/components';
import { AcMindIcon } from '../../design-system/icons';

interface PermissionConfirmDialogProps {
  proposal: AgentActionProposal;
  onConfirm: () => void;
  onCancel: () => void;
}

export function PermissionConfirmDialog({ proposal, onConfirm, onCancel }: PermissionConfirmDialogProps): JSX.Element {
  const [isProcessing, setIsProcessing] = useState(false);

  const handleConfirm = async () => {
    setIsProcessing(true);
    try {
      onConfirm();
    } finally {
      setIsProcessing(false);
    }
  };

  const { colorClass, bgClass, iconName, label } = getRiskLevelStyles(proposal.riskLevel);

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 backdrop-blur-sm">
      <div className="bg-surface border border-border-subtle rounded-2xl shadow-xl max-w-md w-full mx-4 overflow-hidden">
        {/* Header with risk indicator */}
        <div className={`px-6 py-4 ${bgClass} border-b border-border-subtle`}>
          <div className="flex items-center gap-3">
            <div className={`w-10 h-10 rounded-full ${bgClass} flex items-center justify-center`}>
              <AcMindIcon name={iconName} size={20} className={colorClass} />
            </div>
            <div>
              <h3 className="font-semibold text-text-primary">{proposal.label}</h3>
              <span className={`text-xs ${colorClass} font-medium`}>{label}</span>
            </div>
          </div>
        </div>

        {/* Content */}
        <div className="px-6 py-4">
          <p className="text-sm text-text-secondary mb-4">
            {proposal.description || getDefaultDescription(proposal.type)}
          </p>

          {/* Action details */}
          <div className="bg-surface-muted rounded-lg p-3 text-xs text-text-tertiary space-y-1">
            <div className="flex justify-between">
              <span>操作类型</span>
              <span className="text-text-secondary">{getActionTypeLabel(proposal.type)}</span>
            </div>
            {proposal.target && (
              <div className="flex justify-between">
                <span>目标</span>
                <span className="text-text-secondary truncate max-w-[200px]">{proposal.target}</span>
              </div>
            )}
            {proposal.params && Object.keys(proposal.params).length > 0 && (
              <div className="flex justify-between">
                <span>参数</span>
                <span className="text-text-secondary">{Object.keys(proposal.params).length} 个</span>
              </div>
            )}
          </div>
        </div>

        {/* Footer */}
        <div className="px-6 py-4 border-t border-border-subtle flex justify-end gap-3">
          <Button variant="ghost" size="md" onClick={onCancel} disabled={isProcessing}>
            取消
          </Button>
          <Button
            variant={proposal.riskLevel === 'danger' ? 'danger' : 'primary'}
            size="md"
            onClick={handleConfirm}
            disabled={isProcessing}
            leadingIcon={
              isProcessing ? (
                <span className="w-4 h-4 border-2 border-current border-t-transparent rounded-full animate-spin" />
              ) : undefined
            }
          >
            {isProcessing ? '执行中...' : '确认执行'}
          </Button>
        </div>
      </div>
    </div>
  );
}

function getRiskLevelStyles(riskLevel: AgentActionProposal['riskLevel']) {
  switch (riskLevel) {
    case 'safe':
      return {
        colorClass: 'text-success',
        bgClass: 'bg-success-soft',
        iconName: 'status-success' as const,
        label: '安全操作',
      };
    case 'confirm':
      return {
        colorClass: 'text-warning',
        bgClass: 'bg-warning-soft',
        iconName: 'status-warning' as const,
        label: '需要确认',
      };
    case 'danger':
      return {
        colorClass: 'text-danger',
        bgClass: 'bg-danger-soft',
        iconName: 'status-error' as const,
        label: '危险操作',
      };
    default:
      return {
        colorClass: 'text-text-secondary',
        bgClass: 'bg-surface-muted',
        iconName: 'ai-workspace' as const,
        label: '未知风险',
      };
  }
}

function getActionTypeLabel(type: AgentActionProposal['type']): string {
  const labels: Record<string, string> = {
    navigate: '页面导航',
    open_file: '打开文件',
    distill: '蒸馏内容',
    export: '导出内容',
    scan: '扫描内容',
    run_skill: '运行技能',
    create_task: '创建任务',
  };
  return labels[type] || type;
}

function getDefaultDescription(type: AgentActionProposal['type']): string {
  const descriptions: Record<string, string> = {
    navigate: '将跳转到指定页面。',
    open_file: '将打开指定的文件。',
    distill: '将对选中的内容进行 AI 蒸馏处理。',
    export: '将内容导出到目标位置。',
    scan: '将扫描指定范围内的内容。',
    run_skill: '将运行指定的技能脚本。',
    create_task: '将创建新的任务。',
  };
  return descriptions[type] || '执行此操作。';
}
