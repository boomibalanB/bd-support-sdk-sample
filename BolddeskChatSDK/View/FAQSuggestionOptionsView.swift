import SwiftUI

struct FAQSuggestionOptionsView: View {
    let suggestions: [SuggestionOption]
    let onOptionSelected: (SuggestionOption) -> Void

    var body: some View {
        VStack(alignment: .trailing, spacing: 12) {
            ForEach(suggestions, id: \.id) { suggestion in
                HStack {
                    Spacer()
                    Button {
                        onOptionSelected(suggestion)
                    } label: {
                        HStack(spacing: 8) {
                            AppIcon(icon: .arrowUpLeft, color: Color.textSecondary)
                            Text(suggestion.text)
                                .font(FontFamily.customFont(size: FontSize.medium, weight: .medium))
                                .foregroundColor(Color.textSecondary)
                                .multilineTextAlignment(.leading)
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.bgSecondary)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(Color.borderSecondary, lineWidth: 1)
                        )
                    }
                    .frame(minHeight: 32)
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.trailing, 12)
    }
}
