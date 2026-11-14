// Run: node franco.test.js. Mirrors mac/Tests/Sa7CoreTests/FrancoTests.swift: keep the cases in sync.
const assert = require("node:assert");
const franco = require("./franco.js");
const ar = franco.toArabic;

// Phrases from everyday Egyptian chat.
assert.equal(ar("ezayak 3amel eh"), "ازيك عامل ايه");
assert.equal(ar("ana 2olt keda"), "انا قلت كده");
assert.equal(ar("mesh 3aref"), "مش عارف");
assert.equal(ar("el sa3a kam"), "الساعة كام");
assert.equal(ar("yalla bina"), "يلا بينا");
assert.equal(ar("sabah el 5eer"), "صباح الخير");
assert.equal(ar("ana 3ayez akol"), "انا عايز اكل");
assert.equal(ar("inshallah"), "ان شاء الله");

// Single words through the rules, not the dictionary.
const words = {
  "7abibi": "حبيبي", "3amel": "عامل", "wa7ed": "واحد", "ragel": "راجل", "mashe": "ماشي",
  "kalam": "كلام", "tamam": "تمام", "beta3": "بتاع", "ta3ban": "تعبان", "salam": "سلام",
  "sa3a": "ساعة", "sa3ah": "ساعة", "bokra": "بكرة", "7elwa": "حلوة", "kelma": "كلمة", "fekra": "فكرة",
  "3arabeya": "عربية", "donya": "دنيا", "a7la": "احلى", "aktar": "اكتر", "a7san": "احسن",
  "momken": "ممكن", "2olt": "قلت", "yom": "يوم", "3ando": "عنده", "3andaha": "عندها", "marra": "مرة",
  "ezay": "ازاي", "shay": "شاي", "leh": "ليه", "feeh": "فيه", "ba7eb": "بحب", "ma3ak": "معاك",
  "2ahwa": "قهوة", "7'adt": "خدت", "3'aly": "غالي", "9aba7": "صباح", "6ayeb": "طايب", "3ady": "عادي", "ibn": "ابن",
};
for (const [k, v] of Object.entries(words)) assert.equal(ar(k), v, k);

// Articles: joined, standalone, hyphenated, and the other prefixed forms.
assert.equal(ar("elbeit"), "البيت");
assert.equal(ar("el-sa3a"), "الساعة");
assert.equal(ar("fel beit"), "في البيت");
assert.equal(ar("elly"), "اللي", "dictionary beats the article rule");

// Case, punctuation and spacing are kept around the words.
assert.equal(ar("El Sa3a KAM"), "الساعة كام");
assert.equal(ar("sa7?"), "صح?");
assert.equal(ar("(mesh 3aref)"), "(مش عارف)");
assert.equal(ar("ana,  enta!\nmesh keda"), "انا,  انت!\nمش كده");

// Text without Latin letters passes through untouched.
assert.equal(ar("مرحبا يا sa7"), "مرحبا يا صح");
assert.equal(ar("123 456"), "123 456");
assert.equal(ar(""), "");
assert.equal(ar("constructor"), "كنستروكتر", "built-in object keys are not dictionary words");

// looksLikeFranco
for (const s of ["ezayak 3amel eh", "ana 2olt keda", "sa7", "mesh 3aref", "el sa3a kam", "yalla bina", "inshallah", "7abibi"])
  assert.equal(franco.looksLikeFranco(s), true, s);
for (const s of ["hello world", "lvpfh", "hgsghl ugd;l", "I love mesh networks", "Ana is here", "the 3rd floor",
  "send me the mp3", "مرحبا", "123", ""])
  assert.equal(franco.looksLikeFranco(s), false, s);

console.log("all franco ok");
