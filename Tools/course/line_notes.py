"""Handgeschriebene Zeilenerklärungen (Vorrang vor der Engine). Schlüssel: Codezeile ohne Einrückung."""
NOTES = {
    "public class Hallo {": "Hier beginnt die Klasse „Hallo“. In Java muss jedes Programm in so einer Klasse stehen – hier dient sie nur als Behälter für unser Programm, nicht als Kuchenform für Objekte. Die geschweifte Klammer { öffnet den Behälter.",
    "public class Main {": "Hier beginnt die Klasse „Main“. In Java muss jedes Programm in so einer Klasse stehen – hier dient sie nur als Behälter für unser Programm, nicht als Kuchenform für Objekte. Die geschweifte Klammer { öffnet den Behälter.",
    "int x = 10 / 0;": "Hier soll 10 durch 0 geteilt werden. Das geht mathematisch nicht – Java löst deshalb sofort einen Alarm aus (eine ArithmeticException). Die Box „x“ wird nie befüllt; das Programm springt direkt zum passenden catch-Block.",
    "int x = 5 / 0;": "Hier soll 5 durch 0 geteilt werden. Das geht mathematisch nicht – Java löst deshalb sofort einen Alarm aus (eine ArithmeticException). Die Box „x“ wird nie befüllt; das Programm springt direkt zum passenden catch-Block.",
    "int zahl = i;": "Legt eine Kopie von i in die Box „zahl“. Ein Lambda darf nur Boxen benutzen, die sich danach nicht mehr ändern – i wird jede Runde größer, die Kopie „zahl“ bleibt für diese Aufgabe fest.",
    "p.x();": "Fragt beim Record „p“ den gespeicherten Wert „x“ ab. Records bauen diese Abfrage-Methode für jedes Feld automatisch – sie heißt genauso wie das Feld.",
}
