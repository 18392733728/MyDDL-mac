#!/usr/bin/env swift

import Foundation

// MARK: - 配置
let gitAuthorName = "liyiyang5"  // 修改为你的Git用户名
let daysToImport = 30  // 导入最近多少天的数据
let repositoriesBasePath = "/Users/tal/4s"  // 仓库根目录

// MARK: - 简单的 Git Commit 模型
struct SimpleCommit {
    let hash: String
    let authorName: String
    let authorEmail: String
    let date: Date
    let message: String
    let repositoryName: String
}

// MARK: - Git 命令执行函数
func runGitCommand(in repoPath: String, arguments: [String]) throws -> String {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    process.currentDirectoryURL = URL(fileURLWithPath: repoPath)
    process.arguments = ["git"] + arguments

    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = Pipe()

    try process.run()
    process.waitUntilExit()

    guard process.terminationStatus == 0 else {
        throw NSError(domain: "Git command failed", code: Int(process.terminationStatus))
    }

    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    return String(data: data, encoding: .utf8) ?? ""
}

// MARK: - 扫描目录查找 Git 仓库
func findGitRepositories(in basePath: String) -> [String] {
    var repositories: [String] = []
    let fileManager = FileManager.default

    guard fileManager.fileExists(atPath: basePath) else {
        print("❌ 路径不存在: \(basePath)")
        return repositories
    }

    guard let contents = try? fileManager.contentsOfDirectory(atPath: basePath) else {
        print("❌ 无法读取目录: \(basePath)")
        return repositories
    }

    for itemName in contents {
        let itemPath = (basePath as NSString).appendingPathComponent(itemName)
        var isDirectory: ObjCBool = false

        guard fileManager.fileExists(atPath: itemPath, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            continue
        }

        let gitPath = (itemPath as NSString).appendingPathComponent(".git")
        if fileManager.fileExists(atPath: gitPath) {
            repositories.append(itemPath)
            print("✅ 找到仓库: \(itemName)")
        }
    }

    return repositories
}

// MARK: - 获取提交记录
func getCommits(in repoPath: String, from startDate: Date, to endDate: Date, author: String?) throws -> [SimpleCommit] {
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy-MM-dd"
    let startDateString = dateFormatter.string(from: startDate)
    let endDateString = dateFormatter.string(from: endDate)

    var arguments = [
        "log",
        "--all",
        "--since", startDateString,
        "--until", endDateString
    ]

    if let author = author, !author.isEmpty {
        arguments.append(contentsOf: ["--author", author])
    }

    arguments.append(contentsOf: [
        "--pretty=format:%H|%an|%ae|%aI|%s",
        "--date=iso-strict"
    ])

    let output = try runGitCommand(in: repoPath, arguments: arguments)
    let lines = output.components(separatedBy: "\n").filter { !$0.isEmpty }

    let isoFormatter = DateFormatter()
    isoFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
    isoFormatter.locale = Locale(identifier: "en_US_POSIX")
    isoFormatter.timeZone = TimeZone(secondsFromGMT: 0)

    var commits: [SimpleCommit] = []
    let repoName = (repoPath as NSString).lastPathComponent

    for line in lines {
        let components = line.components(separatedBy: "|")
        guard components.count == 5 else { continue }

        let hash = components[0]
        let authorName = components[1]
        let authorEmail = components[2]
        let dateString = components[3]
        let message = components[4]

        guard let date = isoFormatter.date(from: dateString) else {
            continue
        }

        let commit = SimpleCommit(
            hash: hash,
            authorName: authorName,
            authorEmail: authorEmail,
            date: date,
            message: message,
            repositoryName: repoName
        )
        commits.append(commit)
    }

    return commits
}

// MARK: - 生成 SQL 插入语句
func generateSQL(commits: [SimpleCommit], repositoryId: String) -> String {
    var sql = ""

    for commit in commits {
        let commitId = UUID().uuidString
        let hash = commit.hash.replacingOccurrences(of: "'", with: "''")
        let authorName = commit.authorName.replacingOccurrences(of: "'", with: "''")
        let authorEmail = commit.authorEmail.replacingOccurrences(of: "'", with: "''")
        let message = commit.message.replacingOccurrences(of: "'", with: "''")
        let dateTimestamp = commit.date.timeIntervalSince1970
        let createdAt = Date().timeIntervalSince1970

        sql += """
        INSERT OR IGNORE INTO git_commits (id, hash, authorName, authorEmail, date, message, repositoryId, createdAt)
        VALUES ('\(commitId)', '\(hash)', '\(authorName)', '\(authorEmail)', \(dateTimestamp), '\(message)', '\(repositoryId)', \(createdAt));

        """
    }

    return sql
}

// MARK: - 主程序
print("🚀 开始导入 Git 历史提交记录...")
print("📁 扫描路径: \(repositoriesBasePath)")
print("👤 作者过滤: \(gitAuthorName.isEmpty ? "无" : gitAuthorName)")
print("📅 导入天数: \(daysToImport)")
print()

let repositories = findGitRepositories(in: repositoriesBasePath)

guard !repositories.isEmpty else {
    print("❌ 没有找到任何 Git 仓库")
    exit(1)
}

print("\n📊 找到 \(repositories.count) 个仓库，开始获取提交记录...\n")

let calendar = Calendar.current
let endDate = Date()
let startDate = calendar.date(byAdding: .day, value: -daysToImport, to: endDate)!

var allSQL = "-- Git 提交记录导入脚本\n"
allSQL += "-- 生成时间: \(Date())\n"
allSQL += "-- 作者: \(gitAuthorName)\n"
allSQL += "-- 时间范围: \(startDate) 至 \(endDate)\n\n"

var totalCommits = 0

for repoPath in repositories {
    let repoName = (repoPath as NSString).lastPathComponent
    print("📦 处理仓库: \(repoName)")

    do {
        let commits = try getCommits(
            in: repoPath,
            from: startDate,
            to: endDate,
            author: gitAuthorName.isEmpty ? nil : gitAuthorName
        )

        if commits.isEmpty {
            print("   ℹ️  没有找到提交记录")
            continue
        }

        print("   ✅ 找到 \(commits.count) 条提交")

        // 生成随机的 repository ID（实际使用时应该从数据库获取）
        let repositoryId = UUID().uuidString
        let sql = generateSQL(commits: commits, repositoryId: repositoryId)

        allSQL += "-- 仓库: \(repoName) (\(commits.count) 条提交)\n"
        allSQL += sql
        allSQL += "\n"

        totalCommits += commits.count
    } catch {
        print("   ❌ 错误: \(error)")
    }
}

// 保存 SQL 文件
let outputPath = "/tmp/import_git_commits.sql"
do {
    try allSQL.write(toFile: outputPath, atomically: true, encoding: .utf8)
    print("\n✅ SQL 文件已生成: \(outputPath)")
    print("📊 总计: \(totalCommits) 条提交记录")
    print("\n⚠️  注意: 此脚本生成的 repositoryId 是随机的")
    print("   请手动修改 SQL 文件中的 repositoryId 为数据库中实际的仓库 ID")
    print("\n执行步骤:")
    print("1. 打开 SQL 文件: \(outputPath)")
    print("2. 查询数据库获取实际的 repository ID:")
    print("   SELECT id, name FROM git_repositories;")
    print("3. 替换 SQL 文件中的 repositoryId")
    print("4. 执行 SQL 导入:")
    print("   sqlite3 ~/Library/Application\\ Support/MyDDL/myddl.db < \(outputPath)")
} catch {
    print("❌ 保存 SQL 文件失败: \(error)")
    exit(1)
}
