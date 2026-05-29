import AppKit
import SwiftUI

struct NotchCitationCardView: View {
    let citation: AnswerCitation
    let onOpenSource: () -> Void

    private var previewImage: NSImage? {
        guard let path = citation.previewAssetPath else { return nil }
        let resolvedPath: String
        if path.hasPrefix("/") {
            resolvedPath = path
        } else {
            resolvedPath = path
        }
        return NSImage(contentsOfFile: resolvedPath)
    }

    private var sourceKindLabel: String {
        switch citation.sourceKind {
        case .image:
            return CasebasePromptCatalog.language == .simplifiedChinese ? "图片" : "Image"
        case .text:
            return CasebasePromptCatalog.language == .simplifiedChinese ? "文本" : "Text"
        case .pdf:
            return CasebasePromptCatalog.language == .simplifiedChinese ? "PDF" : "PDF"
        case .audio:
            return CasebasePromptCatalog.language == .simplifiedChinese ? "音频" : "Audio"
        case .folder:
            return CasebasePromptCatalog.language == .simplifiedChinese ? "文件夹" : "Folder"
        case .binary:
            return CasebasePromptCatalog.language == .simplifiedChinese ? "文档" : "Document"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 8) {
                Text(sourceKindLabel)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.8))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color.white.opacity(0.08))
                    )

                Spacer(minLength: 0)

                Button(action: onOpenSource) {
                    Text(CasebasePromptCatalog.ui.sourceOpenButtonTitle)
                        .font(.system(size: 11, weight: .medium))
                }
                .buttonStyle(NotchActionButtonStyle(prominent: false))
            }

            Text(citation.title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            Text(citation.shortSummary)
                .font(.system(size: 12))
                .foregroundStyle(Color.white.opacity(0.7))
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            if let previewImage {
                Image(nsImage: previewImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            if let evidenceExcerpt = citation.evidenceExcerpt, !evidenceExcerpt.isEmpty {
                Text(evidenceExcerpt)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.white.opacity(0.56))
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let supportNote = citation.supportNote, !supportNote.isEmpty {
                Text(supportNote)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.74))
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        }
    }
}
