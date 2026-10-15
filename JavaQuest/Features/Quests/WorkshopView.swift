import SwiftUI
import JavaQuestKit

/// Ein eigenes Programm in der Werkstatt.
struct WorkshopProject: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var code: String
    var updatedAt = Date()

    static func template(named name: String) -> WorkshopProject {
        let className = name.filter { $0.isLetter || $0.isNumber }.prefix(1).uppercased() + String(name.filter { $0.isLetter || $0.isNumber }.dropFirst())
        let safe = className.isEmpty || !(className.first?.isLetter ?? false) ? "MeinProgramm" : className
        return WorkshopProject(name: name, code: """
        public class \(safe) {
            public static void main(String[] args) {
                System.out.println("Hallo aus der Werkstatt!");
            }
        }
        """)
    }
}

/// Die Projekte der Werkstatt – lokal auf diesem Gerät.
@MainActor
@Observable
final class WorkshopModel {
    private static let key = "workshopProjects"

    var projects: [WorkshopProject]
    var selectedId: UUID
    private(set) var output = ""
    private(set) var problem: JavaProblem?
    private(set) var warnings: [JavaWarning] = []
    private(set) var isRunning = false
    /// Der Code des letzten Laufs – nur dafür gibt es „Zusehen“.
    private(set) var ranCode: String?
    let editor = CodeEditorController()

    init() {
        let stored = (LocalDrafts.isEnabled ? UserDefaults.standard.data(forKey: Self.key) : nil).flatMap { try? JSONDecoder().decode([WorkshopProject].self, from: $0) } ?? []
        let projects = stored.isEmpty ? [WorkshopProject.template(named: "Mein Programm")] : stored
        self.projects = projects
        selectedId = projects[0].id
    }

    var code: String {
        get { projects.first { $0.id == selectedId }?.code ?? "" }
        set {
            guard let index = projects.firstIndex(where: { $0.id == selectedId }) else { return }
            projects[index].code = newValue
            projects[index].updatedAt = .now
            save()
        }
    }

    var selected: WorkshopProject? { projects.first { $0.id == selectedId } }

    func select(_ id: UUID) {
        selectedId = id
        clearRun()
    }

    func newProject() {
        let project = WorkshopProject.template(named: "Programm \(projects.count + 1)")
        projects.append(project)
        select(project.id)
        save()
    }

    func rename(to name: String) {
        guard let index = projects.firstIndex(where: { $0.id == selectedId }), !name.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        projects[index].name = name
        save()
    }

    func deleteSelected() {
        projects.removeAll { $0.id == selectedId }
        if projects.isEmpty { projects = [.template(named: "Mein Programm")] }
        select(projects[0].id)
        save()
    }

    func run() async {
        guard !isRunning else { return }
        isRunning = true
        let code = JavaSource.normalizingTypography(code)
        let result = await Task.detached(priority: .userInitiated) { JavaRunner.run(code) }.value
        output = result.output
        problem = result.problem
        warnings = result.warnings
        ranCode = code
        isRunning = false
    }

    private func clearRun() {
        output = ""
        problem = nil
        warnings = []
        ranCode = nil
    }

    private func save() {
        guard LocalDrafts.isEnabled else { return }
        if let data = try? JSONEncoder().encode(projects) { UserDefaults.standard.set(data, forKey: Self.key) }
    }
}

struct WorkshopContainer: View {
    @Environment(\.dismiss) private var dismiss
    @State private var model = WorkshopModel()

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 34, height: 34)
                        .background(Theme.fieldBackground, in: Circle())
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.cancelAction)
                .accessibilityLabel(Text("Schließen"))
                Label("Werkstatt", systemImage: "hammer.fill").font(.subheadline.weight(.semibold))
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(.bar)
            WorkshopView(model: model)
        }
        .background(Theme.screenBackground)
    }
}

/// Freies Bauen: eigene Programme schreiben, ausführen, zusehen – mit den Bauplänen aus den Quests.
struct WorkshopView: View {
    @Bindable var model: WorkshopModel
    @Environment(ProgressStore.self) private var store
    @State private var width: CGFloat = 400
    @State private var isRenaming = false
    @State private var newName = ""
    @State private var confirmsDelete = false

    private var isWide: Bool { width >= 900 }

    var body: some View {
        Group {
            if isWide {
                HStack(alignment: .top, spacing: 0) {
                    ScrollView { main.padding(24) }
                    Divider()
                    ScrollView { sidebar.padding(20) }
                        .frame(width: 320)
                        .background(Theme.cardBackground.opacity(0.5))
                }
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        main
                        sidebar
                    }
                    .padding(16)
                }
                .scrollDismissesKeyboard(.interactively)
            }
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
        .alert("Programm umbenennen", isPresented: $isRenaming) {
            TextField("Name", text: $newName)
            Button("Umbenennen") { model.rename(to: newName) }
            Button("Abbrechen", role: .cancel) {}
        }
        .confirmationDialog("„\(model.selected?.name ?? "Programm")“ löschen?", isPresented: $confirmsDelete, titleVisibility: .visible) {
            Button("Löschen", role: .destructive) { model.deleteSelected() }
        } message: {
            Text("Das Programm und sein Code sind danach weg.")
        }
    }

    private var main: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Menu {
                    Picker("Programm", selection: Binding(get: { model.selectedId }, set: { model.select($0) })) {
                        ForEach(model.projects) { project in
                            Text(project.name).tag(project.id)
                        }
                    }
                    Divider()
                    Button { model.newProject() } label: { Label("Neues Programm", systemImage: "plus") }
                    Button {
                        newName = model.selected?.name ?? ""
                        isRenaming = true
                    } label: { Label("Umbenennen …", systemImage: "pencil") }
                    Button(role: .destructive) { confirmsDelete = true } label: { Label("Löschen …", systemImage: "trash") }
                } label: {
                    Label(model.selected?.name ?? "Programm", systemImage: "doc.text.fill")
                        .font(.headline)
                }
                .menuStyle(.button)
                .fixedSize()
                Spacer()
                Button {
                    Task { await model.run() }
                } label: {
                    HStack(spacing: 6) {
                        if model.isRunning { ProgressView().controlSize(.small).tint(.white) } else { Image(systemName: "play.fill") }
                        Text("Ausführen")
                    }
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 9)
                    .background(Theme.teal, in: Capsule())
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(model.isRunning)
                .help("Programm ausführen (⌘↩)")
            }

            JavaCodeEditor(text: $model.code, runErrorLine: model.problem?.line, controller: model.editor, minHeight: isWide ? 420 : 300)

            console

            if let ranCode = model.ranCode, model.problem?.kind != .syntax {
                CodeRunPanel(source: ranCode, lines: CodeExplainer.explain(ranCode))
                    .id(ranCode)
            }
        }
    }

    private var console: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Konsole", systemImage: "terminal.fill").font(.caption.weight(.bold)).foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 4) {
                Text("> java \(className)").foregroundStyle(CodeTheme.plain.opacity(0.45))
                if model.ranCode == nil {
                    Text("Drück auf „Ausführen“ – hier erscheint, was dein Programm ausgibt.").foregroundStyle(CodeTheme.plain.opacity(0.4))
                } else if !model.output.isEmpty {
                    Text(model.output.trimmingCharacters(in: .newlines)).foregroundStyle(CodeTheme.plain)
                        .textSelection(.enabled)
                } else if model.problem == nil {
                    Text("(keine Ausgabe)").foregroundStyle(CodeTheme.plain.opacity(0.4))
                }
                if let problem = model.problem {
                    Text(problem.kind == .stepLimit
                         ? "Dein Programm hört nicht auf – vermutlich eine Endlosschleife."
                         : (problem.line.map { "Zeile \($0): " } ?? "") + problem.message)
                        .foregroundStyle(Color(red: 1, green: 0.55, blue: 0.55))
                }
                ForEach(model.warnings, id: \.self) { warning in
                    Text("Hinweis, Zeile \(warning.line): \(warning.message)").foregroundStyle(.yellow)
                }
            }
            .font(.system(.footnote, design: .monospaced))
            .frame(maxWidth: .infinity, minHeight: 60, alignment: .topLeading)
            .padding(12)
            .background(CodeTheme.background, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .environment(\.colorScheme, .dark)
        }
    }

    private var className: String {
        let code = JavaSource.normalizingTypography(model.code)
        if let match = code.firstMatch(of: /public\s+class\s+(\w+)/) { return String(match.1) }
        if let match = code.firstMatch(of: /class\s+(\w+)/) { return String(match.1) }
        return "Programm"
    }

    private var sidebar: some View {
        let progress = store.questProgress
        let blueprints = progress.blueprints
        let locked = progress.book.quests.filter { $0.blueprint != nil }.count - blueprints.count
        return VStack(alignment: .leading, spacing: 14) {
            SectionTitle(title: "Baupläne", subtitle: "Tippe zum Einfügen an der Cursorstelle", systemImage: "scroll.fill")
            if blueprints.isEmpty {
                Text("Noch keine Baupläne. Löse Quests mit 3 Sternen – sauberer Code schaltet sie frei.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            ForEach(blueprints, id: \.quest.id) { entry in
                BlueprintRow(blueprint: entry.blueprint) { model.editor.insert(entry.blueprint.code) }
            }
            if locked > 0 {
                Label("\(locked) weitere Baupläne warten in den Quests", systemImage: "lock.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Divider()
            VStack(alignment: .leading, spacing: 6) {
                Label("So funktioniert die Werkstatt", systemImage: "info.circle").font(.subheadline.weight(.semibold))
                Text("Deine Programme laufen in einem geschützten Übungs-Interpreter auf diesem Gerät – ohne Internet, ohne Risiko. Er versteht Klassen, Vererbung, Interfaces, Exceptions, Listen und Maps.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct BlueprintRow: View {
    let blueprint: QuestBlueprint
    let onInsert: () -> Void
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "scroll.fill").foregroundStyle(Theme.teal)
                VStack(alignment: .leading, spacing: 1) {
                    Text(blueprint.title).font(.subheadline.weight(.semibold))
                    Text(blueprint.text).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button { withAnimation(.smooth) { isExpanded.toggle() } } label: {
                    Image(systemName: isExpanded ? "eye.slash" : "eye")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .accessibilityLabel(Text(isExpanded ? "Code ausblenden" : "Code zeigen"))
                Button(action: onInsert) {
                    Image(systemName: "plus.circle.fill").font(.title3)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Theme.teal)
                .accessibilityLabel(Text("\(blueprint.title) einfügen"))
            }
            if isExpanded {
                CodeBlockView(code: blueprint.code, caption: blueprint.title)
            }
        }
        .padding(12)
        .background(Theme.teal.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
