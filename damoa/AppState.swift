//
//  AppState.swift
//  damoa
//
//  Created by 김승현 on 4/19/26.
//

import SwiftUI
import Observation
import SwiftData

// MARK: - Format Helpers

func formatAccumulated(_ minutes: Int) -> String? {
    guard minutes > 0 else { return nil }
    let h = minutes / 60
    let m = minutes % 60
    if h == 0 { return "\(m)m" }
    if m == 0 { return "\(h)h" }
    return "\(h)h \(m)m"
}

func formatTotal(_ minutes: Int) -> String {
    guard minutes > 0 else { return "0m" }
    let h = minutes / 60
    let m = minutes % 60
    if h == 0 { return "\(m)m" }
    if m == 0 { return "\(h)h" }
    return "\(h)h \(m)m"
}

func formatCountdown(_ seconds: Int) -> String {
    let m = seconds / 60
    let s = seconds % 60
    return String(format: "%d:%02d", m, s)
}

func todayDateString() -> String {
    let f = DateFormatter()
    f.dateFormat = "yyyy-MM-dd"
    return f.string(from: Date())
}

// MARK: - AppState

@Observable
@MainActor
final class AppState {
    var todos: [TodoItem] = []
    var activeTimerID: UUID? = nil
    var remainingSeconds: Int = 0
    var isPaused: Bool = false

    var onMenuBarTextChange: ((String) -> Void)?

    private let modelContext: ModelContext
    private var currentDayRecord: DayRecord?
    private var timerRef: Timer?
    private var sessionDuration: Int = 0

    var totalAccumulatedMinutes: Int {
        todos.reduce(0) { $0 + $1.accumulatedMinutes }
    }

    var menuBarText: String {
        if activeTimerID != nil {
            return formatCountdown(remainingSeconds)
        }
        return formatTotal(totalAccumulatedMinutes)
    }

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        loadToday()
    }

    // MARK: - Load

    private func loadToday() {
        let today = todayDateString()
        let descriptor = FetchDescriptor<DayRecord>(
            predicate: #Predicate { $0.date == today }
        )
        if let record = (try? modelContext.fetch(descriptor))?.first {
            currentDayRecord = record
            todos = record.todos.sorted { $0.createdAt < $1.createdAt }
        } else {
            let record = DayRecord(date: today)
            modelContext.insert(record)
            save()
            currentDayRecord = record
            todos = []
        }
    }

    // MARK: - CRUD

    func addTodo(text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let item = TodoItem(title: trimmed, date: todayDateString())
        item.dayRecord = currentDayRecord
        modelContext.insert(item)
        todos.append(item)
        save()
    }

    func toggleCompletion(id: UUID) {
        guard let item = todos.first(where: { $0.id == id }) else { return }
        if activeTimerID == id {
            stopAndAccumulate()
        }
        item.isCompleted.toggle()
        item.completedAt = item.isCompleted ? Date() : nil
        save()
    }

    func deleteTodo(id: UUID) {
        if activeTimerID == id {
            cancelTimer()
        }
        if let item = todos.first(where: { $0.id == id }) {
            modelContext.delete(item)
            todos.removeAll { $0.id == id }
        }
        save()
        notifyMenuBar()
    }

    // MARK: - Timer

    func startTimer(for id: UUID, minutes: Int) {
        stopAndAccumulate()
        activeTimerID = id
        sessionDuration = minutes * 60
        remainingSeconds = minutes * 60
        isPaused = false
        scheduleTimer()
        notifyMenuBar()
    }

    func togglePause() {
        guard activeTimerID != nil else { return }
        isPaused.toggle()
        if isPaused {
            timerRef?.invalidate()
            timerRef = nil
        } else {
            scheduleTimer()
        }
        notifyMenuBar()
    }

    func stopTimer() {
        stopAndAccumulate()
        notifyMenuBar()
    }

    func resetDay() {
        cancelTimer()
        let completed = todos.filter { $0.isCompleted }
        completed.forEach { modelContext.delete($0) }
        todos.removeAll { $0.isCompleted }
        todos.forEach { $0.accumulatedMinutes = 0 }
        updateDayTotal()
        save()
        notifyMenuBar()
    }

    // MARK: - Private

    private func stopAndAccumulate() {
        if let id = activeTimerID, sessionDuration > 0 {
            let elapsed = sessionDuration - remainingSeconds
            let elapsedMinutes = elapsed / 60
            if elapsedMinutes > 0, let item = todos.first(where: { $0.id == id }) {
                item.accumulatedMinutes += elapsedMinutes
                updateDayTotal()
                save()
            }
        }
        cancelTimer()
    }

    private func cancelTimer() {
        timerRef?.invalidate()
        timerRef = nil
        activeTimerID = nil
        remainingSeconds = 0
        isPaused = false
        sessionDuration = 0
    }

    private func scheduleTimer() {
        timerRef = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.tick()
            }
        }
    }

    private func tick() {
        guard activeTimerID != nil, !isPaused else { return }
        if remainingSeconds > 0 {
            remainingSeconds -= 1
            notifyMenuBar()
        }
        if remainingSeconds == 0 {
            stopTimer()
        }
    }

    private func updateDayTotal() {
        currentDayRecord?.totalMinutes = totalAccumulatedMinutes
    }

    private func save() {
        try? modelContext.save()
    }

    private func notifyMenuBar() {
        onMenuBarTextChange?(menuBarText)
    }
}
