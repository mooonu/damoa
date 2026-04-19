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
    @State private var displayedStreak: Int = 0

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

    private var streakColor: Color {
        displayedStreak >= 3 ? Color.teal : Color.orange
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
        .frame(width: 300)
        .onChange(of: state.popoverOpenToken) { _, _ in
            animateStreak()
        }
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
        .frame(maxHeight: 400)
    }

    // MARK: - Footer

    private var footerSection: some View {
        HStack {
            Button("기록") { showHistory = true }
                .buttonStyle(.plain)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

            Spacer()

            if state.streakDays > 0 {
                HStack(spacing: 0) {
                    Text("\(displayedStreak)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(streakColor)
                    Text("일 연속")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Helpers

    private func submit() {
        let trimmed = newTodoText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        state.addTodo(text: trimmed)
        newTodoText = ""
    }

    private func animateStreak() {
        let target = state.streakDays
        guard target > 0 else {
            displayedStreak = 0
            return
        }
        displayedStreak = 0
        let steps = min(target, 20)
        let stepDuration = 0.3 / Double(steps)
        Task { @MainActor in
            for i in 1...steps {
                try? await Task.sleep(for: .seconds(stepDuration))
                displayedStreak = (i == steps) ? target : max(1, target * i / steps)
            }
        }
    }
}

// MARK: - Active Todo Row

struct ActiveTodoRow: View {
    let todo: TodoItem
    let state: AppState
    @State private var draftTitle = ""
    @FocusState private var isEditing: Bool

    private var editing: Bool { state.editingTodoID == todo.id }

    var body: some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(Color.orange)
                .frame(width: 3)

            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    if editing {
                        TextField("", text: $draftTitle)
                            .textFieldStyle(.plain)
                            .font(.system(size: 14, weight: .medium))
                            .focused($isEditing)
                            .onSubmit { state.commitEdit(id: todo.id, newTitle: draftTitle) }
                            .onChange(of: isEditing) { _, focused in
                                guard !focused, state.editingTodoID == todo.id else { return }
                                state.commitEdit(id: todo.id, newTitle: draftTitle)
                            }
                    } else {
                        Text(todo.title)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Color.primary.opacity(0.92))
                            .lineLimit(1)
                    }

                    Text(formatCountdown(state.remainingSeconds))
                        .font(.system(size: 12).monospacedDigit())
                        .foregroundStyle(Color.primary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 0) {
                    if state.isPaused {
                        Button {
                            state.togglePause()
                        } label: {
                            Image(systemName: "play.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(Color.orange)
                                .frame(width: 28, height: 28)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("재개")

                        Button {
                            state.stopTimer()
                        } label: {
                            Image(systemName: "stop.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(Color.secondary)
                                .frame(width: 28, height: 28)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("중단")
                    } else {
                        Button {
                            state.togglePause()
                        } label: {
                            Image(systemName: "pause.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(Color.secondary)
                                .frame(width: 28, height: 28)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("일시정지")
                    }
                }
            }
            .padding(.leading, 13)
            .padding(.trailing, 16)
            .padding(.vertical, 10)
        }
        .background(state.isPaused ? Color.orange.opacity(0.05) : Color.orange.opacity(0.08))
        .onChange(of: state.editingTodoID) { _, id in
            if id == todo.id {
                draftTitle = todo.title
                isEditing = true
            }
        }
        .contextMenu {
            Button { state.startEditing(id: todo.id) } label: {
                Label("이름 변경", systemImage: "pencil")
            }
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
    @State private var draftTitle = ""
    @FocusState private var isEditing: Bool
    @State private var showingCustomInput = false
    @State private var customMinutesText = ""
    @FocusState private var isCustomInputFocused: Bool

    private var editing: Bool { state.editingTodoID == todo.id }

    private func submitCustomInput() {
        guard let minutes = Int(customMinutesText.trimmingCharacters(in: .whitespaces)),
              minutes > 0 else {
            cancelCustomInput()
            return
        }
        state.startTimer(for: todo.id, minutes: minutes)
        cancelCustomInput()
    }

    private func cancelCustomInput() {
        showingCustomInput = false
        customMinutesText = ""
    }

    var body: some View {
        HStack(spacing: 8) {
            Button {
                state.toggleCompletion(id: todo.id)
            } label: {
                Circle()
                    .strokeBorder(Color.secondary.opacity(0.5), lineWidth: 1.5)
                    .frame(width: 18, height: 18)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)

            if editing {
                TextField("", text: $draftTitle)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))
                    .focused($isEditing)
                    .onSubmit { state.commitEdit(id: todo.id, newTitle: draftTitle) }
                    .onChange(of: isEditing) { _, focused in
                        guard !focused, state.editingTodoID == todo.id else { return }
                        state.commitEdit(id: todo.id, newTitle: draftTitle)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text(todo.title)
                    .font(.system(size: 14))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if showingCustomInput {
                HStack(spacing: 3) {
                    TextField("", text: $customMinutesText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13).monospacedDigit())
                        .frame(width: 36)
                        .multilineTextAlignment(.trailing)
                        .focused($isCustomInputFocused)
                        .onSubmit { submitCustomInput() }
                        .onKeyPress(.escape) {
                            cancelCustomInput()
                            return .handled
                        }
                        .onChange(of: customMinutesText) { _, new in
                            customMinutesText = new.filter { $0.isNumber }
                        }
                        .onChange(of: isCustomInputFocused) { _, focused in
                            if !focused { cancelCustomInput() }
                        }
                        .onAppear { isCustomInputFocused = true }
                    Text("분")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
            } else {
                if let timeStr = formatAccumulated(todo.accumulatedMinutes) {
                    Text(timeStr)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }

                if let saved = todo.savedRemainingSeconds, saved > 0 {
                    Menu {
                        Button("이어서 \(formatCountdown(saved))") {
                            state.resumeTimer(for: todo.id)
                        }
                        Divider()
                        ForEach([5, 10, 15, 20, 25, 30], id: \.self) { min in
                            Button("\(min)분") {
                                state.startTimer(for: todo.id, minutes: min)
                            }
                        }
                        Divider()
                        Button("직접 입력...") { showingCustomInput = true }
                    } label: {
                        Image(systemName: "play.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.orange)
                    }
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.hidden)
                    .frame(width: 28, height: 28)
                    .accessibilityLabel("재개 또는 새로 시작")
                } else {
                    Menu {
                        ForEach([5, 10, 15, 20, 25, 30], id: \.self) { min in
                            Button("\(min)분") {
                                state.startTimer(for: todo.id, minutes: min)
                            }
                        }
                        Divider()
                        Button("직접 입력...") { showingCustomInput = true }
                    } label: {
                        Image(systemName: "play.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.secondary)
                    }
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.hidden)
                    .frame(width: 28, height: 28)
                    .accessibilityLabel("시작")
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .onChange(of: state.editingTodoID) { _, id in
            if id == todo.id {
                draftTitle = todo.title
                isEditing = true
            }
        }
        .contextMenu {
            Button { state.startEditing(id: todo.id) } label: {
                Label("이름 변경", systemImage: "pencil")
            }
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
    @State private var draftTitle = ""
    @FocusState private var isEditing: Bool

    private var editing: Bool { state.editingTodoID == todo.id }

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

            if editing {
                TextField("", text: $draftTitle)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))
                    .focused($isEditing)
                    .onSubmit { state.commitEdit(id: todo.id, newTitle: draftTitle) }
                    .onChange(of: isEditing) { _, focused in
                        guard !focused, state.editingTodoID == todo.id else { return }
                        state.commitEdit(id: todo.id, newTitle: draftTitle)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text(todo.title)
                    .font(.system(size: 14))
                    .strikethrough()
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let timeStr = formatAccumulated(todo.accumulatedMinutes) {
                Text(timeStr)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .opacity(editing ? 1 : 0.6)
        .onChange(of: state.editingTodoID) { _, id in
            if id == todo.id {
                draftTitle = todo.title
                isEditing = true
            }
        }
        .contextMenu {
            Button { state.startEditing(id: todo.id) } label: {
                Label("이름 변경", systemImage: "pencil")
            }
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
