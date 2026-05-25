//
//  BatteryService.swift
//  AcMind
//
//  Adapted from BoringNotch BatteryActivityManager
//

import Foundation
import IOKit.ps
import Combine

// MARK: - Battery Info

/// 电池信息
public struct BatteryInfo: Sendable {
    public var isPluggedIn: Bool
    public var isCharging: Bool
    public var currentCapacity: Float
    public var maxCapacity: Float
    public var isInLowPowerMode: Bool
    public var timeToFullCharge: Int

    public init(
        isPluggedIn: Bool = false,
        isCharging: Bool = false,
        currentCapacity: Float = 0,
        maxCapacity: Float = 100,
        isInLowPowerMode: Bool = false,
        timeToFullCharge: Int = 0
    ) {
        self.isPluggedIn = isPluggedIn
        self.isCharging = isCharging
        self.currentCapacity = currentCapacity
        self.maxCapacity = maxCapacity
        self.isInLowPowerMode = isInLowPowerMode
        self.timeToFullCharge = timeToFullCharge
    }
}

// MARK: - Battery Event

public enum BatteryEvent: Sendable {
    case powerSourceChanged(isPluggedIn: Bool)
    case batteryLevelChanged(level: Float)
    case lowPowerModeChanged(isEnabled: Bool)
    case isChargingChanged(isCharging: Bool)
    case timeToFullChargeChanged(time: Int)
    case maxCapacityChanged(capacity: Float)
}

// MARK: - Battery Service

/// 电池状态服务 - 监控电池状态变化
@MainActor
public class BatteryService: ObservableObject {
    public static let shared = BatteryService()

    @Published public private(set) var batteryInfo: BatteryInfo = BatteryInfo()

    private var batterySource: CFRunLoopSource?
    private var cancellables = Set<AnyCancellable>()

    private init() {
        setupMonitoring()
        setupLowPowerModeObserver()
        updateBatteryInfo()
    }

    // MARK: - Setup

    private func setupMonitoring() {
        guard let powerSource = IOPSNotificationCreateRunLoopSource({ context in
            guard let context = context else { return }
            let service = Unmanaged<BatteryService>.fromOpaque(context).takeUnretainedValue()
            Task { @MainActor in
                service.updateBatteryInfo()
            }
        }, Unmanaged.passUnretained(self).toOpaque())?.takeRetainedValue() else {
            return
        }
        batterySource = powerSource
        CFRunLoopAddSource(CFRunLoopGetCurrent(), powerSource, .defaultMode)
    }

    private func setupLowPowerModeObserver() {
        NotificationCenter.default.publisher(
            for: NSNotification.Name.NSProcessInfoPowerStateDidChange
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] _ in
            self?.updateBatteryInfo()
        }
        .store(in: &cancellables)
    }

    // MARK: - Update

    private func updateBatteryInfo() {
        do {
            guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue() else {
                throw NSError(domain: "BatteryService", code: -1)
            }

            guard let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef],
                  !sources.isEmpty else {
                throw NSError(domain: "BatteryService", code: -2)
            }

            let source = sources.first!

            guard let description = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any] else {
                throw NSError(domain: "BatteryService", code: -3)
            }

            let currentCapacity = description[kIOPSCurrentCapacityKey] as? Float ?? 0
            let maxCapacity = description[kIOPSMaxCapacityKey] as? Float ?? 100
            let isCharging = description["Is Charging"] as? Bool ?? false
            let powerSource = description[kIOPSPowerSourceStateKey] as? String ?? ""
            let timeToFullCharge = description[kIOPSTimeToFullChargeKey] as? Int ?? 0

            batteryInfo = BatteryInfo(
                isPluggedIn: powerSource == kIOPSACPowerValue,
                isCharging: isCharging,
                currentCapacity: currentCapacity,
                maxCapacity: maxCapacity,
                isInLowPowerMode: Foundation.ProcessInfo.processInfo.isLowPowerModeEnabled,
                timeToFullCharge: timeToFullCharge
            )
        } catch {
            // 保持默认值
        }
    }

}

// MARK: - Battery View

import SwiftUI

/// 电池状态视图
public struct BatteryIndicatorView: View {
    @ObservedObject private var batteryService = BatteryService.shared
    var batteryWidth: CGFloat = 26
    var showPercentage: Bool = true

    public init(batteryWidth: CGFloat = 26, showPercentage: Bool = true) {
        self.batteryWidth = batteryWidth
        self.showPercentage = showPercentage
    }

    public var body: some View {
        HStack(spacing: 6) {
            if showPercentage {
                Text("\(Int(batteryService.batteryInfo.currentCapacity))%")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.white)
            }

            batteryIcon
        }
    }

    private var batteryIcon: some View {
        ZStack(alignment: .leading) {
            // 电池轮廓
            Image(systemName: "battery.0")
                .resizable()
                .fontWeight(.thin)
                .aspectRatio(contentMode: .fit)
                .foregroundStyle(Color.white.opacity(0.5))
                .frame(width: batteryWidth + 1)

            // 电量条
            RoundedRectangle(cornerRadius: 2.5)
                .fill(batteryColor)
                .frame(
                    width: CGFloat((CGFloat(batteryService.batteryInfo.currentCapacity) / 100) * (batteryWidth - 6)),
                    height: (batteryWidth - 2.75) - 18
                )
                .padding(.leading, 2)

            // 充电图标
            if batteryService.batteryInfo.isCharging || batteryService.batteryInfo.isPluggedIn {
                Image(systemName: batteryService.batteryInfo.isCharging ? "bolt.fill" : "plug.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .foregroundStyle(Color.white)
                    .frame(width: 12, height: 12)
                    .frame(width: batteryWidth, height: batteryWidth)
            }
        }
    }

    private var batteryColor: Color {
        let info = batteryService.batteryInfo
        if info.isInLowPowerMode {
            return .yellow
        } else if info.currentCapacity <= 20 && !info.isCharging && !info.isPluggedIn {
            return .red
        } else if info.isCharging || info.isPluggedIn || info.currentCapacity == 100 {
            return .green
        } else {
            return .white
        }
    }
}
