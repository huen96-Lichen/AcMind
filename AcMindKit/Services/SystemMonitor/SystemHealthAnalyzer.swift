import Foundation

public final class SystemHealthAnalyzer: Sendable {
    public init() {}

    public func analyze(snapshot: SystemMonitorSnapshot) -> SystemHealthSummary {
        var warnings: [String] = []
        var level: SystemHealthLevel = .good

        let cpuUsage = snapshot.cpu.usagePercent
        let memoryPressure = snapshot.memory.pressureLevel
        let storageUsed = snapshot.storage.usedPercent
        let battery = snapshot.battery
        let thermal = snapshot.thermal
        let gpu = snapshot.gpu
        let power = snapshot.power

        if cpuUsage >= 90 {
            warnings.append("CPU 负载偏高")
            level = .highLoad
        } else if cpuUsage >= 75 {
            warnings.append("CPU 负载正在升高")
            level = level.elevating(to: .attention)
        }

        switch memoryPressure {
        case .high:
            warnings.append("内存压力过高")
            level = .highLoad
        case .moderate:
            warnings.append("内存压力偏高")
            if level != .highLoad {
                level = .attention
            }
        case .low, .unknown:
            break
        }

        if storageUsed >= 95 {
            warnings.append("硬盘空间不足")
            level = .highLoad
        } else if storageUsed >= 85 {
            warnings.append("硬盘空间开始吃紧")
            if level != .highLoad {
                level = .attention
            }
        }

        if let battery {
            if !battery.isPluggedIn && battery.percentage <= 15 {
                warnings.append("电池电量较低")
                if level != .highLoad {
                    level = .attention
                }
            } else if !battery.isPluggedIn && battery.percentage <= 25 {
                warnings.append("电池正在放电，建议连接电源")
                if level != .highLoad {
                    level = .attention
                }
            }
        }

        if let thermal {
            switch thermal.pressureLevel {
            case .critical:
                warnings.append("温度与风扇负载过高")
                level = .highLoad
            case .serious:
                warnings.append("温度偏高，风扇正在加速")
                if level != .highLoad {
                    level = .attention
                }
            case .fair:
                warnings.append("温度轻微升高")
                if level != .highLoad, level != .attention {
                    level = .attention
                }
            case .nominal, .unknown:
                break
            }

            if let cpuTemperature = thermal.cpuTemperatureCelsius, cpuTemperature >= 92 {
                warnings.append("CPU 温度接近上限")
                level = .highLoad
            } else if let cpuTemperature = thermal.cpuTemperatureCelsius, cpuTemperature >= 82 {
                warnings.append("CPU 温度偏高")
                if level != .highLoad {
                    level = .attention
                }
            }

            if let gpuTemperature = thermal.gpuTemperatureCelsius, gpuTemperature >= 92 {
                warnings.append("GPU 温度接近上限")
                level = .highLoad
            } else if let gpuTemperature = thermal.gpuTemperatureCelsius, gpuTemperature >= 82 {
                warnings.append("GPU 温度偏高")
                if level != .highLoad {
                    level = .attention
                }
            }

            if let fanSpeed = thermal.fanSpeedRPM, fanSpeed >= 5_000 {
                warnings.append("风扇转速异常升高")
                level = .highLoad
            } else if let fanSpeed = thermal.fanSpeedRPM, fanSpeed >= 3_500 {
                warnings.append("风扇正在提高转速")
                if level != .highLoad {
                    level = .attention
                }
            }
        }

        if let gpu {
            if let usage = gpu.usagePercent, usage >= 95 {
                warnings.append("GPU 负载偏高")
                level = .highLoad
            } else if let usage = gpu.usagePercent, usage >= 85 {
                warnings.append("GPU 占用较高")
                if level != .highLoad {
                    level = .attention
                }
            }

            if let temperature = gpu.temperatureCelsius, temperature >= 92 {
                warnings.append("GPU 温度过高")
                level = .highLoad
            } else if let temperature = gpu.temperatureCelsius, temperature >= 82 {
                warnings.append("GPU 温度偏高")
                if level != .highLoad {
                    level = .attention
                }
            }
        }

        if let power {
            if let watts = power.consumptionWatts, watts >= 60 {
                warnings.append("功耗过高")
                level = .highLoad
            } else if let watts = power.consumptionWatts, watts >= 35 {
                warnings.append("功耗偏高")
                if level != .highLoad {
                    level = .attention
                }
            }
        }

        if warnings.isEmpty {
            return SystemHealthSummary(
                level: .good,
                title: "当前状态良好",
                message: "CPU、内存和存储负载都处于较轻状态。",
                warnings: []
            )
        }

        let title: String
        let message: String
        switch level {
        case .good, .unknown:
            title = "当前状态良好"
            message = "CPU、内存和存储负载都处于较轻状态。"
        case .attention:
            title = "当前状态需要留意"
            message = warnings.prefix(3).joined(separator: " · ")
        case .highLoad:
            title = "当前状态偏高负载"
            message = warnings.prefix(4).joined(separator: " · ")
        }

        return SystemHealthSummary(
            level: level,
            title: title,
            message: message,
            warnings: warnings
        )
    }
}

private extension SystemHealthLevel {
    func elevating(to other: SystemHealthLevel) -> SystemHealthLevel {
        let lhs = self
        let rhs = other
        if lhs == .highLoad || rhs == .highLoad { return .highLoad }
        if lhs == .attention || rhs == .attention { return .attention }
        if lhs == .good || rhs == .good { return .good }
        return .unknown
    }
}
