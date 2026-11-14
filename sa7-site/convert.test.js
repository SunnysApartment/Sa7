// Run: node convert.test.js
const assert = require("node:assert");
const convert = require("./convert.js");

assert.equal(convert("lvpfh"), "مرحبا");
assert.equal(convert("hgsghl ugd;l"), "السلام عليكم");
assert.equal(convert("dgh fdkh"), "يلا بينا");
assert.equal(convert("wp"), "صح");
assert.equal(convert("اثممخ"), "hello");
assert.equal(convert("bh"), "لاا", "lam-alef key");
assert.equal(convert("لا"), "b", "lam-alef reverses as one key");
assert.equal(convert("Hkh"), "أنا", "Shift layer");
assert.equal(convert("LVPFH"), "مرحبا", "all caps means Caps Lock");
assert.equal(convert("lvpfh?"), "مرحبا؟");
assert.equal(convert("123"), "123");
assert.equal(convert(""), "");
console.log("all conversions ok");
