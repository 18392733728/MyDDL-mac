import Foundation

// 简单的超时辅助函数
func withTaskTimeout(seconds: TimeInterval, operation: @escaping () async -> Void) async -> Bool {
    return await withTaskGroup(of: Bool.self) { group in
        group.addTask {
            await operation()
            return true
        }

        group.addTask {
            try? await _Concurrency.Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            return false
        }

        // 返回第一个完成的结果
        if let first = await group.next() {
            group.cancelAll()
            return first
        }
        return false
    }
}

class GitManager: ObservableObject {
    static let shared = GitManager()

    private init() {}

    // MARK: - 扫描目录查找 Git 仓库
    func scanForRepositories(in basePath: String) -> [GitRepository] {
        var repositories: [GitRepository] = []
        let fileManager = FileManager.default

        // 检查基础路径是否存在
        guard fileManager.fileExists(atPath: basePath) else {
            print("Path does not exist: \(basePath)")
            return repositories
        }

        // 获取一级子目录
        guard let contents = try? fileManager.contentsOfDirectory(atPath: basePath) else {
            print("Cannot read directory: \(basePath)")
            return repositories
        }

        for itemName in contents {
            let itemPath = (basePath as NSString).appendingPathComponent(itemName)
            var isDirectory: ObjCBool = false

            // 检查是否是目录
            guard fileManager.fileExists(atPath: itemPath, isDirectory: &isDirectory),
                  isDirectory.boolValue else {
                continue
            }

            // 检查是否包含 .git 目录
            let gitPath = (itemPath as NSString).appendingPathComponent(".git")
            if fileManager.fileExists(atPath: gitPath) {
                // 获取remote URL
                let remoteURL = getRemoteURL(for: itemPath)

                let repository = GitRepository(
                    name: itemName,
                    path: itemPath,
                    remoteURL: remoteURL
                )
                repositories.append(repository)
                print("Found repository: \(itemName) at \(itemPath)")
            }
        }

        print("Total repositories found: \(repositories.count)")
        return repositories
    }

    // MARK: - 获取仓库的remote URL
    func getRemoteURL(for repositoryPath: String) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.currentDirectoryURL = URL(fileURLWithPath: repositoryPath)
        process.arguments = ["git", "remote", "get-url", "origin"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()

            guard process.terminationStatus == 0 else {
                return nil
            }

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8) else {
                return nil
            }

            return output.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            print("Failed to get remote URL for \(repositoryPath): \(error)")
            return nil
        }
    }

    // MARK: - 获取指定日期范围的提交记录
    func getCommits(
        for repository: GitRepository,
        from startDate: Date,
        to endDate: Date,
        author: String? = nil
    ) async throws -> [GitCommit] {
        print("[GitManager] 🔴 getCommits called for \(repository.name)")
        print("[GitManager] 🔴 Path: \(repository.path)")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.currentDirectoryURL = URL(fileURLWithPath: repository.path)

        // 使用 git 兼容的日期格式（YYYY-MM-DD）
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.timeZone = TimeZone.current
        let startDateString = dateFormatter.string(from: startDate)
        let endDateString = dateFormatter.string(from: endDate)
        print("[GitManager] 🔴 Date range: \(startDateString) to \(endDateString)")

        // 构建参数数组
        var arguments = [
            "git", "log",
            "--all",
            "--since", startDateString,
            "--until", endDateString
        ]

        // 如果指定了作者，添加 --author 参数
        if let author = author, !author.isEmpty {
            arguments.append(contentsOf: ["--author", author])
            print("[GitManager] 🔴 Using author filter: \(author)")
        }

        arguments.append(contentsOf: [
            "--pretty=format:COMMIT_START|%H|%an|%ae|%aI|%s",
            "--numstat",
            "--date=iso-strict"
        ])

        process.arguments = arguments
        print("[GitManager] 🔴 Running git command: \(arguments.joined(separator: " "))")

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        let startTime = Date()
        print("[GitManager] 🔴 Starting git process...")
        fflush(stdout)  // 强制刷新输出

        try process.run()
        print("[GitManager] 🔴 Process started, PID: \(process.processIdentifier)")
        fflush(stdout)

        // 使用异步方式等待进程完成，带超时
        print("[GitManager] 🔴 Waiting for git process to complete (async, 10s timeout)...")
        fflush(stdout)

        let completed = await withTaskTimeout(seconds: 10) {
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                process.terminationHandler = { _ in
                    print("[GitManager] 🔴 Process terminated callback")
                    fflush(stdout)
                    continuation.resume()
                }
            }
        }

        if !completed {
            print("[GitManager] ⚠️ Git process timeout after 10s, terminating...")
            fflush(stdout)
            process.terminate()
            try await _Concurrency.Task.sleep(nanoseconds: 100_000_000) // 100ms
            throw GitError.commandFailed
        }

        let duration = Date().timeIntervalSince(startTime)
        print("[GitManager] 🔴 Git process completed in \(String(format: "%.2f", duration))s, status: \(process.terminationStatus)")
        fflush(stdout)

        guard process.terminationStatus == 0 else {
            print("[GitManager] ❌ Git command failed with status \(process.terminationStatus)")
            throw GitError.commandFailed
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else {
            print("[GitManager] ❌ Failed to decode git output")
            throw GitError.invalidOutput
        }

        print("[GitManager] 🔴 Git output length: \(output.count) chars")
        let commits = parseCommits(from: output, repositoryId: repository.id)
        print("[GitManager] ✅ Parsed \(commits.count) commits")
        return commits
    }

    // MARK: - 获取今天的提交记录（实时查询）
    func getTodayCommits(for repository: GitRepository, author: String? = nil) async throws -> [GitCommit] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!

        return try await getCommits(for: repository, from: today, to: tomorrow, author: author)
    }

    // MARK: - 获取提交统计
    func getCommitStats(
        for repository: GitRepository,
        from startDate: Date,
        to endDate: Date
    ) async throws -> GitCommitStats {
        let commits = try await getCommits(for: repository, from: startDate, to: endDate)

        return GitCommitStats(
            totalCommits: commits.count,
            commitsByDate: groupCommitsByDate(commits),
            commitsByAuthor: groupCommitsByAuthor(commits)
        )
    }

    // MARK: - 解析 git log 输出
    private func parseCommits(from output: String, repositoryId: UUID) -> [GitCommit] {
        var commits: [GitCommit] = []

        // 使用标准 DateFormatter，支持 ISO8601 格式
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)

        // 按 COMMIT_START 分割输出
        let commitBlocks = output.components(separatedBy: "COMMIT_START|").filter { !$0.isEmpty }

        for block in commitBlocks {
            let lines = block.components(separatedBy: "\n")
            guard let firstLine = lines.first, !firstLine.isEmpty else { continue }

            // 解析提交信息行
            let components = firstLine.components(separatedBy: "|")
            guard components.count >= 5 else { continue }

            let hash = components[0]
            let authorName = components[1]
            let authorEmail = components[2]
            let dateString = components[3]
            let message = components.dropFirst(4).joined(separator: "|") // 消息可能包含 |

            // 解析日期
            guard let date = dateFormatter.date(from: dateString) else {
                continue
            }

            // 解析 numstat 行统计代码行数
            var linesAdded = 0
            var linesDeleted = 0

            for line in lines.dropFirst() {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                guard !trimmed.isEmpty else { continue }

                // numstat 格式: "added\tdeleted\tfilename"
                let parts = trimmed.components(separatedBy: "\t")
                if parts.count >= 2 {
                    // "-" 表示二进制文件，跳过
                    if let added = Int(parts[0]) {
                        linesAdded += added
                    }
                    if let deleted = Int(parts[1]) {
                        linesDeleted += deleted
                    }
                }
            }

            let commit = GitCommit(
                hash: hash,
                authorName: authorName,
                authorEmail: authorEmail,
                date: date,
                message: message,
                repositoryId: repositoryId,
                linesAdded: linesAdded,
                linesDeleted: linesDeleted
            )
            commits.append(commit)
        }

        return commits
    }

    // MARK: - 按日期分组
    private func groupCommitsByDate(_ commits: [GitCommit]) -> [Date: Int] {
        let calendar = Calendar.current
        var grouped: [Date: Int] = [:]

        for commit in commits {
            let dateKey = calendar.startOfDay(for: commit.date)
            grouped[dateKey, default: 0] += 1
        }

        return grouped
    }

    // MARK: - 按作者分组
    private func groupCommitsByAuthor(_ commits: [GitCommit]) -> [String: Int] {
        var grouped: [String: Int] = [:]

        for commit in commits {
            grouped[commit.authorName, default: 0] += 1
        }

        return grouped
    }
}

// MARK: - Git Error
enum GitError: Error, LocalizedError {
    case commandFailed
    case invalidOutput
    case repositoryNotFound

    var errorDescription: String? {
        switch self {
        case .commandFailed:
            return "Git 命令执行失败"
        case .invalidOutput:
            return "无法解析 Git 输出"
        case .repositoryNotFound:
            return "仓库不存在"
        }
    }
}

// MARK: - Git Commit Stats
struct GitCommitStats {
    let totalCommits: Int
    let commitsByDate: [Date: Int]
    let commitsByAuthor: [String: Int]
}
