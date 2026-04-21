import SwiftUI

struct ConversationListAvatarSection: View {
    let agentInfo: AssignedAgent?

    var body: some View {
        if let urlString = agentInfo?.profileImageUrl, let url = URL(string: urlString) {
            AgentAvatarView(
                url: url,
                shortCode: agentInfo?.shortCode ?? "",
                colorCode: agentInfo?.colorCode ?? "",
                avatarSize: 40
            )
        } else if let code = agentInfo?.shortCode, !code.isEmpty {
            AgentShortCodeView(
                shortCode: agentInfo?.shortCode ?? "",
                colorCode: agentInfo?.colorCode ?? "",
                avatarSize: 40
            )
        }
        else{
            if let uiImage = UIImage(named: "ProfileIcon", in: Bundle(for: SDKBundleFinder.self), compatibleWith: nil) {
                ZStack {
                    Circle()
                        .fill(Color.borderSecondary)
                        .frame(width: 40, height: 40)
                    
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 24, height: 24)
                }
                .overlay(
                    Circle()
                        .stroke(Color.borderPrimary, lineWidth: 1)
                )
            }
        }
    }
}

struct AgentAvatarSection: View {
    let agentInfo: AgentInfo

    var body: some View {
        if let urlString = agentInfo.profileImageUrl, let url = URL(string: urlString) {
            AgentAvatarView(
                url: url,
                shortCode: agentInfo.shortCode,
                colorCode: agentInfo.colorCode,
                avatarSize: 32
            )
        } else {
            AgentShortCodeView(
                shortCode: agentInfo.shortCode,
                colorCode: agentInfo.colorCode,
                avatarSize: 32
            )
        }
    }
}

struct AgentAvatarView: View {

    @StateObject private var loader: AvatarImageLoader
    let shortCode: String
    let colorCode: String
    let avatarSize: CGFloat

    init(url: URL, shortCode: String, colorCode: String, avatarSize: CGFloat) {
        _loader = StateObject(wrappedValue: AvatarImageLoader(url: url))
        self.shortCode = shortCode
        self.colorCode = colorCode
        self.avatarSize = avatarSize
    }

    var body: some View {
        Group {
            if let uiImage = loader.image {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else if loader.failed {
                AgentShortCodeView(shortCode: shortCode, colorCode: colorCode, avatarSize: 32)
            } else {
                Circle()
                    .foregroundColor(Color.gray.opacity(0.15))
                    .shimmer()
            }
        }
        .frame(width: avatarSize, height: avatarSize)
        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(Color.borderPrimary, lineWidth: 1)
        )
        .onAppear { loader.load() }
    }
}

import UIKit

final class AvatarDiskCache {

    static let shared = AvatarDiskCache()

    private let fileManager = FileManager.default
    private let cacheDirectory: URL
    private let expirationDays: Int = 7

    private init() {
        let urls = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)
        cacheDirectory = urls[0].appendingPathComponent("AvatarCache")

        if !fileManager.fileExists(atPath: cacheDirectory.path) {
            try? fileManager.createDirectory(at: cacheDirectory,
                                              withIntermediateDirectories: true)
        }

        cleanExpiredFiles()
    }

    // MARK: - Save

    func save(_ image: UIImage, for url: URL) {
        let fileURL = cacheDirectory.appendingPathComponent(fileName(for: url))

        if let data = image.pngData() {
            try? data.write(to: fileURL)
        }
    }

    // MARK: - Load

    func load(for url: URL) -> UIImage? {
        let fileURL = cacheDirectory.appendingPathComponent(fileName(for: url))

        guard fileManager.fileExists(atPath: fileURL.path) else { return nil }

        // Check expiration
        if isExpired(fileURL: fileURL) {
            try? fileManager.removeItem(at: fileURL)
            return nil
        }

        return UIImage(contentsOfFile: fileURL.path)
    }

    // MARK: - Expiration

    private func isExpired(fileURL: URL) -> Bool {
        guard
            let attributes = try? fileManager.attributesOfItem(atPath: fileURL.path),
            let creationDate = attributes[.creationDate] as? Date
        else { return true }

        let expirationDate = Calendar.current.date(
            byAdding: .day,
            value: expirationDays,
            to: creationDate
        )!

        return Date() > expirationDate
    }

    func cleanExpiredFiles() {
        guard let files = try? fileManager.contentsOfDirectory(
            at: cacheDirectory,
            includingPropertiesForKeys: [.creationDateKey]
        ) else { return }

        for file in files {
            if isExpired(fileURL: file) {
                try? fileManager.removeItem(at: file)
            }
        }
    }

    // MARK: - File name

    private func fileName(for url: URL) -> String {
        return url.absoluteString
            .addingPercentEncoding(withAllowedCharacters: .alphanumerics)
            ?? UUID().uuidString
    }
}

final class AvatarImageLoader: ObservableObject {

    @Published var image: UIImage?
    @Published var failed = false

    private let url: URL
    private static let memoryCache = NSCache<NSURL, UIImage>()

    init(url: URL) {
        self.url = url
    }

    func load() {

        // 1️⃣ Memory cache
        if let cached = Self.memoryCache.object(forKey: url as NSURL) {
            self.image = cached
            return
        }

        // 2️⃣ Disk cache
        if let diskImage = AvatarDiskCache.shared.load(for: url) {
            Self.memoryCache.setObject(diskImage, forKey: url as NSURL)
            self.image = diskImage
            return
        }

        // 3️⃣ Network load (only if not cached)
        URLSession.shared.dataTask(with: url) { data, _, error in
            DispatchQueue.main.async {
                guard let data, let uiImage = UIImage(data: data) else {
                    self.failed = true
                    return
                }

                // Save to both caches
                Self.memoryCache.setObject(uiImage, forKey: self.url as NSURL)
                AvatarDiskCache.shared.save(uiImage, for: self.url)

                self.image = uiImage
            }
        }.resume()
    }
}
