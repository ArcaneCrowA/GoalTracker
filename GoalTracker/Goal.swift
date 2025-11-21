//
//  Goal.swift
//  GoalTracker
//
//  Created by Adilet Beishekeyev on 20.11.2025.
//

import Foundation
import SwiftData

@Model
final class Goal: Identifiable {
    @Attribute(.unique) var id: UUID
    var name: String { didSet { updatedAt = Date() } }
    var targetValue: Int { didSet { updatedAt = Date() } }
    var currentValue: Int { didSet { updatedAt = Date() } }
    var creationDate: Date
    var isComplete: Bool { didSet { updatedAt = Date() } }
    var updatedAt: Date

    init(
        id: UUID = UUID(), name: String, targetValue: Int, currentValue: Int = 0,
        creationDate: Date = Date(), isComplete: Bool = false, updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.targetValue = targetValue
        self.currentValue = currentValue
        self.creationDate = creationDate
        self.isComplete = isComplete
        self.updatedAt = updatedAt

        if currentValue >= targetValue {
            self.isComplete = true
        }
    }

    var progressPercent: Double {
        if targetValue == 0 { return 0 }
        return min(Double(currentValue) / Double(targetValue), 1.0)
    }
}
