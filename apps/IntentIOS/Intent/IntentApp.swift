//
//  IntentApp.swift
//  Intent
//
//  Created by Codex on 2026-05-11.
//

import SwiftUI

@main
struct IntentApp: App {
    @StateObject private var model = IntentionalityAppModel()

    var body: some Scene {
        WindowGroup {
            ContentView(model: model)
                .preferredColorScheme(.dark)
        }
    }
}
