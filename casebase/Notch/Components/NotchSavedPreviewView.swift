import SwiftUI

struct NotchSavedPreviewView: View {
    @ObservedObject var viewModel: NotchViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Text(CasebasePromptCatalog.ui.savedLabel)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)

                Spacer(minLength: 0)

                NotchBackIconButton(action: viewModel.backFromSavedPreviewToTaskPanel)
            }

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    if let noticeMessage = viewModel.noticeMessage {
                        Text(noticeMessage)
                            .font(.system(size: 11))
                            .foregroundStyle(Color.white.opacity(0.56))
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if let record = viewModel.activeRecord {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(CasebasePromptCatalog.ui.savedLabel)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(Color.white.opacity(0.56))

                            HStack(alignment: .top, spacing: 8) {
                                Text(record.title)
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .multilineTextAlignment(.leading)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .layoutPriority(1)
                                    .fixedSize(horizontal: false, vertical: true)

                                if record.needsReview {
                                    Text(CasebasePromptCatalog.ui.needsReviewLabel)
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundStyle(Color.black)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Capsule(style: .continuous).fill(Color.white.opacity(0.9)))
                                }
                            }

                            Text(record.shortSummary)
                                .font(.system(size: 13))
                                .foregroundStyle(Color.white.opacity(0.74))
                                .multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .fixedSize(horizontal: false, vertical: true)

                            Text("\(record.scene) · \(record.purpose)")
                                .font(.system(size: 11))
                                .foregroundStyle(Color.white.opacity(0.56))
                                .multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .fixedSize(horizontal: false, vertical: true)

                            if !record.tags.isEmpty {
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
