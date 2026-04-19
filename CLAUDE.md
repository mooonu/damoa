# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Rules

- When creating git commits, do NOT include a `Co-Authored-By` line.
- After every commit, update CLAUDE.md to reflect any architectural or structural changes made in that task.
- Always stage and commit CLAUDE.md together with the related source changes in a single commit — no separate commit message needed for it.
- Never run `git push` unless the user explicitly asks.
- When installing a built .app to /Applications, always `rm -rf` the existing app first, then `cp -R`. Never overwrite directly (cp -R into an existing bundle creates a nested copy).
- Commit at feature-level milestones only — not after every sub-task. Multiple file changes that together complete one feature = one commit.

## Design Principles (strictly enforced)

- Use system fonts only (`.system`)
- Use SF Symbols icons only
- Use semantic colors only (`Color.primary`, `.secondary`, `.accentColor`) — no hardcoded color values
- Spacing in 8pt increments (8, 16, 24)
- Prefer SwiftUI built-in components (`List`, `TextField`, `Button`, `Toggle`)
- Completed items: apply `.strikethrough` + `.secondary` color to text
- Do not display redundant zero values (e.g. `0h 00m` → `0m`)

## Project Overview

**damoa** is a macOS menu bar app built with SwiftUI. Targets macOS only (SDKROOT=macosx), minimum deployment target macOS 26.4, Swift 5.0. Dock icon is hidden (LSUIElement=YES).

## Build & Run

This is an Xcode project — build and run via Xcode or `xcodebuild`:

```bash
# Build
xcodebuild -project damoa.xcodeproj -scheme damoa -configuration Debug build

# Run tests (once tests exist)
xcodebuild test -project damoa.xcodeproj -scheme damoa -destination 'platform=macOS'
```

Open in Xcode: `open damoa.xcodeproj`

## Architecture

macOS menu bar only app:

- `damoa/damoaApp.swift` — app entry point (`@main`), uses `@NSApplicationDelegateAdaptor(AppDelegate.self)`, body is `Settings { EmptyView() }` (no visible window)
- `damoa/AppDelegate.swift` — `NSStatusItem` 생성, 클릭 시 `NSPopover`(320×480)로 `ContentView` 표시. `AppState` 인스턴스를 소유하고 `onMenuBarTextChange` 콜백으로 메뉴바 텍스트 갱신. 팝오버 열기 전 `checkAndReloadIfDateChanged()` 호출
- `damoa/Models.swift` — SwiftData `@Model` 클래스. `TodoItem`(id, title, isCompleted, accumulatedMinutes, createdAt, completedAt, date, dayRecord)과 `DayRecord`(id, date, totalMinutes, todos) 정의. `DayRecord → TodoItem` cascade 삭제 관계
- `damoa/AppState.swift` — `@Observable @MainActor` 공유 상태. `ModelContext`를 init에서 주입받아 모든 CRUD를 SwiftData로 처리. 포맷 헬퍼(`formatTotal`, `formatAccumulated`, `formatCountdown`)는 분 단위 기준. 타이머 로직은 초 단위 유지. `loadedDateString`으로 현재 로드된 날짜 추적; `checkAndReloadIfDateChanged()`로 날짜 전환 감지 및 재로드; 60초 주기 `dateCheckTimer`로 자정 통과 대응
- `damoa/ContentView.swift` — 팝오버 UI(320×480). 상단 날짜/누적시간 헤더, 투명 입력 필드, 할 일 목록(진행 중/대기/완료 구분 행), 하단 기록 푸터. `AppState`를 `.environment`로 주입받음
- `damoa/HistoryView.swift` — 기록 화면. `@Query`로 DayRecord 전체 조회, 날짜별 목록 → 할 일 상세 2단계 내비게이션
- `damoa/Assets.xcassets` — asset catalog

### 타이머 동작
- `PendingTodoRow`의 ▶ 버튼(Menu) → 5/10/15/20/25/30분 선택 → 카운트다운 시작
- 동시에 하나의 타이머만 실행 (새 타이머 시작 시 기존 취소)
- 타이머 가동 중: 메뉴바 텍스트 = 카운트다운 (`"24:38"`)
- 타이머 미가동: 메뉴바 텍스트 = 총 누적시간
- 0 도달 시 해당 항목에 세션 시간 자동 누적
- 중간 정지(전환/완료체크/수동정지) 시 경과 시간만큼 누적 (`stopAndAccumulate()`)
- 삭제 및 날 초기화 시에는 경과 시간 누적 없이 타이머만 취소 (`cancelTimer()`)

### 누적시간 표시 규칙
- 0분: 표시 안 함 (항목 행), `"0m"` (헤더 합계)
- 1~59분: `"32m"`
- 60분 이상: `"1h 5m"`
- 저장 단위: 분 (`accumulatedMinutes`). 타이머 내부는 초(`remainingSeconds`, `sessionDuration`) 단위 유지, 누적 시 `/60` 변환

### 통계
- **날짜 전환 감지**: `loadedDateString`에 현재 로드된 날짜 보관. `checkAndReloadIfDateChanged()`가 오늘 날짜와 다르면 `loadToday()` 재호출. 호출 지점: ① 60초 주기 타이머(자정 자동 전환) ② 팝오버 열기(AppDelegate) ③ `addTodo()` 진입 시
- `yesterdayDiff: Int?` — 오늘 누적 - 어제 누적. 어제 기록 없거나 차이 0이면 nil. `_yesterdayMinutes`에 앱 시작 시 캐시
- `streakDays: Int` — 오늘(0m이면 어제)부터 연속으로 totalMinutes > 0인 날 수. save() 시마다 갱신
- `ContentView` 헤더에 어제 대비 표시 (green/orange), 푸터에 연속 일수 표시
- `기록` 버튼 → `HistoryView` 전환 (`showHistory: Bool` in ContentView)

The project uses **PBXFileSystemSynchronizedRootGroup**, meaning Xcode automatically tracks new files added to the `damoa/` directory without manually adding them to `project.pbxproj`.
