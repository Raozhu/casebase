import Foundation

struct AnswerAttributionResolver {
    func resolveCitations(from hits: [SearchHit], citedIndexes: [Int]) -> ([UUID], [AnswerCitation]) {
        var resolvedIDs: [UUID] = []
        var citations: [AnswerCitation] = []
        var seen = Set<UUID>()

        for index in citedIndexes {
            let hitIndex = index - 1
            guard hits.indices.contains(hitIndex) else {
                continue
            }

            let hit = hits[hitIndex]
            let record = hit.record
            guard seen.insert(record.id).inserted else {
                continue
            }

            let relevantSnippet = hit.matchedSnippets.first ?? record.usefulSnippets.first
            resolvedIDs.append(record.id)
            citations.append(
                AnswerCitation(
                    id: record.id,
                    title: record.title,
                    shortSummary: record.shortSummary,
                    relevantSnippet: relevantSnippet
                )
            )
        }

        return (resolvedIDs, citations)
    }
}
