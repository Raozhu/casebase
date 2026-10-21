import AppKit
import Foundation

struct DemoImportDraft {
    let title: String
    let summary: String
    let snippets: [String]
    let tags: [String]
    let contentType: String
    let scene: String
    let purpose: String
    let folder: String
    let thoughts: [String]
}

/// The made-up material shown in the README demos. Nothing here comes from a real library.
@MainActor
enum DemoContent {
    static var reportFileName: String { L("Q3 Market Report.pdf", "Q3 市场报告.pdf") }
    static var screenshotFileName: String { L("Weekly active users.png", "周活跃用户.png") }

    static var reportResult: DemoImportDraft {
        DemoImportDraft(
            title: L("Q3 Market Report: APAC leads growth", "Q3 市场报告：亚太区领跑增长"),
            summary: L(
                "Quarterly market report. APAC revenue grew 38% quarter over quarter and churn fell to 2.1%. It recommends doubling the APAC sales team.",
                "季度市场报告。亚太区收入环比增长 38%，流失率降到 2.1%，建议把亚太销售团队扩大一倍。"
            ),
            snippets: [
                L("APAC revenue +38% QoQ", "亚太区收入环比 +38%"),
                L("Churn down to 2.1%", "流失率降至 2.1%"),
                L("Recommendation: double the APAC sales team", "建议：亚太销售团队扩大一倍"),
            ],
            tags: [L("Market report", "市场报告"), "Q3", L("APAC", "亚太")],
            contentType: L("Market report", "市场报告"),
            scene: L("Quarterly business review", "季度经营复盘"),
            purpose: L("Reports", "报告"),
            folder: L("Reports", "报告"),
            thoughts: [
                L("A 12-page quarterly market report.", "这是一份 12 页的季度市场报告。"),
                L("Key numbers: APAC revenue +38%, churn 2.1%.", "关键数字：亚太区收入 +38%，流失率 2.1%。"),
                L("Filing it under Reports.", "归到「报告」。"),
            ]
        )
    }

    static var screenshotResult: DemoImportDraft {
        DemoImportDraft(
            title: L("Weekly active users: 18.4k in week 6", "周活跃用户：第 6 周达到 1.84 万"),
            summary: L(
                "Bar chart of weekly active users over six weeks, climbing from 9.2k to 18.4k after the onboarding redesign.",
                "六周周活跃用户柱状图，新手引导改版后从 9200 增长到 18400。"
            ),
            snippets: [L("Week 6: 18.4k weekly active users", "第 6 周：周活跃 18400")],
            tags: [L("Metrics", "数据指标"), L("Growth", "增长")],
            contentType: L("Chart", "图表"),
            scene: L("Product metrics", "产品数据"),
            purpose: L("Metrics", "数据指标"),
            folder: L("Metrics", "数据指标"),
            thoughts: [
                L("A bar chart of weekly active users.", "这是一张周活跃用户柱状图。"),
                L("Up from 9.2k to 18.4k in six weeks.", "六周内从 9200 涨到 18400。"),
                L("Filing it under Metrics.", "归到「数据指标」。"),
            ]
        )
    }

    static var browser: StageProps.BrowserWindow {
        StageProps.BrowserWindow(
            frame: CGRect(x: 456, y: 150, width: 600, height: 340),
            title: "Analytics",
            url: "analytics.example.com/growth",
            chartTitle: L("Weekly active users", "周活跃用户"),
            chartSubtitle: L("After the onboarding redesign", "新手引导改版后"),
            bars: [("W1", 9200), ("W2", 10400), ("W3", 12100), ("W4", 13900), ("W5", 16200), ("W6", 18400)]
        )
    }

    static var question: String { L("What did we decide on launch pricing?", "发布定价最后是怎么定的？") }

    static var answerThought: String {
        L("Looking through the launch sync and the pricing notes…", "正在查看发布同步会和定价调研笔记…")
    }

    static var answerText: String {
        L(
            "Launch pricing is $12 a month or $99 a year, and the annual plan includes the export add-on. The team picked $12 because the pricing research showed $15 lost about a third of trials. Tom will update the pricing page by Thursday.",
            "发布定价定为月付 12 美元、年付 99 美元，年付包含导出功能。选 12 美元是因为定价调研显示，15 美元会流失约三分之一的试用用户。汤姆会在周四前更新定价页。"
        )
    }

    static var meetingTitle: String { L("Q4 launch sync", "Q4 发布同步会") }
    static var pricingNotesTitle: String { L("Pricing research notes", "定价调研笔记") }
    static var answerCitationTitles: [String] { [meetingTitle, pricingNotesTitle] }

    // MARK: Seed library

    static func seed(_ library: DemoLibrary) throws {
        let now = Date()
        let hour: TimeInterval = 3600

        let meetingText = L(
            "Mia: Let's lock launch pricing today.\nTom: The data says $12 is the sweet spot. At $15 we lose a third of trials.\nMia: Agreed. $12 a month, $99 a year, and annual gets the export add-on.\nTom: I'll update the pricing page by Thursday and send it to Lena.",
            "米娅：今天把发布定价定下来。\n汤姆：数据看 12 美元最合适，定 15 美元会流失三分之一的试用。\n米娅：同意。月付 12 美元、年付 99 美元，年付送导出功能。\n汤姆：我周四前改好定价页，发给李娜。"
        )
        var meeting = ImportRecord(
            assetPath: try writeText(meetingText, to: "assets/\(L("Meetings", "会议"))/\(meetingTitle).txt", in: library),
            assetHash: "demo-meeting",
            fileName: "\(meetingTitle).txt",
            mimeType: "text/plain",
            sourceKind: .text,
            contentType: L("Meeting transcript", "会议转写"),
            scene: L("Team meeting", "团队会议"),
            purpose: L("Meetings", "会议"),
            title: meetingTitle,
            shortSummary: L(
                "Launch pricing set at $12/month or $99/year, with the export add-on on annual plans.",
                "发布定价定为月付 12 美元、年付 99 美元，年付含导出功能。"
            ),
            usefulSnippets: [L("$12 a month, $99 a year", "月付 12 美元、年付 99 美元")],
            tags: [L("Meeting", "会议"), L("Pricing", "定价"), L("Launch", "发布")],
            structuredData: [
                MeetingRecordMetadata.sourceKey: .string(MeetingRecordMetadata.sourceValue),
                MeetingRecordMetadata.participantCountKey: .number(3),
                MeetingRecordMetadata.durationSecondsKey: .number(1860),
                MeetingRecordMetadata.topicKey: .string(L("Launch pricing", "发布定价")),
            ],
            searchText: meetingText,
            userSupplement: meetingText,
            parseStatus: .ready,
            createdAt: now.addingTimeInterval(-2 * hour)
        )
        try MeetingRecordMetadata.setActionItems([
            MeetingActionItemCandidate(
                title: L("Update the pricing page to $12 / $99 and send it to Lena", "把定价页改成 12 / 99 美元并发给李娜"),
                owner: L("Tom", "汤姆"),
                dueText: L("Thursday", "周四"),
                reason: L("The new pricing has to be live before launch.", "新定价要在发布前上线。"),
                evidence: L("I'll update the pricing page by Thursday and send it to Lena.", "我周四前改好定价页，发给李娜。"),
                suggestedQuadrant: .importantUrgent
            ),
            MeetingActionItemCandidate(
                title: L("Add the export add-on to the annual plan", "给年付套餐加上导出功能"),
                owner: L("Mia", "米娅"),
                dueText: L("Next week", "下周"),
                reason: L("Agreed as the annual-plan incentive.", "会上定为年付的附加权益。"),
                evidence: L("Annual gets the export add-on.", "年付送导出功能。")
            ),
        ], in: &meeting)
        library.replace(meeting)

        library.replace(ImportRecord(
            assetPath: try writeText("$9: 41% trial-to-paid\n$12: 38%\n$15: 25%", to: "assets/\(L("Research", "调研"))/\(pricingNotesTitle).md", in: library),
            assetHash: "demo-pricing",
            fileName: "\(pricingNotesTitle).md",
            mimeType: "text/markdown",
            sourceKind: .text,
            contentType: L("Research notes", "调研笔记"),
            scene: L("Pricing research", "定价调研"),
            purpose: L("Research", "调研"),
            title: pricingNotesTitle,
            shortSummary: L("Trial-to-paid conversion drops from 38% at $12 to 25% at $15.", "试用转付费率：12 美元为 38%，15 美元降到 25%。"),
            usefulSnippets: [L("$15 converts 25% vs 38% at $12", "15 美元转化 25%，12 美元为 38%")],
            tags: [L("Pricing", "定价"), L("Research", "调研")],
            searchText: "pricing",
            parseStatus: .ready,
            createdAt: now.addingTimeInterval(-26 * hour)
        ))

        library.replace(ImportRecord(
            assetPath: try writeText("Interview notes", to: "assets/\(L("Research", "调研"))/interview-ana.txt", in: library),
            assetHash: "demo-interview",
            fileName: "interview-ana.txt",
            mimeType: "text/plain",
            sourceKind: .text,
            contentType: L("User interview", "用户访谈"),
            scene: L("User research", "用户研究"),
            purpose: L("Research", "调研"),
            title: L("Interview: Ana, product designer", "访谈：安娜，产品设计师"),
            shortSummary: L("Wants faster export and shared folders.", "希望导出更快、支持共享文件夹。"),
            usefulSnippets: [],
            tags: [L("Interview", "访谈")],
            searchText: "interview",
            parseStatus: .ready,
            createdAt: now.addingTimeInterval(-50 * hour)
        ))

        let contractURL = library.root.appendingPathComponent("assets/\(L("Contracts", "合同"))/supplier-contract.pdf")
        try makePDF(at: contractURL, title: L("Supplier Agreement 2026", "2026 供应商协议"), lines: [L("Term: 24 months", "期限：24 个月"), L("Payment: net 30", "付款：月结 30 天")])
        library.replace(ImportRecord(
            assetPath: "assets/\(L("Contracts", "合同"))/supplier-contract.pdf",
            assetHash: "demo-contract",
            fileName: "supplier-contract.pdf",
            mimeType: "application/pdf",
            sourceKind: .pdf,
            contentType: L("Contract", "合同"),
            scene: L("Procurement", "采购"),
            purpose: L("Contracts", "合同"),
            title: L("Supplier agreement 2026", "2026 供应商协议"),
            shortSummary: L("24-month term, net-30 payment.", "期限 24 个月，月结 30 天。"),
            usefulSnippets: [],
            tags: [L("Contract", "合同")],
            searchText: "contract",
            parseStatus: .ready,
            createdAt: now.addingTimeInterval(-74 * hour)
        ))
    }

    private static func writeText(_ text: String, to relative: String, in library: DemoLibrary) throws -> String {
        let url = library.root.appendingPathComponent(relative)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try text.write(to: url, atomically: true, encoding: .utf8)
        return relative
    }

    /// A small but real PDF, so the app's own PDF preview has something to render.
    static func makePDF(at url: URL, title: String, lines: [String], bars: [Double] = []) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        var box = CGRect(x: 0, y: 0, width: 612, height: 792)
        guard let context = CGContext(url as CFURL, mediaBox: &box, nil) else { return }
        context.beginPDFPage(nil)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
        NSColor(red: 0.31, green: 0.45, blue: 0.98, alpha: 1).setFill()
        CGRect(x: 0, y: 742, width: 612, height: 50).fill()
        (title as NSString).draw(at: CGPoint(x: 48, y: 680), withAttributes: [.font: NSFont.boldSystemFont(ofSize: 30), .foregroundColor: NSColor.black])
        for (index, line) in lines.enumerated() {
            (line as NSString).draw(at: CGPoint(x: 48, y: 630 - CGFloat(index) * 28), withAttributes: [.font: NSFont.systemFont(ofSize: 16), .foregroundColor: NSColor.darkGray])
        }
        for (index, value) in bars.enumerated() {
            NSColor(red: 0.31, green: 0.45, blue: 0.98, alpha: index == bars.count - 1 ? 1 : 0.4).setFill()
            NSBezierPath(roundedRect: CGRect(x: 60 + CGFloat(index) * 90, y: 200, width: 56, height: CGFloat(value) * 240), xRadius: 6, yRadius: 6).fill()
        }
        NSGraphicsContext.restoreGraphicsState()
        context.endPDFPage()
        context.closePDF()
    }

    static func makeReport(at url: URL) throws {
        try makePDF(
            at: url,
            title: L("Q3 Market Report", "Q3 市场报告"),
            lines: [L("APAC revenue +38% QoQ", "亚太区收入环比 +38%"), L("Churn 2.1%", "流失率 2.1%"), L("Double the APAC sales team", "亚太销售团队扩大一倍")],
            bars: [0.35, 0.48, 0.55, 0.82]
        )
    }
}
