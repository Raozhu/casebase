import Foundation

struct AnswerEvidenceBuilder {
    private let extractor: Extractor
    private let assetVault: AssetVault
    private let maxModelTextCharacters = 6_000
    private let maxExcerptCharacters = 360

    init(extractor: Extractor, assetVault: AssetVault) {
        self.extractor = extractor
        self.assetVault = assetVault
    }

    func buildEvidencePackets(question: String, hits: [SearchHit]) async -> [AnswerEvidencePacket] {
        var packets: [AnswerEvidencePacket] = []
        let queryCandidates = excerptCandidates(from: question)

        for hit in hits {
            guard let packet = await buildEvidencePacket(questionCandidates: queryCandidates, hit: hit) else {
                continue
            }
            packets.append(packet)
        }

        return packets
    }

    private func buildEvidencePacket(
        questionCandidates: [String],
        hit: SearchHit
    ) async -> AnswerEvidencePacket? {
        let record = hit.record
        let assetURL = await assetVault.url(for: record.assetPath)
        let payload = ImportPayload.file(
            FileImportPayload(
                fileURL: assetURL,
                suggestedFileName: record.fileName,
                mimeType: record.mimeType,
                sourceKindHint: record.sourceKind
            )
        )

        guard let normalized = try? await extractor.normalize(payload) else {
            return nil
        }

        let normalizedText = normalized.rawText?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let matchCandidates = questionCandidates + hit.matchedSnippets + record.usefulSnippets
        let previewAssetPath = resolvePreviewAssetPath(
            for: record,
            attachments: normalized.attachments,
            assetURL: assetURL
        )
        let evidenceExcerpt = resolveEvidenceExcerpt(
            rawText: normalizedText,
            matchCandidates: matchCandidates,
            fallbackSnippets: hit.matchedSnippets + record.usefulSnippets,
            shortSummary: record.shortSummary
        )

        return AnswerEvidencePacket(
            id: record.id,
            record: record,
            rawText: normalizedText,
            modelTextContext: resolveModelTextContext(
                rawText: normalizedText,
                matchCandidates: matchCandidates
            ),
            evidenceExcerpt: evidenceExcerpt,
            attachments: normalized.attachments,
            previewAssetPath: previewAssetPath,
            openTarget: assetURL.path,
            matchedSnippets: hit.matchedSnippets
        )
    }

    private func resolvePreviewAssetPath(
        for record: ImportRecord,
        attachments: [NormalizedAttachment],
        assetURL: URL
    ) -> String? {
        if let preview = attachments.first(where: { $0.kind == .imagePreview || $0.kind == .pagePreview }) {
            return preview.path
        }

        if record.sourceKind == .image || record.sourceKind == .pdf {
            return assetURL.path
        }

        return nil
    }

    private func resolveEvidenceExcerpt(
        rawText: String?,
        matchCandidates: [String],
        fallbackSnippets: [String],
        shortSummary: String
    ) -> String? {
        if let rawText, !rawText.isEmpty {
            return excerpt(from: rawText, around: matchCandidates, maximumCharacters: maxExcerptCharacters)
        }

        if let fallback = fallbackSnippets.first(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
            return fallback
        }

        let trimmedSummary = shortSummary.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedSummary.isEmpty ? nil : trimmedSummary
    }

    private func resolveModelTextContext(
        rawText: String?,
        matchCandidates: [String]
    ) -> String? {
        guard let rawText, !rawText.isEmpty else {
            return nil
        }
        return excerpt(from: rawText, around: matchCandidates, maximumCharacters: maxModelTextCharacters)
    }

    private func excerpt(
        from rawText: String,
        around candidates: [String],
        maximumCharacters: Int
    ) -> String {
        let normalized = normalizeWhitespace(in: rawText)
        guard normalized.count > maximumCharacters else {
            return normalized
        }

        for candidate in candidates {
            let trimmedCandidate = normalizeWhitespace(in: candidate)
            guard trimmedCandidate.count >= 2 else { continue }

            if let range = normalized.range(
                of: trimmedCandidate,
                options: [.caseInsensitive, .diacriticInsensitive]
            ) {
                return window(
                    in: normalized,
                    around: range,
                    maximumCharacters: maximumCharacters
                )
            }
        }

        let endIndex = normalized.index(normalized.startIndex, offsetBy: maximumCharacters)
        return String(normalized[..<endIndex]).trimmingCharacters(in: .whitespacesAndNewlines) + "…"
    }

    private func window(
        in text: String,
        around range: Range<String.Index>,
        maximumCharacters: Int
    ) -> String {
        let halfWindow = max(40, maximumCharacters / 2)
        let prefixStart = text.index(range.lowerBound, offsetBy: -halfWindow, limitedBy: text.startIndex) ?? text.startIndex
        let suffixEnd = text.index(range.upperBound, offsetBy: halfWindow, limitedBy: text.endIndex) ?? text.endIndex
        var snippet = String(text[prefixStart..<suffixEnd]).trimmingCharacters(in: .whitespacesAndNewlines)

        if prefixStart > text.startIndex {
            snippet = "…" + snippet
        }
        if suffixEnd < text.endIndex {
            snippet += "…"
        }

        if snippet.count <= maximumCharacters {
            return snippet
        }

        let endIndex = snippet.index(snippet.startIndex, offsetBy: maximumCharacters)
        return String(snippet[..<endIndex]).trimmingCharacters(in: .whitespacesAndNewlines) + "…"
    }

    private func excerptCandidates(from question: String) -> [String] {
        let normalizedQuestion = normalizeWhitespace(in: question)
        var candidates: [String] = []

        if !normalizedQuestion.isEmpty {
            candidates.append(normalizedQuestion)
        }

        let latinTokens = normalizedQuestion
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count >= 2 }
        candidates.append(contentsOf: latinTokens)

        return Array(NSOrderedSet(array: candidates)) as? [String] ?? candidates
    }

    private func normalizeWhitespace(in text: String) -> String {
        text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
