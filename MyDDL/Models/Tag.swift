import Foundation
import SwiftUI

struct Tag: Identifiable, Codable, Equatable, Hashable {
    var id: UUID
    var name: String
    var colorHex: String
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        colorHex: String = "#5B8DEF",
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.createdAt = createdAt
    }

    var color: Color {
        Color(hex: colorHex) ?? Color.blue
    }

    // 预设标签颜色
    static let presetColors: [String] = [
        "#FF6B6B", // 红色
        "#4ECDC4", // 青色
        "#FFD93D", // 黄色
        "#6BCB77", // 绿色
        "#A8E6CF", // 浅绿
        "#FF8B94", // 粉色
        "#C7CEEA", // 紫色
        "#B4A7D6", // 淡紫
        "#FFB347", // 橙色
        "#87CEEB", // 天蓝
    ]
}

// MARK: - Tag Manager
class TagManager: ObservableObject {
    @Published var tags: [Tag] = []

    static let shared = TagManager()

    private let userDefaultsKey = "app.tags"

    private init() {
        loadTags()

        // 添加默认标签
        if tags.isEmpty {
            let defaultTags = [
                Tag(name: "重要", colorHex: "#FF6B6B"),
                Tag(name: "紧急", colorHex: "#FFD93D"),
                Tag(name: "开发", colorHex: "#4ECDC4"),
                Tag(name: "测试", colorHex: "#6BCB77"),
                Tag(name: "设计", colorHex: "#FF8B94"),
                Tag(name: "文档", colorHex: "#C7CEEA"),
            ]
            tags = defaultTags
            saveTags()
        }
    }

    private func loadTags() {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let decoded = try? JSONDecoder().decode([Tag].self, from: data) else {
            return
        }
        tags = decoded
    }

    private func saveTags() {
        guard let encoded = try? JSONEncoder().encode(tags) else { return }
        UserDefaults.standard.set(encoded, forKey: userDefaultsKey)
    }

    func addTag(_ tag: Tag) {
        tags.append(tag)
        saveTags()
    }

    func updateTag(_ tag: Tag) {
        if let index = tags.firstIndex(where: { $0.id == tag.id }) {
            tags[index] = tag
            saveTags()
        }
    }

    func deleteTag(_ tag: Tag) {
        tags.removeAll { $0.id == tag.id }
        saveTags()
    }

    func getTag(by name: String) -> Tag? {
        tags.first { $0.name == name }
    }

    // 获取或创建标签
    func getOrCreateTag(name: String, colorHex: String? = nil) -> Tag {
        if let existing = getTag(by: name) {
            return existing
        }

        let color = colorHex ?? Tag.presetColors.randomElement() ?? "#5B8DEF"
        let newTag = Tag(name: name, colorHex: color)
        addTag(newTag)
        return newTag
    }
}
