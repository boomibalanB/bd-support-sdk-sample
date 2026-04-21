import Foundation

// MARK: - Categories

struct KBCategoriesResponse: Codable {
    let categorylist: [KBCategory]
}

struct KBCategory: Codable, Identifiable {
    let id: Int
    let name: String
    let description: String?
    let position: Int?
    let icon: String?
    let articleCount: Int?
    let createdOn: String?
    let groupId: Int?
    let groupName: String?
    let groupSlugTitle: String?
    let groupPosition: Int?
}

// MARK: - Articles List

struct KBArticlesResponse: Codable {
    let result: [KBArticle]
    let count: Int?
    let sectionArticleCount: Int?
    let title: String?
    let description: String?
}

struct KBArticle: Codable, Identifiable {
    let id: Int
    let name: String?
    let slugTitle: String?
    let position: Int?
    let isSection: Bool?
    let category: KBCategoryRef?
    let section: KBSectionRef?
    let createdOn: String?
    let lastModifiedOn: String?
    let publishedOn: String?
    let articleStatusIndicator: KBStatusIndicator?
    let isReplicated: Bool?
    let replicatedCategory: String?
    let replicatedSection: String?
    let isArticleReplicated: Bool?
    let articleCount: Int?
}

struct KBCategoryRef: Codable {
    let id: Int?
    let name: String?
}

struct KBSectionRef: Codable {
    let id: Int?
    let name: String?
}

struct KBStatusIndicator: Codable {
    let id: Int?
    let name: String?
    let expiryDate: String?
}

struct KBSearchArticle: Codable, Identifiable {
    let id: Int?
    let title: String?
    let description: String?
    let slugtitle: String?
    let titleRank: Double?
    let descriptionRank: Double?
}
