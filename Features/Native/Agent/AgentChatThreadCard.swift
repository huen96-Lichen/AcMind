import SwiftUI

struct AgentChatThreadCard: View {
    private let executionSteps = [
        ("读取并整理数据结构", .completed),
        ("分析核心增长指标", .completed),
        ("生成可视化图表", .running),
        ("提炼关键结论", .waiting),
        ("生成汇报文档", .waiting)
    ]
    
    private let previewCards = [
        "用户增长趋势",
        "活跃用户分布", 
        "渠道转化率",
        "留存趋势"
    ]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                userMessage
                
                agentReplyCard
            }
            .padding(.top, 28)
            .padding(.horizontal, 28)
            .padding(.bottom, 24)
        }
        .agentCardStyle()
        .frame(maxHeight: .infinity)
    }
    
    private var userMessage: some View {
        HStack(alignment: .top, spacing: 14) {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "#A855F7"), Color(hex: "#C084FC")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 32, height: 32)
                .overlay(
                    Image(systemName: "person.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.white)
                )
            
            VStack(alignment: .trailing, spacing: 6) {
                Text("帮我分析本季度产品增长数据，生成可视化图表和关键结论，输出一份汇报文档。")
                    .font(.system(size: 14))
                    .foregroundColor(AgentColors.primaryText)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 14)
                    .background(AgentColors.cardBackground)
                    .cornerRadius(14)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(AgentColors.border, lineWidth: 1)
                    )
                
                Text("10:23")
                    .font(AgentTypography.mini)
                    .foregroundColor(AgentColors.secondaryText)
            }
        }
    }
    
    private var agentReplyCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center, spacing: 10) {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "#A855F7"), Color(hex: "#7C3AED")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 32, height: 32)
                    .overlay(
                        Image(systemName: "sparkles")
                            .font(.system(size: 14))
                            .foregroundColor(.white)
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Agent")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AgentColors.primaryText)
                    
                    Text("GPT-5.5 Thinking")
                        .font(AgentTypography.body)
                        .foregroundColor(AgentColors.secondaryText)
                }
            }
            
            Text("好的，我将为您分析本季度产品增长数据，并生成可视化图表和相关结论，最后输出一份汇报文档。")
                .font(.system(size: 14))
                .foregroundColor(AgentColors.primaryText)
                .lineSpacing(4)
            
            executionPlanSection
            
            analysisPreviewSection
            
            progressSection
        }
        .padding(24)
        .background(AgentColors.cardBackground)
        .cornerRadius(AgentLayout.cardRadius)
        .overlay(
            RoundedRectangle(cornerRadius: AgentLayout.cardRadius)
                .stroke(AgentColors.border, lineWidth: 1)
        )
        .padding(.top, 20)
    }
    
    private var executionPlanSection: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "list.bullet")
                    .font(.system(size: 14))
                    .foregroundColor(AgentColors.accentPurple)
                
                Text("执行计划")
                    .font(AgentTypography.sectionTitle)
                    .foregroundColor(AgentColors.primaryText)
            }
            
            VStack(spacing: 0) {
                ForEach(0..<executionSteps.count, id: \.self) { index in
                    let step = executionSteps[index]
                    HStack(alignment: .center, spacing: 8) {
                        stepStatusIcon(step.1)
                        
                        Text(step.0)
                            .font(AgentTypography.body)
                            .foregroundColor(AgentColors.primaryText)
                        
                        Spacer()
                    }
                    .frame(height: 28)
                }
            }
            .padding(.top, 8)
        }
    }
    
    @State private var isAnimating = false
    
    private func stepStatusIcon(_ status: TaskStatus) -> some View {
        Group {
            switch status {
            case .completed:
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(AgentColors.accentGreen)
            case .running:
                Circle()
                    .fill(AgentColors.accentPurple)
                    .frame(width: 14, height: 14)
                    .scaleEffect(isAnimating ? 1.0 : 0.8)
                    .opacity(isAnimating ? 1.0 : 0.6)
                    .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isAnimating)
                    .onAppear { isAnimating = true }
            case .waiting:
                Circle()
                    .fill(AgentColors.tertiaryText)
                    .frame(width: 14, height: 14)
            }
        }
    }
    
    private var analysisPreviewSection: some View {
        VStack(spacing: 12) {
            Text("分析结果预览")
                .font(AgentTypography.panelTitle)
                .foregroundColor(AgentColors.primaryText)
            
            HStack(spacing: 12) {
                ForEach(0..<previewCards.count, id: \.self) { index in
                    previewChartCard(title: previewCards[index], type: index)
                }
            }
        }
        .padding(.top, 20)
    }
    
    private func previewChartCard(title: String, type: Int) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(Color(hex: "#333333"))
                .padding(.top, 10)
                .padding(.leading, 10)
                .padding(.trailing, 10)
            
            Spacer()
            
            HStack {
                Spacer()
                mockChart(type: type)
                Spacer()
            }
            
            Spacer()
        }
        .frame(width: 132, height: 100)
        .background(AgentColors.cardBackground)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(AgentColors.border, lineWidth: 1)
        )
    }
    
    private func mockChart(type: Int) -> some View {
        Group {
            switch type {
            case 0:
                LineChartView()
            case 1:
                PieChartView()
            case 2:
                BarChartView()
            case 3:
                LineChartView()
            default:
                EmptyView()
            }
        }
    }
    
    private var progressSection: some View {
        VStack(spacing: 8) {
            Text("正在生成可视化图表...")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(AgentColors.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            GeometryReader { geometry in
                ProgressView(value: 0.6)
                    .progressViewStyle(LinearProgressViewStyle(tint: AgentColors.accentPurple))
                    .frame(height: 4)
                    .background(AgentColors.border)
                    .cornerRadius(2)
            }
            .frame(height: 4)
        }
        .padding(.top, 24)
    }
}

struct LineChartView: View {
    var body: some View {
        VStack {
            Path { path in
                let points: [(CGFloat, CGFloat)] = [
                    (0, 40), (15, 30), (30, 35), (45, 25), (60, 38), (75, 28), (90, 42)
                ]
                path.move(to: CGPoint(x: points[0].0, y: points[0].1))
                for i in 1..<points.count {
                    path.addLine(to: CGPoint(x: points[i].0, y: points[i].1))
                }
            }
            .stroke(AgentColors.accentPurple, lineWidth: 2)
        }
        .frame(width: 112, height: 50)
    }
}

struct PieChartView: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(AgentColors.border)
                .frame(width: 40, height: 40)
            
            Circle()
                .trim(from: 0, to: 0.42)
                .fill(AgentColors.accentPurple)
                .frame(width: 40, height: 40)
                .rotationEffect(.degrees(-90))
            
            Circle()
                .trim(from: 0.42, to: 0.8)
                .fill(Color(hex: "#C084FC"))
                .frame(width: 40, height: 40)
                .rotationEffect(.degrees(-90))
            
            Circle()
                .trim(from: 0.8, to: 1)
                .fill(Color(hex: "#E9D5FF"))
                .frame(width: 40, height: 40)
                .rotationEffect(.degrees(-90))
        }
        .frame(width: 112, height: 50)
    }
}

struct BarChartView: View {
    var body: some View {
        HStack(spacing: 6) {
            ForEach([40, 55, 35, 65, 45, 50], id: \.self) { height in
                Rectangle()
                    .fill(AgentColors.accentPurple)
                    .frame(width: 12, height: height)
                    .cornerRadius(6)
            }
        }
        .frame(width: 112, height: 70)
        .padding(.bottom, 10)
    }
}