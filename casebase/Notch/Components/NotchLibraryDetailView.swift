import SwiftUI

struct NotchLibraryDetailView: View {
    @ObservedObject var viewModel: NotchViewModel

    var body: some View {
        guard let record = viewModel.selectedLibraryRecord else {
            return AnyView(
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        Text(CasebasePromptCatalog.ui.libraryDetailTitle)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white)

                        Spacer()

                        Button(action: viewModel.closeLibraryDetail) {
                            Text(CasebasePromptCatalog.ui.settingsCloseButtonTitle)
                        }
                        .buttonStyle(NotchActionButtonStyle(prominent: false))
                    }

                    Text(CasebasePromptCatalog.ui.libraryEmptyTitle)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            )
        }

        return AnyView(
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    Text(CasebasePromptCatalog.ui.libraryDetailTitle)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)

                    Spacer()

                    Button(action: viewModel.closeLibraryDetail) {
                        Text(CasebasePromptCatalog.ui.settingsCloseButtonTitle)
                    }
                    .buttonStyle(NotchActionButtonStyle(prominent: false))
                }

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        HStack(alignment: .top, spacing: 16) {
                            LibraryAssetPreviewView(record: record, viewModel: viewModel, compact: false)

                            VStack(alignment: .leading, spacing: 8) {
                                Text(record.title)
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .fixedSize(horizontal: false, vertical: true)

                                Text(viewModel.libraryKindLabel(for: record))
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(Color.white.opacity(0.52))

                                Text(viewModel.formattedLibraryTimestamp(for: record.updatedAt))
                                    .font(.system(size: 11))
                                    .foregroundStyle(Color.white.opacity(0.52))
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        librarySection(title: CasebasePromptCatalog.ui.librarySummarySectionTitle) {
                            Text(record.shortSummary)
                                .font(.system(size: 13))
                                .foregroundStyle(.white)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        librarySection(title: CasebasePromptCatalog.ui.libraryMetadataSectionTitle) {
                            VStack(alignment: .leading, spacing: 10) {
                                LibraryMetadataRow(label: CasebasePromptCatalog.ui.libraryFileNameLabel, value: record.fileName)
                                LibraryMetadataRow(label: CasebasePromptCatalog.ui.libraryTypeLabel, value: viewModel.libraryKindLabel(for: record))
                                LibraryMetadataRow(label: CasebasePromptCatalog.ui.librarySceneLabel, value: record.scene)
                                LibraryMetadataRow(label: CasebasePromptCatalog.ui.libraryPurposeLabel, value: record.purpose)
                                LibraryMetadataRow(
                                    label: CasebasePromptCatalog.ui.libraryParseStatusLabel,
                                    value: CasebasePromptCatalog.ui.libraryParseStatusValue(record.parseStatus)
                                )

                                if !record.tags.isEmpty {
                                    LibraryMetadataRow(
                                        label: CasebasePromptCatalog.ui.libraryTagsLabel,
                                        value: record.tags.joined(separator: " · ")
                                    )
                                }
                            }
                        }

                        librarySection(title: CasebasePromptCatalog.ui.libraryStructuredDataSectionTitle) {
                            if record.structuredData.isEmpty {
                                Text(CasebasePromptCatalog.ui.libraryNoStructuredDataMessage)
                                    .font(.system(size: 12))
                                    .foregroundStyle(Color.white.opacity(0.58))
                            } else {
                                VStack(alignment: .leading, spacing: 10) {
                                    ForEach(record.structuredData.keys.sorted(), id: \.self) { key in
                                        if let value = record.structuredData[key] {
                                            LibraryMetadataRow(
                                                label: key,
                                                value: viewModel.formattedLibraryValue(value)
                                            )
                                        }
                                    }
                                }
                            }
                        }

                        librarySection(title: CasebasePromptCatalog.ui.librarySnippetsSectionTitle) {
                            if record.usefulSnippets.isEmpty {
                                Text(CasebasePromptCatalog.ui.libraryNoSnippetsMessage)
                                    .font(.system(size: 12))
                                    .foregroundStyle(Color.white.opacity(0.58))
                            } else {
                                VStack(alignment: .leading, spacing: 8) {
                                    ForEach(record.usefulSnippets, id: \.self) { snippet in
                                        Text(snippet)
                                            .font(.system(size: 12))
                                            .foregroundStyle(.white)
                                            .fixedSize(horizontal: false, vertical: true)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 10)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .background(
                                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                    .fill(Color.white.opacity(0.04))
                                            )
                                    }
                                }
                            }
                        }

                        if let libraryErrorMessage = viewModel.libraryErrorMessage, !libraryErrorMessage.isEmpty {
                            Text(libraryErrorMessage)
                                .font(.system(size: 12))
                                .foregroundStyle(Color(red: 1.0, green: 0.58, blue: 0.58))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

                VStack(alignment: .leading, spacing: 10) {
                    Text(CasebasePromptCatalog.ui.libraryActionsSectionTitle)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.56))

                    HStack(spacing: 10) {
                        Button(action: viewModel.revealSelectedLibraryRecord) {
                            Text(CasebasePromptCatalog.ui.libraryRevealButtonTitle)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(NotchActionButtonStyle(prominent: false))

                        Button(action: viewModel.openSelectedLibraryRecord) {
                            Text(CasebasePromptCatalog.ui.libraryOpenButtonTitle)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(NotchActionButtonStyle(prominent: false))

                        Button(action: viewModel.deleteSelectedLibraryRecord) {
                            Text(CasebasePromptCatalog.ui.libraryDeleteButtonTitle)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(NotchActionButtonStyle(prominent: false))
                        .disabled(viewModel.isDeletingLibraryRecord)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        )
    }

    private func librarySection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.56))

            content()
        }
    }
}

private struct LibraryMetadataRow: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.56))

            Text(value)
                .font(.system(size: 12))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
