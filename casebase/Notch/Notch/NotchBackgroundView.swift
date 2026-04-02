import SwiftUI

struct NotchBackgroundView: View {
    @ObservedObject var viewModel: NotchViewModel

    var body: some View {
        Rectangle()
            .foregroundStyle(.black)
            .mask(backgroundMask)
            .frame(
                width: viewModel.surfaceSize.width + viewModel.cornerRadius * 2,
                height: viewModel.surfaceSize.height
            )
            .shadow(color: .black.opacity(viewModel.isExpanded ? 1 : 0), radius: 16)
    }

    private var backgroundMask: some View {
        Rectangle()
            .foregroundStyle(.black)
            .frame(width: viewModel.surfaceSize.width, height: viewModel.surfaceSize.height)
            .clipShape(
                .rect(
                    bottomLeadingRadius: viewModel.cornerRadius,
                    bottomTrailingRadius: viewModel.cornerRadius
                )
            )
            .overlay(alignment: .topLeading) {
                topLeftCutout
                    .offset(x: -viewModel.cornerRadius - viewModel.contentPadding + 0.5, y: -0.5)
            }
            .overlay(alignment: .topTrailing) {
                topRightCutout
                    .offset(x: viewModel.cornerRadius + viewModel.contentPadding - 0.5, y: -0.5)
            }
    }

    private var topLeftCutout: some View {
        ZStack(alignment: .topTrailing) {
            Rectangle()
                .frame(width: viewModel.cornerRadius, height: viewModel.cornerRadius)
                .foregroundStyle(.black)
            Rectangle()
                .clipShape(.rect(topTrailingRadius: viewModel.cornerRadius))
                .foregroundStyle(.white)
                .frame(
                    width: viewModel.cornerRadius + viewModel.contentPadding,
                    height: viewModel.cornerRadius + viewModel.contentPadding
                )
                .blendMode(.destinationOut)
        }
        .compositingGroup()
    }

    private var topRightCutout: some View {
        ZStack(alignment: .topLeading) {
            Rectangle()
                .frame(width: viewModel.cornerRadius, height: viewModel.cornerRadius)
                .foregroundStyle(.black)
            Rectangle()
                .clipShape(.rect(topLeadingRadius: viewModel.cornerRadius))
                .foregroundStyle(.white)
                .frame(
                    width: viewModel.cornerRadius + viewModel.contentPadding,
                    height: viewModel.cornerRadius + viewModel.contentPadding
                )
                .blendMode(.destinationOut)
        }
        .compositingGroup()
    }
}
