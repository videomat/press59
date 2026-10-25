// Turns a release's notes (release-notes/<version>.md) into HTML for Sparkle's update window.
// Only the Markdown the notes use: paragraphs, "- " lists, **bold**, `code` and [links](https://…).

function escape(text) {
  return text
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');
}

function inline(text) {
  return escape(text)
    .replace(/\*\*(.+?)\*\*/g, '<strong>$1</strong>')
    .replace(/`(.+?)`/g, '<code>$1</code>')
    .replace(/\[(.+?)\]\((https?:\/\/[^\s)]+)\)/g, '<a href="$2">$1</a>');
}

export function notesHTML(markdown) {
  const blocks = markdown.trim().split(/\n\s*\n/);
  const body = blocks.map((block) => {
    const lines = block.split('\n').map((line) => line.trim()).filter(Boolean);
    if (lines.every((line) => line.startsWith('- '))) {
      return `<ul>${lines.map((line) => `<li>${inline(line.slice(2))}</li>`).join('')}</ul>`;
    }
    return `<p>${inline(lines.join(' '))}</p>`;
  }).join('\n');
  // Sparkle shows this in a web view: use the system font, and dark text colors in Dark Mode.
  return `<meta name="color-scheme" content="light dark">
<style>body { font: 13px -apple-system, sans-serif; line-height: 1.45; } ul { padding-left: 1.2em; } li { margin: 0.3em 0; }</style>
${body}`;
}
