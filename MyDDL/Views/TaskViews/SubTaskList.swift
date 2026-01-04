import SwiftUI

// MARK: - Sub Task List
struct SubTaskList: View {
    @EnvironmentObject var dataStore: DataStore
    @EnvironmentObject var themeManager: ThemeManager

    let parentTask: Task

    @State private var showAddSubTaskSheet = false
    @State private var expandedSubTasks = true

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            // Header
            HStack {
                Button(action: { expandedSubTasks.toggle() }) {
                    HStack(spacing: 6) {
                        Image(systemName: expandedSubTasks ? "chevron.down" : "chevron.right")
                            .font(.system(size: 12, weight: .semibold))

                        Text("子任务")
                            .font(DesignSystem.Fonts.caption)

                        let subtasks = dataStore.subTasks(for: parentTask)
                        if !subtasks.isEmpty {
                            Text("(\(subtasks.filter { $0.status == .completed }.count)/\(subtasks.count))")
                                .font(DesignSystem.Fonts.caption)
                                .foregroundColor(themeManager.current.textTertiary)
                        }
                    }
                    .foregroundColor(themeManager.current.textSecondary)
                }
                .buttonStyle(.plain)

                Spacer()

                Button(action: { showAddSubTaskSheet = true }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(DesignSystem.Colors.accent)
                }
                .buttonStyle(.plain)
            }

            if expandedSubTasks {
                let subtasks = dataStore.subTasks(for: parentTask)

                if subtasks.isEmpty {
                    Text("暂无子任务")
                        .font(DesignSystem.Fonts.body)
                        .foregroundColor(themeManager.current.textTertiary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, DesignSystem.Spacing.lg)
                } else {
                    VStack(spacing: DesignSystem.Spacing.sm) {
                        ForEach(subtasks) { subtask in
                            SubTaskRow(task: subtask, parentTask: parentTask)
                        }
                    }
                }
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(themeManager.current.secondaryBackground)
        .cornerRadius(DesignSystem.Radius.medium)
        .sheet(isPresented: $showAddSubTaskSheet) {
            AddSubTaskSheet(parentTask: parentTask)
                .environmentObject(dataStore)
                .environmentObject(themeManager)
        }
    }
}

// MARK: - Sub Task Row
struct SubTaskRow: View {
    @EnvironmentObject var dataStore: DataStore
    @EnvironmentObject var themeManager: ThemeManager

    let task: Task
    let parentTask: Task

    @State private var isHovered = false
    @State private var showEditSheet = false

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            // Status Toggle
            Button(action: toggleStatus) {
                Image(systemName: task.status.icon)
                    .font(.system(size: 16))
                    .foregroundColor(statusColor)
            }
            .buttonStyle(.plain)

            // Title
            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .font(DesignSystem.Fonts.body)
                    .foregroundColor(themeManager.current.textPrimary)
                    .strikethrough(task.status == .completed)

                Text("\(task.startDate.formatted(date: .abbreviated, time: .omitted)) - \(task.endDate.formatted(date: .abbreviated, time: .omitted))")
                    .font(DesignSystem.Fonts.caption)
                    .foregroundColor(themeManager.current.textSecondary)
            }

            Spacer()

            // Actions
            if isHovered {
                HStack(spacing: 8) {
                    Button(action: { showEditSheet = true }) {
                        Image(systemName: "pencil")
                            .font(.system(size: 14))
                            .foregroundColor(DesignSystem.Colors.accent)
                    }
                    .buttonStyle(.plain)

                    Button(action: deleteSubTask) {
                        Image(systemName: "trash")
                            .font(.system(size: 14))
                            .foregroundColor(DesignSystem.Colors.danger)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(DesignSystem.Spacing.sm)
        .background(isHovered ? themeManager.current.cardBackground : Color.clear)
        .cornerRadius(DesignSystem.Radius.small)
        .onHover { hovering in
            isHovered = hovering
        }
        .sheet(isPresented: $showEditSheet) {
            EditSubTaskSheet(task: task)
                .environmentObject(dataStore)
                .environmentObject(themeManager)
        }
    }

    private var statusColor: Color {
        switch task.status {
        case .completed:
            return DesignSystem.Colors.success
        case .inProgress:
            return DesignSystem.Colors.warning
        case .notStarted:
            return themeManager.current.textTertiary
        }
    }

    private func toggleStatus() {
        var updatedTask = task
        switch task.status {
        case .notStarted:
            updatedTask.status = .inProgress
        case .inProgress:
            updatedTask.status = .completed
        case .completed:
            updatedTask.status = .notStarted
        }
        dataStore.updateTask(updatedTask)
    }

    private func deleteSubTask() {
        dataStore.deleteTask(task)
    }
}

// MARK: - Add Sub Task Sheet
struct AddSubTaskSheet: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var dataStore: DataStore
    @EnvironmentObject var themeManager: ThemeManager

    let parentTask: Task

    @State private var title = ""
    @State private var startDate = Date()
    @State private var endDate = Date()

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            Text("添加子任务")
                .font(DesignSystem.Fonts.headline)
                .foregroundColor(themeManager.current.textPrimary)

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                Text("任务标题")
                    .font(DesignSystem.Fonts.caption)
                    .foregroundColor(themeManager.current.textSecondary)

                TextField("输入任务标题", text: $title)
                    .textFieldStyle(.roundedBorder)
            }

            HStack(spacing: DesignSystem.Spacing.md) {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    Text("开始日期")
                        .font(DesignSystem.Fonts.caption)
                        .foregroundColor(themeManager.current.textSecondary)

                    DatePicker("", selection: $startDate, displayedComponents: .date)
                        .labelsHidden()
                }

                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    Text("结束日期")
                        .font(DesignSystem.Fonts.caption)
                        .foregroundColor(themeManager.current.textSecondary)

                    DatePicker("", selection: $endDate, displayedComponents: .date)
                        .labelsHidden()
                }
            }

            HStack(spacing: DesignSystem.Spacing.md) {
                Button("取消") {
                    dismiss()
                }
                .buttonStyle(.plain)
                .foregroundColor(themeManager.current.textSecondary)

                Button("添加") {
                    dataStore.addSubTask(
                        to: parentTask,
                        title: title,
                        startDate: startDate,
                        endDate: endDate
                    )
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(DesignSystem.Spacing.xl)
        .frame(width: 400)
        .background(themeManager.current.background)
        .onAppear {
            startDate = parentTask.startDate
            endDate = parentTask.endDate
        }
    }
}

// MARK: - Edit Sub Task Sheet
struct EditSubTaskSheet: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var dataStore: DataStore
    @EnvironmentObject var themeManager: ThemeManager

    let task: Task

    @State private var title = ""
    @State private var startDate = Date()
    @State private var endDate = Date()
    @State private var status: TaskStatus = .notStarted

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            Text("编辑子任务")
                .font(DesignSystem.Fonts.headline)
                .foregroundColor(themeManager.current.textPrimary)

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                Text("任务标题")
                    .font(DesignSystem.Fonts.caption)
                    .foregroundColor(themeManager.current.textSecondary)

                TextField("输入任务标题", text: $title)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                Text("任务状态")
                    .font(DesignSystem.Fonts.caption)
                    .foregroundColor(themeManager.current.textSecondary)

                Picker("", selection: $status) {
                    ForEach(TaskStatus.allCases, id: \.self) { status in
                        Text(status.displayName).tag(status)
                    }
                }
                .pickerStyle(.segmented)
            }

            HStack(spacing: DesignSystem.Spacing.md) {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    Text("开始日期")
                        .font(DesignSystem.Fonts.caption)
                        .foregroundColor(themeManager.current.textSecondary)

                    DatePicker("", selection: $startDate, displayedComponents: .date)
                        .labelsHidden()
                }

                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    Text("结束日期")
                        .font(DesignSystem.Fonts.caption)
                        .foregroundColor(themeManager.current.textSecondary)

                    DatePicker("", selection: $endDate, displayedComponents: .date)
                        .labelsHidden()
                }
            }

            HStack(spacing: DesignSystem.Spacing.md) {
                Button("取消") {
                    dismiss()
                }
                .buttonStyle(.plain)
                .foregroundColor(themeManager.current.textSecondary)

                Button("保存") {
                    var updatedTask = task
                    updatedTask.title = title
                    updatedTask.startDate = startDate
                    updatedTask.endDate = endDate
                    updatedTask.status = status
                    dataStore.updateTask(updatedTask)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(DesignSystem.Spacing.xl)
        .frame(width: 400)
        .background(themeManager.current.background)
        .onAppear {
            title = task.title
            startDate = task.startDate
            endDate = task.endDate
            status = task.status
        }
    }
}
