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
            Text(CasebasePromptCatalog.ui.taskPanelTitle)
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
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(CasebasePromptCatalog.ui.taskSupplementTitle)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)

                    Text(task.title)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.68))
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                }

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

                VStack(alignment: .leading, spacing: 8) {
                    if let validationMessage = viewModel.clarificationValidationMessage(for: task.id) {
                        Text(validationMessage)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Color(red: 1.0, green: 0.58, blue: 0.58))
                    }

                    HStack(alignment: .bottom, spacing: 10) {
                        Button(action: { viewModel.skipClarificationQuestion(task.id) }) {
                            Text(CasebasePromptCatalog.ui.taskSupplementDismissButton)
                        }
                        .buttonStyle(NotchActionButtonStyle(prominent: false))

                        Spacer(minLength: 0)

                        VStack(alignment: .trailing, spacing: 5) {
                            if viewModel.isLastClarificationQuestion(for: task.id) {
                                Button(action: { viewModel.submitClarification(task.id) }) {
                                    Text(CasebasePromptCatalog.ui.taskSupplementContinueButton)
                                }
                                .buttonStyle(NotchActionButtonStyle(prominent: true))
                            } else {
                                Button(action: { viewModel.goToNextClarificationQuestion(task.id) }) {
                                    Text(CasebasePromptCatalog.ui.taskClarificationNextButton)
                                }
                                .buttonStyle(NotchActionButtonStyle(prominent: true))
                            }

                            Text(clarificationProgressSummary(for: task))
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(Color.white.opacity(0.52))
                        }
                    }
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white.opacity(0.035))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.07), lineWidth: 1)
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }

    private func clarificationContent(
        taskID: UUID,
        clarificationRequest: ClarificationRequest,
        currentQuestion: ClarificationQuestion
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text(CasebasePromptCatalog.ui.taskClarificationUncertaintyLabel)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.5))

                Text(clarificationRequest.uncertaintySummary)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)

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

    private func clarificationProgressSummary(for task: NotchIngestTask) -> String {
        var parts = [
            CasebasePromptCatalog.ui.taskClarificationRoundLabel(
                current: min((task.record?.clarificationRoundCount ?? 0) + 1, viewModel.maxClarificationRounds),
                maximum: viewModel.maxClarificationRounds
            )
        ]

        if let progress = viewModel.clarificationQuestionProgress(for: task.id) {
            parts.append(
                CasebasePromptCatalog.ui.taskClarificationQuestionProgressLabel(
                    current: progress.current,
                    total: progress.total
                )
            )
        }

        return parts.joined(separator: " · ")
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
    @FocusState private var isManualInputFocused: Bool

    private var normalizedAnswer: String {
        answer.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var manualInputSelected: Bool {
        isManualInputFocused || (!normalizedAnswer.isEmpty && !question.suggestedOptions.contains(normalizedAnswer))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(question.suggestedOptions, id: \.self) { option in
                Button(action: {
                    isManualInputFocused = false
                    onSelectOption(option)
                }) {
                    HStack(spacing: 10) {
                        Text(option)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(normalizedAnswer == option ? Color.black : Color.white.opacity(0.88))
                            .multilineTextAlignment(.leading)
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)

                        Spacer(minLength: 0)

                        if normalizedAnswer == option {
                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.black.opacity(0.8))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(ClarificationOptionRowButtonStyle(isSelected: normalizedAnswer == option))
            }

            manualInputOption
        }
    }

    private var manualInputOption: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(CasebasePromptCatalog.ui.taskClarificationManualInputButton)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(manualInputSelected ? Color.white.opacity(0.9) : Color.white.opacity(0.58))

            TextField(
                "",
                text: $answer,
                prompt: Text(CasebasePromptCatalog.ui.taskSupplementPlaceholder)
                    .foregroundStyle(Color.white.opacity(0.34))
            )
            .textFieldStyle(.plain)
            .font(.system(size: 12))
            .foregroundStyle(.white)
            .focused($isManualInputFocused)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(manualInputSelected ? Color.white.opacity(0.09) : Color.white.opacity(0.04))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.white.opacity(manualInputSelected ? 0.16 : 0.08), lineWidth: 1)
        }
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
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
        isManualInputFocused = true
    }
}

private struct ClarificationOptionRowButtonStyle: ButtonStyle {
    let isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected ? Color.white.opacity(0.92) : Color.white.opacity(0.05))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.white.opacity(isSelected ? 0.0 : 0.08), lineWidth: 1)
            }
            .opacity(configuration.isPressed ? 0.82 : 1)
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
