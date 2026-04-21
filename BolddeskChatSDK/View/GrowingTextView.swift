import SwiftUI

struct GrowingTextView: UIViewRepresentable {
    @Binding var text: String
    let font: UIFont
    let minHeight: CGFloat
    let maxHeight: CGFloat
    var placeholder: String
    var onHeightChange: ((CGFloat) -> Void)? = nil

    init(
        text: Binding<String>,
        font: UIFont = .systemFont(ofSize: 16),
        placeholder: String = ResourceManager.localized("message_input_placeholder"),
        onHeightChange: ((CGFloat) -> Void)? = nil
    ) {
        self._text = text
        self.font = font
        self.minHeight = font.lineHeight + 8   // 1 line + padding
        self.maxHeight = font.lineHeight * 5 + 8 // 5 lines + padding
        self.placeholder = placeholder
        self.onHeightChange = onHeightChange
    }

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.font = font
        textView.isScrollEnabled = false
        textView.backgroundColor = .clear
        textView.textContainerInset = UIEdgeInsets(top: 4, left: 0, bottom: 4, right: 0)
        textView.textContainer.lineBreakMode = .byWordWrapping
        textView.textContainer.lineFragmentPadding = 0
        textView.textContainer.widthTracksTextView = true
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textView.autocorrectionType = .no
        textView.autocapitalizationType = .none

        // ✅ ADD THIS — Done button toolbar
        let toolbar = UIToolbar()
        toolbar.sizeToFit()

        let flexSpace = UIBarButtonItem(
            barButtonSystemItem: .flexibleSpace,
            target: nil,
            action: nil
        )

        let doneButton = UIBarButtonItem(
            title: "Done",
            style: .plain,
            target: context.coordinator,
            action: #selector(Coordinator.doneTapped)
        )

        toolbar.items = [flexSpace, doneButton]
        textView.inputAccessoryView = toolbar

        // Placeholder (unchanged)
        let pl = context.coordinator.placeholderLabel
        pl.text = placeholder
        pl.font = font
        pl.textColor = UIColor(Color.textPlaceholder)
        pl.numberOfLines = 0
        pl.translatesAutoresizingMaskIntoConstraints = false
        textView.addSubview(pl)

        context.coordinator.leadingConstraint = pl.leadingAnchor.constraint(
            equalTo: textView.leadingAnchor,
            constant: 5 + textView.textContainerInset.left
        )
        context.coordinator.topConstraint = pl.topAnchor.constraint(
            equalTo: textView.topAnchor,
            constant: textView.textContainerInset.top
        )
        context.coordinator.trailingConstraint = pl.trailingAnchor.constraint(
            lessThanOrEqualTo: textView.trailingAnchor,
            constant: -(5 + textView.textContainerInset.right)
        )

        NSLayoutConstraint.activate([
            context.coordinator.leadingConstraint!,
            context.coordinator.topConstraint!,
            context.coordinator.trailingConstraint!
        ])

        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }
        uiView.font = font

        // Update placeholder
        context.coordinator.placeholderLabel.isHidden = !text.isEmpty
        // Update constraints to follow inset/width changes safely (prevents 0-width glitches)
        context.coordinator.topConstraint?.constant = uiView.textContainerInset.top
        context.coordinator.leadingConstraint?.constant = 5 + uiView.textContainerInset.left
        context.coordinator.trailingConstraint?.constant = -(5 + uiView.textContainerInset.right)
        uiView.setNeedsLayout()

        // ✅ Sync textContainer width with SwiftUI layout
        let width = uiView.bounds.width
        if width > 0 {
            uiView.textContainer.size = CGSize(width: width, height: .greatestFiniteMagnitude)
        }

        // Measure height
        let fittingHeight = uiView.sizeThatFits(
            CGSize(width: width, height: .greatestFiniteMagnitude)
        ).height
        let clampedHeight = min(max(fittingHeight, minHeight), maxHeight)

        uiView.isScrollEnabled = fittingHeight > maxHeight

        DispatchQueue.main.async {
            onHeightChange?(clampedHeight)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UITextViewDelegate {
        var parent: GrowingTextView
        let placeholderLabel = UILabel()
        var topConstraint: NSLayoutConstraint?
        var leadingConstraint: NSLayoutConstraint?
        var trailingConstraint: NSLayoutConstraint?

        init(_ parent: GrowingTextView) {
            self.parent = parent
        }

        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text
            placeholderLabel.isHidden = !textView.text.isEmpty
        }

        // ✅ Done button action
        @objc func doneTapped() {
            UIApplication.shared.sendAction(
                #selector(UIResponder.resignFirstResponder),
                to: nil,
                from: nil,
                for: nil
            )
        }
    }
}

struct ChatInput: View {
    @State private var text: String = ""
    @State private var dynamicHeight: CGFloat = 0

    var body: some View {
        GrowingTextView(
            text: $text,
            font: .systemFont(ofSize: 17),
            placeholder: "Type your message..."
        ) { newHeight in
            dynamicHeight = newHeight
        }
        .frame(height: dynamicHeight)
        .frame(maxWidth: .infinity) // ✅ take all available width
        .padding(8)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
        .padding(.horizontal, 6)
    }
}

#Preview {
    ChatInput()
}
