import SwiftUI

struct OptionChipForStickyButton: View {
    let text: String
    let onTap: () -> Void
    let isDisabled: Bool
    let isSticky: Bool

    init(
        text: String,
        onTap: @escaping () -> Void,
        isDisabled: Bool = false,
        isSticky: Bool = false
    ) {
        self.text = text
        self.onTap = onTap
        self.isDisabled = isDisabled
        self.isSticky = isSticky
    }

    var body: some View {
        return Button(action: onTap) {
            Text(text)
                .font(
                    FontFamily.customFont(
                        size: FontSize.medium,
                        weight: .medium
                    )
                )
                .foregroundColor(Color.stickyButtonTextColor)
                .multilineTextAlignment(.leading)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(Color.stickyButtonColor)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .stroke(
                            isDisabled
                                ? Color.stickyButtonColor.opacity(0.6)
                                : Color.stickyButtonColor,
                            lineWidth: 1
                        )
                )
        }
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.6 : 1.0)
    }
}

struct OptionChipForSuggestion: View {
    let text: String
    let onTap: () -> Void
    let isDisabled: Bool
    let isSticky: Bool

    init(
        text: String,
        onTap: @escaping () -> Void,
        isDisabled: Bool = false,
        isSticky: Bool = false
    ) {
        self.text = text
        self.onTap = onTap
        self.isDisabled = isDisabled
        self.isSticky = isSticky
    }

    var body: some View {
        return Button(action: onTap) {
            Text(text)
                .font(
                    FontFamily.customFont(
                        size: FontSize.medium,
                        weight: .medium
                    )
                )
                .foregroundColor(
                    isDisabled ? Color.fgDisabled : Color.actionColorPrimaryBg
                )
                .lineLimit(1)
                .padding(.horizontal, 12)  // 👈 more pill spacing
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .fill(
                            isDisabled
                                ? Color.fgDisabled.opacity(0.2)
                                : Color.actionColorPrimaryBg.opacity(0.2)
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .stroke(
                            isDisabled
                                ? Color.fgDisabled.opacity(0.4)
                                : Color.actionColorPrimaryBorder.opacity(0.4),
                            lineWidth: 1
                        )
                )

        }
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.6 : 1.0)
    }
}

struct FormOptionView: View {
    let options: [DropdownItemModel]
    let onOptionTap: (DropdownItemModel) -> Void
    let isDisabled: Bool

    var body: some View {
        FlexibleView(data: options, spacing: 12, alignment: .leading) {
            option in
            OptionChipForSuggestion(
                text: option.displayName,
                onTap: {
                    onOptionTap(option)
                },
                isDisabled: isDisabled
            )
        }
        .padding(.top, 8)
    }
}

struct SuggestionOptionsView: View {
    let suggestions: [SuggestionOption]
    let onSuggestionTap: (SuggestionOption) -> Void

    var body: some View {
        FlexibleView(data: suggestions, spacing: 8, alignment: .leading) {
            suggestion in
            OptionChipForSuggestion(text: suggestion.text) {
                onSuggestionTap(suggestion)
            }
        }
//        .padding(.top, 4)
    }
}

// MARK: - Sticky Buttons
struct StickyButtonsContainer: View {
    let buttons: [StickyButton]
    var isDisabled: Bool = false
    let onTap: (StickyButton) -> Void

    var body: some View {
        FlexibleView(data: buttons, spacing: 4, alignment: .leading) { btn in
            OptionChipForStickyButton(
                text: btn.text,
                onTap: { onTap(btn) },
                isDisabled: isDisabled,
                isSticky: true
            )
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
}

/// A view that arranges its children in a flow-like manner,
/// wrapping them to a new line when they don't fit horizontally.
struct FlexibleView<Data: Collection, Content: View>: View
where Data.Element: Hashable {
    let data: Data
    let spacing: CGFloat
    let alignment: HorizontalAlignment
    let content: (Data.Element) -> Content

    @State private var elementSizes: [Data.Element: CGSize] = [:]
    @State private var availableWidth: CGFloat = 0

    var body: some View {
        VStack(alignment: alignment, spacing: spacing) {
            ForEach(computeRows(in: max(availableWidth, 1)), id: \.self) {
                rowElements in
                HStack(spacing: spacing) {
                    ForEach(rowElements, id: \.self) { element in
                        content(element)
                            .fixedSize(horizontal: false, vertical: true)
                            .readSize { size in
                                elementSizes[element] = size
                            }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)  // left align each row
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .readSize { size in
            if abs(self.availableWidth - size.width) > 0.5 {
                self.availableWidth = size.width
            }
        }
    }

    /// Computes rows that fit within the available width
    private func computeRows(in availableWidth: CGFloat) -> [[Data.Element]] {
        var rows: [[Data.Element]] = [[]]
        var currentRow = 0
        var remainingWidth = availableWidth

        for element in data {
            let elementSize = elementSizes[
                element,
                default: CGSize(width: availableWidth, height: 1)
            ]

            if remainingWidth - (elementSize.width + spacing) >= 0 {
                rows[currentRow].append(element)
            } else {
                currentRow += 1
                rows.append([element])  // add new row with this element
                remainingWidth = availableWidth
            }

            remainingWidth -= (elementSize.width + spacing)
        }
        return rows
    }
}

/// A helper view extension to read the size of a view.
extension View {
    func readSize(onChange: @escaping (CGSize) -> Void) -> some View {
        background(
            GeometryReader { geometryProxy in
                Color.clear
                    .preference(
                        key: SizePreferenceKey.self,
                        value: geometryProxy.size
                    )
            }
        )
        .onPreferenceChange(SizePreferenceKey.self, perform: onChange)
    }
}

struct SizePreferenceKey: PreferenceKey {
    static var defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {}
}
