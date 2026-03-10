//
//  IntentApp.swift
//  Intent
//
//  Created by Codex on 2026-03-10.
//

import SwiftUI

@main
struct IntentApp: App {
    @StateObject private var model = IntentAppModel()

    var body: some Scene {
        WindowGroup(id: "main") {
            ContentView(model: model)
        }

        MenuBarExtra(
            "Intent",
            systemImage: model.pendingReviewsCount > 0 ? "flag.fill" : "scope"
        ) {
            MenuBarView(model: model)
        }
    }
}
