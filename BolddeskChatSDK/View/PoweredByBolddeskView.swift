import SwiftUI

struct PoweredByBolddeskView: View {
    var body: some View {
        Link(destination: URL(string:   AppConstant.bolddeskURL)!) {
            HStack {
                Text(ResourceManager.localized("powered_by"))
                    .font(FontFamily.customFont(size: 12, weight: .regular))
                    .foregroundColor(.textQuarterary)
                AppIcon(icon: .bolddeskLogo, size: 14, color: Color.fgQuarterary)
                    .padding(.horizontal, -2)
                AppIcon(icon: .bolddesk, size: 50, color: Color.fgQuarterary)
            }
        }
        .padding(.vertical, -8)
    }
}

#Preview {
    PoweredByBolddeskView()
}
