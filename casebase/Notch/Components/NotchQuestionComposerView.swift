import SwiftUI

struct NotchQuestionComposerView: View {
    @Binding var question: String
    let isBusy: Bool
    let onSubmit: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            TextField(CasebasePromptCatalog.ui.composerPlaceholder, text: $question)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .foregroundStyle(.white)
                .disabled(isBusy)
                .onSubmit(onSubmit)

            Button(action: onSubmit) {
                Text(CasebasePromptCatalog.ui.composerSubmitButton)
                    .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(NotchActionButtonStyle(prominent: true))
            .disabled(isBusy || question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
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

struct NotchActionButtonStyle: ButtonStyle {
    let prominent: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(prominent ? Color.black : Color.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(prominent ? Color.white : Color.white.opacity(0.08))
            )
            .opacity(configuration.isPressed ? 0.72 : 1)
    }
}
