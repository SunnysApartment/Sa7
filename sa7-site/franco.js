// Franco-Arabic (Arabizi) to Arabic, tuned for Egyptian chat: "ezayak 3amel eh" -> "ازيك عامل ايه".
// Port of mac/Sources/Sa7Core/Franco.swift: same dictionary, same rules. Change both together.
//
// Choices (Egyptian first):
//   2 -> ق   Cairenes say ق as a glottal stop, so "2olt" is قلت. Real hamza words (so2al, ra2y) are in WORDS.
//   3 -> ع, 3' -> غ, 5 -> خ, 7 -> ح, 7' -> خ, 6 -> ط, 6' -> ظ, 8 -> ق, 9 -> ص, 9' -> ض.
//   g -> ج (Egyptian gim), th -> ث, dh -> ذ, ch -> ش, x -> كس, c -> س before e/i else ك.
//   Short vowels are dropped, i/ee -> ي, u/oo/ou -> و; a word-initial vowel is a bare ا (how chat spells it).
//   Doubled letters (marra) are written once: Arabic shows shadda as a mark, not a second letter.
//   The standalone article "el sa3a" joins the next word (الساعة), so that whitespace run disappears.
const franco = (() => {
  // Exact spellings, checked before the rules: words the rules get wrong, and multi-word phrases.
  // Null prototype so words like "constructor" aren't found in it.
  const WORDS = Object.assign(Object.create(null), {
    ana: "انا", enta: "انت", inta: "انت", anta: "انت", ente: "انتي", enti: "انتي", inti: "انتي",
    howa: "هو", huwa: "هو", heya: "هي", hya: "هي", hiya: "هي", e7na: "احنا", i7na: "احنا",
    ento: "انتو", entom: "انتو", into: "انتو", homa: "هما", hma: "هما",
    da: "ده", dah: "ده", de: "دي", di: "دي", dol: "دول", keda: "كده", kida: "كده", kda: "كده", kedah: "كده", ma3ak: "معاك", ma3aki: "معاكي", ostaz: "استاذ", ostaza: "استاذة", lela: "ليلة", leila: "ليلة",
    hena: "هنا", henak: "هناك", hnak: "هناك", ezay: "ازاي", izay: "ازاي", ezzay: "ازاي",
    ezayak: "ازيك", ezayk: "ازيك", ezayek: "ازيك", izayak: "ازيك", ezayko: "ازيكو",
    eh: "ايه", eih: "ايه", ehh: "ايه", leh: "ليه", leih: "ليه", feen: "فين", fen: "فين", fein: "فين",
    meen: "مين", min: "من", men: "من", emta: "امتى", imta: "امتى", kam: "كام",
    mesh: "مش", msh: "مش", mish: "مش", la: "لا", la2: "لا", aywa: "ايوه", aiwa: "ايوه", ah: "اه", aah: "اه",
    tab: "طب", tayeb: "طيب", tayb: "طيب", mashy: "ماشي", mashi: "ماشي",
    fe: "في", fi: "في", "3ala": "على", "3la": "على", "3an": "عن", ma3: "مع", we: "و", wa: "و",
    aw: "او", wala: "ولا", walla: "ولا", bas: "بس", lakin: "لكن", lakn: "لكن", "3ashan": "عشان", "3shan": "عشان",
    law: "لو", lw: "لو", lama: "لما", lamma: "لما", ba2a: "بقى", kaman: "كمان", bardo: "برضو", bardu: "برضو",
    delwa2ty: "دلوقتي", dlwa2ty: "دلوقتي", delwa2t: "دلوقت", ella: "الا", elly: "اللي", elli: "اللي",
    sa7: "صح", kol: "كل", kul: "كل", ya: "يا", aho: "اهو", ahe: "اهي", mafeesh: "مفيش", mafish: "مفيش",
    // Greetings and phrases.
    inshallah: "ان شاء الله", inshalla: "ان شاء الله", insha2allah: "ان شاء الله",
    mashallah: "ما شاء الله", masha2allah: "ما شاء الله", alhamdulillah: "الحمد لله",
    el7amdulillah: "الحمد لله", elhamdulillah: "الحمد لله", el7amdolelah: "الحمد لله", alhamdolillah: "الحمد لله",
    allah: "الله", wallah: "والله", wallahi: "والله", yalla: "يلا", yala: "يلا", yarab: "يارب",
    habibi: "حبيبي", habibty: "حبيبتي", habibti: "حبيبتي", "7abibty": "حبيبتي",
    ahlan: "اهلا", marhaba: "مرحبا", shokran: "شكرا", shukran: "شكرا", "3afwan": "عفوا",
    ma3lesh: "معلش", ma3lsh: "معلش", mabrook: "مبروك", mabrouk: "مبروك", salama: "سلامة",
    saba7: "صباح", sabah: "صباح", masa2: "مساء", khalas: "خلاص", "5alas": "خلاص", "7ader": "حاضر",
    // Adverbs ending in tanween -an (the rules would add ن).
    gedan: "جدا", tab3an: "طبعا", fe3lan: "فعلا", aslan: "اصلا", masalan: "مثلا", ta2riban: "تقريبا", abadan: "ابدا",
    // Everyday words the vowel rules can't guess.
    ya3ni: "يعني", keteer: "كتير", kteer: "كتير", kter: "كتير", shwaya: "شوية", shewaya: "شوية",
    awy: "قوي", awi: "قوي", "2awy": "قوي", kwayes: "كويس", kwayis: "كويس", kwayesa: "كويسة",
    "3ayez": "عايز", "3ayz": "عايز", "3ayza": "عايزة", "3arfa": "عارفة", "3amla": "عاملة",
    ba7ebak: "بحبك", ba7bak: "بحبك", ba7ebek: "بحبك", ba7bek: "بحبك",
    naharda: "النهارده", ennaharda: "النهارده", elnaharda: "النهارده", embare7: "امبارح", imbare7: "امبارح",
    bokra: "بكرة", sa7by: "صاحبي", sa7bi: "صاحبي", so2al: "سؤال", mas2ala: "مسألة", ra2y: "رأي",
  });
  // Dictionary words that are also everyday English, so they don't count as Franco evidence.
  const LOOKALIKES = new Set(["da", "de", "di", "fe", "fi", "la", "ya", "we", "wa", "aw", "law", "men", "min",
    "bas", "tab", "ah", "eh", "ella", "allah", "into", "hena", "dol", "ma3"]);
  // Standalone articles that attach to the next word: "el sa3a" -> الساعة.
  const ARTICLES = Object.assign(Object.create(null),
    { el: "ال", al: "ال", il: "ال", bel: "بال", bil: "بال", fel: "في ال", wel: "وال", lel: "لل" });

  const DIGITS = { "2": "ق", "3": "ع", "5": "خ", "6": "ط", "7": "ح", "8": "ق", "9": "ص" };
  const PRIMED = { "3'": "غ", "7'": "خ", "9'": "ض", "6'": "ظ" };
  const PAIRS = { sh: "ش", ch: "ش", kh: "خ", gh: "غ", th: "ث", dh: "ذ" };
  const LETTERS = { b: "ب", c: "ك", d: "د", f: "ف", g: "ج", h: "ه", j: "ج", k: "ك", l: "ل", m: "م", n: "ن",
    p: "ب", q: "ق", r: "ر", s: "س", t: "ت", v: "ف", w: "و", x: "كس", y: "ي", z: "ز" };
  const isVowel = ch => "aeiou".includes(ch);
  const hasLatin = s => /[A-Za-z]/.test(s);

  // A lowercase word as units: {v: "ee"} vowel runs, {c: "ش"} Arabic consonants, {lit: "1"} kept as typed.
  const units = word => {
    const ch = [...word], out = [];
    for (let i = 0; i < ch.length; i++) {
      const last = out[out.length - 1], two = ch[i] + (ch[i + 1] ?? "");
      if (isVowel(ch[i])) {
        if (last?.v) last.v += ch[i]; else out.push({ v: ch[i] });
        continue;
      }
      let c;
      if (PRIMED[two] || PAIRS[two]) { c = PRIMED[two] || PAIRS[two]; i++; }
      else if (ch[i] === "c" && "ei".includes(ch[i + 1])) c = "س";
      else c = DIGITS[ch[i]] ?? LETTERS[ch[i]];
      if (c === undefined) { if (ch[i] !== "'") out.push({ lit: ch[i] }); continue; }
      if (last?.c === c) { last.double = true; continue; } // doubled letter written once: marra -> مرة
      out.push({ c });
    }
    return out;
  };

  const transliterate = word => {
    const u = units(word);
    const vowels = u.filter(x => x.v).length, vowelStart = !!u[0]?.v;
    // Final -ah after two or more syllables is ta marbuta: sa3ah -> ساعة.
    let taa = false;
    if (vowels >= 2 && u.length >= 2 && u[u.length - 1].c === "ه" && u[u.length - 2].v === "a") { u.pop(); taa = true; }
    const last = u.length - 1;

    // CaCe.. / CaCa / CaCi: the first a of an active participle, a short feminine noun or a CaCi adjective
    // is long (3amel, 3aref, sa3a, 7aga, 3ady). Not after b, the Egyptian present prefix (ba7eb -> بحب).
    const longFirstA = i => i === 1 && u[0].c && u[0].c !== "ب" && u[2]?.c && !u[2].double &&
      (u[3]?.v === "e" || (last === 3 && (u[3].v === "a" || u[3].v === "i" || u[3].c === "ي")));

    const initial = v => /^(ee|ei|ai|ie|ii)/.test(v) ? "اي" : /^(oo|ou|uu)/.test(v) ? "او" : "ا";

    const medial = i => {
      const v = u[i].v, next = u[i + 1], beforeLastC = i === last - 1 && next.c;
      if (v === "a") {
        if (longFirstA(i)) return "ا";
        if (beforeLastC && next.c === "ي") return "ا"; // -ay: shay, ezay
        // Final -aC is usually long (kaman, tamam, beta3); not -ak, the "your" suffix (ma3ak -> معك).
        if (beforeLastC && vowels >= 2 && !vowelStart && next.c !== "ك") return "ا";
        return "";
      }
      if (v === "e" && beforeLastC && next.c === "ه") return "ي"; // -eh: leh, feh
      if (v === "aa") return "ا";
      if (v.includes("i") || v.includes("ee")) return "ي";
      if (v.includes("u") || v.includes("oo")) return "و";
      if (v === "o" && vowels === 1 && beforeLastC) return "و"; // one-syllable CoC: yom, ro7 (2olt stays short)
      return ""; // short a / e / o
    };

    const finalA = i => {
      const prev = u[i - 1];
      if (taa) return "ة";
      if (vowels === 1) return "ا"; // la, ya, ma
      if (prev.c === "ن" || prev.c === "ه") return "ا"; // -na "our", -ha "her": beta3na, 3andaha
      if (prev.c === "ي") return u[i - 2]?.v ? "ة" : "ا"; // 3arabeya, shwaya -> ية; donya -> يا
      if (vowelStart && u.length === 4 && u[1].c && u[2].c) return "ى"; // elative aCCa: a7la, a2wa
      return "ة"; // feminine: bokra, 7elwa, kelma
    };

    const final = i => {
      const v = u[i].v;
      if (v === "a") return finalA(i);
      if (v === "aa") return "ا";
      if (v === "o") return "ه"; // Egyptian "his": 3ando -> عنده
      if (v === "ia" || v === "ea") return "ية";
      if (v.includes("u") || v.includes("oo")) return "و";
      return "ي"; // e, i, ee: ente, fi
    };

    return u.map((x, i) => x.c ?? x.lit ?? (i === 0 ? initial(x.v) : i === last ? final(i) : medial(i))).join("");
  };

  const word = w => {
    const lower = w.toLowerCase();
    if (!hasLatin(lower)) return w;
    if (WORDS[lower]) return WORDS[lower];
    // Joined article: elbeit -> البيت (needs a consonant and 3+ letters after it, so "elly", "alby" stay whole).
    const m = /^(el|al|il)([^aeiou'].{2,})$/.exec(lower);
    if (m) return "ال" + (WORDS[m[2]] ?? transliterate(m[2]));
    return transliterate(lower);
  };

  // One whitespace-free token: words convert, punctuation between them stays. "el-sa3a" joins like "el sa3a".
  const token = t => {
    if (!hasLatin(t)) return t;
    const seg = t.match(/[A-Za-z0-9']+|[^A-Za-z0-9']+/g);
    let out = "";
    for (let i = 0; i < seg.length; i++) {
      const art = ARTICLES[seg[i].toLowerCase()];
      if (art && seg[i + 1] === "-" && seg[i + 2]) { out += art + word(seg[i + 2]); i += 2; }
      else out += /[A-Za-z0-9']/.test(seg[i][0]) ? word(seg[i]) : seg[i];
    }
    return out;
  };

  const toArabic = text => {
    const t = text.match(/\s+|\S+/g) ?? [];
    let out = "";
    for (let i = 0; i < t.length; i++) {
      const art = ARTICLES[t[i].toLowerCase()];
      if (art && /^\s+$/.test(t[i + 1] ?? "") && /^[A-Za-z0-9]/.test(t[i + 2] ?? "") && hasLatin(t[i + 2])) {
        out += art + token(t[i + 2]); i += 2;
      } else out += token(t[i]);
    }
    return out;
  };

  // Franco evidence per word: a digit used as a letter (sa7, 3amel; not 2nd, 3rd), or a known Franco word.
  const looksLikeFranco = text => {
    const words = (text.toLowerCase().match(/[a-z0-9']+/g) ?? []).filter(hasLatin);
    if (!words.length) return false;
    const hits = words.filter(w =>
      (/[a-z][2356789]|[2356789]'?[a-z]/.test(w) && /[aeiouy]/.test(w) && !/^\d+(st|nd|rd|th)$/.test(w)) ||
      (WORDS[w] && !LOOKALIKES.has(w)) || w === "el" || w === "kam").length;
    return hits * 2 >= words.length; // at least half the words, so one "mesh" in an English sentence isn't enough
  };

  return { toArabic, looksLikeFranco };
})();

if (typeof module !== "undefined") module.exports = franco;
