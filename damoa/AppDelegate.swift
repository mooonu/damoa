//
//  AppDelegate.swift
//  damoa
//
//  Created by 김승현 on 4/19/26.
//

import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private let appState = AppState()

    func applicationDidFinishLaunching(_ notification: Notification) {
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
        let contentView = ContentView().environment(appState)
        let controller = NSHostingController(rootView: contentView)
        controller.sizingOptions = .preferredContentSize
        popover.contentViewController = controller
    }

    @objc func togglePopover() {
        guard let button = statusItem.button else { return }

        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }
}
