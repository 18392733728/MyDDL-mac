import Foundation

// MARK: - Git Commit Model
struct GitCommit: Identifiable, Codable, Equatable {
    var id: UUID
    var hash: String
    var authorName: String
    var authorEmail: String
    var date: Date
    var message: String
    var repositoryId: UUID
    var linesAdded: Int
    var linesDeleted: Int
    var createdAt: Date

    init(
        id: UUID = UUID(),
        hash: String,
        authorName: String,
        authorEmail: String,
        date: Date,
        message: String,
        repositoryId: UUID,
        linesAdded: Int = 0,
        linesDeleted: Int = 0,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.hash = hash
        self.authorName = authorName
        self.authorEmail = authorEmail
        self.date = date
        self.message = message
        self.repositoryId = repositoryId
        self.linesAdded = linesAdded
        self.linesDeleted = linesDeleted
        self.createdAt = createdAt
    }

    // 总变更行数
    var totalLinesChanged: Int {
        linesAdded + linesDeleted
    }

    // 短哈希值（前7位）
    var shortHash: String {
        String(hash.prefix(7))
    }

    // 格式化的提交消息（第一行）
    var shortMessage: String {
        message.components(separatedBy: "\n").first ?? message
    }

    // 是否是今天的提交
    var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }

    // 生成commit的Web URL（根据remote URL）
    func webURL(remoteURL: String) -> String? {
        // 解析remote URL并构建commit链接
        guard let parsedInfo = parseRemoteURL(remoteURL) else {
            return nil
        }

        let (host, owner, repo) = parsedInfo

        // 根据不同的Git服务器构建URL
        if host.contains("github.com") {
            return "https://\(host)/\(owner)/\(repo)/commit/\(hash)"
        } else if host.contains("gitlab") {
            return "https://\(host)/\(owner)/\(repo)/-/commit/\(hash)"
        } else if host.contains("gitee.com") {
            return "https://\(host)/\(owner)/\(repo)/commit/\(hash)"
        } else {
            // 默认使用GitLab格式（大多数私有Git服务器使用GitLab）
            return "https://\(host)/\(owner)/\(repo)/-/commit/\(hash)"
        }
    }

    // 解析remote URL，返回 (host, owner, repo)
    private func parseRemoteURL(_ remoteURL: String) -> (String, String, String)? {
        // 支持两种格式：
        // 1. git@host:owner/repo.git
        // 2. https://host/owner/repo.git

        var urlString = remoteURL.trimmingCharacters(in: .whitespaces)

        // 移除.git后缀
        if urlString.hasSuffix(".git") {
            urlString = String(urlString.dropLast(4))
        }

        // SSH格式: git@host:owner/repo
        if urlString.hasPrefix("git@") {
            let parts = urlString.dropFirst(4).components(separatedBy: ":")
            guard parts.count == 2 else { return nil }

            let host = parts[0]
            let pathParts = parts[1].components(separatedBy: "/")
            guard pathParts.count >= 2 else { return nil }

            let owner = pathParts[pathParts.count - 2]
            let repo = pathParts[pathParts.count - 1]

            return (host, owner, repo)
        }

        // HTTPS格式: https://host/owner/repo
        if urlString.hasPrefix("https://") || urlString.hasPrefix("http://") {
            guard let url = URL(string: urlString),
                  let host = url.host else { return nil }

            let pathComponents = url.pathComponents.filter { $0 != "/" }
            guard pathComponents.count >= 2 else { return nil }

            let owner = pathComponents[pathComponents.count - 2]
            let repo = pathComponents[pathComponents.count - 1]

            return (host, owner, repo)
        }

        return nil
    }
}

// MARK: - Git Repository Model
struct GitRepository: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var path: String
    var isActive: Bool
    var remoteURL: String?
    var lastScannedAt: Date?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        path: String,
        isActive: Bool = true,
        remoteURL: String? = nil,
        lastScannedAt: Date? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.path = path
        self.isActive = isActive
        self.remoteURL = remoteURL
        self.lastScannedAt = lastScannedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    // 仓库路径是否存在
    var pathExists: Bool {
        FileManager.default.fileExists(atPath: path)
    }

    // 是否是有效的 git 仓库
    var isValidGitRepo: Bool {
        let gitPath = (path as NSString).appendingPathComponent(".git")
        return FileManager.default.fileExists(atPath: gitPath)
    }
}
