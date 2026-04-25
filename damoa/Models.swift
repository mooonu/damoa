//
//  Models.swift
//  damoa
//
//  Created by 김승현 on 4/19/26.
//

import SwiftData
import Foundation

@Model
final class PinItem {
    @Attribute(.unique) var id: UUID
    var title: String
    var createdAt: Date

    init(title: String) {
        self.id = UUID()
        self.title = title
        self.createdAt = Date()
    }
}

@Model
final class TodoItem {
    @Attribute(.unique) var id: UUID
    var title: String
    var isCompleted: Bool
    var accumulatedMinutes: Int
    var savedRemainingSeconds: Int?
    var createdAt: Date
    var completedAt: Date?
    var date: String
    var dayRecord: DayRecord?

    init(title: String, date: String) {
        self.id = UUID()
        self.title = title
        self.isCompleted = false
        self.accumulatedMinutes = 0
        self.savedRemainingSeconds = nil
        self.createdAt = Date()
        self.completedAt = nil
        self.date = date
    }
}

@Model
final class DayRecord {
    @Attribute(.unique) var id: UUID
    @Attribute(.unique) var date: String
    var totalMinutes: Int
    @Relationship(deleteRule: .cascade, inverse: \TodoItem.dayRecord)
    var todos: [TodoItem]

    init(date: String) {
        self.id = UUID()
        self.date = date
        self.totalMinutes = 0
        self.todos = []
    }
}
