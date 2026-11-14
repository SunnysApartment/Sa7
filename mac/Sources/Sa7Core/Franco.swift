/// Franco-Arabic (Arabizi) to Arabic, tuned for Egyptian chat: "ezayak 3amel eh" -> "ازيك عامل ايه".
/// sa7-site/franco.js is a port of this file with the same dictionary and rules: change both together.
///
/// Choices (Egyptian first):
///   2 -> ق   Cairenes say ق as a glottal stop, so "2olt" is قلت. Real hamza words (so2al, ra2y) are in `words`.
///   3 -> ع, 3' -> غ, 5 -> خ, 7 -> ح, 7' -> خ, 6 -> ط, 6' -> ظ, 8 -> ق, 9 -> ص, 9' -> ض.
///   g -> ج (Egyptian gim), th -> ث, dh -> ذ, ch -> ش, x -> كس, c -> س before e/i else ك.
///   Short vowels are dropped, i/ee -> ي, u/oo/ou -> و; a word-initial vowel is a bare ا (how chat spells it).
///   Doubled letters (marra) are written once: Arabic shows shadda as a mark, not a second letter.
///   The standalone article "el sa3a" joins the next word (الساعة), so that whitespace run disappears.
public enum Franco {
    /// Arabic text for Franco-Arabic input. Words without Latin letters (Arabic, plain numbers) pass through,
    /// punctuation and spacing are kept as typed, except that a standalone article joins the next word.
    public static func toArabic(_ text: String) -> String {
        let t = runs(text, by: \.isWhitespace)
        var out = ""
        var i = 0
        while i < t.count {
            if let article = articles[t[i].lowercased()], i + 2 < t.count, t[i + 1].first!.isWhitespace,
               let first = t[i + 2].first, first.isASCII, first.isLetter || first.isNumber, hasLatin(t[i + 2]) {
                out += article + token(t[i + 2])
                i += 3
            } else {
                out += token(t[i])
                i += 1
            }
        }
        return out
    }

    /// True when the text is most likely Franco-Arabic rather than English or wrong-keyboard gibberish.
    /// Franco evidence per word: a digit used as a letter (sa7, 3amel; not 2nd, 3rd), or a known Franco word.
    public static func looksLikeFranco(_ text: String) -> Bool {
        let all = runs(text.lowercased(), by: isWordChar).filter { isWordChar($0.first!) && hasLatin($0) }
        guard !all.isEmpty else { return false }
        let hits = all.filter { w in
            let ch = Array(w)
            let digitAsLetter = ch.indices.contains { i in
                guard "2356789".contains(ch[i]) else { return false }
                let j = i + 1 < ch.count && ch[i + 1] == "'" ? i + 2 : i + 1
                return (i > 0 && ch[i - 1].isLetter) || (j < ch.count && ch[j].isLetter)
            }
            let leadingDigits = w.prefix(while: \.isNumber)
            let ordinal = !leadingDigits.isEmpty && ["st", "nd", "rd", "th"].contains(w.dropFirst(leadingDigits.count))
            return (digitAsLetter && w.contains(where: "aeiouy".contains) && !ordinal) ||
                (words[w] != nil && !lookalikes.contains(w)) || w == "el" || w == "kam"
        }.count
        return hits * 2 >= all.count // at least half the words, so one "mesh" in an English sentence isn't enough
    }

    /// Exact spellings, checked before the rules: words the rules get wrong, and multi-word phrases.
    static let words: [String: String] = [
        "ana": "انا", "enta": "انت", "inta": "انت", "anta": "انت", "ente": "انتي", "enti": "انتي", "inti": "انتي",
        "howa": "هو", "huwa": "هو", "heya": "هي", "hya": "هي", "hiya": "هي", "e7na": "احنا", "i7na": "احنا",
        "ento": "انتو", "entom": "انتو", "into": "انتو", "homa": "هما", "hma": "هما",
        "da": "ده", "dah": "ده", "de": "دي", "di": "دي", "dol": "دول", "keda": "كده", "kida": "كده", "kda": "كده", "kedah": "كده", "ma3ak": "معاك", "ma3aki": "معاكي", "ostaz": "استاذ", "ostaza": "استاذة", "lela": "ليلة", "leila": "ليلة",
        "hena": "هنا", "henak": "هناك", "hnak": "هناك", "ezay": "ازاي", "izay": "ازاي", "ezzay": "ازاي",
        "ezayak": "ازيك", "ezayk": "ازيك", "ezayek": "ازيك", "izayak": "ازيك", "ezayko": "ازيكو",
        "eh": "ايه", "eih": "ايه", "ehh": "ايه", "leh": "ليه", "leih": "ليه", "feen": "فين", "fen": "فين", "fein": "فين",
        "meen": "مين", "min": "من", "men": "من", "emta": "امتى", "imta": "امتى", "kam": "كام",
        "mesh": "مش", "msh": "مش", "mish": "مش", "la": "لا", "la2": "لا", "aywa": "ايوه", "aiwa": "ايوه", "ah": "اه", "aah": "اه",
        "tab": "طب", "tayeb": "طيب", "tayb": "طيب", "mashy": "ماشي", "mashi": "ماشي",
        "fe": "في", "fi": "في", "3ala": "على", "3la": "على", "3an": "عن", "ma3": "مع", "we": "و", "wa": "و",
        "aw": "او", "wala": "ولا", "walla": "ولا", "bas": "بس", "lakin": "لكن", "lakn": "لكن", "3ashan": "عشان", "3shan": "عشان",
        "law": "لو", "lw": "لو", "lama": "لما", "lamma": "لما", "ba2a": "بقى", "kaman": "كمان", "bardo": "برضو", "bardu": "برضو",
        "delwa2ty": "دلوقتي", "dlwa2ty": "دلوقتي", "delwa2t": "دلوقت", "ella": "الا", "elly": "اللي", "elli": "اللي",
        "sa7": "صح", "kol": "كل", "kul": "كل", "ya": "يا", "aho": "اهو", "ahe": "اهي", "mafeesh": "مفيش", "mafish": "مفيش",
        // Greetings and phrases.
        "inshallah": "ان شاء الله", "inshalla": "ان شاء الله", "insha2allah": "ان شاء الله",
        "mashallah": "ما شاء الله", "masha2allah": "ما شاء الله", "alhamdulillah": "الحمد لله",
        "el7amdulillah": "الحمد لله", "elhamdulillah": "الحمد لله", "el7amdolelah": "الحمد لله", "alhamdolillah": "الحمد لله",
        "allah": "الله", "wallah": "والله", "wallahi": "والله", "yalla": "يلا", "yala": "يلا", "yarab": "يارب",
        "habibi": "حبيبي", "habibty": "حبيبتي", "habibti": "حبيبتي", "7abibty": "حبيبتي",
        "ahlan": "اهلا", "marhaba": "مرحبا", "shokran": "شكرا", "shukran": "شكرا", "3afwan": "عفوا",
        "ma3lesh": "معلش", "ma3lsh": "معلش", "mabrook": "مبروك", "mabrouk": "مبروك", "salama": "سلامة",
        "saba7": "صباح", "sabah": "صباح", "masa2": "مساء", "khalas": "خلاص", "5alas": "خلاص", "7ader": "حاضر",
        // Adverbs ending in tanween -an (the rules would add ن).
        "gedan": "جدا", "tab3an": "طبعا", "fe3lan": "فعلا", "aslan": "اصلا", "masalan": "مثلا", "ta2riban": "تقريبا", "abadan": "ابدا",
        // Everyday words the vowel rules can't guess.
        "ya3ni": "يعني", "keteer": "كتير", "kteer": "كتير", "kter": "كتير", "shwaya": "شوية", "shewaya": "شوية",
        "awy": "قوي", "awi": "قوي", "2awy": "قوي", "kwayes": "كويس", "kwayis": "كويس", "kwayesa": "كويسة",
        "3ayez": "عايز", "3ayz": "عايز", "3ayza": "عايزة", "3arfa": "عارفة", "3amla": "عاملة",
        "ba7ebak": "بحبك", "ba7bak": "بحبك", "ba7ebek": "بحبك", "ba7bek": "بحبك",
        "naharda": "النهارده", "ennaharda": "النهارده", "elnaharda": "النهارده", "embare7": "امبارح", "imbare7": "امبارح",
        "bokra": "بكرة", "sa7by": "صاحبي", "sa7bi": "صاحبي", "so2al": "سؤال", "mas2ala": "مسألة", "ra2y": "رأي",
    ]
    /// Dictionary words that are also everyday English, so they don't count as Franco evidence.
    static let lookalikes: Set<String> = ["da", "de", "di", "fe", "fi", "la", "ya", "we", "wa", "aw", "law", "men", "min",
                                          "bas", "tab", "ah", "eh", "ella", "allah", "into", "hena", "dol", "ma3"]
    /// Standalone articles that attach to the next word: "el sa3a" -> الساعة.
    static let articles: [String: String] = ["el": "ال", "al": "ال", "il": "ال", "bel": "بال", "bil": "بال",
                                             "fel": "في ال", "wel": "وال", "lel": "لل"]

    static let digits: [Character: String] = ["2": "ق", "3": "ع", "5": "خ", "6": "ط", "7": "ح", "8": "ق", "9": "ص"]
    static let primed: [String: String] = ["3'": "غ", "7'": "خ", "9'": "ض", "6'": "ظ"]
    static let pairs: [String: String] = ["sh": "ش", "ch": "ش", "kh": "خ", "gh": "غ", "th": "ث", "dh": "ذ"]
    static let letters: [Character: String] = [
        "b": "ب", "c": "ك", "d": "د", "f": "ف", "g": "ج", "h": "ه", "j": "ج", "k": "ك", "l": "ل", "m": "م", "n": "ن",
        "p": "ب", "q": "ق", "r": "ر", "s": "س", "t": "ت", "v": "ف", "w": "و", "x": "كس", "y": "ي", "z": "ز",
    ]

    static func isWordChar(_ c: Character) -> Bool { c.isASCII && (c.isLetter || c.isNumber) || c == "'" }
    static func hasLatin(_ s: String) -> Bool { s.contains { $0.isASCII && $0.isLetter } }

    /// Consecutive characters with the same `key`, in order: "ab  c" by isWhitespace -> ["ab", "  ", "c"].
    static func runs(_ s: String, by key: (Character) -> Bool) -> [String] {
        var out: [String] = []
        var lastKey: Bool?
        for ch in s {
            let k = key(ch)
            if k == lastKey { out[out.count - 1].append(ch) } else { out.append(String(ch)); lastKey = k }
        }
        return out
    }

    /// One whitespace-free token: words convert, punctuation between them stays. "el-sa3a" joins like "el sa3a".
    static func token(_ t: String) -> String {
        guard hasLatin(t) else { return t }
        let seg = runs(t, by: isWordChar)
        var out = ""
        var i = 0
        while i < seg.count {
            if let article = articles[seg[i].lowercased()], seg.count > i + 2, seg[i + 1] == "-" {
                out += article + word(seg[i + 2])
                i += 3
            } else {
                out += isWordChar(seg[i].first!) ? word(seg[i]) : seg[i]
                i += 1
            }
        }
        return out
    }

    static func word(_ w: String) -> String {
        let lower = w.lowercased()
        guard hasLatin(lower) else { return w }
        if let exact = words[lower] { return exact }
        // Joined article: elbeit -> البيت (needs a consonant and 3+ letters after it, so "elly", "alby" stay whole).
        if ["el", "al", "il"].contains(String(lower.prefix(2))) {
            let rest = String(lower.dropFirst(2))
            if rest.count >= 3, !"aeiou'".contains(rest.first!) { return "ال" + (words[rest] ?? transliterate(rest)) }
        }
        return transliterate(lower)
    }

    /// A vowel run ("ee"), an Arabic consonant ("ش"), or a character kept as typed ("1").
    struct Unit {
        var vowel = "", letter = "", literal = ""
        var doubled = false
    }

    static func units(_ word: String) -> [Unit] {
        let ch = Array(word)
        var out: [Unit] = []
        var i = 0
        while i < ch.count {
            let c = ch[i]
            let two = i + 1 < ch.count ? String([c, ch[i + 1]]) : String(c)
            i += 1
            if "aeiou".contains(c) {
                if let last = out.last, !last.vowel.isEmpty { out[out.count - 1].vowel.append(c) } else { out.append(Unit(vowel: String(c))) }
                continue
            }
            let arabic: String?
            if let pair = primed[two] ?? pairs[two] { arabic = pair; i += 1 }
            else if c == "c", i < ch.count, "ei".contains(ch[i]) { arabic = "س" }
            else { arabic = digits[c] ?? letters[c] }
            guard let arabic else {
                if c != "'" { out.append(Unit(literal: String(c))) }
                continue
            }
            if out.last?.letter == arabic { out[out.count - 1].doubled = true; continue } // doubled letter written once: marra -> مرة
            out.append(Unit(letter: arabic))
        }
        return out
    }

    static func transliterate(_ word: String) -> String {
        var all = units(word)
        let vowels = all.filter { !$0.vowel.isEmpty }.count
        let vowelStart = !(all.first?.vowel.isEmpty ?? true)
        // Final -ah after two or more syllables is ta marbuta: sa3ah -> ساعة.
        var taa = false
        if vowels >= 2, all.count >= 2, all[all.count - 1].letter == "ه", all[all.count - 2].vowel == "a" {
            all.removeLast()
            taa = true
        }
        let u = all, last = u.count - 1
        func at(_ i: Int) -> Unit? { u.indices.contains(i) ? u[i] : nil }
        func isLetter(_ i: Int) -> Bool { !(at(i)?.letter.isEmpty ?? true) }

        // CaCe.. / CaCa / CaCi: the first a of an active participle, a short feminine noun or a CaCi adjective
        // is long (3amel, 3aref, sa3a, 7aga, 3ady). Not after b, the Egyptian present prefix (ba7eb -> بحب).
        func longFirstA(_ i: Int) -> Bool {
            i == 1 && isLetter(0) && u[0].letter != "ب" && isLetter(2) && !u[2].doubled &&
                (at(3)?.vowel == "e" || (last == 3 && (u[3].vowel == "a" || u[3].vowel == "i" || u[3].letter == "ي")))
        }

        func initial(_ v: String) -> String {
            if ["ee", "ei", "ai", "ie", "ii"].contains(where: v.hasPrefix) { return "اي" }
            if ["oo", "ou", "uu"].contains(where: v.hasPrefix) { return "او" }
            return "ا"
        }

        func medial(_ i: Int) -> String {
            let v = u[i].vowel, next = u[i + 1], beforeLastC = i == last - 1 && !next.letter.isEmpty
            if v == "a" {
                if longFirstA(i) { return "ا" }
                if beforeLastC && next.letter == "ي" { return "ا" } // -ay: shay, ezay
                // Final -aC is usually long (kaman, tamam, beta3); not -ak, the "your" suffix (ma3ak -> معك).
                if beforeLastC && vowels >= 2 && !vowelStart && next.letter != "ك" { return "ا" }
                return ""
            }
            if v == "e" && beforeLastC && next.letter == "ه" { return "ي" } // -eh: leh, feh
            if v == "aa" { return "ا" }
            if v.contains("i") || v.contains("ee") { return "ي" }
            if v.contains("u") || v.contains("oo") { return "و" }
            if v == "o" && vowels == 1 && beforeLastC { return "و" } // one-syllable CoC: yom, ro7 (2olt stays short)
            return "" // short a / e / o
        }

        func finalA(_ i: Int) -> String {
            let prev = u[i - 1]
            if taa { return "ة" }
            if vowels == 1 { return "ا" } // la, ya, ma
            if prev.letter == "ن" || prev.letter == "ه" { return "ا" } // -na "our", -ha "her": beta3na, 3andaha
            if prev.letter == "ي" { return (at(i - 2)?.vowel.isEmpty ?? true) ? "ا" : "ة" } // 3arabeya, shwaya -> ية; donya -> يا
            if vowelStart && u.count == 4 && isLetter(1) && isLetter(2) { return "ى" } // elative aCCa: a7la, a2wa
            return "ة" // feminine: bokra, 7elwa, kelma
        }

        func final(_ i: Int) -> String {
            let v = u[i].vowel
            if v == "a" { return finalA(i) }
            if v == "aa" { return "ا" }
            if v == "o" { return "ه" } // Egyptian "his": 3ando -> عنده
            if v == "ia" || v == "ea" { return "ية" }
            if v.contains("u") || v.contains("oo") { return "و" }
            return "ي" // e, i, ee: ente, fi
        }

        return u.indices.map { i in
            let x = u[i]
            if !x.letter.isEmpty { return x.letter }
            if !x.literal.isEmpty { return x.literal }
            return i == 0 ? initial(x.vowel) : i == last ? final(i) : medial(i)
        }.joined()
    }
}
