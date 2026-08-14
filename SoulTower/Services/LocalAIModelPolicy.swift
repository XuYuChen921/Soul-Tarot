import Foundation

enum LocalAIModelPolicy {
    static let policyVersion = 2
    static let fallbackModel = "qwen3:0.6b"

    static var deviceMemoryGiB: Int {
        memoryGiB(bytes: ProcessInfo.processInfo.physicalMemory)
    }

    static var recommendedModel: String {
        recommendedModel(memoryGiB: deviceMemoryGiB)
    }

    static var recommendationText: String {
        recommendationText(memoryGiB: deviceMemoryGiB)
    }

    static func recommendedModel(memoryGiB: Int) -> String {
        if memoryGiB < 20 {
            return "qwen3.5:4b"
        }
        return "qwen3.5:9b"
    }

    static func recommendationText(memoryGiB: Int) -> String {
        if memoryGiB < 20 {
            return "16GB 级别优先使用 4B：中文整理能力和内存余量更均衡，可与视频通话并用；0.6B 仅作省电备用，9B 需在非视频时段实测后再启用。"
        }
        return "当前内存适合优先使用 9B；应用仍会关闭深度思考并限制上下文，减少等待和内存占用。"
    }

    private static func memoryGiB(bytes: UInt64) -> Int {
        let unit = UInt64(1_073_741_824)
        return Int((bytes + unit / 2) / unit)
    }
}
