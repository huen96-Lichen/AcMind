import SwiftUI

enum ConversationTab {
    case conversation, task, history
}

struct AgentConversationList: View {
    @State private var selectedTab: ConversationTab = .conversation
    @State private var selectedIndex: Int = 0
    
    private let todayConversations = [
        ("帮我分析本季度产品增长数据", "10:23", "正在分析中...", .running),
        ("生成一份竞品分析报告", "昨天", "已完成", .completed),
        ("整理会议纪要并生成待办事项", "昨天", "已完成", .completed),
        ("设计一个用户调研问卷", "05-08", "已完成", .completed),
        ("帮我优化这段代码", "05-07", "已完成", .completed)
    ]
    
    private let earlierConversations = [
        ("比较 iPhone 15 和 16 的差异", "05-06"),
        ("制定下周的学习计划", "05-05"),
        ("翻译一段英文文档", "05-04")
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            tabBar
            
            Divider()
                .foregroundColor(AgentColors.border)
            
            ScrollView {
                VStack(spacing: 0) {
                    newConversationButton
                    
                    todaySection
                    
                    earlierSection
                    
                    viewAllButton
                }
            }
        }
        .agentCardStyle()
        .frame(maxHeight: .infinity)
    }
    
    private var tabBar: some View {
        HStack(spacing: 0) {
            tabButton(title: "对话", isSelected: selectedTab == .conversation, action: { selectedTab = .conversation })
            tabButton(title: "任务", isSelected: selectedTab == .task, action: { selectedTab = .task })
            tabButton(title: "历史", isSelected: selectedTab == .history, action: { selectedTab = .history })
        }
        .frame(height: 56)
    }
    
    private func tabButton(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 0) {
                Text(title)
                    .font(isSelected ? .system(size: 13, weight: .semibold) : .system(size: 13, weight: .medium))
                    .foregroundColor(isSelected ? AgentColors.accentBlue : Color(hex: "#333333"))
                
                Spacer()
                
                if isSelected {
                    Rectangle()
                        .fill(AgentColors.accentBlue)
                        .frame(width: 28, height: 2)
                        .cornerRadius(1)
                } else {
                    Rectangle()
                        .fill(Color.clear)
                        .frame(width: 28, height: 2)
                }
            }
            .padding(.top, 16)
        }
        .frame(maxWidth: .infinity)
    }
    
    private var newConversationButton: some View {
        HStack(spacing: 8) {
            Button(action: {}) {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                        .font(.system(size: 14))
                    
                    Text("新建对话")
                        .font(AgentTypography.bodyMedium)
                    
                    Text("⌘N")
                        .font(.system(size: 11))
                        .foregroundColor(AgentColors.tertiaryText)
                }
                .foregroundColor(AgentColors.primaryText)
                .frame(height: 44)
                .frame(maxWidth: .infinity)
                .background(AgentColors.cardBackground)
                .cornerRadius(AgentLayout.smallRadius)
                .overlay(
                    RoundedRectangle(cornerRadius: AgentLayout.smallRadius)
                        .stroke(AgentColors.border, lineWidth: 1)
                )
            }
            
            Button(action: {}) {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .font(.system(size: 16))
                    .foregroundColor(AgentColors.secondaryText)
                    .frame(width: 44, height: 44)
                    .background(AgentColors.cardBackground)
                    .cornerRadius(AgentLayout.smallRadius)
                    .overlay(
                        RoundedRectangle(cornerRadius: AgentLayout.smallRadius)
                            .stroke(AgentColors.border, lineWidth: 1)
                    )
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 8)
    }
    
    private var todaySection: some View {
        VStack(spacing: 0) {
            Text("今天")
                .font(AgentTypography.caption)
                .fontWeight(.medium)
                .foregroundColor(AgentColors.secondaryText)
                .padding(.leading, 18)
                .padding(.top, 24)
                .padding(.bottom, 12)
            
            ForEach(0..<todayConversations.count, id: \.self) { index in
                let item = todayConversations[index]
                conversationRow(
                    title: item.0,
                    time: item.1,
                    statusText: item.2,
                    status: item.3,
                    isSelected: index == selectedIndex,
                    action: { selectedIndex = index }
                )
            }
        }
    }
    
    private var earlierSection: some View {
        VStack(spacing: 0) {
            Text("更早")
                .font(AgentTypography.caption)
                .fontWeight(.medium)
                .foregroundColor(AgentColors.secondaryText)
                .padding(.leading, 18)
                .padding(.top, 20)
                .padding(.bottom, 12)
            
            ForEach(0..<earlierConversations.count, id: \.self) { index in
                let item = earlierConversations[index]
                earlierRow(title: item.0, time: item.1)
            }
        }
    }
    
    private func conversationRow(title: String, time: String, statusText: String, status: TaskStatus, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                HStack(alignment: .top, spacing: 0) {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(AgentColors.primaryText)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    Text(time)
                        .font(AgentTypography.mini)
                        .foregroundColor(AgentColors.secondaryText)
                }
                
                HStack(alignment: .center, spacing: 4) {
                    Text(statusText)
                        .font(AgentTypography.caption)
                        .foregroundColor(AgentColors.secondaryText)
                    
                    Spacer()
                    
                    Circle()
                        .fill(status.color)
                        .frame(width: 6, height: 6)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(height: 64)
            .background(isSelected ? AgentColors.selectedFill : Color.clear)
            .cornerRadius(AgentLayout.smallRadius)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func earlierRow(title: String, time: String) -> some View {
        Button(action: {}) {
            HStack(alignment: .center, spacing: 0) {
                Text(title)
                    .font(AgentTypography.body)
                    .foregroundColor(AgentColors.primaryText)
                    .lineLimit(1)
                
                Spacer()
                
                Text(time)
                    .font(AgentTypography.mini)
                    .foregroundColor(AgentColors.secondaryText)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(height: 44)
            .background(Color.clear)
            .cornerRadius(AgentLayout.smallRadius)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var viewAllButton: some View {
        Button(action: {}) {
            HStack(spacing: 4) {
                Text("查看全部历史记录")
                    .font(AgentTypography.bodyMedium)
                    .foregroundColor(AgentColors.primaryText)
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
            }
            .frame(height: 44)
            .frame(maxWidth: .infinity)
            .background(AgentColors.softFill)
            .cornerRadius(AgentLayout.smallRadius)
            .padding(.horizontal, 18)
            .padding(.bottom, 18)
            .padding(.top, 8)
        }
    }
}

enum TaskStatus {
    case running, completed, waiting
    
    var color: Color {
        switch self {
        case .running: return AgentColors.accentPurple
        case .completed: return AgentColors.accentGreen
        case .waiting: return AgentColors.tertiaryText
        }
    }
}