//
//  AppDelegate.swift
//  damoa
//
//  Created by 김승현 on 4/19/26.
//

import AppKit
import SwiftUI
import SwiftData

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var appState: AppState!
    private var modelContainer: ModelContainer!

    func applicationDidFinishLaunching(_ notification: Notification) {
        do {
            modelContainer = try ModelContainer(for: TodoItem.self, DayRecord.self)
        } catch {
            fatalError("ModelContainer 생성 실패: \(error)")
        }

        appState = AppState(modelContext: modelContainer.mainContext)

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.title = appState.menuBarText
            button.action = #selector(togglePopover)
            button.target = self
        }

        appState.onMenuBarTextChange = { [weak self] text in
            self?.statusItem.button?.title = text
        }

        popover = NSPopover()
        popover.behavior = .transient
        let contentView = ContentView()
            .environment(appState)
            .modelContainer(modelContainer)
        let controller = NSHostingController(rootView: contentView)
        controller.sizingOptions = .preferredContentSize
        popover.contentViewController = controller
    }

    @objc func togglePopover() {
        guard let button = statusItem.button else { return }

        if popover.isShown {
            popover.performClose(nil)
        } else {
            appState.popoverOpenToken += 1
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }
}
