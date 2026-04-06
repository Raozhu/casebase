import SwiftUI

struct NotchCitationCardView: View {
    let citation: AnswerCitation

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
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

            if let relevantSnippet = citation.relevantSnippet {
                Text(relevantSnippet)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.white.opacity(0.56))
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
