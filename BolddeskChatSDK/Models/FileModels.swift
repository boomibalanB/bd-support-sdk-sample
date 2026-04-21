import SwiftUI

struct FileInfo: Hashable {
    let id: String
    let name: String
    let size: Int
    let type: String
    let url: URL
}


struct AttachmentInfo: Decodable, Hashable {
    let token: String
    let url: String
    let previewUrl: String
}

struct File: Hashable {
    var url: String
    var size: String
    var name: String
    var mediaType: String
    let disposition: String
    let rawFile: FileInfo?
    var cID: String?
}
