import SwiftUI
import JavaQuestKit

/// App-Start: Begrüßung → Erfahrungsgrad → (Einstufungstest → Ergebnis).
/// Anfänger springen ohne Test direkt in die erste Theorie-Lektion.
struct OnboardingFlowView: View {
    @Environment(ProgressStore.self) private var store
    @Environment(AppRouter.self) private var router
    @State private var step: Step = .welcome
    @State private var level: ExperienceLevel?
    @State private var placement: PlacementTest?

    enum Step: Hashable {
        case welcome, experience, placementIntro, placement, result
    }

    var body: some View {
        Group {
            if step == .placement, placement != nil {
                // Eigenes Layout mit fixierter Abgabe-Leiste (wie in den Lektionen).
                PlacementTestView(test: Binding(get: { placement! }, set: { placement = $0 }),
                                  course: store.course) { go(.result) }
                    .transition(.opacity)
            } else {
                ScrollView {
                    stepView
                        .id(step)
                        .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                                removal: .move(edge: .leading).combined(with: .opacity)))
                        .padding(24)
                        .frame(maxWidth: 600)
                        .frame(maxWidth: .infinity)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
        }
        .background { OnboardingBackground() }
    }

    @ViewBuilder private var stepView: some View {
        switch step {
        case .welcome:
            WelcomeStep { go(.experience) }
        case .experience:
            ExperienceStep(selection: $level) { continueFromExperience() }
        case .placementIntro:
            if let level {
                PlacementIntroStep(level: level, config: store.course.placement,
                                   onStart: startPlacement, onBack: { go(.experience) })
            }
        case .placement:
            EmptyView()
        case .result:
            if let placement {
                PlacementResultView(test: placement, course: store.course,
                                    onStart: { finish(startLesson: true) },
                                    onDashboard: { finish(startLesson: false) })
            }
        }
    }

    private func go(_ next: Step) {
        withAnimation(.smooth(duration: 0.45)) { step = next }
    }

    private func continueFromExperience() {
        guard let level else { return }
        if level.requiresPlacement {
            go(.placementIntro)
        } else {
            finish(startLesson: true)
        }
    }

    private func startPlacement() {
        guard let level else { return }
        placement = PlacementTest(course: store.course, level: level)
        go(placement == nil ? .experience : .placement)
    }

    private func finish(startLesson: Bool) {
        let chosen = level ?? .beginner
        store.completeOnboarding(level: chosen, placement: chosen.requiresPlacement ? placement : nil)
        router.selection = .dashboard
        if startLesson, let lesson = store.nextLesson {
            router.startLesson(lesson.id)
        }
    }
}

/// Weicher, dezenter Verlauf hinter dem Onboarding. Die Farbflächen liegen als
/// Overlay, damit sie die Layoutbreite nicht vergrößern (wichtig auf dem iPhone).
struct OnboardingBackground: View {
    var body: some View {
        Theme.screenBackground
            .overlay(alignment: .topLeading) {
                Circle()
                    .fill(Theme.violet.opacity(0.2))
                    .frame(width: 420, height: 420)
                    .blur(radius: 90)
                    .offset(x: -160, y: -140)
            }
            .overlay(alignment: .bottomTrailing) {
                Circle()
                    .fill(Theme.orange.opacity(0.18))
                    .frame(width: 400, height: 400)
                    .blur(radius: 90)
                    .offset(x: 150, y: 150)
            }
            .clipped()
            .ignoresSafeArea()
    }
}

struct WelcomeStep: View {
    let onContinue: () -> Void

    var body: some View {
        // Kompakt genug, dass „Los geht’s“ auf aktuellen iPhones ohne Scrollen sichtbar ist.
        VStack(spacing: 22) {
            ZStack {
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(Theme.heroGradient)
                    .frame(width: 104, height: 104)
                    .shadow(color: Theme.violet.opacity(0.4), radius: 20, y: 10)
                Image(systemName: "cup.and.saucer.fill")
                    .font(.system(size: 48, weight: .semibold))
                    .foregroundStyle(.white)
            }
            VStack(spacing: 10) {
                Text("Lerne Java.\nLevel für Level.")
                    .font(.system(.largeTitle, design: .rounded).weight(.heavy))
                    .multilineTextAlignment(.center)
                Text("Kurze Theorie-Happen, Aufgaben mit steigendem Niveau und eine Auswertung, die deine Wissenslücken findet – komplett offline.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            VStack(alignment: .leading, spacing: 14) {
                FeatureRow(symbol: "text.magnifyingglass", tint: Theme.indigo, title: "Jede Codezeile erklärt", text: "Tippe eine Zeile an – sie wird in Alltagssprache erklärt.")
                FeatureRow(symbol: "chart.line.uptrend.xyaxis", tint: Theme.orange, title: "Niveau 1 bis 5", text: "Aufgaben werden Schritt für Schritt anspruchsvoller.")
                FeatureRow(symbol: "brain.head.profile", tint: Theme.success, title: "Automatische Analyse", text: "Stärken, Lücken und neue Themen auf einen Blick.")
                FeatureRow(symbol: "lock.shield.fill", tint: Theme.violet, title: "Privat & lokal", text: "Kein Konto, keine Cloud, kein API-Key.")
            }
            .card()
            Button(action: onContinue) {
                Label("Los geht’s", systemImage: "arrow.right")
            }
            .buttonStyle(.primary)
            .keyboardShortcut(.defaultAction)
        }
    }
}

private struct FeatureRow: View {
    let symbol: String
    let tint: Color
    let title: String
    let text: String

    var body: some View {
        HStack(spacing: 14) {
            IconTile(systemImage: symbol, tint: tint, size: 38)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(text).font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }
}

struct ExperienceStep: View {
    @Binding var selection: ExperienceLevel?
    let onContinue: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 8) {
                Text("SCHRITT 1 VON 2").font(.caption.weight(.heavy)).tracking(1.2).foregroundStyle(Theme.orange)
                Text("Wie viel Java kannst du schon?")
                    .font(.largeTitle.weight(.bold))
                Text("Wähle, was auf dich zutrifft. Mit Vorkenntnissen zeigt eine einzige Frage, wo du einsteigst.")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            VStack(spacing: 12) {
                ForEach(ExperienceLevel.onboardingChoices) { level in
                    ExperienceOption(level: level, isSelected: selection == level) {
                        withAnimation(.spring(duration: 0.3)) { selection = level }
                    }
                }
            }
            Button(action: onContinue) {
                Label(selection?.requiresPlacement == true ? "Weiter zur Einstufungsfrage" : "Mit dem Grundkurs starten",
                      systemImage: "arrow.right")
            }
            .buttonStyle(.primary)
            .disabled(selection == nil)
            .keyboardShortcut(.defaultAction)
        }
    }
}

private struct ExperienceOption: View {
    let level: ExperienceLevel
    let isSelected: Bool
    let action: () -> Void

    private var tint: Color { Theme.color(for: level) }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                IconTile(systemImage: level.symbolName, tint: tint, size: 50)
                VStack(alignment: .leading, spacing: 4) {
                    Text(level.onboardingTitle)
                        .font(.headline)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(level.onboardingSummary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    if level.requiresPlacement {
                        Label("Mit einer Einstufungsfrage", systemImage: "checklist")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(tint)
                            .padding(.top, 2)
                    }
                }
                Spacer(minLength: 8)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(isSelected ? tint : Color.secondary.opacity(0.4))
            }
            .padding(16)
            .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
                    .strokeBorder(isSelected ? tint : Color.primary.opacity(0.06), lineWidth: isSelected ? 2.5 : 1)
            }
            .shadow(color: isSelected ? tint.opacity(0.25) : .black.opacity(0.04), radius: isSelected ? 16 : 8, y: 5)
            .contentShape(RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

struct PlacementIntroStep: View {
    let level: ExperienceLevel
    let config: PlacementConfig
    let onStart: () -> Void
    let onBack: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 8) {
                Text("SCHRITT 2 VON 2").font(.caption.weight(.heavy)).tracking(1.2).foregroundStyle(Theme.orange)
                Text("Eine Einstufungsfrage").font(.largeTitle.weight(.bold))
                Text(level.onboardingTitle).font(.title3).foregroundStyle(.secondary)
            }
            VStack(alignment: .leading, spacing: 16) {
                InfoLine(symbol: "square.and.pencil", text: config.questionsPerTest == 1
                         ? "Eine Frage: Du ergänzt ein kleines Programm mit mehreren Lücken – etwa 2 Minuten."
                         : "\(config.questionsPerTest) Fragen, etwa 3–5 Minuten.")
                InfoLine(symbol: "percent", text: "Jede richtige Lücke bringt Punkte. Bewertet wird von 0 bis 100 %.")
                InfoLine(symbol: "flag.checkered", text: "Ab \(config.passThreshold) % überspringst du den Grundkurs und startest bei den Objekten. Sonst beginnst du ganz entspannt mit dem Grundkurs.")
                InfoLine(symbol: "text.magnifyingglass", text: "Hilfen gibt es während der Frage nicht – danach siehst du die Lösung Zeile für Zeile erklärt.")
            }
            .card()
            HStack(spacing: 12) {
                Button("Zurück", systemImage: "chevron.left", action: onBack)
                    .buttonStyle(.secondary)
                    .frame(maxWidth: 170)
                Button(action: onStart) {
                    Label(config.questionsPerTest == 1 ? "Frage starten" : "Test starten", systemImage: "play.fill")
                }
                .buttonStyle(.primary)
                .keyboardShortcut(.defaultAction)
            }
        }
    }
}

private struct InfoLine: View {
    let symbol: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.headline)
                .foregroundStyle(Theme.orange)
                .frame(width: 26)
            Text(text).font(.body).fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Previews

#Preview("Onboarding") {
    OnboardingFlowView()
        .environment(PreviewSupport.makeStore(.fresh))
        .environment(AppRouter())
}
