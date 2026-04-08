import AppKit
import ImageIO
import SwiftUI

struct NotchLibraryView: View {
    @ObservedObject var viewModel: NotchViewModel
    let isMeasuring: Bool

    init(viewModel: NotchViewModel, isMeasuring: Bool = false) {
        self.viewModel = viewModel
        self.isMeasuring = isMeasuring
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            if viewModel.isLibraryLoading {
                libraryStatusView(message: CasebasePromptCatalog.ui.libraryLoadingMessage)
            } else if let errorMessage = viewModel.libraryErrorMessage, !errorMessage.isEmpty {
                errorView(message: errorMessage)
            } else if viewModel.libraryRecords.isEmpty {
                emptyView
            } else {
                recordsView
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Text(CasebasePromptCatalog.ui.libraryTitle)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white)

            if !viewModel.libraryRecords.isEmpty {
                Text("\(viewModel.libraryRecords.count)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.82))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color.white.opacity(0.08))
                    )
            }

            Spacer()

            NotchBackIconButton(action: viewModel.closeLibrary)
        }
    }

    private var recordsView: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(alignment: .leading, spacing: 14) {
                ForEach(viewModel.libraryRecords) { record in
                    LibraryRecordRow(record: record, viewModel: viewModel, isMeasuring: isMeasuring)
                }
            }
            .padding(.bottom, 4)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private var emptyView: some View {
        LibraryGlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Text(CasebasePromptCatalog.ui.libraryEmptyTitle)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)

                Text(CasebasePromptCatalog.ui.libraryEmptyDetail)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.white.opacity(0.66))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func errorView(message: String) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(message)
                .font(.system(size: 12))
                .foregroundStyle(Color(red: 1.0, green: 0.58, blue: 0.58))
                .fixedSize(horizontal: false, vertical: true)

            Button(action: viewModel.openLibrary) {
                Text(CasebasePromptCatalog.ui.retryButtonTitle)
            }
            .buttonStyle(NotchActionButtonStyle(prominent: false))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct LibraryRecordRow: View {
    let record: ImportRecord
    @ObservedObject var viewModel: NotchViewModel
    let isMeasuring: Bool

    var body: some View {
        Button(action: { viewModel.openLibraryRecord(record.id) }) {
            HStack(alignment: .center, spacing: 12) {
                LibraryAssetPreviewView(
                    record: record,
                    viewModel: viewModel,
                    compact: true,
                    isMeasuring: isMeasuring
                )

                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .top, spacing: 8) {
                        Text(record.title)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)

                        Spacer(minLength: 6)

                        Image(systemName: "arrow.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color.white.opacity(0.34))
                    }

                    HStack(spacing: 8) {
                        LibraryInfoPill(
                            text: viewModel.libraryKindLabel(for: record),
                            tone: .accent
                        )

                        Text(viewModel.formattedLibraryTimestamp(for: record.updatedAt))
                            .font(.system(size: 10))
                            .foregroundStyle(Color.white.opacity(0.46))
                            .lineLimit(1)
                    }

                    if !record.scene.isEmpty {
                        Text(record.scene)
                            .font(.system(size: 11))
                            .foregroundStyle(Color.white.opacity(0.58))
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white.opacity(0.045))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.05), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}

struct LibraryAssetPreviewView: View {
    let record: ImportRecord
    @ObservedObject var viewModel: NotchViewModel
    let compact: Bool
    let isMeasuring: Bool

    @State private var previewImage: NSImage?

    private var assetURL: URL? {
        viewModel.libraryAssetURL(for: record)
    }

    private var previewSize: CGFloat {
        compact ? 64 : 128
    }

    private var cacheKey: NSString {
        let path = assetURL?.path ?? record.id.uuidString
        return "\(path)#\(Int(previewSize))" as NSString
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: compact ? 18 : 26, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            previewTint.opacity(0.28),
                            Color.white.opacity(0.04),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            if let previewImage {
                Image(nsImage: previewImage)
                    .resizable()
                    .scaledToFill()
            } else {
                fallbackPreview
            }
        }
        .frame(width: previewSize, height: previewSize)
        .clipShape(RoundedRectangle(cornerRadius: compact ? 18 : 26, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: compact ? 18 : 26, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        }
        .task(id: cacheKey) {
            await loadPreview()
        }
    }

    private var fallbackPreview: some View {
        VStack(spacing: compact ? 8 : 12) {
            Image(systemName: viewModel.libraryPreviewSystemImage(for: record))
                .font(.system(size: compact ? 24 : 32, weight: .semibold))
                .foregroundStyle(.white)

            VStack(spacing: 4) {
                Text(viewModel.libraryKindLabel(for: record))
                    .font(.system(size: compact ? 11 : 12, weight: .semibold))
                    .foregroundStyle(.white)

                Text(viewModel.libraryKindDetail(for: record))
                    .font(.system(size: compact ? 9 : 10))
                    .foregroundStyle(Color.white.opacity(0.56))
                    .multilineTextAlignment(.center)
                    .lineLimit(compact ? 2 : 3)
            }
        }
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var previewTint: Color {
        switch record.sourceKind {
        case .image:
            return Color(red: 0.22, green: 0.47, blue: 0.88)
        case .pdf:
            return Color(red: 0.66, green: 0.28, blue: 0.25)
        case .text:
            return Color(red: 0.23, green: 0.58, blue: 0.48)
        case .audio:
            return Color(red: 0.62, green: 0.35, blue: 0.78)
        case .binary:
            return Color(red: 0.40, green: 0.46, blue: 0.60)
        }
    }

    private func loadPreview() async {
        guard !isMeasuring, record.sourceKind == .image, let assetURL else {
            previewImage = nil
            return
        }

        if let cached = LibraryPreviewImageCache.images.object(forKey: cacheKey) {
            previewImage = cached
            return
        }

        let maxPixelSize = max(160, Int(previewSize * 2.2))
        let image = await Task.detached(priority: .utility) {
            LibraryPreviewImageCache.thumbnail(for: assetURL, maxPixelSize: maxPixelSize)
        }.value

        guard !Task.isCancelled else { return }
        previewImage = image
    }
}

struct LibraryGlassCard<Content: View>: View {
    @ViewBuilder let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.06),
                                Color.white.opacity(0.024),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.05), lineWidth: 1)
            }
    }
}

enum LibraryInfoPillTone {
    case neutral
    case accent
    case warning
    case danger
}

struct LibraryInfoPill: View {
    let text: String
    let tone: LibraryInfoPillTone

    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(foregroundColor)
            .lineLimit(1)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(
                Capsule(style: .continuous)
                    .fill(backgroundColor)
            )
    }

    private var foregroundColor: Color {
        switch tone {
        case .neutral:
            return Color.white.opacity(0.86)
        case .accent:
            return Color(red: 0.70, green: 0.83, blue: 1.0)
        case .warning:
            return Color(red: 1.0, green: 0.86, blue: 0.55)
        case .danger:
            return Color(red: 1.0, green: 0.72, blue: 0.72)
        }
    }

    private var backgroundColor: Color {
        switch tone {
        case .neutral:
            return Color.white.opacity(0.09)
        case .accent:
            return Color(red: 0.12, green: 0.24, blue: 0.42)
        case .warning:
            return Color(red: 0.29, green: 0.21, blue: 0.07)
        case .danger:
            return Color(red: 0.32, green: 0.10, blue: 0.12)
        }
    }
}

struct LibraryTagPill: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(Color.white.opacity(0.72))
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.white.opacity(0.06))
            )
            .overlay {
                Capsule(style: .continuous)
                    .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
            }
    }
}

struct LibraryActionTileButton: View {
    let systemImage: String
    let title: String
    let subtitle: String?
    let isDestructive: Bool
    let action: () -> Void

    init(systemImage: String, title: String, subtitle: String? = nil, isDestructive: Bool = false, action: @escaping () -> Void) {
        self.systemImage = systemImage
        self.title = title
        self.subtitle = subtitle
        self.isDestructive = isDestructive
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.system(size: 12, weight: .semibold))
                if let subtitle, !subtitle.isEmpty {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(title)
                            .font(.system(size: 11, weight: .medium))
                            .lineLimit(1)

                        Text(subtitle)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle((isDestructive ? Color(red: 1.0, green: 0.74, blue: 0.74) : Color.white).opacity(0.62))
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Text(title)
                        .font(.system(size: 11, weight: .medium))
                        .lineLimit(1)
                }
            }
            .foregroundStyle(isDestructive ? Color(red: 1.0, green: 0.74, blue: 0.74) : .white)
            .frame(maxWidth: .infinity, minHeight: subtitle == nil ? 36 : 42)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isDestructive ? Color(red: 0.18, green: 0.07, blue: 0.08) : Color.white.opacity(0.05))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(
                        isDestructive ? Color(red: 0.38, green: 0.13, blue: 0.15) : Color.white.opacity(0.06),
                        lineWidth: 1
                    )
            }
        }
        .buttonStyle(.plain)
    }
}

private enum LibraryPreviewImageCache {
    static let images: NSCache<NSString, NSImage> = {
        let cache = NSCache<NSString, NSImage>()
        cache.countLimit = 160
        return cache
    }()

    static func thumbnail(for url: URL, maxPixelSize: Int) -> NSImage? {
        let key = "\(url.path)#\(maxPixelSize)" as NSString
        if let cached = images.object(forKey: key) {
            return cached
        }

        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            return nil
        }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
            kCGImageSourceShouldCacheImmediately: true,
        ]

        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }

        let image = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
        images.setObject(image, forKey: key)
        return image
    }
}
