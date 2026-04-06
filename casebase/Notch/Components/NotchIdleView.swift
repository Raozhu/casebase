import SwiftUI

struct NotchIdleView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(CasebasePromptCatalog.ui.idleTitle)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)

            Text(CasebasePromptCatalog.ui.idleDetail)
                .font(.system(size: 13))
                .foregroundStyle(Color.white.opacity(0.74))
                .lineLimit(4)

            Spacer(minLength: 0)

            Text(CasebasePromptCatalog.ui.idleHint)
                .font(.system(size: 11))
                .foregroundStyle(Color.white.opacity(0.54))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
