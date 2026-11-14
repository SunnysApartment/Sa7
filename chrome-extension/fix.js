// Shared by the popup, the injected page script and test.js. Expects the globals `convert`
// (sa7-site/convert.js) and, optionally, `franco` (sa7-site/franco.js) to be loaded first.

// [start, end] of the word just before the caret, skipping spaces typed after it.
// Any non-space counts as part of the word: wrong-layout punctuation (, ; [ ') is real letters.
function sa7WordRange(text, caret) {
  let end = caret;
  while (end > 0 && /\s/.test(text[end - 1])) end--;
  let start = end;
  while (start > 0 && !/\s/.test(text[start - 1])) start--;
  return [start, end];
}

function sa7Fix(text) {
  if (typeof franco !== "undefined" && franco.looksLikeFranco(text)) return franco.toArabic(text);
  return convert(text);
}

// Replaces the selection (or the word before the caret) in the focused field of the page.
// execCommand keeps the page's undo stack and fires the events frameworks listen to.
function sa7FixFocused() {
  let el = document.activeElement;
  while (el && el.shadowRoot && el.shadowRoot.activeElement) el = el.shadowRoot.activeElement;
  if (!el) return false;

  if ((el.tagName === "TEXTAREA" || el.tagName === "INPUT") && el.type !== "password" && !el.readOnly) {
    let s, e;
    try { s = el.selectionStart; e = el.selectionEnd; } catch { return false; }
    if (s == null) return false; // input types without a caret (email, number…)
    if (s === e) [s, e] = sa7WordRange(el.value, s);
    const before = el.value.slice(s, e), fixed = sa7Fix(before);
    if (!before || fixed === before) return false;
    el.setSelectionRange(s, e);
    if (!document.execCommand("insertText", false, fixed)) {
      el.setRangeText(fixed, s, e, "end");
      el.dispatchEvent(new InputEvent("input", { bubbles: true, inputType: "insertReplacementText", data: fixed }));
    }
    return true;
  }

  if (!el.isContentEditable) return false;
  const sel = getSelection();
  if (!sel.rangeCount) return false;
  let range = sel.getRangeAt(0).cloneRange();
  if (range.collapsed) {
    let node = range.startContainer, offset = range.startOffset;
    // Caret right after a text node (e.g. at the end of a line) sits on the parent element.
    if (node.nodeType === 1 && offset > 0 && node.childNodes[offset - 1].nodeType === 3) {
      node = node.childNodes[offset - 1];
      offset = node.data.length;
    }
    // shortcut: only looks inside the caret's own text node, words split across styled spans are partly fixed.
    if (node.nodeType !== 3) return false;
    const [s, e] = sa7WordRange(node.data, offset);
    range = document.createRange();
    range.setStart(node, s);
    range.setEnd(node, e);
  }
  const before = range.toString(), fixed = sa7Fix(before);
  if (!before || fixed === before) return false;
  sel.removeAllRanges();
  sel.addRange(range);
  if (!document.execCommand("insertText", false, fixed)) {
    range.deleteContents();
    const t = document.createTextNode(fixed);
    range.insertNode(t);
    sel.collapse(t, t.length);
    el.dispatchEvent(new InputEvent("input", { bubbles: true, inputType: "insertReplacementText", data: fixed }));
  }
  return true;
}

if (typeof module !== "undefined") module.exports = { sa7WordRange, sa7Fix };
