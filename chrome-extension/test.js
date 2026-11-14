// node chrome-extension/test.js — the pure helpers in fix.js, with a stub standing in for franco.js.
const assert = require("assert");
global.convert = require("../sa7-site/convert.js");
const { sa7WordRange, sa7Fix } = require("./fix.js");

const word = (text, caret = text.length) => text.slice(...sa7WordRange(text, caret));

assert.strictEqual(word("hello lvpfh"), "lvpfh");
assert.strictEqual(word("hello lvpfh  "), "lvpfh", "spaces typed after the word are skipped");
assert.strictEqual(word("first\nlvpfh"), "lvpfh");
assert.strictEqual(word("lvpfh"), "lvpfh");
assert.strictEqual(word("ok hgsghl,", 10), "hgsghl,", "wrong-layout punctuation stays in the word");
assert.strictEqual(word("abc defg", 6), "de", "mid-word caret takes the part before it");
assert.strictEqual(word("مرحبا اثممخ"), "اثممخ");
assert.strictEqual(word(""), "");
assert.strictEqual(word("   "), "");
assert.deepStrictEqual(sa7WordRange("hi lvpfh there", 8), [3, 8]);

// Without franco.js loaded, keyboard conversion only.
assert.strictEqual(sa7Fix("lvpfh"), "مرحبا");
assert.strictEqual(sa7Fix("اثممخ"), "hello");

// With franco.js: Franco wins only when it says the text looks like Franco.
global.franco = { looksLikeFranco: t => /\d/.test(t), toArabic: t => `franco(${t})` };
assert.strictEqual(sa7Fix("ezayak 3amel eh"), "franco(ezayak 3amel eh)");
assert.strictEqual(sa7Fix("lvpfh"), "مرحبا");
assert.strictEqual(sa7Fix("اثممخ"), "hello");

console.log("chrome-extension: all tests passed");
