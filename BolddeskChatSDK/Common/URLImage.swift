import SwiftUI
import UIKit

struct URLImage: View {
    let url: String
    @State private var image: UIImage? = nil
    @State private var loadFailed: Bool = false
    @State private var showPreview: Bool = false   // <- For fullscreen preview
    
    var body: some View {
        Group {
            if let img = image {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 252)
                    .cornerRadius(6)
                    .onTapGesture {
                        showPreview = true   // Show preview on tap
                    }
            } else if loadFailed {
                Group {
                    VStack(spacing: 12) {
                        AppIcon(icon: .imageFailed, size: FontSize.semilarge, color: Color.fgWhite)
                        Text("Image unavailable")
                            .foregroundColor(Color.fgWhite)
                            .font(FontFamily.customFont(size: FontSize.medium, weight: .regular))
                    }
                    .frame(maxWidth: 252, minHeight: 120)
                    .background(Color.fgAlphaBlack60)
                }
                .frame(maxWidth: 252, minHeight: 120)
                .background(Color.bgSecondary)
                .cornerRadius(6)
            } else {
                ZStack {
                    Rectangle()
                        .fill(Color.black)
                        .frame(height: 120)
                        .cornerRadius(6)
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .bgBrandSolid))
                        .scaleEffect(2)
                }
                .frame(maxWidth: 252, minHeight: 120)
                .onAppear {
                    loadImage()
                }
            }
        }
        .fullScreenCover(isPresented: $showPreview) {
            if let img = image {
                ImagePreviewView(image: img)
            }
        }
    }
    
    private func loadImage() {
        guard let imageURL = URL(string: url) else {
            loadFailed = true
            return
        }
        URLSession.shared.dataTask(with: imageURL) { data, response, _ in
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200,
                  let data = data,
                  let uiImage = UIImage(data: data) else {
                DispatchQueue.main.async {
                    loadFailed = true
                }
                return
            }
            
            DispatchQueue.main.async {
                self.image = uiImage
            }
        }.resume()
    }
}

// MARK: - Fullscreen Image Preview
struct ImagePreviewView: View {
    let image: UIImage
    
    @Environment(\.presentationMode) private var presentationMode
    
    @State private var scale: CGFloat = 1.0   // pinch zoom
    @State private var lastScale: CGFloat = 1.0
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            // Image with pinch zoom
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .scaleEffect(scale)
                .gesture(
                    MagnificationGesture()
                        .onChanged { value in
                            scale = lastScale * value
                        }
                        .onEnded { _ in
                            lastScale = scale
                        }
                )
                .ignoresSafeArea()
            
            VStack {
                Spacer()
                
                // Bottom toolbar
                HStack {
                    Spacer()
                    
                    Button(action: downloadImage) {
                        VStack(spacing: 6) {
                            AppIcon(icon: .download, size: FontSize.extralarge, color: .fgWhite)
                            Text("Download")
                                .font(FontFamily.customFont(size: FontSize.xsmall, weight: .medium))
                                .foregroundColor(.fgWhite)
                        }
                    }
                    
                    Spacer()
                    
                    Divider()
                        .frame(height: 30)
                        .background(Color.borderTertiary)
                    
                    Spacer()
                    
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        VStack(spacing: 6) {
                            AppIcon(icon: .close, size: FontSize.extralarge, color: .fgWhite)
                            Text("Close")
                                .font(FontFamily.customFont(size: FontSize.xsmall, weight: .medium))
                                .foregroundColor(.fgWhite)
                        }
                    }
                    
                    Spacer()
                }
                .padding()
                .padding(.bottom, 10)
                .background(Color.utilityGray800)
            }
        }
        .ignoresSafeArea()
    }
    
    private func downloadImage() {
        // Save image temporarily
        if let data = image.pngData() {
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString + ".png")
            
            do {
                try data.write(to: tempURL)
                
                // Dismiss preview first, then present share sheet
                presentationMode.wrappedValue.dismiss()
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    openFile(tempURL)
                }
            } catch {
                NotificationManager.shared.show(.somethingWentWrong, shouldAutoHide: true)
            }
        }
    }

    private func openFile(_ url: URL) {
        DispatchQueue.main.async {
            let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
            activityVC.popoverPresentationController?.sourceRect = CGRect(x: UIScreen.main.bounds.midX, y: UIScreen.main.bounds.maxY - 50, width: 0, height: 0)
            activityVC.popoverPresentationController?.sourceView = UIApplication.shared.windows.first { $0.isKeyWindow }
            if let presenter = topMostViewController() {
                presenter.present(activityVC, animated: true)
            } else if let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first,
                      let rootVC = scene.windows.first?.rootViewController {
                rootVC.present(activityVC, animated: true)
            }
        }
    }
    
    // MARK: - Presenter helper (local)
    private func topMostViewController(base: UIViewController? = nil) -> UIViewController? {
        let baseVC: UIViewController? = {
            if let base = base { return base }
            guard let windowScene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive }) else { return nil }
            if let key = windowScene.windows.first(where: { $0.isKeyWindow }) {
                return key.rootViewController
            }
            return windowScene.windows.first?.rootViewController
        }()
        guard let root = baseVC else { return nil }
        if let nav = root as? UINavigationController {
            return topMostViewController(base: nav.visibleViewController)
        }
        if let tab = root as? UITabBarController {
            return topMostViewController(base: tab.selectedViewController)
        }
        if let presented = root.presentedViewController {
            return topMostViewController(base: presented)
        }
        return root
    }

}
