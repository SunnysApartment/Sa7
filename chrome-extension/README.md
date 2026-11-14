# Sa7 | صح for Chrome

Fixes text typed with the wrong keyboard layout (`lvpfh` → `مرحبا`, `اثممخ` → `hello`) and Franco-Arabic (`ezayak 3amel eh` → `ازيك عامل ايه`) inside any text box on any page: `<input>`, `<textarea>` and rich editors (`contenteditable`). Free and open source (MIT), by Khaled Omar.

## Install

1. Get `Sa7-chrome.zip` (or build it, below) and unzip it into a folder you'll keep.
2. Open `chrome://extensions` and switch on **Developer mode** (top right).
3. Click **Load unpacked** and pick the unzipped folder.

Also works in other Chromium browsers (Edge, Brave, Arc, Opera).

## Use

- **Shortcut:** select the wrong text, or put the cursor right after the wrong word, and press **Alt+Shift+K** (on Mac **⌥ Option+Shift+K**). Change it at `chrome://extensions/shortcuts`.
- **Right-click** in a text box › **Fix with Sa7 / صحّح بـ Sa7**.
- **Toolbar button:** a try-box. Paste text, get the fixed version, press Copy.

With nothing selected, Sa7 fixes the word before the cursor (spaces typed after it are skipped). The fix goes through the browser's own editing command, so **Ctrl/⌘+Z undoes it** and sites like Gmail, WhatsApp Web and React apps see the change.

Text that looks like Franco-Arabic (Arabic written in Latin letters, often with 2, 3, 5, 7 for sounds) is transliterated to Arabic; everything else is converted between the Arabic PC keyboard and English QWERTY, whichever way the text needs.

## Privacy

No data leaves your browser. Sa7 has no server, no analytics and makes no network requests. It only reads a page when you press the shortcut or use the menu (Chrome's `activeTab` permission), and then only the text box you're in. Permissions: `activeTab`, `scripting`, `contextMenus`; no access to any site until you ask.

## Build

```sh
./chrome-extension/build.sh
```

Copies `sa7-site/convert.js` and `sa7-site/franco.js` in, makes the icons from `mac/Resources/icon-1024.png` (with macOS `sips`), runs the tests and writes `chrome-extension/dist/Sa7-chrome.zip`. After a build, the `chrome-extension/` folder itself can also be loaded unpacked.

Tests: `node chrome-extension/test.js` (uses `sa7-site/convert.js` and a stand-in for `franco.js`).

## Limitations

- Pages Chrome keeps extensions out of (`chrome://` pages, the Chrome Web Store, the PDF viewer) can't be fixed.
- The shortcut works on the page's main frame; editors inside an iframe from another site (some embedded comment boxes) only work through the right-click menu, and not always.
- Rich editors that draw their own text (Google Docs, some canvas editors) don't expose a normal text box, so the in-page fix doesn't reach them; use the toolbar try-box there.
- Keyboard conversion uses the Arabic PC (101) layout, like the website.

## Chrome Web Store

Publishing to the Chrome Web Store needs a developer account with a one-time registration fee (USD 5). Until then, install with Load unpacked as above.
