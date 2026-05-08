import Foundation

// MARK: - AI Error

/// AI 服务错误类型
public enum AIError: Error, LocalizedError {
    case invalidResponse
    case noKey
    case noProvider
    case providerNotFound(String)
    case requestFailed(String)
    case rateLimited
    case timeout
    case modelNotFound(String)
    case contextTooLong
    case contentFiltered(String)
    case invalidInput(String)
    case notImplemented(String)
    
    public var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "无效的 AI 响应"
        case .noKey:
            return "未配置 API Key"
        case .noProvider:
            return "未配置 AI Provider"
        case .providerNotFound(let id):
            return "Provider 未找到: \(id)"
        case .requestFailed(let message):
            return "请求失败: \(message)"
        case .rateLimited:
            return "请求频率超限，请稍后重试"
        case .timeout:
            return "请求超时"
        case .modelNotFound(let model):
            return "模型未找到: \(model)"
        case .contextTooLong:
            return "上下文长度超限"
        case .contentFiltered(let reason):
            return "内容被过滤: \(reason)"
        case .invalidInput(let message):
            return "输入无效: \(message)"
        case .notImplemented(let message):
            return "功能未实现: \(message)"
        }
    }
    
    public var recoverySuggestion: String? {
        switch self {
        case .invalidResponse:
            return "请检查 Provider 配置或重试"
        case .noKey:
            return "请在设置中配置 API Key"
        case .noProvider:
            return "请在设置中添加 AI Provider"
        case .providerNotFound:
            return "请检查 Provider ID 是否正确"
        case .requestFailed:
            return "请检查网络连接或 Provider 状态"
        case .rateLimited:
            return "请等待一段时间后重试"
        case .timeout:
            return "请检查网络连接或增加超时时间"
        case .modelNotFound:
            return "请检查模型名称是否正确"
        case .contextTooLong:
            return "请减少输入内容长度"
        case .contentFiltered:
            return "请修改输入内容"
        case .invalidInput:
            return "请检查输入参数"
        case .notImplemented:
            return "该功能正在开发中"
        }
    }
}
