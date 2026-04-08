import SwiftUI

struct NotchLibraryDetailView: View {
    @ObservedObject var viewModel: NotchViewModel
    let isMeasuring: Bool

    init(viewModel: NotchViewModel, isMeasuring: Bool = false) {
        self.viewModel = viewModel
        self.isMeasuring = isMeasuring
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            if let record = viewModel.selectedLibraryRecord {
                detailBody(record: record)
            } else {
                missingRecordView
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Text(CasebasePromptCatalog.ui.libraryDetailTitle)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white)

            Spacer()

            NotchBackIconButton(action: viewModel.closeLibraryDetail)
        }
    }

    private var missingRecordView: some View {
        LibraryGlassCard {
            Text(CasebasePromptCatalog.ui.libraryEmptyTitle)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private func detailBody(record: ImportRecord) -> some View {
        VStack(spacing: 10) {
            if isMeasuring {
                detailSections(record: record)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    detailSections(record: record)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }

            actionBar
        }
    }

    private func detailSections(record: ImportRecord) -> some View {
        LazyVStack(alignment: .leading, spacing: 12) {
            heroCard(record: record)
            metadataCard(record: record)
            structuredDataCard(record: record)
            snippetsCard(record: record)

            if let libraryErrorMessage = viewModel.libraryErrorMessage, !libraryErrorMessage.isEmpty {
                LibraryGlassCard {
                    Text(libraryErrorMessage)
                        .font(.system(size: 12))
                        .foregroundStyle(Color(red: 1.0, green: 0.58, blue: 0.58))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(.bottom, 4)
    }

    private func heroCard(record: ImportRecord) -> some View {
        LibraryGlassCard {
            HStack(alignment: .top, spacing: 14) {
                LibraryAssetPreviewView(
                    record: record,
                    viewModel: viewModel,
                    compact: false,
                    isMeasuring: isMeasuring
                )

                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        LibraryInfoPill(
                            text: viewModel.libraryKindLabel(for: record),
                            tone: .accent
                        )

                        LibraryInfoPill(
                            text: CasebasePromptCatalog.ui.libraryParseStatusValue(record.parseStatus),
                            tone: record.parseStatus == .ready ? .neutral : .warning
                        )

                        Spacer(minLength: 0)
                    }

                    Text(record.title)
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(record.shortSummary)
                        .font(.system(size: 12))
                        .foregroundStyle(Color.white.opacity(0.76))
                        .fixedSize(horizontal: false, vertical: true)

                    if !record.tags.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(record.tags, id: \.self) { tag in
                                    LibraryTagPill(text: tag)
                                }
                            }
                        }
                    }

                    HStack(spacing: 10) {
                        DetailMetaFact(
                            label: CasebasePromptCatalog.ui.libraryUpdatedAtLabel,
                            value: viewModel.formattedLibraryTimestamp(for: record.updatedAt)
                        )

                        DetailMetaFact(
                            label: CasebasePromptCatalog.ui.libraryFileNameLabel,
                            value: record.fileName
                        )
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func metadataCard(record: ImportRecord) -> some View {
        librarySectionCard(title: CasebasePromptCatalog.ui.libraryMetadataSectionTitle) {
            VStack(alignment: .leading, spacing: 12) {
                DetailValueRow(label: CasebasePromptCatalog.ui.libraryFileNameLabel, value: record.fileName)
                DetailValueRow(label: CasebasePromptCatalog.ui.libraryTypeLabel, value: viewModel.libraryKindLabel(for: record))
                DetailValueRow(label: CasebasePromptCatalog.ui.librarySceneLabel, value: record.scene)
                DetailValueRow(label: CasebasePromptCatalog.ui.libraryPurposeLabel, value: record.purpose)
                DetailValueRow(
                    label: CasebasePromptCatalog.ui.libraryParseStatusLabel,
                    value: CasebasePromptCatalog.ui.libraryParseStatusValue(record.parseStatus)
                )
                DetailValueRow(
                    label: CasebasePromptCatalog.ui.libraryUpdatedAtLabel,
                    value: viewModel.formattedLibraryTimestamp(for: record.updatedAt)
                )

                if !record.tags.isEmpty {
                    DetailValueRow(
                        label: CasebasePromptCatalog.ui.libraryTagsLabel,
                        value: record.tags.joined(separator: " · ")
                    )
                }
            }
        }
    }

    private func structuredDataCard(record: ImportRecord) -> some View {
        librarySectionCard(title: CasebasePromptCatalog.ui.libraryStructuredDataSectionTitle) {
            if record.structuredData.isEmpty {
                Text(CasebasePromptCatalog.ui.libraryNoStructuredDataMessage)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.white.opacity(0.58))
            } else {
                LazyVStack(alignment: .leading, spacing: 10) {
                    ForEach(record.structuredData.keys.sorted(), id: \.self) { key in
                        if let value = record.structuredData[key] {
                            DetailValueRow(
                                label: key,
                                value: viewModel.formattedLibraryValue(value)
                            )
                        }
                    }
                }
            }
        }
    }

    private func snippetsCard(record: ImportRecord) -> some View {
        librarySectionCard(title: CasebasePromptCatalog.ui.librarySnippetsSectionTitle) {
            if record.usefulSnippets.isEmpty {
                Text(CasebasePromptCatalog.ui.libraryNoSnippetsMessage)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.white.opacity(0.58))
            } else {
                LazyVStack(alignment: .leading, spacing: 10) {
                    ForEach(record.usefulSnippets, id: \.self) { snippet in
                        Text(snippet)
                            .font(.system(size: 12))
                            .foregroundStyle(.white)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(Color.white.opacity(0.05))
                            )
                            .overlay {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
                            }
                    }
                }
            }
        }
    }

    private var actionBar: some View {
        HStack(spacing: 8) {
            LibraryActionTileButton(
                systemImage: "folder",
                title: CasebasePromptCatalog.ui.libraryRevealButtonTitle,
                action: viewModel.revealSelectedLibraryRecord
            )

            LibraryActionTileButton(
                systemImage: "arrow.up.right.square",
                title: CasebasePromptCatalog.ui.libraryOpenButtonTitle,
                action: viewModel.openSelectedLibraryRecord
            )

            LibraryActionTileButton(
                systemImage: "trash",
                title: CasebasePromptCatalog.ui.libraryDeleteButtonTitle,
                isDestructive: true,
                action: viewModel.deleteSelectedLibraryRecord
            )
            .disabled(viewModel.isDeletingLibraryRecord)
        }
    }

    private func librarySectionCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        LibraryGlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Text(title)
                    .font(.system(size: 10))
                    .foregroundStyle(Color.white.opacity(0.46))

                content()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct DetailMetaFact: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(Color.white.opacity(0.42))

            Text(value)
                .font(.system(size: 11))
                .foregroundStyle(.white)
                .lineLimit(2)
        }
    }
}

private struct DetailValueRow: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(Color.white.opacity(0.42))

            Text(value)
                .font(.system(size: 12))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 2)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
