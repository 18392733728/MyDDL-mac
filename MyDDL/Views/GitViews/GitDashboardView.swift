import SwiftUI

struct GitDashboardView: View {
    @EnvironmentObject var dataStore: DataStore
    @EnvironmentObject var themeManager: ThemeManager

    @State private var todayCommits: [GitCommit] = []
    @State private var commitHistory: [Date: DayStats] = [:] // 最近30天的提交历史
    @State private var isLoading = false
    @State private var selectedRepositories: Set<UUID> = []
    @State private var showSettings = false
    @State private var selectedDate: Date?
    @State private var selectedDateCommits: [GitCommit] = []
    @State private var showDateCommitsSheet = false
    @State private var isLoadingDateCommits = false
    @State private var currentLoadTask: _Concurrency.Task<Void, Never>?
    @State private var repositoryMap: [UUID: GitRepository] = [:]  // 缓存仓库映射
    @AppStorage("gitAuthorName") private var gitAuthorName: String = "liyiyang5"

    // 统计信息缓存
    @State private var repoStats: [UUID: RepoStats] = [:]

    // 仓库排序
    @AppStorage("repoOrder") private var repoOrderData: Data = Data()
    @State private var repoOrder: [UUID] = []

    struct RepoStats {
        var todayCount: Int = 0
        var weekCount: Int = 0
        var monthCount: Int = 0
        var lastCommitDate: Date?
    }

    // 每日统计数据
    struct DayStats {
        var commitCount: Int = 0
        var linesAdded: Int = 0
        var linesDeleted: Int = 0

        var totalLines: Int {
            linesAdded + linesDeleted
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Git 提交记录")
                        .font(DesignSystem.Fonts.title)
                        .foregroundColor(themeManager.current.textPrimary)

                    Text("查看你的每日代码提交统计")
                        .font(DesignSystem.Fonts.caption)
                        .foregroundColor(themeManager.current.textTertiary)
                }

                Spacer()

                Button(action: refreshData) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 14))
                        .foregroundColor(themeManager.current.textSecondary)
                        .frame(width: 28, height: 28)
                        .background(themeManager.current.secondaryBackground)
                        .cornerRadius(DesignSystem.Radius.small)
                }
                .buttonStyle(.plain)
                .disabled(isLoading)

                Button(action: { showSettings = true }) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 14))
                        .foregroundColor(themeManager.current.textSecondary)
                        .frame(width: 28, height: 28)
                        .background(themeManager.current.secondaryBackground)
                        .cornerRadius(DesignSystem.Radius.small)
                }
                .buttonStyle(.plain)
            }
            .padding(DesignSystem.Spacing.xl)

            Divider()

            if dataStore.gitRepositories.isEmpty {
                emptyStateView
            } else {
                ScrollView {
                    VStack(spacing: DesignSystem.Spacing.lg) {
                        // 今日统计卡片
                        todayStatsCard

                        // 提交日历热力图
                        commitCalendarSection

                        // 仓库列表
                        repositoryListSection

                        // 今日提交记录
                        if !todayCommits.isEmpty {
                            todayCommitsSection
                        }
                    }
                    .padding(DesignSystem.Spacing.xl)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(themeManager.current.background)
        .sheet(isPresented: $showSettings) {
            GitRepositorySettingsView()
                .environmentObject(dataStore)
                .environmentObject(themeManager)
        }
        .popover(isPresented: $showDateCommitsSheet) {
            VStack(spacing: 0) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(selectedDate?.formatted(date: .abbreviated, time: .omitted) ?? "提交记录")
                            .font(DesignSystem.Fonts.headline)
                            .foregroundColor(themeManager.current.textPrimary)

                        Text("\(selectedDateCommits.count) 条提交")
                            .font(DesignSystem.Fonts.caption)
                            .foregroundColor(themeManager.current.textSecondary)
                    }

                    Spacer()

                    Button(action: { showDateCommitsSheet = false }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(themeManager.current.textTertiary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(DesignSystem.Spacing.lg)
                .background(themeManager.current.cardBackground)

                Divider()

                if isLoadingDateCommits {
                    VStack(spacing: DesignSystem.Spacing.md) {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("加载中...")
                            .font(DesignSystem.Fonts.body)
                            .foregroundColor(themeManager.current.textSecondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(themeManager.current.background)
                } else if selectedDateCommits.isEmpty {
                    VStack(spacing: DesignSystem.Spacing.md) {
                        Image(systemName: "tray")
                            .font(.system(size: 48))
                            .foregroundColor(themeManager.current.textTertiary.opacity(0.5))

                        Text("没有提交记录")
                            .font(DesignSystem.Fonts.body)
                            .foregroundColor(themeManager.current.textSecondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(themeManager.current.background)
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                            ForEach(selectedDateCommits) { commit in
                                DateCommitCard(commit: commit, repository: repositoryMap[commit.repositoryId])
                                    .environmentObject(themeManager)
                            }
                        }
                        .padding(DesignSystem.Spacing.lg)
                    }
                    .background(themeManager.current.background)
                }
            }
            .frame(width: 650, height: 550)
            .background(themeManager.current.background)
        }
        .onChange(of: showDateCommitsSheet) { _, isShowing in
            if !isShowing {
                // Popover关闭时，取消正在进行的任务并重置状态
                currentLoadTask?.cancel()
                currentLoadTask = nil
                isLoadingDateCommits = false
            }
        }
        .onAppear {
            loadTodayCommits()
            loadCommitHistory()

            // Load saved repository order
            if let decoded = try? JSONDecoder().decode([UUID].self, from: repoOrderData) {
                repoOrder = decoded
            }

            // 监听导入完成通知
            NotificationCenter.default.addObserver(
                forName: NSNotification.Name("RefreshGitCalendar"),
                object: nil,
                queue: .main
            ) { _ in
                loadTodayCommits()
                loadCommitHistory()
            }
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            Image(systemName: "folder.badge.gearshape")
                .font(.system(size: 48))
                .foregroundColor(themeManager.current.textTertiary.opacity(0.5))

            Text("还没有添加 Git 仓库")
                .font(DesignSystem.Fonts.headline)
                .foregroundColor(themeManager.current.textPrimary)

            Text("点击右上角的设置按钮添加代码仓库路径")
                .font(DesignSystem.Fonts.body)
                .foregroundColor(themeManager.current.textSecondary)

            Button(action: { showSettings = true }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("添加仓库")
                }
                .font(DesignSystem.Fonts.body)
                .foregroundColor(.white)
                .padding(.horizontal, DesignSystem.Spacing.lg)
                .padding(.vertical, DesignSystem.Spacing.md)
                .background(DesignSystem.Colors.accent)
                .cornerRadius(DesignSystem.Radius.medium)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Today Stats Card

    private var todayStatsCard: some View {
        HStack(spacing: DesignSystem.Spacing.xl) {
            StatBadge(
                icon: "folder.fill",
                value: "\(activeRepositoriesCount)",
                label: "活跃仓库",
                color: DesignSystem.Colors.warning
            )
        }
        .padding(DesignSystem.Spacing.lg)
        .background(themeManager.current.cardBackground)
        .cornerRadius(DesignSystem.Radius.large)
    }

    private var uniqueAuthors: Int {
        Set(todayCommits.map { $0.authorName }).count
    }

    private var activeRepositoriesCount: Int {
        dataStore.gitRepositories.filter { $0.isActive }.count
    }

    // MARK: - Commit Calendar Section

    private var commitCalendarSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            HStack {
                Text("提交日历（最近30天）")
                    .font(DesignSystem.Fonts.headline)
                    .foregroundColor(themeManager.current.textPrimary)

                if !selectedRepositories.isEmpty {
                    Text("· 已筛选 \(selectedRepositories.count) 个仓库")
                        .font(DesignSystem.Fonts.caption)
                        .foregroundColor(themeManager.current.textSecondary)
                }
            }

            CommitCalendarView(
                commitHistory: commitHistory,
                onDateTapped: { date in
                    handleDateTapped(date)
                }
            )
        }
        .padding(DesignSystem.Spacing.lg)
        .background(themeManager.current.cardBackground)
        .cornerRadius(DesignSystem.Radius.large)
    }

    // MARK: - Repository List Section

    private var repositoryListSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            HStack {
                Text("仓库列表")
                    .font(DesignSystem.Fonts.headline)
                    .foregroundColor(themeManager.current.textPrimary)

                if !selectedRepositories.isEmpty {
                    Button(action: {
                        selectedRepositories.removeAll()
                        loadCommitHistory()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 12))
                            Text("清空筛选 (\(selectedRepositories.count))")
                                .font(DesignSystem.Fonts.caption)
                        }
                        .foregroundColor(DesignSystem.Colors.warning)
                        .padding(.horizontal, DesignSystem.Spacing.sm)
                        .padding(.vertical, 4)
                        .background(DesignSystem.Colors.warning.opacity(0.1))
                        .cornerRadius(DesignSystem.Radius.small)
                    }
                    .buttonStyle(.plain)
                }

                Spacer()

                Button(action: { showSettings = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 14))
                        Text("添加仓库")
                            .font(DesignSystem.Fonts.caption)
                    }
                    .foregroundColor(DesignSystem.Colors.accent)
                    .padding(.horizontal, DesignSystem.Spacing.md)
                    .padding(.vertical, DesignSystem.Spacing.sm)
                    .background(DesignSystem.Colors.accent.opacity(0.1))
                    .cornerRadius(DesignSystem.Radius.medium)
                }
                .buttonStyle(.plain)
            }

            VStack(spacing: DesignSystem.Spacing.sm) {
                ForEach(sortedRepositories) { repository in
                    RepositoryCard(
                        repository: repository,
                        stats: repoStats[repository.id],
                        isSelected: selectedRepositories.contains(repository.id),
                        onTap: {
                            if selectedRepositories.contains(repository.id) {
                                selectedRepositories.remove(repository.id)
                            } else {
                                selectedRepositories.insert(repository.id)
                            }
                            loadCommitHistory()
                        }
                    )
                    .onDrag {
                        return NSItemProvider(object: repository.id.uuidString as NSString)
                    }
                    .onDrop(of: [.text], delegate: RepositoryDropDelegate(
                        repository: repository,
                        repositories: sortedRepositories,
                        repoOrder: $repoOrder,
                        repoOrderData: $repoOrderData
                    ))
                }
            }
        }
        .padding(DesignSystem.Spacing.lg)
        .background(themeManager.current.cardBackground)
        .cornerRadius(DesignSystem.Radius.large)
    }

    private var sortedRepositories: [GitRepository] {
        let repos = dataStore.gitRepositories
        if repoOrder.isEmpty {
            return repos
        }

        let orderedRepos = repoOrder.compactMap { id in
            repos.first { $0.id == id }
        }

        let remainingRepos = repos.filter { repo in
            !repoOrder.contains(repo.id)
        }

        return orderedRepos + remainingRepos
    }

    // MARK: - Today Commits Section

    private var todayCommitsSection: some View {
        let filteredCommits = selectedRepositories.isEmpty
            ? todayCommits
            : todayCommits.filter { selectedRepositories.contains($0.repositoryId) }

        return VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            HStack {
                Text("今日提交 (\(filteredCommits.count))")
                    .font(DesignSystem.Fonts.headline)
                    .foregroundColor(themeManager.current.textPrimary)

                if !selectedRepositories.isEmpty {
                    let repoNames = selectedRepositories.compactMap { id in
                        dataStore.gitRepositories.first(where: { $0.id == id })?.name
                    }.joined(separator: ", ")

                    Text("· \(repoNames)")
                        .font(DesignSystem.Fonts.caption)
                        .foregroundColor(themeManager.current.textSecondary)
                        .lineLimit(1)
                }
            }

            VStack(spacing: DesignSystem.Spacing.sm) {
                ForEach(filteredCommits) { commit in
                    CommitRow(commit: commit)
                }
            }
        }
        .padding(DesignSystem.Spacing.lg)
        .background(themeManager.current.cardBackground)
        .cornerRadius(DesignSystem.Radius.large)
    }

    // MARK: - Actions

    private func loadTodayCommits() {
        guard !isLoading else { return }

        isLoading = true
        _Concurrency.Task {
            let commits = await dataStore.getAllTodayCommits()
            await MainActor.run {
                todayCommits = commits
                isLoading = false
                updateRepoStats()
            }
        }
    }

    private func updateRepoStats() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: today)!
        let monthAgo = calendar.date(byAdding: .day, value: -30, to: today)!

        var newStats: [UUID: RepoStats] = [:]

        for repo in dataStore.gitRepositories where repo.isActive {
            let todayCount = todayCommits.filter { $0.repositoryId == repo.id }.count

            let weekCommits = dataStore.getCommitsForDateRange(
                repositoryId: repo.id,
                from: weekAgo,
                to: Date()
            )

            let monthCommits = dataStore.getCommitsForDateRange(
                repositoryId: repo.id,
                from: monthAgo,
                to: Date()
            )

            let lastCommit = monthCommits.max(by: { $0.date < $1.date })

            newStats[repo.id] = RepoStats(
                todayCount: todayCount,
                weekCount: weekCommits.count,
                monthCount: monthCommits.count,
                lastCommitDate: lastCommit?.date
            )
        }

        repoStats = newStats
    }

    private func loadCommitHistory() {
        _Concurrency.Task {
            print("[GitDashboard] 📊 从数据库加载最近30天的提交统计...")
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())
            let startDate = calendar.date(byAdding: .day, value: -30, to: today)!

            var history: [Date: DayStats] = [:]

            // 根据是否有选中仓库进行过滤
            let reposToQuery = selectedRepositories.isEmpty
                ? dataStore.gitRepositories.filter { $0.isActive }
                : dataStore.gitRepositories.filter { $0.isActive && selectedRepositories.contains($0.id) }

            // 从数据库读取已保存的提交记录
            for repository in reposToQuery {
                let commits = dataStore.getCommitsForDateRange(
                    repositoryId: repository.id,
                    from: startDate,
                    to: Date()
                )

                // 如果配置了作者过滤，应用过滤
                let author = gitAuthorName
                let filteredCommits = author.isEmpty ? commits : commits.filter { $0.authorName.contains(author) }

                for commit in filteredCommits {
                    let commitDay = calendar.startOfDay(for: commit.date)
                    var stats = history[commitDay, default: DayStats()]
                    stats.commitCount += 1
                    stats.linesAdded += commit.linesAdded
                    stats.linesDeleted += commit.linesDeleted
                    history[commitDay] = stats
                }
            }

            let totalCommits = history.values.reduce(0) { $0 + $1.commitCount }
            let totalLines = history.values.reduce(0) { $0 + $1.totalLines }
            print("[GitDashboard] ✅ 从数据库加载了 \(totalCommits) 条提交统计, 总行数变更: \(totalLines)")

            await MainActor.run {
                commitHistory = history
            }
        }
    }

    private func refreshData() {
        loadTodayCommits()
        loadCommitHistory()
    }

    private func handleDateTapped(_ date: Date) {
        // 直接同步加载，避免所有线程问题
        let activeRepos = dataStore.gitRepositories.filter { $0.isActive }
        let author = UserDefaults.standard.string(forKey: "gitAuthorName") ?? ""
        let dbManager = DatabaseManager.shared

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        var allCommits: [GitCommit] = []
        for repository in activeRepos {
            let commits = dbManager.fetchGitCommits(for: repository.id, from: startOfDay, to: endOfDay)
            allCommits.append(contentsOf: commits)
        }

        if !author.isEmpty {
            allCommits = allCommits.filter { $0.authorName.contains(author) }
        }

        // 预先计算仓库映射，避免在 popover body 中重复计算
        repositoryMap = Dictionary(uniqueKeysWithValues: dataStore.gitRepositories.map { ($0.id, $0) })

        selectedDate = date
        selectedDateCommits = allCommits.sorted { $0.date > $1.date }
        isLoadingDateCommits = false
        showDateCommitsSheet = true
    }
}

// MARK: - Repository Drop Delegate

struct RepositoryDropDelegate: DropDelegate {
    let repository: GitRepository
    let repositories: [GitRepository]
    @Binding var repoOrder: [UUID]
    @Binding var repoOrderData: Data

    func performDrop(info: DropInfo) -> Bool {
        return true
    }

    func dropEntered(info: DropInfo) {
        guard let draggedId = info.itemProviders(for: [.text]).first else { return }

        draggedId.loadItem(forTypeIdentifier: "public.text", options: nil) { (data, error) in
            guard let data = data as? Data,
                  let idString = String(data: data, encoding: .utf8),
                  let draggedUUID = UUID(uuidString: idString) else { return }

            DispatchQueue.main.async {
                let fromIndex = repositories.firstIndex(where: { $0.id == draggedUUID })
                let toIndex = repositories.firstIndex(where: { $0.id == repository.id })

                guard let from = fromIndex, let to = toIndex, from != to else { return }

                // Update order
                var newOrder = repoOrder.isEmpty ? repositories.map { $0.id } : repoOrder
                newOrder.move(fromOffsets: IndexSet(integer: from), toOffset: to > from ? to + 1 : to)
                repoOrder = newOrder

                // Persist to UserDefaults
                if let encoded = try? JSONEncoder().encode(newOrder) {
                    repoOrderData = encoded
                }
            }
        }
    }
}

// MARK: - Stat Badge

struct StatBadge: View {
    @EnvironmentObject var themeManager: ThemeManager

    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            HStack(spacing: DesignSystem.Spacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(color)

                Text(value)
                    .font(DesignSystem.Fonts.headline)
                    .foregroundColor(themeManager.current.textPrimary)
            }

            Text(label)
                .font(DesignSystem.Fonts.caption)
                .foregroundColor(themeManager.current.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(DesignSystem.Spacing.md)
        .background(themeManager.current.secondaryBackground)
        .cornerRadius(DesignSystem.Radius.medium)
    }
}

// MARK: - Repository Card

struct RepositoryCard: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var dataStore: DataStore

    let repository: GitRepository
    let stats: GitDashboardView.RepoStats?
    let isSelected: Bool
    let onTap: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: DesignSystem.Spacing.sm) {
                    Image(systemName: "folder.fill")
                        .font(.system(size: 14))
                        .foregroundColor(DesignSystem.Colors.accent)

                    Text(repository.name)
                        .font(DesignSystem.Fonts.body)
                        .foregroundColor(themeManager.current.textPrimary)

                    if !repository.isActive {
                        Text("已停用")
                            .font(DesignSystem.Fonts.caption)
                            .foregroundColor(themeManager.current.textTertiary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(themeManager.current.textTertiary.opacity(0.2))
                            .cornerRadius(4)
                    }
                }

                Text(repository.path)
                    .font(DesignSystem.Fonts.caption)
                    .foregroundColor(themeManager.current.textSecondary)
                    .lineLimit(1)

                // Statistics
                if let stats = stats {
                    HStack(spacing: DesignSystem.Spacing.md) {
                        // Today commits
                        if stats.todayCount > 0 {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.up.doc.fill")
                                    .font(.system(size: 10))
                                Text("今天 \(stats.todayCount)")
                                    .font(.system(size: 10))
                            }
                            .foregroundColor(DesignSystem.Colors.success)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(DesignSystem.Colors.success.opacity(0.1))
                            .cornerRadius(4)
                        }

                        // Week commits
                        HStack(spacing: 4) {
                            Image(systemName: "calendar")
                                .font(.system(size: 10))
                            Text("本周 \(stats.weekCount)")
                                .font(.system(size: 10))
                        }
                        .foregroundColor(themeManager.current.textSecondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(themeManager.current.textTertiary.opacity(0.1))
                        .cornerRadius(4)

                        // Last commit
                        if let lastDate = stats.lastCommitDate {
                            HStack(spacing: 4) {
                                Image(systemName: "clock")
                                    .font(.system(size: 10))
                                Text(lastDate.timeAgo())
                                    .font(.system(size: 10))
                            }
                            .foregroundColor(themeManager.current.textTertiary)
                        }
                    }
                }
            }

            Spacer()

            HStack(spacing: DesignSystem.Spacing.sm) {
                if isHovered {
                    Button(action: {
                        dataStore.deleteGitRepository(repository)
                    }) {
                        Image(systemName: "trash")
                            .font(.system(size: 14))
                            .foregroundColor(DesignSystem.Colors.danger)
                            .frame(width: 28, height: 28)
                            .background(DesignSystem.Colors.danger.opacity(0.1))
                            .cornerRadius(DesignSystem.Radius.small)
                    }
                    .buttonStyle(.plain)
                    .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(
            isSelected ? DesignSystem.Colors.accent.opacity(0.1) :
            (isHovered ? themeManager.current.secondaryBackground : themeManager.current.cardBackground)
        )
        .cornerRadius(DesignSystem.Radius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.medium)
                .stroke(isSelected ? DesignSystem.Colors.accent : Color.clear, lineWidth: 2)
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.1)) {
                isHovered = hovering
            }
        }
        .onTapGesture {
            onTap()
        }
        .contextMenu {
            Button(action: {
                NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: repository.path)
            }) {
                Text("在 Finder 中显示")
                Image(systemName: "folder")
            }

            Button(action: {
                openInTerminal(path: repository.path)
            }) {
                Text("在终端中打开")
                Image(systemName: "terminal")
            }

            Divider()

            if let remoteURL = repository.remoteURL {
                Button(action: {
                    if let url = URL(string: remoteURL) {
                        NSWorkspace.shared.open(url)
                    }
                }) {
                    Text("打开远程仓库")
                    Image(systemName: "arrow.up.forward.square")
                }

                Divider()
            }

            Button(action: {
                var updated = repository
                updated.isActive.toggle()
                dataStore.updateGitRepository(updated)
            }) {
                Text(repository.isActive ? "停用" : "激活")
                Image(systemName: repository.isActive ? "pause.circle" : "play.circle")
            }

            Button(action: {
                dataStore.deleteGitRepository(repository)
            }) {
                Text("删除")
                Image(systemName: "trash")
            }
        }
    }

    private func openInTerminal(path: String) {
        let script = """
        tell application "Terminal"
            activate
            set newTab to do script "cd '\(path)'; clear"
        end tell
        """

        if let scriptObject = NSAppleScript(source: script) {
            var error: NSDictionary?
            scriptObject.executeAndReturnError(&error)
            if let error = error {
                print("Error opening terminal: \(error)")
            }
        }
    }
}

// MARK: - Commit Row

struct CommitRow: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var dataStore: DataStore

    let commit: GitCommit

    private var repository: GitRepository? {
        dataStore.gitRepositories.first { $0.id == commit.repositoryId }
    }

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            // 头像
            Circle()
                .fill(DesignSystem.Colors.accent.opacity(0.2))
                .frame(width: 36, height: 36)
                .overlay(
                    Text(commit.authorName.prefix(1))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(DesignSystem.Colors.accent)
                )

            VStack(alignment: .leading, spacing: 6) {
                // 完整的提交消息
                Text(commit.message)
                    .font(DesignSystem.Fonts.body)
                    .foregroundColor(themeManager.current.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: DesignSystem.Spacing.sm) {
                    if let repo = repository {
                        HStack(spacing: 4) {
                            Image(systemName: "folder.fill")
                                .font(.system(size: 10))
                            Text(repo.name)
                        }
                        .font(DesignSystem.Fonts.caption)
                        .foregroundColor(themeManager.current.textSecondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(themeManager.current.textTertiary.opacity(0.1))
                        .cornerRadius(4)
                    }

                    // 代码行数变更
                    if commit.linesAdded > 0 || commit.linesDeleted > 0 {
                        HStack(spacing: 4) {
                            if commit.linesAdded > 0 {
                                Text("+\(commit.linesAdded)")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(DesignSystem.Colors.success)
                            }
                            if commit.linesDeleted > 0 {
                                Text("-\(commit.linesDeleted)")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(DesignSystem.Colors.danger)
                            }
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(themeManager.current.textTertiary.opacity(0.1))
                        .cornerRadius(4)
                    }

                    Text(commit.authorName)
                        .font(DesignSystem.Fonts.caption)
                        .foregroundColor(themeManager.current.textSecondary)

                    Text("•")
                        .foregroundColor(themeManager.current.textTertiary)

                    Text(commit.shortHash)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(themeManager.current.textTertiary)

                    Text("•")
                        .foregroundColor(themeManager.current.textTertiary)

                    Text(commit.date.formatted(date: .omitted, time: .shortened))
                        .font(DesignSystem.Fonts.caption)
                        .foregroundColor(themeManager.current.textTertiary)
                }
            }

            Spacer()
        }
        .padding(DesignSystem.Spacing.md)
        .background(themeManager.current.cardBackground)
        .cornerRadius(DesignSystem.Radius.medium)
    }
}

// MARK: - Commit Calendar View

struct CommitCalendarView: View {
    @EnvironmentObject var themeManager: ThemeManager

    let commitHistory: [Date: GitDashboardView.DayStats]
    let onDateTapped: (Date) -> Void

    private let columns = 7

    // 日历单元格：可能是日期或空白占位符
    private enum CalendarCell: Identifiable {
        case date(Date)
        case placeholder

        var id: String {
            switch self {
            case .date(let date):
                return date.timeIntervalSince1970.description
            case .placeholder:
                return UUID().uuidString
            }
        }
    }

    private var calendarCells: [CalendarCell] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // 获取最近30天的日期
        let dates = (0..<30).reversed().compactMap { offset -> Date? in
            calendar.date(byAdding: .day, value: -offset, to: today)
        }

        guard let firstDate = dates.first else { return [] }

        // 获取第一天是星期几 (1 = 周一, 7 = 周日)
        let weekday = calendar.component(.weekday, from: firstDate)
        // Swift的weekday: 1=周日, 2=周一, ..., 7=周六
        // 我们需要转换为: 周一=0, 周二=1, ..., 周日=6
        let offset = weekday == 1 ? 6 : weekday - 2

        // 创建占位符
        var cells: [CalendarCell] = []
        for _ in 0..<offset {
            cells.append(.placeholder)
        }

        // 添加实际日期
        for date in dates {
            cells.append(.date(date))
        }

        return cells
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            // 星期头
            HStack(spacing: 2) {
                ForEach(["一", "二", "三", "四", "五", "六", "日"], id: \.self) { day in
                    Text(day)
                        .font(.system(size: 10))
                        .foregroundColor(themeManager.current.textTertiary)
                        .frame(maxWidth: .infinity)
                }
            }

            // 日历网格
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: columns), spacing: 2) {
                ForEach(calendarCells) { cell in
                    switch cell {
                    case .date(let date):
                        dayCell(for: date)
                    case .placeholder:
                        placeholderCell()
                    }
                }
            }

            // 图例
            HStack(spacing: DesignSystem.Spacing.md) {
                Text("代码行数：")
                    .font(DesignSystem.Fonts.caption)
                    .foregroundColor(themeManager.current.textSecondary)

                HStack(spacing: 4) {
                    ForEach([0, 50, 200, 500], id: \.self) { lines in
                        HStack(spacing: 2) {
                            Rectangle()
                                .fill(colorForLines(lines))
                                .frame(width: 12, height: 12)
                                .cornerRadius(2)
                            if lines > 0 {
                                Text("\(lines)+")
                                    .font(.system(size: 9))
                                    .foregroundColor(themeManager.current.textTertiary)
                            } else {
                                Text("0")
                                    .font(.system(size: 9))
                                    .foregroundColor(themeManager.current.textTertiary)
                            }
                        }
                    }
                }
            }
            .padding(.top, DesignSystem.Spacing.sm)
        }
    }

    private func placeholderCell() -> some View {
        VStack(spacing: 2) {
            Rectangle()
                .fill(Color.clear)
                .frame(height: 30)

            Text("")
                .font(.system(size: 9))
        }
    }

    private func dayCell(for date: Date) -> some View {
        let stats = commitHistory[date] ?? GitDashboardView.DayStats()
        let isToday = Calendar.current.isDateInToday(date)

        return VStack(spacing: 2) {
            Rectangle()
                .fill(colorForLines(stats.totalLines))
                .frame(height: 30)
                .cornerRadius(4)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(isToday ? DesignSystem.Colors.accent : Color.clear, lineWidth: 2)
                )
                .overlay(
                    Group {
                        if stats.totalLines > 0 {
                            Text("\(stats.totalLines)")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundColor(stats.totalLines > 200 ? .white : themeManager.current.textSecondary)
                        }
                    }
                )
                // 禁用点击功能，避免卡死问题

            Text("\(Calendar.current.component(.day, from: date))")
                .font(.system(size: 9))
                .foregroundColor(themeManager.current.textTertiary)
        }
    }

    private func colorForLines(_ lines: Int) -> Color {
        if lines == 0 {
            return themeManager.current.textTertiary.opacity(0.1)
        } else if lines < 50 {
            return DesignSystem.Colors.success.opacity(0.3)
        } else if lines < 200 {
            return DesignSystem.Colors.success.opacity(0.6)
        } else if lines < 500 {
            return DesignSystem.Colors.success.opacity(0.8)
        } else {
            return DesignSystem.Colors.success
        }
    }
}

// MARK: - Date Commits Sheet

struct DateCommitsSheet: View {
    let date: Date
    let commits: [GitCommit]
    let repositories: [GitRepository]
    let isLoading: Bool

    var body: some View {
        Text("测试: 找到 \(commits.count) 条提交")
            .font(.title)
            .frame(width: 400, height: 300)
    }
}

// MARK: - Date Commit Row

struct DateCommitRow: View {
    @EnvironmentObject var themeManager: ThemeManager

    let commit: GitCommit
    let repositories: [GitRepository]

    private var repository: GitRepository? {
        repositories.first { $0.id == commit.repositoryId }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            // 提交消息
            Text(commit.message)
                .font(DesignSystem.Fonts.body)
                .foregroundColor(themeManager.current.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: DesignSystem.Spacing.md) {
                // 仓库名
                if let repo = repository {
                    HStack(spacing: 4) {
                        Image(systemName: "folder.fill")
                            .font(.system(size: 10))
                        Text(repo.name)
                    }
                    .font(DesignSystem.Fonts.caption)
                    .foregroundColor(themeManager.current.textSecondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(themeManager.current.textTertiary.opacity(0.1))
                    .cornerRadius(4)
                }

                // 作者
                Text(commit.authorName)
                    .font(DesignSystem.Fonts.caption)
                    .foregroundColor(themeManager.current.textSecondary)

                Text("•")
                    .foregroundColor(themeManager.current.textTertiary)

                // Commit hash
                Text(commit.shortHash)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(themeManager.current.textTertiary)

                Text("•")
                    .foregroundColor(themeManager.current.textTertiary)

                // 时间
                Text(commit.date.formatted(date: .omitted, time: .shortened))
                    .font(DesignSystem.Fonts.caption)
                    .foregroundColor(themeManager.current.textTertiary)

                Spacer()

                // 跳转按钮
                if let repo = repository, let remoteURL = repo.remoteURL,
                   let webURL = commit.webURL(remoteURL: remoteURL) {
                    Button(action: {
                        if let url = URL(string: webURL) {
                            NSWorkspace.shared.open(url)
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up.forward.square")
                                .font(.system(size: 12))
                            Text("查看")
                                .font(DesignSystem.Fonts.caption)
                        }
                        .foregroundColor(DesignSystem.Colors.accent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(DesignSystem.Colors.accent.opacity(0.1))
                        .cornerRadius(DesignSystem.Radius.small)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(themeManager.current.cardBackground)
        .cornerRadius(DesignSystem.Radius.medium)
    }
}

// MARK: - Date Commit Card (for popover)

struct DateCommitCard: View {
    @EnvironmentObject var themeManager: ThemeManager

    let commit: GitCommit
    let repository: GitRepository?  // 作为参数传入，避免重复计算

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            // 头像
            Circle()
                .fill(DesignSystem.Colors.accent.opacity(0.2))
                .frame(width: 36, height: 36)
                .overlay(
                    Text(commit.authorName.prefix(1))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(DesignSystem.Colors.accent)
                )

            VStack(alignment: .leading, spacing: 6) {
                // 提交消息
                Text(commit.message)
                    .font(DesignSystem.Fonts.body)
                    .foregroundColor(themeManager.current.textPrimary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: DesignSystem.Spacing.sm) {
                    // 仓库名
                    if let repo = repository {
                        HStack(spacing: 4) {
                            Image(systemName: "folder.fill")
                                .font(.system(size: 10))
                            Text(repo.name)
                        }
                        .font(DesignSystem.Fonts.caption)
                        .foregroundColor(themeManager.current.textSecondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(themeManager.current.textTertiary.opacity(0.1))
                        .cornerRadius(4)
                    }

                    // 代码行数变更
                    if commit.linesAdded > 0 || commit.linesDeleted > 0 {
                        HStack(spacing: 4) {
                            if commit.linesAdded > 0 {
                                Text("+\(commit.linesAdded)")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(DesignSystem.Colors.success)
                            }
                            if commit.linesDeleted > 0 {
                                Text("-\(commit.linesDeleted)")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(DesignSystem.Colors.danger)
                            }
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(themeManager.current.textTertiary.opacity(0.1))
                        .cornerRadius(4)
                    }

                    // 作者名
                    Text(commit.authorName)
                        .font(DesignSystem.Fonts.caption)
                        .foregroundColor(themeManager.current.textSecondary)

                    Text("•")
                        .foregroundColor(themeManager.current.textTertiary)

                    // Hash
                    Text(commit.shortHash)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(themeManager.current.textTertiary)

                    Text("•")
                        .foregroundColor(themeManager.current.textTertiary)

                    // 时间
                    Text(commit.date.formatted(date: .omitted, time: .shortened))
                        .font(DesignSystem.Fonts.caption)
                        .foregroundColor(themeManager.current.textTertiary)
                }
            }

            Spacer()

            // 查看按钮
            if let repo = repository,
               let remoteURL = repo.remoteURL,
               let webURL = commit.webURL(remoteURL: remoteURL) {
                Button(action: {
                    if let url = URL(string: webURL) {
                        NSWorkspace.shared.open(url)
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.forward.square")
                            .font(.system(size: 12))
                        Text("查看")
                            .font(DesignSystem.Fonts.caption)
                    }
                    .foregroundColor(DesignSystem.Colors.accent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(DesignSystem.Colors.accent.opacity(0.1))
                    .cornerRadius(DesignSystem.Radius.small)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(themeManager.current.cardBackground)
        .cornerRadius(DesignSystem.Radius.medium)
    }
}

// MARK: - Date Extension

extension Date {
    func timeAgo() -> String {
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: self, to: now)

        if let year = components.year, year > 0 {
            return "\(year)年前"
        }

        if let month = components.month, month > 0 {
            return "\(month)月前"
        }

        if let day = components.day, day > 0 {
            return "\(day)天前"
        }

        if let hour = components.hour, hour > 0 {
            return "\(hour)小时前"
        }

        if let minute = components.minute, minute > 0 {
            return "\(minute)分钟前"
        }

        return "刚刚"
    }
}
