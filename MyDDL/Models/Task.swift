import Foundation
import SwiftUI

enum TaskStatus: String, Codable, CaseIterable {
    case notStarted = "not_started"
    case inProgress = "in_progress"
    case completed = "completed"

    var displayName: String {
        switch self {
        case .notStarted: return "未开始"
        case .inProgress: return "进行中"
        case .completed: return "已完成"
        }
    }

    var icon: String {
        switch self {
        case .notStarted: return "circle"
        case .inProgress: return "circle.lefthalf.filled"
        case .completed: return "checkmark.circle.fill"
        }
    }
}

enum TaskPriority: String, Codable, CaseIterable {
    case high = "high"
    case medium = "medium"
    case low = "low"

    var displayName: String {
        switch self {
        case .high: return "高"
        case .medium: return "中"
        case .low: return "低"
        }
    }

    var sortOrder: Int {
        switch self {
        case .high: return 0
        case .medium: return 1
        case .low: return 2
        }
    }
}

struct Task: Identifiable, Codable, Equatable {
    var id: UUID
    var title: String
    var startDate: Date
    var endDate: Date
    var estimatedHours: Double
    var priority: TaskPriority
    var status: TaskStatus
    var projectId: UUID?
    var requirementId: UUID?
    var notes: String
    var createdAt: Date
    var updatedAt: Date
    var parentTaskId: UUID?
    var tags: [String]

    init(
        id: UUID = UUID(),
        title: String,
        startDate: Date,
        endDate: Date,
        estimatedHours: Double = 8.0,
        priority: TaskPriority = .medium,
        status: TaskStatus = .notStarted,
        projectId: UUID? = nil,
        requirementId: UUID? = nil,
        notes: String = "",
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        parentTaskId: UUID? = nil,
        tags: [String] = []
    ) {
        self.id = id
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.estimatedHours = estimatedHours
        self.priority = priority
        self.status = status
        self.projectId = projectId
        self.requirementId = requirementId
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.parentTaskId = parentTaskId
        self.tags = tags
    }

    var isMultiDay: Bool {
        !Calendar.current.isDate(startDate, inSameDayAs: endDate)
    }

    var daySpan: Int {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: startDate)
        let end = calendar.startOfDay(for: endDate)
        let components = calendar.dateComponents([.day], from: start, to: end)
        return (components.day ?? 0) + 1
    }

    func isOnDate(_ date: Date) -> Bool {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: startDate)
        let end = calendar.startOfDay(for: endDate)
        let target = calendar.startOfDay(for: date)
        return target >= start && target <= end
    }

    var isOverdue: Bool {
        if status == .completed { return false }
        return endDate < Date()
    }

    var isSubTask: Bool {
        parentTaskId != nil
    }

    var hasSubTasks: Bool {
        // This will be computed by DataStore
        false
    }
}

// MARK: - Transferable for Drag & Drop
extension Task: Transferable {
    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .json)
    }
}
