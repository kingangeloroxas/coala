//
//  PlanView.swift
//  Coala Beta 2.2
//
//  Created by Kristoffer Roxas on 8/3/25.
//


import SwiftUI
import FirebaseFirestore

struct PlanView: View {
    let groupId: String
    let topBranch: String

    @State private var date = ""
    @State private var time = ""
    @State private var location = ""
    @State private var note = ""
    @State private var isSaving = false
    @State private var successMessage = ""

    let db = Firestore.firestore()

    // 🔁 Replace this with actual logged-in username later
    let currentUser = "Alex"

    var isTopBranch: Bool {
        currentUser == topBranch
    }

    var body: some View {
        Form {
            Section(header: Text("Final Plan")) {
                TextField("Date (e.g. Aug 9)", text: $date)
                    .disabled(!isTopBranch)
                TextField("Time (e.g. 6:00 PM)", text: $time)
                    .disabled(!isTopBranch)
                TextField("Location", text: $location)
                    .disabled(!isTopBranch)
                TextField("Optional Note", text: $note)
                    .disabled(!isTopBranch)
            }

            if isTopBranch {
                Button(isSaving ? "Saving..." : "Save Plan") {
                    savePlan()
                }
                .disabled(isSaving || date.isEmpty || time.isEmpty || location.isEmpty)
            }

            if !successMessage.isEmpty {
                Text(successMessage)
                    .foregroundColor(.green)
            }
        }
        .navigationTitle("Group Plan")
        .onAppear(perform: loadPlan)
    }

    func loadPlan() {
        db.collection("groups").document(groupId).getDocument { snapshot, error in
            if let data = snapshot?.data(), let plan = data["plan"] as? [String: String] {
                date = plan["date"] ?? ""
                time = plan["time"] ?? ""
                location = plan["location"] ?? ""
                note = plan["note"] ?? ""
            }
        }
    }

    func savePlan() {
        isSaving = true
        let planData = [
            "date": date,
            "time": time,
            "location": location,
            "note": note
        ]
        db.collection("groups").document(groupId).updateData([
            "plan": planData
        ]) { error in
            isSaving = false
            if let error = error {
                print("Error saving plan: \(error.localizedDescription)")
            } else {
                successMessage = "✅ Plan saved!"
            }
        }
    }
}
