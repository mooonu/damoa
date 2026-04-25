//
//  AppState.swift
//  damoa
//
//  Created by 김승현 on 4/19/26.
//

import SwiftUI
import Observation
import SwiftData
import UserNotifications

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
    var pins: [PinItem] = []
    var activeTimerID: UUID? = nil
    var remainingSeconds: Int = 0
    var isPaused: Bool = false
    var streakDays: Int = 0
    var popoverOpenToken: Int = 0
    var editingTodoID: UUID? = nil

    var onMenuBarTextChange: ((String) -> Void)?

    private let modelContext: ModelContext
    private var currentDayRecord: DayRecord?
    private var loadedDateString: String = ""
    private var timerRef: Timer?
    private var dateCheckTimer: Timer?
    private var sessionDuration: Int = 0
    private var _yesterdayMinutes: Int? = nil

    var totalAccumulatedMinutes: Int {
        todos.reduce(0) { $0 + $1.accumulatedMinutes }
    }

    /// 오늘 누적 - 어제 누적. 어제 기록 없으면 nil, 차이 0이면 nil.
    var yesterdayDiff: Int? {
        guard let yd = _yesterdayMinutes else { return nil }
        let diff = totalAccumulatedMinutes - yd
        return diff != 0 ? diff : nil
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
        loadPins()
    }

    // MARK: - Load

    private func loadPins() {
        let descriptor = FetchDescriptor<PinItem>(sortBy: [SortDescriptor(\.createdAt)])
        pins = (try? modelContext.fetch(descriptor)) ?? []
    }

    private func loadToday() {
        let today = todayDateString()
        loadedDateString = today
        let descriptor = FetchDescriptor<DayRecord>(
            predicate: #Predicate { $0.date == today }
        )
        if let record = (try? modelContext.fetch(descriptor))?.first {
            currentDayRecord = record
            todos = record.todos.sorted { $0.createdAt < $1.createdAt }
        } else {
            let record = DayRecord(date: today)
            modelContext.insert(record)
            currentDayRecord = record
            todos = []
            try? modelContext.save()
        }
        loadYesterdayMinutes()
        refreshStreak()
        startDateCheckTimer()
    }

    func checkAndReloadIfDateChanged() {
        let today = todayDateString()
        guard today != loadedDateString else { return }
        cancelTimer()
        loadToday()
        notifyMenuBar()
    }

    private func startDateCheckTimer() {
        dateCheckTimer?.invalidate()
        dateCheckTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.checkAndReloadIfDateChanged()
            }
        }
    }

    private func loadYesterdayMinutes() {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        let yesterday = f.string(from: Calendar.current.date(byAdding: .day, value: -1, to: Date())!)
        let descriptor = FetchDescriptor<DayRecord>(predicate: #Predicate { $0.date == yesterday })
        _yesterdayMinutes = (try? modelContext.fetch(descriptor))?.first?.totalMinutes
    }

    private func refreshStreak() {
        let descriptor = FetchDescriptor<DayRecord>()
        let records = (try? modelContext.fetch(descriptor)) ?? []
        let dateSet = Set(records.filter { $0.totalMinutes > 0 }.map { $0.date })

        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        let cal = Calendar.current
        var count = 0
        var checkDate = Date()

        // 오늘 0m이면 어제부터 시작
        if totalAccumulatedMinutes == 0 {
            checkDate = cal.date(byAdding: .day, value: -1, to: checkDate)!
        }

        while true {
            let ds = f.string(from: checkDate)
            guard dateSet.contains(ds) else { break }
            count += 1
            checkDate = cal.date(byAdding: .day, value: -1, to: checkDate)!
        }
        streakDays = count
    }

    // MARK: - Pin CRUD

    func addPin(text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let item = PinItem(title: trimmed)
        modelContext.insert(item)
        pins.append(item)
        try? modelContext.save()
    }

    func deletePin(id: UUID) {
        if let item = pins.first(where: { $0.id == id }) {
            modelContext.delete(item)
            pins.removeAll { $0.id == id }
        }
        try? modelContext.save()
    }

    // MARK: - CRUD

    func startEditing(id: UUID) {
        editingTodoID = id
    }

    func commitEdit(id: UUID, newTitle: String) {
        editingTodoID = nil
        let trimmed = newTitle.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty,
              let item = todos.first(where: { $0.id == id }) else { return }
        item.title = trimmed
        save()
    }

    func addTodo(text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        checkAndReloadIfDateChanged()
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
            notifyMenuBar()
        }
        item.savedRemainingSeconds = nil
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
        if let item = todos.first(where: { $0.id == id }) {
            item.savedRemainingSeconds = nil
        }
        activeTimerID = id
        sessionDuration = minutes * 60
        remainingSeconds = minutes * 60
        isPaused = false
        scheduleTimer()
        notifyMenuBar()
    }

    func resumeTimer(for id: UUID) {
        guard let item = todos.first(where: { $0.id == id }),
              let seconds = item.savedRemainingSeconds, seconds > 0 else { return }
        stopAndAccumulate()
        item.savedRemainingSeconds = nil
        activeTimerID = id
        sessionDuration = seconds
        remainingSeconds = seconds
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
        save()
        notifyMenuBar()
    }

    // MARK: - Private

    private func stopAndAccumulate() {
        if let id = activeTimerID, let item = todos.first(where: { $0.id == id }) {
            item.savedRemainingSeconds = remainingSeconds
            if sessionDuration > 0 {
                let elapsed = sessionDuration - remainingSeconds
                let elapsedMinutes = elapsed / 60
                if elapsedMinutes > 0 {
                    item.accumulatedMinutes += elapsedMinutes
                    save()
                }
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
            sendCompletionNotification()
            stopTimer()
        }
    }

    private func sendCompletionNotification() {
        guard let id = activeTimerID,
              let todo = todos.first(where: { $0.id == id }) else { return }
        let minutes = sessionDuration / 60
        let content = UNMutableNotificationContent()
        content.title = "타이머 완료"
        content.body = "\(todo.title) - \(minutes)분 완료"
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    private func save() {
        currentDayRecord?.totalMinutes = totalAccumulatedMinutes
        try? modelContext.save()
        refreshStreak()
    }

    private func notifyMenuBar() {
        onMenuBarTextChange?(menuBarText)
    }
}
