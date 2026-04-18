//
//  AppState.swift
//  damoa
//
//  Created by 김승현 on 4/19/26.
//

import SwiftUI
import Observation

// MARK: - Model

struct TodoItem: Identifiable {
    let id = UUID()
    var text: String
    var isCompleted: Bool = false
    var accumulatedSeconds: Int = 0
}

// MARK: - Format Helpers

func formatAccumulated(_ seconds: Int) -> String? {
    guard seconds > 0 else { return nil }
    let h = seconds / 3600
    let m = (seconds % 3600) / 60
    if h == 0 { return "\(m)m" }
    if m == 0 { return "\(h)h" }
    return "\(h)h \(m)m"
}

func formatTotal(_ seconds: Int) -> String {
    guard seconds > 0 else { return "0m" }
    let h = seconds / 3600
    let m = (seconds % 3600) / 60
    if h == 0 { return "\(m)m" }
    if m == 0 { return "\(h)h" }
    return "\(h)h \(m)m"
}

func formatCountdown(_ seconds: Int) -> String {
    let m = seconds / 60
    let s = seconds % 60
    return String(format: "%d:%02d", m, s)
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

    private var timerRef: Timer?
    private var sessionDuration: Int = 0

    var totalAccumulatedSeconds: Int {
        todos.reduce(0) { $0 + $1.accumulatedSeconds }
    }

    var menuBarText: String {
        if activeTimerID != nil {
            return formatCountdown(remainingSeconds)
        }
        return formatTotal(totalAccumulatedSeconds)
    }

    func addTodo(text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        todos.append(TodoItem(text: trimmed))
    }

    func toggleCompletion(id: UUID) {
        guard let idx = todos.firstIndex(where: { $0.id == id }) else { return }
        if activeTimerID == id {
            stopAndAccumulate()
        }
        todos[idx].isCompleted.toggle()
    }

    func deleteTodo(id: UUID) {
        if activeTimerID == id {
            cancelTimer()
        }
        todos.removeAll { $0.id == id }
        notifyMenuBar()
    }

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
        todos.removeAll { $0.isCompleted }
        for i in todos.indices {
            todos[i].accumulatedSeconds = 0
        }
        notifyMenuBar()
    }

    private func stopAndAccumulate() {
        if let id = activeTimerID, sessionDuration > 0 {
            let elapsed = sessionDuration - remainingSeconds
            if elapsed > 0, let idx = todos.firstIndex(where: { $0.id == id }) {
                todos[idx].accumulatedSeconds += elapsed
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
        guard let id = activeTimerID, !isPaused else { return }
        if remainingSeconds > 0 {
            remainingSeconds -= 1
            notifyMenuBar()
        }
        if remainingSeconds == 0 {
            stopTimer()
        }
    }

    private func notifyMenuBar() {
        onMenuBarTextChange?(menuBarText)
    }
}
