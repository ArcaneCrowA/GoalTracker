//
//  GoalListView.swift
//  GoalTracker
//
//  Created by Adilet Beishekeyev on 20.11.2025.
//

import SwiftUI
import SwiftData

struct GoalListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Goal.creationDate, order: .reverse) private var goals: [Goal]
    
    @State private var isShowingNewGoalSheet = false
    
    var body: some View {
        NavigationSplitView {
            List {
                ForEach(goals) { goal in
                    GoalRowView(goal: goal)
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
                }
            }
        } detail: {
            Text("Select a goal to view its details, or add a new one.")
                .font(.title3)
                .foregroundColor(.secondary)
        }
        .sheet(isPresented: $isShowingNewGoalSheet) {
            NewGoalView()
        }
    }
    
    
    private func deleteGoals(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(goals[index])
            }
            do {
                try modelContext.save()
            } catch {
                print("Error deleting goals: \(error.localizedDescription)")
            }
        }
    }
}


struct GoalRowView: View {
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
                    goal.currentValue = min(
                        goal.currentValue + 1,
                        goal.targetValue
                    )
                                
                                
                    if goal.currentValue >= goal.targetValue {
                        goal.isComplete = true
                    }
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
                    .frame(width:50)
            }
        }
        .padding(.vertical, 4)
    }
}


struct NewGoalView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) var dismiss
    
    @State private var name: String = ""
    @State private var targetValue: Int = 1
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Create New Goal")
                .font(.largeTitle)
                .padding(.bottom, 10)
            
            Form {
                TextField("Goal Name (e.g., Pages to read)", text: $name)
                    .textFieldStyle(.roundedBorder)
                
                Stepper(
                    "Target Value: \(targetValue)",
                    value: $targetValue,
                    in: 1...9999
                )
            }
            .padding()
            
            Button("Save Goal") {
                saveGoal()
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
            .disabled(
                name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            )
        }
        .padding(40)
        .frame(minWidth: 400, idealWidth: 450, idealHeight: 300)
    }
    
    private func saveGoal() {
        let newGoal = Goal(name: name, targetValue: targetValue)
        
        modelContext.insert(newGoal)
        
        do {
            try modelContext.save()
            dismiss()
        } catch {
            print("Error saving goal: \(error.localizedDescription)")
        }
    }
}
