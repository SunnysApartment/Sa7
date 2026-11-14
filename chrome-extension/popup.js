const t = (key, sub) => chrome.i18n.getMessage(key, sub);
document.documentElement.lang = t("@@ui_locale").replace("_", "-");
document.documentElement.dir = t("@@bidi_dir");
for (const el of document.querySelectorAll("[data-i18n]")) el.textContent = t(el.dataset.i18n);
for (const el of document.querySelectorAll("[data-i18n-placeholder]")) el.placeholder = t(el.dataset.i18nPlaceholder);

const input = document.getElementById("in"), output = document.getElementById("out"), copy = document.getElementById("copy");

input.addEventListener("input", () => {
  output.value = input.value ? sa7Fix(input.value) : "";
  copy.disabled = !output.value;
  copy.textContent = t("copy");
});

copy.addEventListener("click", async () => {
  await navigator.clipboard.writeText(output.value);
  copy.textContent = t("copied");
});

chrome.commands.getAll(commands => {
  const key = commands.find(c => c.name === "fix-text")?.shortcut || t("noShortcut");
  document.getElementById("hint").textContent = t("shortcutHint", [key]);
});

document.getElementById("shortcuts").addEventListener("click", e => {
  e.preventDefault();
  chrome.tabs.create({ url: "chrome://extensions/shortcuts" });
});
