import Foundation
import SwiftUI

enum InboxItemType: String, CaseIterable {
    case voice = "语音"
    case task = "任务"
    case markdown = "Markdown"
    case document = "文档"
    case image = "图片"
}

enum InboxItemStatus: String, CaseIterable {
    case pending = "待处理"
    case completed = "已完成"
    case archived = "已归档"
    case collected = "已采集"
}

struct InboxItem: Identifiable {
    let id = UUID()
    let title: String
    let type: InboxItemType
    let source: String
    let summary: String
    let time: String
    let status: InboxItemStatus
    let duration: String?
    let waveformData: [CGFloat]?
    let recognitionText: String?
    let metadata: [String: String]
    let tags: [(String, Color)]
}

let inboxMockItems: [InboxItem] = [
    InboxItem(
        title: "语音记录 05-09 10:23",
        type: .voice,
        source: "10:23",
        summary: "音频波形 00:06",
        time: "10:23",
        status: .pending,
        duration: "00:06",
        waveformData: [6, 12, 8, 16, 10, 7, 14, 18, 9, 12, 20, 15, 8, 10, 13, 18, 11, 7, 12, 16],
        recognitionText: "帮我分析本季度产品增长数据，生成可视化图表和关键结论，最后输出一份汇报文档。重点关注用户增长趋势、活跃用户分布和各渠道转化效果。数据来源：产品后台与市场部提供的统计数据。",
        metadata: [
            "来源": "语音输入",
            "创建时间": "2025-05-09 10:23",
            "时长": "00:06",
            "识别状态": "已完成",
            "存储位置": "本地"
        ],
        tags: [
            ("产品分析", Color(hex: "#FF9500")),
            ("数据可视化", Color(hex: "#6366F1")),
            ("汇报文档", Color(hex: "#14B8A6"))
        ]
    ),
    InboxItem(
        title: "整理会议纪要并生成待办事项",
        type: .task,
        source: "Agent 生成",
        summary: "整理昨天的市场会议纪要，提炼关键点并生成待办清单",
        time: "09:47",
        status: .completed,
        duration: nil,
        waveformData: nil,
        recognitionText: nil,
        metadata: [
            "来源": "Agent 生成",
            "创建时间": "2025-05-09 09:47",
            "状态": "已完成",
            "优先级": "中"
        ],
        tags: [("会议纪要", Color(hex: "#0A84FF"))]
    ),
    InboxItem(
        title: "产品需求 PRD 初稿.md",
        type: .markdown,
        source: "Agent 生成",
        summary: "产品需求文档初稿，包含功能列表、用户流程和页面结构",
        time: "09:12",
        status: .archived,
        duration: nil,
        waveformData: nil,
        recognitionText: nil,
        metadata: [
            "来源": "Agent 生成",
            "创建时间": "2025-05-09 09:12",
            "格式": "Markdown",
            "存储位置": "本地"
        ],
        tags: [("产品文档", Color(hex: "#A855F7")), ("需求分析", Color(hex: "#14B8A6"))]
    ),
    InboxItem(
        title: "语音记录 05-08 18:16",
        type: .voice,
        source: "05-08",
        summary: "音频波形 00:13",
        time: "05-08",
        status: .completed,
        duration: "00:13",
        waveformData: [10, 15, 8, 12, 18, 14, 9, 16, 11, 20, 13, 7, 15, 10, 17, 12, 8, 14, 16, 11],
        recognitionText: "明天下午三点开会讨论新版本发布计划，请提前准备相关资料。",
        metadata: [
            "来源": "语音输入",
            "创建时间": "2025-05-08 18:16",
            "时长": "00:13",
            "识别状态": "已完成",
            "存储位置": "本地"
        ],
        tags: [("会议", Color(hex: "#FF9500"))]
    ),
    InboxItem(
        title: "增加一个今晚 10 点的进程提醒我吃药",
        type: .task,
        source: "",
        summary: "每天 22:00 提醒我吃药，并记录完成情况",
        time: "05-08",
        status: .completed,
        duration: nil,
        waveformData: nil,
        recognitionText: nil,
        metadata: [
            "来源": "语音输入",
            "创建时间": "2025-05-08 17:30",
            "状态": "已完成",
            "重复": "每天"
        ],
        tags: [("健康", Color(hex: "#34C759"))]
    ),
    InboxItem(
        title: "你好测试 0508",
        type: .document,
        source: "",
        summary: "你好测试 0508",
        time: "05-08",
        status: .completed,
        duration: nil,
        waveformData: nil,
        recognitionText: nil,
        metadata: [
            "来源": "手动输入",
            "创建时间": "2025-05-08 16:00",
            "格式": "文本",
            "存储位置": "本地"
        ],
        tags: []
    ),
    InboxItem(
        title: "对竞品产品进行功能对比分析",
        type: .task,
        source: "Agent 生成",
        summary: "选择 3 个主要竞品，输出功能对比表格和分析结论",
        time: "05-07",
        status: .pending,
        duration: nil,
        waveformData: nil,
        recognitionText: nil,
        metadata: [
            "来源": "Agent 生成",
            "创建时间": "2025-05-07 15:30",
            "状态": "待处理",
            "优先级": "高"
        ],
        tags: [("竞品分析", Color(hex: "#6366F1"))]
    ),
    InboxItem(
        title: "本周工作计划.md",
        type: .markdown,
        source: "",
        summary: "本周重点工作安排与目标拆解",
        time: "05-07",
        status: .archived,
        duration: nil,
        waveformData: nil,
        recognitionText: nil,
        metadata: [
            "来源": "手动创建",
            "创建时间": "2025-05-07 09:00",
            "格式": "Markdown",
            "存储位置": "本地"
        ],
        tags: [("工作计划", Color(hex: "#0A84FF"))]
    )
]

let categoryTabs: [(String, Int)] = [
    ("全部", 32),
    ("待处理", 10),
    ("语音", 8),
    ("任务", 7),
    ("文档", 5),
    ("Markdown", 2),
    ("图片", 0)
]
