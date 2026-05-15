import SwiftUI

struct ContinentExpandedPreviewCard: View {
    @Binding var tabs: [CompanionContinentPreviewTab]
    @Binding var selectedTabID: UUID
    
    private var selectedTab: CompanionContinentPreviewTab {
        tabs.first(where: { $0.id == selectedTabID }) ?? tabs.first ?? Self.defaultTab
    }
    
    private static let defaultTab = CompanionContinentPreviewTab(
        id: UUID(),
        name: "今日",
        icon: "sun.max",
        layout: .overview,
        enabledModules: [.timeline, .musicPlayer, .quickActions, .tasks, .agentStatus],
        isDefault: true
    )
    
    private var customTabCount: Int {
        tabs.filter { !$0.isDefault }.count
    }
    
    var body: some View {
        ConfigCardContainer {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("大陆展开预览")
                            .font(ContinentConfigTypography.cardTitle)
                            .foregroundColor(ContinentConfigTokens.primaryText)
                        Text("切换板块查看不同内容布局")
                            .font(ContinentConfigTypography.cardSubtitle)
                            .foregroundColor(ContinentConfigTokens.secondaryText)
                    }
                    Spacer()
                    Button {
                    } label: {
                        Text("管理板块")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(ContinentConfigTokens.primaryText)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(ContinentConfigTokens.cardBackground, in: Capsule())
                            .overlay(Capsule().stroke(ContinentConfigTokens.border, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, ContinentConfigLayout.cardPadding)
                .padding(.top, 18)
                .frame(height: 42)
                
                HStack(spacing: 12) {
                    ForEach(tabs) { tab in
                        tabButton(tab.name, isSelected: selectedTab.id == tab.id) {
                            selectedTabID = tab.id
                        }
                    }
                    addTabButton()
                }
                .padding(.horizontal, ContinentConfigLayout.cardPadding)
                .padding(.top, 14)
                
                BlackContinentPreview(tab: selectedTab)
                    .padding(.horizontal, ContinentConfigLayout.cardPadding)
                    .padding(.top, 10)
            }
        }
    }
    
    private func tabButton(_ title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(isSelected ? .white : ContinentConfigTokens.primaryText)
                .padding(.horizontal, 20)
                .padding(.vertical, 7)
                .background(
                    isSelected 
                        ? ContinentConfigTokens.blackCapsule
                        : ContinentConfigTokens.softFill,
                    in: Capsule()
                )
                .overlay(
                    Capsule().stroke(isSelected ? Color.clear : ContinentConfigTokens.border, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
    
    private func addTabButton() -> some View {
        Button {
            let newTab = CompanionContinentPreviewTab(
                id: UUID(),
                name: "自定义\(customTabCount + 1)",
                icon: "plus",
                layout: .custom,
                enabledModules: [.timeline, .quickActions, .weather],
                isDefault: false
            )
            tabs.append(newTab)
            selectedTabID = newTab.id
        } label: {
            Text("+")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(ContinentConfigTokens.primaryText)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(ContinentConfigTokens.softFill, in: Capsule())
                .overlay(Capsule().stroke(ContinentConfigTokens.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

struct BlackContinentPreview: View {
    let tab: CompanionContinentPreviewTab
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: 14)
                .fill(ContinentConfigTokens.blackCapsule)
                .frame(height: 164)
            
            Text("LIVE")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(ContinentConfigTokens.accentGreen)
                .padding(.top, 14)
                .padding(.trailing, 18)
            
            HStack(spacing: 12) {
                TodayPreviewCard()
                MusicPreviewCard()
                AgentPreviewCard()
            }
            .padding(.top, 16)
            .padding(.leading, 16)
            .padding(.trailing, 16)
            .padding(.bottom, 16)
        }
    }
}

struct TodayPreviewCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("今日")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white)
            
            Text("日程")
                .font(.system(size: 11, weight: .regular))
                .foregroundColor(Color.white.opacity(0.6))
            
            VStack(spacing: 4) {
                scheduleRow(time: "10:00", title: "需求评审会", color: ContinentConfigTokens.accentBlue)
                scheduleRow(time: "14:30", title: "产品同步", color: ContinentConfigTokens.accentGreen)
                scheduleRow(time: "16:00", title: "开发对齐", color: ContinentConfigTokens.accentPurple)
            }
            
            HStack(spacing: 2) {
                Text("+")
                    .font(.system(size: 10, weight: .medium))
                Text("2项")
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundColor(Color.white.opacity(0.6))
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .frame(height: 116)
        .background(ContinentConfigTokens.blackCard, in: RoundedRectangle(cornerRadius: 10))
    }
    
    private func scheduleRow(time: String, title: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 5, height: 5)
            Text(time)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white)
            Text(title)
                .font(.system(size: 11, weight: .regular))
                .foregroundColor(Color.white.opacity(0.8))
        }
    }
}

struct MusicPreviewCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("音乐")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white)
            
            RoundedRectangle(cornerRadius: 8)
                .fill(ContinentConfigTokens.secondaryText)
                .frame(width: 44, height: 44)
            
            VStack(alignment: .leading, spacing: 1) {
                Text("Dream It Possible")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white)
                Text("Delacey")
                    .font(.system(size: 10, weight: .regular))
                    .foregroundColor(Color.white.opacity(0.6))
            }
            
            HStack(spacing: 24) {
                Image(systemName: "backward.fill")
                    .font(.system(size: 16, weight: .medium))
                Image(systemName: "play.fill")
                    .font(.system(size: 16, weight: .medium))
                Image(systemName: "forward.fill")
                    .font(.system(size: 16, weight: .medium))
            }
            .foregroundColor(.white)
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .frame(height: 116)
        .background(ContinentConfigTokens.blackCard, in: RoundedRectangle(cornerRadius: 10))
    }
}

struct AgentPreviewCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Agent")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white)
            
            RoundedRectangle(cornerRadius: 10)
                .fill(ContinentConfigTokens.accentBlue)
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: "sparkles")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                )
            
            VStack(alignment: .leading, spacing: 1) {
                Text("思考中")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white)
                Text("已处理 1 项任务")
                    .font(.system(size: 10, weight: .regular))
                    .foregroundColor(Color.white.opacity(0.6))
            }
            
            VStack(spacing: 2) {
                HStack(alignment: .center, spacing: 0) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(ContinentConfigTokens.accentBlue)
                        .frame(width: 87, height: 4)
                }
                .background(ContinentConfigTokens.secondaryText, in: RoundedRectangle(cornerRadius: 2))
                .frame(height: 4)
                
                Text("87%")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(Color.white.opacity(0.6))
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .frame(height: 116)
        .background(ContinentConfigTokens.blackCard, in: RoundedRectangle(cornerRadius: 10))
    }
}
