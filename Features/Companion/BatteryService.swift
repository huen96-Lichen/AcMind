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
    public var isAvailable: Bool
    public var isPluggedIn: Bool
    public var isCharging: Bool
    public var currentCapacity: Float
    public var maxCapacity: Float
    public var designCapacity: Float?
    public var isInLowPowerMode: Bool
    public var timeToFullCharge: Int
    public var powerSourceState: String
    public var healthPercentage: Float?

    public var percentage: Float {
        guard maxCapacity > 0 else { return currentCapacity }
        return max(0, min(100, (currentCapacity / maxCapacity) * 100))
    }

    public init(
        isAvailable: Bool = true,
        isPluggedIn: Bool = false,
        isCharging: Bool = false,
        currentCapacity: Float = 0,
        maxCapacity: Float = 100,
        designCapacity: Float? = nil,
        isInLowPowerMode: Bool = false,
        timeToFullCharge: Int = 0,
        powerSourceState: String = "",
        healthPercentage: Float? = nil
    ) {
        self.isAvailable = isAvailable
        self.isPluggedIn = isPluggedIn
        self.isCharging = isCharging
        self.currentCapacity = currentCapacity
        self.maxCapacity = maxCapacity
        self.designCapacity = designCapacity
        self.isInLowPowerMode = isInLowPowerMode
        self.timeToFullCharge = timeToFullCharge
        self.powerSourceState = powerSourceState
        self.healthPercentage = healthPercentage
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
    @Published public private(set) var batteryInfo: BatteryInfo = BatteryInfo()

    private var batterySource: CFRunLoopSource?
    private var cancellables = Set<AnyCancellable>()

    public init() {
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
            let designCapacity = description[kIOPSDesignCapacityKey] as? Float
            let isCharging = description["Is Charging"] as? Bool ?? false
            let powerSource = description[kIOPSPowerSourceStateKey] as? String ?? ""
            let timeToFullCharge = description[kIOPSTimeToFullChargeKey] as? Int ?? 0
            let healthPercentage: Float? = {
                guard let designCapacity, designCapacity > 0 else { return nil }
                return max(0, min(100, (maxCapacity / designCapacity) * 100))
            }()

            batteryInfo = BatteryInfo(
                isAvailable: true,
                isPluggedIn: powerSource == kIOPSACPowerValue,
                isCharging: isCharging,
                currentCapacity: currentCapacity,
                maxCapacity: maxCapacity,
                designCapacity: designCapacity,
                isInLowPowerMode: Foundation.ProcessInfo.processInfo.isLowPowerModeEnabled,
                timeToFullCharge: timeToFullCharge,
                powerSourceState: powerSource,
                healthPercentage: healthPercentage
            )
        } catch {
            batteryInfo = BatteryInfo(
                isAvailable: false,
                currentCapacity: 0,
                maxCapacity: 0,
                powerSourceState: "无电池"
            )
        }
    }

}

// MARK: - Battery View

import SwiftUI

/// 电池状态视图
public struct BatteryIndicatorView: View {
    @ObservedObject private var batteryService: BatteryService
    var batteryWidth: CGFloat = 26
    var showPercentage: Bool = true

    public init(batteryService: BatteryService = BatteryService(), batteryWidth: CGFloat = 26, showPercentage: Bool = true) {
        _batteryService = ObservedObject(wrappedValue: batteryService)
        self.batteryWidth = batteryWidth
        self.showPercentage = showPercentage
    }

    public var body: some View {
        HStack(spacing: 6) {
            if showPercentage {
                Text(batteryService.batteryInfo.isAvailable ? "\(Int(batteryService.batteryInfo.percentage.rounded()))%" : "♾️")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.white)
            }

            batteryIcon
        }
    }

    private var batteryIcon: some View {
        ZStack(alignment: .leading) {
            if batteryService.batteryInfo.isAvailable == false {
                Image(systemName: "infinity")
                    .resizable()
                    .fontWeight(.thin)
                    .aspectRatio(contentMode: .fit)
                    .foregroundStyle(Color.white.opacity(0.75))
                    .frame(width: batteryWidth + 1)
            } else {
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
                    width: CGFloat((CGFloat(batteryService.batteryInfo.percentage) / 100) * (batteryWidth - 6)),
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
    }

    private var batteryColor: Color {
        let info = batteryService.batteryInfo
        if info.isAvailable == false {
            return .white.opacity(0.7)
        }
        if info.isInLowPowerMode {
            return .yellow
        } else if info.percentage <= 20 && !info.isCharging && !info.isPluggedIn {
            return .red
        } else if info.isCharging || info.isPluggedIn || info.percentage >= 100 {
            return .green
        } else {
            return .white
        }
    }
}
