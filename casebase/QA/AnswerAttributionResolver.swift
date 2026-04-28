import Foundation

struct AnswerAttributionResolver {
    struct CitationSupport: Hashable {
        let index: Int
        let supportNote: String
    }

    func resolveCitations(
        from sources: [AnswerEvidencePacket],
        citedSources: [CitationSupport]
    ) -> ([UUID], [AnswerCitation]) {
        var resolvedIDs: [UUID] = []
        var citations: [AnswerCitation] = []
        var seen = Set<UUID>()

        for support in citedSources {
            let sourceIndex = support.index - 1
            guard sources.indices.contains(sourceIndex) else {
                continue
            }

            let source = sources[sourceIndex]
            let record = source.record
            guard seen.insert(record.id).inserted else {
                continue
            }

            resolvedIDs.append(record.id)
            citations.append(
                AnswerCitation(
                    id: record.id,
                    sourceKind: record.sourceKind,
                    title: record.title,
                    shortSummary: record.shortSummary,
                    sourceTags: record.tags,
                    evidenceExcerpt: source.evidenceExcerpt,
                    previewAssetPath: source.previewAssetPath,
                    openTarget: source.openTarget,
                    supportNote: support.supportNote.trimmingCharacters(in: .whitespacesAndNewlines)
                )
            )
        }

        return (resolvedIDs, citations)
    }

    func fallbackCitations(from sources: [AnswerEvidencePacket]) -> ([UUID], [AnswerCitation]) {
        resolveCitations(
            from: sources,
            citedSources: sources.enumerated().map { offset, _ in
                CitationSupport(index: offset + 1, supportNote: "")
            }
        )
    }
}
