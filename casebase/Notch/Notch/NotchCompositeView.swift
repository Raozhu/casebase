import SwiftUI

struct NotchCompositeView: View {
    @ObservedObject var viewModel: NotchViewModel

    var body: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.white.opacity(0.02))
            )
            .padding(.top, 2)
            .padding(.horizontal, 2)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}
