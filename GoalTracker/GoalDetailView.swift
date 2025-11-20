//
//  GoalDetailView.swift
//  GoalTracker
//
//  Created by Adilet Beishekeyev on 20.11.2025.
//

import SwiftData
import SwiftUI

struct GoalDetailView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) var dismiss

    @Bindable var goal: Goal

    @State private var isEditing = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {

            HStack {
                Text(goal.name)
                    .font(.largeTitle.bold())
                    .strikethrough(goal.isComplete)

                Spacer()

                Button("Edit", systemImage: "pencil.circle.fill") {
                    isEditing = true
                }
            }
            .padding(.bottom, 10)

            VStack(alignment: .leading, spacing: 8) {
                Text("Current Progress: \(goal.currentValue) / \(goal.targetValue)")
                    .font(.title3)

                ProgressView(value: goal.progressPercent)
                    .progressViewStyle(.linear)
                    .tint(goal.isComplete ? .green : .blue)
                    .scaleEffect(x: 1, y: 4, anchor: .center)
            }
            .padding(.vertical)

            HStack {
                Image(systemName: goal.isComplete ? "checkmark.seal.fill" : "hourglass")
                    .foregroundColor(goal.isComplete ? .green : .orange)

                Text(goal.isComplete ? "Goal Achieved!" : "Still in Progress...")
                    .font(.headline)
            }

            Divider()

            Text("Target Value: \(goal.targetValue)")
                .font(.title3)

            Text("Started on: \(goal.creationDate.formatted(date: .abbreviated, time: .shortened))")
                .foregroundColor(.secondary)

            Spacer()

            if !goal.isComplete {
                Button {
                    goal.currentValue = min(goal.currentValue + 1, goal.targetValue)

                    if goal.currentValue >= goal.targetValue {
                        goal.isComplete = true
                    }
                    goal.updatedAt = Date()  // Mark as updated
                    goal.updatedAt = Date()  // Mark as updated
                } label: {
                    Text("Increment Progress (+1)")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Delete", systemImage: "trash.fill") {
                    deleteGoal()
                }
                .tint(.red)
            }
        }
        .sheet(isPresented: $isEditing) {
            EditGoalView(goal: goal)
        }

    }
    private func deleteGoal() {
        withAnimation {
            modelContext.delete(goal)

            do {
                try modelContext.save()
            } catch {
                print("Error deleting goal from detail view: \(error.localizedDescription)")
            }
        }
    }

}

struct EditGoalView: View {
    @Environment(\.dismiss) var dismiss
    @Bindable var goal: Goal

    @State private var name: String
    @State private var targetValue: Int

    init(goal: Goal) {

        self.goal = goal
        _name = State(initialValue: goal.name)
        _targetValue = State(initialValue: goal.targetValue)
    }

    var body: some View {
        VStack(spacing: 20) {
            Text("Edit Goal")
                .font(.largeTitle)
                .padding(.bottom, 10)

            Form {
                TextField("Goal Name", text: $name)
                    .textFieldStyle(.roundedBorder)

                Stepper("Target Value: \(targetValue)", value: $targetValue, in: 1...9999)
            }
            .padding()

            Button("Update Goal") {
                goal.name = name
                goal.targetValue = targetValue

                if goal.currentValue >= targetValue {
                    goal.isComplete = true
                } else {
                    goal.isComplete = false
                }

                goal.currentValue = min(goal.currentValue, targetValue)

                goal.updatedAt = Date()  // Mark as updated

                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(40)
        .frame(minWidth: 400, idealWidth: 450, idealHeight: 300)
    }
}
