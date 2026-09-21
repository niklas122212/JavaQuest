import SwiftUI
import JavaQuestKit

/// Zeichnet ein UML-Klassendiagramm: Kästen mit Namen, Attributen und Methoden,
/// dazu die Linien zwischen ihnen (Dreiecksspitze, Raute, gestrichelt).
/// Die Anordnung kommt aus `UMLLayout` – auf allen Plattformen dieselbe.
struct UMLDiagramView: View {
    let diagram: UMLDiagram

    private var layout: UMLLayout.Result { UMLLayout.compute(diagram) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ScrollView(.horizontal, showsIndicators: true) {
                ZStack(alignment: .topLeading) {
                    RelationLayer(diagram: diagram, layout: layout)
                    ForEach(layout.boxes, id: \.box.name) { placed in
                        UMLBoxView(box: placed.box)
                            .frame(width: placed.width, height: placed.height)
                            .offset(x: placed.x, y: placed.y)
                    }
                }
                .frame(width: max(layout.width, 1), height: max(layout.height, 1))
                .padding(.vertical, 8)
                .padding(.horizontal, 2)
            }

            if !diagram.relations.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("LINIEN IM DIAGRAMM")
                        .font(.caption.weight(.heavy)).tracking(1.1)
                        .foregroundStyle(.secondary)
                    ForEach(diagram.relations) { relation in
                        RelationLegendRow(relation: relation)
                    }
                }
            }
        }
        .padding(14)
        .background(Theme.fieldBackground, in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
    }
}

/// Ein einzelner Klassenkasten mit seinen drei Fächern.
private struct UMLBoxView: View {
    let box: UMLDiagram.Box

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 1) {
                if let stereotype = box.kind.stereotype {
                    Text(stereotype)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(Theme.indigo)
                }
                Text(box.name)
                    .font(.system(.subheadline, design: .monospaced).weight(.bold))
                    .italic(box.kind == .abstractType)
            }
            .frame(maxWidth: .infinity)
            .frame(height: UMLLayout.headerHeight)
            .background(Theme.indigo.opacity(0.12))

            Divider()
            section(box.fields)
            Divider()
            section(box.methods)
        }
        .background(Theme.cardBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Theme.indigo.opacity(0.45), lineWidth: 1.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    @ViewBuilder
    private func section(_ members: [UMLDiagram.Member]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if members.isEmpty {
                Text(" ")
                    .font(.system(.caption, design: .monospaced))
                    .frame(height: UMLLayout.rowHeight)
            } else {
                ForEach(members) { member in
                    HStack(spacing: 4) {
                        Text(member.visibility.rawValue)
                            .font(.system(.caption, design: .monospaced).weight(.bold))
                            .foregroundStyle(color(for: member.visibility))
                        Text(member.type.map { "\(member.name): \($0)" } ?? member.name)
                            .font(.system(.caption, design: .monospaced))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        Spacer(minLength: 0)
                    }
                    .frame(height: UMLLayout.rowHeight)
                    .accessibilityLabel(Text("\(member.line). \(member.visibility.meaning)"))
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, UMLLayout.sectionPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func color(for visibility: UMLDiagram.Visibility) -> Color {
        switch visibility {
        case .publicAccess: Theme.success
        case .privateAccess: Theme.ember
        case .protectedAccess: Theme.orange
        }
    }
}

/// Die Linien zwischen den Kästen, inklusive Pfeilspitzen, Rauten und Beschriftungen.
private struct RelationLayer: View {
    let diagram: UMLDiagram
    let layout: UMLLayout.Result

    var body: some View {
        Canvas { context, _ in
            for relation in diagram.relations {
                guard let from = layout.placed(named: relation.from),
                      let to = layout.placed(named: relation.to) else { continue }
                draw(relation, from: from, to: to, in: &context)
            }
        }
    }

    private func draw(_ relation: UMLDiagram.Relation, from: UMLLayout.Placed, to: UMLLayout.Placed, in context: inout GraphicsContext) {
        // Von der Oberkante des Kindes zur Unterkante des Ziels – oder seitlich, wenn sie nebeneinander liegen.
        let sameRow = abs(from.y - to.y) < 1
        let start = sameRow
            ? CGPoint(x: from.x + from.width, y: from.y + from.height / 2)
            : CGPoint(x: from.centerX, y: from.y)
        let end = sameRow
            ? CGPoint(x: to.x, y: to.y + to.height / 2)
            : CGPoint(x: to.centerX, y: to.bottom)

        var path = Path()
        path.move(to: start)
        if sameRow {
            path.addLine(to: end)
        } else {
            let midY = (start.y + end.y) / 2
            path.addLine(to: CGPoint(x: start.x, y: midY))
            path.addLine(to: CGPoint(x: end.x, y: midY))
            path.addLine(to: end)
        }

        let style = StrokeStyle(lineWidth: 1.8, dash: relation.kind.isDashed ? [6, 4] : [])
        context.stroke(path, with: .color(Theme.umlLine), style: style)

        let direction = sameRow ? CGPoint(x: 1, y: 0) : CGPoint(x: 0, y: -1)
        switch relation.kind {
        case .extendsRelation, .implementsRelation:
            drawTriangle(at: end, direction: direction, in: &context)
        case .aggregation, .composition:
            // Die Raute steht am Ganzen – also am Ziel der Linie.
            drawDiamond(at: end, direction: direction, filled: relation.kind == .composition, in: &context)
        case .association, .dependency:
            drawArrow(at: end, direction: direction, in: &context)
        }

        if let text = [relation.label, relation.multiplicity].compactMap({ $0 }).first {
            let midPoint = CGPoint(x: (start.x + end.x) / 2 + 8, y: (start.y + end.y) / 2)
            context.draw(
                Text(text).font(.caption2).foregroundStyle(.secondary),
                at: midPoint,
                anchor: .leading
            )
        }
    }

    private func drawTriangle(at point: CGPoint, direction: CGPoint, in context: inout GraphicsContext) {
        let size: CGFloat = 11
        var path = Path()
        if direction.y != 0 {
            path.move(to: CGPoint(x: point.x, y: point.y))
            path.addLine(to: CGPoint(x: point.x - size * 0.7, y: point.y + size))
            path.addLine(to: CGPoint(x: point.x + size * 0.7, y: point.y + size))
        } else {
            path.move(to: CGPoint(x: point.x, y: point.y))
            path.addLine(to: CGPoint(x: point.x - size, y: point.y - size * 0.7))
            path.addLine(to: CGPoint(x: point.x - size, y: point.y + size * 0.7))
        }
        path.closeSubpath()
        context.fill(path, with: .color(Theme.umlFill))
        context.stroke(path, with: .color(Theme.umlLine), lineWidth: 1.8)
    }

    private func drawDiamond(at point: CGPoint, direction: CGPoint, filled: Bool, in context: inout GraphicsContext) {
        let length: CGFloat = 16
        let width: CGFloat = 9
        var path = Path()
        if direction.y != 0 {
            path.move(to: point)
            path.addLine(to: CGPoint(x: point.x - width / 2, y: point.y + length / 2))
            path.addLine(to: CGPoint(x: point.x, y: point.y + length))
            path.addLine(to: CGPoint(x: point.x + width / 2, y: point.y + length / 2))
        } else {
            path.move(to: point)
            path.addLine(to: CGPoint(x: point.x - length / 2, y: point.y - width / 2))
            path.addLine(to: CGPoint(x: point.x - length, y: point.y))
            path.addLine(to: CGPoint(x: point.x - length / 2, y: point.y + width / 2))
        }
        path.closeSubpath()
        context.fill(path, with: .color(filled ? Theme.umlLine : Theme.umlFill))
        context.stroke(path, with: .color(Theme.umlLine), lineWidth: 1.8)
    }

    private func drawArrow(at point: CGPoint, direction: CGPoint, in context: inout GraphicsContext) {
        let size: CGFloat = 9
        var path = Path()
        if direction.y != 0 {
            path.move(to: CGPoint(x: point.x - size * 0.6, y: point.y + size))
            path.addLine(to: point)
            path.addLine(to: CGPoint(x: point.x + size * 0.6, y: point.y + size))
        } else {
            path.move(to: CGPoint(x: point.x - size, y: point.y - size * 0.6))
            path.addLine(to: point)
            path.addLine(to: CGPoint(x: point.x - size, y: point.y + size * 0.6))
        }
        context.stroke(path, with: .color(Theme.umlLine), lineWidth: 1.8)
    }
}

/// Erklärt jede Linie des Diagramms in Alltagssprache – kein Symbol bleibt unerklärt.
private struct RelationLegendRow: View {
    let relation: UMLDiagram.Relation

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            RelationGlyph(kind: relation.kind)
                .frame(width: 34, height: 16)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(relation.from) → \(relation.to): \(relation.kind.title)")
                    .font(.caption.weight(.semibold))
                Text(relation.kind.meaning)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if let multiplicity = relation.multiplicity {
                    Text("Vielfachheit \(multiplicity): \(RelationGlyph.meaning(ofMultiplicity: multiplicity))")
                        .font(.caption)
                        .foregroundStyle(Theme.indigo)
                }
            }
        }
    }
}

/// Kleines Vorschaubild der Linienart für die Legende.
private struct RelationGlyph: View {
    let kind: UMLDiagram.RelationKind

    static func meaning(ofMultiplicity value: String) -> String {
        switch value {
        case "1": "genau eins"
        case "0..1": "keins oder eins"
        case "1..*": "mindestens eins"
        case "*": "beliebig viele"
        default: "so viele wie angegeben"
        }
    }

    var body: some View {
        Canvas { context, size in
            let y = size.height / 2
            var line = Path()
            line.move(to: CGPoint(x: 0, y: y))
            line.addLine(to: CGPoint(x: size.width - 10, y: y))
            context.stroke(
                line,
                with: .color(Theme.umlLine),
                style: StrokeStyle(lineWidth: 1.6, dash: kind.isDashed ? [4, 3] : [])
            )

            var head = Path()
            switch kind {
            case .extendsRelation, .implementsRelation:
                head.move(to: CGPoint(x: size.width, y: y))
                head.addLine(to: CGPoint(x: size.width - 10, y: y - 5))
                head.addLine(to: CGPoint(x: size.width - 10, y: y + 5))
                head.closeSubpath()
                context.fill(head, with: .color(Theme.umlFill))
                context.stroke(head, with: .color(Theme.umlLine), lineWidth: 1.6)
            case .aggregation, .composition:
                head.move(to: CGPoint(x: size.width, y: y))
                head.addLine(to: CGPoint(x: size.width - 6, y: y - 4))
                head.addLine(to: CGPoint(x: size.width - 12, y: y))
                head.addLine(to: CGPoint(x: size.width - 6, y: y + 4))
                head.closeSubpath()
                context.fill(head, with: .color(kind == .composition ? Theme.umlLine : Theme.umlFill))
                context.stroke(head, with: .color(Theme.umlLine), lineWidth: 1.6)
            case .association, .dependency:
                head.move(to: CGPoint(x: size.width - 8, y: y - 4))
                head.addLine(to: CGPoint(x: size.width, y: y))
                head.addLine(to: CGPoint(x: size.width - 8, y: y + 4))
                context.stroke(head, with: .color(Theme.umlLine), lineWidth: 1.6)
            }
        }
    }
}

#if DEBUG
#Preview("UML-Diagramm") {
    UMLDiagramView(diagram: UMLDiagram(
        classes: [
            UMLDiagram.Box(name: "Tier", kind: .abstractType,
                           fields: [.init(visibility: .protectedAccess, name: "name", type: "String")],
                           methods: [.init(visibility: .publicAccess, name: "laut()", type: "String")]),
            UMLDiagram.Box(name: "Hund",
                           methods: [.init(visibility: .publicAccess, name: "laut()", type: "String")]),
        ],
        relations: [.init(from: "Hund", to: "Tier", kind: .extendsRelation)]
    ))
    .padding()
}
#endif
