import SwiftUI

// 自定义日历选择器
struct CustomDatePicker: View {
    @Binding var selectedDate: Date
    let minDate: Date?
    let accentColor: Color
    let icon: String

    @State private var showingCalendar = false
    @State private var displayMonth: Date

    init(selectedDate: Binding<Date>, minDate: Date? = nil, accentColor: Color = DesignSystem.Colors.accent, icon: String = "calendar") {
        self._selectedDate = selectedDate
        self.minDate = minDate
        self.accentColor = accentColor
        self.icon = icon
        self._displayMonth = State(initialValue: selectedDate.wrappedValue)
    }

    private let weekdays = ["日", "一", "二", "三", "四", "五", "六"]

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(accentColor)

            Text(selectedDate.formatted(date: .abbreviated, time: .omitted))
                .font(DesignSystem.Fonts.body)
                .foregroundColor(DesignSystem.Colors.textPrimary)

            Spacer()

            Image(systemName: "chevron.down")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(DesignSystem.Colors.textTertiary)
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
        .padding(.vertical, DesignSystem.Spacing.sm)
        .background(DesignSystem.Colors.elevatedBackground)
        .cornerRadius(DesignSystem.Radius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.medium)
                .stroke(showingCalendar ? accentColor : accentColor.opacity(0.3), lineWidth: showingCalendar ? 2 : 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            displayMonth = selectedDate
            showingCalendar.toggle()
        }
        .popover(isPresented: $showingCalendar, arrowEdge: .bottom) {
            calendarView
        }
    }

    private var calendarView: some View {
        VStack(spacing: 0) {
            // 月份导航
            HStack {
                Button(action: { navigateMonth(-1) }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .frame(width: 28, height: 28)
                        .background(DesignSystem.Colors.elevatedBackground)
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)

                Spacer()

                Text(displayMonth.formatted(.dateTime.year().month(.wide)))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(DesignSystem.Colors.textPrimary)

                Spacer()

                Button(action: { navigateMonth(1) }) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .frame(width: 28, height: 28)
                        .background(DesignSystem.Colors.elevatedBackground)
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            Divider()

            // 星期头
            HStack(spacing: 0) {
                ForEach(weekdays, id: \.self) { day in
                    Text(day)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(DesignSystem.Colors.textTertiary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.vertical, 8)

            // 日历网格
            let days = calendarDays
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 7), spacing: 2) {
                ForEach(days.indices, id: \.self) { index in
                    if let date = days[index] {
                        dayCell(for: date)
                    } else {
                        Color.clear
                            .frame(height: 32)
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 12)

            Divider()

            // 快捷按钮
            HStack(spacing: 8) {
                quickButton(title: "今天", date: Date())
                quickButton(title: "明天", date: Calendar.current.date(byAdding: .day, value: 1, to: Date())!)
                quickButton(title: "下周", date: Calendar.current.date(byAdding: .weekOfYear, value: 1, to: Date())!)
            }
            .padding(10)
        }
        .frame(width: 280)
        .background(DesignSystem.Colors.cardBackground)
    }

    private func dayCell(for date: Date) -> some View {
        let isSelected = Calendar.current.isDate(date, inSameDayAs: selectedDate)
        let isToday = Calendar.current.isDateInToday(date)
        let isDisabled = minDate != nil && date < Calendar.current.startOfDay(for: minDate!)
        let isCurrentMonth = Calendar.current.isDate(date, equalTo: displayMonth, toGranularity: .month)

        return Button(action: {
            if !isDisabled {
                selectedDate = date
                showingCalendar = false
            }
        }) {
            ZStack {
                if isSelected {
                    Circle()
                        .fill(accentColor)
                        .frame(width: 30, height: 30)
                } else if isToday {
                    Circle()
                        .stroke(accentColor, lineWidth: 1.5)
                        .frame(width: 30, height: 30)
                }

                Text("\(Calendar.current.component(.day, from: date))")
                    .font(.system(size: 13, weight: isSelected || isToday ? .semibold : .regular))
                    .foregroundColor(
                        isDisabled ? DesignSystem.Colors.textTertiary.opacity(0.5) :
                        isSelected ? .white :
                        isCurrentMonth ? DesignSystem.Colors.textPrimary :
                        DesignSystem.Colors.textTertiary
                    )
            }
            .frame(height: 32)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
    }

    private func quickButton(title: String, date: Date) -> some View {
        let isDisabled = minDate != nil && date < Calendar.current.startOfDay(for: minDate!)

        return Button(action: {
            if !isDisabled {
                selectedDate = date
                showingCalendar = false
            }
        }) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(isDisabled ? DesignSystem.Colors.textTertiary : accentColor)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isDisabled ? DesignSystem.Colors.border : accentColor.opacity(0.1))
                )
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
    }

    private var calendarDays: [Date?] {
        let calendar = Calendar.current
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: displayMonth))!
        let weekday = calendar.component(.weekday, from: startOfMonth)

        var days: [Date?] = Array(repeating: nil, count: weekday - 1)

        let range = calendar.range(of: .day, in: .month, for: displayMonth)!
        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: startOfMonth) {
                days.append(date)
            }
        }

        // 补齐到42天（6周）
        while days.count < 42 {
            days.append(nil)
        }

        return days
    }

    private func navigateMonth(_ offset: Int) {
        if let newMonth = Calendar.current.date(byAdding: .month, value: offset, to: displayMonth) {
            displayMonth = newMonth
        }
    }
}

struct TaskFormView: View {
    @EnvironmentObject var dataStore: DataStore
    @Binding var isPresented: Bool
    let initialDate: Date
    var initialEndDate: Date?
    let existingTask: Task?
    var onDismiss: (() -> Void)?

    @State private var title: String = ""
    @State private var startDate: Date = Date()
    @State private var endDate: Date = Date()
    @State private var selectedProjectId: UUID?
    @State private var selectedRequirementId: UUID?
    @State private var notes: String = ""
    @State private var selectedTags: [String] = []

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(existingTask == nil ? "新建任务" : "编辑任务")
                        .font(DesignSystem.Fonts.title)
                        .foregroundColor(DesignSystem.Colors.textPrimary)

                    Text(existingTask == nil ? "添加一个新的任务到你的排期中" : "修改任务信息")
                        .font(DesignSystem.Fonts.caption)
                        .foregroundColor(DesignSystem.Colors.textTertiary)
                }

                Spacer()

                Button(action: dismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(DesignSystem.Colors.textTertiary)
                        .frame(width: 28, height: 28)
                        .background(DesignSystem.Colors.elevatedBackground)
                        .cornerRadius(DesignSystem.Radius.small)
                }
                .buttonStyle(.plain)
                .hoverEffect(scale: 1.1)
            }
            .padding(DesignSystem.Spacing.xl)

            Rectangle()
                .fill(DesignSystem.Colors.divider)
                .frame(height: 1)

            ScrollView {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xl) {
                    // Title
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                        Text("任务名称")
                            .font(DesignSystem.Fonts.caption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)

                        TextField("输入任务名称...", text: $title)
                            .textFieldStyle(.plain)
                            .font(DesignSystem.Fonts.body)
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                            .padding(DesignSystem.Spacing.md)
                            .background(DesignSystem.Colors.elevatedBackground)
                            .cornerRadius(DesignSystem.Radius.medium)
                            .overlay(
                                RoundedRectangle(cornerRadius: DesignSystem.Radius.medium)
                                    .stroke(DesignSystem.Colors.border, lineWidth: 1)
                            )
                    }

                    // Date range
                    HStack(spacing: DesignSystem.Spacing.lg) {
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                            Text("开始日期")
                                .font(DesignSystem.Fonts.caption)
                                .foregroundColor(DesignSystem.Colors.textSecondary)

                            CustomDatePicker(
                                selectedDate: $startDate,
                                accentColor: DesignSystem.Colors.accent,
                                icon: "calendar"
                            )
                        }
                        .frame(maxWidth: .infinity)

                        Image(systemName: "arrow.right")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(DesignSystem.Colors.textTertiary)
                            .padding(.top, 24)

                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                            Text("结束日期")
                                .font(DesignSystem.Fonts.caption)
                                .foregroundColor(DesignSystem.Colors.textSecondary)

                            CustomDatePicker(
                                selectedDate: $endDate,
                                minDate: startDate,
                                accentColor: DesignSystem.Colors.success,
                                icon: "calendar.badge.clock"
                            )
                        }
                        .frame(maxWidth: .infinity)
                    }

                    // Project
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                        Text("所属项目")
                            .font(DesignSystem.Fonts.caption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)

                        HStack(spacing: DesignSystem.Spacing.sm) {
                            ForEach(dataStore.projects) { project in
                                ProjectChip(
                                    project: project,
                                    isSelected: selectedProjectId == project.id,
                                    onTap: {
                                        withAnimation(.easeInOut(duration: 0.15)) {
                                            selectedProjectId = project.id
                                        }
                                    }
                                )
                            }
                        }
                    }

                    // Tags
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                        Text("标签")
                            .font(DesignSystem.Fonts.caption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)

                        TagSelector(selectedTags: $selectedTags)
                    }

                    // Sub Tasks (only for existing tasks)
                    if let task = existingTask, !task.isSubTask {
                        SubTaskList(parentTask: task)
                    }

                    // Notes
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                        Text("备注")
                            .font(DesignSystem.Fonts.caption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)

                        TextEditor(text: $notes)
                            .font(DesignSystem.Fonts.body)
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                            .scrollContentBackground(.hidden)
                            .frame(height: 80)
                            .padding(DesignSystem.Spacing.sm)
                            .background(DesignSystem.Colors.elevatedBackground)
                            .cornerRadius(DesignSystem.Radius.medium)
                            .overlay(
                                RoundedRectangle(cornerRadius: DesignSystem.Radius.medium)
                                    .stroke(DesignSystem.Colors.border, lineWidth: 1)
                            )
                    }
                }
                .padding(DesignSystem.Spacing.xl)
            }

            Rectangle()
                .fill(DesignSystem.Colors.divider)
                .frame(height: 1)

            // Actions
            HStack {
                if existingTask != nil {
                    Button(action: {
                        if let task = existingTask {
                            dataStore.deleteTask(task)
                        }
                        dismiss()
                    }) {
                        HStack(spacing: DesignSystem.Spacing.sm) {
                            Image(systemName: "trash")
                                .font(.system(size: 12))
                            Text("删除")
                                .font(DesignSystem.Fonts.caption)
                        }
                        .foregroundColor(DesignSystem.Colors.danger)
                        .padding(.horizontal, DesignSystem.Spacing.lg)
                        .padding(.vertical, DesignSystem.Spacing.sm)
                        .background(DesignSystem.Colors.danger.opacity(0.2))
                        .cornerRadius(DesignSystem.Radius.medium)
                    }
                    .buttonStyle(.plain)
                    .hoverEffect(scale: 1.02)
                }

                Spacer()

                Button(action: dismiss) {
                    Text("取消")
                        .font(DesignSystem.Fonts.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .padding(.horizontal, DesignSystem.Spacing.lg)
                        .padding(.vertical, DesignSystem.Spacing.sm)
                        .background(DesignSystem.Colors.elevatedBackground)
                        .cornerRadius(DesignSystem.Radius.medium)
                }
                .buttonStyle(.plain)
                .hoverEffect(scale: 1.02)

                Button(action: save) {
                    HStack(spacing: DesignSystem.Spacing.sm) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                        Text("保存")
                            .font(DesignSystem.Fonts.caption)
                    }
                }
                .buttonStyle(GradientButtonStyle())
                .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                .opacity(title.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1)
            }
            .padding(DesignSystem.Spacing.xl)
        }
        .frame(width: 480, height: 540)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.xlarge)
                .fill(DesignSystem.Colors.cardBackground)
        )
        .onAppear {
            if let task = existingTask {
                title = task.title
                startDate = task.startDate
                endDate = task.endDate
                selectedProjectId = task.projectId
                selectedRequirementId = task.requirementId
                notes = task.notes
                selectedTags = task.tags
            } else {
                startDate = initialDate
                endDate = initialEndDate ?? initialDate
                if let firstProject = dataStore.projects.first {
                    selectedProjectId = firstProject.id
                }
            }
        }
    }

    private func save() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
        guard !trimmedTitle.isEmpty else { return }

        if var task = existingTask {
            task.title = trimmedTitle
            task.startDate = startDate
            task.endDate = endDate
            task.projectId = selectedProjectId
            task.requirementId = selectedRequirementId
            task.notes = notes
            task.tags = selectedTags
            dataStore.updateTask(task)
        } else {
            let task = Task(
                title: trimmedTitle,
                startDate: startDate,
                endDate: endDate,
                projectId: selectedProjectId,
                requirementId: selectedRequirementId,
                notes: notes,
                tags: selectedTags
            )
            dataStore.addTask(task)
        }

        dismiss()
    }

    private func dismiss() {
        onDismiss?()
        isPresented = false
    }
}

// Requirement Chip for task form
struct RequirementChip: View {
    let title: String
    let status: RequirementStatus?
    let isSelected: Bool
    var onTap: () -> Void

    @State private var isHovered = false

    private var chipColor: Color {
        status?.color ?? DesignSystem.Colors.textTertiary
    }

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.xs) {
            if let status = status {
                Image(systemName: status.icon)
                    .font(.system(size: 10))
            }

            Text(title)
                .font(DesignSystem.Fonts.caption)
                .lineLimit(1)
        }
        .foregroundColor(isSelected ? .white : chipColor)
        .padding(.horizontal, DesignSystem.Spacing.md)
        .padding(.vertical, DesignSystem.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.medium)
                .fill(isSelected ? chipColor : (isHovered ? chipColor.opacity(0.2) : DesignSystem.Colors.elevatedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.medium)
                .stroke(isSelected ? Color.clear : chipColor.opacity(0.5), lineWidth: 1)
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.1)) {
                isHovered = hovering
            }
        }
        .onTapGesture {
            onTap()
        }
    }
}

struct ProjectChip: View {
    let project: Project
    let isSelected: Bool
    var onTap: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            Circle()
                .fill(project.color)
                .frame(width: 10, height: 10)

            Text(project.name)
                .font(DesignSystem.Fonts.caption)
                .foregroundColor(isSelected ? .white : DesignSystem.Colors.textPrimary)
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
        .padding(.vertical, DesignSystem.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.medium)
                .fill(isSelected ? project.color : (isHovered ? project.color.opacity(0.2) : DesignSystem.Colors.elevatedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.medium)
                .stroke(isSelected ? Color.clear : DesignSystem.Colors.border, lineWidth: 1)
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.1)) {
                isHovered = hovering
            }
        }
        .onTapGesture {
            onTap()
        }
    }
}
