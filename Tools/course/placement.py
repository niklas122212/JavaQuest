"""Fragen für die Einstufung.

Wer angibt, schon Vorkenntnisse zu haben, wird nicht mit einer einzigen Frage einsortiert.
Der Test ist adaptiv: Er startet auf Stufe 3, steigt nach einem Treffer und sinkt nach einem
Fehler. Damit das funktioniert, braucht er auf jeder Stufe mehrere Fragen zur Auswahl –
und zwar aus verschiedenen Themen, damit nicht eine Wissenslücke das ganze Ergebnis kippt.

Die Fragen sind bewusst kurz: Es geht um eine Einschätzung in wenigen Minuten,
nicht um eine Prüfung.
"""
from authoring import any_of, fill, mc, out

# ---------------------------------------------------------------- Stufe 1: Grundlagen
LEVEL_1 = [
    mc("p-1a", "variables", 1, "Welcher Datentyp speichert true oder false?",
       ["boolean", "int", "String", "char"],
       "boolean ist der Typ für Ja-Nein-Werte. Er kennt genau zwei Möglichkeiten: true und false.",
       why=[None,
            "int speichert ganze Zahlen. Anders als in manchen Sprachen gilt in Java keine Zahl als „wahr“.",
            "String ist für Text. „true“ in Anführungszeichen wäre Text, mit dem if nichts anfangen kann.",
            "char speichert genau ein Zeichen, etwa 'A'."]),
    mc("p-1b", "syntax", 1, "Welche Zeile gibt in Java Text auf dem Bildschirm aus?",
       ['System.out.println("Hi");', 'print("Hi");', 'console.log("Hi");', 'echo "Hi";'],
       "System.out.println ist der Weg in Java: System.out ist der Bildschirm, println schreibt "
       "darauf und beendet die Zeile.",
       why=[None,
            "print allein ohne System.out davor kennt Java nicht – so schreibt man es in Python.",
            "console.log gehört zu JavaScript.",
            "echo stammt aus der Kommandozeile und aus PHP."]),
    out("p-1c", "operators", 1, "Was gibt diese Zeile aus?",
        'System.out.println(3 + 4 * 2);',
        "11",
        "Punkt vor Strich gilt auch in Java: Erst 4 * 2 = 8, dann 3 + 8 = 11."),
]

# ---------------------------------------------------------------- Stufe 2: Kontrollfluss
LEVEL_2 = [
    out("p-2a", "loops", 2, "Was gibt die Schleife aus?",
        """
        for (int i = 0; i < 3; i++) {
            System.out.print(i);
        }
        System.out.println();
        """,
        "012",
        "i nimmt die Werte 0, 1 und 2 an – bei 3 ist die Bedingung nicht mehr erfüllt. "
        "print bleibt in derselben Zeile, deshalb stehen die Ziffern nebeneinander."),
    mc("p-2b", "strings", 2, 'Was liefert "Java".length()?',
       ["4", "3", "5", "Nichts – String hat keine Methode length()"],
       "length() zählt die Zeichen: J, a, v, a – also 4.",
       why=[None,
            "3 wäre die Zahl der Buchstaben ohne das letzte a. Gezählt wird jedes Zeichen.",
            "5 käme heraus, wenn man die Anführungszeichen mitzählte. Die gehören nicht zum Text.",
            "Die Methode gibt es – bei Arrays heißt es dagegen length ohne Klammern."]),
    out("p-2c", "conditionals", 2, "Was wird ausgegeben?",
        """
        int x = 5;
        if (x > 3) {
            System.out.println("gross");
        } else {
            System.out.println("klein");
        }
        """,
        "gross",
        "5 > 3 ist wahr, also läuft der erste Block. Der else-Zweig wird übersprungen."),
]

# ---------------------------------------------------------------- Stufe 3: Methoden, Arrays, Objekte
LEVEL_3 = [
    out("p-3b", "arrays", 3, "Was gibt das Programm aus?",
        """
        int[] zahlen = {3, 1, 4};
        int summe = 0;
        for (int w : zahlen) {
            summe += w;
        }
        System.out.println(summe);
        """,
        "8",
        "Die for-each-Schleife holt nacheinander jeden Wert: 3 + 1 + 4 = 8."),
    mc("p-3c", "oop", 3, "Was bewirkt new Auto();?",
       ["Es erzeugt ein neues Objekt der Klasse Auto",
        "Es legt die Klasse Auto an",
        "Es löscht ein vorhandenes Auto",
        "Es ruft eine Methode namens Auto auf"],
       "new ruft den Konstruktor auf und legt ein neues Objekt im Speicher an. Die Klasse selbst "
       "steht schon vorher in der Datei – sie ist der Bauplan.",
       why=[None,
            "Die Klasse entsteht beim Schreiben des Quelltexts, nicht zur Laufzeit.",
            "Gelöscht wird in Java nichts von Hand; darum kümmert sich die Speicherbereinigung.",
            "Der Konstruktor heißt zwar wie die Klasse, ist aber keine gewöhnliche Methode – "
            "er läuft nur zusammen mit new."]),
    out("p-3d", "methods", 3, "Was gibt main aus?",
        """
        static int quadrat(int n) {
            return n * n;
        }

        public static void main(String[] args) {
            System.out.println(quadrat(4) + 1);
        }
        """,
        "17",
        "Erst läuft die Methode: quadrat(4) ergibt 16. Danach kommt die 1 dazu – also 17.",
        ctx="members"),
]

# ---------------------------------------------------------------- Stufe 4: Objekte, Sammlungen, Fehler
LEVEL_4 = [
    out("p-4a", "inheritance", 4, "Was gibt das Programm aus?",
        """
        class Tier {
            String laut() {
                return "...";
            }
        }

        class Hund extends Tier {
            @Override
            String laut() {
                return "Wau";
            }
        }

        public class Main {
            public static void main(String[] args) {
                Tier t = new Hund();
                System.out.println(t.laut());
            }
        }
        """,
        "Wau",
        "Links steht Tier, im Speicher liegt aber ein Hund. Beim Aufruf zählt das tatsächliche "
        "Objekt – Java nimmt deshalb dessen Fassung von laut().",
        ctx="file"),
    out("p-4b", "collections", 4, "Was gibt das Programm aus?",
        """
        Map<String, Integer> punkte = new HashMap<>();
        punkte.put("Ada", 3);
        punkte.put("Ada", 5);
        System.out.println(punkte.size());
        System.out.println(punkte.get("Ada"));
        """,
        """
        1
        5
        """,
        "In einer Map ist jeder Schlüssel nur einmal vergeben. Das zweite put legt keinen neuen "
        "Eintrag an, sondern überschreibt den alten Wert."),
    out("p-4c", "exceptions", 4, "In welcher Reihenfolge erscheinen die Zeilen?",
        """
        try {
            System.out.println("A");
            int x = 1 / 0;
            System.out.println("B");
        } catch (ArithmeticException e) {
            System.out.println("C");
        } finally {
            System.out.println("D");
        }
        """,
        """
        A
        C
        D
        """,
        "Nach dem Fehler bei 1 / 0 wird der Rest des try-Blocks übersprungen – „B“ erscheint nie. "
        "Es folgt das catch, und finally läuft in jedem Fall zum Schluss."),
]

# ---------------------------------------------------------------- Stufe 5: Streams und modernes Java
LEVEL_5 = [
    out("p-5a", "lambdas", 5, "Was gibt das Programm aus?",
        """
        List<Integer> zahlen = List.of(1, 2, 3, 4, 5);
        int summe = zahlen.stream()
                          .filter(n -> n % 2 == 0)
                          .mapToInt(n -> n * n)
                          .sum();
        System.out.println(summe);
        """,
        "20",
        "Das Sieb lässt nur 2 und 4 durch, der Umformer macht daraus 4 und 16 – zusammen 20."),
    out("p-5b", "modern", 5, "Was gibt das Programm aus?",
        """
        record Punkt(int x, int y) {}

        public class Main {
            public static void main(String[] args) {
                Punkt p = new Punkt(1, 2);
                String text = switch (p.x()) {
                    case 1 -> "eins";
                    default -> "anders";
                };
                System.out.println(text + " " + p);
            }
        }
        """,
        "eins Punkt[x=1, y=2]",
        "Der Record liefert die Lesemethode x() und eine lesbare toString-Darstellung. Das switch "
        "als Ausdruck gibt einen Wert zurück, der direkt in die Variable wandert.",
        ctx="file"),
]

PLACEMENT_POOL = LEVEL_1 + LEVEL_2 + LEVEL_3 + LEVEL_4 + LEVEL_5
