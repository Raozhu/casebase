import SwiftUI

struct NotchAnswerResultView: View {
    @ObservedObject var viewModel: NotchViewModel

    private var composerLeadingIcon: NotchPixelIcon? {
        viewModel.showsSearchConversationDeleteButton ? .trash : nil
    }

    private var composerLeadingAction: (() -> Void)? {
        guard viewModel.showsSearchConversationDeleteButton else { return nil }
        return viewModel.deleteActiveSearchConversation
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            ScrollView(.vertical, showsIndicators: false) {
                Group {
                    if viewModel.questionContext == .globalSearch {
                        exploreContent
                    } else {
                        savedRecordContent
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            NotchQuestionComposerView(
                question: $viewModel.draftQuestion,
                placeholder: viewModel.answerComposerPlaceholder,
                isBusy: viewModel.isBusy,
                leadingIcon: composerLeadingIcon,
                leadingActionTitle: CasebasePromptCatalog.ui.libraryDeleteButtonTitle,
                leadingActionTint: Color(red: 0.95, green: 0.52, blue: 0.52),
                isLeadingActionDisabled: !viewModel.showsSearchConversationDeleteButton,
                onLeadingAction: composerLeadingAction,
                onSubmit: viewModel.submitQuestion
            )
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private var header: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(viewModel.answerPanelTitle)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
            }

            Spacer(minLength: 0)

            if viewModel.questionContext == .globalSearch,
               !viewModel.showsSearchConversationList,
               !viewModel.activeSearchConversationTags.isEmpty
            {
                SearchConversationTagStrip(tags: viewModel.activeSearchConversationTags)
            }

            if viewModel.answerPanelShowsBackButton && !viewModel.isBusy {
                NotchBackIconButton(action: viewModel.backFromAnswerPanel)
            }
        }
    }

    private var savedRecordContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !viewModel.answerPanelDetail.isEmpty || viewModel.answerPanelMetaLine != nil {
                VStack(alignment: .leading, spacing: 6) {
                    if !viewModel.answerPanelDetail.isEmpty {
                        Text(viewModel.answerPanelDetail)
                            .font(.system(size: 13))
                            .foregroundStyle(Color.white.opacity(0.74))
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if let metaLine = viewModel.answerPanelMetaLine {
                        Text(metaLine)
                            .font(.system(size: 11))
                            .foregroundStyle(Color.white.opacity(0.56))
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if let record = viewModel.activeRecord,
                       viewModel.questionContext == .savedRecord,
                       !record.tags.isEmpty
                    {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(record.tags, id: \.self) { tag in
                                    Text(tag)
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(Color.white.opacity(0.82))
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(
                                            Capsule(style: .continuous)
                                                .fill(Color.white.opacity(0.07))
                                        )
                                }
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let answerText = viewModel.answerDisplayText {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Text(CasebasePromptCatalog.ui.answerLabel)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.56))

                        if viewModel.isBusy {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .tint(.white)
                                .scaleEffect(0.6)
                        } else if let answer = viewModel.latestAnswer, answer.usedModelSupplement {
                            Text(CasebasePromptCatalog.ui.modelSupplementLabel)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(Color.black)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Capsule(style: .continuous).fill(Color.white))
                        }
                    }

                    Text(answerText)
                        .font(.system(size: 14))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else if viewModel.isBusy {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(.white)
                            .scaleEffect(0.7)

                        Text(CasebasePromptCatalog.ui.answeringTitle)
                            .font(.system(size: 12))
                            .foregroundStyle(Color.white.opacity(0.62))
                    }

                    Text(viewModel.answerThinkingDisplayText)
                        .font(.system(size: 13))
                        .foregroundStyle(Color.white.opacity(0.78))
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if let answer = viewModel.latestAnswer, !answer.citations.isEmpty {
                sourceSection(for: answer)
            }
        }
    }

    private var exploreContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            if viewModel.showsSearchConversationList {
                if viewModel.orderedSearchConversations.isEmpty {
                    SearchConversationEmptyStateView()
                } else {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        ForEach(viewModel.orderedSearchConversations) { conversation in
                            SearchConversationRow(
                                conversation: conversation,
                                formattedDate: viewModel.formattedLibraryTimestamp(for: conversation.updatedAt),
                                onOpen: {
                                    viewModel.openSearchConversation(conversation.id)
                                }
                            )
                        }
                    }
                }
            } else {
                if let summary = viewModel.activeSearchConversationSummary, !summary.isEmpty {
                    Text(summary)
                        .font(.system(size: 12))
                        .foregroundStyle(Color.white.opacity(0.58))
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(alignment: .leading, spacing: 10) {
                    ForEach(viewModel.activeSearchConversationTurns) { turn in
                        SearchConversationTurnCard(
                            turn: turn,
                            timestamp: viewModel.formattedLibraryTimestamp(for: turn.createdAt)
                        )
                    }

                    if let pendingQuestion = viewModel.activeSearchPendingQuestion {
                        PendingSearchConversationTurnCard(
                            question: pendingQuestion,
                            answerText: viewModel.answerDisplayText,
                            thoughtText: viewModel.answerThinkingDisplayText,
                            isBusy: viewModel.isBusy
                        )
                    }
                }

                if let answer = viewModel.activeSearchAnswer, !answer.citations.isEmpty {
                    sourceSection(for: answer)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func sourceSection(for answer: AnswerResult) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(CasebasePromptCatalog.ui.sourcesLabel)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.56))

            VStack(spacing: 8) {
                ForEach(answer.citations) { citation in
                    NotchCitationCardView(
                        citation: citation,
                        onOpenSource: {
                            viewModel.openCitationSource(citation)
                        }
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct SearchConversationTagStrip: View {
    let tags: [String]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(tags, id: \.self) { tag in
                Text(tag)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.82))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color.white.opacity(0.07))
                    )
                    .lineLimit(1)
            }
        }
    }
}

private struct SearchConversationRow: View {
    let conversation: NotchSearchConversation
    let formattedDate: String
    let onOpen: () -> Void

    private var latestQuestion: String? {
        conversation.turns.last?.question
    }

    private var latestAnswer: String? {
        conversation.turns.last?.answer.answerText
    }

    var body: some View {
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(conversation.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    Spacer(minLength: 0)

                    Text(formattedDate)
                        .font(.system(size: 10))
                        .foregroundStyle(Color.white.opacity(0.42))
                        .lineLimit(1)
                }

                if let latestQuestion, !latestQuestion.isEmpty {
                    Text(latestQuestion)
                        .font(.system(size: 12))
                        .foregroundStyle(Color.white.opacity(0.78))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }

                if let latestAnswer, !latestAnswer.isEmpty {
                    Text(latestAnswer)
                        .font(.system(size: 11))
                        .foregroundStyle(Color.white.opacity(0.52))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }

                Text("\(conversation.turns.count) \(CasebasePromptCatalog.ui.searchHistoryTurnsLabel)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.44))
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.045))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}

private struct SearchConversationEmptyStateView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(CasebasePromptCatalog.ui.searchHistoryEmptyTitle)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)

            Text(CasebasePromptCatalog.ui.searchHistoryEmptyDetail)
                .font(.system(size: 12))
                .foregroundStyle(Color.white.opacity(0.58))
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.045))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
        }
    }
}

private struct SearchConversationTurnCard: View {
    let turn: NotchSearchConversationTurn
    let timestamp: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(CasebasePromptCatalog.ui.searchQuestionLabel)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.52))

                Spacer(minLength: 0)

                Text(timestamp)
                    .font(.system(size: 10))
                    .foregroundStyle(Color.white.opacity(0.38))
            }

            Text(turn.question)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                Text(CasebasePromptCatalog.ui.answerLabel)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.52))

                if turn.answer.usedModelSupplement {
                    Text(CasebasePromptCatalog.ui.modelSupplementLabel)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color.black)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule(style: .continuous).fill(Color.white))
                }
            }

            Text(turn.answer.answerText)
                .font(.system(size: 13))
                .foregroundStyle(Color.white.opacity(0.86))
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.045))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
        }
    }
}

private struct PendingSearchConversationTurnCard: View {
    let question: String
    let answerText: String?
    let thoughtText: String
    let isBusy: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(CasebasePromptCatalog.ui.searchQuestionLabel)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.52))

            if !question.isEmpty {
                Text(question)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 8) {
                Text(CasebasePromptCatalog.ui.answerLabel)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.52))

                if isBusy {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                        .scaleEffect(0.6)
                }
            }

            if let answerText, !answerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(answerText)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.white.opacity(0.86))
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text(thoughtText)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.white.opacity(0.64))
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.045))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
        }
    }
}
