"""UML-Klassendiagramme: Theorie, Diagramme und Aufgaben – eng mit dem Java-Stoff verzahnt.

Jeder Begriff (Sichtbarkeit, Vererbung, Assoziation, Aggregation, Komposition,
Abhängigkeit, Vielfachheit) wird zuerst erklärt und erst danach abgefragt.
"""
from authoring import any_of, card, code, fill, forbid, lesson, mc, out, req

UML_TOPICS = [
    ("umlbasics", "UML-Klassendiagramme", "square.on.square", "Kästen lesen: Klassen, Attribute, Methoden, Sichtbarkeit"),
    ("umlrelations", "UML-Beziehungen", "arrow.triangle.pull", "Vererbung, Assoziation, Aggregation, Komposition, Vielfachheit"),
]


# ---------------------------------------------------------------- Bausteine für Diagramme
def m(visibility, name, type=None):
    """Ein Feld oder eine Methode im Kasten: m('-', 'name', 'String')."""
    member = {"visibility": visibility, "name": name}
    if type:
        member["type"] = type
    return member


def box(name, fields=(), methods=(), kind="classType"):
    return {"name": name, "kind": kind, "fields": list(fields), "methods": list(methods)}


def rel(frm, to, kind, label=None, mult=None):
    r = {"from": frm, "to": to, "kind": kind}
    if label:
        r["label"] = label
    if mult:
        r["multiplicity"] = mult
    return r


def diagram(classes, relations=()):
    return {"classes": list(classes), "relations": list(relations)}


# ---------------------------------------------------------------- Diagramme des Kurses
PERSON = diagram([
    box("Person",
        fields=[m("-", "name", "String"), m("-", "alter", "int")],
        methods=[m("+", "getName()", "String"), m("+", "hatGeburtstag()")]),
])

TIER_HUND = diagram(
    [
        box("Tier", fields=[m("#", "name", "String")], methods=[m("+", "laut()", "String")]),
        box("Hund", methods=[m("+", "laut()", "String"), m("+", "apportieren()")]),
    ],
    [rel("Hund", "Tier", "extendsRelation")],
)

INTERFACE_DIAGRAM = diagram(
    [
        box("Fahrbar", kind="interfaceType", methods=[m("+", "fahren()")]),
        box("Auto", fields=[m("-", "marke", "String")], methods=[m("+", "fahren()")]),
    ],
    [rel("Auto", "Fahrbar", "implementsRelation")],
)

SCHULE = diagram(
    [
        box("Schulklasse", fields=[m("-", "raum", "String")], methods=[m("+", "anzahl()", "int")]),
        box("Schueler", fields=[m("-", "name", "String")]),
    ],
    [rel("Schulklasse", "Schueler", "aggregation", mult="1..*")],
)

HAUS = diagram(
    [
        box("Haus", fields=[m("-", "adresse", "String")]),
        box("Raum", fields=[m("-", "flaeche", "double")]),
    ],
    [rel("Haus", "Raum", "composition", mult="1..*")],
)

BESTELLUNG = diagram(
    [
        box("Bestellung", fields=[m("-", "nummer", "int")], methods=[m("+", "summe()", "double")]),
        box("Kunde", fields=[m("-", "name", "String")]),
    ],
    [rel("Bestellung", "Kunde", "association", label="gehoert zu", mult="1")],
)

KONTO = diagram([
    box("Konto",
        fields=[m("-", "stand", "double")],
        methods=[m("+", "einzahlen()"), m("+", "getStand()", "double")]),
])

FORM_HIERARCHIE = diagram(
    [
        box("Form", kind="abstractType", methods=[m("+", "flaeche()", "double")]),
        box("Kreis", fields=[m("-", "radius", "double")], methods=[m("+", "flaeche()", "double")]),
        box("Quadrat", fields=[m("-", "seite", "double")], methods=[m("+", "flaeche()", "double")]),
    ],
    [rel("Kreis", "Form", "extendsRelation"), rel("Quadrat", "Form", "extendsRelation")],
)

DRUCKER = diagram(
    [
        box("Rechnung", methods=[m("+", "drucke()")]),
        box("Drucker", methods=[m("+", "ausgeben()")]),
    ],
    [rel("Rechnung", "Drucker", "dependency", label="benutzt")],
)


# ---------------------------------------------------------------- Lektion 1: Kästen lesen
l30 = lesson("l30-uml-basics", "UML lesen: der Klassenkasten",
             "Klassen als Bild: Name, Attribute, Methoden und Sichtbarkeit.",
             ["umlbasics"], 8, [
    card("Ein Kasten pro Klasse",
         "Ein UML-Klassendiagramm zeigt denselben Bauplan wie dein Java-Code, nur als Bild. "
         "Jede Klasse ist ein Kasten mit drei Fächern: oben der Name, in der Mitte die Attribute "
         "(die Felder), unten die Methoden. So sieht man auf einen Blick, was eine Klasse kann – "
         "ohne den Code zu lesen.",
         diagram=PERSON,
         tip="UML heißt „Unified Modeling Language“ – eine einheitliche Sprache, um Software als Bild aufzuzeichnen."),
    card("Die Zeichen + - # : Wer darf ran?",
         "Vor jedem Attribut und jeder Methode steht ein Zeichen für die Sichtbarkeit. "
         "+ heißt öffentlich (public): von überall nutzbar. - heißt privat (private): nur innerhalb "
         "der eigenen Klasse. # heißt geschützt (protected): in der Klasse selbst und in ihren Kind-Klassen. "
         "Hinter dem Doppelpunkt steht der Typ – bei Methoden der Rückgabetyp.",
         diagram=KONTO,
         info="Faustregel wie in Java: Attribute privat (-), Methoden so öffentlich wie nötig (+)."),
    card("Vom Kasten zum Java-Code",
         "Der Kasten links und der Code rechts sagen dasselbe. „- stand: double“ wird zu "
         "„private double stand;“, „+ getStand(): double“ wird zu „public double getStand()“. "
         "Ein leerer Rückgabetyp im Diagramm bedeutet void.",
         code="""
         class Konto {
             private double stand;

             public void einzahlen(double betrag) {
                 stand = stand + betrag;
             }

             public double getStand() {
                 return stand;
             }
         }
         """,
         verify={"context": "file", "main": "Konto k = new Konto(); k.einzahlen(5); System.out.println(k.getStand());",
                 "output": "5.0"}),
], [
    mc("t30-1", "umlbasics", 1, "Was steht im obersten Fach eines UML-Klassenkastens?",
       ["Der Name der Klasse", "Die Attribute", "Die Methoden", "Der Konstruktor"],
       "Der Kasten ist immer gleich aufgebaut: oben der Name, in der Mitte die Attribute, unten die Methoden."),
    mc("t30-2", "umlbasics", 2, "Was bedeutet das Minus vor „- alter: int“?",
       ["privat – nur innerhalb der Klasse nutzbar",
        "öffentlich – von überall nutzbar",
        "geschützt – auch in Kind-Klassen nutzbar",
        "Das Attribut ist gelöscht"],
       "- steht für private: Von außen kommt man nur über Methoden heran. + wäre öffentlich, # geschützt.",
       diagram=PERSON),
    mc("t30-3", "umlbasics", 2, "Welchen Typ liefert die Methode getName() laut Diagramm zurück?",
       ["String", "int", "void – sie liefert nichts", "Person"],
       "Hinter dem Doppelpunkt steht bei einer Methode der Rückgabetyp: „+ getName(): String“ liefert einen Text.",
       diagram=PERSON),
    mc("t30-4", "umlbasics", 3, "Welcher Java-Code passt zu „- stand: double“ im Kasten Konto?",
       ["private double stand;", "public double stand;", "double stand();", "private stand: double;"],
       "Das Minus wird zu private, hinter dem Doppelpunkt steht der Typ – und der steht in Java vor dem Namen.",
       diagram=KONTO),
    code("t30-5", "umlbasics", 3,
         "Setze den Kasten in Java um: Die Klasse Person hat ein privates Feld name (String) und die öffentliche Methode getName(), die name zurückgibt.",
         "class Person {\n    // Feld und Methode hier\n}",
         """
         class Person {
             private String name;

             public String getName() {
                 return name;
             }
         }
         """,
         [req(r"class\s+Person", "Schreibe die Klasse Person."),
          req(r"private\s+String\s+name", "Das Minus im Diagramm bedeutet private."),
          req(r"public\s+String\s+getName\s*\(\s*\)", "getName() ist öffentlich und liefert einen String."),
          any_of([r"return\s+name\b", r"return\s+this\.name\b"], "Gib das Feld name zurück.")],
         "Jede Zeile des Kastens wird zu einer Zeile Java: - name: String → private String name; und + getName(): String → public String getName().",
         ctx="file",
         diagram=PERSON,
         verify={"context": "file", "main": "System.out.println(new Person().getName());", "output": "null"}),
])


# ---------------------------------------------------------------- Lektion 2: Linien zwischen Kästen
l31 = lesson("l31-uml-relations", "UML-Beziehungen zwischen Klassen",
             "Vererbung, Assoziation, Aggregation, Komposition und Vielfachheit.",
             ["umlrelations"], 10, [
    card("Vererbung und Interfaces: die Dreiecksspitze",
         "Ein Pfeil mit leerer Dreiecksspitze zeigt immer zur Eltern-Klasse und bedeutet „ist ein“: "
         "Ein Hund ist ein Tier. In Java steht dort extends. Zeigt derselbe Pfeil gestrichelt auf ein "
         "Interface («interface»), heißt das: Die Klasse unterschreibt diesen Vertrag – in Java implements.",
         diagram=TIER_HUND,
         tip="Merke: Die Spitze zeigt dorthin, wo geerbt wird – also nach oben zur Eltern-Klasse."),
    card("Assoziation: eine Klasse kennt eine andere",
         "Eine einfache Linie heißt Assoziation: Die eine Klasse kennt die andere dauerhaft, meist als Feld. "
         "An der Linie steht oft, wie viele gemeint sind – die Vielfachheit. 1 heißt genau eine, "
         "0..1 heißt keine oder eine, 1..* heißt mindestens eine, * heißt beliebig viele.",
         diagram=BESTELLUNG,
         info="Die Beschriftung an der Linie („gehoert zu“) sagt, wie die Beziehung gemeint ist."),
    card("Aggregation und Komposition: die Raute",
         "Beides heißt „besteht aus“, der Unterschied steckt in der Raute. Die leere Raute (Aggregation) "
         "bedeutet: Die Teile leben ohne das Ganze weiter – löst man die Schulklasse auf, gibt es die Schüler "
         "immer noch. Die gefüllte Raute (Komposition) bedeutet: Ohne das Ganze gibt es die Teile nicht – "
         "reißt man das Haus ab, sind auch die Räume weg. Die Raute steht immer am Ganzen.",
         diagram=HAUS,
         warning="Verwechsle die Raute nicht mit der Dreiecksspitze: Raute = besteht aus, Dreieck = ist ein."),
], [
    mc("t31-1", "umlrelations", 1, "Was bedeutet ein Pfeil mit leerer Dreiecksspitze von Hund zu Tier?",
       ["Hund erbt von Tier – ein Hund ist ein Tier",
        "Tier erbt von Hund",
        "Hund besteht aus Tieren",
        "Hund benutzt Tier kurzzeitig"],
       "Die Dreiecksspitze zeigt zur Eltern-Klasse. In Java: class Hund extends Tier.",
       diagram=TIER_HUND),
    mc("t31-2", "umlrelations", 2, "Welches Java-Schlüsselwort gehört zur gestrichelten Linie mit Dreiecksspitze auf «interface» Fahrbar?",
       ["implements", "extends", "new", "import"],
       "Gestrichelt plus Dreiecksspitze auf ein Interface heißt: Die Klasse unterschreibt den Vertrag – class Auto implements Fahrbar.",
       diagram=INTERFACE_DIAGRAM),
    mc("t31-3", "umlrelations", 3, "Was bedeutet die leere Raute an der Schulklasse?",
       ["Aggregation: Die Schüler gibt es auch ohne die Schulklasse",
        "Komposition: Ohne die Schulklasse gibt es die Schüler nicht",
        "Vererbung: Schueler erbt von Schulklasse",
        "Abhängigkeit: Die Schulklasse benutzt Schüler nur kurz"],
       "Leere Raute = Aggregation: Das Ganze hat Teile, die Teile leben aber weiter. Gefüllt wäre es Komposition.",
       diagram=SCHULE),
    mc("t31-4", "umlrelations", 3, "Was sagt die Vielfachheit 1..* an der Linie zwischen Haus und Raum?",
       ["Ein Haus hat mindestens einen Raum",
        "Ein Haus hat höchstens einen Raum",
        "Ein Haus hat genau einen Raum",
        "Ein Haus hat keine oder einen Raum"],
       "1..* heißt: mindestens eins, nach oben offen. 0..1 wäre keins oder eins, * wäre beliebig viele.",
       diagram=HAUS),
    mc("t31-5", "umlrelations", 4, "Rechnung benutzt Drucker nur innerhalb einer Methode als Parameter. Welche Beziehung ist das?",
       ["Abhängigkeit – gestrichelter Pfeil",
        "Komposition – gefüllte Raute",
        "Vererbung – Dreiecksspitze",
        "Aggregation – leere Raute"],
       "Wird eine Klasse nur kurz benutzt (Parameter, lokale Variable), ist das eine Abhängigkeit: gestrichelter Pfeil, keine Raute.",
       diagram=DRUCKER),
])


# ---------------------------------------------------------------- Lektion 3: UML und Java verbinden
l32 = lesson("l32-uml-java", "UML ↔ Java übersetzen",
             "Aus dem Diagramm Code lesen – und aus Code das Diagramm.",
             ["umlrelations", "umlbasics"], 10, [
    card("Vom Diagramm zum Code",
         "Eine abstrakte Klasse steht in UML mit «abstract» über dem Namen. Die Kind-Klassen hängen "
         "mit der Dreiecksspitze daran und füllen die fehlende Methode aus. Das Bild rechts ist also "
         "genau der Java-Code darunter – nur kürzer aufgeschrieben.",
         diagram=FORM_HIERARCHIE,
         code="""
         abstract class Form {
             abstract double flaeche();
         }

         class Quadrat extends Form {
             private double seite;

             Quadrat(double seite) {
                 this.seite = seite;
             }

             @Override
             double flaeche() {
                 return seite * seite;
             }
         }
         """,
         verify={"context": "file", "main": "System.out.println(new Quadrat(3).flaeche());", "output": "9.0"}),
    card("Vom Code zum Diagramm",
         "Umgekehrt geht es genauso: Jedes Feld wird eine Zeile im mittleren Fach, jede Methode eine "
         "Zeile im unteren Fach. private wird zu -, public zu +. Steht im Code ein Feld vom Typ einer "
         "anderen Klasse, zeichnet man eine Linie dorthin statt einer normalen Zeile.",
         code="""
         class Bestellung {
             private int nummer;
             private Kunde kunde;

             public double summe() {
                 return 0.0;
             }
         }
         """,
         diagram=BESTELLUNG,
         tip="Das Feld „kunde“ taucht im Kasten nicht als Zeile auf – dafür gibt es die Linie zum Kunden."),
], [
    mc("t32-1", "umlrelations", 1, "Welcher Java-Code passt zum Diagramm?",
       ["class Hund extends Tier { }",
        "class Tier extends Hund { }",
        "class Hund implements Tier { }",
        "class Hund { Tier tier; }"],
       "Die Dreiecksspitze zeigt von Hund auf Tier – also erbt Hund von Tier: class Hund extends Tier.",
       diagram=TIER_HUND),
    mc("t32-2", "umlbasics", 2, "Welche UML-Zeile passt zu „public void einzahlen(double betrag)“?",
       ["+ einzahlen()", "- einzahlen()", "+ einzahlen(): double", "# einzahlen(): void"],
       "public wird zu +, und weil die Methode nichts zurückgibt (void), steht hinter dem Namen kein Typ.",
       diagram=KONTO),
    out("t32-3", "umlrelations", 3, "Das Diagramm zeigt Form mit den Kindern Kreis und Quadrat. Was gibt dieser Code aus?",
        """
        abstract class Form {
            abstract double flaeche();
        }

        class Quadrat extends Form {
            private double seite;

            Quadrat(double seite) {
                this.seite = seite;
            }

            @Override
            double flaeche() {
                return seite * seite;
            }
        }

        public class Main {
            public static void main(String[] args) {
                Form f = new Quadrat(4);
                System.out.println(f.flaeche());
            }
        }
        """,
        "16.0",
        "Auf dem Etikett steht Form, drin liegt ein Quadrat – aufgerufen wird die Methode des echten Objekts: 4 · 4 = 16.0.",
        ctx="file",
        diagram=FORM_HIERARCHIE),
    fill("t32-4", "umlrelations", 3, "Ergänze den Code zum Diagramm: Auto setzt das Interface Fahrbar um.",
         """
         interface Fahrbar {
             void fahren();
         }

         class Auto {{0}} Fahrbar {
             public void fahren() {
                 System.out.println("faehrt");
             }
         }
         """,
         [["implements"]],
         "Die gestrichelte Linie mit Dreiecksspitze auf ein Interface heißt implements.",
         ctx="file",
         diagram=INTERFACE_DIAGRAM,
         verify={"context": "file", "main": "new Auto().fahren();", "output": "faehrt"}),
    code("t32-5", "umlrelations", 4,
         "Setze das Diagramm um: Hund erbt von Tier und überschreibt laut() mit der Rückgabe \"Wau\".",
         """
         class Tier {
             protected String name;

             public String laut() {
                 return "...";
             }
         }

         // Klasse Hund hier
         """,
         """
         class Tier {
             protected String name;

             public String laut() {
                 return "...";
             }
         }

         class Hund extends Tier {
             @Override
             public String laut() {
                 return "Wau";
             }
         }
         """,
         [req(r"class\s+Hund\s+extends\s+Tier", "Die Dreiecksspitze bedeutet extends."),
          req(r"public\s+String\s+laut\s*\(\s*\)", "Überschreibe die Methode laut()."),
          req(r'"Wau"', "Gib \"Wau\" zurück.", scope="raw")],
         "Die Dreiecksspitze im Diagramm wird zu extends; die Methode im Kasten des Hundes überschreibt die geerbte.",
         ctx="file",
         diagram=TIER_HUND,
         verify={"context": "file", "main": "System.out.println(new Hund().laut());", "output": "Wau"}),
])

UML_MODULE = {
    "id": "m13-uml", "title": "UML", "subtitle": "Klassendiagramme lesen, schreiben und in Java übersetzen",
    "tier": "intermediate", "symbol": "square.on.square", "lessons": [l30, l31, l32],
}

# Varianten für den Übungspool – damit UML im freien Training nicht nach drei Runden ausgeht.
UML_POOL = [
    mc("p-uml-1a", "umlbasics", 2, "Was bedeutet das Zeichen # vor einem Attribut?",
       ["geschützt – in der Klasse und in ihren Kind-Klassen nutzbar",
        "privat – nur in der eigenen Klasse",
        "öffentlich – von überall",
        "Das Attribut ist eine Konstante"],
       "# steht für protected: Die eigene Klasse und alle Kind-Klassen kommen heran, sonst niemand.",
       diagram=TIER_HUND, group="t30-2"),
    mc("p-uml-1b", "umlbasics", 2, "In welchem Fach des Kastens stehen die Methoden?",
       ["Im untersten Fach", "Im obersten Fach", "Im mittleren Fach", "Neben dem Klassennamen"],
       "Von oben nach unten: Name, Attribute, Methoden.",
       diagram=KONTO, group="t30-1"),
    mc("p-uml-2a", "umlrelations", 3, "Was bedeutet die gefüllte Raute am Haus?",
       ["Komposition: Ohne das Haus gibt es die Räume nicht",
        "Aggregation: Die Räume leben ohne das Haus weiter",
        "Vererbung: Raum erbt von Haus",
        "Assoziation ohne weitere Bedeutung"],
       "Gefüllte Raute = Komposition. Das Ganze und seine Teile gehören untrennbar zusammen.",
       diagram=HAUS, group="t31-3"),
    mc("p-uml-2b", "umlrelations", 3, "Welche Vielfachheit heißt „keine oder genau eine“?",
       ["0..1", "1", "1..*", "*"],
       "0..1 erlaubt auch keinen Partner. 1 verlangt genau einen, 1..* mindestens einen, * beliebig viele.",
       diagram=BESTELLUNG, group="t31-4"),
    mc("p-uml-3a", "umlrelations", 3, "Welcher Java-Code passt zur gestrichelten Linie mit Dreiecksspitze?",
       ["class Auto implements Fahrbar { }",
        "class Auto extends Fahrbar { }",
        "interface Auto extends Fahrbar { }",
        "class Fahrbar implements Auto { }"],
       "Gestrichelt plus Dreiecksspitze auf ein «interface» heißt implements – die Klasse erfüllt den Vertrag.",
       diagram=INTERFACE_DIAGRAM, group="t31-2"),
]
