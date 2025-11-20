//
//  Item.swift
//  GoalTracker
//
//  Created by Adilet Beishekeyev on 20.11.2025.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
