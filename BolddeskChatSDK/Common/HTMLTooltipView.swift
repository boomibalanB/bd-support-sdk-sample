import SwiftUI
import UIKit
import SwiftUI

struct HTMLTooltipView: View {
    
    let html: String
    let tooltipMessage: String?
    
    @State private var webHeight: CGFloat = 1
    @State private var tooltipDismissTask: Task<Void, Never>? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            
            WebView(
                html: html,
                contentHeight: $webHeight,
                shouldAddIcon: (tooltipMessage != nil && !(tooltipMessage?.isEmpty ?? true))
            ) { point in
                
                guard let message = tooltipMessage, !message.isEmpty else {
                    return
                }
                
                tooltipDismissTask?.cancel()
                tooltipDismissTask = nil
                
                SwiftTooltip.dismissAll()
                
                SwiftTooltip.show(
                    title: nil,
                    text: message,
                    at: point,
                    pointerPosition: .bottomCenter,
                    config: {
                        let c = SwiftTooltip.Configuration()
                        c.pointerSize = .zero
                        c.textColor = UIColor(Color.tooltipBackground)
                        c.color = UIColor(Color.tooltipText)
                        c.dismissBehavior = .dismissOnTapOutside
                        c.maxWidth = UIScreen.main.bounds.width - 40
                        c.clickThroughBehavior = .allowed
                        return c
                    }(),
                    onDismiss: {
                        tooltipDismissTask?.cancel()
                        tooltipDismissTask = nil
                    }
                )
                
                tooltipDismissTask = Task {
                    do {
                        try await Task.sleep(nanoseconds: 2_000_000_000)
                        await MainActor.run {
                            SwiftTooltip.dismissAll()
                        }
                    } catch {}
                    
                    await MainActor.run {
                        tooltipDismissTask = nil
                    }
                }
            }
            .frame(height: webHeight)
        }
        .onDisappear {
            tooltipDismissTask?.cancel()
            SwiftTooltip.dismissAll()
        }
    }
}

//
//  SwiftTooltip.swift
//  SwiftTooltip
//
//  Created by Quan on 27/10/25.
//


private var _tooltipViews: [SwiftTooltip.TooltipView] = []

 struct SwiftTooltip {
     enum PointerPosition {
        case topCenter
        case topLeft
        case topRight
        case bottomCenter
        case bottomLeft
        case bottomRight
        case left
        case right
    }
    
    enum DismissBehavior {
        case dismissOnTapEverywhere
        case dismissOnTapOutside
        case dismissOnTapTargetView
        case dismissManually
    }
    
    enum ClickThroughBehavior {
        case allowed
        case blocked
    }
    
    enum TooltipAnimation {
        case none
        case movingLinear(distance: CGFloat = 10, duration: TimeInterval = 0.5)
        case movingSpring(distance: CGFloat = 10, duration: TimeInterval = 0.5)
    }

    enum PointerStyle {
        case straight
        case curved
    }
    
    class Configuration {
        static var global = Configuration()
        
        // Text styling
         var textColor: UIColor
         var titleColor: UIColor
         var titleAlignment: NSTextAlignment
         var textAlignment: NSTextAlignment
         var textFont: UIFont
         var titleFont: UIFont

        // Bubble styling
         var color: UIColor
         var backgroundColor: UIColor // overlay color
         var cornerRadius: CGFloat
         var horizontalPadding: CGFloat
         var verticalPadding: CGFloat
         var verticalSpacing: CGFloat
        // Max bubble width; 0 means use screen width - 32
         var maxWidth: CGFloat

        // Shadow styling
         var shadowColor: UIColor
         var shadowOffset: CGSize
         var shadowOpacity: Float
         var shadowRadius: CGFloat

        // Pointer styling
         var pointerSize: CGSize
        // Padding from pointer to the left/right edge if the pointer position is not center
         var pointerHorizontalPadding: CGFloat
         var pointerStyle: PointerStyle

        // Dismiss behavior
         var dismissBehavior: DismissBehavior
        
        // Click behavior
         var clickThroughBehavior: ClickThroughBehavior
        
        // Animation configuration
         var appearAnimationDuration: TimeInterval
         var disappearAnimationDuration: TimeInterval
         var animation: TooltipAnimation
        
         init(
            textColor: UIColor = .label,
            titleColor: UIColor = .label,
            titleAlignment: NSTextAlignment = .center,
            textAlignment: NSTextAlignment = .center,
            textFont: UIFont = .systemFont(ofSize: 15, weight: .regular),
            titleFont: UIFont = .systemFont(ofSize: 17, weight: .bold),
            color: UIColor = .systemBackground,
            backgroundColor: UIColor = .clear,
            cornerRadius: CGFloat = 8,
            horizontalPadding: CGFloat = 12,
            verticalPadding: CGFloat = 8,
            verticalSpacing: CGFloat = 2,
            maxWidth: CGFloat = 280,
            shadowColor: UIColor = .label,
            shadowOffset: CGSize = .init(width: 0, height: 15),
            shadowOpacity: Float = 0.2,
            shadowRadius: CGFloat = 30,
            pointerSize: CGSize = .init(width: 14, height: 8),
            pointerHorizontalPadding: CGFloat = 12,
            pointerStyle: PointerStyle = .straight,
            dismissBehavior: DismissBehavior = .dismissOnTapTargetView,
            clickThroughBehavior: ClickThroughBehavior = .allowed,
            appearAnimationDuration: TimeInterval = 0.25,
            disappearAnimationDuration: TimeInterval = 0.25,
            animation: TooltipAnimation = .none
        ) {
            self.textColor = textColor
            self.titleColor = titleColor
            self.titleAlignment = titleAlignment
            self.textAlignment = textAlignment
            self.textFont = textFont
            self.titleFont = titleFont
            self.color = color
            self.backgroundColor = backgroundColor
            self.cornerRadius = cornerRadius
            self.horizontalPadding = horizontalPadding
            self.verticalPadding = verticalPadding
            self.verticalSpacing = verticalSpacing
            self.maxWidth = maxWidth
            self.shadowColor = shadowColor
            self.shadowOffset = shadowOffset
            self.shadowOpacity = shadowOpacity
            self.shadowRadius = shadowRadius
            self.pointerSize = pointerSize
            self.pointerHorizontalPadding = pointerHorizontalPadding
            self.pointerStyle = pointerStyle
            self.dismissBehavior = dismissBehavior
            self.clickThroughBehavior = clickThroughBehavior
            self.appearAnimationDuration = appearAnimationDuration
            self.disappearAnimationDuration = disappearAnimationDuration
            self.animation = animation
        }
    }
    
    @discardableResult
     static func show(
        title: String? = nil,
        text: String,
        in parentView: UIView? = nil,
        to view: UIView? = nil,
        at point: CGPoint? = nil,
        pointerPosition: PointerPosition = .bottomCenter,
        pointerOffset: CGPoint = .init(x: 0, y: 0),
        delay: TimeInterval = 0,
        id: String? = nil,
        config: Configuration? = nil,
        onTapTarget: (() -> Void)? = nil,
        onDismiss: (() -> Void)? = nil
    ) -> TooltipView {
        guard let parentView = parentView ?? self.window else { return .init(frame: .zero) }
        let tooltipView = TooltipView(frame: parentView.bounds)
        tooltipView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        tooltipView.config = config ?? .global
        tooltipView.title = title
        tooltipView.text = text
        tooltipView.offset = pointerOffset
        tooltipView.pointerPosition = pointerPosition
        tooltipView.id = id
        if let view {
            tooltipView.targetViewFrame = view.convert(view.bounds, to: parentView)
            tooltipView.hasTargetView = true
        } else {
            tooltipView.targetViewFrame = .init(origin: point ?? parentView.center, size: .zero)
        }
        tooltipView.onDismiss = onDismiss
        tooltipView.onTapTarget = onTapTarget
        tooltipView.setUp()
        parentView.addSubview(tooltipView)
        tooltipView.appear(delay: delay)
        _tooltipViews.append(tooltipView)
        return tooltipView
    }
    
     static func configure(_ configuration: Configuration) {
        Configuration.global = configuration
    }
    
     static func dismissAll() {
        _tooltipViews.forEach { $0.dismiss() }
    }
    
     static func dismiss(id: String) {
        _tooltipViews.filter { $0.id == id }
            .forEach { $0.dismiss() }
    }
}

extension SwiftTooltip {
     final class TooltipView: UIView, UIGestureRecognizerDelegate {
         var id: String?
         var config: Configuration = .init()
         var title: String?
         var text: String = ""
         var offset: CGPoint = .zero
         var pointerPosition: PointerPosition = .bottomCenter
         var targetViewFrame: CGRect = .zero
         var onDismiss: (() -> Void)?
         var onTapTarget: (() -> Void)?
         var hasTargetView: Bool = false

        private var bubbleView: UIView!
        private var titleLabel: UILabel!
        private var messageLabel: UILabel!
        private weak var pointerView: PointerView?
        private var externalTapGR: UITapGestureRecognizer?

         func setUp() {
            backgroundColor = config.backgroundColor
            let tapGR = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
            tapGR.cancelsTouchesInView = (config.clickThroughBehavior == .blocked)
            tapGR.delaysTouchesBegan = false
            tapGR.delegate = self
            addGestureRecognizer(tapGR)

            if config.clickThroughBehavior == .allowed, config.dismissBehavior != .dismissManually {
                // Add an external recognizer on the key window to listen for taps
                // while allowing touches to pass through.
                if let win = SwiftTooltip.window {
                    let ext = UITapGestureRecognizer(target: self, action: #selector(handleExternalTap(_:)))
                    ext.cancelsTouchesInView = false
                    ext.delaysTouchesBegan = false
                    ext.delegate = self
                    win.addGestureRecognizer(ext)
                    externalTapGR = ext
                }
            }

            // Effective maximum bubble width
            let maxBubbleWidth = max(config.maxWidth, 0)

            // Bubble width based on text content, capped at maxBubbleWidth
            let singleLineTextWidth = max(text._singleLineSize(withFont: config.textFont).width, title?._singleLineSize(withFont: config.titleFont).width ?? 0)
            let bubbleWidth = min(maxBubbleWidth, ceil(singleLineTextWidth + config.horizontalPadding * 2))

            // Measure title and text heights with wrapping within content width
            let contentWidth = bubbleWidth - config.horizontalPadding * 2
            let hasTitle = !(title ?? "").isEmpty
            let titleSize = hasTitle ? (title ?? "")._boundedSize(withFont: config.titleFont, maxWidth: contentWidth) : .zero
            let textSize = text._boundedSize(withFont: config.textFont, maxWidth: contentWidth)

            let contentHeight = (hasTitle ? titleSize.height : 0)
                + (hasTitle ? config.verticalSpacing : 0)
                + textSize.height

            let bubbleSize = CGSize(
                width: bubbleWidth,
                height: contentHeight + config.verticalPadding * 2
            )

            let bubbleView = UIView(frame: .init(origin: .zero, size: bubbleSize))

            // Pointer setup based on position
            let pointerSize = config.pointerSize
            let pointerPadding = config.pointerHorizontalPadding
            let pointerView: PointerView
            var offsetX: CGFloat = 0
            let offsetY: CGFloat
            switch pointerPosition {
            case .topLeft:
                pointerView = .init(frame: .init(x: pointerPadding, y: -pointerSize.height, width: pointerSize.width, height: pointerSize.height), type: .up, style: config.pointerStyle, color: config.color)
                offsetX = bubbleView.frame.width / 2 - pointerPadding - pointerSize.width / 2
                offsetY = bubbleView.bounds.height / 2 + pointerSize.height + targetViewFrame.height / 2 + offset.y
            case .topCenter:
                pointerView = .init(frame: .init(x: bubbleView.bounds.width / 2 - pointerSize.width / 2, y: -pointerSize.height, width: pointerSize.width, height: pointerSize.height), type: .up, style: config.pointerStyle, color: config.color)
                offsetX = 0
                offsetY = bubbleView.bounds.height / 2 + pointerSize.height + targetViewFrame.height / 2 + offset.y
            case .topRight:
                pointerView = .init(frame: .init(x: bubbleView.bounds.width - pointerPadding - pointerSize.width, y: -pointerSize.height, width: pointerSize.width, height: pointerSize.height), type: .up, style: config.pointerStyle, color: config.color)
                offsetX = -(bubbleView.frame.width / 2 - pointerPadding - pointerSize.width / 2)
                offsetY = bubbleView.bounds.height / 2 + pointerSize.height + targetViewFrame.height / 2 + offset.y
            case .bottomLeft:
                pointerView = .init(frame: .init(x: pointerPadding, y: bubbleView.bounds.height, width: pointerSize.width, height: pointerSize.height), type: .down, style: config.pointerStyle, color: config.color)
                offsetX = bubbleView.frame.width / 2 - pointerPadding - pointerSize.width / 2
                offsetY = -bubbleView.bounds.height / 2 - pointerSize.height - targetViewFrame.height / 2 - offset.y
            case .bottomCenter:
                pointerView = .init(frame: .init(x: bubbleView.bounds.width / 2 - pointerSize.width / 2, y: bubbleView.bounds.height, width: pointerSize.width, height: pointerSize.height), type: .down, style: config.pointerStyle, color: config.color)
                offsetX = 0
                offsetY = -bubbleView.bounds.height / 2 - pointerSize.height - targetViewFrame.height / 2 - offset.y
            case .bottomRight:
                pointerView = .init(frame: .init(x: bubbleView.bounds.width - pointerPadding - pointerSize.width, y: bubbleView.bounds.height, width: pointerSize.width, height: pointerSize.height), type: .down, style: config.pointerStyle, color: config.color)
                offsetX = -(bubbleView.frame.width / 2 - pointerPadding - pointerSize.width / 2)
                offsetY = -bubbleView.bounds.height / 2 - pointerSize.height - targetViewFrame.height / 2 - offset.y
            case .left:
                let pW = pointerSize.height
                let pH = pointerSize.width
                pointerView = .init(frame: .init(x: -pW, y: bubbleView.bounds.height / 2 - pH / 2, width: pW, height: pH), type: .left, style: config.pointerStyle, color: config.color)
                offsetX = bubbleView.bounds.width / 2 + pW + targetViewFrame.width / 2 + offset.x
                offsetY = offset.y
            case .right:
                let pW = pointerSize.height
                let pH = pointerSize.width
                pointerView = .init(frame: .init(x: bubbleView.bounds.width, y: bubbleView.bounds.height / 2 - pH / 2, width: pW, height: pH), type: .right, style: config.pointerStyle, color: config.color)
                offsetX = -(bubbleView.bounds.width / 2 + pW + targetViewFrame.width / 2 + offset.x)
                offsetY = offset.y
            }

            bubbleView.center = .init(
                x: targetViewFrame.midX + offsetX,
                y: targetViewFrame.midY + offsetY
            )

            // Keep bubble within screen bounds with small margins
            let margin: CGFloat = 8
            var frame = bubbleView.frame
            if frame.minX < margin { frame.origin.x = margin }
            if frame.maxX > bounds.width - margin { frame.origin.x = bounds.width - margin - frame.width }
            if frame.minY < margin { frame.origin.y = margin }
            if frame.maxY > bounds.height - margin { frame.origin.y = bounds.height - margin - frame.height }
            bubbleView.frame = frame

            bubbleView.backgroundColor = config.color
            bubbleView.layer.cornerRadius = config.cornerRadius
            bubbleView.layer.shadowColor = config.shadowColor.cgColor
            bubbleView.layer.shadowOffset = config.shadowOffset
            bubbleView.layer.shadowOpacity = config.shadowOpacity
            bubbleView.layer.shadowRadius = config.shadowRadius
            bubbleView.addSubview(pointerView)
            addSubview(bubbleView)
            self.bubbleView = bubbleView
            self.pointerView = pointerView

            titleLabel = UILabel(frame: .init(
                x: config.horizontalPadding,
                y: config.verticalPadding,
                width: bubbleView.bounds.width - config.horizontalPadding * 2,
                height: hasTitle ? titleSize.height : 0
            ))
            titleLabel.text = title
            titleLabel.isHidden = !hasTitle
            titleLabel.numberOfLines = 0
            titleLabel.textAlignment = config.titleAlignment
            titleLabel.font = config.titleFont
            titleLabel.textColor = config.titleColor
            bubbleView.addSubview(titleLabel)

            messageLabel = UILabel(frame: .init(
                x: config.horizontalPadding,
                y: config.verticalPadding + (hasTitle ? titleSize.height + config.verticalSpacing : 0),
                width: bubbleView.bounds.width - config.horizontalPadding * 2,
                height: textSize.height
            ))
            messageLabel.text = text
            messageLabel.numberOfLines = 0
            messageLabel.textAlignment = config.textAlignment
            messageLabel.font = config.textFont
            messageLabel.textColor = config.textColor
            bubbleView.addSubview(messageLabel)
        }

         func dismiss() {
            // Stop continuous animation before dismissing
            stopContinuousAnimation()
            let duration = max(0, config.disappearAnimationDuration)
            UIView.animate(withDuration: duration, delay: 0, options: .curveEaseOut) {
                self.alpha = 0
            } completion: { _ in
                self._finalizeDismiss()
            }
        }

        private func _finalizeDismiss() {
            self.removeFromSuperview()
            self.onDismiss?()
            if let ext = self.externalTapGR, let view = ext.view {
                view.removeGestureRecognizer(ext)
            }
            _tooltipViews.removeAll { $0 === self }
        }

        func appear(delay: TimeInterval) {
            let duration = max(0, config.appearAnimationDuration)
            self.alpha = 0
            UIView.animate(withDuration: duration, delay: delay, options: .curveEaseInOut) {
                self.alpha = 1
            } completion: { _ in
                self.startContinuousAnimationIfNeeded()
            }
        }

        // Continuous animation utilities below

        private func startContinuousAnimationIfNeeded() {
            // Determine outward direction and axis based on pointer position
            let unit: CGVector
            switch pointerPosition {
            case .topLeft, .topCenter, .topRight:
                unit = CGVector(dx: 0, dy: 1)   // downwards
            case .bottomLeft, .bottomCenter, .bottomRight:
                unit = CGVector(dx: 0, dy: -1)  // upwards
            case .left:
                unit = CGVector(dx: 1, dy: 0)   // to the right
            case .right:
                unit = CGVector(dx: -1, dy: 0)  // to the left
            }

            switch config.animation {
            case .none:
                return
            case .movingLinear(let distance, let duration):
                let a = max(0, distance)
                let targetTransform = CGAffineTransform(translationX: unit.dx * a, y: unit.dy * a)
                self.bubbleView.transform = .identity
                UIView.animate(withDuration: max(0.05, duration), delay: 0, options: [.autoreverse, .repeat, .allowUserInteraction, .curveLinear]) {
                    self.bubbleView.transform = targetTransform
                }
            case .movingSpring(let distance, let duration):
                let a = max(0, distance)
                let targetTransform = CGAffineTransform(translationX: unit.dx * a, y: unit.dy * a)
                self.bubbleView.transform = .identity
                UIView.animate(withDuration: max(0.05, duration), delay: 0, usingSpringWithDamping: 0.65, initialSpringVelocity: 0.8, options: [.autoreverse, .repeat, .allowUserInteraction]) {
                    self.bubbleView.transform = targetTransform
                }
            }
        }

        private func stopContinuousAnimation() {
            bubbleView.layer.removeAllAnimations()
            bubbleView.transform = .identity
        }

        @objc private func handleTap(_ gr: UITapGestureRecognizer) {
            let location = gr.location(in: self)
            let isInsideBubble = bubbleView.frame.contains(location)
            let isOnTarget = targetViewFrame.contains(location)

            if hasTargetView && isOnTarget { onTapTarget?() }
            switch config.dismissBehavior {
            case .dismissOnTapEverywhere:
                dismiss()
            case .dismissOnTapOutside:
                if !isInsideBubble { dismiss() }
            case .dismissOnTapTargetView:
                if isOnTarget { dismiss() }
            case .dismissManually:
                break
            }
        }

        @objc private func handleExternalTap(_ gr: UITapGestureRecognizer) {
            // Convert location to our coordinate space
            guard let v = gr.view else { return }
            let pointInSelf = self.convert(gr.location(in: v), from: v)
            let isInsideBubble = bubbleView.frame.contains(pointInSelf)
            let isOnTarget = targetViewFrame.contains(pointInSelf)

            if hasTargetView && isOnTarget { onTapTarget?() }
            switch config.dismissBehavior {
            case .dismissOnTapEverywhere:
                dismiss()
            case .dismissOnTapOutside:
                if !isInsideBubble { dismiss() }
            case .dismissOnTapTargetView:
                if isOnTarget { dismiss() }
            case .dismissManually:
                break
            }
        }

        override  func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
            switch config.clickThroughBehavior {
            case .allowed:
                // Only interact with bubble itself; let other touches pass through
                return bubbleView?.frame.contains(point) ?? false
            case .blocked:
                return super.point(inside: point, with: event)
            }
        }

        // Allow our tap recognizer to coexist with others beneath
         func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            return true
        }
    }
    
    final class PointerView: UIView {
        enum PointerType {
            case up
            case down
            case left
            case right
        }
        
        private var path: UIBezierPath!
        private var color: UIColor = .black

        init(frame: CGRect, type: PointerType, style: PointerStyle, color: UIColor) {
            super.init(frame: frame)
            backgroundColor = .clear
            self.color = color
            let w = frame.width, h = frame.height
            let r: CGFloat = min(w, h) * 0.4 // tip rounding depth
            switch (type, style) {
            case (.up, .straight):
                path = UIBezierPath()
                path.move(to: CGPoint(x: w/2, y: 0))
                path.addLine(to: CGPoint(x: w, y: h))
                path.addLine(to: CGPoint(x: 0, y: h))
                path.close()
            case (.down, .straight):
                path = UIBezierPath()
                path.move(to: CGPoint(x: 0, y: 0))
                path.addLine(to: CGPoint(x: w, y: 0))
                path.addLine(to: CGPoint(x: w/2, y: h))
                path.close()
            case (.right, .straight):
                path = UIBezierPath()
                path.move(to: CGPoint(x: 0, y: 0))
                path.addLine(to: CGPoint(x: w, y: h/2))
                path.addLine(to: CGPoint(x: 0, y: h))
                path.close()
            case (.left, .straight):
                path = UIBezierPath()
                path.move(to: CGPoint(x: w, y: 0))
                path.addLine(to: CGPoint(x: w, y: h))
                path.addLine(to: CGPoint(x: 0, y: h/2))
                path.close()
            case (.up, .curved):
                // Base at y=h; rounded tip near apex (w/2, 0)
                let t = h > 0 ? r / h : 0
                let L = CGPoint(x: w/2 * (1 - t), y: r)
                let R = CGPoint(x: w/2 * (1 + t), y: r)
                let apex = CGPoint(x: w/2, y: 0)
                path = UIBezierPath()
                path.move(to: CGPoint(x: 0, y: h))
                path.addLine(to: CGPoint(x: w, y: h))
                path.addLine(to: R)
                path.addQuadCurve(to: L, controlPoint: apex)
                path.addLine(to: CGPoint(x: 0, y: h))
                path.close()
            case (.down, .curved):
                // Base at y=0; rounded tip near apex (w/2, h)
                let t = h > 0 ? r / h : 0
                let L = CGPoint(x: w/2 * (1 - t), y: h - r)
                let R = CGPoint(x: w/2 * (1 + t), y: h - r)
                let apex = CGPoint(x: w/2, y: h)
                path = UIBezierPath()
                path.move(to: CGPoint(x: 0, y: 0))
                path.addLine(to: CGPoint(x: w, y: 0))
                path.addLine(to: R)
                path.addQuadCurve(to: L, controlPoint: apex)
                path.addLine(to: CGPoint(x: 0, y: 0))
                path.close()
            case (.right, .curved):
                // Base at x=0; rounded tip near apex (w, h/2)
                let t = w > 0 ? r / w : 0
                let U = CGPoint(x: w - r, y: h/2 * (1 - t))
                let D = CGPoint(x: w - r, y: h/2 * (1 + t))
                let apex = CGPoint(x: w, y: h/2)
                path = UIBezierPath()
                path.move(to: CGPoint(x: 0, y: 0))
                path.addLine(to: CGPoint(x: 0, y: h))
                path.addLine(to: D)
                path.addQuadCurve(to: U, controlPoint: apex)
                path.addLine(to: CGPoint(x: 0, y: 0))
                path.close()
            case (.left, .curved):
                // Base at x=w; rounded tip near apex (0, h/2)
                let t = w > 0 ? r / w : 0
                let U = CGPoint(x: r, y: h/2 * (1 - t))
                let D = CGPoint(x: r, y: h/2 * (1 + t))
                let apex = CGPoint(x: 0, y: h/2)
                path = UIBezierPath()
                path.move(to: CGPoint(x: w, y: 0))
                path.addLine(to: CGPoint(x: w, y: h))
                path.addLine(to: D)
                path.addQuadCurve(to: U, controlPoint: apex)
                path.addLine(to: CGPoint(x: w, y: 0))
                path.close()
            }
        }
        
        override func draw(_ rect: CGRect) {
            guard let path else { return }
            color.setFill()
            path.fill()
        }
        
        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }
}

extension SwiftTooltip {
    static var window: UIView? {
        UIApplication
            .shared
            .connectedScenes
            .flatMap { ($0 as? UIWindowScene)?.windows ?? [] }
            .first { $0.isKeyWindow }
    }
}

private extension String {
    func _boundedSize(withFont font: UIFont, maxWidth: CGFloat) -> CGSize {
        let rect = (self as NSString).boundingRect(
            with: CGSize(width: max(0, maxWidth), height: CGFloat.greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font],
            context: nil
        )
        return CGSize(width: ceil(rect.width), height: ceil(rect.height))
    }

    func _singleLineSize(withFont font: UIFont) -> CGSize {
        let size = (self as NSString).size(withAttributes: [.font: font])
        return CGSize(width: ceil(size.width), height: ceil(size.height))
    }
}

@available(iOS 13.0, *)
 extension View {
    func tooltip(
        title: String? = nil,
        text: String,
        isPresented: Binding<Bool>,
        pointerPosition: SwiftTooltip.PointerPosition = .bottomCenter,
        pointerOffset: CGPoint = .zero,
        delay: TimeInterval = 0,
        id: String? = nil,
        config: SwiftTooltip.Configuration = .init()
    ) -> some View {
        modifier(SwiftTooltipModifier(
            title: title,
            text: text,
            isPresented: isPresented,
            pointerPosition: pointerPosition,
            pointerOffset: pointerOffset,
            delay: delay,
            id: id,
            config: config
        ))
    }
}

@available(iOS 13.0, *)
private struct SwiftTooltipModifier: ViewModifier {
    let title: String?
    let text: String
    @Binding var isPresented: Bool
    let pointerPosition: SwiftTooltip.PointerPosition
    let pointerOffset: CGPoint
    let delay: TimeInterval
    let id: String?
    let config: SwiftTooltip.Configuration

    @State private var globalFrame: CGRect = .zero
    @State private var tooltipView: SwiftTooltip.TooltipView?
    @State private var showInFlight: Bool = false
    @State private var resolvedId: String = UUID().uuidString

    func body(content: Content) -> some View {
        content
            .background(GeometryReader { geo in
                Color.clear
                    .preference(key: TooltipFramePreferenceKey.self, value: geo.frame(in: .global))
            })
            .onPreferenceChange(TooltipFramePreferenceKey.self) { value in
                globalFrame = value
                if isPresented, tooltipView == nil, !value.isEmpty, !showInFlight {
                    DispatchQueue.main.async {
                        showTooltip()
                    }
                }
            }
            .onAppear {
                if isPresented, tooltipView == nil, !globalFrame.isEmpty, !showInFlight {
                    showTooltip()
                }
            }
            .onChange(of: isPresented) { presented in
                if presented {
                    if tooltipView == nil, !globalFrame.isEmpty, !showInFlight {
                        showTooltip()
                    }
                } else {
                    tooltipView?.dismiss()
                    tooltipView = nil
                    showInFlight = false
                }
            }
            .onDisappear {
                tooltipView?.dismiss()
                tooltipView = nil
                showInFlight = false
            }
    }

    private func sideMidpoint(for rect: CGRect, position: SwiftTooltip.PointerPosition) -> CGPoint {
        switch position {
        case .topLeft, .topCenter, .topRight:
            // Pointer at bubble top means bubble is below the target → aim to target's bottom edge
            return CGPoint(x: rect.midX, y: rect.maxY)
        case .bottomLeft, .bottomCenter, .bottomRight:
            // Pointer at bubble bottom means bubble is above the target → aim to target's top edge
            return CGPoint(x: rect.midX, y: rect.minY)
        case .left:
            // Pointer at bubble left means bubble is to the right of the target → aim to target's right edge
            return CGPoint(x: rect.maxX, y: rect.midY)
        case .right:
            // Pointer at bubble right means bubble is to the left of the target → aim to target's left edge
            return CGPoint(x: rect.minX, y: rect.midY)
        }
    }

    private func showTooltip() {
        guard globalFrame != .zero else { return }
        let point = sideMidpoint(for: globalFrame, position: pointerPosition)
        guard !showInFlight, tooltipView == nil else { return }
        showInFlight = true
        let tv = SwiftTooltip.show(
            title: title,
            text: text,
            in: nil,
            to: nil,
            at: point,
            pointerPosition: pointerPosition,
            pointerOffset: pointerOffset,
            delay: delay,
            id: id ?? resolvedId,
            config: config,
            onDismiss: {
                // Sync state if the tooltip dismisses itself
                if isPresented { self.isPresented = false }
            })
        tooltipView = tv
        showInFlight = false
    }
}

@available(iOS 13.0, *)
private struct TooltipFramePreferenceKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}
