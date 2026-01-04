import SwiftUI

struct GitRepositorySettingsView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var dataStore: DataStore
    @EnvironmentObject var themeManager: ThemeManager

    @State private var repositoryPath: String = ""
    @State private var isScanning = false
    @State private var scanMessage: String = ""
    @AppStorage("gitAuthorName") private var gitAuthorName: String = "liyiyang5"

    // Import history states
    @State private var importDays: Double = 30
    @State private var importAuthors: String = "liyiyang5"
    @State private var selectedRepoIds: Set<UUID> = []
    @State private var isImporting = false
    @State private var importProgress: String = ""
    @State private var importedCount: Int = 0

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Git 仓库设置")
                        .font(DesignSystem.Fonts.title)
                        .foregroundColor(themeManager.current.textPrimary)

                    Text("添加代码仓库路径以自动扫描 Git 提交记录")
                        .font(DesignSystem.Fonts.caption)
                        .foregroundColor(themeManager.current.textTertiary)
                }

                Spacer()

                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(themeManager.current.textTertiary)
                        .frame(width: 28, height: 28)
                        .background(themeManager.current.secondaryBackground)
                        .cornerRadius(DesignSystem.Radius.small)
                }
                .buttonStyle(.plain)
            }
            .padding(DesignSystem.Spacing.xl)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xl) {
                    // 当前用户配置
                    currentUserSection

                    // 添加仓库路径
                    scanSection

                    // 已添加的仓库列表
                    if !dataStore.gitRepositories.isEmpty {
                        repositoryListSection
                    }

                    // 导入历史记录
                    if !dataStore.gitRepositories.isEmpty {
                        importHistorySection
                    }
                }
                .padding(DesignSystem.Spacing.xl)
            }
        }
        .frame(width: 600, height: 650)
        .background(themeManager.current.background)
    }

    // MARK: - Current User Section

    private var currentUserSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("当前用户")
                .font(DesignSystem.Fonts.headline)
                .foregroundColor(themeManager.current.textPrimary)

            Text("只显示此 Git 用户名的提交记录")
                .font(DesignSystem.Fonts.body)
                .foregroundColor(themeManager.current.textSecondary)

            HStack(spacing: DesignSystem.Spacing.md) {
                Image(systemName: "person.fill")
                    .font(.system(size: 14))
                    .foregroundColor(themeManager.current.textTertiary)
                    .frame(width: 36, height: 36)
                    .background(themeManager.current.secondaryBackground)
                    .cornerRadius(DesignSystem.Radius.medium)

                TextField("Git 用户名，如: liyiyang5", text: $gitAuthorName)
                    .textFieldStyle(.plain)
                    .font(DesignSystem.Fonts.body)
                    .foregroundColor(themeManager.current.textPrimary)
                    .padding(DesignSystem.Spacing.md)
                    .background(themeManager.current.secondaryBackground)
                    .cornerRadius(DesignSystem.Radius.medium)
            }

            if !gitAuthorName.isEmpty {
                HStack(spacing: DesignSystem.Spacing.sm) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(DesignSystem.Colors.success)
                    Text("已配置用户: \(gitAuthorName)")
                        .font(DesignSystem.Fonts.caption)
                        .foregroundColor(DesignSystem.Colors.success)
                }
                .padding(DesignSystem.Spacing.md)
                .background(DesignSystem.Colors.success.opacity(0.1))
                .cornerRadius(DesignSystem.Radius.medium)
            }
        }
        .padding(DesignSystem.Spacing.lg)
        .background(themeManager.current.cardBackground)
        .cornerRadius(DesignSystem.Radius.large)
    }

    // MARK: - Scan Section

    private var scanSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("扫描仓库目录")
                .font(DesignSystem.Fonts.headline)
                .foregroundColor(themeManager.current.textPrimary)

            Text("输入包含多个 Git 仓库的父目录路径，例如: /Users/username/Projects")
                .font(DesignSystem.Fonts.body)
                .foregroundColor(themeManager.current.textSecondary)

            HStack(spacing: DesignSystem.Spacing.md) {
                TextField("仓库路径，如: ~/Projects", text: $repositoryPath)
                    .textFieldStyle(.plain)
                    .font(DesignSystem.Fonts.body)
                    .foregroundColor(themeManager.current.textPrimary)
                    .padding(DesignSystem.Spacing.md)
                    .background(themeManager.current.secondaryBackground)
                    .cornerRadius(DesignSystem.Radius.medium)

                Button(action: selectFolder) {
                    Image(systemName: "folder")
                        .font(.system(size: 14))
                        .foregroundColor(themeManager.current.textSecondary)
                        .frame(width: 36, height: 36)
                        .background(themeManager.current.secondaryBackground)
                        .cornerRadius(DesignSystem.Radius.medium)
                }
                .buttonStyle(.plain)

                Button(action: scanRepositories) {
                    HStack(spacing: 6) {
                        if isScanning {
                            ProgressView()
                                .scaleEffect(0.7)
                        } else {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 14))
                        }
                        Text("扫描")
                            .font(DesignSystem.Fonts.body)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, DesignSystem.Spacing.lg)
                    .padding(.vertical, DesignSystem.Spacing.sm)
                    .background(DesignSystem.Colors.accent)
                    .cornerRadius(DesignSystem.Radius.medium)
                }
                .buttonStyle(.plain)
                .disabled(repositoryPath.isEmpty || isScanning)
            }

            if !scanMessage.isEmpty {
                HStack(spacing: DesignSystem.Spacing.sm) {
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: 12))
                    Text(scanMessage)
                        .font(DesignSystem.Fonts.caption)
                }
                .foregroundColor(DesignSystem.Colors.accent)
                .padding(DesignSystem.Spacing.md)
                .background(DesignSystem.Colors.accent.opacity(0.1))
                .cornerRadius(DesignSystem.Radius.medium)
            }
        }
        .padding(DesignSystem.Spacing.lg)
        .background(themeManager.current.cardBackground)
        .cornerRadius(DesignSystem.Radius.large)
    }

    // MARK: - Repository List Section

    private var repositoryListSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("已添加的仓库 (\(dataStore.gitRepositories.count))")
                .font(DesignSystem.Fonts.headline)
                .foregroundColor(themeManager.current.textPrimary)

            VStack(spacing: DesignSystem.Spacing.sm) {
                ForEach(dataStore.gitRepositories) { repository in
                    RepositorySettingRow(repository: repository)
                }
            }
        }
    }

    // MARK: - Actions

    private func selectFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "选择包含 Git 仓库的目录"

        if panel.runModal() == .OK, let url = panel.url {
            repositoryPath = url.path
        }
    }

    private func scanRepositories() {
        guard !repositoryPath.isEmpty else { return }

        isScanning = true
        scanMessage = ""

        DispatchQueue.global(qos: .userInitiated).async {
            let expandedPath = (repositoryPath as NSString).expandingTildeInPath
            dataStore.scanRepositoriesInPath(expandedPath)

            DispatchQueue.main.async {
                isScanning = false
                scanMessage = "扫描完成！找到 \(dataStore.gitRepositories.count) 个仓库"
            }
        }
    }

    // MARK: - Import History Section

    private var importHistorySection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("导入历史记录")
                .font(DesignSystem.Fonts.headline)
                .foregroundColor(themeManager.current.textPrimary)

            Text("批量导入历史 Git 提交记录到数据库")
                .font(DesignSystem.Fonts.body)
                .foregroundColor(themeManager.current.textSecondary)

            // 导入天数
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                HStack {
                    Text("导入天数:")
                        .font(DesignSystem.Fonts.body)
                        .foregroundColor(themeManager.current.textPrimary)

                    Spacer()

                    Text("\(Int(importDays)) 天")
                        .font(DesignSystem.Fonts.body)
                        .foregroundColor(DesignSystem.Colors.accent)
                        .padding(.horizontal, DesignSystem.Spacing.md)
                        .padding(.vertical, DesignSystem.Spacing.sm)
                        .background(DesignSystem.Colors.accent.opacity(0.1))
                        .cornerRadius(DesignSystem.Radius.small)
                }

                Slider(value: $importDays, in: 7...90, step: 1)
                    .accentColor(DesignSystem.Colors.accent)
            }

            // Git 用户名
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                Text("Git 用户名（多个用逗号分隔）:")
                    .font(DesignSystem.Fonts.body)
                    .foregroundColor(themeManager.current.textPrimary)

                TextField("如: user1,user2,user3", text: $importAuthors)
                    .textFieldStyle(.plain)
                    .font(DesignSystem.Fonts.body)
                    .foregroundColor(themeManager.current.textPrimary)
                    .padding(DesignSystem.Spacing.md)
                    .background(themeManager.current.secondaryBackground)
                    .cornerRadius(DesignSystem.Radius.medium)
            }

            // 选择仓库
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                HStack {
                    Text("选择要导入的仓库:")
                        .font(DesignSystem.Fonts.body)
                        .foregroundColor(themeManager.current.textPrimary)

                    Spacer()

                    Button(action: {
                        if selectedRepoIds.count == dataStore.gitRepositories.count {
                            selectedRepoIds.removeAll()
                        } else {
                            selectedRepoIds = Set(dataStore.gitRepositories.map { $0.id })
                        }
                    }) {
                        Text(selectedRepoIds.count == dataStore.gitRepositories.count ? "取消全选" : "全选")
                            .font(DesignSystem.Fonts.caption)
                            .foregroundColor(DesignSystem.Colors.accent)
                    }
                    .buttonStyle(.plain)
                }

                ScrollView {
                    VStack(spacing: DesignSystem.Spacing.xs) {
                        ForEach(dataStore.gitRepositories) { repo in
                            Button(action: {
                                if selectedRepoIds.contains(repo.id) {
                                    selectedRepoIds.remove(repo.id)
                                } else {
                                    selectedRepoIds.insert(repo.id)
                                }
                            }) {
                                HStack {
                                    Image(systemName: selectedRepoIds.contains(repo.id) ? "checkmark.square.fill" : "square")
                                        .foregroundColor(selectedRepoIds.contains(repo.id) ? DesignSystem.Colors.accent : themeManager.current.textTertiary)

                                    Text(repo.name)
                                        .font(DesignSystem.Fonts.body)
                                        .foregroundColor(themeManager.current.textPrimary)

                                    Spacer()
                                }
                                .padding(DesignSystem.Spacing.sm)
                                .background(selectedRepoIds.contains(repo.id) ? DesignSystem.Colors.accent.opacity(0.1) : themeManager.current.secondaryBackground)
                                .cornerRadius(DesignSystem.Radius.small)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .frame(maxHeight: 150)
            }

            // 导入按钮
            HStack {
                if isImporting {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.7)
                            Text(importProgress)
                                .font(DesignSystem.Fonts.caption)
                                .foregroundColor(themeManager.current.textSecondary)
                        }

                        if importedCount > 0 {
                            Text("已导入 \(importedCount) 条记录")
                                .font(DesignSystem.Fonts.caption)
                                .foregroundColor(DesignSystem.Colors.success)
                        }
                    }

                    Spacer()
                } else {
                    Button(action: startImport) {
                        HStack {
                            Image(systemName: "arrow.down.circle.fill")
                            Text("开始导入")
                        }
                        .font(DesignSystem.Fonts.body)
                        .foregroundColor(.white)
                        .padding(.horizontal, DesignSystem.Spacing.lg)
                        .padding(.vertical, DesignSystem.Spacing.md)
                        .background(DesignSystem.Colors.accent)
                        .cornerRadius(DesignSystem.Radius.medium)
                    }
                    .buttonStyle(.plain)
                    .disabled(selectedRepoIds.isEmpty || importAuthors.isEmpty)

                    Spacer()

                    Text("已选 \(selectedRepoIds.count) 个仓库")
                        .font(DesignSystem.Fonts.caption)
                        .foregroundColor(themeManager.current.textSecondary)
                }
            }
        }
        .padding(DesignSystem.Spacing.lg)
        .background(themeManager.current.cardBackground)
        .cornerRadius(DesignSystem.Radius.large)
    }

    // MARK: - Import Actions

    private func startImport() {
        guard !selectedRepoIds.isEmpty, !importAuthors.isEmpty else { return }

        isImporting = true
        importedCount = 0
        importProgress = "清空旧数据..."

        _Concurrency.Task {
            // 1. 先清空选中仓库的所有历史数据（全量导入）
            await MainActor.run {
                for repoId in selectedRepoIds {
                    dataStore.deleteGitCommitsForRepository(repoId)
                }
            }

            await MainActor.run {
                importProgress = "开始导入..."
            }

            let calendar = Calendar.current
            let endDate = Date()
            let startDate = calendar.date(byAdding: .day, value: -Int(importDays), to: endDate)!

            let authors = importAuthors.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            let selectedRepos = dataStore.gitRepositories.filter { selectedRepoIds.contains($0.id) }

            var totalImported = 0

            // 2. 导入新数据
            for (index, repo) in selectedRepos.enumerated() {
                await MainActor.run {
                    importProgress = "[\(index + 1)/\(selectedRepos.count)] \(repo.name)"
                }

                for author in authors {
                    do {
                        let commits = try await dataStore.gitManager.getCommits(
                            for: repo,
                            from: startDate,
                            to: endDate,
                            author: author.isEmpty ? nil : author
                        )

                        if !commits.isEmpty {
                            await MainActor.run {
                                dataStore.saveGitCommits(commits)
                                totalImported += commits.count
                                importedCount = totalImported
                            }
                        }
                    } catch {
                        print("[Import] Error importing \(repo.name): \(error)")
                    }
                }
            }

            // 3. 导入完成后刷新日历视图
            await MainActor.run {
                isImporting = false
                importProgress = "✅ 导入完成！共 \(totalImported) 条记录"

                // 通知 GitDashboardView 刷新数据
                NotificationCenter.default.post(name: NSNotification.Name("RefreshGitCalendar"), object: nil)

                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    importProgress = ""
                    importedCount = 0
                }
            }
        }
    }
}

// MARK: - Repository Setting Row

struct RepositorySettingRow: View {
    @EnvironmentObject var dataStore: DataStore
    @EnvironmentObject var themeManager: ThemeManager

    let repository: GitRepository

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: DesignSystem.Spacing.sm) {
                    Image(systemName: "folder.fill")
                        .font(.system(size: 14))
                        .foregroundColor(repository.isValidGitRepo ? DesignSystem.Colors.success : DesignSystem.Colors.danger)

                    Text(repository.name)
                        .font(DesignSystem.Fonts.body)
                        .foregroundColor(themeManager.current.textPrimary)
                }

                Text(repository.path)
                    .font(DesignSystem.Fonts.caption)
                    .foregroundColor(themeManager.current.textSecondary)
                    .lineLimit(1)

                if let lastScan = repository.lastScannedAt {
                    Text("最后扫描: \(lastScan.formatted(date: .abbreviated, time: .shortened))")
                        .font(.system(size: 10))
                        .foregroundColor(themeManager.current.textTertiary)
                }
            }

            Spacer()

            HStack(spacing: DesignSystem.Spacing.sm) {
                // 激活/停用按钮
                Button(action: {
                    var updated = repository
                    updated.isActive.toggle()
                    dataStore.updateGitRepository(updated)
                }) {
                    Image(systemName: repository.isActive ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 16))
                        .foregroundColor(repository.isActive ? DesignSystem.Colors.success : themeManager.current.textTertiary)
                }
                .buttonStyle(.plain)
                .help(repository.isActive ? "点击停用" : "点击激活")

                // 删除按钮
                if isHovered {
                    Button(action: {
                        dataStore.deleteGitRepository(repository)
                    }) {
                        Image(systemName: "trash")
                            .font(.system(size: 14))
                            .foregroundColor(DesignSystem.Colors.danger)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(isHovered ? themeManager.current.secondaryBackground : themeManager.current.cardBackground)
        .cornerRadius(DesignSystem.Radius.medium)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.1)) {
                isHovered = hovering
            }
        }
    }
}
