import Foundation
import SwiftUI

class DataStore: ObservableObject {
    @Published var tasks: [Task] = []
    @Published var projects: [Project] = []
    @Published var requirements: [Requirement] = []
    @Published var notes: [Note] = []
    @Published var gitRepositories: [GitRepository] = []
    @Published var cachedGitCommits: [GitCommit] = []

    private let db = DatabaseManager.shared
    let gitManager = GitManager.shared

    init() {
        loadData()
    }

    // MARK: - Data Persistence

    private func loadData() {
        tasks = db.fetchAllTasks()
        projects = db.fetchAllProjects()
        requirements = db.fetchAllRequirements()
        notes = db.fetchAllNotes()
        gitRepositories = db.fetchAllGitRepositories()

        // Add default project if none exist
        if projects.isEmpty {
            let defaultProject = Project(name: "默认项目", colorHex: "#5B8DEF")
            projects.append(defaultProject)
            db.saveProject(defaultProject)
        }
    }

    private func saveTasks() {
        db.saveTasks(tasks)
    }

    private func saveProjects() {
        db.saveProjects(projects)
    }

    private func saveRequirements() {
        db.saveRequirements(requirements)
    }

    // MARK: - Task CRUD

    func addTask(_ task: Task) {
        var newTask = task

        // Auto-create a corresponding requirement
        let requirement = Requirement(
            title: task.title,
            description: task.notes,
            status: .developing,
            priority: task.priority == .high ? .p1 : (task.priority == .medium ? .p2 : .p3),
            projectId: task.projectId,
            relatedTaskIds: [task.id]
        )
        requirements.append(requirement)
        db.saveRequirement(requirement)

        // Link task to the requirement
        newTask.requirementId = requirement.id
        tasks.append(newTask)
        db.saveTask(newTask)
    }

    // 添加任务但不自动创建需求（用于拆分任务等场景）
    func addTaskWithoutRequirement(_ task: Task) {
        tasks.append(task)
        db.saveTask(task)
    }

    func updateTask(_ task: Task) {
        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
            var updatedTask = task
            updatedTask.updatedAt = Date()
            tasks[index] = updatedTask
            db.saveTask(updatedTask)

            // Sync to requirement if linked
            if let reqId = task.requirementId,
               let reqIndex = requirements.firstIndex(where: { $0.id == reqId }) {
                var req = requirements[reqIndex]
                req.title = task.title
                req.description = task.notes
                req.projectId = task.projectId
                req.updatedAt = Date()
                requirements[reqIndex] = req
                db.saveRequirement(req)
            }
        }
    }

    func deleteTask(_ task: Task) {
        // Also delete the linked requirement
        if let reqId = task.requirementId {
            requirements.removeAll { $0.id == reqId }
            db.deleteRequirement(id: reqId)
        }

        tasks.removeAll { $0.id == task.id }
        db.deleteTask(id: task.id)
    }

    func deleteTask(id: UUID) {
        if let task = tasks.first(where: { $0.id == id }) {
            deleteTask(task)
        } else {
            tasks.removeAll { $0.id == id }
            db.deleteTask(id: id)
        }
    }

    // MARK: - Project CRUD

    func addProject(_ project: Project) {
        projects.append(project)
        db.saveProject(project)
    }

    // MARK: - SubTask Methods

    /// 获取任务的所有子任务
    func subTasks(for task: Task) -> [Task] {
        tasks.filter { $0.parentTaskId == task.id }
            .sorted { $0.createdAt < $1.createdAt }
    }

    /// 获取任务的父任务
    func parentTask(for task: Task) -> Task? {
        guard let parentId = task.parentTaskId else { return nil }
        return tasks.first { $0.id == parentId }
    }

    /// 检查任务是否有子任务
    func hasSubTasks(_ task: Task) -> Bool {
        tasks.contains { $0.parentTaskId == task.id }
    }

    /// 计算子任务完成进度 (0.0 - 1.0)
    func subTaskProgress(for task: Task) -> Double {
        let subtasks = subTasks(for: task)
        guard !subtasks.isEmpty else { return 0.0 }

        let completedCount = subtasks.filter { $0.status == .completed }.count
        return Double(completedCount) / Double(subtasks.count)
    }

    /// 添加子任务
    func addSubTask(to parentTask: Task, title: String, startDate: Date, endDate: Date) {
        let subTask = Task(
            title: title,
            startDate: startDate,
            endDate: endDate,
            projectId: parentTask.projectId,
            parentTaskId: parentTask.id,
            tags: parentTask.tags
        )
        addTaskWithoutRequirement(subTask)
    }

    /// 删除任务及其所有子任务
    func deleteTaskWithSubTasks(_ task: Task) {
        // 先删除所有子任务
        let subtasks = subTasks(for: task)
        for subtask in subtasks {
            deleteTask(subtask)
        }

        // 再删除父任务
        deleteTask(task)
    }

    // MARK: - Tag Methods

    /// 获取所有使用中的标签（去重）
    func allUsedTags() -> [String] {
        var tagSet = Set<String>()
        for task in tasks {
            task.tags.forEach { tagSet.insert($0) }
        }
        return Array(tagSet).sorted()
    }

    /// 按标签筛选任务
    func tasks(withTag tag: String) -> [Task] {
        tasks.filter { $0.tags.contains(tag) }
    }

    /// 按标签组合筛选（任务必须包含所有指定标签）
    func tasks(withTags tags: [String]) -> [Task] {
        guard !tags.isEmpty else { return tasks }
        return tasks.filter { task in
            tags.allSatisfy { tag in task.tags.contains(tag) }
        }
    }

    /// 按标签组合筛选（任务包含任一标签即可）
    func tasks(withAnyTag tags: [String]) -> [Task] {
        guard !tags.isEmpty else { return tasks }
        return tasks.filter { task in
            tags.contains(where: { tag in task.tags.contains(tag) })
        }
    }

    /// 为任务添加标签
    func addTag(_ tag: String, to task: Task) {
        guard let index = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        var updatedTask = tasks[index]

        if !updatedTask.tags.contains(tag) {
            updatedTask.tags.append(tag)
            updatedTask.updatedAt = Date()
            tasks[index] = updatedTask
            db.saveTask(updatedTask)
        }
    }

    /// 从任务中移除标签
    func removeTag(_ tag: String, from task: Task) {
        guard let index = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        var updatedTask = tasks[index]

        if let tagIndex = updatedTask.tags.firstIndex(of: tag) {
            updatedTask.tags.remove(at: tagIndex)
            updatedTask.updatedAt = Date()
            tasks[index] = updatedTask
            db.saveTask(updatedTask)
        }
    }

    // MARK: - Project CRUD (continued)

    func updateProject(_ project: Project) {
        if let index = projects.firstIndex(where: { $0.id == project.id }) {
            projects[index] = project
            db.saveProject(project)
        }
    }

    func deleteProject(_ project: Project) {
        // Remove all tasks associated with this project
        let tasksToDelete = tasks.filter { $0.projectId == project.id }
        for task in tasksToDelete {
            db.deleteTask(id: task.id)
        }
        tasks.removeAll { $0.projectId == project.id }

        projects.removeAll { $0.id == project.id }
        db.deleteProject(id: project.id)
    }

    // MARK: - Query Methods

    func tasks(for date: Date) -> [Task] {
        tasks.filter { $0.isOnDate(date) }
            .sorted { $0.priority.sortOrder < $1.priority.sortOrder }
    }

    func tasks(for project: Project) -> [Task] {
        tasks.filter { $0.projectId == project.id }
    }

    func tasks(in dateRange: ClosedRange<Date>) -> [Task] {
        tasks.filter { task in
            let taskRange = task.startDate...task.endDate
            return taskRange.overlaps(dateRange)
        }
    }

    func project(for task: Task) -> Project? {
        guard let projectId = task.projectId else { return nil }
        return projects.first { $0.id == projectId }
    }

    // MARK: - Statistics

    func totalHours(for date: Date) -> Double {
        tasks(for: date).reduce(0) { total, task in
            // For multi-day tasks, distribute hours evenly
            let hoursPerDay = task.estimatedHours / Double(task.daySpan)
            return total + hoursPerDay
        }
    }

    func totalHours(for dateRange: ClosedRange<Date>) -> Double {
        var total: Double = 0
        var currentDate = dateRange.lowerBound
        let calendar = Calendar.current

        while currentDate <= dateRange.upperBound {
            total += totalHours(for: currentDate)
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        }

        return total
    }

    func completedTasksCount(for date: Date) -> Int {
        tasks(for: date).filter { $0.status == .completed }.count
    }

    func overdueTasksCount() -> Int {
        tasks.filter { $0.isOverdue }.count
    }

    // MARK: - Task Movement

    func moveTask(_ task: Task, to newStartDate: Date) {
        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
            var updatedTask = task
            let duration = task.endDate.timeIntervalSince(task.startDate)
            updatedTask.startDate = newStartDate
            updatedTask.endDate = newStartDate.addingTimeInterval(duration)
            updatedTask.updatedAt = Date()
            tasks[index] = updatedTask
            db.saveTask(updatedTask)
        }
    }

    func resizeTask(_ task: Task, newEndDate: Date) {
        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
            var updatedTask = task
            updatedTask.endDate = max(newEndDate, task.startDate)
            updatedTask.updatedAt = Date()
            tasks[index] = updatedTask
            db.saveTask(updatedTask)
        }
    }

    // MARK: - Requirement CRUD

    func addRequirement(_ requirement: Requirement) {
        requirements.append(requirement)
        db.saveRequirement(requirement)
    }

    func updateRequirement(_ requirement: Requirement) {
        if let index = requirements.firstIndex(where: { $0.id == requirement.id }) {
            var updated = requirement
            updated.updatedAt = Date()
            requirements[index] = updated
            db.saveRequirement(updated)

            // Sync title/description back to linked task
            if let taskIndex = tasks.firstIndex(where: { $0.requirementId == requirement.id }) {
                var task = tasks[taskIndex]
                task.title = requirement.title
                task.notes = requirement.description
                task.projectId = requirement.projectId
                task.updatedAt = Date()
                tasks[taskIndex] = task
                db.saveTask(task)
            }
        }
    }

    func deleteRequirement(_ requirement: Requirement) {
        // Also delete linked task
        if let taskIndex = tasks.firstIndex(where: { $0.requirementId == requirement.id }) {
            let task = tasks[taskIndex]
            tasks.remove(at: taskIndex)
            db.deleteTask(id: task.id)
        }

        requirements.removeAll { $0.id == requirement.id }
        db.deleteRequirement(id: requirement.id)
    }

    func deleteRequirement(id: UUID) {
        if let req = requirements.first(where: { $0.id == id }) {
            deleteRequirement(req)
        } else {
            requirements.removeAll { $0.id == id }
            db.deleteRequirement(id: id)
        }
    }

    // MARK: - Requirement Query

    func requirements(for status: RequirementStatus) -> [Requirement] {
        requirements.filter { $0.status == status }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func requirements(for project: Project) -> [Requirement] {
        requirements.filter { $0.projectId == project.id }
    }

    func requirementsCount(for status: RequirementStatus) -> Int {
        requirements.filter { $0.status == status }.count
    }

    func project(for requirement: Requirement) -> Project? {
        guard let projectId = requirement.projectId else { return nil }
        return projects.first { $0.id == projectId }
    }

    func requirement(for task: Task) -> Requirement? {
        guard let requirementId = task.requirementId else { return nil }
        return requirements.first { $0.id == requirementId }
    }

    func tasks(for requirement: Requirement) -> [Task] {
        tasks.filter { $0.requirementId == requirement.id }
    }

    // MARK: - Note CRUD

    func addNote(_ note: Note) {
        notes.append(note)
        db.saveNote(note)
    }

    func updateNote(_ note: Note) {
        if let index = notes.firstIndex(where: { $0.id == note.id }) {
            let existing = notes[index]
            // 只比较 title、content 和 isPinned，不比较 rtfData（因为序列化每次可能不同）
            let contentChanged = existing.title != note.title ||
                                 existing.content != note.content ||
                                 existing.isPinned != note.isPinned

            debugLog("[DataStore] updateNote: contentChanged=\(contentChanged), title: '\(existing.title)' -> '\(note.title)', content: '\(existing.content.prefix(50))' -> '\(note.content.prefix(50))'")

            var updated = note
            if contentChanged {
                updated.updatedAt = Date()
                debugLog("[DataStore] updateNote: Content changed, updating updatedAt")
            } else {
                updated.updatedAt = existing.updatedAt
                debugLog("[DataStore] updateNote: No change, keeping original updatedAt")
            }
            notes[index] = updated
            db.saveNote(updated)
        }
    }

    func deleteNote(_ note: Note) {
        // Delete associated images
        let imagesToDelete = note.imageFilenames
        ImageManager.shared.deleteImages(filenames: imagesToDelete)

        notes.removeAll { $0.id == note.id }
        db.deleteNote(id: note.id)
    }

    func deleteNote(id: UUID) {
        // Find note first to get image filenames
        if let note = notes.first(where: { $0.id == id }) {
            deleteNote(note)
        } else {
            notes.removeAll { $0.id == id }
            db.deleteNote(id: id)
        }
    }

    /// 记录每个笔记在列表中的稳定位置（用于编辑时保持位置不变）
    private var notePositions: [UUID: Int] = [:]

    func sortedNotes(editing editingNoteId: UUID? = nil) -> [Note] {
        // 基础排序：置顶优先，然后按更新时间
        var result = notes.sorted { note1, note2 in
            if note1.isPinned != note2.isPinned {
                return note1.isPinned
            }
            return note1.updatedAt > note2.updatedAt
        }

        // 如果有正在编辑的笔记，检查它是否因为编辑而移动了
        if let editId = editingNoteId,
           let savedPosition = notePositions[editId],
           let currentIndex = result.firstIndex(where: { $0.id == editId }),
           currentIndex != savedPosition {
            // 把它移回原位置
            let note = result.remove(at: currentIndex)
            let targetIndex = min(savedPosition, result.count)
            result.insert(note, at: targetIndex)
        }

        // 更新位置缓存（排除正在编辑的笔记）
        for (index, note) in result.enumerated() {
            if note.id != editingNoteId {
                notePositions[note.id] = index
            }
        }
        // 如果没有正在编辑的笔记，也更新它的位置
        if editingNoteId == nil {
            for (index, note) in result.enumerated() {
                notePositions[note.id] = index
            }
        }

        return result
    }

    func toggleNotePin(_ note: Note) {
        if let index = notes.firstIndex(where: { $0.id == note.id }) {
            var updated = notes[index]
            updated.isPinned.toggle()
            // 不更新 updatedAt，保持笔记在组内的相对位置
            notes[index] = updated
            db.saveNote(updated)
        }
    }

    /// Clean up orphan images that are no longer referenced by any note
    func cleanOrphanImages() {
        var allReferencedFilenames: Set<String> = []
        for note in notes {
            allReferencedFilenames.formUnion(note.imageFilenames)
        }
        ImageManager.shared.cleanOrphanImages(referencedFilenames: allReferencedFilenames)
    }

    // MARK: - Import from JSON

    func importFromJSON(url: URL) {
        guard let data = try? Data(contentsOf: url),
              let jsonData = try? JSONDecoder().decode(JSONRequirementData.self, from: data) else {
            return
        }

        // 清除旧的已上线和已废弃需求
        let idsToRemove = requirements.filter { $0.status == .released || $0.status == .deprecated }.map { $0.id }
        for id in idsToRemove {
            db.deleteRequirement(id: id)
        }
        requirements.removeAll { $0.status == .released || $0.status == .deprecated }

        let baseDate = Date()

        // 导入已上线需求
        if let released = jsonData.released {
            for (index, item) in released.enumerated() {
                let priority = determinePriority(from: item.title)
                let createdAt = baseDate.addingTimeInterval(Double(index))

                let req = Requirement(
                    title: item.title,
                    description: item.description,
                    status: .released,
                    priority: priority,
                    projectId: nil,
                    relatedTaskIds: [],
                    createdAt: createdAt,
                    updatedAt: createdAt
                )
                requirements.append(req)
                db.saveRequirement(req)
            }
        }

        // 导入已废弃需求
        if let deprecated = jsonData.deprecated {
            for (index, item) in deprecated.enumerated() {
                let priority = determinePriority(from: item.title)
                let createdAt = baseDate.addingTimeInterval(Double(index))

                let req = Requirement(
                    title: item.title,
                    description: item.description,
                    status: .deprecated,
                    priority: priority,
                    projectId: nil,
                    relatedTaskIds: [],
                    createdAt: createdAt,
                    updatedAt: createdAt
                )
                requirements.append(req)
                db.saveRequirement(req)
            }
        }
    }

    private struct JSONRequirementData: Codable {
        let released: [JSONRequirementItem]?
        let deprecated: [JSONRequirementItem]?
    }

    private struct JSONRequirementItem: Codable {
        let title: String
        let description: String
    }

    private func determinePriority(from title: String) -> RequirementPriority {
        if title.contains("P0") {
            return .p0
        } else if title.contains("BUG") || title.contains("bug") || title.contains("fix") {
            return .p1
        } else if title.contains("优化") {
            return .p2
        } else {
            return .p2
        }
    }

    // MARK: - Git Repository Operations

    func addGitRepository(_ repository: GitRepository) {
        gitRepositories.append(repository)
        db.saveGitRepository(repository)
    }

    func updateGitRepository(_ repository: GitRepository) {
        if let index = gitRepositories.firstIndex(where: { $0.id == repository.id }) {
            var updated = repository
            updated.updatedAt = Date()
            gitRepositories[index] = updated
            db.saveGitRepository(updated)
        }
    }

    func deleteGitRepository(_ repository: GitRepository) {
        gitRepositories.removeAll { $0.id == repository.id }
        db.deleteGitRepository(id: repository.id)
    }

    func scanRepositoriesInPath(_ basePath: String) {
        let scannedRepos = gitManager.scanForRepositories(in: basePath)

        for scannedRepo in scannedRepos {
            // 检查是否已存在
            if !gitRepositories.contains(where: { $0.path == scannedRepo.path }) {
                addGitRepository(scannedRepo)
            }
        }
    }

    // MARK: - Git Commit Operations

    // 当前 Git 用户名（从 UserDefaults 读取）
    private var currentGitAuthor: String {
        UserDefaults.standard.string(forKey: "gitAuthorName") ?? ""
    }

    func fetchCommits(for repository: GitRepository, from startDate: Date, to endDate: Date) async {
        // 只从数据库读取，不再自动从git获取
        let commits = db.fetchGitCommits(for: repository.id, from: startDate, to: endDate)

        // 如果配置了作者过滤，应用过滤
        let author = currentGitAuthor
        let filteredCommits = author.isEmpty ? commits : commits.filter { $0.authorName.contains(author) }

        await MainActor.run {
            cachedGitCommits = filteredCommits
        }
    }

    func getTodayCommits(for repository: GitRepository) async -> [GitCommit] {
        // 从数据库读取今天的提交
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!

        let commits = db.fetchGitCommits(for: repository.id, from: today, to: tomorrow)

        // 如果配置了作者过滤，应用过滤
        let author = currentGitAuthor
        return author.isEmpty ? commits : commits.filter { $0.authorName.contains(author) }
    }

    func getAllTodayCommits() async -> [GitCommit] {
        // 从数据库读取今天的所有提交
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!

        var allCommits: [GitCommit] = []
        let activeRepos = gitRepositories.filter { $0.isActive }

        for repository in activeRepos {
            let commits = db.fetchGitCommits(for: repository.id, from: today, to: tomorrow)
            allCommits.append(contentsOf: commits)
        }

        // 如果配置了作者过滤，应用过滤
        let author = currentGitAuthor
        let filteredCommits = author.isEmpty ? allCommits : allCommits.filter { $0.authorName.contains(author) }

        return filteredCommits.sorted { $0.date > $1.date }
    }

    func getCommitsForDate(_ date: Date) async -> [GitCommit] {
        print("[DataStore] 🔍 getCommitsForDate 开始")

        // 在主线程先捕获所需数据
        let activeRepos = self.gitRepositories.filter { $0.isActive }
        let author = self.currentGitAuthor
        let dbManager = self.db

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        print("[DataStore] 🔍 活跃仓库: \(activeRepos.count), 开始后台查询")

        // 在后台线程执行数据库操作
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                print("[DataStore] 🔍 后台线程开始")
                var allCommits: [GitCommit] = []

                for repository in activeRepos {
                    let commits = dbManager.fetchGitCommits(for: repository.id, from: startOfDay, to: endOfDay)
                    allCommits.append(contentsOf: commits)
                }

                if !author.isEmpty {
                    allCommits = allCommits.filter { $0.authorName.contains(author) }
                }

                print("[DataStore] 🔍 查询完成: \(allCommits.count) 条")
                continuation.resume(returning: allCommits.sorted { $0.date > $1.date })
            }
        }
    }

    // 保存git提交记录到数据库
    func saveGitCommits(_ commits: [GitCommit]) {
        db.saveGitCommits(commits)
    }

    // 删除指定仓库的所有提交记录
    func deleteGitCommitsForRepository(_ repositoryId: UUID) {
        db.deleteGitCommitsForRepository(repositoryId)
    }

    // 获取指定日期范围的提交记录（不带过滤）
    func getCommitsForDateRange(repositoryId: UUID, from startDate: Date, to endDate: Date) -> [GitCommit] {
        return db.fetchGitCommits(for: repositoryId, from: startDate, to: endDate)
    }

    func getCommitStats(for repository: GitRepository, days: Int = 7) async -> GitCommitStats? {
        do {
            let endDate = Date()
            let startDate = Calendar.current.date(byAdding: .day, value: -days, to: endDate)!
            return try await gitManager.getCommitStats(for: repository, from: startDate, to: endDate)
        } catch {
            print("Get commit stats error: \(error)")
            return nil
        }
    }
}
