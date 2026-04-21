import SwiftUI

/// A SwiftUI view that automatically detects and renders URLs within a block of text.
struct AutoLinkText: View {
    // The full input text to be rendered
    let text: String
    // Color to apply to both links and plain text
    let color: Color

    var body: some View {
        if #available(iOS 15.0, *) {
            // Use NSAttributedString for iOS 15 and above
            Text(attributedString)
                .multilineTextAlignment(.leading)
        } else {
            // Fallback to original flow for iOS 14 and below
            HStack(spacing: 0) {
                ForEach(parsedTextParts, id: \.self) { part in
                    if part.isLink, let url = URL(string: part.text) {
                        // If the part is a link, render it as tappable and underlined
                        Text(part.text)
                            .foregroundColor(color == .textSecondary ? Color.textBrandSecondary : color)
                            .underline()
                            .font(FontFamily.customFont(size: FontSize.medium, weight: .medium))
                            .onTapGesture {
                                UIApplication.shared.open(url) // Open link in Safari
                            }
                    } else {
                        // Render plain text normally
                        Text(part.text)
                            .foregroundColor(color)
                            .font(FontFamily.customFont(size: FontSize.medium, weight: .regular))
                    }
                }
            }
            .multilineTextAlignment(.leading)
        }
    }

    /// Splits the input text into parts: links and non-links
    private var parsedTextParts: [TextPart] {
        // Regular expression to match URLs (http, https, ftp)
        guard let regex = try? NSRegularExpression(pattern: AppConstant.urlRegex, options: []) else {
            // If regex fails, return the whole text as plain
            return [TextPart(text: text, isLink: false)]
        }

        let nsText = text as NSString
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsText.length))

        var parts: [TextPart] = []
        var currentIndex = 0

        for match in matches {
            let matchRange = match.range

            // Add plain text before the link
            if matchRange.location > currentIndex {
                let plainText = nsText.substring(with: NSRange(location: currentIndex, length: matchRange.location - currentIndex))
                parts.append(TextPart(text: plainText, isLink: false))
            }

            // Add the detected link
            let linkText = nsText.substring(with: matchRange)
            parts.append(TextPart(text: linkText, isLink: true))

            // Move the index past the current match
            currentIndex = matchRange.location + matchRange.length
        }

        // Add any remaining plain text after the last link
        if currentIndex < nsText.length {
            let remainingText = nsText.substring(from: currentIndex)
            parts.append(TextPart(text: remainingText, isLink: false))
        }

        return parts
    }

    /// Creates an NSAttributedString for iOS 15+ with tappable links
    @available(iOS 15.0, *)
    private var attributedString: AttributedString {
        // Initialize AttributedString with the provided font and color
        var attributedString = AttributedString(text)
        attributedString.font = FontFamily.customFont(size: FontSize.medium, weight: .regular)
        attributedString.foregroundColor = color

        let nsText = text as NSString

        // Regular expression to match URLs
        guard let regex = try? NSRegularExpression(pattern: AppConstant.urlRegex, options: []) else {
            return attributedString
        }

        let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsText.length))

        // Apply link attributes to detected URLs
        for match in matches {
            let range = match.range
            let linkText = nsText.substring(with: range)
            if let url = URL(string: linkText) {
                let swiftUIRange = Range<AttributedString.Index>(NSRange(location: range.location, length: range.length), in: attributedString)!
                attributedString[swiftUIRange].link = url
                attributedString[swiftUIRange].underlineStyle = .single
                // Explicitly reapply font and color to links to ensure consistency
                attributedString[swiftUIRange].font = FontFamily.customFont(size: FontSize.medium, weight: .medium)
                attributedString[swiftUIRange].foregroundColor = color == .textSecondary ? Color.textBrandSecondary : color
            }
        }

        return attributedString
    }

    /// Represents a segment of text, either a link or plain text
    private struct TextPart: Hashable {
        let text: String
        let isLink: Bool
    }
}
