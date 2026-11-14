// Same rules as the desktop apps: the majority script picks the direction, longest key match wins.
// shortcut: fixed Arabic 101 / Arabic PC table, the apps read the installed layout from the OS instead.
const convert = (() => {
  const en = [..."qwertyuiop[]asdfghjkl;'`zxcvnm,./"];
  const ar = [..."ضصثقفغعهخحجدشسيبلاتنمكطذئءؤرىةوزظ"];
  const toArabic = Object.fromEntries(en.map((k, i) => [k, ar[i]]));
  Object.assign(toArabic, {
    b: "لا", Q: "َ", W: "ً", E: "ُ", R: "ٌ", T: "لإ", Y: "إ", U: "‘",
    I: "÷", O: "×", P: "؛", "{": "<", "}": ">", A: "ِ", S: "ٍ", D: "]", F: "[",
    G: "لأ", H: "أ", J: "ـ", K: "،", L: "/", Z: "~", X: "ْ", C: "}", V: "{",
    B: "لآ", N: "آ", M: "’", "<": ",", ">": ".", "?": "؟", "~": "ّ"
  });
  const toEnglish = Object.fromEntries(Object.entries(toArabic).map(([k, v]) => [v, k]));

  const map = (text, table) => {
    const c = Array.from(text);
    let out = "";
    for (let i = 0; i < c.length; i++) {
      const two = c[i] + (c[i + 1] ?? "");
      if (table[two]) { out += table[two]; i++; }
      else out += table[c[i]] ?? c[i];
    }
    return out;
  };

  const fix = text => {
    const latin = text.replace(/[^A-Za-z]/g, "");
    const arabic = text.replace(/[^؀-ۿ]/g, "");
    if (latin.length <= arabic.length) return map(text, toEnglish);
    // All capitals almost always means Caps Lock was on, not Shift.
    const capsOn = latin.length >= 2 && latin === latin.toUpperCase();
    return map(capsOn ? text.toLowerCase() : text, toArabic);
  };
  return Object.assign(fix, { toArabic, toEnglish });
})();

if (typeof module !== "undefined") module.exports = convert;
