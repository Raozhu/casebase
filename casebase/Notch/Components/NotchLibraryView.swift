import AppKit
import SwiftUI

struct NotchLibraryView: View {
    @ObservedObject var viewModel: NotchViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Text(CasebasePromptCatalog.ui.libraryTitle)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)

                Spacer()

                Button(action: viewModel.closeLibrary) {
                    Text(CasebasePromptCatalog.ui.settingsCloseButtonTitle)
                }
                .buttonStyle(NotchActionButtonStyle(prominent: false))
            }

            if viewModel.isLibraryLoading {
                libraryStatusView(message: CasebasePromptCatalog.ui.libraryLoadingMessage)
            } else if let errorMessage = viewModel.libraryErrorMessage, !errorMessage.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text(errorMessage)
                        .font(.system(size: 12))
                        .foregroundStyle(Color(red: 1.0, green: 0.58, blue: 0.58))
                        .fixedSize(horizontal: false, vertical: true)

                    Button(action: viewModel.openLibrary) {
                        Text(CasebasePromptCatalog.ui.retryButtonTitle)
                    }
                    .buttonStyle(NotchActionButtonStyle(prominent: false))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            } else if viewModel.libraryRecords.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text(CasebasePromptCatalog.ui.libraryEmptyTitle)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)

                    Text(CasebasePromptCatalog.ui.libraryEmptyDetail)
                        .font(.system(size: 12))
                        .foregroundStyle(Color.white.opacity(0.64))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.libraryRecords) { record in
                            LibraryRecordRow(record: record, viewModel: viewModel)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func libraryStatusView(message: String) -> some View {
        VStack(spacing: 12) {
            ProgressView()
                .controlSize(.small)
                .tint(.white)

            Text(message)
                .font(.system(size: 12))
                .foregroundStyle(Color.white.opacity(0.68))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
}

private struct LibraryRecordRow: View {
    let record: ImportRecord
    @ObservedObject var viewModel: NotchViewModel

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            LibraryAssetPreviewView(record: record, viewModel: viewModel, compact: true)

            VStack(alignment: .leading, spacing: 6) {
                Text(record.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Text(record.shortSummary)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.white.opacity(0.72))
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)

                Text(viewModel.formattedLibraryTimestamp(for: record.updatedAt))
                    .font(.system(size: 11))
                    .foregroundStyle(Color.white.opacity(0.48))
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: { viewModel.openLibraryRecord(record.id) }) {
                Text(CasebasePromptCatalog.ui.libraryViewDetailButton)
            }
            .buttonStyle(NotchActionButtonStyle(prominent: false))
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.04))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        }
    }
}

struct LibraryAssetPreviewView: View {
    let record: ImportRecord
    @ObservedObject var viewModel: NotchViewModel
    let compact: Bool

    private var assetURL: URL? {
        viewModel.libraryAssetURL(for: record)
    }

    private var previewSize: CGFloat {
        compact ? 72 : 120
    }

    var body: some View {
        Group {
            if record.sourceKind == .image,
               let assetURL,
               let image = NSImage(contentsOf: assetURL)
            {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                VStack(spacing: compact ? 8 : 10) {
                    Image(systemName: viewModel.libraryPreviewSystemImage(for: record))
                        .font(.system(size: compact ? 22 : 28, weight: .semibold))
                        .foregroundStyle(.white)

                    Text(viewModel.libraryKindLabel(for: record))
                        .font(.system(size: compact ? 11 : 12, weight: .semibold))
                        .foregroundStyle(.white)

                    Text(viewModel.libraryKindDetail(for: record))
                        .font(.system(size: compact ? 9 : 10))
                        .foregroundStyle(Color.white.opacity(0.56))
                        .multilineTextAlignment(.center)
                        .lineLimit(compact ? 2 : 3)
                }
                .padding(.horizontal, 8)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.white.opacity(0.04))
            }
        }
        .frame(width: previewSize, height: previewSize)
        .clipped()
        .background(
            RoundedRectangle(cornerRadius: compact ? 16 : 20, style: .continuous)
                .fill(Color.white.opacity(0.04))
        )
        .overlay {
            RoundedRectangle(cornerRadius: compact ? 16 : 20, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: compact ? 16 : 20, style: .continuous))
    }
}
