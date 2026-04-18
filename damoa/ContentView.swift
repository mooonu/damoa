//
//  ContentView.swift
//  damoa
//
//  Created by 김승현 on 4/19/26.
//

import SwiftUI

// MARK: - ContentView

struct ContentView: View {
    @Environment(AppState.self) private var state
    @State private var newTodoText = ""
    @State private var showHistory = false

    private var dateString: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "M월 d일 EEEE"
        return f.string(from: Date())
    }

    private var activeTodo: TodoItem? {
        guard let id = state.activeTimerID else { return nil }
        return state.todos.first { $0.id == id }
    }

    private var pendingTodos: [TodoItem] {
        state.todos.filter { !$0.isCompleted && $0.id != state.activeTimerID }
    }

    private var completedTodos: [TodoItem] {
        Array(state.todos.filter { $0.isCompleted }.suffix(3))
    }

    var body: some View {
        if showHistory {
            HistoryView(onBack: { showHistory = false })
        } else {
            mainContent
        }
    }

    // MARK: - Main Content

    private var mainContent: some View {
        VStack(spacing: 0) {
            headerSection
            Divider()
            inputSection
            Divider()
            todoListSection
            Divider()
            footerSection
        }
        .frame(width: 320, height: 480)
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(dateString)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
            Text(formatTotal(state.totalAccumulatedMinutes))
                .font(.system(size: 28, weight: .medium))
                .tracking(-0.5)
                .foregroundStyle(.primary)
            if let diff = state.yesterdayDiff {
                let sign = diff > 0 ? "+" : "-"
                Text("\(sign)어제보다 \(formatTotal(abs(diff)))")
                    .font(.system(size: 12))
                    .foregroundStyle(diff > 0 ? Color.green : Color.orange)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
    }

    // MARK: - Input

    private var inputSection: some View {
        HStack(spacing: 8) {
            TextField("할 일 추가", text: $newTodoText)
                .textFieldStyle(.plain)
                .font(.system(size: 14))
                .onSubmit { submit() }

            Button {
                submit()
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(
                        newTodoText.trimmingCharacters(in: .whitespaces).isEmpty
                            ? Color.secondary.opacity(0.4)
                            : Color.accentColor
                    )
            }
            .buttonStyle(.plain)
            .disabled(newTodoText.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Todo List

    private var todoListSection: some View {
        ScrollView {
            VStack(spacing: 0) {
                if let active = activeTodo {
                    ActiveTodoRow(todo: active, state: state)
                }

                ForEach(pendingTodos, id: \.id) { todo in
                    PendingTodoRow(todo: todo, state: state)
                }

                if !completedTodos.isEmpty {
                    Divider()
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                    ForEach(completedTodos, id: \.id) { todo in
                        CompletedTodoRow(todo: todo, state: state)
                    }
                }
            }
        }
        .frame(maxHeight: .infinity)
    }

    // MARK: - Footer

    private var footerSection: some View {
        HStack(spacing: 8) {
            Button("기록") { showHistory = true }
                .buttonStyle(.plain)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

            if state.streakDays > 0 {
                Text("\(state.streakDays)일 연속")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private func submit() {
        let trimmed = newTodoText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        state.addTodo(text: trimmed)
        newTodoText = ""
    }
}

// MARK: - Active Todo Row

struct ActiveTodoRow: View {
    let todo: TodoItem
    let state: AppState

    var body: some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(Color.accentColor)
                .frame(width: 3)

            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(todo.title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Text(formatCountdown(state.remainingSeconds))
                        .font(.system(size: 12))
                        .foregroundStyle(Color.accentColor)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Button {
                    state.togglePause()
                } label: {
                    Image(systemName: state.isPaused ? "play.fill" : "pause.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
            }
            .padding(.leading, 13)
            .padding(.trailing, 16)
            .padding(.vertical, 10)
        }
        .background(Color.accentColor.opacity(0.08))
        .contextMenu {
            Button(role: .destructive) {
                state.deleteTodo(id: todo.id)
            } label: {
                Label("삭제", systemImage: "trash")
            }
        }
    }
}

// MARK: - Pending Todo Row

struct PendingTodoRow: View {
    let todo: TodoItem
    let state: AppState

    var body: some View {
        HStack(spacing: 8) {
            Button {
                state.toggleCompletion(id: todo.id)
            } label: {
                Circle()
                    .strokeBorder(Color.secondary.opacity(0.5), lineWidth: 1.5)
                    .frame(width: 18, height: 18)
            }
            .buttonStyle(.plain)

            Text(todo.title)
                .font(.system(size: 14))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let timeStr = formatAccumulated(todo.accumulatedMinutes) {
                Text(timeStr)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            Menu {
                ForEach([5, 10, 15, 20, 25, 30], id: \.self) { min in
                    Button("\(min)분") {
                        state.startTimer(for: todo.id, minutes: min)
                    }
                }
            } label: {
                Image(systemName: "play.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 24, height: 24)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .contextMenu {
            Button(role: .destructive) {
                state.deleteTodo(id: todo.id)
            } label: {
                Label("삭제", systemImage: "trash")
            }
        }
    }
}

// MARK: - Completed Todo Row

struct CompletedTodoRow: View {
    let todo: TodoItem
    let state: AppState

    var body: some View {
        HStack(spacing: 8) {
            Button {
                state.toggleCompletion(id: todo.id)
            } label: {
                ZStack {
                    Circle()
                        .fill(Color.secondary)
                        .frame(width: 18, height: 18)
                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .buttonStyle(.plain)

            Text(todo.title)
                .font(.system(size: 14))
                .strikethrough()
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let timeStr = formatAccumulated(todo.accumulatedMinutes) {
                Text(timeStr)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .opacity(0.6)
        .contextMenu {
            Button(role: .destructive) {
                state.deleteTodo(id: todo.id)
            } label: {
                Label("삭제", systemImage: "trash")
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ContentView()
}
