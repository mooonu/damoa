//
//  ContentView.swift
//  damoa
//
//  Created by 김승현 on 4/19/26.
//

import SwiftUI

struct TodoItem: Identifiable {
    let id = UUID()
    var text: String
    var isCompleted: Bool = false
    var elapsedSeconds: Int = 0
}

struct ContentView: View {
    @State private var todos: [TodoItem] = []
    @State private var newTodoText: String = ""

    private var todayString: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "yyyy년 M월 d일 EEEE"
        return formatter.string(from: Date())
    }

    private var totalSeconds: Int {
        todos.reduce(0) { $0 + $1.elapsedSeconds }
    }

    private func formattedTotal() -> String {
        let h = totalSeconds / 3600
        let m = (totalSeconds % 3600) / 60
        return "\(h)h \(String(format: "%02d", m))m"
    }

    var body: some View {
        VStack(spacing: 0) {
            // 오늘 날짜
            Text(todayString)
                .font(.subheadline)
                .fontWeight(.medium)
                .padding(.vertical, 12)

            Divider()

            // 할 일 목록
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach($todos) { $todo in
                        TodoRowView(todo: $todo)
                        Divider()
                    }
                }
            }

            Divider()

            // 입력 필드
            HStack(spacing: 8) {
                TextField("할 일 추가", text: $newTodoText)
                    .textFieldStyle(.plain)
                    .onSubmit { addTodo() }

                Button("추가") { addTodo() }
                    .disabled(newTodoText.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            // 총 공부 시간
            HStack {
                Text("오늘 총 공부:")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
                Spacer()
                Text(formattedTotal())
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
    }

    private func addTodo() {
        let trimmed = newTodoText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        todos.append(TodoItem(text: trimmed))
        newTodoText = ""
    }
}

struct TodoRowView: View {
    @Binding var todo: TodoItem

    private func formattedTime(_ seconds: Int) -> String {
        if seconds < 3600 {
            return "\(seconds / 60)m"
        }
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        return "\(h)h \(String(format: "%02d", m))m"
    }

    var body: some View {
        HStack(spacing: 8) {
            // 체크박스
            Button {
                todo.isCompleted.toggle()
            } label: {
                Image(systemName: todo.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(todo.isCompleted ? Color.accentColor : .secondary)
                    .font(.system(size: 16))
            }
            .buttonStyle(.plain)

            // 할 일 텍스트
            Text(todo.text)
                .strikethrough(todo.isCompleted)
                .foregroundStyle(todo.isCompleted ? .secondary : .primary)
                .frame(maxWidth: .infinity, alignment: .leading)

            // 누적 시간
            Text(formattedTime(todo.elapsedSeconds))
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(minWidth: 24, alignment: .trailing)

            // 타이머 시작 버튼
            Button {
                // 타이머 동작은 추후 구현
            } label: {
                Image(systemName: "play.fill")
                    .font(.caption)
                    .foregroundStyle(Color.accentColor)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
}

#Preview {
    ContentView()
        .frame(width: 320, height: 480)
}
