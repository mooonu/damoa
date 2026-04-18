# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Rules

- When creating git commits, do NOT include a `Co-Authored-By` line.
- After every commit, update CLAUDE.md to reflect any architectural or structural changes made in that task.
- Always stage and commit CLAUDE.md together with the related source changes in a single commit — no separate commit message needed for it.

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
- `damoa/AppDelegate.swift` — `NSStatusItem` ("0h 00m" 텍스트), 클릭 시 `NSPopover`(320×480)로 `ContentView` 표시
- `damoa/ContentView.swift` — 팝오버 내부 할 일 목록 UI. `TodoItem` 모델(`@State`)로 임시 관리. 날짜 헤더, 할 일 추가 입력, 체크박스/시간/타이머 버튼 행, 총 공부 시간 푸터 포함
- `damoa/Assets.xcassets` — asset catalog

The project uses **PBXFileSystemSynchronizedRootGroup**, meaning Xcode automatically tracks new files added to the `damoa/` directory without manually adding them to `project.pbxproj`.
