const $ = s => document.querySelector(s);
const arabicPage = document.documentElement.lang === "ar";
const say = (en, ar) => (arabicPage ? ar : en);

// Hero: the wrong word is struck out in chalk, the right one written under it,
// and the keys on the tray light up the other letter they always carried.
const demo = $("#demo"), keys = $("#keys");
const examples = arabicPage ? ["lvpfh", "a;vh", "اثممخ", "wp"] : ["lvpfh", "اثممخ", "a;vh", "wp"];
const calm = matchMedia("(prefers-reduced-motion: reduce)").matches;
let current = 0, timer;

const caps = word => {
  const toArabic = /[A-Za-z;,.[\]'`/]/.test(word);
  keys.dir = toArabic ? "rtl" : "ltr"; // keys read in the order of the corrected word
  keys.replaceChildren(...Array.from(word, (c, i) => {
    const en = toArabic ? c : convert.toEnglish[c] ?? c;
    const ar = toArabic ? convert.toArabic[c] ?? c : c;
    const cap = document.createElement("span");
    cap.className = "cap " + (toArabic ? "from-en" : "from-ar");
    cap.style.setProperty("--i", i);
    cap.innerHTML = `<span class="en"></span><span class="ar"></span>`;
    cap.firstChild.textContent = en.toUpperCase();
    cap.lastChild.textContent = ar;
    return cap;
  }));
};

const correct = () => {
  demo.classList.add("done");
  keys.classList.add("done");
  if (!calm) timer = setTimeout(() => show(current + 1), 3200);
};
const show = n => {
  clearTimeout(timer);
  current = n % examples.length;
  demo.classList.remove("done");
  keys.classList.remove("done");
  $("#bad").textContent = examples[current];
  $("#good").textContent = convert(examples[current]);
  caps(examples[current]);
  timer = setTimeout(correct, calm ? 0 : 1200);
};
$("#press").onclick = () => {
  if (demo.classList.contains("done")) return show(current + 1);
  clearTimeout(timer);
  correct();
};
show(0);

// The board leans gently toward the pointer. Eased every frame toward the target (critically damped feel),
// so it can be redirected at any moment and settles without overshoot.
const tilt = $(".tilt"), board = $(".board");
if (!calm && matchMedia("(pointer: fine)").matches) {
  let tx = 0, ty = 0, x = 0, y = 0, frame = 0;
  const step = () => {
    x += (tx - x) * 0.1;
    y += (ty - y) * 0.1;
    tilt.style.setProperty("--rx", (-y * 5).toFixed(2) + "deg");
    tilt.style.setProperty("--ry", (x * 7).toFixed(2) + "deg");
    board.style.setProperty("--gx", (50 + x * 90).toFixed(1) + "%");
    frame = Math.abs(tx - x) + Math.abs(ty - y) > 0.0005 ? requestAnimationFrame(step) : 0;
  };
  addEventListener("pointermove", e => {
    tx = e.clientX / innerWidth - 0.5;
    ty = e.clientY / innerHeight - 0.5;
    if (!frame) frame = requestAnimationFrame(step);
  }, { passive: true });
}

// Try box
const input = $("#input"), output = $("#output"), copy = $("#copy");
// franco.js is optional: Franco (ezayak 3amel eh) becomes Arabic, everything else goes through the key table.
const fix = text => typeof franco !== "undefined" && franco.looksLikeFranco(text) ? franco.toArabic(text) : convert(text);
const update = () => {
  output.textContent = fix(input.value);
  copy.disabled = !input.value;
  copy.textContent = say("Copy", "انسخ");
};
input.addEventListener("input", update);
document.querySelectorAll("[data-example]").forEach(b => b.onclick = () => {
  input.value = b.dataset.example;
  update();
});
document.querySelectorAll("[data-copy]").forEach(b => b.onclick = async () => {
  try {
    await navigator.clipboard.writeText(b.dataset.copy);
    b.textContent = say("Copied", "اتنسخ");
  } catch (e) {
    b.textContent = say("Select it and copy", "حدّد النص وانسخه");
  }
});
copy.onclick = async () => {
  try {
    await navigator.clipboard.writeText(output.textContent);
    copy.textContent = say("Copied", "اتنسخ");
  } catch (e) {
    copy.textContent = say("Select it and copy", "حدّد النص وانسخه");
  }
};
