import SwiftUI

struct NotchQuestionComposerView: View {
    @Binding var question: String
    let placeholder: String
    let isBusy: Bool
    let leadingIcon: NotchPixelIcon?
    let leadingActionTitle: String?
    let leadingActionTint: Color
    let isLeadingActionDisabled: Bool
    let onLeadingAction: (() -> Void)?
    let onSubmit: () -> Void

    init(
        question: Binding<String>,
        placeholder: String,
        isBusy: Bool,
        leadingIcon: NotchPixelIcon? = nil,
        leadingActionTitle: String? = nil,
        leadingActionTint: Color = Color.white.opacity(0.74),
        isLeadingActionDisabled: Bool = false,
        onLeadingAction: (() -> Void)? = nil,
        onSubmit: @escaping () -> Void
    ) {
        _question = question
        self.placeholder = placeholder
        self.isBusy = isBusy
        self.leadingIcon = leadingIcon
        self.leadingActionTitle = leadingActionTitle
        self.leadingActionTint = leadingActionTint
        self.isLeadingActionDisabled = isLeadingActionDisabled
        self.onLeadingAction = onLeadingAction
        self.onSubmit = onSubmit
    }

    var body: some View {
        HStack(spacing: 10) {
            if let leadingIcon, let onLeadingAction {
                Button(action: onLeadingAction) {
                    NotchPixelIconView(
                        icon: leadingIcon,
                        color: leadingActionTint,
                        size: 12
                    )
                }
                .buttonStyle(NotchChromeIconButtonStyle())
                .disabled(isBusy || isLeadingActionDisabled)
                .help(leadingActionTitle ?? "")
            }

            TextField(placeholder, text: $question)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .foregroundStyle(.white)
                .disabled(isBusy)
                .onSubmit(onSubmit)

            Button(action: onSubmit) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 13, weight: .semibold))
            }
            .buttonStyle(NotchCircularSendButtonStyle())
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

struct NotchCircularSendButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(Color.black.opacity(configuration.isPressed ? 0.78 : 1))
            .frame(width: 30, height: 30)
            .background(
                Circle()
                    .fill(Color.white.opacity(configuration.isPressed ? 0.82 : 1))
            )
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

struct NotchChromeIconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(Color.white.opacity(configuration.isPressed ? 0.96 : 0.74))
            .frame(width: 30, height: 30)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.white.opacity(configuration.isPressed ? 0.12 : 0.06))
            )
    }
}

struct NotchBackIconButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            NotchPixelIconView(
                icon: .chevronLeft,
                color: Color.white.opacity(0.84),
                size: 13
            )
        }
        .buttonStyle(NotchChromeIconButtonStyle())
    }
}
