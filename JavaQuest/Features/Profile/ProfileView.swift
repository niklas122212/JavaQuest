import SwiftUI
import JavaQuestKit

struct ProfileView: View {
    @Environment(ProgressStore.self) private var store
    @State private var confirmReset = false

    private var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(short) (\(build))"
    }

    var body: some View {
        Form {
            if let profile = store.profile {
                Section("Lernprofil") {
                    LabeledContent("Selbsteinschätzung", value: profile.experienceLevel.title)
                    if let score = profile.placementScore {
                        LabeledContent("Einstufungstest", value: "\(score) %")
                    }
                    if let placed = profile.placedLevel {
                        LabeledContent("Eingestiegen bei", value: store.course.entryModule(for: placed)?.title ?? placed.title)
                    }
                    LabeledContent("Dabei seit") { Text(profile.createdAt, format: .dateTime.day().month(.wide).year()) }
                }
                Section("Fortschritt") {
                    LabeledContent("Java Master Score", value: "\(store.masterScore) / \(MasterScore.maximum)")
                    LabeledContent("Rang", value: store.rank.title)
                    LabeledContent("Längste Serie", value: profile.longestStreak == 1 ? "1 Tag" : "\(profile.longestStreak) Tage")
                    LabeledContent("Lektionen", value: "\(store.completedLessonCount) von \(store.course.allLessons.count)")
                }
            }

            Section {
                Label("Alle Daten bleiben auf diesem Gerät. Kein Konto, kein Tracking, keine Netzwerkverbindung – auch die Auswertung deiner Antworten läuft lokal.", systemImage: "lock.shield.fill")
                    .foregroundStyle(.secondary)
            } header: {
                Text("Datenschutz")
            }

            Section {
                Button("Fortschritt zurücksetzen", role: .destructive) { confirmReset = true }
            } footer: {
                Text("JavaQuest \(version) · Kurs „\(store.course.title)“")
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Profil")
        .confirmationDialog("Gesamten Fortschritt löschen?", isPresented: $confirmReset, titleVisibility: .visible) {
            Button("Alles zurücksetzen", role: .destructive) { store.resetAllProgress() }
        } message: {
            Text("Score, Lernpfad und Wissensanalyse werden gelöscht. Danach startest du wieder mit der Einstufung.")
        }
    }
}
