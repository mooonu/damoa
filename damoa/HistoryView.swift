//
//  HistoryView.swift
//  damoa
//
//  Created by 김승현 on 4/19/26.
//

import SwiftUI
import SwiftData

// MARK: - History View

struct HistoryView: View {
    @Query(sort: [SortDescriptor(\DayRecord.date, order: .reverse)]) private var dayRecords: [DayRecord]
    @State private var selectedRecord: DayRecord? = nil
    let onBack: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Divider()
            if let record = selectedRecord {
                DayDetailView(record: record)
            } else {
                DayListView(dayRecords: dayRecords, onSelect: { selectedRecord = $0 })
            }
        }
        .frame(width: 320, height: 480)
    }

    private var headerBar: some View {
        HStack {
            Button {
                if selectedRecord != nil {
                    selectedRecord = nil
                } else {
                    onBack()
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .medium))
                    Text(selectedRecord != nil ? "기록" : "돌아가기")
                        .font(.system(size: 13))
                }
                .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - Day List View

struct DayListView: View {
    let dayRecords: [DayRecord]
    let onSelect: (DayRecord) -> Void

    var body: some View {
        if dayRecords.isEmpty {
            VStack {
                Spacer()
                Text("기록이 없습니다")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(dayRecords, id: \.id) { record in
                        DayRecordRow(record: record)
                            .onTapGesture { onSelect(record) }
                        Divider()
                            .padding(.horizontal, 16)
                    }
                }
            }
        }
    }
}

// MARK: - Day Record Row

struct DayRecordRow: View {
    let record: DayRecord

    private var dateLabel: String {
        let parser = DateFormatter()
        parser.dateFormat = "yyyy-MM-dd"
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "M월 d일 EEEE"
        guard let date = parser.date(from: record.date) else { return record.date }
        return formatter.string(from: date)
    }

    private var completedCount: Int {
        record.todos.filter { $0.isCompleted }.count
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(dateLabel)
                    .font(.system(size: 14))
                    .foregroundStyle(.primary)
                HStack(spacing: 8) {
                    Text(formatTotal(record.totalMinutes))
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    Text("\(completedCount)/\(record.todos.count)")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "chevron.right")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}

// MARK: - Day Detail View

struct DayDetailView: View {
    let record: DayRecord

    private var sortedTodos: [TodoItem] {
        record.todos.sorted { $0.createdAt < $1.createdAt }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(sortedTodos, id: \.id) { todo in
                    HStack(spacing: 8) {
                        completionIcon(todo.isCompleted)
                        Text(todo.title)
                            .font(.system(size: 14))
                            .foregroundStyle(todo.isCompleted ? .secondary : .primary)
                            .strikethrough(todo.isCompleted)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        if let t = formatAccumulated(todo.accumulatedMinutes) {
                            Text(t)
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .opacity(todo.isCompleted ? 0.6 : 1)
                }
            }
        }
    }

    @ViewBuilder
    private func completionIcon(_ isCompleted: Bool) -> some View {
        if isCompleted {
            ZStack {
                Circle()
                    .fill(Color.secondary)
                    .frame(width: 16, height: 16)
                Image(systemName: "checkmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.white)
            }
        } else {
            Circle()
                .strokeBorder(Color.secondary.opacity(0.5), lineWidth: 1.5)
                .frame(width: 16, height: 16)
        }
    }
}
