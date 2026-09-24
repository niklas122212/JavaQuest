import SwiftUI
import UniformTypeIdentifiers
import JavaQuestKit

struct ProfileView: View {
    @Environment(ProgressStore.self) private var store
    @State private var confirmReset = false
    @State private var zeigeExport = false
    @State private var exportDaten: Data?
    @State private var zeigeImport = false
    @State private var sicherungsMeldung: String?
    @AppStorage(Erinnerungen.anSchluessel) private var erinnerungAn = false
    @AppStorage(Erinnerungen.minutenSchluessel) private var erinnerungMinuten = ReviewReminder.defaultMinutes
    @State private var erinnerungsMeldung: String?

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
                Toggle("An fällige Wiederholungen erinnern", isOn: Binding(
                    get: { erinnerungAn },
                    set: { neu in
                        guard neu else { erinnerungAn = false; Erinnerungen.planen(for: store); return }
                        Task {
                            if await Erinnerungen.erlaubnisHolen() {
                                erinnerungAn = true
                                erinnerungsMeldung = nil
                            } else {
                                erinnerungAn = false
                                erinnerungsMeldung = "Mitteilungen sind für JavaQuest ausgeschaltet – in den Systemeinstellungen unter „Mitteilungen“ erlauben."
                            }
                            Erinnerungen.planen(for: store)
                        }
                    }
                ))
                if erinnerungAn {
                    DatePicker("Uhrzeit", selection: Binding(
                        get: { Calendar.current.date(bySettingHour: erinnerungMinuten / 60, minute: erinnerungMinuten % 60, second: 0, of: .now) ?? .now },
                        set: { zeit in
                            let teile = Calendar.current.dateComponents([.hour, .minute], from: zeit)
                            erinnerungMinuten = (teile.hour ?? 18) * 60 + (teile.minute ?? 0)
                            Erinnerungen.planen(for: store)
                        }
                    ), displayedComponents: .hourAndMinute)
                    if let naechste = Erinnerungen.termine(for: store).first {
                        LabeledContent("Nächste Erinnerung") {
                            Text("\(naechste.date.formatted(.dateTime.weekday(.abbreviated).day().month().hour().minute())) · \(naechste.count == 1 ? "1 Lernziel" : "\(naechste.count) Lernziele")")
                        }
                    } else {
                        Text("Gerade ist nichts zur Wiederholung vorgemerkt.").foregroundStyle(.secondary)
                    }
                }
                if let erinnerungsMeldung {
                    Text(erinnerungsMeldung).font(.footnote).foregroundStyle(.secondary)
                }
            } header: {
                Text("Erinnerung")
            } footer: {
                Text("Nur an Tagen, an denen wirklich etwas fällig ist – und höchstens drei Tage hintereinander, falls du nicht reinschaust. Wer übt, verschiebt die nächste Erinnerung von selbst.")
            }

            Section {
                Label("Alle Daten bleiben auf diesem Gerät. Kein Konto, kein Tracking, keine Netzwerkverbindung – auch die Auswertung deiner Antworten läuft lokal.", systemImage: "lock.shield.fill")
                    .foregroundStyle(.secondary)
            } header: {
                Text("Datenschutz")
            }

            Section {
                Button("Sicherung speichern …", systemImage: "square.and.arrow.down") {
                    // Die Daten entstehen hier auf dem Hauptthread; das Dokument selbst
                    // wird von SwiftUI außerhalb davon gebaut und darf nicht auf den
                    // Speicher zugreifen.
                    do {
                        exportDaten = try store.backupData()
                        zeigeExport = true
                    } catch {
                        sicherungsMeldung = "Sicherung fehlgeschlagen: \(error.localizedDescription)"
                    }
                }
                Button("Sicherung einlesen …", systemImage: "square.and.arrow.up") { zeigeImport = true }
                if let sicherungsMeldung {
                    Text(sicherungsMeldung).font(.footnote).foregroundStyle(.secondary)
                }
            } header: {
                Text("Fortschritt sichern")
            } footer: {
                Text("Eine Datei zum Mitnehmen. Beim Einlesen wird nichts gelöscht: Aus beiden Ständen wird jeweils das bessere Ergebnis übernommen. Die Datei passt in jede Fassung: Web-App, Mac, iPhone und Windows.")
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
        .fileExporter(isPresented: $zeigeExport, document: exportDaten.map(SicherungsDatei.init),
                      contentType: .json, defaultFilename: dateiname()) { ergebnis in
            switch ergebnis {
            case .success: sicherungsMeldung = "Sicherung gespeichert."
            case .failure(let fehler): sicherungsMeldung = "Speichern fehlgeschlagen: \(fehler.localizedDescription)"
            }
        }
        .fileImporter(isPresented: $zeigeImport, allowedContentTypes: [.json]) { ergebnis in
            switch ergebnis {
            case .success(let url):
                // Aus dem Dateiauswahl-Dialog kommt eine Adresse außerhalb der Sandbox;
                // ohne diesen Zugriff schlägt das Lesen auf dem Mac fehl.
                let zugriff = url.startAccessingSecurityScopedResource()
                defer { if zugriff { url.stopAccessingSecurityScopedResource() } }
                guard let daten = try? Data(contentsOf: url) else {
                    sicherungsMeldung = "Die Datei ließ sich nicht lesen."
                    return
                }
                if let dazu = store.importBackup(daten) {
                    sicherungsMeldung = "Eingelesen: \(dazu) Aufgabe(n) dazugekommen, nichts gelöscht."
                } else {
                    sicherungsMeldung = "Das sieht nicht nach einer JavaQuest-Sicherung aus."
                }
            case .failure(let fehler):
                sicherungsMeldung = "Einlesen fehlgeschlagen: \(fehler.localizedDescription)"
            }
        }
    }

    private func dateiname() -> String {
        "javaquest-" + Date.now.formatted(.iso8601.year().month().day().dateSeparator(.dash))
    }
}

/// Hülle für den Export-Dialog: SwiftUI verlangt ein Dokument, wir haben nur Daten.
private struct SicherungsDatei: FileDocument {
    static let readableContentTypes = [UTType.json]

    let daten: Data

    init(_ daten: Data) {
        self.daten = daten
    }

    init(configuration: ReadConfiguration) throws {
        daten = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: daten)
    }
}
