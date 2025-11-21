//
//  GoalListView.swift
//  GoalTracker
//
//  Created by Adilet Beishekeyev on 20.11.2025.
//

import SwiftData
import SwiftUI

struct GoalListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Goal.creationDate, order: .reverse) private var goals: [Goal]

    @State private var selectedGoal: Goal?
    @State private var isShowingNewGoalSheet = false
    @AppStorage("lastSyncTime") private var lastSyncTime: Date = .distantPast

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedGoal) {
                ForEach(goals) { goal in
                    GoalRowContent(goal: goal)
                        .tag(goal)
                }
                .onDelete(perform: deleteGoals)
            }
            .navigationTitle("Goals")
            .toolbar {
                ToolbarItemGroup {
                    Button("New Goal", systemImage: "plus.circle.fill") {
                        isShowingNewGoalSheet = true
                    }
                    .keyboardShortcut("n", modifiers: [.command])

                    Button("Sync", systemImage: "arrow.triangle.2.circlepath") {
                        Task {
                            await syncData()
                        }
                    }
                }
            }
            .onAppear {
                Task {
                    await syncData()
                }
            }
        } detail {
            if let goal = selectedGoal {
                GoalDetailView(goal: goal)
            } else {
                Text("Select a goal to view its details, or add a new one.")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
        }
        .sheet(isPresented: $isShowingNewGoalSheet) {
            NewGoalView(onSave: {
                Task {
                    await syncData()
                }
            })
        }
    }

    private func deleteGoals(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                let goalToDelete = goals[index]
                modelContext.delete(goalToDelete)
                Task {
                    do {
                        try await BackendService.shared.deleteGoal(id: goalToDelete.id)
                        print("Successfully pushed delete for goal ID: \(goalToDelete.id)")
                    } catch {
                        print("Error pushing delete for goal ID \(goalToDelete.id): \(error.localizedDescription)")
                    }
                }
            }
            do {
                try modelContext.save()
            } catch {
                print("Error deleting goals: \(error.localizedDescription)")
            }
        }
    }

    private func syncData() async {
        print("Starting sync...")
        do {
            let remoteGoals = try await BackendService.shared.fetchGoals(since: lastSyncTime)
            print("Fetched \(remoteGoals.count) remote goals.")

            await MainActor.run {
                applyRemoteChanges(remoteGoals)
                lastSyncTime = Date()
            }
            print("Sync completed successfully. Last sync time: \(lastSyncTime)")

        } catch {
            print("Sync failed: \(error.localizedDescription)")
        }
    }

    private func applyRemoteChanges(_ remoteGoals: [GoalResponse]) {
        for remoteGoal in remoteGoals {
            let localGoal = goals.first { $0.id == remoteGoal.id }

            if let localGoal = localGoal {
                if remoteGoal.updated_at > localGoal.updatedAt {
                    print("Updating local goal: \(localGoal.name) (ID: \(localGoal.id))")
                    localGoal.name = remoteGoal.name
                    localGoal.targetValue = remoteGoal.target_value
                    localGoal.currentValue = remoteGoal.current_value
                    localGoal.updatedAt = remoteGoal.updated_at
                    localGoal.isComplete = localGoal.currentValue >= localGoal.targetValue
                }
            } else {
                print("Inserting new local goal: \(remoteGoal.name) (ID: \(remoteGoal.id))")
                let newGoal = Goal(
                    id: remoteGoal.id,
                    name: remoteGoal.name,
                    targetValue: remoteGoal.target_value,
                    currentValue: remoteGoal.current_value,
                    updatedAt: remoteGoal.updated_at
                )
                modelContext.insert(newGoal)
            }
        }

        do {
            try modelContext.save()
            print("Local SwiftData store saved after applying remote changes.")
        } catch {
            print("Error saving modelContext after sync: \(error.localizedDescription)")
        }
    }
}
struct GoalRowContent: View {
    @Bindable var goal: Goal

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(goal.name)
                    .font(.headline)
                    .strikethrough(goal.isComplete)

                Text("Progress: \(goal.currentValue) / \(goal.targetValue)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            ProgressView(value: goal.progressPercent)
                .progressViewStyle(.linear)
                .frame(width: 120)
                .scaleEffect(x: 1, y: 1.5, anchor: .center)

            if !goal.isComplete {
                Button {
                    goal.currentValue = min(goal.currentValue + 1, goal.targetValue)
                    if goal.currentValue >= goal.targetValue {
                        goal.isComplete = true
                    }
                    goal.updatedAt = Date()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title)
                        .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
                .frame(width: 50)
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.title)
                    .frame(width: 50)
            }
        }
        .padding(.vertical, 4)
    }
}

struct NewGoalView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) var dismiss

    var onSave: () -> Void

    @State private var name: String = ""
    @State private var targetValue: Int = 1

    init(onSave: @escaping () -> Void) {
        self.onSave = onSave
    }

    var body: some View {
        VStack(spacing: 20) {
            Text("Create New Goal")
                .font(.largeTitle)
                .padding(.bottom, 10)

            Form {
                TextField("Goal Name (e.g., Pages to read)", text: $name)
                    .textFieldStyle(.roundedBorder)

                Stepper("Target Value: \(targetValue)", value: $targetValue, in: 1...9999)
            }
            .padding()

            Button("Save Goal") {
                saveGoal()
                onSave()
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
            .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(40)
        .frame(minWidth: 400, idealWidth: 450, idealHeight: 300)
    }

    private func saveGoal() {
        let newGoal = Goal(name: name, targetValue: targetValue, updatedAt: Date())

        modelContext.insert(newGoal)

        do {
            try modelContext.save()
            // Push to backend after local save
            Task {
                await pushCreate(goal: newGoal)
            }
            dismiss()
        } catch {
            print("Error saving goal: \(error.localizedDescription)")
        }
    }

    private func pushCreate(goal: Goal) async {
        do {
            try await BackendService.shared.createGoal(goal: goal)
            print("Successfully pushed new goal: \(goal.name)")
        } catch {
            print("Error pushing new goal \(goal.name): \(error.localizedDescription)")
        }
    }
}
