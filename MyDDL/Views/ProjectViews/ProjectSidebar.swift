import SwiftUI

struct ProjectSidebar: View {
    @EnvironmentObject var dataStore: DataStore
    @Binding var selectedProjectId: UUID?
    @Binding var showingProjectForm: Bool
    @Binding var mainViewMode: MainViewMode
    @Binding var selectedRequirementStatus: RequirementStatus?

    @State private var editingProject: Project?
    @State private var showingRequirementForm = false
    @State private var editingRequirement: Requirement?
    @State private var showingSettings = false

    // 折叠状态
    // (removed: requirements are always expanded now)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SidebarHeader(showingSettings: $showingSettings)

            SidebarDivider()

            // 笔记 (moved to top)
            NotesSectionRow(mainViewMode: $mainViewMode)

            SidebarDivider()

            // Git
            GitSectionRow(mainViewMode: $mainViewMode)

            SidebarDivider()

            ProjectSectionHeader(showingProjectForm: $showingProjectForm)

            AllTasksRow(selectedProjectId: $selectedProjectId, mainViewMode: $mainViewMode)

            ProjectListView(
                selectedProjectId: $selectedProjectId,
                editingProject: $editingProject,
                mainViewMode: $mainViewMode
            )

            SidebarDivider()

            // 需求管理（不可折叠，直接显示）
            RequirementSection(
                selectedStatus: $selectedRequirementStatus,
                mainViewMode: $mainViewMode,
                showingRequirementForm: $showingRequirementForm
            )

            Spacer()

            SidebarDivider()

            SidebarFooterStats()
        }
        .background(DesignSystem.Colors.cardBackground)
        .sheet(item: $editingProject) { project in
            ProjectFormView(isPresented: .constant(true), existingProject: project) {
                editingProject = nil
            }
        }
        .sheet(isPresented: $showingRequirementForm) {
            RequirementFormView(
                isPresented: $showingRequirementForm,
                existingRequirement: nil
            )
            .environmentObject(dataStore)
        }
        .sheet(item: $editingRequirement) { requirement in
            RequirementFormView(
                isPresented: .constant(true),
                existingRequirement: requirement,
                onDismiss: { editingRequirement = nil }
            )
            .environmentObject(dataStore)
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
    }
}

// MARK: - Requirement Section (Non-Collapsible)
struct RequirementSection: View {
    @EnvironmentObject var dataStore: DataStore
    @Binding var selectedStatus: RequirementStatus?
    @Binding var mainViewMode: MainViewMode
    @Binding var showingRequirementForm: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Header with title and add button
            HStack {
                Text("需求")
                    .font(DesignSystem.Fonts.caption)
                    .foregroundColor(DesignSystem.Colors.textTertiary)
                    .textCase(.uppercase)
                    .tracking(1.5)

                Spacer()

                Button(action: { showingRequirementForm = true }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [DesignSystem.Colors.success, DesignSystem.Colors.successLight],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .buttonStyle(.plain)
                .hoverEffect(scale: 1.15)
            }
            .padding(.horizontal, DesignSystem.Spacing.xl)
            .padding(.top, DesignSystem.Spacing.lg)
            .padding(.bottom, DesignSystem.Spacing.sm)

            // Status list - always visible
            RequirementStatusListView(
                selectedStatus: $selectedStatus,
                editingRequirement: .constant(nil),
                mainViewMode: $mainViewMode
            )
        }
    }
}

// MARK: - Collapsible Requirement Section (deprecated, kept for reference)
struct CollapsibleRequirementSection: View {
    @EnvironmentObject var dataStore: DataStore
    @Binding var isExpanded: Bool
    @Binding var selectedStatus: RequirementStatus?
    @Binding var mainViewMode: MainViewMode
    @Binding var showingRequirementForm: Bool

    @State private var isHovered = false

    private var isSelected: Bool {
        mainViewMode == .requirements
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header row - styled like NotesSectionRow
            HStack(spacing: DesignSystem.Spacing.md) {
                // Icon box
                ZStack {
                    RoundedRectangle(cornerRadius: DesignSystem.Radius.small)
                        .fill(isSelected ?
                              LinearGradient(colors: [DesignSystem.Colors.success, DesignSystem.Colors.success.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing) :
                              LinearGradient(colors: [DesignSystem.Colors.success.opacity(0.15), DesignSystem.Colors.success.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .frame(width: 32, height: 32)

                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(isSelected ? .white : DesignSystem.Colors.success)
                }
                .shadow(color: isSelected ? DesignSystem.Colors.success.opacity(0.3) : Color.clear, radius: 6, x: 0, y: 3)

                Text("需求")
                    .font(DesignSystem.Fonts.body)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundColor(isSelected ? DesignSystem.Colors.textPrimary : DesignSystem.Colors.textSecondary)

                // Expand/collapse indicator
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(DesignSystem.Colors.textTertiary)

                Spacer()

                // Count badge
                if dataStore.requirements.count > 0 {
                    Text("\(dataStore.requirements.count)")
                        .font(DesignSystem.Fonts.caption)
                        .fontWeight(.medium)
                        .foregroundColor(isSelected ? DesignSystem.Colors.success : DesignSystem.Colors.textTertiary)
                        .padding(.horizontal, DesignSystem.Spacing.sm)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(isSelected ? DesignSystem.Colors.success.opacity(0.15) : DesignSystem.Colors.border)
                        )
                }

                // Add button
                Button(action: { showingRequirementForm = true }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [DesignSystem.Colors.success, DesignSystem.Colors.successLight],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .buttonStyle(.plain)
                .hoverEffect(scale: 1.15)
            }
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.vertical, DesignSystem.Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.medium)
                    .fill(isSelected ? DesignSystem.Colors.success.opacity(0.1) : (isHovered ? Color.black.opacity(0.03) : Color.clear))
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignSystem.Radius.medium)
                            .stroke(isSelected ? DesignSystem.Colors.success.opacity(0.2) : Color.clear, lineWidth: 1)
                    )
            )
            .padding(.horizontal, DesignSystem.Spacing.sm)
            .padding(.top, DesignSystem.Spacing.md)
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                    mainViewMode = .requirements
                }
            }
            .onHover { hovering in isHovered = hovering }

            // Expandable content
            if isExpanded {
                RequirementStatusListView(
                    selectedStatus: $selectedStatus,
                    editingRequirement: .constant(nil),
                    mainViewMode: $mainViewMode
                )
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}

// MARK: - Notes Section Row
struct NotesSectionRow: View {
    @EnvironmentObject var dataStore: DataStore
    @Binding var mainViewMode: MainViewMode
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: DesignSystem.Radius.small)
                    .fill(mainViewMode == .notes ?
                          LinearGradient(colors: [DesignSystem.Colors.warning, DesignSystem.Colors.warning.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing) :
                          LinearGradient(colors: [DesignSystem.Colors.warning.opacity(0.15), DesignSystem.Colors.warning.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .frame(width: 32, height: 32)

                Image(systemName: "note.text")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(mainViewMode == .notes ? .white : DesignSystem.Colors.warning)
            }
            .shadow(color: mainViewMode == .notes ? DesignSystem.Colors.warning.opacity(0.3) : Color.clear, radius: 6, x: 0, y: 3)

            Text("笔记")
                .font(DesignSystem.Fonts.body)
                .fontWeight(mainViewMode == .notes ? .semibold : .regular)
                .foregroundColor(mainViewMode == .notes ? DesignSystem.Colors.textPrimary : DesignSystem.Colors.textSecondary)

            Spacer()

            if dataStore.notes.count > 0 {
                Text("\(dataStore.notes.count)")
                    .font(DesignSystem.Fonts.caption)
                    .fontWeight(.medium)
                    .foregroundColor(mainViewMode == .notes ? DesignSystem.Colors.warning : DesignSystem.Colors.textTertiary)
                    .padding(.horizontal, DesignSystem.Spacing.sm)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(mainViewMode == .notes ? DesignSystem.Colors.warning.opacity(0.15) : DesignSystem.Colors.border)
                    )
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
        .padding(.vertical, DesignSystem.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.medium)
                .fill(mainViewMode == .notes ? DesignSystem.Colors.warning.opacity(0.1) : (isHovered ? Color.black.opacity(0.03) : Color.clear))
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.Radius.medium)
                        .stroke(mainViewMode == .notes ? DesignSystem.Colors.warning.opacity(0.2) : Color.clear, lineWidth: 1)
                )
        )
        .padding(.horizontal, DesignSystem.Spacing.sm)
        .padding(.top, DesignSystem.Spacing.md)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                mainViewMode = .notes
            }
        }
        .onHover { hovering in isHovered = hovering }
    }
}

// MARK: - Git Section Row
struct GitSectionRow: View {
    @EnvironmentObject var dataStore: DataStore
    @Binding var mainViewMode: MainViewMode
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: DesignSystem.Radius.small)
                    .fill(mainViewMode == .git ?
                          LinearGradient(colors: [DesignSystem.Colors.accent, DesignSystem.Colors.accent.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing) :
                          LinearGradient(colors: [DesignSystem.Colors.accent.opacity(0.15), DesignSystem.Colors.accent.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .frame(width: 32, height: 32)

                Image(systemName: "arrow.triangle.branch")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(mainViewMode == .git ? .white : DesignSystem.Colors.accent)
            }
            .shadow(color: mainViewMode == .git ? DesignSystem.Colors.accent.opacity(0.3) : Color.clear, radius: 6, x: 0, y: 3)

            Text("Git")
                .font(DesignSystem.Fonts.body)
                .fontWeight(mainViewMode == .git ? .semibold : .regular)
                .foregroundColor(mainViewMode == .git ? DesignSystem.Colors.textPrimary : DesignSystem.Colors.textSecondary)

            Spacer()

            if dataStore.gitRepositories.count > 0 {
                Text("\(dataStore.gitRepositories.filter { $0.isActive }.count)")
                    .font(DesignSystem.Fonts.caption)
                    .fontWeight(.medium)
                    .foregroundColor(mainViewMode == .git ? DesignSystem.Colors.accent : DesignSystem.Colors.textTertiary)
                    .padding(.horizontal, DesignSystem.Spacing.sm)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(mainViewMode == .git ? DesignSystem.Colors.accent.opacity(0.15) : DesignSystem.Colors.border)
                    )
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
        .padding(.vertical, DesignSystem.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.medium)
                .fill(mainViewMode == .git ? DesignSystem.Colors.accent.opacity(0.1) : (isHovered ? Color.black.opacity(0.03) : Color.clear))
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.Radius.medium)
                        .stroke(mainViewMode == .git ? DesignSystem.Colors.accent.opacity(0.2) : Color.clear, lineWidth: 1)
                )
        )
        .padding(.horizontal, DesignSystem.Spacing.sm)
        .padding(.top, DesignSystem.Spacing.md)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                mainViewMode = .git
            }
        }
        .onHover { hovering in isHovered = hovering }
    }
}

// MARK: - Sidebar Header
struct SidebarHeader: View {
    @Binding var showingSettings: Bool

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: DesignSystem.Radius.medium)
                    .fill(
                        LinearGradient(
                            colors: [DesignSystem.Colors.accent, DesignSystem.Colors.accentLight],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 36, height: 36)
                    .shadow(color: DesignSystem.Colors.accent.opacity(0.3), radius: 8, x: 0, y: 4)

                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
            }

            Spacer()

            // Settings button - always visible
            Button(action: { showingSettings = true }) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 16))
                    .foregroundColor(DesignSystem.Colors.textTertiary)
                    .frame(width: 32, height: 32)
                    .background(
                        RoundedRectangle(cornerRadius: DesignSystem.Radius.small)
                            .fill(DesignSystem.Colors.hover)
                    )
            }
            .buttonStyle(.plain)
            .hoverEffect(scale: 1.1)
        }
        .padding(.horizontal, DesignSystem.Spacing.lg)
        .padding(.vertical, DesignSystem.Spacing.md)
    }
}

// MARK: - Divider
struct SidebarDivider: View {
    var body: some View {
        Rectangle()
            .fill(DesignSystem.Colors.divider)
            .frame(height: 1)
            .padding(.horizontal, DesignSystem.Spacing.lg)
    }
}

// MARK: - Project Section Header
struct ProjectSectionHeader: View {
    @Binding var showingProjectForm: Bool

    var body: some View {
        HStack {
            Text("项目")
                .font(DesignSystem.Fonts.caption)
                .foregroundColor(DesignSystem.Colors.textTertiary)
                .textCase(.uppercase)
                .tracking(1.5)

            Spacer()

            Button(action: { showingProjectForm = true }) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [DesignSystem.Colors.accent, DesignSystem.Colors.accentLight],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .buttonStyle(.plain)
            .hoverEffect(scale: 1.15)
        }
        .padding(.horizontal, DesignSystem.Spacing.xl)
        .padding(.top, DesignSystem.Spacing.lg)
        .padding(.bottom, DesignSystem.Spacing.sm)
    }
}

// MARK: - All Tasks Row
struct AllTasksRow: View {
    @EnvironmentObject var dataStore: DataStore
    @Binding var selectedProjectId: UUID?
    @Binding var mainViewMode: MainViewMode

    var body: some View {
        ProjectRow(
            name: "全部任务",
            icon: "tray.full.fill",
            color: DesignSystem.Colors.accent,
            count: dataStore.tasks.count,
            isSelected: selectedProjectId == nil && mainViewMode == .calendar
        )
        .onTapGesture {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                selectedProjectId = nil
                mainViewMode = .calendar
            }
        }
    }
}

// MARK: - Project List View
struct ProjectListView: View {
    @EnvironmentObject var dataStore: DataStore
    @Binding var selectedProjectId: UUID?
    @Binding var editingProject: Project?
    @Binding var mainViewMode: MainViewMode

    var body: some View {
        ScrollView {
            LazyVStack(spacing: DesignSystem.Spacing.xs) {
                ForEach(dataStore.projects) { project in
                    ProjectRowItem(
                        project: project,
                        isSelected: selectedProjectId == project.id && mainViewMode == .calendar,
                        onTap: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                selectedProjectId = project.id
                                mainViewMode = .calendar
                            }
                        },
                        onEdit: { editingProject = project },
                        onDelete: {
                            dataStore.deleteProject(project)
                            if selectedProjectId == project.id {
                                selectedProjectId = nil
                            }
                        }
                    )
                }
            }
            .padding(.vertical, DesignSystem.Spacing.sm)
        }
        .frame(maxHeight: 180)
    }
}

struct ProjectRowItem: View {
    @EnvironmentObject var dataStore: DataStore
    let project: Project
    let isSelected: Bool
    var onTap: () -> Void
    var onEdit: () -> Void
    var onDelete: () -> Void

    var body: some View {
        ProjectRow(
            name: project.name,
            icon: "folder.fill",
            color: project.color,
            count: dataStore.tasks(for: project).count,
            isSelected: isSelected
        )
        .onTapGesture { onTap() }
        .contextMenu {
            Button(action: onEdit) {
                Label("编辑", systemImage: "pencil")
            }
            Divider()
            Button(role: .destructive, action: onDelete) {
                Label("删除", systemImage: "trash")
            }
        }
    }
}

// MARK: - Requirement Status List
struct RequirementStatusListView: View {
    @EnvironmentObject var dataStore: DataStore
    @Binding var selectedStatus: RequirementStatus?
    @Binding var editingRequirement: Requirement?
    @Binding var mainViewMode: MainViewMode

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.xs) {
            // All Requirements row
            ProjectRow(
                name: "全部需求",
                icon: "doc.text.fill",
                color: DesignSystem.Colors.success,
                count: dataStore.requirements.count,
                isSelected: selectedStatus == nil && mainViewMode == .requirements
            )
            .onTapGesture {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    selectedStatus = nil
                    mainViewMode = .requirements
                }
            }

            ForEach(RequirementStatus.allCases, id: \.self) { status in
                RequirementStatusRow(
                    status: status,
                    isSelected: selectedStatus == status,
                    onTap: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            if selectedStatus == status {
                                selectedStatus = nil
                            } else {
                                selectedStatus = status
                            }
                            mainViewMode = .requirements
                        }
                    }
                )
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.sm)
    }
}

// MARK: - Footer Stats
struct SidebarFooterStats: View {
    @EnvironmentObject var dataStore: DataStore

    private var inProgressCount: Int {
        dataStore.requirementsCount(for: .developing) + dataStore.requirementsCount(for: .testing)
    }

    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(DesignSystem.Colors.divider)
                .frame(height: 1)
                .padding(.horizontal, DesignSystem.Spacing.lg)

            HStack {
                Spacer()
                SidebarStatCard(
                    title: "进行中",
                    value: "\(inProgressCount)",
                    color: DesignSystem.Colors.warning
                )
                Spacer()
            }
            .padding(DesignSystem.Spacing.lg)
        }
    }
}

// MARK: - Stat Card
struct SidebarStatCard: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(DesignSystem.Fonts.title)
                .fontWeight(.bold)
                .foregroundColor(color)

            Text(title)
                .font(DesignSystem.Fonts.tiny)
                .foregroundColor(DesignSystem.Colors.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DesignSystem.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.small)
                .fill(color.opacity(0.08))
        )
    }
}

// MARK: - Project Row
struct ProjectRow: View {
    let name: String
    var icon: String = "folder.fill"
    let color: Color
    let count: Int
    let isSelected: Bool

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            iconView
            nameView
            Spacer()
            countView
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
        .padding(.vertical, DesignSystem.Spacing.sm)
        .background(backgroundView)
        .padding(.horizontal, DesignSystem.Spacing.sm)
        .scaleEffect(isHovered && !isSelected ? 1.01 : 1.0)
        .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isHovered)
        .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isSelected)
        .onHover { hovering in
            isHovered = hovering
        }
    }

    private var iconView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: DesignSystem.Radius.small)
                .fill(isSelected ?
                      LinearGradient(colors: [color, color.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing) :
                      LinearGradient(colors: [color.opacity(0.15), color.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .frame(width: 32, height: 32)

            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(isSelected ? .white : color)
        }
        .shadow(color: isSelected ? color.opacity(0.3) : Color.clear, radius: 6, x: 0, y: 3)
    }

    private var nameView: some View {
        Text(name)
            .font(DesignSystem.Fonts.body)
            .fontWeight(isSelected ? .semibold : .regular)
            .foregroundColor(isSelected ? DesignSystem.Colors.textPrimary : DesignSystem.Colors.textSecondary)
            .lineLimit(1)
    }

    @ViewBuilder
    private var countView: some View {
        if count > 0 {
            Text("\(count)")
                .font(DesignSystem.Fonts.caption)
                .fontWeight(.medium)
                .foregroundColor(isSelected ? color : DesignSystem.Colors.textTertiary)
                .padding(.horizontal, DesignSystem.Spacing.sm)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(isSelected ? color.opacity(0.15) : DesignSystem.Colors.border)
                )
        }
    }

    private var backgroundView: some View {
        RoundedRectangle(cornerRadius: DesignSystem.Radius.medium)
            .fill(isSelected ? color.opacity(0.1) : (isHovered ? Color.black.opacity(0.03) : Color.clear))
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.medium)
                    .stroke(isSelected ? color.opacity(0.2) : Color.clear, lineWidth: 1)
            )
    }
}
