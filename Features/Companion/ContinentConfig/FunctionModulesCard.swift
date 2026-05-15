import SwiftUI
import AcMindKit

struct FunctionModulesCard: View {
    @Binding var enabledFeatureIDs: Set<String>
    
    var body: some View {
        ConfigCardContainer {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("功能模块")
                        .font(ContinentConfigTypography.cardTitle)
                        .foregroundColor(ContinentConfigTokens.primaryText)
                    Text("开启桌面中的能力模块")
                        .font(ContinentConfigTypography.cardSubtitle)
                        .foregroundColor(ContinentConfigTokens.secondaryText)
                }
                .padding(.horizontal, ContinentConfigLayout.cardPadding)
                .padding(.top, 18)
                
                HStack(spacing: 14) {
                    ForEach(CompanionFeatureCatalog.cards) { card in
                        FunctionModuleTile(
                            card: card,
                            isEnabled: enabledFeatureIDs.contains(card.id)
                        ) {
                            toggleFeature(card.id)
                        }
                    }
                }
                .padding(.horizontal, ContinentConfigLayout.cardPadding)
                .padding(.top, 22)
            }
        }
    }
    
    private func toggleFeature(_ id: String) {
        if enabledFeatureIDs.contains(id) {
            enabledFeatureIDs.remove(id)
        } else {
            enabledFeatureIDs.insert(id)
        }
    }
}

struct FunctionModuleTile: View {
    let card: CompanionFeatureDefinition
    let isEnabled: Bool
    let toggle: () -> Void
    
    private var tierColor: Color {
        switch card.tier {
        case .pro:
            return ContinentConfigTokens.accentBlue
        case .free:
            return ContinentConfigTokens.accentGreen
        case .beta:
            return ContinentConfigTokens.accentOrange
        }
    }
    
    private var tierSymbolName: String {
        switch card.tier {
        case .pro:
            return "crown.fill"
        case .free:
            return "checkmark.seal.fill"
        case .beta:
            return "flask.fill"
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 8) {
                Circle()
                    .fill(tierColor.opacity(0.14))
                    .frame(width: 34, height: 34)
                    .overlay(
                        Image(systemName: tierSymbolName)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(tierColor)
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(card.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(ContinentConfigTokens.primaryText)
                    Text(card.subtitle)
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(ContinentConfigTokens.secondaryText)
                }
                
                Spacer()
            }
            
            HStack(spacing: 12) {
                Toggle("", isOn: Binding(
                    get: { isEnabled },
                    set: { newValue in
                        if newValue != isEnabled {
                            toggle()
                        }
                    }
                ))
                .labelsHidden()
                .tint(ContinentConfigTokens.accentBlue)
                .frame(width: 42)
                
                Spacer()
                
                Button("设置") { }
                    .buttonStyle(.borderless)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(ContinentConfigTokens.secondaryText)
            }
        }
        .padding(14)
        .frame(width: 190, height: 78)
        .background(ContinentConfigTokens.cardBackground, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(ContinentConfigTokens.border, lineWidth: 1))
        .shadow(color: .black.opacity(0.025), radius: 8, x: 0, y: 2)
    }
}
