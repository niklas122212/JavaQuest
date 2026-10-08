/* Der eingebaute Java-Interpreter – dieselbe Teilmenge und dieselben Meldungen wie in der
   Apple-App (Packages/JavaQuestKit/Sources/JavaQuestKit/Interpreter) und unter Windows.

   Er kennt Variablen, Kontrollfluss, statische Methoden, Arrays und Strings. Klassen,
   Lambdas, Collections und try/catch meldet er als „nicht unterstützt“ – dann bleibt es
   bei der Regelprüfung. Ganzzahlen rechnen wie in Java: int mit 32 Bit, long mit 64 Bit
   (BigInt), beide laufen über.

   Klassisches Browser-Skript ohne Fremdbibliothek: Es legt nur `JavaKern` an. Die Prüfungen
   unter Node laden dieselbe Datei (siehe tests/java.mjs). */
const JavaKern = (() => {
  "use strict";

  // MARK: - Probleme

  class JavaProblem extends Error {
    /** kind: "syntax" | "unsupported" | "runtime" | "stepLimit" */
    constructor(kind, message, line) {
      super(message);
      this.kind = kind;
      this.line = line == null ? null : line;
    }
    /** Meldung mit vorangestellter Zeilennummer. */
    get description() { return this.line == null ? this.message : `Zeile ${this.line}: ${this.message}`; }
  }
  const syntax = (m, line) => new JavaProblem("syntax", m, line);
  const unsupported = (m, line) => new JavaProblem("unsupported", m, line);
  const runtime = (m, line) => new JavaProblem("runtime", m, line);

  // MARK: - Typen
  // Als Text: "int", "long", "double", "boolean", "char", "String", "void", "var" (abgeleitet),
  // Arrays mit "[]" ("int[][]"), unbekannte Klassen mit "?" davor ("?ArrayList<String>").

  const isArrayType = (t) => t.endsWith("[]");
  const elementOf = (t) => t.slice(0, -2);
  const baseOf = (t) => t.replace(/(\[\])+$/, "");
  const typeText = (t) => (t.startsWith("?") ? t.slice(1) : t);
  const isUnknown = (t) => t.startsWith("?");

  // MARK: - Werte

  class JavaString { constructor(text) { this.text = text; } }

  let arrayCounter = 0x1b6d3586;
  class JavaArray {
    constructor(elementType, elements) {
      this.elementType = elementType;
      this.elements = elements;
      // Eindeutige „Adresse“, wie Java sie bei println(array) zeigt.
      arrayCounter = (Math.imul(arrayCounter, 31) + 7) & 0x7fffffff;
      this.serial = arrayCounter;
    }
    get identityString() {
      const code = { int: "[I", long: "[J", double: "[D", boolean: "[Z", char: "[C", String: "[Ljava.lang.String;" }[this.elementType] || "[Ljava.lang.Object;";
      return `${code}@${this.serial.toString(16)}`;
    }
  }

  const NULL = Object.freeze({ k: "null" });
  const VOID = Object.freeze({ k: "void" });
  const TRUE = Object.freeze({ k: "boolean", v: true });
  const FALSE = Object.freeze({ k: "boolean", v: false });
  const V = {
    int: (v) => ({ k: "int", v }),
    long: (v) => ({ k: "long", v }),
    double: (v) => ({ k: "double", v }),
    boolean: (v) => (v ? TRUE : FALSE),
    char: (v) => ({ k: "char", v }),
    /** Ein neu berechneter String – ein eigenes Objekt. */
    str: (text) => ({ k: "string", o: new JavaString(text) }),
    string: (object) => ({ k: "string", o: object }),
    array: (array) => ({ k: "array", a: array }),
  };

  function valueType(value) {
    switch (value.k) {
      case "string": return "String";
      case "array": return `${value.a.elementType}[]`;
      case "null": return "?null";
      default: return value.k;
    }
  }
  const typeName = (value) => (value.k === "null" ? "null" : typeText(valueType(value)));

  /** Text, wie ihn System.out.println bzw. String-Verkettung erzeugt. */
  function javaString(value) {
    switch (value.k) {
      case "int": return String(value.v);
      case "long": return value.v.toString();
      case "double": return formatDouble(value.v);
      case "boolean": return value.v ? "true" : "false";
      case "char": return String.fromCharCode(value.v);
      case "string": return value.o.text;
      case "array": return value.a.identityString;
      case "null": return "null";
      default: return "";
    }
  }

  /** Darstellung für die Variablen-Anzeige: Strings in Anführungszeichen, Arrays mit Inhalt. */
  function debugDisplay(value) {
    switch (value.k) {
      case "string": return `"${value.o.text}"`;
      case "char": return `'${javaString(value)}'`;
      case "array": {
        const items = value.a.elements;
        return "{" + items.slice(0, 12).map(debugDisplay).join(", ") + (items.length > 12 ? ", …" : "") + "}";
      }
      default: return javaString(value);
    }
  }

  function defaultValue(type) {
    switch (type) {
      case "int": return V.int(0);
      case "long": return V.long(0n);
      case "double": return V.double(0);
      case "boolean": return FALSE;
      case "char": return V.char(0);
      default: return NULL;
    }
  }

  // MARK: - Zahlen und Formate

  const INT_MIN = -2147483648, INT_MAX = 2147483647;
  const LONG_MIN = -(2n ** 63n), LONG_MAX = 2n ** 63n - 1n;
  const asLong = (x) => BigInt.asIntN(64, x);

  /** Zerlegt eine positive Zahl in Ziffern D und Exponent E mit Wert = 0.D × 10^E – kürzeste eindeutige Darstellung. */
  function decimalDigits(value) {
    const [mantissa, power] = value.toExponential().split("e");
    const digits = mantissa.replace(".", "").replace(/0+$/, "") || "0";
    return [digits, Number(power) + 1];
  }

  /** Double.toString aus Java: zwischen 10⁻³ und 10⁷ als Dezimalzahl, sonst wissenschaftlich (1.0E10). */
  function formatDouble(value) {
    if (Number.isNaN(value)) return "NaN";
    if (!Number.isFinite(value)) return value < 0 ? "-Infinity" : "Infinity";
    if (value === 0) return Object.is(value, -0) ? "-0.0" : "0.0";
    const sign = value < 0 ? "-" : "";
    const magnitude = Math.abs(value);
    const [digits, exponent] = decimalDigits(magnitude);
    if (magnitude >= 1e-3 && magnitude < 1e7) {
      if (exponent <= 0) return `${sign}0.${"0".repeat(-exponent)}${digits}`;
      if (exponent >= digits.length) return `${sign}${digits}${"0".repeat(exponent - digits.length)}.0`;
      return `${sign}${digits.slice(0, exponent)}.${digits.slice(exponent)}`;
    }
    const rest = digits.length > 1 ? digits.slice(1) : "0";
    return `${sign}${digits[0]}.${rest}E${exponent - 1}`;
  }

  /** Kaufmännisches Runden (HALF_UP) auf der Dezimaldarstellung – wie Javas Formatter. */
  function fixed(value, precision) {
    if (Number.isNaN(value)) return "NaN";
    if (!Number.isFinite(value)) return value < 0 ? "-Infinity" : "Infinity";
    const negative = value < 0 || Object.is(value, -0);
    let intPart = "0", frac = "";
    if (value !== 0) {
      const [digits, exponent] = decimalDigits(Math.abs(value));
      if (exponent <= 0) { frac = "0".repeat(-exponent) + digits; }
      else if (exponent >= digits.length) { intPart = digits + "0".repeat(exponent - digits.length); }
      else { intPart = digits.slice(0, exponent); frac = digits.slice(exponent); }
    }
    if (frac.length > precision) {
      const roundUp = frac[precision] >= "5";
      let all = (intPart + frac.slice(0, precision)).split("").map(Number);
      if (roundUp) {
        let i = all.length - 1;
        while (i >= 0) {
          if (all[i] === 9) { all[i] = 0; i -= 1; } else { all[i] += 1; break; }
        }
        if (i < 0) all = [1, ...all];
      }
      const text = all.join("");
      intPart = text.slice(0, text.length - precision) || "0";
      frac = text.slice(text.length - precision);
    } else {
      frac = frac.padEnd(precision, "0");
    }
    intPart = intPart.replace(/^0+(?=\d)/, "");
    return (negative ? "-" : "") + intPart + (precision > 0 ? "." + frac : "");
  }

  function grouped(digits) {
    return digits.replace(/\B(?=(\d{3})+(?!\d))/g, ",");
  }

  /** String.format/printf für die gängigen Platzhalter: %d %s %f %.2f %c %b %x %e %n %% samt Breite und Flags. */
  function format(pattern, args, line) {
    let result = "";
    let i = 0;
    let argIndex = 0;
    while (i < pattern.length) {
      const c = pattern[i++];
      if (c !== "%") { result += c; continue; }
      let flags = "";
      while (i < pattern.length && "-0+,# ".includes(pattern[i])) flags += pattern[i++];
      let widthText = "";
      while (i < pattern.length && /[0-9]/.test(pattern[i])) widthText += pattern[i++];
      let precision = null;
      if (pattern[i] === ".") {
        i += 1;
        let p = "";
        while (i < pattern.length && /[0-9]/.test(pattern[i])) p += pattern[i++];
        precision = Number(p) || 0;
      }
      if (i >= pattern.length) {
        throw runtime("UnknownFormatConversionException: Das Format endet mit einem einzelnen %.", line);
      }
      const conversion = pattern[i++];
      if (conversion === "n") { result += "\n"; continue; }
      if (conversion === "%") { result += "%"; continue; }
      if (argIndex >= args.length) {
        throw runtime(`MissingFormatArgumentException: Für „%${conversion}“ fehlt ein Wert.`, line);
      }
      const arg = args[argIndex++];
      let text;
      switch (conversion) {
        case "d": {
          let number;
          if (arg.k === "int") number = BigInt(arg.v);
          else if (arg.k === "long") number = arg.v;
          else throw runtime(`IllegalFormatConversionException: %d erwartet eine Ganzzahl, bekam ${typeName(arg)}.`, line);
          const absolute = (number < 0n ? -number : number).toString();
          text = flags.includes(",") ? grouped(absolute) : absolute;
          if (number < 0n) text = "-" + text; else if (flags.includes("+")) text = "+" + text;
          break;
        }
        case "f": case "e": {
          if (arg.k !== "double") {
            throw runtime(`IllegalFormatConversionException: %${conversion} erwartet eine Kommazahl (double), bekam ${typeName(arg)}.`, line);
          }
          const number = arg.v;
          if (conversion === "e") {
            text = number.toExponential(precision == null ? 6 : precision).replace(/e([+-])(\d)$/, "e$10$2");
          } else {
            text = fixed(number, precision == null ? 6 : precision);
            if (flags.includes(",")) {
              const negative = text.startsWith("-");
              const body = negative ? text.slice(1) : text;
              const [whole, part] = body.split(".");
              text = (negative ? "-" : "") + grouped(whole) + (part != null ? "." + part : "");
            }
          }
          if (number >= 0 && flags.includes("+")) text = "+" + text;
          break;
        }
        case "s": case "S":
          text = javaString(arg);
          if (precision != null) text = text.slice(0, precision);
          if (conversion === "S") text = text.toUpperCase();
          break;
        case "c":
          text = javaString(arg);
          break;
        case "b": case "B":
          text = arg.k === "boolean" ? String(arg.v) : arg.k === "null" ? "false" : "true";
          break;
        case "x": case "X":
          if (arg.k === "int") text = (arg.v >>> 0).toString(16);
          else if (arg.k === "long") text = BigInt.asUintN(64, arg.v).toString(16);
          else throw runtime("IllegalFormatConversionException: %x erwartet eine Ganzzahl.", line);
          if (conversion === "X") text = text.toUpperCase();
          break;
        default:
          throw runtime(`UnknownFormatConversionException: „%${conversion}“ kennt String.format nicht.`, line);
      }
      const width = widthText === "" ? null : Number(widthText);
      if (width != null && text.length < width) {
        const padding = width - text.length;
        if (flags.includes("-")) {
          text += " ".repeat(padding);
        } else if (flags.includes("0") && "dfx".includes(conversion)) {
          const negative = text.startsWith("-");
          const body = negative ? text.slice(1) : text;
          text = (negative ? "-" : "") + "0".repeat(padding) + body;
        } else {
          text = " ".repeat(padding) + text;
        }
      }
      result += text;
    }
    return result;
  }

  /** Javas binäre numerische Typanpassung: char/int → int, dann long, dann double. */
  function numeric(value) {
    switch (value.k) {
      case "int": return { t: "int", v: value.v };
      case "char": return { t: "int", v: value.v };
      case "long": return { t: "long", v: value.v };
      case "double": return { t: "double", v: value.v };
      default: return null;
    }
  }
  const N = {
    value: (n) => (n.t === "int" ? V.int(n.v) : n.t === "long" ? V.long(n.v) : V.double(n.v)),
    toDouble: (n) => (n.t === "long" ? Number(n.v) : n.v),
    toInt64(n) {
      if (n.t === "int") return BigInt(n.v);
      if (n.t === "long") return n.v;
      const v = n.v;
      if (Number.isNaN(v)) return 0n;
      if (v >= 9.223372036854775807e18) return LONG_MAX;
      if (v <= -9.223372036854775808e18) return LONG_MIN;
      return BigInt(Math.trunc(v));
    },
    toInt32(n) {
      if (n.t === "int") return n.v;
      if (n.t === "long") return Number(BigInt.asIntN(32, n.v));
      const v = n.v;
      if (Number.isNaN(v)) return 0;
      if (v >= INT_MAX) return INT_MAX;
      if (v <= INT_MIN) return INT_MIN;
      return Math.trunc(v) | 0;
    },
    isNaN: (n) => n.t === "double" && Number.isNaN(n.v),
    isZeroIntegral: (n) => (n.t === "int" ? n.v === 0 : n.t === "long" ? n.v === 0n : false),
    promote(a, b) {
      if (a.t === "double" || b.t === "double") return [{ t: "double", v: N.toDouble(a) }, { t: "double", v: N.toDouble(b) }];
      if (a.t === "long" || b.t === "long") return [{ t: "long", v: N.toInt64(a) }, { t: "long", v: N.toInt64(b) }];
      return [a, b];
    },
    /** -1, 0 oder 1 – NaN ist mit nichts gleich (ergibt -1 wie in der Apple-Fassung). */
    compare(a, b) {
      const [x, y] = N.promote(a, b);
      if (x.t !== "double") return x.v < y.v ? -1 : x.v > y.v ? 1 : 0;
      return x.v < y.v ? -1 : x.v > y.v ? 1 : x.v === y.v ? 0 : -1;
    },
    apply(op, a, b) {
      const [x, y] = N.promote(a, b);
      if (x.t === "int") {
        switch (op) {
          case "+": return { t: "int", v: (x.v + y.v) | 0 };
          case "-": return { t: "int", v: (x.v - y.v) | 0 };
          case "*": return { t: "int", v: Math.imul(x.v, y.v) };
          case "/": return { t: "int", v: (x.v / y.v) | 0 };
          default: return { t: "int", v: (x.v % y.v) | 0 };
        }
      }
      if (x.t === "long") {
        switch (op) {
          case "+": return { t: "long", v: asLong(x.v + y.v) };
          case "-": return { t: "long", v: asLong(x.v - y.v) };
          case "*": return { t: "long", v: asLong(x.v * y.v) };
          case "/": return { t: "long", v: asLong(x.v / y.v) };
          default: return { t: "long", v: asLong(x.v % y.v) };
        }
      }
      switch (op) {
        case "+": return { t: "double", v: x.v + y.v };
        case "-": return { t: "double", v: x.v - y.v };
        case "*": return { t: "double", v: x.v * y.v };
        case "/": return { t: "double", v: x.v / y.v };
        default: return { t: "double", v: x.v % y.v };
      }
    },
    bitwise(op, a, b) {
      if (op === "<<" || op === ">>" || op === ">>>") {
        // Bei Shifts bestimmt nur der linke Operand den Typ.
        if (a.t === "int") {
          const n = Number(N.toInt64(b) & 31n);
          if (op === "<<") return { t: "int", v: a.v << n };
          if (op === ">>") return { t: "int", v: a.v >> n };
          return { t: "int", v: (a.v >>> n) | 0 };
        }
        const x = N.toInt64(a);
        const n = N.toInt64(b) & 63n;
        if (op === "<<") return { t: "long", v: asLong(x << n) };
        if (op === ">>") return { t: "long", v: x >> n };
        return { t: "long", v: asLong(BigInt.asUintN(64, x) >> n) };
      }
      const [x, y] = N.promote(a, b);
      if (x.t === "int") {
        if (op === "&") return { t: "int", v: x.v & y.v };
        if (op === "|") return { t: "int", v: x.v | y.v };
        return { t: "int", v: x.v ^ y.v };
      }
      const p = N.toInt64(x), q = N.toInt64(y);
      if (op === "&") return { t: "long", v: asLong(p & q) };
      if (op === "|") return { t: "long", v: asLong(p | q) };
      return { t: "long", v: asLong(p ^ q) };
    },
  };

  // MARK: - Quelltext

  /** Ersetzt typografische Zeichen („smarte“ Anführungszeichen, Gedankenstriche) durch ASCII. */
  function normalizingTypography(text) {
    return String(text)
      .replace(/[“”„‟«»]/g, "\"")
      .replace(/[‘’‚‛]/g, "'")
      .replace(/—/g, "--")
      .replace(/–/g, "-")
      .replace(/…/g, "...")
      .replace(/ /g, " ");
  }

  /** Kommentare entfernen (plain) und zusätzlich Literale leeren (masked) – wie JavaSource im Kern. */
  function scan(source) {
    const chars = Array.from(source);
    let plain = "", masked = "";
    let state = "code";
    let i = 0;
    const peek = (o) => (i + o < chars.length ? chars[i + o] : null);
    while (i < chars.length) {
      const c = chars[i];
      if (state === "code") {
        if (c === "/" && peek(1) === "/") { state = "line"; i += 2; continue; }
        if (c === "/" && peek(1) === "*") { state = "block"; plain += " "; masked += " "; i += 2; continue; }
        if (c === "\"" && peek(1) === "\"" && peek(2) === "\"") { state = "textBlock"; plain += "\"\"\""; masked += "\"\"\""; i += 3; continue; }
        if (c === "\"") state = "string";
        if (c === "'") state = "character";
        plain += c; masked += c;
      } else if (state === "line") {
        if (c === "\n") { state = "code"; plain += c; masked += c; }
      } else if (state === "block") {
        if (c === "*" && peek(1) === "/") { state = "code"; i += 2; continue; }
        if (c === "\n") { plain += c; masked += c; }
      } else if (state === "string" || state === "character") {
        const delimiter = state === "string" ? "\"" : "'";
        if (c === "\\" && peek(1) != null) { plain += c + peek(1); i += 2; continue; }
        if (c === delimiter || c === "\n") {
          // Zeilenende schließt ein nicht beendetes Literal, damit der Rest analysierbar bleibt.
          state = "code";
          plain += c;
          masked += c === "\n" ? "\n" : delimiter;
        } else {
          plain += c;
        }
      } else {
        if (c === "\"" && peek(1) === "\"" && peek(2) === "\"") { state = "code"; plain += "\"\"\""; masked += "\"\"\""; i += 3; continue; }
        plain += c;
        if (c === "\n") masked += c;
      }
      i += 1;
    }
    return { plain, masked };
  }
  const strippingComments = (source) => scan(source).plain;
  const maskingLiterals = (source) => scan(source).masked;

  // MARK: - Lexer

  const KEYWORDS = new Set([
    "abstract", "boolean", "break", "byte", "case", "catch", "char", "class", "continue", "default",
    "do", "double", "else", "enum", "extends", "final", "finally", "float", "for", "if", "implements",
    "import", "instanceof", "int", "interface", "long", "new", "null", "package", "private", "protected",
    "public", "return", "short", "static", "super", "switch", "this", "throw", "throws", "true", "false",
    "try", "void", "while", "var", "yield", "record",
  ]);
  /** Mehrzeichen-Operatoren zuerst, damit >>>= nicht als > > … zerfällt. */
  const SYMBOLS = [
    ">>>=", "<<=", ">>=", ">>>", "...", "->", "::", "++", "--", "&&", "||", "==", "!=", "<=", ">=",
    "+=", "-=", "*=", "/=", "%=", "&=", "|=", "^=", "<<", ">>",
    "(", ")", "{", "}", "[", "]", ";", ",", ".", "=", "<", ">", "!", "~", "?", ":",
    "+", "-", "*", "/", "%", "&", "|", "^", "@",
  ];
  const isNumber = (c) => c != null && /\p{N}/u.test(c);
  const isLetter = (c) => c != null && /\p{L}/u.test(c);
  const isHexDigit = (c) => c != null && /[0-9a-fA-F]/.test(c);
  const isWhitespace = (c) => /\s/u.test(c);

  class Token {
    constructor(kind, text, line) { this.kind = kind; this.text = text; this.line = line; }
    is(symbol) { return (this.kind === "symbol" || this.kind === "keyword") && this.text === symbol; }
  }

  function tokenize(source) {
    const chars = Array.from(normalizingTypography(source));
    const tokens = [];
    let i = 0;
    let line = 1;
    const peek = (o = 0) => (i + o < chars.length ? chars[i + o] : null);

    function escape() {
      if (i + 1 >= chars.length) throw syntax("Nach \\ fehlt ein Zeichen.", line);
      const e = chars[i + 1];
      i += 2;
      switch (e) {
        case "n": return "\n";
        case "t": return "\t";
        case "r": return "\r";
        case "b": return "\b";
        case "f": return "\f";
        case "0": return "\0";
        case "\\": return "\\";
        case "'": return "'";
        case "\"": return "\"";
        case "u": {
          let hex = "";
          while (hex.length < 4 && i < chars.length && isHexDigit(chars[i])) hex += chars[i++];
          if (hex.length !== 4) throw syntax("\\u braucht genau vier Hex-Ziffern, z. B. \\u00e4.", line);
          return String.fromCharCode(parseInt(hex, 16));
        }
        default:
          throw syntax(`„\\${e}“ ist keine gültige Escape-Sequenz.`, line);
      }
    }

    while (i < chars.length) {
      const c = chars[i];
      if (c === "\n") { line += 1; i += 1; continue; }
      if (isWhitespace(c)) { i += 1; continue; }

      // Kommentare
      if (c === "/" && peek(1) === "/") {
        while (i < chars.length && chars[i] !== "\n") i += 1;
        continue;
      }
      if (c === "/" && peek(1) === "*") {
        const startLine = line;
        i += 2;
        while (i < chars.length && !(chars[i] === "*" && peek(1) === "/")) {
          if (chars[i] === "\n") line += 1;
          i += 1;
        }
        if (i >= chars.length) throw syntax("Der Kommentar /* … wird nie mit */ geschlossen.", startLine);
        i += 2;
        continue;
      }

      // Zahlen
      if (isNumber(c) || (c === "." && isNumber(peek(1)))) {
        let text = "";
        let isDouble = false;
        if (c === "0" && (peek(1) === "x" || peek(1) === "X")) {
          i += 2;
          let hex = "";
          while (isHexDigit(peek()) || peek() === "_") { if (peek() !== "_") hex += peek(); i += 1; }
          const isLong = peek() === "L" || peek() === "l";
          if (isLong) i += 1;
          if (hex === "" || hex.length > 16) throw syntax(`„0x${hex}“ ist keine gültige Hexadezimalzahl.`, line);
          tokens.push(new Token(isLong ? "longLiteral" : "intLiteral", BigInt.asIntN(64, BigInt("0x" + hex)).toString(), line));
          continue;
        }
        while (true) {
          const d = peek();
          if (d == null) break;
          const last = text[text.length - 1];
          if (!(isNumber(d) || d === "_" || d === "." || d === "e" || d === "E" || ((d === "+" || d === "-") && (last === "e" || last === "E")))) break;
          if (d === ".") {
            // 1..2 gibt es nicht; ein Punkt gefolgt von einem Buchstaben ist ein Methodenaufruf.
            const next = peek(1);
            if (!(next != null && (isNumber(next) || !isLetter(next)))) break;
            if (isDouble) break;
            isDouble = true;
          }
          if (d === "e" || d === "E") isDouble = true;
          if (d !== "_") text += d;
          i += 1;
        }
        const suffix = peek();
        if (suffix != null && "lLdDfF".includes(suffix)) {
          i += 1;
          if (suffix === "l" || suffix === "L") tokens.push(new Token("longLiteral", text, line));
          else if (suffix === "f" || suffix === "F") throw unsupported("float-Zahlen (mit f am Ende) kennt der eingebaute Interpreter nicht – nimm double.", line);
          else tokens.push(new Token("doubleLiteral", text, line));
          continue;
        }
        tokens.push(new Token(isDouble ? "doubleLiteral" : "intLiteral", text, line));
        continue;
      }

      // Namen und Schlüsselwörter
      if (isLetter(c) || c === "_" || c === "$") {
        let text = "";
        while (peek() != null && (isLetter(peek()) || isNumber(peek()) || peek() === "_" || peek() === "$")) text += chars[i++];
        tokens.push(new Token(KEYWORDS.has(text) ? "keyword" : "identifier", text, line));
        continue;
      }

      // Text-Blöcke """…""" werden nicht unterstützt, normale Strings schon.
      if (c === "\"") {
        if (peek(1) === "\"" && peek(2) === "\"") {
          throw unsupported("Text-Blöcke (\"\"\") kennt der eingebaute Interpreter nicht.", line);
        }
        i += 1;
        let value = "";
        while (true) {
          const d = peek();
          if (d == null || d === "\n") throw syntax("Der Text wird nicht mit \" geschlossen.", line);
          if (d === "\"") { i += 1; break; }
          if (d === "\\") { value += escape(); continue; }
          value += d;
          i += 1;
        }
        tokens.push(new Token("stringLiteral", value, line));
        continue;
      }
      if (c === "'") {
        i += 1;
        let value = "";
        if (peek() === "\\") {
          value += escape();
        } else if (peek() != null && peek() !== "'" && peek() !== "\n") {
          value += chars[i++];
        }
        if (peek() !== "'" || Array.from(value).length !== 1) {
          throw syntax("Ein char steht in einfachen Anführungszeichen und enthält genau ein Zeichen, z. B. 'a'.", line);
        }
        i += 1;
        tokens.push(new Token("charLiteral", value, line));
        continue;
      }

      const symbol = SYMBOLS.find((s) => chars.slice(i, i + s.length).join("") === s);
      if (symbol) {
        tokens.push(new Token("symbol", symbol, line));
        i += symbol.length;
        continue;
      }
      throw syntax(`Das Zeichen „${c}“ gehört nicht in Java-Code.`, line);
    }
    tokens.push(new Token("end", "", line));
    return tokens;
  }

  // MARK: - Parser
  // Ausdrücke und Anweisungen sind Objekte mit `k` (Art) und `line`.

  const MODIFIERS = new Set(["public", "private", "protected", "static", "final", "abstract"]);
  const PRIMITIVE = { int: "int", long: "long", double: "double", boolean: "boolean", char: "char" };
  const ASSIGNMENT_OPS = new Set(["=", "+=", "-=", "*=", "/=", "%=", "&=", "|=", "^=", "<<=", ">>=", ">>>="]);
  const LEVELS = [
    ["||"], ["&&"], ["|"], ["^"], ["&"], ["==", "!="], ["<", ">", "<=", ">=", "instanceof"],
    ["<<", ">>", ">>>"], ["+", "-"], ["*", "/", "%"],
  ];

  class Parser {
    constructor(tokens) {
      this.tokens = tokens;
      this.position = 0;
      this.classCount = 0;
      /** String-Pool: Gleiche Literale sind in Java dasselbe Objekt ("a" == "a" ist true). */
      this.pool = new Map();
    }

    intern(text) {
      if (!this.pool.has(text)) this.pool.set(text, new JavaString(text));
      return this.pool.get(text);
    }

    get current() { return this.tokens[this.position]; }
    peek(offset = 1) { return this.tokens[Math.min(this.position + offset, this.tokens.length - 1)]; }
    get previousLine() { return this.position > 0 ? this.tokens[this.position - 1].line : this.current.line; }

    advance() {
      const token = this.tokens[this.position];
      if (this.position < this.tokens.length - 1) this.position += 1;
      return token;
    }

    accept(symbol) {
      if (!this.current.is(symbol)) return false;
      this.position += 1;
      return true;
    }

    expect(symbol, message) {
      if (this.accept(symbol)) return;
      if (symbol === ";") {
        // Wie javac: Das fehlende Semikolon gehört zur vorigen Zeile.
        throw syntax("Hier fehlt ein Semikolon (;) am Ende der Anweisung.", this.previousLine);
      }
      const found = this.current.kind === "end" ? "das Ende des Codes" : `„${this.current.text}“`;
      throw syntax(message || `Erwartet wurde „${symbol}“, gefunden ${found}.`, this.current.kind === "end" ? this.previousLine : this.current.line);
    }

    identifier(what) {
      if (this.current.kind !== "identifier") {
        if (this.current.kind === "keyword") {
          throw syntax(`„${this.current.text}“ ist ein reserviertes Java-Wort und kann nicht als ${what} dienen.`, this.current.line);
        }
        throw syntax(`Hier wird ein Name für ${what} erwartet.`, this.current.line);
      }
      return this.advance().text;
    }

    /** Wie `try?` in Swift: Fehler werden verschluckt, es kommt null zurück. */
    attempt(fn) {
      try { return fn(); } catch (e) { if (e instanceof JavaProblem) return null; throw e; }
    }

    // Programm

    parseProgram() {
      const program = { methods: new Map(), staticFields: [], statements: [], hasMain: false };
      while (this.current.kind !== "end") {
        if (this.current.is("import") || this.current.is("package")) {
          while (this.current.kind !== "end" && !this.current.is(";")) this.advance();
          this.expect(";");
          continue;
        }
        if (this.current.is("@")) { this.skipAnnotation(); continue; }
        const start = this.position;
        const mods = new Set();
        while (MODIFIERS.has(this.current.text) && this.current.kind === "keyword") mods.add(this.advance().text);
        if (this.current.is("class")) { this.parseClass(program); continue; }
        if (this.current.is("interface") || this.current.is("enum") || this.current.is("record")) {
          throw unsupported(`${this.current.text} kennt der eingebaute Interpreter nicht.`, this.current.line);
        }
        const method = this.parseMethodIfPresent(mods);
        if (method) { this.add(method, program); continue; }
        if (mods.has("static")) {
          // static int zaehler = 0; zwischen eigenen Methoden: ein Feld für alle Methoden.
          program.staticFields.push(this.declarationStatement(mods.has("final")));
          continue;
        }
        this.position = start;
        program.statements.push(this.statement());
      }
      // main ohne umgebende Klasse (wie in Java 21+ mit „implicit classes“).
      const main = (program.methods.get("main") || [])[0];
      if (!program.hasMain && main && main.returnType === "void") {
        if (program.statements.length > 0) {
          throw syntax("Neben einer main-Methode dürfen keine losen Anweisungen stehen – sie gehören in main.", program.statements[0].line);
        }
        program.statements = main.body;
        program.hasMain = true;
        program.methods.delete("main");
      }
      return program;
    }

    skipAnnotation() {
      this.expect("@");
      this.identifier("die Annotation");
      if (this.accept("(")) {
        let depth = 1;
        while (depth > 0 && this.current.kind !== "end") {
          if (this.current.is("(")) depth += 1;
          if (this.current.is(")")) depth -= 1;
          this.advance();
        }
      }
    }

    add(method, program) {
      const existing = program.methods.get(method.name) || [];
      const signature = method.parameters.map((p) => p.type).join(",");
      if (existing.some((m) => m.parameters.map((p) => p.type).join(",") === signature)) {
        throw syntax(`Die Methode ${method.name} gibt es mit genau diesen Parametern schon.`, method.line);
      }
      program.methods.set(method.name, [...existing, method]);
    }

    parseClass(program) {
      const line = this.current.line;
      this.expect("class");
      const name = this.identifier("die Klasse");
      this.classCount += 1;
      if (this.classCount > 1) throw unsupported("Mehrere Klassen kennt der eingebaute Interpreter nicht.", line);
      if (this.current.is("extends") || this.current.is("implements") || this.current.is("<")) {
        throw unsupported("Vererbung und Interfaces kennt der eingebaute Interpreter nicht.", this.current.line);
      }
      this.expect("{", `Nach „class ${name}“ beginnt der Klassenkörper mit {.`);
      while (!this.current.is("}")) {
        if (this.current.kind === "end") throw syntax(`Die Klasse ${name} wird nicht mit } geschlossen.`, line);
        if (this.current.is("@")) { this.skipAnnotation(); continue; }
        if (this.accept(";")) continue;
        const mods = new Set();
        while (MODIFIERS.has(this.current.text) && this.current.kind === "keyword") mods.add(this.advance().text);
        if (["class", "interface", "enum", "record"].some((k) => this.current.is(k))) {
          throw unsupported("Verschachtelte Typen kennt der eingebaute Interpreter nicht.", this.current.line);
        }
        if (this.current.kind === "identifier" && this.current.text === name && this.peek().is("(")) {
          throw unsupported("Konstruktoren und Objekte eigener Klassen kennt der eingebaute Interpreter nicht.", this.current.line);
        }
        const method = this.parseMethodIfPresent(mods);
        if (method) {
          if (method.name === "main" && method.returnType === "void" && mods.has("static")) {
            program.statements.push(...method.body);
            program.hasMain = true;
          } else if (!mods.has("static")) {
            throw unsupported("Objektmethoden (ohne static) kennt der eingebaute Interpreter nicht.", method.line);
          } else {
            this.add(method, program);
          }
          continue;
        }
        if (!mods.has("static")) {
          throw unsupported("Objekt-Felder (ohne static) kennt der eingebaute Interpreter nicht.", this.current.line);
        }
        program.staticFields.push(this.declarationStatement(mods.has("final")));
      }
      this.expect("}");
    }

    /** Erkennt `Typ name(` und liest die ganze Methode – sonst bleibt die Position unverändert. */
    parseMethodIfPresent(modifiers) {
      const start = this.position;
      if (this.current.is("<")) throw unsupported("Generische Methoden kennt der eingebaute Interpreter nicht.", this.current.line);
      const line = this.current.line;
      const returnType = this.attempt(() => this.typeIfPresent(true));
      if (returnType == null || this.current.kind !== "identifier" || !this.peek().is("(")) {
        this.position = start;
        return null;
      }
      const name = this.advance().text;
      this.expect("(");
      const parameters = [];
      if (!this.current.is(")")) {
        do {
          this.accept("final");
          const type = this.typeIfPresent(false);
          if (type == null) throw syntax("Jeder Parameter braucht einen Typ, z. B. „int zahl“.", this.current.line);
          if (this.accept("...")) throw unsupported("Variable Parameterlisten (…) kennt der eingebaute Interpreter nicht.", this.previousLine);
          let parameterType = type;
          const parameterName = this.identifier("den Parameter");
          while (this.accept("[")) { this.expect("]"); parameterType += "[]"; }
          parameters.push({ type: parameterType, name: parameterName });
        } while (this.accept(","));
      }
      this.expect(")", `Die Parameterliste von ${name} wird mit ) geschlossen.`);
      if (this.accept("throws")) {
        do { this.identifier("die Exception"); } while (this.accept(","));
      }
      if (modifiers.has("abstract") || this.current.is(";")) {
        throw unsupported("Methoden ohne Körper kennt der eingebaute Interpreter nicht.", line);
      }
      this.expect("{", `Der Körper der Methode ${name} beginnt mit {.`);
      const body = this.blockBody(line);
      return { name, returnType, parameters, body, line };
    }

    // Typen

    /** Liest einen Typ, falls einer kommt (inkl. []). Wirft nur bei klar unpassendem Code. */
    typeIfPresent(allowVoid) {
      let type;
      const current = this.current;
      if (current.kind === "keyword") {
        if (current.text === "void" && allowVoid) type = "void";
        else if (current.text === "var") type = "var";
        else if (["byte", "short", "float"].includes(current.text)) {
          throw unsupported(`Den Typ ${current.text} kennt der eingebaute Interpreter nicht – nimm int oder double.`, current.line);
        } else if (PRIMITIVE[current.text]) type = PRIMITIVE[current.text];
        else return null;
        this.advance();
      } else if (current.kind === "identifier") {
        const name = this.advance().text;
        if (name === "String") {
          type = "String";
        } else {
          let full = name;
          // Qualifizierte Namen wie java.util.List
          while (this.current.is(".") && this.peek().kind === "identifier" && this.position + 2 < this.tokens.length) {
            const save = this.position;
            this.advance();
            const part = this.advance().text;
            if (!(this.current.kind === "identifier" || this.current.is("<") || this.current.is("["))) {
              this.position = save;
              break;
            }
            full += "." + part;
          }
          if (this.current.is("<")) {
            let depth = 0;
            do {
              if (this.current.is("<")) depth += 1;
              if (this.current.is(">")) depth -= 1;
              if (this.current.is(">>")) depth -= 2;
              full += this.current.text;
              this.advance();
            } while (depth > 0 && this.current.kind !== "end");
          }
          type = "?" + full;
        }
      } else {
        return null;
      }
      while (this.current.is("[") && this.peek().is("]")) {
        this.position += 2;
        type += "[]";
      }
      return type;
    }

    /** Sieht nach `Typ Name` aus? Prüft ohne zu verbrauchen. */
    looksLikeDeclaration() {
      const start = this.position;
      try {
        this.accept("final");
        const type = this.attempt(() => this.typeIfPresent(false));
        if (type == null) return false;
        if (type === "var" && this.current.kind !== "identifier") return false;
        if (this.current.kind !== "identifier") return false;
        const next = this.peek();
        return next.is("=") || next.is(";") || next.is(",") || next.is(":") || next.is("[");
      } finally {
        this.position = start;
      }
    }

    // Anweisungen

    blockBody(line) {
      const body = [];
      while (!this.current.is("}")) {
        if (this.current.kind === "end") throw syntax(`Der Block aus Zeile ${line} wird nie mit } geschlossen.`, line);
        body.push(this.statement());
      }
      this.advance();
      return body;
    }

    statement() {
      const token = this.current;
      const line = token.line;
      if (token.kind === "keyword" || token.kind === "symbol") {
        switch (token.text) {
          case "{":
            this.advance();
            return { k: "block", body: this.blockBody(line), line };
          case ";":
            this.advance();
            return { k: "empty", line };
          case "if": {
            this.advance();
            const condition = this.parenthesized("if");
            const then = this.statement();
            const otherwise = this.accept("else") ? this.statement() : null;
            return { k: "if", condition, then, otherwise, line };
          }
          case "while": {
            this.advance();
            const condition = this.parenthesized("while");
            return { k: "while", condition, body: this.statement(), line };
          }
          case "do": {
            this.advance();
            const body = this.statement();
            this.expect("while", "Nach dem do-Block folgt while (…);");
            const condition = this.parenthesized("while");
            this.expect(";");
            return { k: "doWhile", body, condition, line };
          }
          case "for":
            return this.forStatement();
          case "break":
            this.advance();
            if (this.current.kind === "identifier") throw unsupported("break mit Sprungmarke kennt der eingebaute Interpreter nicht.", line);
            this.expect(";");
            return { k: "break", line };
          case "continue":
            this.advance();
            if (this.current.kind === "identifier") throw unsupported("continue mit Sprungmarke kennt der eingebaute Interpreter nicht.", line);
            this.expect(";");
            return { k: "continue", line };
          case "return": {
            this.advance();
            if (this.accept(";")) return { k: "return", value: null, line };
            const value = this.expression();
            this.expect(";");
            return { k: "return", value, line };
          }
          case "yield": {
            this.advance();
            const value = this.expression();
            this.expect(";");
            return { k: "yield", value, line };
          }
          case "switch": {
            this.advance();
            const subject = this.parenthesized("switch");
            const cases = this.switchBody(false);
            return { k: "switch", subject, cases, line };
          }
          case "throw":
            throw unsupported("throw kennt der eingebaute Interpreter nicht.", line);
          case "try": case "catch": case "finally":
            throw unsupported("try/catch kennt der eingebaute Interpreter nicht.", line);
          case "class": case "interface": case "enum": case "record":
            throw unsupported("Typen innerhalb von Methoden kennt der eingebaute Interpreter nicht.", line);
          case "else":
            throw syntax("Zu diesem else gibt es kein passendes if (steht vielleicht ein ; hinter der if-Bedingung?).", line);
          case "case": case "default":
            throw syntax(`„${token.text}“ darf nur innerhalb von switch stehen.`, line);
          case "public": case "private": case "protected": case "static":
            throw syntax(`„${token.text}“ darf nicht innerhalb einer Methode stehen.`, line);
          default:
            break;
        }
      }
      // Kontextuelle Schlüsselwörter (sealed, non-sealed, permits): gültiges Java, das hier nicht unterstützt wird.
      if ((token.kind === "identifier" && ["sealed", "non", "permits"].includes(token.text))
        || (token.kind === "identifier" && ["class", "interface", "enum", "record"].includes(this.peek().text) && this.peek().kind === "keyword")) {
        throw unsupported(`„${token.text} …“-Typen (z. B. sealed interface) kennt der eingebaute Interpreter nicht.`, line);
      }
      if (token.kind === "identifier" && this.peek().is(":") && !this.peek(2).is(":")) {
        throw unsupported("Sprungmarken kennt der eingebaute Interpreter nicht.", line);
      }
      if (this.looksLikeDeclaration()) {
        const isFinal = this.accept("final");
        return this.declarationStatement(isFinal);
      }
      const expr = this.expression();
      this.expect(";");
      this.requireStatementExpression(expr);
      return { k: "expr", expr, line };
    }

    /** Java erlaubt als Anweisung nur Zuweisungen, ++/-- und Methodenaufrufe. */
    requireStatementExpression(expr) {
      if (["assign", "increment", "call", "switchExpr"].includes(expr.k)) return;
      throw syntax("Das ist keine vollständige Anweisung – der Wert wird berechnet, aber nirgends gespeichert oder ausgegeben.", expr.line);
    }

    declarationStatement(isFinal) {
      const line = this.current.line;
      const type = this.typeIfPresent(false);
      if (type == null) throw syntax("Hier wird ein Typ erwartet, z. B. int oder String.", line);
      if (isUnknown(baseOf(type))) throw unsupported(`Den Typ ${typeText(baseOf(type))} kennt der eingebaute Interpreter nicht.`, line);
      const declarators = [];
      do {
        const declLine = this.current.line;
        const name = this.identifier("die Variable");
        let extra = 0;
        while (this.accept("[")) { this.expect("]"); extra += 1; }
        let initializer = null;
        if (this.accept("=")) {
          if (this.current.is("{")) initializer = this.arrayInitializer(this.elementType(type, extra));
          else initializer = this.expression();
        } else if (type === "var") {
          throw syntax("Mit var braucht die Variable sofort einen Wert, z. B. var x = 5;", declLine);
        }
        declarators.push({ name, extraDimensions: extra, initializer, line: declLine });
      } while (this.accept(","));
      this.expect(";");
      return { k: "varDecl", type, declarators, isFinal, line };
    }

    elementType(type, extra) {
      const full = type + "[]".repeat(extra);
      return isArrayType(full) ? elementOf(full) : null;
    }

    arrayInitializer(element) {
      const line = this.current.line;
      this.expect("{");
      const items = [];
      const inner = element != null && isArrayType(element) ? elementOf(element) : null;
      while (!this.current.is("}")) {
        items.push(this.current.is("{") ? this.arrayInitializer(inner) : this.expression());
        if (!this.accept(",")) break;
      }
      this.expect("}", "Die Werteliste wird mit } geschlossen.");
      return { k: "arrayLiteral", element, items, line };
    }

    parenthesized(keyword) {
      this.expect("(", `Nach ${keyword} folgt die Bedingung in runden Klammern.`);
      const expr = this.expression();
      this.expect(")", `Die Bedingung von ${keyword} wird mit ) geschlossen.`);
      return expr;
    }

    forStatement() {
      const line = this.current.line;
      this.expect("for");
      this.expect("(", "Nach for folgen runde Klammern.");
      // for-each: for (int z : zahlen)
      const start = this.position;
      this.accept("final");
      const type = this.attempt(() => this.typeIfPresent(false));
      if (type != null && this.current.kind === "identifier" && this.peek().is(":")) {
        const name = this.advance().text;
        this.expect(":");
        const collection = this.expression();
        this.expect(")");
        return { k: "forEach", type, name, collection, body: this.statement(), line };
      }
      this.position = start;

      const initializers = [];
      if (!this.current.is(";")) {
        if (this.looksLikeDeclaration()) {
          const isFinal = this.accept("final");
          initializers.push(this.declarationStatement(isFinal));
          this.position -= 1; // declarationStatement hat das ; gelesen – unten erneut erwartet.
        } else {
          do {
            const expr = this.expression();
            initializers.push({ k: "expr", expr, line: expr.line });
          } while (this.accept(","));
        }
      }
      this.expect(";");
      const condition = this.current.is(";") ? null : this.expression();
      this.expect(";");
      const updates = [];
      if (!this.current.is(")")) {
        do { updates.push(this.expression()); } while (this.accept(","));
      }
      this.expect(")", "Der Kopf der for-Schleife wird mit ) geschlossen.");
      return { k: "for", init: initializers, condition, update: updates, body: this.statement(), line };
    }

    switchBody(isExpression) {
      const open = this.current.line;
      this.expect("{", "Der switch-Block beginnt mit {.");
      const cases = [];
      while (!this.current.is("}")) {
        if (this.current.kind === "end") throw syntax("Der switch-Block wird nicht mit } geschlossen.", open);
        const line = this.current.line;
        const labels = [];
        let isDefault = false;
        if (this.accept("default")) {
          isDefault = true;
        } else {
          this.expect("case", "Im switch-Block stehen case- und default-Zweige.");
          do {
            if (this.accept("default")) { isDefault = true; continue; }
            labels.push(this.ternary());
          } while (this.accept(","));
        }
        if (this.accept("->")) {
          if (this.current.is("{")) {
            const blockLine = this.advance().line;
            cases.push({ labels, isDefault, isArrow: true, body: this.blockBody(blockLine), value: null, line });
          } else if (this.current.is("throw")) {
            throw unsupported("throw kennt der eingebaute Interpreter nicht.", this.current.line);
          } else {
            const value = this.expression();
            this.expect(";");
            if (isExpression) {
              cases.push({ labels, isDefault, isArrow: true, body: [], value, line });
            } else {
              this.requireStatementExpression(value);
              cases.push({ labels, isDefault, isArrow: true, body: [{ k: "expr", expr: value, line: value.line }], value: null, line });
            }
          }
        } else {
          this.expect(":", "Nach dem case-Wert folgt ein Doppelpunkt (:) oder ein Pfeil (->).");
          const body = [];
          while (!this.current.is("case") && !this.current.is("default") && !this.current.is("}") && this.current.kind !== "end") {
            body.push(this.statement());
          }
          cases.push({ labels, isDefault, isArrow: false, body, value: null, line });
        }
      }
      this.expect("}");
      if (new Set(cases.map((c) => c.isArrow)).size > 1) {
        throw syntax("In einem switch dürfen „case …:“ und „case … ->“ nicht gemischt werden.", open);
      }
      return cases;
    }

    // Ausdrücke

    expression() {
      const target = this.ternary();
      if (this.current.kind === "symbol" && ASSIGNMENT_OPS.has(this.current.text)) {
        const op = this.advance();
        if (!["name", "index", "field"].includes(target.k)) {
          throw syntax(`Links vom „${op.text}“ muss eine Variable stehen.`, op.line);
        }
        const value = this.expression();
        return { k: "assign", op: op.text, target, value, line: op.line };
      }
      if (this.current.is("->")) throw unsupported("Lambdas (->) kennt der eingebaute Interpreter nicht.", this.current.line);
      return target;
    }

    ternary() {
      const condition = this.binary(0);
      if (!this.current.is("?")) return condition;
      const line = this.advance().line;
      const then = this.ternary();
      this.expect(":", "Beim Bedingungsoperator ?: fehlt der Doppelpunkt.");
      const otherwise = this.ternary();
      return { k: "conditional", condition, then, otherwise, line };
    }

    binary(level) {
      if (level >= LEVELS.length) return this.unary();
      let left = this.binary(level + 1);
      while ((this.current.kind === "symbol" || this.current.is("instanceof")) && LEVELS[level].includes(this.current.text)) {
        const op = this.advance();
        if (op.text === "instanceof") {
          const type = this.typeIfPresent(false);
          if (type == null) throw syntax("Nach instanceof folgt ein Typ.", op.line);
          if (this.current.kind === "identifier") {
            throw unsupported("instanceof mit Variable (Pattern Matching) kennt der eingebaute Interpreter nicht.", op.line);
          }
          left = { k: "instanceOf", value: left, type, line: op.line };
          continue;
        }
        const right = this.binary(level + 1);
        left = { k: op.text === "&&" || op.text === "||" ? "logical" : "binary", op: op.text, left, right, line: op.line };
      }
      return left;
    }

    unary() {
      const token = this.current;
      if (token.kind === "symbol") {
        switch (token.text) {
          case "++": case "--":
            this.advance();
            return { k: "increment", op: token.text, prefix: true, target: this.unary(), line: token.line };
          case "-": case "+": case "!": case "~": {
            this.advance();
            const operand = this.unary();
            // -2147483648 ist als Literal erlaubt, obwohl 2147483648 allein zu groß wäre.
            if (token.text === "-" && operand.k === "literal" && operand.value.k === "long" && operand.value.v === 2147483648n && this.wasIntLiteral) {
              return { k: "literal", value: V.int(INT_MIN), line: operand.line };
            }
            return { k: "unary", op: token.text, operand, line: token.line };
          }
          case "(": {
            const cast = this.castIfPresent();
            if (cast) return cast;
            break;
          }
          default:
            break;
        }
      }
      return this.postfix(this.primary());
    }

    get wasIntLiteral() { return this.position > 0 && this.tokens[this.position - 1].kind === "intLiteral"; }

    castIfPresent() {
      const start = this.position;
      const line = this.current.line;
      this.advance(); // (
      const isPrimitive = this.current.kind === "keyword" && PRIMITIVE[this.current.text] != null;
      const isStringCast = this.current.kind === "identifier" && this.current.text === "String" && this.peek().is(")");
      if (["byte", "short", "float"].includes(this.current.text) && this.current.kind === "keyword" && this.peek().is(")")) {
        throw unsupported(`Den Typ ${this.current.text} kennt der eingebaute Interpreter nicht.`, line);
      }
      const type = isPrimitive || isStringCast ? this.typeIfPresent(false) : null;
      if (type == null || !this.accept(")")) {
        this.position = start;
        return null;
      }
      return { k: "cast", type, operand: this.unary(), line };
    }

    postfix(base) {
      let expr = base;
      while (true) {
        const token = this.current;
        if (this.accept(".")) {
          const name = this.identifier("das Feld oder die Methode");
          if (this.current.is("(")) expr = { k: "call", target: expr, name, args: this.arguments(), line: token.line };
          else expr = { k: "field", base: expr, name, line: token.line };
        } else if (this.accept("[")) {
          const index = this.expression();
          this.expect("]", "Der Index wird mit ] geschlossen.");
          expr = { k: "index", base: expr, index, line: token.line };
        } else if (token.is("++") || token.is("--")) {
          this.advance();
          expr = { k: "increment", op: token.text, prefix: false, target: expr, line: token.line };
        } else if (token.is("::")) {
          throw unsupported("Methodenreferenzen (::) kennt der eingebaute Interpreter nicht.", token.line);
        } else {
          return expr;
        }
      }
    }

    arguments() {
      this.expect("(");
      const args = [];
      if (!this.current.is(")")) {
        do { args.push(this.expression()); } while (this.accept(","));
      }
      this.expect(")", "Die Argumentliste wird mit ) geschlossen.");
      return args;
    }

    primary() {
      const token = this.advance();
      const line = token.line;
      switch (token.kind) {
        case "intLiteral": {
          let value;
          try { value = BigInt(token.text); } catch { throw syntax(`Die Zahl ${token.text} ist zu groß.`, line); }
          if (value > LONG_MAX) throw syntax(`Die Zahl ${token.text} ist zu groß.`, line);
          if (value > BigInt(INT_MAX)) {
            if (value === 2147483648n) return { k: "literal", value: V.long(value), line };
            throw syntax(`Die Zahl ${token.text} ist zu groß für int. Für große Zahlen: long mit L am Ende (${token.text}L).`, line);
          }
          return { k: "literal", value: V.int(Number(value) | 0), line };
        }
        case "longLiteral": {
          let value;
          try { value = BigInt(token.text); } catch { value = null; }
          if (value == null || value > LONG_MAX || value < LONG_MIN) throw syntax(`Die Zahl ${token.text} ist zu groß für long.`, line);
          return { k: "literal", value: V.long(value), line };
        }
        case "doubleLiteral": {
          const value = Number(token.text);
          if (token.text === "" || Number.isNaN(value)) throw syntax(`„${token.text}“ ist keine gültige Kommazahl.`, line);
          return { k: "literal", value: V.double(value), line };
        }
        case "stringLiteral":
          return { k: "literal", value: V.string(this.intern(token.text)), line };
        case "charLiteral":
          return { k: "literal", value: V.char(token.text.charCodeAt(0) || 0), line };
        case "identifier":
          if (this.current.is("->")) throw unsupported("Lambdas (->) kennt der eingebaute Interpreter nicht.", line);
          if (this.current.is("(")) return { k: "call", target: null, name: token.text, args: this.arguments(), line };
          return { k: "name", name: token.text, line };
        case "keyword":
          switch (token.text) {
            case "true": return { k: "literal", value: TRUE, line };
            case "false": return { k: "literal", value: FALSE, line };
            case "null": return { k: "literal", value: NULL, line };
            case "new": return this.newExpression(line);
            case "switch": {
              const subject = this.parenthesized("switch");
              return { k: "switchExpr", subject, cases: this.switchBody(true), line };
            }
            case "this": case "super":
              throw unsupported(`„${token.text}“ gibt es nur in Objekten – die kennt der eingebaute Interpreter nicht.`, line);
            case "int": case "long": case "double": case "boolean": case "char":
              if (this.current.is(".") && this.peek().text === "class") {
                throw unsupported("Klassenliterale kennt der eingebaute Interpreter nicht.", line);
              }
              throw syntax(`Hier wird ein Wert erwartet, kein Typ. Für eine neue Variable: ${token.text} name = …;`, line);
            default:
              throw syntax(`„${token.text}“ ist hier fehl am Platz.`, line);
          }
        case "symbol":
          if (token.text === "(") {
            if (this.current.is(")") || (this.current.kind === "identifier" && (this.peek().is(",") || (this.peek().is(")") && this.peek(2).is("->"))))) {
              throw unsupported("Lambdas (->) kennt der eingebaute Interpreter nicht.", line);
            }
            const inner = this.expression();
            this.expect(")", "Hier fehlt eine schließende Klammer ).");
            return inner;
          }
          if (token.text === "{") {
            throw syntax("Eine Werteliste { … } ist nur direkt bei der Deklaration erlaubt – sonst new int[] { … }.", line);
          }
          throw syntax(`„${token.text}“ ist hier fehl am Platz – erwartet wird ein Wert.`, line);
        default:
          throw syntax("Der Code endet mitten in einem Ausdruck.", this.previousLine);
      }
    }

    newExpression(line) {
      let element;
      if (this.current.kind === "keyword" && PRIMITIVE[this.current.text]) {
        element = PRIMITIVE[this.current.text];
        this.advance();
      } else if (this.current.kind === "identifier" && this.current.text === "String") {
        element = "String";
        this.advance();
        if (this.current.is("(")) return { k: "newObject", className: "String", args: this.arguments(), line };
      } else if (this.current.kind === "identifier") {
        throw unsupported(`Objekte mit new ${this.current.text}(…) kennt der eingebaute Interpreter nicht.`, line);
      } else {
        throw syntax("Nach new folgt ein Typ, z. B. new int[5].", line);
      }
      if (!this.current.is("[")) throw unsupported(`Objekte mit new ${element}(…) kennt der eingebaute Interpreter nicht.`, line);
      const sizes = [];
      let extra = 0;
      while (this.current.is("[")) {
        this.advance();
        if (this.accept("]")) {
          extra += 1;
        } else {
          if (extra > 0) throw syntax("Größenangaben müssen vorne stehen: new int[3][].", line);
          sizes.push(this.expression());
          this.expect("]");
        }
      }
      if (sizes.length === 0) {
        const arrayType = element + "[]".repeat(Math.max(extra, 1) - 1);
        if (!this.current.is("{")) throw syntax(`new ${element}[] braucht eine Größe in den Klammern oder eine Werteliste { … }.`, line);
        return this.arrayInitializer(arrayType);
      }
      if (this.current.is("{")) throw syntax("Entweder Größe oder Werteliste – beides zusammen geht nicht.", line);
      return { k: "newArray", element, sizes, extraDimensions: extra, line };
    }
  }

  function parse(source) {
    return new Parser(tokenize(source)).parseProgram();
  }

  // MARK: - Interpreter

  const NORMAL = { f: "normal" };
  const BREAK = { f: "break" };
  const CONTINUE = { f: "continue" };
  const MAX_CALL_DEPTH = 400;
  const MAX_OUTPUT = 60000;

  class Interpreter {
    constructor(program, stepLimit, host) {
      this.program = program;
      this.stepLimit = stepLimit;
      this.host = host || null;
      this.output = "";
      this.steps = 0;
      this.warnings = [];
      this.globals = new Map();
      this.frames = [{ scopes: [new Map()], method: null }];
      this.randomState = 0x9E3779B97F4A7C15n;
    }

    run() {
      try {
        for (const field of this.program.staticFields) this.execute(field, true);
        for (const statement of this.program.statements) {
          const flow = this.execute(statement);
          if (flow.f === "normal") continue;
          if (flow.f === "returned") return null;
          if (flow.f === "break") throw syntax("break steht außerhalb einer Schleife oder eines switch.", statement.line);
          if (flow.f === "continue") throw syntax("continue steht außerhalb einer Schleife.", statement.line);
          throw syntax("yield gibt es nur in switch-Ausdrücken.", statement.line);
        }
        return null;
      } catch (error) {
        if (error instanceof JavaProblem) return error;
        // Der Stapel des Browsers ist kleiner als der der Apple-App: Sehr tiefe Rekursion meldet er so.
        if (error instanceof RangeError) {
          return runtime("StackOverflowError: Eine Methode ruft sich immer wieder selbst auf und hört nie auf. Jede Rekursion braucht einen Abbruchfall.", this.lastLine || null);
        }
        throw error;
      }
    }

    // Variablen

    get frame() { return this.frames[this.frames.length - 1]; }

    tick(line) {
      this.steps += 1;
      this.lastLine = line;
      if (this.steps > this.stepLimit) {
        throw new JavaProblem("stepLimit", `Dein Programm hört nach ${this.stepLimit.toLocaleString("de-DE")} Schritten immer noch nicht auf – vermutlich eine Endlosschleife. Prüfe, ob sich die Bedingung der Schleife irgendwann ändert.`, line);
      }
    }

    declare(name, type, value, isFinal, line, global = false) {
      if (global) {
        if (this.globals.has(name)) throw syntax(`Das Feld „${name}“ gibt es schon.`, line);
        this.globals.set(name, { type, value, isFinal });
        return;
      }
      if (this.frame.scopes.some((scope) => scope.has(name))) {
        throw syntax(`Die Variable „${name}“ gibt es hier schon. Eine Box mit demselben Namen darf es nur einmal geben – zum Ändern einfach ${name} = …; schreiben.`, line);
      }
      this.frame.scopes[this.frame.scopes.length - 1].set(name, { type, value, isFinal });
    }

    lookup(name) {
      const scopes = this.frame.scopes;
      for (let i = scopes.length - 1; i >= 0; i -= 1) {
        const slot = scopes[i].get(name);
        if (slot) return slot;
      }
      return this.globals.get(name) || null;
    }

    read(name, line) {
      const slot = this.lookup(name);
      if (!slot) throw this.unknownName(name, line);
      if (slot.value === undefined) {
        throw syntax(`Die Variable „${name}“ hat noch keinen Wert. Gib ihr zuerst einen, z. B. ${name} = 0;`, line);
      }
      return slot.value;
    }

    write(name, value, line) {
      const scopes = this.frame.scopes;
      for (let i = scopes.length - 1; i >= 0; i -= 1) {
        const slot = scopes[i].get(name);
        if (slot) {
          if (slot.isFinal && slot.value !== undefined) {
            throw syntax(`„${name}“ ist final – der Wert darf nach dem ersten Festlegen nicht mehr geändert werden.`, line);
          }
          slot.value = this.coerce(value, slot.type, line, `Die Variable „${name}“`);
          return slot.value;
        }
      }
      const slot = this.globals.get(name);
      if (slot) {
        if (slot.isFinal && slot.value !== undefined) throw syntax(`„${name}“ ist final – der Wert darf nicht mehr geändert werden.`, line);
        slot.value = this.coerce(value, slot.type, line, `Das Feld „${name}“`);
        return slot.value;
      }
      throw this.unknownName(name, line);
    }

    unknownName(name, line) {
      if (this.host && this.host.objectNames.has(name)) {
        return syntax(`„${name}“ ist ein Objekt – rufe eine seiner Methoden auf, z. B. ${name}.move();`, line);
      }
      const similar = this.similarName(name);
      if (similar) return syntax(`„${name}“ kennt Java hier nicht. Meintest du „${similar}“? Achte auf Groß- und Kleinschreibung.`, line);
      return syntax(`„${name}“ kennt Java hier nicht. Ist die Variable deklariert (z. B. int ${name} = 0;) und richtig geschrieben?`, line);
    }

    similarName(name) {
      const known = [
        ...this.frame.scopes.flatMap((scope) => [...scope.keys()]),
        ...this.globals.keys(),
        ...(this.host ? this.host.objectNames : []),
      ];
      return known.find((k) => k.toLowerCase() === name.toLowerCase() && k !== name) || null;
    }

    /** Sichtbare Variablen – für die Anzeige in der Arena. */
    visibleVariables() {
      const merged = new Map(this.globals);
      const order = [...this.globals.keys()].sort();
      for (const scope of this.frame.scopes) {
        for (const name of [...scope.keys()].sort()) {
          if (!merged.has(name)) order.push(name);
          merged.set(name, scope.get(name));
        }
      }
      const result = [];
      for (const name of order) {
        const slot = merged.get(name);
        if (!slot || slot.value === undefined) continue;
        const type = slot.type === "var" ? valueType(slot.value) : slot.type;
        result.push({ name, type: typeText(type), value: debugDisplay(slot.value) });
      }
      return result;
    }

    warn(message, line) {
      if (!this.warnings.some((w) => w.message === message && w.line === line)) this.warnings.push({ message, line });
    }

    // Anweisungen

    executeBlock(statements) {
      this.frame.scopes.push(new Map());
      try {
        for (const statement of statements) {
          const flow = this.execute(statement);
          if (flow.f !== "normal") return flow;
        }
        return NORMAL;
      } finally {
        this.frame.scopes.pop();
      }
    }

    /** Ein einzelner Schleifen-/if-Körper ohne Klammern bekommt trotzdem einen eigenen Bereich. */
    executeBody(statement) {
      if (statement.k === "block") return this.executeBlock(statement.body);
      if (statement.k === "varDecl") {
        throw syntax("Eine Variablen-Deklaration braucht hier geschweifte Klammern { … } drumherum.", statement.line);
      }
      return this.execute(statement);
    }

    loopFlow(flow) {
      // null: weiter mit der nächsten Runde
      if (flow.f === "break") return NORMAL;
      if (flow.f === "returned" || flow.f === "yielded") return flow;
      return null;
    }

    execute(statement, global = false) {
      this.tick(statement.line);
      switch (statement.k) {
        case "varDecl":
          for (const declarator of statement.declarators) {
            let declared = statement.type + "[]".repeat(declarator.extraDimensions);
            let value;
            if (declarator.initializer) {
              const raw = this.evaluate(declarator.initializer, declared);
              if (declared === "var") {
                if (raw.k === "null") throw syntax("Mit var kann Java aus null keinen Typ ableiten.", declarator.line);
                if (raw.k === "void") throw syntax("Die Methode gibt nichts zurück (void) – das kann man nicht speichern.", declarator.line);
                declared = valueType(raw);
              }
              value = this.coerce(raw, declared, declarator.line, `Die Variable „${declarator.name}“`);
            } else if (global) {
              value = defaultValue(declared);
            }
            this.declare(declarator.name, declared, value, statement.isFinal, declarator.line, global);
          }
          return NORMAL;

        case "expr":
          this.evaluate(statement.expr);
          return NORMAL;

        case "block":
          return this.executeBlock(statement.body);

        case "if":
          if (this.test(statement.condition, "if")) return this.executeBody(statement.then);
          if (statement.otherwise) return this.executeBody(statement.otherwise);
          return NORMAL;

        case "while":
          while (this.test(statement.condition, "while")) {
            const result = this.loopFlow(this.executeBody(statement.body));
            if (result) return result;
            this.tick(statement.line);
          }
          return NORMAL;

        case "doWhile":
          do {
            const result = this.loopFlow(this.executeBody(statement.body));
            if (result) return result;
            this.tick(statement.line);
          } while (this.test(statement.condition, "while"));
          return NORMAL;

        case "for":
          this.frame.scopes.push(new Map());
          try {
            for (const initializer of statement.init) this.execute(initializer);
            while (statement.condition == null || this.test(statement.condition, "for")) {
              const result = this.loopFlow(this.executeBody(statement.body));
              if (result) return result;
              for (const update of statement.update) this.evaluate(update);
              this.tick(statement.line);
            }
            return NORMAL;
          } finally {
            this.frame.scopes.pop();
          }

        case "forEach": {
          const line = statement.line;
          const source = this.evaluate(statement.collection);
          if (source.k !== "array") {
            if (source.k === "string") throw syntax("Über einen String kann for-each nicht direkt laufen – nimm text.toCharArray().", line);
            if (source.k === "null") throw runtime("NullPointerException: Das Array ist null.", line);
            throw syntax(`for-each braucht ein Array, bekommt aber ${typeName(source)}.`, line);
          }
          const array = source.a;
          for (let index = 0; index < array.elements.length; index += 1) {
            const element = array.elements[index];
            this.frame.scopes.push(new Map());
            let flow;
            try {
              const declared = statement.type === "var" ? array.elementType : statement.type;
              const value = this.coerce(element, declared, line, `Die Schleifenvariable „${statement.name}“`);
              this.declare(statement.name, declared, value, false, line);
              flow = this.executeBody(statement.body);
            } finally {
              this.frame.scopes.pop();
            }
            const result = this.loopFlow(flow);
            if (result) return result;
            this.tick(line);
          }
          return NORMAL;
        }

        case "break": return BREAK;
        case "continue": return CONTINUE;

        case "return": {
          const method = this.frame.method;
          const line = statement.line;
          if (!method) {
            // return im main-Block beendet das Programm.
            if (statement.value) throw syntax("main gibt nichts zurück – return steht hier ohne Wert.", line);
            return { f: "returned", v: VOID };
          }
          if (!statement.value) {
            if (method.returnType !== "void") {
              throw syntax(`Die Methode ${method.name} muss einen Wert vom Typ ${typeText(method.returnType)} zurückgeben: return …;`, line);
            }
            return { f: "returned", v: VOID };
          }
          if (method.returnType === "void") {
            throw syntax(`${method.name} ist void und gibt nichts zurück – hinter return darf hier kein Wert stehen.`, line);
          }
          const value = this.evaluate(statement.value, method.returnType);
          return { f: "returned", v: this.coerce(value, method.returnType, line, `Der Rückgabewert von ${method.name}`) };
        }

        case "yield":
          return { f: "yielded", v: this.evaluate(statement.value) };

        case "switch": {
          const value = this.evaluate(statement.subject);
          const start = this.matchingCase(value, statement.cases, statement.line);
          if (start == null) return NORMAL;
          const cases = statement.cases;
          this.frame.scopes.push(new Map());
          try {
            if (cases[start].isArrow) {
              const flow = this.executeBlock(cases[start].body);
              return flow.f === "break" ? NORMAL : flow;
            }
            for (let index = start; index < cases.length; index += 1) {
              for (const inner of cases[index].body) {
                const flow = this.execute(inner);
                if (flow.f === "normal") continue;
                if (flow.f === "break") return NORMAL;
                return flow;
              }
            }
            return NORMAL;
          } finally {
            this.frame.scopes.pop();
          }
        }

        case "empty":
          return NORMAL;

        default:
          throw unsupported("throw kennt der eingebaute Interpreter nicht.", statement.line);
      }
    }

    test(expr, keyword) {
      const value = this.evaluate(expr);
      if (value.k !== "boolean") {
        if (expr.k === "assign" && expr.op === "=") {
          throw syntax("In der Bedingung steht = (Zuweisung). Zum Vergleichen braucht man ==.", expr.line);
        }
        throw syntax(`Die Bedingung von ${keyword} muss true oder false ergeben, nicht ${typeName(value)}.`, expr.line);
      }
      return value.v;
    }

    matchingCase(value, cases, line) {
      if (value.k === "null") throw runtime("NullPointerException: switch über null.", line);
      let defaultIndex = null;
      for (let index = 0; index < cases.length; index += 1) {
        const switchCase = cases[index];
        if (switchCase.isDefault) defaultIndex = index;
        for (const label of switchCase.labels) {
          const candidate = this.evaluate(label);
          if (this.valuesEqual(value, candidate, label.line)) return index;
        }
      }
      return defaultIndex;
    }

    valuesEqual(lhs, rhs, line) {
      const a = numeric(lhs), b = numeric(rhs);
      if (a && b) return N.compare(a, b) === 0;
      if (lhs.k === "string" && rhs.k === "string") return lhs.o.text === rhs.o.text;
      if (lhs.k === "boolean" && rhs.k === "boolean") return lhs.v === rhs.v;
      throw syntax(`Der case-Wert (${typeName(rhs)}) passt nicht zum Typ im switch (${typeName(lhs)}).`, line);
    }

    // Ausdrücke

    evaluate(expr, expected = null) {
      switch (expr.k) {
        case "literal":
          return expr.value;

        case "name":
          return this.read(expr.name, expr.line);

        case "unary":
          return this.unary(expr.op, this.evaluate(expr.operand), expr.line);

        case "increment": {
          const old = this.evaluate(expr.target);
          const number = numeric(old);
          if (!number) throw syntax(`${expr.op} funktioniert nur mit Zahlen, nicht mit ${typeName(old)}.`, expr.line);
          const changed = N.apply(expr.op === "++" ? "+" : "-", number, { t: "int", v: 1 });
          const updated = this.cast(N.value(changed), valueType(old), expr.line);
          this.store(updated, expr.target, expr.line);
          return expr.prefix ? updated : old;
        }

        case "binary":
          return this.binary(expr.op, this.evaluate(expr.left), this.evaluate(expr.right), expr.line);

        case "logical": {
          const left = this.evaluate(expr.left);
          if (left.k !== "boolean") throw syntax(`${expr.op} verknüpft nur true/false-Werte, links steht aber ${typeName(left)}.`, expr.line);
          if (expr.op === "&&" && !left.v) return FALSE;
          if (expr.op === "||" && left.v) return TRUE;
          const right = this.evaluate(expr.right);
          if (right.k !== "boolean") throw syntax(`${expr.op} verknüpft nur true/false-Werte, rechts steht aber ${typeName(right)}.`, expr.line);
          return right;
        }

        case "assign": {
          const line = expr.line;
          if (expr.op === "=") {
            const targetType = this.storageType(expr.target, line);
            const value = this.evaluate(expr.value, targetType);
            if (value.k === "void") throw syntax("Die Methode gibt nichts zurück (void) – das kann man nicht speichern.", line);
            return this.store(value, expr.target, line);
          }
          const old = this.evaluate(expr.target);
          const operand = this.evaluate(expr.value);
          const combined = this.binary(expr.op.slice(0, -1), old, operand, line);
          // Zusammengesetzte Zuweisungen enthalten in Java einen versteckten Cast: int x += 1.5 ist erlaubt.
          const result = this.cast(combined, valueType(old), line);
          this.store(result, expr.target, line);
          return result;
        }

        case "conditional": {
          const test = this.evaluate(expr.condition);
          if (test.k !== "boolean") throw syntax("Vor dem ? muss eine Bedingung stehen (true/false).", expr.line);
          return this.evaluate(test.v ? expr.then : expr.otherwise, expected);
        }

        case "cast":
          return this.cast(this.evaluate(expr.operand), expr.type, expr.line);

        case "index": {
          const container = this.evaluate(expr.base);
          const index = this.evaluate(expr.index);
          const [array, position] = this.arrayAccess(container, index, expr.line);
          return array.elements[position];
        }

        case "field":
          return this.field(expr.base, expr.name, expr.line);

        case "call":
          return this.call(expr.target, expr.name, expr.args, expr.line);

        case "newArray": {
          const line = expr.line;
          const counts = expr.sizes.map((size) => {
            const value = this.evaluate(size);
            const number = numeric(value);
            if (!number || number.t !== "int") throw syntax("Die Größe eines Arrays muss eine ganze Zahl (int) sein.", line);
            if (number.v < 0) throw runtime(`NegativeArraySizeException: Ein Array kann nicht ${number.v} Plätze haben.`, line);
            return number.v;
          });
          return this.makeArray(counts, expr.element + "[]".repeat(expr.extraDimensions));
        }

        case "arrayLiteral": {
          let elementType = expr.element;
          if (elementType == null && expected != null && isArrayType(expected)) elementType = elementOf(expected);
          if (elementType == null) throw syntax("Bei einer Werteliste { … } muss klar sein, welcher Array-Typ entsteht.", expr.line);
          const values = expr.items.map((item) => this.coerce(this.evaluate(item, elementType), elementType, item.line, "Ein Element des Arrays"));
          return V.array(new JavaArray(elementType, values));
        }

        case "switchExpr": {
          const line = expr.line;
          const value = this.evaluate(expr.subject);
          const start = this.matchingCase(value, expr.cases, line);
          if (start == null) throw syntax("Der switch-Ausdruck braucht einen default-Zweig, damit immer ein Wert herauskommt.", line);
          this.frame.scopes.push(new Map());
          try {
            for (let index = start; index < expr.cases.length; index += 1) {
              const switchCase = expr.cases[index];
              if (switchCase.value) return this.evaluate(switchCase.value, expected);
              for (const statement of switchCase.body) {
                const flow = this.execute(statement);
                if (flow.f === "normal") continue;
                if (flow.f === "yielded") return flow.v;
                if (flow.f === "break") throw syntax("In einem switch-Ausdruck verlässt man einen Zweig mit yield, nicht mit break.", statement.line);
                throw syntax("Ein Zweig des switch-Ausdrucks muss mit yield einen Wert liefern.", switchCase.line);
              }
              if (switchCase.isArrow) throw syntax("Ein Zweig des switch-Ausdrucks muss mit yield einen Wert liefern.", switchCase.line);
            }
            throw syntax("Der switch-Ausdruck liefert keinen Wert (yield fehlt).", line);
          } finally {
            this.frame.scopes.pop();
          }
        }

        case "newObject": {
          const line = expr.line;
          if (expr.className !== "String") throw unsupported(`Objekte mit new ${expr.className}(…) kennt der eingebaute Interpreter nicht.`, line);
          const args = this.evaluateArgs(expr.args);
          if (args.length === 0) return V.str("");
          if (args.length === 1) {
            if (args[0].k === "array" && args[0].a.elementType === "char") return V.str(args[0].a.elements.map(javaString).join(""));
            if (args[0].k !== "string") throw syntax("new String(…) erwartet einen Text.", line);
            // Absichtlich ein neues Objekt – genau deshalb ist new String("a") == "a" in Java false.
            return V.str(args[0].o.text);
          }
          throw unsupported("new String mit mehreren Werten kennt der eingebaute Interpreter nicht.", line);
        }

        case "instanceOf": {
          const evaluated = this.evaluate(expr.value);
          if (evaluated.k === "string" && expr.type === "String") return TRUE;
          if (evaluated.k === "null") return FALSE;
          if (expr.type === "?Object") return TRUE;
          throw unsupported(`instanceof mit ${typeText(expr.type)} kennt der eingebaute Interpreter nicht.`, expr.line);
        }

        default:
          throw syntax("Unbekannter Ausdruck.", expr.line);
      }
    }

    makeArray(counts, leaf) {
      if (counts.length === 0) return defaultValue(leaf);
      const elementType = leaf + "[]".repeat(counts.length - 1);
      const rest = counts.slice(1);
      const elements = [];
      for (let i = 0; i < counts[0]; i += 1) elements.push(rest.length === 0 ? defaultValue(leaf) : this.makeArray(rest, leaf));
      return V.array(new JavaArray(elementType, elements));
    }

    storageType(target, line) {
      if (target.k === "name") {
        const slot = this.lookup(target.name);
        if (!slot) throw this.unknownName(target.name, line);
        return slot.type;
      }
      if (target.k === "index") {
        const base = this.evaluate(target.base);
        return base.k === "array" ? base.a.elementType : null;
      }
      return null;
    }

    /** Speichert den Wert und liefert ihn so zurück, wie er abgelegt wurde (z. B. int → double). */
    store(value, target, line) {
      switch (target.k) {
        case "name":
          return this.write(target.name, value, line);
        case "index": {
          const container = this.evaluate(target.base);
          const index = this.evaluate(target.index);
          const [array, position] = this.arrayAccess(container, index, line);
          const stored = this.coerce(value, array.elementType, line, "Ein Platz im Array");
          array.elements[position] = stored;
          return stored;
        }
        case "field":
          if (target.name === "length") throw syntax("length eines Arrays kann man nicht ändern – die Größe steht beim Erzeugen fest.", line);
          throw syntax(`„${target.name}“ kann man nicht verändern.`, line);
        default:
          throw syntax("Links vom = muss eine Variable stehen.", line);
      }
    }

    arrayAccess(container, index, line) {
      if (container.k !== "array") {
        if (container.k === "string") throw syntax("Bei Strings holt man ein Zeichen mit charAt(i), nicht mit [i].", line);
        if (container.k === "null") throw runtime("NullPointerException: Das Array ist null.", line);
        throw syntax(`[ ] gibt es nur bei Arrays, nicht bei ${typeName(container)}.`, line);
      }
      const number = numeric(index);
      if (!number || number.t !== "int") throw syntax("Der Index in [ ] muss eine ganze Zahl (int) sein.", line);
      const array = container.a;
      const position = number.v;
      if (position < 0 || position >= array.elements.length) {
        const range = array.elements.length === 0 ? "das Array ist leer" : `erlaubt sind nur 0 bis ${array.elements.length - 1}`;
        throw runtime(`ArrayIndexOutOfBoundsException: Index ${position} gibt es nicht – ${range}. Denk dran: Gezählt wird ab 0.`, line);
      }
      return [array, position];
    }

    // Operatoren

    unary(op, value, line) {
      switch (op) {
        case "!":
          if (value.k !== "boolean") throw syntax("! (nicht) funktioniert nur mit true/false.", line);
          return V.boolean(!value.v);
        case "-": case "+": {
          const number = numeric(value);
          if (!number) throw syntax(`${op} funktioniert nur mit Zahlen.`, line);
          if (op === "+") return N.value(number);
          if (number.t === "int") return V.int((0 - number.v) | 0);
          if (number.t === "long") return V.long(asLong(-number.v));
          return V.double(-number.v);
        }
        case "~": {
          const number = numeric(value);
          if (!number || number.t === "double") throw syntax("~ funktioniert nur mit ganzen Zahlen.", line);
          if (number.t === "int") return V.int(~number.v);
          return V.long(asLong(~number.v));
        }
        default:
          throw syntax(`Unbekannter Operator ${op}.`, line);
      }
    }

    binary(op, lhs, rhs, line) {
      if (lhs.k === "void") throw syntax(`Links von ${op} steht ein Methodenaufruf, der nichts zurückgibt (void).`, line);
      if (rhs.k === "void") throw syntax(`Rechts von ${op} steht ein Methodenaufruf, der nichts zurückgibt (void).`, line);

      if (op === "+" && (lhs.k === "string" || rhs.k === "string")) return V.str(javaString(lhs) + javaString(rhs));

      if (op === "==" || op === "!=") {
        let equal;
        const a = numeric(lhs), b = numeric(rhs);
        if (a && b) {
          equal = N.compare(a, b) === 0;
        } else if (lhs.k === "boolean" && rhs.k === "boolean") {
          equal = lhs.v === rhs.v;
        } else if (lhs.k === "string" && rhs.k === "string") {
          // Wie in Java: == prüft, ob beide auf dasselbe String-Objekt zeigen.
          equal = lhs.o === rhs.o;
          this.warn(`Strings vergleicht man mit equals(), nicht mit ${op}. == prüft nur, ob beide Variablen auf dasselbe Objekt zeigen – nicht, ob der Text gleich ist.`, line);
        } else if (lhs.k === "null" && rhs.k === "null") {
          equal = true;
        } else if ((lhs.k === "null" && (rhs.k === "string" || rhs.k === "array")) || (rhs.k === "null" && (lhs.k === "string" || lhs.k === "array"))) {
          equal = false;
        } else if (lhs.k === "array" && rhs.k === "array") {
          equal = lhs.a === rhs.a;
        } else {
          throw syntax(`${typeName(lhs)} und ${typeName(rhs)} kann man nicht mit ${op} vergleichen.`, line);
        }
        return V.boolean(op === "==" ? equal : !equal);
      }
      if ((op === "&" || op === "|" || op === "^") && lhs.k === "boolean" && rhs.k === "boolean") {
        if (op === "&") return V.boolean(lhs.v && rhs.v);
        if (op === "|") return V.boolean(lhs.v || rhs.v);
        return V.boolean(lhs.v !== rhs.v);
      }

      const a = numeric(lhs), b = numeric(rhs);
      if (!a || !b) {
        const offender = a ? rhs : lhs;
        if (offender.k === "boolean") throw syntax(`Mit ${op} kann man nicht mit true/false rechnen.`, line);
        if (offender.k === "string") throw syntax(`Mit ${op} kann man nicht mit Text (String) rechnen. Nur + hängt Texte aneinander.`, line);
        if (offender.k === "null") throw runtime("NullPointerException: Mit null kann man nicht rechnen.", line);
        throw syntax(`${op} passt nicht zu ${typeName(lhs)} und ${typeName(rhs)}.`, line);
      }

      switch (op) {
        case "<": case ">": case "<=": case ">=": {
          if (N.isNaN(a) || N.isNaN(b)) return FALSE;
          const order = N.compare(a, b);
          if (op === "<") return V.boolean(order === -1);
          if (op === ">") return V.boolean(order === 1);
          if (op === "<=") return V.boolean(order !== 1);
          return V.boolean(order !== -1);
        }
        case "/": case "%": {
          const [x, y] = N.promote(a, b);
          if (N.isZeroIntegral(y)) throw runtime("ArithmeticException: / by zero – durch 0 teilen geht bei ganzen Zahlen nicht.", line);
          return N.value(N.apply(op, x, y));
        }
        case "+": case "-": case "*":
          return N.value(N.apply(op, a, b));
        case "&": case "|": case "^": case "<<": case ">>": case ">>>":
          if (a.t === "double" || b.t === "double") throw syntax(`${op} funktioniert nur mit ganzen Zahlen.`, line);
          return N.value(N.bitwise(op, a, b));
        default:
          throw syntax(`Unbekannter Operator ${op}.`, line);
      }
    }

    // Typen

    /** Implizite Umwandlung wie bei Zuweisung und Methodenaufruf: nur verlustfreie Verbreiterung. */
    coerce(value, type, line, what) {
      const mismatch = () => {
        let message = `Typen passen nicht: ${what} erwartet ${typeText(type)}, bekommt aber ${typeName(value)}.`;
        const pair = `${value.k}>${type}`;
        if (["double>int", "double>long", "long>int"].includes(pair)) {
          message += ` Das ginge nur mit Verlust. Wenn du die Nachkommastellen bewusst abschneiden willst: (${type}) davor schreiben.`;
        } else if (["string>int", "string>double", "string>long"].includes(pair)) {
          message += " Ein Text ist keine Zahl – umwandeln geht mit Integer.parseInt(text) bzw. Double.parseDouble(text).";
        } else if (["int>String", "double>String", "long>String", "boolean>String", "char>String"].includes(pair)) {
          message += " Eine Zahl ist kein Text – umwandeln geht mit String.valueOf(wert) oder \"\" + wert.";
        } else if (pair === "string>char") {
          message += " Ein einzelnes Zeichen (char) steht in einfachen Anführungszeichen: 'a'.";
        } else if (value.k === "void") {
          message = `Die Methode gibt nichts zurück (void) – ${what} bekommt deshalb keinen Wert.`;
        }
        return syntax(message, line);
      };

      switch (type) {
        case "var": return value;
        case "int":
          if (value.k === "int") return value;
          if (value.k === "char") return V.int(value.v);
          throw mismatch();
        case "long":
          if (value.k === "long") return value;
          if (value.k === "int" || value.k === "char") return V.long(BigInt(value.v));
          throw mismatch();
        case "double":
          if (value.k === "double") return value;
          if (value.k === "int" || value.k === "char") return V.double(value.v);
          if (value.k === "long") return V.double(Number(value.v));
          throw mismatch();
        case "boolean":
          if (value.k === "boolean") return value;
          throw mismatch();
        case "char":
          if (value.k === "char") return value;
          // Ganzzahl-Konstanten im char-Bereich darf man direkt zuweisen (char c = 65;).
          if (value.k === "int" && value.v >= 0 && value.v <= 65535) return V.char(value.v);
          throw mismatch();
        case "String":
          if (value.k === "string" || value.k === "null") return value;
          throw mismatch();
        case "void":
          throw syntax("Eine Variable kann nicht den Typ void haben.", line);
        default:
          if (isArrayType(type)) {
            if (value.k === "null") return value;
            if (value.k === "array" && value.a.elementType === elementOf(type)) return value;
            throw mismatch();
          }
          throw unsupported(`Den Typ ${typeText(type)} kennt der eingebaute Interpreter nicht.`, line);
      }
    }

    /** Expliziter Cast (int) x – mit Javas Regeln für Abschneiden und Überlauf. */
    cast(value, type, line) {
      if (type === "String") {
        if (value.k === "string" || value.k === "null") return value;
        throw syntax(`${typeName(value)} kann man nicht in String casten – nimm String.valueOf(wert).`, line);
      }
      if (type === "boolean") {
        if (value.k === "boolean") return value;
        throw syntax("Zahlen lassen sich nicht in boolean umwandeln.", line);
      }
      const number = numeric(value);
      if (!number) {
        if (value.k === "boolean") throw syntax("true/false lässt sich nicht in eine Zahl umwandeln.", line);
        return this.coerce(value, type, line, "Der Cast");
      }
      switch (type) {
        case "int": return V.int(N.toInt32(number));
        case "long": return V.long(N.toInt64(number));
        case "double": return V.double(N.toDouble(number));
        case "char": return V.char(N.toInt32(number) & 0xffff);
        default: return this.coerce(value, type, line, "Der Cast");
      }
    }

    // Felder

    field(base, name, line) {
      if (base.k === "name" && !this.lookup(base.name)) {
        const className = base.name;
        if (className === "java" || className === "javax") {
          throw unsupported(`Voll qualifizierte Klassen (${className}.${name}…) kennt der eingebaute Interpreter nicht.`, line);
        }
        switch (`${className}.${name}`) {
          case "Math.PI": return V.double(Math.PI);
          case "Math.E": return V.double(Math.E);
          case "Integer.MAX_VALUE": return V.int(INT_MAX);
          case "Integer.MIN_VALUE": return V.int(INT_MIN);
          case "Long.MAX_VALUE": return V.long(LONG_MAX);
          case "Long.MIN_VALUE": return V.long(LONG_MIN);
          case "Double.MAX_VALUE": return V.double(Number.MAX_VALUE);
          case "Double.MIN_VALUE": return V.double(Number.MIN_VALUE);
          case "Double.POSITIVE_INFINITY": return V.double(Infinity);
          case "Double.NEGATIVE_INFINITY": return V.double(-Infinity);
          case "Double.NaN": return V.double(NaN);
          case "System.out":
            throw syntax("System.out allein macht nichts – zum Ausgeben: System.out.println(…);", line);
          default:
            if (this.host && this.host.objectNames.has(className)) {
              throw syntax(`${className}.${name} braucht runde Klammern: ${className}.${name}();`, line);
            }
            if (/^\p{Lu}/u.test(className)) throw unsupported(`${className}.${name} kennt der eingebaute Interpreter nicht.`, line);
            throw this.unknownName(className, line);
        }
      }
      const value = this.evaluate(base);
      if (value.k === "array" && name === "length") return V.int(value.a.elements.length);
      if (value.k === "string" && name === "length") throw syntax("Bei Strings ist length eine Methode und braucht Klammern: length().", line);
      if (value.k === "null") throw runtime(`NullPointerException: Der Wert ist null – darauf gibt es kein „${name}“.`, line);
      throw syntax(`${typeName(value)} hat kein Feld „${name}“.`, line);
    }

    // Methodenaufrufe

    call(target, name, argExprs, line) {
      if (!target) return this.callUserMethod(name, argExprs, line);
      // System.out.println(…)
      if (target.k === "field" && target.base.k === "name" && target.base.name === "System" && !this.lookup("System")) {
        if (target.name !== "out" && target.name !== "err") {
          throw unsupported(`System.${target.name} kennt der eingebaute Interpreter nicht.`, line);
        }
        return this.printCall(name, this.evaluateArgs(argExprs), line);
      }
      if (target.k === "name" && !this.lookup(target.name)) {
        const objectName = target.name;
        const args = this.evaluateArgs(argExprs);
        if (this.host && this.host.objectNames.has(objectName)) {
          args.forEach((arg, index) => {
            if (arg.k === "void") throw syntax(`Argument ${index + 1} gibt keinen Wert zurück (void).`, line);
          });
          const context = this.host.wantsSnapshot
            ? { line, variables: this.visibleVariables(), output: this.output }
            : { line, variables: [], output: "" };
          return this.host.call(objectName, name, args, context);
        }
        return callStatic(objectName, name, args, line, this);
      }
      const receiver = this.evaluate(target);
      return callInstance(receiver, name, this.evaluateArgs(argExprs), line, this);
    }

    evaluateArgs(exprs) { return exprs.map((expr) => this.evaluate(expr)); }

    printCall(name, args, line) {
      switch (name) {
        case "println":
          if (args.length > 1) throw syntax("println nimmt höchstens einen Wert – verbinde mehrere mit +.", line);
          if (args.length === 1) this.emit(this.printable(args[0], line), line);
          this.emit("\n", line);
          break;
        case "print":
          if (args.length !== 1) throw syntax("print braucht genau einen Wert in den Klammern.", line);
          this.emit(this.printable(args[0], line), line);
          break;
        case "printf": case "format":
          if (!args[0] || args[0].k !== "string") {
            throw syntax("printf braucht als Erstes einen Format-Text, z. B. printf(\"%d%n\", zahl).", line);
          }
          this.emit(format(args[0].o.text, args.slice(1), line), line);
          break;
        default:
          throw syntax(`System.out.${name} gibt es nicht. Meintest du println oder print?`, line);
      }
      return VOID;
    }

    printable(value, line) {
      if (value.k === "void") throw syntax("Diese Methode gibt nichts zurück (void) – es gibt nichts auszugeben.", line);
      if (value.k === "array" && value.a.elementType === "char") return value.a.elements.map(javaString).join("");
      return javaString(value);
    }

    emit(text, line) {
      this.output += text;
      if (this.output.length > MAX_OUTPUT) {
        throw new JavaProblem("stepLimit", "Dein Programm gibt sehr viel aus und wurde gestoppt – vermutlich eine Endlosschleife mit println.", line);
      }
    }

    callUserMethod(name, argExprs, line) {
      const candidates = this.program.methods.get(name);
      if (!candidates) {
        if (name === "println" || name === "print") throw syntax(`${name} allein kennt Java nicht – es heißt System.out.${name}(…).`, line);
        const similar = [...this.program.methods.keys()].find((k) => k.toLowerCase() === name.toLowerCase());
        if (similar) throw syntax(`Die Methode ${name}(…) gibt es nicht. Meintest du ${similar}? Achte auf Groß- und Kleinschreibung.`, line);
        if (this.host && this.host.objectNames.size > 0) {
          const object = [...this.host.objectNames].sort()[0];
          throw syntax(`Die Methode ${name}(…) gibt es nicht. Befehle für den Roboter schreibt man mit Punkt davor: ${object}.${name}();`, line);
        }
        throw syntax(`Die Methode ${name}(…) gibt es nicht. Ist sie geschrieben und richtig benannt?`, line);
      }
      const args = this.evaluateArgs(argExprs);
      const matching = candidates.filter((m) => m.parameters.length === args.length);
      if (matching.length === 0) {
        const counts = candidates.map((m) => String(m.parameters.length)).join(" oder ");
        throw syntax(`${name} erwartet ${counts} Wert(e) in den Klammern, bekommt aber ${args.length}.`, line);
      }
      // Erst exakte Typen, dann erlaubte Verbreiterung (int → double usw.).
      const exact = matching.find((m) => m.parameters.every((p, i) => p.type === valueType(args[i]) || p.type === "var"));
      const widening = matching.find((m) => m.parameters.every((p, i) => {
        try { this.coerce(args[i], p.type, line, ""); return true; } catch (e) { if (e instanceof JavaProblem) return false; throw e; }
      }));
      const method = exact || widening;
      if (!method) {
        // Keine passt: die Meldung der ersten Variante erklärt, welcher Parameter nicht passt.
        const first = matching[0];
        first.parameters.forEach((p, i) => this.coerce(args[i], p.type, line, `Der Parameter „${p.name}“ von ${name}`));
        throw syntax(`Die Werte passen nicht zu den Parametern von ${name}.`, line);
      }
      return this.invoke(method, args, line);
    }

    invoke(method, args, line) {
      if (this.frames.length >= MAX_CALL_DEPTH) {
        throw runtime(`StackOverflowError: ${method.name} ruft sich immer wieder selbst auf und hört nie auf. Jede Rekursion braucht einen Abbruchfall.`, line);
      }
      const frame = { scopes: [new Map()], method };
      method.parameters.forEach((p, i) => {
        const value = this.coerce(args[i], p.type, line, `Der Parameter „${p.name}“ von ${method.name}`);
        frame.scopes[0].set(p.name, { type: p.type, value, isFinal: false });
      });
      this.frames.push(frame);
      try {
        for (const statement of method.body) {
          const flow = this.execute(statement);
          if (flow.f === "normal") continue;
          if (flow.f === "returned") return flow.v;
          if (flow.f === "break") throw syntax("break steht außerhalb einer Schleife.", statement.line);
          if (flow.f === "continue") throw syntax("continue steht außerhalb einer Schleife.", statement.line);
          throw syntax("yield gibt es nur in switch-Ausdrücken.", statement.line);
        }
        if (method.returnType !== "void") {
          throw syntax(`Die Methode ${method.name} endet, ohne einen Wert zurückzugeben. Es fehlt ein return mit einem ${typeText(method.returnType)}-Wert.`, method.line);
        }
        return VOID;
      } finally {
        this.frames.pop();
      }
    }

    /** SplitMix64 – reproduzierbar, damit Programme bei jedem Lauf gleich ablaufen. */
    nextRandom() {
      const mask = (1n << 64n) - 1n;
      this.randomState = (this.randomState + 0x9E3779B97F4A7C15n) & mask;
      let z = this.randomState;
      z = ((z ^ (z >> 30n)) * 0xBF58476D1CE4E5B9n) & mask;
      z = ((z ^ (z >> 27n)) * 0x94D049BB133111EBn) & mask;
      z ^= z >> 31n;
      return Number(z >> 11n) / 2 ** 53;
    }
  }

  // MARK: - Standardbibliothek

  function arity(args, count, name, line) {
    if (args.length !== count) throw syntax(`${name} erwartet ${count} Wert(e) in den Klammern, bekommt aber ${args.length}.`, line);
  }
  function numberArg(value, name, line) {
    const number = numeric(value);
    if (!number) throw syntax(`${name} rechnet nur mit Zahlen, nicht mit ${typeName(value)}.`, line);
    return number;
  }
  const doubleArg = (value, name, line) => N.toDouble(numberArg(value, name, line));
  function intArg(value, name, line) {
    const number = numeric(value);
    if (!number || number.t !== "int") throw syntax(`${name} erwartet hier eine ganze Zahl (int), bekommt aber ${typeName(value)}.`, line);
    return number.v;
  }
  function stringArg(value, name, line) {
    if (value.k === "string") return value.o.text;
    if (value.k === "null") throw runtime(`NullPointerException: ${name} bekommt null statt eines Textes.`, line);
    throw syntax(`${name} erwartet einen Text (String), bekommt aber ${typeName(value)}.`, line);
  }

  function callStatic(className, name, args, line, interpreter) {
    switch (className) {
      case "Math": return math(name, args, line, interpreter);
      case "Integer": case "Long": case "Double": case "Boolean": return wrapper(className, name, args, line);
      case "String": return stringStatic(name, args, line);
      case "Character": return character(name, args, line);
      case "Arrays": return arrays(name, args, line, interpreter);
      case "System": throw unsupported(`System.${name} kennt der eingebaute Interpreter nicht.`, line);
      default:
        if (/^\p{Lu}/u.test(className)) throw unsupported(`Die Klasse ${className} kennt der eingebaute Interpreter nicht.`, line);
        throw syntax(`„${className}“ kennt Java hier nicht. Ist die Variable deklariert und richtig geschrieben?`, line);
    }
  }

  function math(name, args, line, interpreter) {
    const label = `Math.${name}`;
    switch (name) {
      case "random":
        arity(args, 0, label, line);
        return V.double(interpreter.nextRandom());
      case "abs": {
        arity(args, 1, label, line);
        const n = numberArg(args[0], label, line);
        if (n.t === "int") return V.int(n.v === INT_MIN ? n.v : Math.abs(n.v));
        if (n.t === "long") return V.long(n.v === LONG_MIN ? n.v : (n.v < 0n ? -n.v : n.v));
        return V.double(Math.abs(n.v));
      }
      case "max": case "min": {
        arity(args, 2, label, line);
        const [a, b] = N.promote(numberArg(args[0], label, line), numberArg(args[1], label, line));
        if (N.isNaN(a) || N.isNaN(b)) return V.double(NaN);
        const order = N.compare(a, b);
        const pickFirst = name === "max" ? order !== -1 : order !== 1;
        return N.value(pickFirst ? a : b);
      }
      case "pow":
        arity(args, 2, label, line);
        return V.double(Math.pow(doubleArg(args[0], label, line), doubleArg(args[1], label, line)));
      case "round": {
        arity(args, 1, label, line);
        const v = doubleArg(args[0], label, line);
        // Java rundet .5 immer nach oben (auch bei negativen Zahlen: -2.5 → -2).
        return V.long(N.toInt64({ t: "double", v: Math.floor(v + 0.5) }));
      }
      case "floorDiv": case "floorMod": {
        arity(args, 2, label, line);
        const [a, b] = N.promote(numberArg(args[0], label, line), numberArg(args[1], label, line));
        if (a.t === "double") throw syntax(`${label} rechnet nur mit ganzen Zahlen.`, line);
        if (N.isZeroIntegral(b)) throw runtime("ArithmeticException: / by zero", line);
        const x = N.toInt64(a), y = N.toInt64(b);
        let quotient = x / y;
        if (x % y !== 0n && (x < 0n) !== (y < 0n)) quotient -= 1n;
        const result = name === "floorDiv" ? quotient : x - quotient * y;
        if (a.t === "int") return V.int(Number(BigInt.asIntN(32, result)));
        return V.long(asLong(result));
      }
      case "hypot":
        arity(args, 2, label, line);
        return V.double(Math.hypot(doubleArg(args[0], label, line), doubleArg(args[1], label, line)));
      case "signum": {
        arity(args, 1, label, line);
        const v = doubleArg(args[0], label, line);
        return V.double(v > 0 ? 1 : v < 0 ? -1 : v);
      }
      default: {
        const unary = {
          sqrt: Math.sqrt, cbrt: Math.cbrt, floor: Math.floor, ceil: Math.ceil,
          log: Math.log, log10: Math.log10, exp: Math.exp, sin: Math.sin, cos: Math.cos, tan: Math.tan,
          toRadians: (x) => (x * Math.PI) / 180, toDegrees: (x) => (x * 180) / Math.PI,
        }[name];
        if (!unary) throw unsupported(`${label} kennt der eingebaute Interpreter nicht.`, line);
        arity(args, 1, label, line);
        return V.double(unary(doubleArg(args[0], label, line)));
      }
    }
  }

  function wrapper(className, name, args, line) {
    const label = `${className}.${name}`;
    const key = `${className}.${name}`;
    if (key === "Integer.parseInt" || key === "Integer.valueOf") {
      arity(args, 1, label, line);
      if (args[0].k !== "string") {
        if (name !== "valueOf") { stringArg(args[0], label, line); return VOID; }
        return V.int(intArg(args[0], label, line));
      }
      const text = args[0].o.text;
      const value = /^[+-]?[0-9]+$/.test(text) ? BigInt(text) : null;
      if (value == null || value > BigInt(INT_MAX) || value < BigInt(INT_MIN)) {
        throw runtime(`NumberFormatException: For input string: "${text}" – das ist keine ganze Zahl.`, line);
      }
      return V.int(Number(value));
    }
    if (key === "Long.parseLong" || key === "Long.valueOf") {
      arity(args, 1, label, line);
      const text = stringArg(args[0], label, line);
      const value = /^[+-]?[0-9]+$/.test(text) ? BigInt(text) : null;
      if (value == null || value > LONG_MAX || value < LONG_MIN) throw runtime(`NumberFormatException: For input string: "${text}"`, line);
      return V.long(value);
    }
    if (key === "Double.parseDouble" || key === "Double.valueOf") {
      arity(args, 1, label, line);
      const number = numeric(args[0]);
      if (number) return V.double(N.toDouble(number));
      const text = stringArg(args[0], label, line).trim();
      const special = { NaN: NaN, Infinity: Infinity, "+Infinity": Infinity, "-Infinity": -Infinity };
      if (text in special) return V.double(special[text]);
      if (!/^[+-]?([0-9]+\.?[0-9]*|\.[0-9]+)([eE][+-]?[0-9]+)?$/.test(text)) {
        throw runtime(`NumberFormatException: For input string: "${text}" – das ist keine Zahl (Kommazahlen mit Punkt schreiben).`, line);
      }
      return V.double(Number(text));
    }
    if (key === "Boolean.parseBoolean") {
      arity(args, 1, label, line);
      if (args[0].k === "null") return FALSE;
      return V.boolean(stringArg(args[0], label, line).toLowerCase() === "true");
    }
    if (name === "toString") {
      arity(args, 1, label, line);
      return V.str(javaString(args[0]));
    }
    if (key === "Integer.toBinaryString") {
      arity(args, 1, label, line);
      return V.str((intArg(args[0], label, line) >>> 0).toString(2));
    }
    if (key === "Integer.compare" || key === "Double.compare" || key === "Long.compare") {
      arity(args, 2, label, line);
      return V.int(N.compare(numberArg(args[0], label, line), numberArg(args[1], label, line)));
    }
    if (key === "Integer.sum") {
      arity(args, 2, label, line);
      return V.int((intArg(args[0], label, line) + intArg(args[1], label, line)) | 0);
    }
    if (key === "Integer.max" || key === "Integer.min") {
      arity(args, 2, label, line);
      const a = intArg(args[0], label, line), b = intArg(args[1], label, line);
      return V.int(name === "max" ? Math.max(a, b) : Math.min(a, b));
    }
    throw unsupported(`${label} kennt der eingebaute Interpreter nicht.`, line);
  }

  function stringStatic(name, args, line) {
    switch (name) {
      case "valueOf":
        arity(args, 1, "String.valueOf", line);
        if (args[0].k === "array" && args[0].a.elementType === "char") return V.str(args[0].a.elements.map(javaString).join(""));
        return V.str(javaString(args[0]));
      case "format":
        if (!args[0] || args[0].k !== "string") throw syntax("String.format braucht als Erstes einen Format-Text.", line);
        return V.str(format(args[0].o.text, args.slice(1), line));
      case "join": {
        if (args.length < 2) throw syntax("String.join braucht ein Trennzeichen und Texte.", line);
        const separator = stringArg(args[0], "String.join", line);
        const parts = args.length === 2 && args[1].k === "array"
          ? args[1].a.elements.map(javaString)
          : args.slice(1).map((value) => stringArg(value, "String.join", line));
        return V.str(parts.join(separator));
      }
      default:
        throw unsupported(`String.${name} kennt der eingebaute Interpreter nicht.`, line);
    }
  }

  function character(name, args, line) {
    const label = `Character.${name}`;
    arity(args, 1, label, line);
    if (args[0].k !== "char") throw syntax(`${label} erwartet ein Zeichen (char), bekommt aber ${typeName(args[0])}.`, line);
    const code = args[0].v;
    const c = code >= 0xd800 && code <= 0xdfff ? " " : String.fromCharCode(code);
    switch (name) {
      case "isDigit": return V.boolean(/^[0-9]$/.test(c));
      case "isLetter": return V.boolean(/\p{L}/u.test(c));
      case "isLetterOrDigit": return V.boolean(/[\p{L}\p{N}]/u.test(c));
      case "isUpperCase": return V.boolean(/\p{Lu}/u.test(c));
      case "isLowerCase": return V.boolean(/\p{Ll}/u.test(c));
      case "isWhitespace": return V.boolean(/\s/u.test(c));
      case "toUpperCase": return V.char(c.toUpperCase().charCodeAt(0));
      case "toLowerCase": return V.char(c.toLowerCase().charCodeAt(0));
      case "getNumericValue": return V.int(/^[0-9]$/.test(c) ? Number(c) : -1);
      case "toString": case "valueOf": return V.str(c);
      default: throw unsupported(`${label} kennt der eingebaute Interpreter nicht.`, line);
    }
  }

  function arrays(name, args, line, interpreter) {
    const label = `Arrays.${name}`;
    if (!args[0] || args[0].k !== "array") {
      if (args[0] && args[0].k === "null") throw runtime(`NullPointerException: ${label} bekommt null statt eines Arrays.`, line);
      throw syntax(`${label} erwartet ein Array.`, line);
    }
    const array = args[0].a;
    switch (name) {
      case "toString":
        arity(args, 1, label, line);
        return V.str("[" + array.elements.map(javaString).join(", ") + "]");
      case "sort":
        arity(args, 1, label, line);
        if (array.elementType === "String") {
          array.elements.sort((a, b) => compareStrings(javaString(a), javaString(b)));
        } else if (array.elementType === "boolean") {
          throw syntax("Ein boolean-Array kann man nicht sortieren.", line);
        } else {
          array.elements.sort((a, b) => {
            const x = numeric(a), y = numeric(b);
            if (!x || !y) return 0;
            const order = N.compare(x, y);
            return order === -1 ? -1 : N.compare(y, x) === -1 ? 1 : 0;
          });
        }
        return VOID;
      case "fill": {
        arity(args, 2, label, line);
        const value = interpreter.coerce(args[1], array.elementType, line, label);
        array.elements = array.elements.map(() => value);
        return VOID;
      }
      case "copyOf": {
        arity(args, 2, label, line);
        const length = intArg(args[1], label, line);
        if (length < 0) throw runtime(`NegativeArraySizeException: ${length}`, line);
        const copy = array.elements.slice(0, length);
        while (copy.length < length) copy.push(defaultValue(array.elementType));
        return V.array(new JavaArray(array.elementType, copy));
      }
      case "equals": {
        arity(args, 2, label, line);
        if (args[1].k !== "array") return FALSE;
        const a = array.elements.map(javaString), b = args[1].a.elements.map(javaString);
        return V.boolean(a.length === b.length && a.every((x, i) => x === b[i]));
      }
      default:
        throw unsupported(`${label} kennt der eingebaute Interpreter nicht.`, line);
    }
  }

  function callInstance(receiver, name, args, line) {
    switch (receiver.k) {
      case "string":
        return stringMethod(receiver.o.text, name, args, line);
      case "array":
        if (name === "clone") {
          arity(args, 0, "clone", line);
          return V.array(new JavaArray(receiver.a.elementType, [...receiver.a.elements]));
        }
        if (name === "length") throw syntax("Bei Arrays ist length ein Feld ohne Klammern: zahlen.length.", line);
        throw syntax(`Arrays haben keine Methode ${name}(). Für Hilfsfunktionen gibt es Arrays.${name}(…).`, line);
      case "null":
        throw runtime(`NullPointerException: Der Wert ist null – auf null kann man keine Methode ${name}() aufrufen.`, line);
      case "void":
        throw syntax(`Die Methode davor gibt nichts zurück (void) – darauf kann man nicht .${name}() aufrufen.`, line);
      default:
        throw syntax(`${typeName(receiver)} ist ein einfacher Wert und hat keine Methoden wie ${name}().`, line);
    }
  }

  /** String.compareTo: Differenz der ersten verschiedenen Zeichen, sonst der Längen. */
  function compareStrings(a, b) {
    const n = Math.min(a.length, b.length);
    for (let i = 0; i < n; i += 1) {
      if (a.charCodeAt(i) !== b.charCodeAt(i)) return a.charCodeAt(i) - b.charCodeAt(i);
    }
    return a.length - b.length;
  }

  function regex(pattern, line, flags = "") {
    try { return new RegExp(pattern, flags); } catch {
      throw runtime(`PatternSyntaxException: „${pattern}“ ist kein gültiger regulärer Ausdruck.`, line);
    }
  }

  function stringMethod(text, name, args, line) {
    const label = name;
    const index = (value) => intArg(value, label, line);
    const needle = (value) => (value.k === "char" ? javaString(value) : stringArg(value, label, line));

    switch (name) {
      case "length":
        arity(args, 0, "length()", line);
        return V.int(text.length);
      case "charAt": {
        arity(args, 1, "charAt", line);
        const i = index(args[0]);
        if (i < 0 || i >= text.length) {
          throw runtime(`StringIndexOutOfBoundsException: Index ${i} gibt es nicht – "${text}" hat nur die Positionen 0 bis ${text.length - 1}.`, line);
        }
        return V.char(text.charCodeAt(i));
      }
      case "substring": {
        if (args.length < 1 || args.length > 2) throw syntax("substring erwartet 1 oder 2 Zahlen.", line);
        const begin = index(args[0]);
        const end = args.length === 2 ? index(args[1]) : text.length;
        if (begin < 0 || end > text.length || begin > end) {
          throw runtime(`StringIndexOutOfBoundsException: begin ${begin}, end ${end}, length ${text.length} – der Bereich passt nicht in den Text.`, line);
        }
        return V.str(text.slice(begin, end));
      }
      case "indexOf": case "lastIndexOf": {
        if (args.length < 1 || args.length > 2) throw syntax(`${name} erwartet 1 oder 2 Werte.`, line);
        const search = needle(args[0]);
        const from = args.length === 2 ? index(args[1]) : name === "indexOf" ? 0 : text.length;
        if (search === "") return V.int(Math.max(0, Math.min(from, text.length)));
        let found = -1;
        for (let p = 0; p + search.length <= text.length; p += 1) {
          if (text.startsWith(search, p)) {
            if (name === "indexOf") { if (p >= from) { found = p; break; } } else if (p <= from) { found = p; }
          }
        }
        return V.int(found);
      }
      case "contains": {
        arity(args, 1, "contains", line);
        const search = needle(args[0]);
        return V.boolean(search === "" || text.includes(search));
      }
      case "equals":
        arity(args, 1, "equals", line);
        return V.boolean(args[0].k === "string" && args[0].o.text === text);
      case "equalsIgnoreCase":
        arity(args, 1, "equalsIgnoreCase", line);
        return V.boolean(args[0].k === "string" && args[0].o.text.toLowerCase() === text.toLowerCase());
      case "compareTo": case "compareToIgnoreCase": {
        arity(args, 1, name, line);
        const other = stringArg(args[0], name, line);
        return name === "compareTo"
          ? V.int(compareStrings(text, other))
          : V.int(compareStrings(text.toLowerCase(), other.toLowerCase()));
      }
      case "toUpperCase":
        arity(args, 0, name, line);
        return V.str(text.toUpperCase());
      case "toLowerCase":
        arity(args, 0, name, line);
        return V.str(text.toLowerCase());
      case "trim": case "strip":
        arity(args, 0, name, line);
        return V.str(text.trim());
      case "isEmpty":
        arity(args, 0, name, line);
        return V.boolean(text.length === 0);
      case "isBlank":
        arity(args, 0, name, line);
        return V.boolean(/^\s*$/u.test(text));
      case "startsWith": case "endsWith": {
        arity(args, 1, name, line);
        const part = stringArg(args[0], name, line);
        return V.boolean(name === "startsWith" ? text.startsWith(part) : text.endsWith(part));
      }
      case "replace": {
        arity(args, 2, "replace", line);
        const old = needle(args[0]), replacement = needle(args[1]);
        if (old === "") throw unsupported("replace mit leerem Suchtext kennt der eingebaute Interpreter nicht.", line);
        return V.str(text.split(old).join(replacement));
      }
      case "replaceAll": case "matches": case "split": {
        const pattern = stringArg(args[0] || NULL, name, line);
        if (name === "matches") {
          arity(args, 1, name, line);
          return V.boolean(regex(`^(?:${pattern})$`, line).test(text));
        }
        if (name === "replaceAll") {
          arity(args, 2, name, line);
          const replacement = stringArg(args[1], name, line);
          return V.str(text.replace(regex(pattern, line, "g"), replacement));
        }
        arity(args, 1, name, line);
        if (text === "") return V.array(new JavaArray("String", [V.str("")]));
        const parts = [];
        let last = 0;
        for (const match of text.matchAll(regex(pattern, line, "g"))) {
          const start = match.index, end = match.index + match[0].length;
          // Ein Treffer der Länge 0 ganz am Anfang erzeugt in Java kein leeres erstes Element.
          if (start === end && (start === 0 || start === text.length)) continue;
          parts.push(text.slice(last, start));
          last = end;
        }
        parts.push(text.slice(last));
        while (parts.length > 1 && parts[parts.length - 1] === "") parts.pop();
        return V.array(new JavaArray("String", parts.map(V.str)));
      }
      case "repeat": {
        arity(args, 1, "repeat", line);
        const count = index(args[0]);
        if (count < 0) throw runtime(`IllegalArgumentException: count is negative: ${count}`, line);
        return V.str(text.repeat(count));
      }
      case "concat":
        arity(args, 1, "concat", line);
        return V.str(text + stringArg(args[0], "concat", line));
      case "toCharArray":
        arity(args, 0, "toCharArray", line);
        return V.array(new JavaArray("char", Array.from({ length: text.length }, (_, i) => V.char(text.charCodeAt(i)))));
      case "hashCode": {
        arity(args, 0, "hashCode", line);
        let hash = 0;
        for (let i = 0; i < text.length; i += 1) hash = (Math.imul(hash, 31) + text.charCodeAt(i)) | 0;
        return V.int(hash);
      }
      default:
        throw unsupported(`Die String-Methode ${name}() kennt der eingebaute Interpreter nicht.`, line);
    }
  }

  // MARK: - Ausführen

  const DEFAULT_STEP_LIMIT = 200000;

  /** Prüft nur die Syntax (und ob der Interpreter alle Bausteine kennt). */
  function check(source) {
    try { parse(source); return null; } catch (error) {
      if (error instanceof JavaProblem) return error;
      throw error;
    }
  }

  /**
   * Führt das Programm aus: { output, problem, steps, warnings }.
   * `host` stellt Objekte wie `robot` bereit: { objectNames: Set, wantsSnapshot, call(object, method, args, context) }.
   */
  function run(source, { stepLimit = DEFAULT_STEP_LIMIT, host = null } = {}) {
    let program;
    try {
      program = parse(source);
    } catch (error) {
      if (error instanceof JavaProblem) return { output: "", problem: error, steps: 0, warnings: [] };
      if (error instanceof RangeError) {
        return { output: "", problem: syntax("Der Code ist zu tief verschachtelt.", null), steps: 0, warnings: [] };
      }
      throw error;
    }
    const interpreter = new Interpreter(program, stepLimit, host);
    const problem = interpreter.run();
    return { output: interpreter.output, problem, steps: interpreter.steps, warnings: interpreter.warnings };
  }

  return {
    run, check, JavaProblem,
    V, NULL, VOID, TRUE, FALSE, javaString,
    formatDouble, format, normalizingTypography, strippingComments, maskingLiterals,
    DEFAULT_STEP_LIMIT,
  };
})();

