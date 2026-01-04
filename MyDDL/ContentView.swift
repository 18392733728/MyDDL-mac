import SwiftUI

enum CalendarViewType: String, CaseIterable {
    case month = "month"
    case week = "week"
    case day = "day"

    var displayName: String {
        switch self {
        case .month: return "月"
        case .week: return "周"
        case .day: return "日"
        }
    }

    var icon: String {
        switch self {
        case .month: return "calendar"
        case .week: return "calendar.badge.clock"
        case .day: return "sun.max"
        }
    }
}

// 主视图模式
enum MainViewMode {
    case calendar
    case requirements
    case notes
    case git
}

// 用于 sheet(item:) 的日期范围结构
struct DateRangeSelection: Identifiable {
    let id = UUID()
    let startDate: Date
    let endDate: Date
}

struct ContentView: View {
    @EnvironmentObject var dataStore: DataStore
    @EnvironmentObject var themeManager: ThemeManager
    @State private var selectedDate = Date()
    @State private var viewType: CalendarViewType = .month
    @State private var showingTaskForm = false
    @State private var showingProjectForm = false
    @State private var selectedTask: Task?
    @State private var selectedProjectId: UUID?
    @State private var sidebarWidth: CGFloat = 240

    // 视图模式
    @State private var mainViewMode: MainViewMode = .calendar

    // 需求相关
    @State private var selectedRequirementStatus: RequirementStatus?
    @State private var selectedRequirement: Requirement?

    // 笔记相关
    @State private var selectedNote: Note?
    @State private var noteListWidth: CGFloat = 180
    @State private var isNoteListCollapsed: Bool = false

    // 用 item 方式管理日期范围选择的 sheet
    @State private var dateRangeSelection: DateRangeSelection?

    var body: some View {
        HStack(spacing: 0) {
            // Sidebar
            ProjectSidebar(
                selectedProjectId: $selectedProjectId,
                showingProjectForm: $showingProjectForm,
                mainViewMode: $mainViewMode,
                selectedRequirementStatus: $selectedRequirementStatus
            )
            .frame(width: sidebarWidth)

            // Main content
            VStack(spacing: 0) {
                if mainViewMode == .calendar {
                    // Calendar Header
                    CalendarHeader(
                        selectedDate: $selectedDate,
                        viewType: $viewType,
                        showingTaskForm: $showingTaskForm
                    )

                    // Calendar view
                    ZStack {
                        switch viewType {
                        case .month:
                            MonthView(
                                selectedDate: $selectedDate,
                                selectedTask: $selectedTask,
                                selectedProjectId: selectedProjectId,
                                onRangeSelected: { start, end in
                                    debugLog("[ContentView] onRangeSelected: \(start) to \(end)")
                                    dateRangeSelection = DateRangeSelection(startDate: start, endDate: end)
                                }
                            )
                        case .week:
                            WeekView(
                                selectedDate: $selectedDate,
                                selectedTask: $selectedTask,
                                selectedProjectId: selectedProjectId
                            )
                        case .day:
                            DayView(
                                selectedDate: $selectedDate,
                                selectedTask: $selectedTask,
                                selectedProjectId: selectedProjectId
                            )
                        }
                    }
                } else if mainViewMode == .requirements {
                    // Requirements view
                    RequirementListView(
                        selectedStatus: $selectedRequirementStatus,
                        selectedRequirement: $selectedRequirement
                    )
                } else if mainViewMode == .notes {
                    // Notes view with list and editor
                    HStack(spacing: 0) {
                        NoteListView(
                            selectedNote: $selectedNote,
                            listWidth: $noteListWidth,
                            isCollapsed: $isNoteListCollapsed
                        )

                        Rectangle()
                            .fill(DesignSystem.Colors.divider)
                            .frame(width: 1)

                        NoteEditorView(note: $selectedNote)
                            .id(selectedNote?.id)
                    }
                } else if mainViewMode == .git {
                    // Git view
                    GitDashboardView()
                        .environmentObject(dataStore)
                        .environmentObject(themeManager)
                }
            }
            .background(DesignSystem.Colors.secondaryBackground)
        }
        .background(DesignSystem.Colors.background)
        .sheet(isPresented: $showingTaskForm) {
            TaskFormView(
                isPresented: $showingTaskForm,
                initialDate: selectedDate,
                existingTask: nil
            )
            .environmentObject(dataStore)
        }
        .sheet(item: $selectedTask) { task in
            TaskFormView(
                isPresented: .constant(true),
                initialDate: task.startDate,
                existingTask: task,
                onDismiss: { selectedTask = nil }
            )
            .environmentObject(dataStore)
        }
        .sheet(isPresented: $showingProjectForm) {
            ProjectFormView(isPresented: $showingProjectForm, existingProject: nil)
                .environmentObject(dataStore)
        }
        .sheet(item: $dateRangeSelection) { selection in
            TaskFormView(
                isPresented: .constant(true),
                initialDate: selection.startDate,
                initialEndDate: selection.endDate,
                existingTask: nil,
                onDismiss: { dateRangeSelection = nil }
            )
            .environmentObject(dataStore)
        }
        .sheet(item: $selectedRequirement) { requirement in
            RequirementFormView(
                isPresented: .constant(true),
                existingRequirement: requirement,
                onDismiss: { selectedRequirement = nil }
            )
            .environmentObject(dataStore)
        }
        .onReceive(NotificationCenter.default.publisher(for: .createNewTask)) { _ in
            showingTaskForm = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .createNewProject)) { _ in
            showingProjectForm = true
        }
    }
}
