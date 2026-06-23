import Foundation
import IOKit

internal enum SystemSMCDataType: String {
    case UI8 = "ui8 "
    case UI16 = "ui16"
    case UI32 = "ui32"
    case SP1E = "sp1e"
    case SP3C = "sp3c"
    case SP4B = "sp4b"
    case SP5A = "sp5a"
    case SPA5 = "spa5"
    case SP69 = "sp69"
    case SP78 = "sp78"
    case SP87 = "sp87"
    case SP96 = "sp96"
    case SPB4 = "spb4"
    case SPF0 = "spf0"
    case FLT = "flt "
    case FPE2 = "fpe2"
    case FP2E = "fp2e"
    case FDS = "{fds"
}

internal enum SystemSMCKeys: UInt8 {
    case kernelIndex = 2
    case readBytes = 5
    case writeBytes = 6
    case readIndex = 8
    case readKeyInfo = 9
}

public enum SystemSMCFanMode: Int, Codable {
    case automatic = 0
    case forced = 1
    case auto3 = 3

    public var isAutomatic: Bool {
        self == .automatic || self == .auto3
    }
}

internal struct SystemSMCKeyData {
    typealias SMCBytes = (
        UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
        UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
        UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
        UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8
    )

    struct Vers {
        var major: CUnsignedChar = 0
        var minor: CUnsignedChar = 0
        var build: CUnsignedChar = 0
        var reserved: CUnsignedChar = 0
        var release: CUnsignedShort = 0
    }

    struct PLimitData {
        var version: UInt16 = 0
        var length: UInt16 = 0
        var cpuPLimit: UInt32 = 0
        var gpuPLimit: UInt32 = 0
        var memPLimit: UInt32 = 0
    }

    struct KeyInfo {
        var dataSize: IOByteCount32 = 0
        var dataType: UInt32 = 0
        var dataAttributes: UInt8 = 0
    }

    var key: UInt32 = 0
    var vers = Vers()
    var pLimitData = PLimitData()
    var keyInfo = KeyInfo()
    var padding: UInt16 = 0
    var result: UInt8 = 0
    var status: UInt8 = 0
    var data8: UInt8 = 0
    var data32: UInt32 = 0
    var bytes: SMCBytes = (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
}

internal struct SystemSMCValue {
    var key: String
    var dataSize: UInt32 = 0
    var dataType: String = ""
    var bytes: [UInt8] = Array(repeating: 0, count: 32)

    init(_ key: String) {
        self.key = key
    }
}

public final class SystemSMCBridge: SystemHardwareBridge {
    public private(set) var isAvailable: Bool = false

    private var conn: io_connect_t = 0
    private var fanModeKeyIsLower: Bool?

    public init?() {
        var result: kern_return_t
        var iterator: io_iterator_t = 0
        let matchingDictionary: CFMutableDictionary = IOServiceMatching("AppleSMC")

        result = IOServiceGetMatchingServices(kIOMainPortDefault, matchingDictionary, &iterator)
        guard result == kIOReturnSuccess else { return nil }

        let device = IOIteratorNext(iterator)
        IOObjectRelease(iterator)
        guard device != 0 else { return nil }

        result = IOServiceOpen(device, mach_task_self_, 0, &conn)
        IOObjectRelease(device)
        guard result == kIOReturnSuccess else { return nil }

        isAvailable = true
    }

    deinit {
        if conn != 0 {
            _ = IOServiceClose(conn)
        }
    }

    public func refreshFanControlStates() -> [SystemFanControlState] {
        guard let fanCount = getValue("FNum"), fanCount > 0 else { return [] }

        let count = max(0, Int(floor(fanCount)))
        var states: [SystemFanControlState] = []
        states.reserveCapacity(count)

        for index in 0..<count {
            let fanName = getStringValue("F\(index)ID")
                ?? getStringValue("F\(index)Nm")
                ?? "Fan #\(index + 1)"
            let rpm = getValue("F\(index)Ac") ?? getValue("F\(index)Sp")
            let minRPM = getValue("F\(index)Mn")
            let maxRPM = getValue("F\(index)Mx")
            let modeValue = getValue(fanModeKey(index)) ?? getValue("F\(index)Md") ?? getValue("F\(index)md")
            let targetRPM = getValue("F\(index)Tg")

            states.append(
                SystemFanControlState(
                    id: index,
                    fanIndex: index,
                    name: fanName,
                    rpm: rpm,
                    minRPM: minRPM,
                    maxRPM: maxRPM,
                    isAutomatic: modeValue.map { $0 == 0 || $0 == 3 } ?? true,
                    controlPercent: Self.rpmToPercentage(targetRPM ?? rpm, minRPM: minRPM, maxRPM: maxRPM),
                    source: "AppleSMC",
                    isAvailable: rpm != nil || minRPM != nil || maxRPM != nil,
                    unavailableReason: rpm == nil ? "风扇数据不可用" : nil
                )
            )
        }

        return states
    }

    public func setFanPercentage(fanIndex: Int, percentage: Double) -> Bool {
        let clamped = min(max(percentage, 0), 100)
        guard let minRPM = getValue("F\(fanIndex)Mn") else { return false }
        let maxRPM = getValue("F\(fanIndex)Mx") ?? minRPM
        let targetRPM = Self.percentageToFanRPM(clamped, minRPM: minRPM, maxRPM: maxRPM)

        if setFanAutomatic(fanIndex: fanIndex) == false {
            return false
        }

        guard setFanMode(fanIndex, mode: .forced) else { return false }
        return setFanSpeed(fanIndex, speed: Int(targetRPM.rounded()))
    }

    public func setFanAutomatic(fanIndex: Int) -> Bool {
        if getValue("FNum") == nil {
            return false
        }

        return setFanMode(fanIndex, mode: .automatic)
    }

    public func resetFanControl() -> Bool {
        guard getValue("FNum") != nil else { return false }

        var ftstVal = SystemSMCValue("Ftst")
        let result = read(&ftstVal)
        if result == kIOReturnSuccess, ftstVal.dataSize > 0 {
            if ftstVal.bytes[0] == 0 { return true }
            ftstVal.bytes[0] = 0
            return writeWithRetry(ftstVal)
        }

        var success = true
        let count = Int(getValue("FNum") ?? 0)
        for index in 0..<count {
            var modeVal = SystemSMCValue(fanModeKey(index))
            guard read(&modeVal) == kIOReturnSuccess else { continue }
            if modeVal.bytes[0] == 0 { continue }
            modeVal.bytes[0] = 0
            if writeWithRetry(modeVal) == false {
                success = false
            }
        }
        return success
    }

    public static func percentageToFanRPM(_ percentage: Double, minRPM: Double, maxRPM: Double) -> Double {
        let clamped = min(max(percentage, 0), 100)
        guard maxRPM > minRPM else { return minRPM }
        return minRPM + ((maxRPM - minRPM) * clamped / 100.0)
    }

    public static func rpmToPercentage(_ rpm: Double?, minRPM: Double?, maxRPM: Double?) -> Double? {
        guard let rpm, let minRPM, let maxRPM, maxRPM > minRPM else { return nil }
        let percentage = ((rpm - minRPM) / (maxRPM - minRPM)) * 100.0
        return min(max(percentage, 0), 100)
    }

    private func fanModeKey(_ id: Int) -> String {
        if fanModeKeyIsLower == nil {
            var probe = SystemSMCValue("F0md")
            fanModeKeyIsLower = read(&probe) == kIOReturnSuccess && probe.dataSize > 0
        }
        return fanModeKeyIsLower! ? "F\(id)md" : "F\(id)Md"
    }

    private func setFanMode(_ id: Int, mode: SystemSMCFanMode) -> Bool {
        if mode == .forced {
            if unlockFanControl(fanId: id) == false { return false }
        }

        var modeVal = SystemSMCValue(fanModeKey(id))
        guard read(&modeVal) == kIOReturnSuccess else { return false }
        modeVal.bytes[0] = UInt8(mode.rawValue)
        return writeWithRetry(modeVal)
    }

    private func setFanSpeed(_ id: Int, speed: Int) -> Bool {
        if let maxSpeed = getValue("F\(id)Mx"), speed > Int(maxSpeed) {
            return setFanSpeed(id, speed: Int(maxSpeed))
        }

        var value = SystemSMCValue("F\(id)Tg")
        guard read(&value) == kIOReturnSuccess else { return false }

        if value.dataType == SystemSMCDataType.FLT.rawValue {
            let bytes = Float(speed).bytes
            value.bytes[0] = bytes[0]
            value.bytes[1] = bytes[1]
            value.bytes[2] = bytes[2]
            value.bytes[3] = bytes[3]
        } else if value.dataType == SystemSMCDataType.FPE2.rawValue {
            value.bytes[0] = UInt8(speed >> 6)
            value.bytes[1] = UInt8((speed << 2) ^ ((speed >> 6) << 8))
        }

        return writeWithRetry(value)
    }

    private func unlockFanControl(fanId: Int) -> Bool {
        let modeKey = fanModeKey(fanId)
        var modeVal = SystemSMCValue(modeKey)
        guard read(&modeVal) == kIOReturnSuccess else { return false }
        modeVal.bytes[0] = 1
        if write(modeVal) == kIOReturnSuccess {
            return true
        }

        var ftstVal = SystemSMCValue("Ftst")
        let ftstResult = read(&ftstVal)
        guard ftstResult == kIOReturnSuccess, ftstVal.dataSize > 0 else { return false }

        if ftstVal.bytes[0] == 1 {
            return retryModeWrite(fanId: fanId, maxAttempts: 20)
        }

        ftstVal.bytes[0] = 1
        if writeWithRetry(ftstVal, maxAttempts: 100, delayMicros: 50_000) == false {
            return false
        }

        usleep(3_000_000)
        return retryModeWrite(fanId: fanId, maxAttempts: 300)
    }

    private func retryModeWrite(fanId: Int, maxAttempts: Int) -> Bool {
        let modeKey = fanModeKey(fanId)
        var modeVal = SystemSMCValue(modeKey)
        guard read(&modeVal) == kIOReturnSuccess else { return false }
        modeVal.bytes[0] = 1
        return writeWithRetry(modeVal, maxAttempts: maxAttempts, delayMicros: 100_000)
    }

    private func writeWithRetry(_ value: SystemSMCValue, maxAttempts: Int = 10, delayMicros: UInt32 = 50_000) -> Bool {
        var lastResult: kern_return_t = kIOReturnSuccess
        for attempt in 0..<maxAttempts {
            lastResult = write(value)
            if lastResult == kIOReturnSuccess {
                return true
            }
            if attempt < maxAttempts - 1 {
                usleep(delayMicros)
            }
        }

        return false
    }

    private func getValue(_ key: String) -> Double? {
        var value = SystemSMCValue(key)
        guard read(&value) == kIOReturnSuccess, value.dataSize > 0 else { return nil }

        if value.bytes.first(where: { $0 != 0 }) == nil
            && value.key != "FS! "
            && value.key != "F0Md"
            && value.key != "F1Md"
            && value.key != "F0md"
            && value.key != "F1md" {
            return nil
        }

        switch value.dataType {
        case SystemSMCDataType.UI8.rawValue:
            return Double(value.bytes[0])
        case SystemSMCDataType.UI16.rawValue:
            return Double(UInt16(bytes: (value.bytes[0], value.bytes[1])))
        case SystemSMCDataType.UI32.rawValue:
            return Double(UInt32(bytes: (value.bytes[0], value.bytes[1], value.bytes[2], value.bytes[3])))
        case SystemSMCDataType.SP78.rawValue:
            return Double(Double(Int(value.bytes[0]) * 256 + Int(value.bytes[1])) / 256)
        case SystemSMCDataType.FLT.rawValue:
            return Float(value.bytes).map(Double.init)
        case SystemSMCDataType.FPE2.rawValue:
            return Double(Int(fromFPE2: (value.bytes[0], value.bytes[1])))
        default:
            return nil
        }
    }

    private func getStringValue(_ key: String) -> String? {
        var value = SystemSMCValue(key)
        guard read(&value) == kIOReturnSuccess, value.dataSize > 0 else { return nil }

        guard value.bytes.first(where: { $0 != 0 }) != nil else { return nil }

        if value.dataType == SystemSMCDataType.FDS.rawValue {
            let chars = value.bytes[4...15].compactMap { byte -> String? in
                guard byte != 0 else { return nil }
                return String(UnicodeScalar(byte))
            }
            let result = chars.joined()
            return result.trimmingCharacters(in: .whitespaces)
        }

        return nil
    }

    private func read(_ value: inout SystemSMCValue) -> kern_return_t {
        var input = SystemSMCKeyData()
        var output = SystemSMCKeyData()

        input.key = FourCharCode(fromString: value.key)
        input.data8 = SystemSMCKeys.readKeyInfo.rawValue

        var result = call(SystemSMCKeys.kernelIndex.rawValue, input: &input, output: &output)
        guard result == kIOReturnSuccess else { return result }

        value.dataSize = UInt32(output.keyInfo.dataSize)
        value.dataType = output.keyInfo.dataType.toString()
        input.keyInfo.dataSize = output.keyInfo.dataSize
        input.data8 = SystemSMCKeys.readBytes.rawValue

        result = call(SystemSMCKeys.kernelIndex.rawValue, input: &input, output: &output)
        guard result == kIOReturnSuccess else { return result }

        memcpy(&value.bytes, &output.bytes, Int(value.dataSize))
        return kIOReturnSuccess
    }

    private func write(_ value: SystemSMCValue) -> kern_return_t {
        var input = SystemSMCKeyData()
        var output = SystemSMCKeyData()

        input.key = FourCharCode(fromString: value.key)
        input.data8 = SystemSMCKeys.writeBytes.rawValue
        input.keyInfo.dataSize = IOByteCount32(value.dataSize)
        input.bytes = (
            value.bytes[0], value.bytes[1], value.bytes[2], value.bytes[3],
            value.bytes[4], value.bytes[5], value.bytes[6], value.bytes[7],
            value.bytes[8], value.bytes[9], value.bytes[10], value.bytes[11],
            value.bytes[12], value.bytes[13], value.bytes[14], value.bytes[15],
            value.bytes[16], value.bytes[17], value.bytes[18], value.bytes[19],
            value.bytes[20], value.bytes[21], value.bytes[22], value.bytes[23],
            value.bytes[24], value.bytes[25], value.bytes[26], value.bytes[27],
            value.bytes[28], value.bytes[29], value.bytes[30], value.bytes[31]
        )

        let result = call(SystemSMCKeys.kernelIndex.rawValue, input: &input, output: &output)
        guard result == kIOReturnSuccess else { return result }

        return output.result == 0x00 ? kIOReturnSuccess : kIOReturnError
    }

    private func call(_ index: UInt8, input: inout SystemSMCKeyData, output: inout SystemSMCKeyData) -> kern_return_t {
        let inputSize = MemoryLayout<SystemSMCKeyData>.stride
        var outputSize = MemoryLayout<SystemSMCKeyData>.stride
        return IOConnectCallStructMethod(conn, UInt32(index), &input, inputSize, &output, &outputSize)
    }
}
