import SwiftUI

struct AgentTaskInspector: View {
    private let toolCalls = [
        ("数据读取", .completed),
        ("数据清洗", .completed),
        ("数据分析", .running),
        ("图表生成", .waiting),
        ("文档生成", .waiting)
    ]
    
    private let referenceFiles = [
        ("产品增长数据_2025Q2.csv", "2.3 MB", .csv),
        ("渠道数据统计.xlsx", "1.1 MB", .xlsx),
        ("用户行为分析报告.pdf", "3.6 MB", .pdf)
    ]
    
    private let capabilities = [
        "任务编排",
        "文件工具",
        "模型切换"
    ]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                currentTaskSection
                
                toolCallsSection
                
                referenceFilesSection
                
                capabilitiesSection
            }
            .padding(.top, 20)
            .padding(.horizontal, 18)
            .padding(.bottom, 20)
        }
        .agentCardStyle()
        .frame(maxHeight: .infinity)
    }
    
    private var currentTaskSection: some View {
        VStack(spacing: 14) {
            HStack(alignment: .center, spacing: 0) {
                Text("当前任务")
                    .font(AgentTypography.panelTitle)
                    .foregroundColor(AgentColors.primaryText)
                
                Spacer()
                
                Button(action: {}) {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16))
                        .foregroundColor(AgentColors.secondaryText)
                }
            }
            
            VStack(spacing: 10) {
                Text("数据分析与可视化")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AgentColors.primaryText)
                
                Text("本季度产品增长数据分析")
                    .font(AgentTypography.body)
                    .foregroundColor(AgentColors.secondaryText)
                    .lineLimit(2)
                
                HStack(spacing: 8) {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(AgentColors.accentPurple)
                            .frame(width: 7, height: 7)
                        
                        Text("执行中")
                            .font(AgentTypography.caption)
                            .foregroundColor(AgentColors.accentPurple)
                    }
                    
                    Spacer()
                    
                    Text("进度 60%")
                        .font(AgentTypography.caption)
                        .foregroundColor(AgentColors.secondaryText)
                }
                
                ProgressView(value: 0.6)
                    .progressViewStyle(LinearProgressViewStyle(tint: AgentColors.accentPurple))
                    .frame(height: 4)
                    .background(AgentColors.border)
                    .cornerRadius(2)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("开始时间")
                        .font(AgentTypography.mini)
                        .foregroundColor(AgentColors.tertiaryText)
                    
                    Text("05-09 10:23")
                        .font(AgentTypography.caption)
                        .foregroundColor(AgentColors.secondaryText)
                }
            }
            .padding(14)
            .background(AgentColors.cardBackground)
            .cornerRadius(AgentLayout.smallRadius)
            .overlay(
                RoundedRectangle(cornerRadius: AgentLayout.smallRadius)
                    .stroke(AgentColors.border, lineWidth: 1)
            )
        }
    }
    
    private var toolCallsSection: some View {
        VStack(spacing: 0) {
            Text("工具调用")
                .font(AgentTypography.panelTitle)
                .foregroundColor(AgentColors.primaryText)
                .padding(.top, 28)
                .padding(.bottom, 12)
            
            VStack(spacing: 0) {
                ForEach(0..<toolCalls.count, id: \.self) { index in
                    let tool = toolCalls[index]
                    
                    HStack(alignment: .center, spacing: 0) {
                        Text(tool.0)
                            .font(AgentTypography.body)
                            .foregroundColor(AgentColors.primaryText)
                        
                        Spacer()
                        
                        HStack(spacing: 4) {
                            toolStatusIcon(tool.1)
                            
                            Text(statusText(tool.1))
                                .font(AgentTypography.caption)
                                .fontWeight(.medium)
                                .foregroundColor(statusColor(tool.1))
                        }
                    }
                    .frame(height: 32)
                    
                    if index < toolCalls.count - 1 {
                        Divider()
                            .foregroundColor(AgentColors.softBorder)
                    }
                }
            }
        }
    }
    
    private func toolStatusIcon(_ status: TaskStatus) -> some View {
        Group {
            switch status {
            case .completed:
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 12))
                    .foregroundColor(AgentColors.accentGreen)
            case .running:
                Circle()
                    .fill(AgentColors.accentPurple)
                    .frame(width: 12, height: 12)
            case .waiting:
                Circle()
                    .fill(AgentColors.tertiaryText)
                    .frame(width: 12, height: 12)
            }
        }
    }
    
    private func statusText(_ status: TaskStatus) -> String {
        switch status {
        case .completed: return "已完成"
        case .running: return "进行中"
        case .waiting: return "等待中"
        }
    }
    
    private func statusColor(_ status: TaskStatus) -> Color {
        switch status {
        case .completed: return AgentColors.accentGreen
        case .running: return AgentColors.accentPurple
        case .waiting: return AgentColors.tertiaryText
        }
    }
    
    private var referenceFilesSection: some View {
        VStack(spacing: 12) {
            Text("参考文件 (3)")
                .font(AgentTypography.panelTitle)
                .foregroundColor(AgentColors.primaryText)
                .padding(.top, 30)
            
            VStack(spacing: 0) {
                ForEach(0..<referenceFiles.count, id: \.self) { index in
                    let file = referenceFiles[index]
                    
                    HStack(alignment: .center, spacing: 8) {
                        fileIcon(file.2)
                        
                        Text(file.0)
                            .font(AgentTypography.caption)
                            .foregroundColor(AgentColors.primaryText)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        Text(file.1)
                            .font(AgentTypography.mini)
                            .foregroundColor(AgentColors.secondaryText)
                    }
                    .frame(height: 34)
                }
            }
            
            Button(action: {}) {
                HStack(spacing: 4) {
                    Image(systemName: "plus")
                        .font(.system(size: 13))
                    
                    Text("添加文件")
                        .font(AgentTypography.bodyMedium)
                        .foregroundColor(AgentColors.primaryText)
                }
                .frame(height: 38)
                .frame(maxWidth: .infinity)
                .background(AgentColors.cardBackground)
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(AgentColors.border, lineWidth: 1)
                )
            }
        }
    }
    
    private func fileIcon(_ type: FileType) -> Image {
        let icon: String
        let color: Color
        
        switch type {
        case .csv:
            icon = "doc.text"
            color = AgentColors.accentBlue
        case .xlsx:
            icon = "table"
            color = AgentColors.accentGreen
        case .pdf:
            icon = "doc.text.fill"
            color = AgentColors.accentRed
        }
        
        return Image(systemName: icon)
            .font(.system(size: 16))
            .foregroundColor(color)
    }
    
    private var capabilitiesSection: some View {
        VStack(spacing: 0) {
            Text("能力预留")
                .font(AgentTypography.panelTitle)
                .foregroundColor(AgentColors.primaryText)
                .padding(.top, 28)
                .padding(.bottom, 12)
            
            VStack(spacing: 0) {
                ForEach(0..<capabilities.count, id: \.self) { index in
                    HStack(alignment: .center, spacing: 8) {
                        Circle()
                            .fill(AgentColors.accentPurple)
                            .frame(width: 6, height: 6)
                        
                        Text(capabilities[index])
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(AgentColors.primaryText)
                        
                        Spacer()
                        
                        Text("预留")
                            .font(AgentTypography.caption)
                            .foregroundColor(AgentColors.secondaryText)
                    }
                    .frame(height: 30)
                }
            }
        }
    }
}

enum FileType {
    case csv, xlsx, pdf
}