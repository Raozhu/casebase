import SwiftUI

struct NotchTaskPanelView: View {
    @ObservedObject var viewModel: NotchViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            if let taskNeedingInput = viewModel.firstNeedsInputTask {
                clarificationPage(for: taskNeedingInput)
            } else {
                taskList
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Text(CasebasePromptCatalog.ui.taskPanelTitle)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)

            Spacer()

            Button(action: viewModel.backToHomeFromTaskPanel) {
                Text(CasebasePromptCatalog.ui.settingsCloseButtonTitle)
            }
            .buttonStyle(NotchActionButtonStyle(prominent: false))
        }
    }

    private var taskList: some View {
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

    @ViewBuilder
    private func clarificationPage(for task: NotchIngestTask) -> some View {
        if let clarificationRequest = viewModel.clarificationRequest(for: task.id),
           let currentQuestion = viewModel.currentClarificationQuestion(for: task.id)
        {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(CasebasePromptCatalog.ui.taskSupplementTitle)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)

                    Text(task.title)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.68))
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(
                        CasebasePromptCatalog.ui.taskClarificationRoundLabel(
                            current: min((task.record?.clarificationRoundCount ?? 0) + 1, viewModel.maxClarificationRounds),
                            maximum: viewModel.maxClarificationRounds
                        )
                    )
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.56))
                }

                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        Text(CasebasePromptCatalog.ui.taskSupplementDetail)
                            .font(.system(size: 12))
                            .foregroundStyle(Color.white.opacity(0.68))
                            .fixedSize(horizontal: false, vertical: true)

                        clarificationMetaBlock(
                            title: CasebasePromptCatalog.ui.taskClarificationUncertaintyLabel,
                            value: clarificationRequest.uncertaintySummary
                        )

                        clarificationMetaBlock(
                            title: CasebasePromptCatalog.ui.taskClarificationImpactLabel,
                            value: clarificationRequest.impactExplanation
                        )

                        if let progress = viewModel.clarificationQuestionProgress(for: task.id) {
                            Text(
                                CasebasePromptCatalog.ui.taskClarificationQuestionProgressLabel(
                                    current: progress.current,
                                    total: progress.total
                                )
                            )
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.56))
                        }

                        ClarificationQuestionCard(
                            question: currentQuestion,
                            answer: viewModel.bindingForClarificationAnswer(taskID: task.id, questionID: currentQuestion.id),
                            onSelectOption: { option in
                                viewModel.applyClarificationOption(option, to: task.id, questionID: currentQuestion.id)
                            }
                        )
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

                if let validationMessage = viewModel.clarificationValidationMessage(for: task.id) {
                    Text(validationMessage)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color(red: 1.0, green: 0.58, blue: 0.58))
                }

                HStack(spacing: 10) {
                    Button(action: { viewModel.skipClarificationQuestion(task.id) }) {
                        Text(CasebasePromptCatalog.ui.taskSupplementDismissButton)
                    }
                    .buttonStyle(NotchActionButtonStyle(prominent: false))

                    Spacer(minLength: 0)

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
                }

                footer
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white.opacity(0.04))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private func clarificationMetaBlock(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.6))

            Text(value)
                .font(.system(size: 12))
                .foregroundStyle(.white)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
        }
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

private struct ClarificationQuestionCard: View {
    let question: ClarificationQuestion
    @Binding var answer: String
    let onSelectOption: (String) -> Void
    @State private var showsManualInput = false

    private let optionColumns = [
        GridItem(.adaptive(minimum: 180, maximum: 260), spacing: 8, alignment: .leading)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(question.title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)

            Text(question.reason)
                .font(.system(size: 11))
                .foregroundStyle(Color.white.opacity(0.58))
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)

            if !question.suggestedOptions.isEmpty {
                LazyVGrid(columns: optionColumns, alignment: .leading, spacing: 8) {
                    ForEach(question.suggestedOptions, id: \.self) { option in
                        Button(action: { onSelectOption(option) }) {
                            Text(option)
                                .font(.system(size: 11, weight: .medium))
                                .multilineTextAlignment(.leading)
                                .lineLimit(nil)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(ClarificationOptionButtonStyle(isSelected: answer == option))
                    }
                }
            }

            Button(action: { showsManualInput.toggle() }) {
                Text(CasebasePromptCatalog.ui.taskClarificationManualInputButton)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.78))
            }
            .buttonStyle(.plain)

            if showsManualInput || !answer.isEmpty {
                ZStack(alignment: .topLeading) {
                    if answer.isEmpty {
                        Text(CasebasePromptCatalog.ui.taskSupplementPlaceholder)
                            .font(.system(size: 13))
                            .foregroundStyle(Color.white.opacity(0.36))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                    }

                    TextEditor(text: $answer)
                        .font(.system(size: 13))
                        .foregroundStyle(.white)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 96, alignment: .topLeading)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                }
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white.opacity(0.04))
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.03))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        }
    }
}

private struct ClarificationOptionButtonStyle: ButtonStyle {
    let isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(isSelected ? Color.black : Color.white.opacity(0.86))
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                Capsule(style: .continuous)
                    .fill(isSelected ? Color.white.opacity(0.92) : Color.white.opacity(0.07))
            )
            .overlay {
                Capsule(style: .continuous)
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
