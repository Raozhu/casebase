import SwiftUI

struct NotchLanguagePickerView: View {
    let selectedLanguage: CasebaseLanguage
    let onSelectLanguage: (CasebaseLanguage) -> Void

    var body: some View {
        HStack(spacing: 4) {
            ForEach(CasebaseLanguage.allCases, id: \.self) { language in
                Button(action: { onSelectLanguage(language) }) {
                    HStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                            .fill(selectedLanguage == language ? Color.black : Color.white.opacity(0.46))
                            .frame(width: 5, height: 5)

                        Text(language.shortDisplayName)
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundStyle(
                                selectedLanguage == language ? Color.black : Color.white.opacity(0.82)
                            )
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(
                                selectedLanguage == language
                                    ? Color.white
                                    : Color.white.opacity(0.06)
                            )
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(
                                selectedLanguage == language
                                    ? Color.white.opacity(0.18)
                                    : Color.white.opacity(0.08),
                                lineWidth: 1
                            )
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }
}
