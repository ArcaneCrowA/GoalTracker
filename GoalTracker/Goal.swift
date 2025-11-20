//
//  Item.swift
//  GoalTracker
//
//  Created by Adilet Beishekeyev on 20.11.2025.
//

import Foundation
import SwiftData

@Model
final class Goal {
    var id: UUID = UUID()
    var name: String
    var targetValue: Int
    var currentValue: Int
    var creationDate: Date
    var isComplete: Bool
    
    init(name: String, targetValue: Int, currentValue: Int = 0, creationDate: Date = Date(), isComplete: Bool = false) {
        self.name = name
        self.targetValue = targetValue
        self.currentValue = currentValue
        self.creationDate = creationDate
        self.isComplete = isComplete
        
        if currentValue >= targetValue {
            self.isComplete = true
        }
    }
    
    var progressPercent: Double {
        if targetValue == 0 { return 0 }
        return min(Double(currentValue) / Double(targetValue), 1.0)
    }
}
