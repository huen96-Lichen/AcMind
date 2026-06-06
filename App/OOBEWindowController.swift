import Cocoa
import AcMindKit

// MARK: - OOBE Window Controller

/// 首次启动引导窗口
/// 5 步线性流程：欢迎 → 权限 → ASR 引擎 → 润色模式 → 完成
@MainActor
final class OOBEWindowController: NSObject {
    static let completionDefaultsKey = "hasCompletedOOBE"
    
    // MARK: - Dependencies
    
    private let permissionManager: PermissionManager
    private let settingsService: SettingsServiceProtocol
    
    // MARK: - Callbacks
    
    var onFinish: ((String, VoicePolishMode) -> Void)?
    var onClose: (() -> Void)?
    
    // MARK: - Window State
    
    private var window: NSWindow?
    private var contentContainer: NSView!
    private var titleDots: [NSView] = []
    private var backButton: NSButton!
    private var nextButton: NSButton!
    
    private var currentStep: Int = 0
    private let totalSteps = 5
    
    // MARK: - Selection State
    
    private var selectedEngine: STTProvider = .appleSpeech
    private var selectedPolishMode: VoicePolishMode = .light
    private var engineCardViews: [EngineCardView] = []
    private var polishCardViews: [PolishCardView] = []
    
    // MARK: - Permission State
    
    private var permissionCards: [PermissionCardView] = []
    private var permissionRefreshTimer: Timer?
    
    // MARK: - Initialization
    
    init(permissionManager: PermissionManager, settingsService: SettingsServiceProtocol) {
        self.permissionManager = permissionManager
        self.settingsService = settingsService
        super.init()
    }
    
    // MARK: - Public Methods
    
    func showWindow() {
        if let w = window {
            w.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        // 加载当前设置
        Task {
            let voiceSettings = await settingsService.getVoiceSettings()
            selectedEngine = STTProvider(rawValue: voiceSettings.defaultProvider) ?? .appleSpeech
            selectedPolishMode = voiceSettings.voicePolishMode
            
            await MainActor.run {
                buildWindow()
            }
        }
    }
    
    // MARK: - Build Window
    
    private func buildWindow() {
        let w = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 720, height: 480),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        w.title = "AcMind 设置向导"
        w.isReleasedWhenClosed = false
        w.delegate = self
        
        guard let cv = w.contentView else { return }
        
        // 顶部步骤指示器
        let dotRow = NSStackView()
        dotRow.orientation = .horizontal
        dotRow.spacing = 8
        dotRow.translatesAutoresizingMaskIntoConstraints = false
        for _ in 0..<totalSteps {
            let dot = NSView()
            dot.wantsLayer = true
            dot.layer?.cornerRadius = 4
            dot.layer?.cornerCurve = .circular
            dot.translatesAutoresizingMaskIntoConstraints = false
            dot.widthAnchor.constraint(equalToConstant: 8).isActive = true
            dot.heightAnchor.constraint(equalToConstant: 8).isActive = true
            dotRow.addArrangedSubview(dot)
            titleDots.append(dot)
        }
        
        contentContainer = NSView()
        contentContainer.translatesAutoresizingMaskIntoConstraints = false
        
        backButton = NSButton(title: "上一步", target: self, action: #selector(backTapped))
        backButton.bezelStyle = .rounded
        backButton.translatesAutoresizingMaskIntoConstraints = false
        
        nextButton = NSButton(title: "下一步", target: self, action: #selector(nextTapped))
        nextButton.bezelStyle = .rounded
        nextButton.keyEquivalent = "\r"
        nextButton.translatesAutoresizingMaskIntoConstraints = false
        
        let footerSpacer = NSView()
        footerSpacer.translatesAutoresizingMaskIntoConstraints = false
        footerSpacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        
        let footerRow = NSStackView(views: [backButton, footerSpacer, nextButton])
        footerRow.orientation = .horizontal
        footerRow.spacing = 12
        footerRow.translatesAutoresizingMaskIntoConstraints = false
        
        cv.addSubview(dotRow)
        cv.addSubview(contentContainer)
        cv.addSubview(footerRow)
        
        NSLayoutConstraint.activate([
            contentContainer.topAnchor.constraint(equalTo: cv.topAnchor, constant: 28),
            contentContainer.leadingAnchor.constraint(equalTo: cv.leadingAnchor, constant: 28),
            contentContainer.trailingAnchor.constraint(equalTo: cv.trailingAnchor, constant: -28),
            contentContainer.bottomAnchor.constraint(equalTo: footerRow.topAnchor, constant: -14),
            
            footerRow.leadingAnchor.constraint(equalTo: cv.leadingAnchor, constant: 24),
            footerRow.trailingAnchor.constraint(equalTo: cv.trailingAnchor, constant: -24),
            footerRow.bottomAnchor.constraint(equalTo: cv.bottomAnchor, constant: -20),
            
            dotRow.centerXAnchor.constraint(equalTo: cv.centerXAnchor),
            dotRow.centerYAnchor.constraint(equalTo: footerRow.centerYAnchor),
        ])
        
        self.window = w
        showStep(0)
        w.center()
        w.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    // MARK: - Step Navigation
    
    private func showStep(_ step: Int) {
        currentStep = step
        updateDots()
        contentContainer.subviews.forEach { $0.removeFromSuperview() }
        stopPermissionRefresh()
        
        let stepView: NSView
        switch step {
        case 0: stepView = makeWelcomeStep()
        case 1: stepView = makePermissionsStep()
        case 2: stepView = makeEngineStep()
        case 3: stepView = makePolishModeStep()
        case 4: stepView = makeDoneStep()
        default: return
        }
        stepView.translatesAutoresizingMaskIntoConstraints = false
        contentContainer.addSubview(stepView)
        NSLayoutConstraint.activate([
            stepView.topAnchor.constraint(equalTo: contentContainer.topAnchor),
            stepView.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor),
            stepView.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor),
            stepView.bottomAnchor.constraint(equalTo: contentContainer.bottomAnchor),
        ])
        
        backButton.isHidden = (step == 0)
        nextButton.title = (step == totalSteps - 1) ? "完成" : "下一步"
    }
    
    private func updateDots() {
        let appearance = window?.effectiveAppearance ?? NSApp.effectiveAppearance
        appearance.performAsCurrentDrawingAppearance {
            let active = NSColor.controlAccentColor.cgColor
            let inactive = NSColor.systemGray.withAlphaComponent(0.45).cgColor
            for (i, dot) in titleDots.enumerated() {
                dot.layer?.backgroundColor = (i == currentStep) ? active : inactive
            }
        }
    }
    
    @objc private func backTapped() {
        if currentStep > 0 { showStep(currentStep - 1) }
    }
    
    @objc private func nextTapped() {
        if currentStep == totalSteps - 1 {
            finish()
        } else {
            showStep(currentStep + 1)
        }
    }
    
    private func finish() {
        UserDefaults.standard.set(true, forKey: Self.completionDefaultsKey)
        
        Task {
            var voiceSettings = await settingsService.getVoiceSettings()
            voiceSettings.defaultProvider = selectedEngine.rawValue
            voiceSettings.voicePolishMode = selectedPolishMode
            try? await settingsService.updateVoiceSettings(voiceSettings)
            
            await MainActor.run {
                window?.close()
                onFinish?(selectedEngine.rawValue, selectedPolishMode)
            }
        }
    }
    
    // MARK: - Step 0: Welcome
    
    private func makeWelcomeStep() -> NSView {
        let v = NSStackView()
        v.orientation = .vertical
        v.alignment = .centerX
        v.spacing = 14
        
        let icon = NSImageView()
        icon.image = NSApp.applicationIconImage
        icon.imageScaling = .scaleProportionallyDown
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.widthAnchor.constraint(equalToConstant: 96).isActive = true
        icon.heightAnchor.constraint(equalToConstant: 96).isActive = true
        
        let title = NSTextField(labelWithString: "欢迎使用 AcMind")
        title.font = .systemFont(ofSize: 26, weight: .semibold)
        title.alignment = .center
        
        let tagline = NSTextField(labelWithString: "智能语音助手，让输入更高效")
        tagline.font = .systemFont(ofSize: 16, weight: .medium)
        tagline.textColor = .labelColor
        tagline.alignment = .center
        
        let subtitle = NSTextField(labelWithString: "接下来我们将引导您完成基本设置，让 AcMind 更好地为您服务。")
        subtitle.font = .systemFont(ofSize: 13)
        subtitle.textColor = .secondaryLabelColor
        subtitle.alignment = .center
        subtitle.lineBreakMode = .byWordWrapping
        subtitle.maximumNumberOfLines = 0
        subtitle.preferredMaxLayoutWidth = 540
        
        let hint = NSTextField(labelWithString: "设置向导大约需要 2 分钟")
        hint.font = .systemFont(ofSize: 12)
        hint.textColor = .tertiaryLabelColor
        hint.alignment = .center
        
        let topSpacer = NSView()
        let botSpacer = NSView()
        
        v.addArrangedSubview(topSpacer)
        v.addArrangedSubview(icon)
        v.setCustomSpacing(20, after: icon)
        v.addArrangedSubview(title)
        v.setCustomSpacing(6, after: title)
        v.addArrangedSubview(tagline)
        v.setCustomSpacing(64, after: tagline)
        v.addArrangedSubview(subtitle)
        v.setCustomSpacing(8, after: subtitle)
        v.addArrangedSubview(hint)
        v.addArrangedSubview(botSpacer)
        topSpacer.heightAnchor.constraint(equalTo: botSpacer.heightAnchor).isActive = true
        
        return v
    }
    
    // MARK: - Step 1: Permissions
    
    private func makePermissionsStep() -> NSView {
        let v = NSStackView()
        v.orientation = .vertical
        v.alignment = .leading
        v.spacing = 0
        
        let heading = NSTextField(labelWithString: "权限设置")
        heading.font = .systemFont(ofSize: 22, weight: .semibold)
        v.addArrangedSubview(heading)
        v.setCustomSpacing(6, after: heading)
        
        let sub = NSTextField(labelWithString: "AcMind 需要以下权限才能正常工作，请依次授予：")
        sub.font = .systemFont(ofSize: 12.5)
        sub.textColor = .secondaryLabelColor
        sub.lineBreakMode = .byWordWrapping
        sub.maximumNumberOfLines = 0
        sub.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        v.addArrangedSubview(sub)
        sub.widthAnchor.constraint(equalTo: v.widthAnchor).isActive = true
        v.setCustomSpacing(18, after: sub)
        
        // 权限卡片
        let cards = NSStackView()
        cards.orientation = .horizontal
        cards.distribution = .fillEqually
        cards.spacing = 12
        cards.translatesAutoresizingMaskIntoConstraints = false
        
        permissionCards = []
        let perms: [(String, String, String, NSColor, AppPermissionKind)] = [
            ("辅助功能", "用于读取光标位置和插入文本", "accessibility", .systemBlue, .accessibility),
            ("麦克风", "用于语音录制", "mic.fill", .systemPink, .microphone),
            ("语音识别", "用于语音转文字", "waveform", .systemPurple, .speechRecognition),
        ]
        for p in perms {
            let card = PermissionCardView(title: p.0, desc: p.1, iconName: p.2, iconColor: p.3, permissionKind: p.4, target: self, action: #selector(permTapped(_:)))
            cards.addArrangedSubview(card)
            permissionCards.append(card)
        }
        v.addArrangedSubview(cards)
        cards.widthAnchor.constraint(equalTo: v.widthAnchor).isActive = true
        
        refreshPermissions()
        startPermissionRefresh()
        return v
    }
    
    private func startPermissionRefresh() {
        permissionRefreshTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshPermissions()
            }
        }
    }
    
    private func stopPermissionRefresh() {
        permissionRefreshTimer?.invalidate()
        permissionRefreshTimer = nil
    }
    
    private func refreshPermissions() {
        let accessibilityStatus = permissionManager.statuses[.accessibility] ?? .unknown
        let microphoneStatus = permissionManager.statuses[.microphone] ?? .unknown
        let speechStatus = permissionManager.statuses[.speechRecognition] ?? .unknown

        permissionCards[0].update(status: accessibilityStatus)
        permissionCards[1].update(status: microphoneStatus)
        permissionCards[2].update(status: speechStatus)
    }
    
    @objc private func permTapped(_ sender: NSButton) {
        guard let kind = AppPermissionKind(rawValue: sender.identifier?.rawValue ?? "") else { return }
        Task {
            await permissionManager.request(kind)
            refreshPermissions()
        }
    }
    
    // MARK: - Step 2: ASR Engine
    
    private func makeEngineStep() -> NSView {
        let v = NSStackView()
        v.orientation = .vertical
        v.alignment = .leading
        v.spacing = 0
        
        let heading = NSTextField(labelWithString: "语音识别引擎")
        heading.font = .systemFont(ofSize: 22, weight: .semibold)
        v.addArrangedSubview(heading)
        v.setCustomSpacing(6, after: heading)
        
        let sub = NSTextField(labelWithString: "选择适合您的语音识别引擎。本地引擎更隐私，云端引擎更准确。")
        sub.font = .systemFont(ofSize: 12.5)
        sub.textColor = .secondaryLabelColor
        sub.lineBreakMode = .byWordWrapping
        sub.maximumNumberOfLines = 0
        v.addArrangedSubview(sub)
        sub.widthAnchor.constraint(equalTo: v.widthAnchor).isActive = true
        v.setCustomSpacing(20, after: sub)
        
        // 引擎卡片
        let cards = NSStackView()
        cards.orientation = .horizontal
        cards.distribution = .fillEqually
        cards.spacing = 12
        cards.translatesAutoresizingMaskIntoConstraints = false
        
        engineCardViews = []
        let engines: [(STTProvider, String, String, String, NSColor, String, String)] = [
            (.appleSpeech, "系统听写", "开箱即用，无需配置", "apple.logo", .labelColor, "免费", "隐私中等"),
            (.senseVoice, "本地识别", "完全离线，隐私保护", "lock.shield.fill", .systemGreen, "免费", "隐私最高"),
            (.openAI, "云端识别", "高准确率，支持多语言", "cloud.fill", .systemBlue, "付费", "隐私较低"),
        ]
        for engine in engines {
            let card = EngineCardView(
                provider: engine.0,
                title: engine.1,
                desc: engine.2,
                iconName: engine.3,
                iconColor: engine.4,
                costText: engine.5,
                privacyText: engine.6,
                target: self,
                action: #selector(engineTapped(_:))
            )
            cards.addArrangedSubview(card)
            engineCardViews.append(card)
        }
        v.addArrangedSubview(cards)
        cards.widthAnchor.constraint(equalTo: v.widthAnchor).isActive = true
        
        applyEngineSelection()
        return v
    }
    
    @objc private func engineTapped(_ sender: NSButton) {
        guard let provider = STTProvider(rawValue: sender.identifier?.rawValue ?? "") else { return }
        selectedEngine = provider
        applyEngineSelection()
    }
    
    private func applyEngineSelection() {
        for card in engineCardViews {
            card.setSelected(card.provider == selectedEngine)
        }
    }
    
    // MARK: - Step 3: Polish Mode
    
    private func makePolishModeStep() -> NSView {
        let v = NSStackView()
        v.orientation = .vertical
        v.alignment = .leading
        v.spacing = 0
        
        let heading = NSTextField(labelWithString: "润色模式")
        heading.font = .systemFont(ofSize: 22, weight: .semibold)
        v.addArrangedSubview(heading)
        v.setCustomSpacing(6, after: heading)
        
        let sub = NSTextField(labelWithString: "选择语音输入后的文本润色模式。")
        sub.font = .systemFont(ofSize: 12.5)
        sub.textColor = .secondaryLabelColor
        sub.lineBreakMode = .byWordWrapping
        sub.maximumNumberOfLines = 0
        v.addArrangedSubview(sub)
        sub.widthAnchor.constraint(equalTo: v.widthAnchor).isActive = true
        v.setCustomSpacing(20, after: sub)
        
        // 润色模式卡片
        let cards = NSStackView()
        cards.orientation = .horizontal
        cards.distribution = .fillEqually
        cards.spacing = 12
        cards.translatesAutoresizingMaskIntoConstraints = false
        
        polishCardViews = []
        let modes: [(VoicePolishMode, String, String, String)] = [
            (.light, "轻度润色", "去掉口癖、重复、停顿，补充标点", "推荐"),
            (.raw, "原文整理", "仅补全标点，保留原话", ""),
            (.structured, "结构化", "按语义归类，适合任务清单", ""),
            (.formal, "正式表达", "适合工作沟通和邮件", ""),
        ]
        for mode in modes {
            let card = PolishCardView(
                mode: mode.0,
                title: mode.1,
                desc: mode.2,
                badge: mode.3,
                target: self,
                action: #selector(polishModeTapped(_:))
            )
            cards.addArrangedSubview(card)
            polishCardViews.append(card)
        }
        v.addArrangedSubview(cards)
        cards.widthAnchor.constraint(equalTo: v.widthAnchor).isActive = true
        
        applyPolishModeSelection()
        return v
    }
    
    @objc private func polishModeTapped(_ sender: NSButton) {
        guard let mode = VoicePolishMode(rawValue: sender.identifier?.rawValue ?? "") else { return }
        selectedPolishMode = mode
        applyPolishModeSelection()
    }
    
    private func applyPolishModeSelection() {
        for card in polishCardViews {
            card.setSelected(card.mode == selectedPolishMode)
        }
    }
    
    // MARK: - Step 4: Done
    
    private func makeDoneStep() -> NSView {
        let v = NSStackView()
        v.orientation = .vertical
        v.alignment = .centerX
        v.spacing = 14
        
        let check = NSImageView()
        check.image = NSImage(systemSymbolName: "checkmark.circle.fill", accessibilityDescription: nil)
        check.symbolConfiguration = .init(pointSize: 64, weight: .regular)
        check.contentTintColor = NSColor(red: 0.15, green: 0.78, blue: 0.33, alpha: 1)
        
        let title = NSTextField(labelWithString: "设置完成！")
        title.font = .systemFont(ofSize: 24, weight: .semibold)
        title.alignment = .center
        
        let body = NSTextField(labelWithString: "AcMind 已准备就绪。按住 Fn 键开始语音输入。")
        body.font = .systemFont(ofSize: 13)
        body.textColor = .secondaryLabelColor
        body.alignment = .center
        body.lineBreakMode = .byWordWrapping
        body.maximumNumberOfLines = 0
        body.preferredMaxLayoutWidth = 540
        
        let followup = NSTextField(labelWithString: "您可以在设置中随时修改这些配置。")
        followup.font = .systemFont(ofSize: 12)
        followup.textColor = .tertiaryLabelColor
        followup.alignment = .center
        
        let topSpacer = NSView()
        let botSpacer = NSView()
        v.addArrangedSubview(topSpacer)
        v.addArrangedSubview(check)
        v.setCustomSpacing(16, after: check)
        v.addArrangedSubview(title)
        v.setCustomSpacing(8, after: title)
        v.addArrangedSubview(body)
        v.setCustomSpacing(20, after: body)
        v.addArrangedSubview(followup)
        v.addArrangedSubview(botSpacer)
        topSpacer.heightAnchor.constraint(equalTo: botSpacer.heightAnchor).isActive = true
        
        return v
    }
}

// MARK: - NSWindowDelegate

extension OOBEWindowController: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        stopPermissionRefresh()
        onClose?()
    }
}

// MARK: - Permission Card View

final class PermissionCardView: NSView {
    private let titleLabel: NSTextField
    private let descLabel: NSTextField
    private let actionBtn: NSButton
    private let iconView: NSImageView
    private let statusDot = NSView()
    private let statusLabel = NSTextField(labelWithString: "")
    private let permissionKind: AppPermissionKind
    private var currentStatus: AppPermissionStatus = .unknown
    
    init(title: String, desc: String, iconName: String, iconColor: NSColor,
         permissionKind: AppPermissionKind, target: AnyObject, action: Selector) {
        self.titleLabel = NSTextField(labelWithString: title)
        self.descLabel = NSTextField(labelWithString: desc)
        self.actionBtn = NSButton(title: "", target: target, action: action)
        self.iconView = NSImageView()
        self.permissionKind = permissionKind
        super.init(frame: .zero)
        self.actionBtn.identifier = NSUserInterfaceItemIdentifier(permissionKind.rawValue)
        self.iconView.image = NSImage(systemSymbolName: iconName, accessibilityDescription: nil)
        self.iconView.symbolConfiguration = .init(pointSize: 28, weight: .regular)
        self.iconView.contentTintColor = iconColor
        setup()
    }
    required init?(coder: NSCoder) { fatalError() }
    
    override var wantsUpdateLayer: Bool { true }
    override func updateLayer() {
        effectiveAppearance.performAsCurrentDrawingAppearance {
            let isDark = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            let bg = isDark ? NSColor(white: 0.20, alpha: 1) : NSColor(white: 0.97, alpha: 1)
            layer?.backgroundColor = bg.cgColor
        }
    }
    
    private func setup() {
        wantsLayer = true
        layer?.cornerRadius = 14
        layer?.cornerCurve = .continuous
        
        iconView.translatesAutoresizingMaskIntoConstraints = false
        
        titleLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        titleLabel.textColor = .labelColor
        
        descLabel.font = .systemFont(ofSize: 11.5)
        descLabel.textColor = .secondaryLabelColor
        descLabel.lineBreakMode = .byWordWrapping
        descLabel.maximumNumberOfLines = 0
        descLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        
        statusDot.wantsLayer = true
        statusDot.layer?.cornerRadius = 5
        statusDot.layer?.cornerCurve = .circular
        statusDot.translatesAutoresizingMaskIntoConstraints = false
        statusDot.widthAnchor.constraint(equalToConstant: 10).isActive = true
        statusDot.heightAnchor.constraint(equalToConstant: 10).isActive = true
        
        statusLabel.font = .systemFont(ofSize: 12, weight: .medium)
        
        let statusRow = NSStackView(views: [statusDot, statusLabel])
        statusRow.orientation = .horizontal
        statusRow.spacing = 6
        statusRow.alignment = .centerY
        
        actionBtn.bezelStyle = .rounded
        actionBtn.translatesAutoresizingMaskIntoConstraints = false
        
        let v = NSStackView()
        v.orientation = .vertical
        v.alignment = .leading
        v.spacing = 0
        v.translatesAutoresizingMaskIntoConstraints = false
        v.addArrangedSubview(iconView)
        v.setCustomSpacing(12, after: iconView)
        v.addArrangedSubview(titleLabel)
        v.setCustomSpacing(6, after: titleLabel)
        v.addArrangedSubview(descLabel)
        
        let sep = NSBox()
        sep.boxType = .separator
        sep.translatesAutoresizingMaskIntoConstraints = false
        
        addSubview(v)
        addSubview(sep)
        addSubview(statusRow)
        addSubview(actionBtn)
        descLabel.widthAnchor.constraint(equalTo: v.widthAnchor).isActive = true
        
        NSLayoutConstraint.activate([
            v.topAnchor.constraint(equalTo: topAnchor, constant: 18),
            v.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            v.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            
            sep.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            sep.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            sep.bottomAnchor.constraint(equalTo: statusRow.topAnchor, constant: -12),
            
            statusRow.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            statusRow.bottomAnchor.constraint(equalTo: actionBtn.topAnchor, constant: -10),
            
            actionBtn.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            actionBtn.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            actionBtn.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -16),
        ])
    }
    
    func update(status: AppPermissionStatus) {
        currentStatus = status
        let color: NSColor
        let label: String
        let buttonTitle: String
        
        switch status {
        case .authorized:
            color = .systemGreen
            label = "已授权"
            buttonTitle = "已授权"
        case .denied, .needsSystemSettings:
            color = .systemRed
            label = "已拒绝"
            buttonTitle = "打开设置"
        case .restricted:
            color = .systemOrange
            label = "受限"
            buttonTitle = "打开设置"
        case .unknown, .notDetermined, .requesting:
            color = .systemGray
            label = "未授权"
            buttonTitle = "授权"
        case .failed:
            color = .systemRed
            label = "失败"
            buttonTitle = "重试"
        }
        
        statusDot.layer?.backgroundColor = color.cgColor
        statusLabel.stringValue = label
        statusLabel.textColor = color
        actionBtn.title = buttonTitle
    }
}

// MARK: - Engine Card View

final class EngineCardView: NSView {
    let provider: STTProvider
    var selected = false
    
    private let titleLabel: NSTextField
    private let descLabel: NSTextField
    private let iconView: NSImageView
    private let costLabel: NSTextField
    private let privacyLabel: NSTextField
    private let actionBtn: NSButton
    
    init(provider: STTProvider, title: String, desc: String, iconName: String, iconColor: NSColor,
         costText: String, privacyText: String, target: AnyObject, action: Selector) {
        self.provider = provider
        self.titleLabel = NSTextField(labelWithString: title)
        self.descLabel = NSTextField(labelWithString: desc)
        self.iconView = NSImageView()
        self.costLabel = NSTextField(labelWithString: costText)
        self.privacyLabel = NSTextField(labelWithString: privacyText)
        self.actionBtn = NSButton(title: "", target: target, action: action)
        super.init(frame: .zero)
        self.actionBtn.identifier = NSUserInterfaceItemIdentifier(provider.rawValue)
        self.iconView.image = NSImage(systemSymbolName: iconName, accessibilityDescription: nil)
        self.iconView.symbolConfiguration = .init(pointSize: 28, weight: .regular)
        self.iconView.contentTintColor = iconColor
        setup()
    }
    required init?(coder: NSCoder) { fatalError() }
    
    override var wantsUpdateLayer: Bool { true }
    override func updateLayer() {
        effectiveAppearance.performAsCurrentDrawingAppearance {
            let isDark = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            let bg = isDark ? NSColor(white: 0.20, alpha: 1) : NSColor(white: 0.97, alpha: 1)
            layer?.backgroundColor = bg.cgColor
            layer?.borderColor = selected ? NSColor.controlAccentColor.cgColor : NSColor.clear.cgColor
        }
    }
    
    private func setup() {
        wantsLayer = true
        layer?.cornerRadius = 14
        layer?.cornerCurve = .continuous
        layer?.borderWidth = 2
        
        iconView.translatesAutoresizingMaskIntoConstraints = false
        
        titleLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        titleLabel.textColor = .labelColor
        
        descLabel.font = .systemFont(ofSize: 11.5)
        descLabel.textColor = .secondaryLabelColor
        descLabel.lineBreakMode = .byWordWrapping
        descLabel.maximumNumberOfLines = 0
        
        costLabel.font = .systemFont(ofSize: 11)
        costLabel.textColor = .tertiaryLabelColor
        
        privacyLabel.font = .systemFont(ofSize: 11)
        privacyLabel.textColor = .tertiaryLabelColor
        
        actionBtn.bezelStyle = .rounded
        actionBtn.translatesAutoresizingMaskIntoConstraints = false
        
        let v = NSStackView()
        v.orientation = .vertical
        v.alignment = .leading
        v.spacing = 0
        v.translatesAutoresizingMaskIntoConstraints = false
        v.addArrangedSubview(iconView)
        v.setCustomSpacing(12, after: iconView)
        v.addArrangedSubview(titleLabel)
        v.setCustomSpacing(6, after: titleLabel)
        v.addArrangedSubview(descLabel)
        v.setCustomSpacing(12, after: descLabel)
        v.addArrangedSubview(costLabel)
        v.setCustomSpacing(4, after: costLabel)
        v.addArrangedSubview(privacyLabel)
        
        addSubview(v)
        addSubview(actionBtn)
        descLabel.widthAnchor.constraint(equalTo: v.widthAnchor).isActive = true
        
        NSLayoutConstraint.activate([
            v.topAnchor.constraint(equalTo: topAnchor, constant: 18),
            v.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            v.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            
            actionBtn.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            actionBtn.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            actionBtn.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -16),
        ])
    }
    
    func setSelected(_ value: Bool) {
        selected = value
        needsDisplay = true
    }
}

// MARK: - Polish Card View

final class PolishCardView: NSView {
    let mode: VoicePolishMode
    var selected = false
    
    private let titleLabel: NSTextField
    private let descLabel: NSTextField
    private let badgeLabel: NSTextField?
    private let actionBtn: NSButton
    
    init(mode: VoicePolishMode, title: String, desc: String, badge: String,
         target: AnyObject, action: Selector) {
        self.mode = mode
        self.titleLabel = NSTextField(labelWithString: title)
        self.descLabel = NSTextField(labelWithString: desc)
        self.badgeLabel = badge.isEmpty ? nil : NSTextField(labelWithString: badge)
        self.actionBtn = NSButton(title: "", target: target, action: action)
        super.init(frame: .zero)
        self.actionBtn.identifier = NSUserInterfaceItemIdentifier(mode.rawValue)
        setup()
    }
    required init?(coder: NSCoder) { fatalError() }
    
    override var wantsUpdateLayer: Bool { true }
    override func updateLayer() {
        effectiveAppearance.performAsCurrentDrawingAppearance {
            let isDark = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            let bg = isDark ? NSColor(white: 0.20, alpha: 1) : NSColor(white: 0.97, alpha: 1)
            layer?.backgroundColor = bg.cgColor
            layer?.borderColor = selected ? NSColor.controlAccentColor.cgColor : NSColor.clear.cgColor
        }
    }
    
    private func setup() {
        wantsLayer = true
        layer?.cornerRadius = 14
        layer?.cornerCurve = .continuous
        layer?.borderWidth = 2
        
        titleLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        titleLabel.textColor = .labelColor
        
        descLabel.font = .systemFont(ofSize: 11.5)
        descLabel.textColor = .secondaryLabelColor
        descLabel.lineBreakMode = .byWordWrapping
        descLabel.maximumNumberOfLines = 0
        
        if let badge = badgeLabel {
            badge.font = .systemFont(ofSize: 10, weight: .semibold)
            badge.textColor = .white
            badge.alignment = .center
            badge.translatesAutoresizingMaskIntoConstraints = false
            
            let badgeBg = NSView()
            badgeBg.wantsLayer = true
            badgeBg.layer?.cornerRadius = 6
            badgeBg.layer?.cornerCurve = .continuous
            badgeBg.layer?.backgroundColor = NSColor.controlAccentColor.cgColor
            badgeBg.translatesAutoresizingMaskIntoConstraints = false
            badgeBg.addSubview(badge)
            NSLayoutConstraint.activate([
                badge.topAnchor.constraint(equalTo: badgeBg.topAnchor, constant: 2),
                badge.bottomAnchor.constraint(equalTo: badgeBg.bottomAnchor, constant: -2),
                badge.leadingAnchor.constraint(equalTo: badgeBg.leadingAnchor, constant: 6),
                badge.trailingAnchor.constraint(equalTo: badgeBg.trailingAnchor, constant: -6),
            ])
        }
        
        actionBtn.bezelStyle = .rounded
        actionBtn.translatesAutoresizingMaskIntoConstraints = false
        
        let v = NSStackView()
        v.orientation = .vertical
        v.alignment = .leading
        v.spacing = 0
        v.translatesAutoresizingMaskIntoConstraints = false
        v.addArrangedSubview(titleLabel)
        v.setCustomSpacing(6, after: titleLabel)
        v.addArrangedSubview(descLabel)
        
        if let badge = badgeLabel {
            v.setCustomSpacing(8, after: descLabel)
            v.addArrangedSubview(badge)
        }
        
        addSubview(v)
        addSubview(actionBtn)
        descLabel.widthAnchor.constraint(equalTo: v.widthAnchor).isActive = true
        
        NSLayoutConstraint.activate([
            v.topAnchor.constraint(equalTo: topAnchor, constant: 18),
            v.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            v.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            
            actionBtn.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            actionBtn.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            actionBtn.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -16),
        ])
    }
    
    func setSelected(_ value: Bool) {
        selected = value
        needsDisplay = true
    }
}
