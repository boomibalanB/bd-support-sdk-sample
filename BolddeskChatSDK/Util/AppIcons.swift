import SwiftUI

enum AppIcons: String, CaseIterable {
    case arrowLeft = "\u{e700}"
    case close = "\u{e701}"
    case jpg = "\u{e702}"
    case clock = "\u{e703}"
    case moreVerticalDot = "\u{e704}"
    case circle = "\u{e705}"
    case trash = "\u{e706}"
    case sendHorizontal = "\u{e707}"
    case smile = "\u{e708}"
    case mail = "\u{e709}"
    case chatFilled = "\u{e70a}"
    case warning = "\u{e70b}"
    case refresh = "\u{e70c}"
    case bolddeskLogo = "\u{e70d}"
    case doubleTick = "\u{e70e}"
    case circleCheck = "\u{e70f}"
    case alertCircle = "\u{e710}"
    case attachment1 = "\u{e711}"
    case infoCircle = "\u{e712}"
    case uploadCloud = "\u{e713}"
    case tick = "\u{e714}"
    case emoji = "\u{e715}"
    case symbols = "\u{e716}"
    case animals = "\u{e717}"
    case travelAndPlaces = "\u{e718}"
    case foodAndDrink = "\u{e719}"
    case objects = "\u{e71a}"
    case activities = "\u{e71b}"
    case chevronDown = "\u{e71c}"
    case bolddesk = "\u{e71d}"
    case downloadCloud = "\u{e71e}"
    case uploadCloud1 = "\u{e71f}"
    case chevronLeft = "\u{e720}"
    case chevronRight = "\u{e721}"
    case article = "\u{e722}"
    case search = "\u{e723}"
    case newTab = "\u{e724}"
    case home2 = "\u{e725}"
    case minimize = "\u{e726}"
    case maximize = "\u{e727}"
    case thumbsUp = "\u{e728}"
    case thumbsDown = "\u{e729}"
    case arrowNarrowUp = "\u{e72a}"
    case arrowNarrowDown = "\u{e72b}"
    case refresh01 = "\u{e72c}"
    case notificationOff = "\u{e72d}"
    case logOut = "\u{e72e}"
    case notification = "\u{e72f}"
    case chevronDoubleDown = "\u{e730}"
    case userRemove = "\u{e731}"
    case userAdd = "\u{e732}"
    case peopleAdd = "\u{e733}"
    case peopleRemove = "\u{e734}"
    case peopleEdit = "\u{e735}"
    case userEdit = "\u{e736}"
    case sendFill = "\u{e737}"
    case edit = "\u{e738}"
    case chat = "\u{e739}"
    case endChat = "\u{e73a}"
    case fileAttachment = "\u{e73b}"
    case calender = "\u{e73c}"
    case dateTime = "\u{e73d}"
    case download = "\u{e73e}"
    case send = "\u{e73f}"
    case copy = "\u{e740}"
    case camera = "\u{e741}"
    case imageFailed = "\u{e742}"
    case arrowUpLeft = "\u{e743}"
    case newConversation = "\u{e76b}"
    case circleHelpFill = "\u{e76c}"
    case helpCircle = "\u{e763}"
    case folder = "\u{e76d}"

    
    var unicode: String {
        return rawValue
    }
}

struct AppIcon: View {
    let icon: AppIcons
    var size: CGFloat
    var color: Color

    init(icon: AppIcons, size: CGFloat = 16, color: Color = Color.textTertiary) {
        self.icon = icon
        self.size = size
        self.color = color
    }

    /// Convenience constructor for app bar icons
//    static func appbar(_ icon: AppIcons, size: CGFloat = 24) -> AppIcon {
//        return AppIcon(icon: icon, size: size, color: Color.isDarkColor(.primaryColor) ? .backgroundPrimary : .textSecondaryColor)
//    }

    var body: some View {
        Text(icon.unicode)
            .font(.custom("Chat Widget", size: size))
            .foregroundColor(color)
    }
}

struct AllIconsGridView: View {
    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(AppIcons.allCases, id: \.self) { icon in
                    VStack {
                        AppIcon(icon: icon)
                            .padding(.bottom, 2)
                        Text(String(describing: icon))
                            .font(.caption)
                            .italic()
                            .bold()
                            .foregroundColor(Color.textTertiary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .padding(4)
                }
            }
            .padding()
        }
    }
}


#Preview {
    ///This is how you should use App Icons
    // AppIcon(icon: .ticket)
    ///You can also specify size and color
    ///
//    AppIcon(icon: .chevronDown)
    AllIconsGridView()
}
            
