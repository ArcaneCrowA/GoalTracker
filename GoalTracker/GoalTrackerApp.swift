//
//  GoalTrackerApp.swift
//  GoalTracker
//
//  Created by Adilet Beishekeyev on 20.11.2025.
//

import SwiftUI
import SwiftData

@main
struct GoalTrackerApp: App {
    var body: some Scene {
        WindowGroup {
            GoalListView()
        }
        .modelContainer(for: Goal.self)
    }
}
