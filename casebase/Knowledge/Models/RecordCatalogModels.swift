import Foundation

struct RecordCatalogFilters: Hashable {
    let purpose: String?
    let tagsAny: [String]
    let sourceKinds: [ImportSourceKind]
    let needsReview: Bool?

    init(
        purpose: String? = nil,
        tagsAny: [String] = [],
        sourceKinds: [ImportSourceKind] = [],
        needsReview: Bool? = nil
    ) {
        let normalizedPurpose = purpose?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.purpose = normalizedPurpose?.isEmpty == false ? normalizedPurpose : nil

        var normalizedTags: [String] = []
        for tag in tagsAny {
            let trimmed = tag.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, !normalizedTags.contains(trimmed) else { continue }
            normalizedTags.append(trimmed)
        }
        self.tagsAny = normalizedTags

        var normalizedSourceKinds: [ImportSourceKind] = []
        for sourceKind in sourceKinds where !normalizedSourceKinds.contains(sourceKind) {
            normalizedSourceKinds.append(sourceKind)
        }
        self.sourceKinds = normalizedSourceKinds
        self.needsReview = needsReview
    }
}

struct RecordCatalogPage: Hashable {
    let items: [ImportRecord]
    let limit: Int
    let offset: Int
    let hasMore: Bool
}

enum RecordCatalogPaging {
    static let defaultLimit = 20
    static let maximumLimit = 100

    static func normalizedLimit(_ value: Int) -> Int {
        min(max(value, 1), maximumLimit)
    }

    static func normalizedOffset(_ value: Int) -> Int {
        max(value, 0)
    }
}
