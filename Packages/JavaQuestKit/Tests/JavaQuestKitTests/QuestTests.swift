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
}
