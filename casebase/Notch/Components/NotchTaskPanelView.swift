import SwiftUI

struct NotchTaskPanelView: View {
    @ObservedObject var viewModel: NotchViewModel
    let isMeasuring: Bool

    init(viewModel: NotchViewModel, isMeasuring: Bool = false) {
        self.viewModel = viewModel
        self.isMeasuring = isMeasuring
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            if let taskNeedingInput = viewModel.firstNeedsInputTask {
                clarificationPage(for: taskNeedingInput)
            } else {
                taskList
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Text(viewModel.firstNeedsInputTask == nil ? CasebasePromptCatalog.ui.taskPanelTitle : CasebasePromptCatalog.ui.taskSupplementTitle)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)

            Spacer()

            NotchBackIconButton(action: viewModel.backToHomeFromTaskPanel)
        }
    }

    private var taskList: some View {
        Group {
            if isMeasuring {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(viewModel.taskPanelTasks) { task in
                        taskRow(task)
                    }

                    footer
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(viewModel.taskPanelTasks) { task in
                            taskRow(task)
                        }

                        footer
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    private func clarificationPage(for task: NotchIngestTask) -> some View {
        if let clarificationRequest = viewModel.clarificationRequest(for: task.id),
           let currentQuestion = viewModel.currentClarificationQuestion(for: task.id)
        {
            VStack(alignment: .leading, spacing: 14) {
                Group {
                    if isMeasuring {
                        clarificationContent(
                            taskID: task.id,
                            clarificationRequest: clarificationRequest,
                            currentQuestion: currentQuestion
                        )
                    } else {
                        ScrollView {
                            clarificationContent(
                                taskID: task.id,
                                clarificationRequest: clarificationRequest,
                                currentQuestion: currentQuestion
                            )
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    if let validationMessage = viewModel.clarificationValidationMessage(for: task.id) {
                        Text(validationMessage)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Color(red: 1.0, green: 0.58, blue: 0.58))
                    }

                    HStack(alignment: .center, spacing: 10) {
                        ClarificationFooterButton(
                            title: CasebasePromptCatalog.ui.taskSupplementDismissButton,
                            systemImage: "forward.end",
                            role: .secondary,
                            action: { viewModel.skipClarificationQuestion(task.id) }
                        )
                        .frame(maxWidth: .infinity)

                        ClarificationFooterButton(
                            title: viewModel.isLastClarificationQuestion(for: task.id)
                                ? CasebasePromptCatalog.ui.taskSupplementContinueButton
                                : CasebasePromptCatalog.ui.taskClarificationNextButton,
                            systemImage: viewModel.isLastClarificationQuestion(for: task.id)
                                ? "sparkles"
                                : "arrow.right",
                            progressText: clarificationQuestionProgressText(for: task.id),
                            role: .primary,
                            action: {
                                if viewModel.isLastClarificationQuestion(for: task.id) {
                                    viewModel.submitClarification(task.id)
                                } else {
                                    viewModel.goToNextClarificationQuestion(task.id)
                                }
                            }
                        )
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }

    private func clarificationContent(
        taskID: UUID,
        clarificationRequest: ClarificationRequest,
        currentQuestion: ClarificationQuestion
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text(currentQuestion.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)

                let subtitle = clarificationSubtitle(
                    clarificationRequest: clarificationRequest,
                    currentQuestion: currentQuestion
                )
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(Color.white.opacity(0.64))
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            ClarificationQuestionOptionsSection(
                question: currentQuestion,
                answer: viewModel.bindingForClarificationAnswer(taskID: taskID, questionID: currentQuestion.id),
                onSelectOption: { option in
                    viewModel.applyClarificationOption(option, to: taskID, questionID: currentQuestion.id)
                }
            )
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private func clarificationSubtitle(
        clarificationRequest: ClarificationRequest,
        currentQuestion: ClarificationQuestion
    ) -> String {
        let primary = currentQuestion.reason.trimmingCharacters(in: .whitespacesAndNewlines)
        if !primary.isEmpty {
            return primary
        }

        return clarificationRequest.impactExplanation.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func clarificationQuestionProgressText(for taskID: UUID) -> String? {
        guard let progress = viewModel.clarificationQuestionProgress(for: taskID) else { return nil }
        return "\(progress.current)/\(progress.total)"
    }

    private func taskRow(_ task: NotchIngestTask) -> some View {
        Button(action: { viewModel.openTaskRecord(task.id) }) {
            HStack(spacing: 12) {
                TaskRowIcon(sourceKind: task.sourceKind)

                VStack(alignment: .leading, spacing: 4) {
                    Text(task.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(2)

                    Text(viewModel.detailText(for: task))
                        .font(.system(size: 11))
                        .foregroundStyle(Color.white.opacity(0.58))
                        .lineLimit(3)
                }

                Spacer(minLength: 0)

                Text(viewModel.statusText(for: task))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(statusTint(for: task))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.04))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .disabled(task.record == nil)
    }

    private var footer: some View {
        Text(CasebasePromptCatalog.ui.taskPanelFooter(unfinishedCount: viewModel.unfinishedTaskCount))
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(Color.white.opacity(0.56))
    }

    private func statusTint(for task: NotchIngestTask) -> Color {
        switch task.status {
        case .queued, .preparing:
            return Color.white.opacity(0.62)
        case .recognizing:
            return Color(red: 0.57, green: 0.82, blue: 1.0)
        case .storing:
            return Color(red: 0.54, green: 1.0, blue: 0.82)
        case .needsInput:
            return Color(red: 1.0, green: 0.82, blue: 0.48)
        case .succeeded:
            return Color(red: 0.55, green: 1.0, blue: 0.72)
        case .failed:
            return Color(red: 1.0, green: 0.56, blue: 0.56)
        }
    }
}

private struct ClarificationQuestionOptionsSection: View {
    let question: ClarificationQuestion
    @Binding var answer: String
    let onSelectOption: (String) -> Void
    @State private var manualInputText = ""
    @FocusState private var isManualInputFocused: Bool

    private var normalizedAnswer: String {
        answer.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var manualInputSelected: Bool {
        isManualInputFocused || (!normalizedAnswer.isEmpty && !question.suggestedOptions.contains(normalizedAnswer))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(question.suggestedOptions, id: \.self) { option in
                Button(action: {
                    isManualInputFocused = false
                    manualInputText = ""
                    onSelectOption(option)
                }) {
                    HStack(spacing: 10) {
                        Text(option)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.leading)
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)

                        Spacer(minLength: 0)

                        if normalizedAnswer == option {
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(Color.white.opacity(0.92))
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(ClarificationOptionRowButtonStyle(isSelected: normalizedAnswer == option))
            }

            manualInputOption
        }
        .onAppear(perform: syncManualInput)
        .onChange(of: question.id) { _, _ in
            syncManualInput()
        }
        .onChange(of: answer) { _, _ in
            syncManualInput()
        }
    }

    private var manualInputOption: some View {
        TextField(
            "",
            text: Binding(
                get: { manualInputText },
                set: { newValue in
                    manualInputText = newValue
                    answer = newValue
                }
            ),
            prompt: Text(CasebasePromptCatalog.ui.taskSupplementPlaceholder)
                .foregroundStyle(Color.white.opacity(0.34))
        )
        .textFieldStyle(.plain)
        .font(.system(size: 12))
        .foregroundStyle(.white.opacity(manualInputSelected ? 0.96 : 0.84))
        .focused($isManualInputFocused)
        .padding(.top, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture {
            activateManualInput()
        }
        .onChange(of: isManualInputFocused) { _, isFocused in
            guard isFocused else { return }
            activateManualInput()
        }
    }

    private func activateManualInput() {
        if question.suggestedOptions.contains(normalizedAnswer) {
            answer = ""
        }
        if manualInputText.isEmpty {
            manualInputText = ""
        }
        isManualInputFocused = true
    }

    private func syncManualInput() {
        if question.suggestedOptions.contains(normalizedAnswer) {
            manualInputText = ""
        } else {
            manualInputText = answer
        }
    }
}

private struct ClarificationOptionRowButtonStyle: ButtonStyle {
    let isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(
                        isSelected
                            ? Color.white.opacity(0.075)
                            : Color.white.opacity(0.02)
                    )
            )
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(
                        isSelected
                            ? Color.white.opacity(0.12)
                            : Color.white.opacity(0.03),
                        lineWidth: 1
                    )
            }
            .opacity(configuration.isPressed ? 0.82 : 1)
    }
}

private struct ClarificationFooterButton: View {
    enum Role {
        case secondary
        case primary
    }

    let title: String
    let systemImage: String
    let progressText: String?
    let role: Role
    let action: () -> Void

    init(
        title: String,
        systemImage: String,
        progressText: String? = nil,
        role: Role,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.progressText = progressText
        self.role = role
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 11, weight: .semibold))
                    .frame(width: 12)

                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)

                Spacer(minLength: 0)

                if let progressText, role == .primary {
                    Text(progressText)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color.black.opacity(0.62))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(
                            Capsule(style: .continuous)
                                .fill(Color.black.opacity(0.08))
                        )
                }
            }
            .foregroundStyle(role == .primary ? Color.black : Color.white.opacity(0.82))
            .frame(maxWidth: .infinity)
            .frame(height: 36)
            .background(background)
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(borderColor, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    private var background: some ShapeStyle {
        switch role {
        case .secondary:
            return AnyShapeStyle(Color.white.opacity(0.045))
        case .primary:
            return AnyShapeStyle(Color.white)
        }
    }

    private var borderColor: Color {
        switch role {
        case .secondary:
            return Color.white.opacity(0.06)
        case .primary:
            return Color.white.opacity(0.12)
        }
    }
}

private struct TaskRowIcon: View {
    let sourceKind: ImportSourceKind

    var body: some View {
        Image(systemName: symbolName)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 34, height: 34)
            .background(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(Color.white.opacity(0.08))
            )
    }

    private var symbolName: String {
        switch sourceKind {
        case .image:
            return "photo.fill"
        case .text:
            return "doc.text.fill"
        case .pdf:
            return "doc.richtext.fill"
        case .audio:
            return "waveform"
        case .binary:
            return "doc.fill"
        }
    }
}
