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
                    // The didSet observer in Goal.swift will set updatedAt
                    Task {
                        await pushUpdate(goal: goal)
                    }
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
            EditGoalView(goal: goal) {
                // This closure is called when EditGoalView saves
                Task {
                    await pushUpdate(goal: goal)
                }
            }
        }

    }
    private func deleteGoal() {
        withAnimation {
            let goalID = goal.id // Capture ID before deletion
            modelContext.delete(goal)

            do {
                try modelContext.save()
                Task {
                    await pushDelete(goalID: goalID)
                }
            } catch {
                print("Error deleting goal from detail view: \(error.localizedDescription)")
            }
        }
    }

    private func pushDelete(goalID: UUID) async {
        do {
            try await BackendService.shared.deleteGoal(id: goalID)
            print("Successfully pushed delete for goal ID: \(goalID)")
        } catch {
            print("Error pushing delete for goal ID \(goalID): \(error.localizedDescription)")
        }
    }

    private func pushUpdate(goal: Goal) async {
        do {
            try await BackendService.shared.updateGoal(goal: goal)
            print("Successfully pushed update for goal: \(goal.name)")
        } catch {
            print("Error pushing update for goal \(goal.name): \(error.localizedDescription)")
        }
    }
}

struct EditGoalView: View {
    @Environment(\.dismiss) var dismiss
    @Bindable var goal: Goal
    var onUpdate: () -> Void // Closure to be called after update

    @State private var name: String
    @State private var targetValue: Int

    init(goal: Goal, onUpdate: @escaping () -> Void) {
        self.goal = goal
        self.onUpdate = onUpdate
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
                // The didSet observer in Goal.swift will set updatedAt

                onUpdate() // Call the closure to trigger sync/push in parent view
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(40)
        .frame(minWidth: 400, idealWidth: 450, idealHeight: 300)
    }
}
