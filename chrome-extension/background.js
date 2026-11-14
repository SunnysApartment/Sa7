// Injects the converter into the page only when the user asks (activeTab), then fixes the focused field.
chrome.runtime.onInstalled.addListener(() => {
  chrome.contextMenus.removeAll(() =>
    chrome.contextMenus.create({ id: "fix", title: chrome.i18n.getMessage("menuTitle"), contexts: ["editable"] }));
});

async function fixIn(tabId, frameId = 0) {
  const target = { tabId, frameIds: [frameId] };
  try {
    // The libraries declare top-level consts, so load them once per page or the second run throws.
    const [{ result: loaded }] = await chrome.scripting.executeScript({ target, func: () => typeof sa7FixFocused === "function" });
    if (!loaded) await chrome.scripting.executeScript({ target, files: ["convert.js", "franco.js", "fix.js"] });
    await chrome.scripting.executeScript({ target, func: () => sa7FixFocused() });
  } catch {
    // Pages Chrome won't let extensions touch (chrome://, the Web Store, cross-origin frames): nothing to fix.
  }
}

chrome.commands.onCommand.addListener((command, tab) => {
  if (command === "fix-text" && tab?.id) fixIn(tab.id);
});

chrome.contextMenus.onClicked.addListener((info, tab) => {
  if (info.menuItemId === "fix" && tab?.id) fixIn(tab.id, info.frameId ?? 0);
});
