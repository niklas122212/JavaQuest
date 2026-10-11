import Foundation
import Testing
@testable import JavaQuestKit

@Suite("Code-Quests")
struct QuestTests {
    let book: QuestBook
    let course: Course

    init() throws {
        book = try QuestBook.loadBundled()
        course = try CourseLoader.loadBundled()
    }

    func quest(_ id: String) throws -> CodeQuest { try #require(book.quest(id: id)) }

    @Test("Quests sind vollständig und folgen dem Kurs")
    func bookIsConsistent() {
        #expect(book.quests.count >= 16)
        #expect(Set(book.quests.map(\.id)).count == book.quests.count, "IDs doppelt")
        #expect(book.quests.allSatisfy { $0.id.hasPrefix("quest-") }, "IDs beginnen mit quest- (so erkennen alle Plattformen sie)")
        let lessons = course.allLessons.map(\.id)
        let topics = Set(course.topics.map(\.id))
        let chapters = Set(book.chapters.map(\.id))
        var lastLesson = 0
        for quest in book.quests {
            let index = lessons.firstIndex(of: quest.lessonId)
            #expect(index != nil, "\(quest.id): Lektion \(quest.lessonId)")
            #expect(topics.contains(quest.topicId), "\(quest.id): Thema \(quest.topicId)")
            #expect(chapters.contains(quest.chapterId), "\(quest.id): Kapitel \(quest.chapterId)")
            #expect(!quest.visibleTests.isEmpty, "\(quest.id): mindestens ein Beispiel-Test")
            #expect((1...5).contains(quest.difficulty))
            // Die Geschichte folgt dem Kurs: keine Quest verlangt etwas aus einer späteren Lektion als die vorige.
            if let index {
                #expect(index >= lastLesson, "\(quest.id) kommt vor einer früheren Lektion")
                lastLesson = index
            }
        }
        for chapter in book.chapters {
            #expect(!book.quests(in: chapter).isEmpty, "Kapitel \(chapter.id) ist leer")
        }
    }

    @Test("Jede Musterlösung besteht alle Tests mit 3 Sternen")
    func solutionsEarnThreeStars() {
        for quest in book.quests {
            let result = QuestRunner.run(quest.solution, quest: quest)
            let failures = result.tests.filter { !$0.passed }.map { "\($0.test.name): \($0.message ?? "")" }
            #expect(result.solved, "\(quest.id): \(result.compileProblem?.description ?? "") \(failures) \(result.missingRequirements)")
            #expect(result.stars == 3, "\(quest.id): \(result.naming.map(\.message)) \(result.indentation.map(\.message))")
            #expect(result.mentor.kind == .success, "\(quest.id)")
        }
    }

    @Test("Der Startcode übersetzt, löst die Quest aber nicht")
    func starterCodeCompilesButFails() {
        for quest in book.quests {
            #expect(JavaRunner.check(quest.starterCode) == nil, "\(quest.id): \(JavaRunner.check(quest.starterCode)?.description ?? "")")
            let result = QuestRunner.run(quest.starterCode, quest: quest)
            #expect(!result.solved, "\(quest.id)")
            #expect(result.compileProblem == nil, "\(quest.id)")
        }
    }

    @Test("Die Tür aus dem Beispiel: unlock(int key)")
    func unlockQuest() throws {
        let tuer = try quest("quest-tuer")
        // Nur „> 100“ geprüft – der versteckte Test mit 110 fällt durch und der Mentor sagt, warum.
        let halb = """
        public class Tuer {
            public static boolean unlock(int key) {
                return key > 100;
            }
        }
        """
        let result = QuestRunner.run(halb, quest: tuer)
        #expect(!result.solved)
        #expect(result.passedCount == 3)
        #expect(result.mentor.kind == .wrongValue)
        #expect(result.mentor.text.contains("110"))
        let failed = try #require(result.tests.first { !$0.passed })
        #expect(failed.actual == "true")
        #expect(failed.message?.contains("Erwartet: false") == true)

        // Als JUnit-Zeile im Auftrag
        #expect(tuer.visibleTests.first?.assertion == "assertEquals(true, Tuer.unlock(105));")
    }

    @Test("Mentor: fehlendes Semikolon, falsche Klasse, Endlosschleife, kein return")
    func mentorExplainsMistakes() throws {
        let tuer = try quest("quest-tuer")
        let semikolon = QuestRunner.run("public class Tuer {\n    public static boolean unlock(int key) {\n        return key > 100\n    }\n}", quest: tuer)
        #expect(semikolon.compileProblem != nil)
        #expect(semikolon.mentor.kind == .compile)
        #expect(semikolon.mentor.text.contains("Semikolon"))
        #expect(semikolon.mentor.line == 3)

        // Fehlt die Methode, zeigt der Mentor den Aufruf des Tests – ohne Zeilennummer aus dem Testcode.
        let ohneMethode = QuestRunner.run(tuer.starterCode, quest: tuer)
        #expect(ohneMethode.mentor.kind == .missingMember)
        #expect(ohneMethode.mentor.text.contains("Tuer.unlock(105)"))
        #expect(ohneMethode.mentor.line == nil)
        #expect(ohneMethode.tests.allSatisfy { $0.line == nil })
        let golemStart = QuestRunner.run(try quest("quest-golem").starterCode, quest: try quest("quest-golem"))
        #expect(golemStart.mentor.kind == .missingMember)

        let klasse = QuestRunner.run("public class tuer {\n    public static boolean unlock(int key) {\n        return true;\n    }\n}", quest: tuer)
        #expect(klasse.mentor.kind == .missingClass)
        #expect(klasse.mentor.text.contains("Groß- und Kleinschreibung"))

        let treppe = try quest("quest-wendeltreppe")
        let endlos = """
        public class Treppe {
            static int stufen(int stockwerke) {
                int summe = 0;
                int i = 1;
                while (i <= stockwerke) {
                    summe = summe + i;
                }
                return summe;
            }
        }
        """
        let endlosResult = QuestRunner.run(endlos, quest: treppe)
        #expect(endlosResult.mentor.kind == .endless)
        #expect(!endlosResult.solved)

        let golem = try quest("quest-golem")
        let ohneReturn = """
        public class Golem {
            private String name;
            private int energie = 100;

            public Golem(String name) {
                this.name = name;
            }

            public String getName() {
                return name;
            }

            public void getEnergie() {
            }

            public void arbeiten() {
                energie = energie - 30;
            }
        }
        """
        let leer = QuestRunner.run(ohneReturn, quest: golem)
        #expect(!leer.solved)
        #expect(leer.tests.first?.message?.contains("Fehlt ein return?") == true)
    }

    @Test("Exceptions: geworfen, falsch geworfen und vergessen")
    func exceptionTests() throws {
        let kammer = try quest("quest-schatzkammer")
        let ohnePruefung = kammer.solution.replacingOccurrences(of: "menge < 1 || ", with: "")
        let result = QuestRunner.run(ohnePruefung, quest: kammer)
        #expect(!result.solved)
        let negativ = try #require(result.tests.first { $0.test.name.contains("Negatives") })
        #expect(!negativ.passed)
        #expect(negativ.message?.contains("ohne Fehler") == true)

        let falsch = kammer.solution.replacingOccurrences(of: "IllegalArgumentException", with: "IllegalStateException")
        let falschResult = QuestRunner.run(falsch, quest: kammer)
        #expect(falschResult.tests.contains { $0.message?.contains("IllegalStateException") == true })
    }

    @Test("Pflicht-Bausteine: hart codierte Ergebnisse zählen nicht")
    func requirementsAreChecked() throws {
        let rune = try quest("quest-rechenrune")
        let geschummelt = """
        public class Rune {
            public static void main(String[] args) {
                System.out.println("Runencode: 100");
            }
        }
        """
        let result = QuestRunner.run(geschummelt, quest: rune)
        #expect(result.tests.allSatisfy { $0.passed })
        #expect(!result.solved)
        #expect(result.mentor.kind == .requirement)
    }

    @Test("Sauberer Code bringt Sterne: Namen und Einrückung")
    func qualityStars() throws {
        let tuer = try quest("quest-tuer")
        let schlechteNamen = """
        public class Tuer {
            public static boolean Unlock_Door(int Key) {
                return Key > 100 && Key % 7 == 0;
            }
        }
        """
        // Die Methode muss unlock heißen – der Test findet Unlock_Door nicht.
        #expect(!QuestRunner.run(schlechteNamen, quest: tuer).solved)

        let parameter = """
        public class Tuer {
            public static boolean unlock(int Key) {
                int Rest = Key % 7;
                return Key > 100 && Rest == 0;
            }
        }
        """
        let result = QuestRunner.run(parameter, quest: tuer)
        #expect(result.solved)
        #expect(result.stars == 2)
        #expect(result.naming.contains { $0.message.contains("key statt Key") })
        #expect(result.naming.contains { $0.message.contains("rest statt Rest") })
        #expect(result.mentor.kind == .quality)

        let schief = """
        public class Tuer {
        public static boolean unlock(int key) {
              return key > 100 && key % 7 == 0;
          }
        }
        """
        let schiefResult = QuestRunner.run(schief, quest: tuer)
        #expect(schiefResult.solved)
        #expect(schiefResult.stars == 2)
        #expect(schiefResult.indentation.map(\.line) == [2, 3, 4])
    }

    @Test("Einrückung: switch, Fortsetzungszeilen und Tabs sind erlaubt")
    func indentationRules() {
        let ok = """
        public class A {
            static String f(int x) {
                switch (x) {
                    case 1:
                        return "eins";
                    default:
                        return "viel";
                }
            }

            static int g(int a,
                         int b) {
            \treturn a
                    + b;
            }
        }
        """
        #expect(CodeQuality.indentation(ok).isEmpty, "\(CodeQuality.indentation(ok).map(\.message))")
        #expect(CodeQuality.indentation("public class A {\n    void f( {\n}").isEmpty, "Bei Syntaxfehlern kein Urteil")
    }

    @Test("Namen: Vorschläge folgen den Java-Konventionen")
    func namingSuggestions() {
        #expect(CodeQuality.suggestedVariable("Max_Wert") == "maxWert")
        #expect(CodeQuality.suggestedType("mein_held") == "MeinHeld")
        #expect(CodeQuality.suggestedConstant("maxEnergie") == "MAX_ENERGIE")
        let code = """
        public class Spiel {
            static final int maxLeben = 3;
            static final int max_punkte = 10;

            public static void main(String[] args) {
                for (int I = 0; I < 2; I++) {
                    System.out.println(I);
                }
            }
        }

        class held {
        }
        """
        let messages = CodeQuality.naming(code).map(\.message)
        #expect(!messages.contains { $0.contains("maxLeben") }, "static final in camelCase ist erlaubt")
        #expect(messages.contains { $0.contains("MAX_PUNKTE statt max_punkte") })
        #expect(messages.contains { $0.contains("i statt I") })
        #expect(messages.contains { $0.contains("Held statt held") })
    }

    @Test("Tests sehen Objekte, Ausgaben und Fehler")
    func testRunner() {
        let code = """
        public class Golem {
            private int energie = 100;

            public void arbeiten() {
                System.out.println("Bumm");
                energie -= 30;
            }

            public int getEnergie() {
                return energie;
            }
        }
        """
        let outcome = JavaRunner.test(code, setup: "Golem g = new Golem();\ng.arbeiten();", expression: "g.getEnergie()")
        #expect(outcome.value == .integer(70))
        #expect(outcome.typeName == "int")
        #expect(outcome.output == "Bumm\n")

        let syntax = JavaRunner.test("public class A {\n    int x = ;\n}", expression: "1")
        #expect(syntax.problem?.kind == .syntax)
        #expect(syntax.problem?.line == 2)

        let thrown = JavaRunner.test("public class A {\n    static int f() {\n        throw new IllegalStateException(\"kaputt\");\n    }\n}", expression: "A.f()")
        #expect(thrown.problem?.exceptionClass == "IllegalStateException")
        #expect(thrown.problem?.line == 3)
    }

    // MARK: Fortschritt, Inventar, Baupläne, Werkstatt

    @Test("Quests öffnen sich der Reihe nach und erst ab ihrer Lektion")
    func unlockOrder() throws {
        let allLessons = Set(course.allLessons.map(\.id))
        let fresh = QuestProgress(book: book, course: course, stars: [:], unlockedLessonIds: ["l01-hello"])
        #expect(fresh.state(of: book.quests[0]) == .open)
        #expect(fresh.state(of: book.quests[1]) == .locked("Erst „\(book.quests[0].title)“ lösen"))
        #expect(fresh.nextQuest?.id == book.quests[0].id)
        #expect(!fresh.isWorkshopUnlocked)

        let afterFirst = QuestProgress(book: book, course: course, stars: [book.quests[0].id: 2], unlockedLessonIds: ["l01-hello"])
        guard case .locked(let reason) = afterFirst.state(of: book.quests[1]) else {
            Issue.record("Quest 2 braucht Lektion 2")
            return
        }
        #expect(reason.hasPrefix("Ab Lektion 2"))
        #expect(afterFirst.inventory.map(\.item) == [book.quests[0].reward.item])
        // Bauplan nur mit 3 Sternen
        #expect(afterFirst.blueprints.isEmpty)

        let chapterOne = book.quests(in: book.chapters[0])
        let stars = Dictionary(uniqueKeysWithValues: chapterOne.map { ($0.id, 3) })
        let workshop = QuestProgress(book: book, course: course, stars: stars.merging(["a01-erste-schritte": 3]) { a, _ in a }, unlockedLessonIds: allLessons)
        #expect(workshop.isWorkshopUnlocked)
        #expect(workshop.blueprints.count == chapterOne.count)
        #expect(workshop.solvedCount == chapterOne.count, "Arena-Missionen zählen nicht als Quest")
        #expect(workshop.nextQuest?.id == book.quests[chapterOne.count].id)
        #expect(workshop.solvedCount(in: book.chapters[0]) == chapterOne.count)
    }

    @Test("Quest-Sterne bringen XP und eigene Abzeichen, Arena-Abzeichen bleiben Arena")
    func questGamification() throws {
        #expect(Achievement.questCount == book.quests.count, "Ziel des Abzeichens an das Questbuch anpassen")
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        let records = book.quests.prefix(5).map {
            ActivityRecord(taskId: $0.id, topicId: $0.topicId, context: .mission, difficulty: $0.difficulty,
                           credit: ActivityRecord.credit(forStars: 3), solved: true, tries: 1, date: date)
        }
        let catalog = try ArenaCatalog.loadBundled()
        let facts = LearnerFacts(course: course, catalog: catalog, attempts: Array(records), lessonResults: [:], longestStreak: 0)
        let unlocked = Achievement.unlocked(facts)
        #expect(unlocked.contains("first-quest"))
        #expect(unlocked.contains("clean-code"))
        #expect(!unlocked.contains("javahall"))
        #expect(!unlocked.contains("first-mission"), "Quests sind keine Arena-Missionen")
        #expect(facts.questStars.count == 5)
        #expect(facts.arenaStars.isEmpty)
        #expect(facts.experience == 5 * 3 * Experience.pointsPerMissionStar)
    }

    // MARK: Editor

    func type(_ input: String, into text: String, at cursor: Int) -> (String, Int)? {
        guard let edit = CodeEditing.edit(for: input, in: text, selection: NSRange(location: cursor, length: 0)) else { return nil }
        let result = (text as NSString).replacingCharacters(in: edit.range, with: edit.replacement)
        return (result, edit.cursor)
    }

    @Test("Editor: Enter rückt ein und schließt Blöcke")
    func editorNewline() throws {
        // Nach { eine Ebene tiefer – und die fehlende } kommt dazu.
        let open = "public class A {"
        let (text, cursor) = try #require(type("\n", into: open, at: open.utf16.count))
        #expect(text == "public class A {\n    \n}")
        #expect(cursor == open.utf16.count + 5)

        // Fehlt eine }, schließt der Editor den neuen Block auf seiner Ebene.
        let nested = "class A {\n    void f() {\n}"
        let (text2, _) = try #require(type("\n", into: nested, at: "class A {\n    void f() {".utf16.count))
        #expect(text2 == "class A {\n    void f() {\n        \n    }\n}")
        // Sind alle Klammern zu, kommt keine weitere dazu.
        let balanced = "class A {\n    void f() {\n    }\n}"
        let (text5, _) = try #require(type("\n", into: balanced, at: "class A {\n    void f() {".utf16.count))
        #expect(text5 == "class A {\n    void f() {\n        \n    }\n}")

        // {|} wird aufgeklappt.
        let braces = "if (x) {}"
        let (text3, cursor3) = try #require(type("\n", into: braces, at: 8))
        #expect(text3 == "if (x) {\n    \n}")
        #expect(cursor3 == 13)

        // Sonst wie die Zeile davor
        let plain = "    int x = 1;"
        let (text4, _) = try #require(type("\n", into: plain, at: plain.utf16.count))
        #expect(text4 == "    int x = 1;\n    ")
    }

    @Test("Editor: } springt zurück, Tab sind vier Leerzeichen, Klammern paarweise")
    func editorBracesAndTab() throws {
        let code = "class A {\n    void f() {\n        int x = 1;\n        "
        let (text, _) = try #require(type("}", into: code, at: code.utf16.count))
        #expect(text.hasSuffix("int x = 1;\n    }"))

        let (tab, tabCursor) = try #require(type("\t", into: "ab", at: 2))
        #expect(tab == "ab  " && tabCursor == 4)

        let (paren, parenCursor) = try #require(type("(", into: "f", at: 1))
        #expect(paren == "f()" && parenCursor == 2)
        // Über die schließende Klammer hinweg
        let (over, overCursor) = try #require(type(")", into: "f()", at: 2))
        #expect(over == "f()" && overCursor == 3)
        // In einem Wort kein Paar
        #expect(type("(", into: "fx", at: 1) == nil)

        let (quote, quoteCursor) = try #require(type("\"", into: "s = ;", at: 4))
        #expect(quote == "s = \"\";" && quoteCursor == 5)
        let (closeQuote, closeCursor) = try #require(type("\"", into: "s = \"ab\";", at: 7))
        #expect(closeQuote == "s = \"ab\";" && closeCursor == 8)
        // In einem String keine Klammerpaare
        #expect(type("(", into: "s = \" \";", at: 6) == nil)
        // Kommentare und Strings zählen bei der Klammersuche nicht
        let tricky = "class A {\n    String s = \"{\";\n    "
        let (trickyText, _) = try #require(type("}", into: tricky, at: tricky.utf16.count))
        #expect(trickyText.hasSuffix("\n}"))
    }

    @Test("Editor: Baupläne rücken auf die Ebene der Cursorzeile ein")
    func editorInsertion() {
        let code = "class A {\n    "
        let edit = CodeEditing.insertion("int x = 1;\nint y = 2;", in: code, selection: NSRange(location: code.utf16.count, length: 0))
        #expect(edit.replacement == "int x = 1;\n    int y = 2;")
        let afterCode = "    f();"
        let edit2 = CodeEditing.insertion("a();\nb();", in: afterCode, selection: NSRange(location: afterCode.utf16.count, length: 0))
        #expect(edit2.replacement == "\n    a();\n    b();")
        let single = CodeEditing.insertion(";", in: "x", selection: NSRange(location: 1, length: 0))
        #expect(single.replacement == ";" && single.cursor == 2)
    }

    @Test("Editor: Eine schon gesetzte } wird übersprungen statt verdoppelt")
    func editorSkipsExistingBrace() throws {
        // Nach Enter steht die } schon da – tippt man sie trotzdem, springt der Cursor dahinter.
        let code = "if (x) {\n    return x;\n    \n}"
        let cursor = "if (x) {\n    return x;\n    ".utf16.count
        let (text, after) = try #require(type("}", into: code, at: cursor))
        #expect(text == "if (x) {\n    return x;\n}")
        #expect(after == text.utf16.count)
        // Fehlt sie wirklich, wird sie geschrieben.
        let open = "if (x) {\n    return x;\n    "
        let (text2, _) = try #require(type("}", into: open, at: open.utf16.count))
        #expect(text2 == "if (x) {\n    return x;\n}")
        // Direkt davor: einfach hinüber.
        let inline = "f() {\n    }"
        let (text3, after3) = try #require(type("}", into: inline, at: "f() {\n    ".utf16.count))
        #expect(text3 == inline && after3 == inline.utf16.count)
    }
}
