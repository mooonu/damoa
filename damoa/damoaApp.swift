//
//  damoaApp.swift
//  damoa
//
//  Created by 김승현 on 4/19/26.
//

import SwiftUI

@main
struct damoaApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
