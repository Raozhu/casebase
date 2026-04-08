import SwiftUI

struct NotchLanguagePickerView: View {
    let selectedLanguage: CasebaseLanguage
    let onSelectLanguage: (CasebaseLanguage) -> Void

    var body: some View {
        HStack(spacing: 4) {
            ForEach(CasebaseLanguage.allCases, id: \.self) { language in
                Button(action: { onSelectLanguage(language) }) {
                    Text(language.shortDisplayName)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(
                            selectedLanguage == language ? Color.black : Color.white.opacity(0.82)
                        )
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            Capsule(style: .continuous)
                                .fill(
                                    selectedLanguage == language
                                        ? Color.white
                                        : Color.white.opacity(0.06)
                                )
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }
}
