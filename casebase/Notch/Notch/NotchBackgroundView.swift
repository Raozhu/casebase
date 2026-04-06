import SwiftUI

struct NotchBackgroundView: View {
    @ObservedObject var viewModel: NotchViewModel

    var body: some View {
        Rectangle()
            .foregroundStyle(.black)
            .mask(backgroundMask)
            .overlay(alignment: .top) {
                if viewModel.captureSinkProgress > 0.001 {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.12 * viewModel.captureSinkProgress))
                            .frame(
                                width: 22 + (76 * viewModel.captureSinkProgress),
                                height: 22 + (76 * viewModel.captureSinkProgress)
                            )
                            .blur(radius: 14 - (6 * viewModel.captureSinkProgress))

                        Circle()
                            .strokeBorder(Color.white.opacity(0.24 * viewModel.captureSinkProgress), lineWidth: 1.4)
                            .frame(
                                width: 18 + (54 * viewModel.captureSinkProgress),
                                height: 18 + (54 * viewModel.captureSinkProgress)
                            )
                            .scaleEffect(1 + (0.14 * viewModel.captureSinkProgress))

                        Capsule(style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.24 * viewModel.captureSinkProgress),
                                        Color.white.opacity(0.04)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(
                                width: 28 + (72 * viewModel.captureSinkProgress),
                                height: 8 + (18 * viewModel.captureSinkProgress)
                            )
                            .blur(radius: 8)
                    }
                    .offset(y: 8 + (2 * viewModel.captureSinkProgress))
                    .blendMode(.screen)
                }
            }
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
