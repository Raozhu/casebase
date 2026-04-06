import SwiftUI

struct NotchAnswerResultView: View {
    @ObservedObject var viewModel: NotchViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 12) {
                    if let answer = viewModel.latestAnswer {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 8) {
                                Text(CasebasePromptCatalog.ui.answerLabel)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(Color.white.opacity(0.56))

                                if answer.usedModelSupplement {
                                    Text(CasebasePromptCatalog.ui.modelSupplementLabel)
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundStyle(Color.black)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Capsule(style: .continuous).fill(Color.white))
                                }
                            }

                            Text(answer.answerText)
                                .font(.system(size: 14))
                                .foregroundStyle(.white)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if let answer = viewModel.latestAnswer, !answer.citations.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(CasebasePromptCatalog.ui.sourcesLabel)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(Color.white.opacity(0.56))

                            VStack(spacing: 8) {
                                ForEach(answer.citations) { citation in
                                    NotchCitationCardView(citation: citation)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            NotchQuestionComposerView(
                question: $viewModel.draftQuestion,
                isBusy: viewModel.isBusy,
                onSubmit: viewModel.submitQuestion
            )
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}
