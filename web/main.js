// Interactive keyboard demo: click a key to see which app ⇪ + key opens.
const apps = {
  c: 'Chrome', s: 'Slack', f: 'Figma', t: 'Terminal', n: 'Notes', m: 'Mail',
  x: 'Xcode', z: 'Zoom', w: 'WhatsApp', p: 'Photos', l: 'Lightroom', a: 'Arc',
  g: 'GarageBand', o: 'Obsidian', k: 'Keynote',
};
const rows = [
  { keys: 'qwertyuiop', indent: 0 },
  { keys: 'asdfghjkl', indent: 28 },
  { keys: 'zxcvbnm', indent: 64 },
];

const keyboard = document.getElementById('keyboard');
const readoutLetter = document.getElementById('readout-letter');
const readoutApp = document.getElementById('readout-app');

function select(letter) {
  keyboard.querySelectorAll('.key').forEach((key) => {
    key.setAttribute('aria-pressed', String(key.dataset.letter === letter));
  });
  readoutLetter.textContent = letter.toUpperCase();
  readoutApp.textContent = apps[letter] || 'Not assigned yet';
}

for (const row of rows) {
  const rowElement = document.createElement('div');
  rowElement.className = 'key-row';
  rowElement.style.paddingLeft = `${row.indent}px`;
  for (const letter of row.keys) {
    const app = apps[letter];
    const key = document.createElement('button');
    key.type = 'button';
    key.className = app ? 'cap key' : 'cap key unassigned';
    key.dataset.letter = letter;
    key.setAttribute('aria-label', `${letter.toUpperCase()} ${app ? `opens ${app}` : 'is not assigned'}`);
    const label = document.createElement('span');
    label.textContent = letter.toUpperCase();
    const appLabel = document.createElement('span');
    appLabel.className = 'key-app';
    appLabel.textContent = app || '—';
    key.append(label, appLabel);
    key.addEventListener('click', () => select(letter));
    rowElement.append(key);
  }
  keyboard.append(rowElement);
}

select('c');

// Show the latest release's version and size under the download buttons.
// latest.json comes from R2 (see functions/latest.json.js); without it the default text stays.
async function showLatestRelease() {
  try {
    const response = await fetch('/latest.json', { headers: { accept: 'application/json' } });
    if (!response.ok) return;
    const release = await response.json();
    if (!release.version || !Number.isFinite(release.size)) return;
    const megabytes = (release.size / 1_000_000).toFixed(1);
    for (const element of document.querySelectorAll('[data-release-info]')) {
      element.textContent = `Version ${release.version} · ${megabytes} MB · macOS 14 or later`;
    }
  } catch {
    // Keep the default text when the release info can't be loaded.
  }
}

showLatestRelease();

// Pass on where the visitor came from, so /download can count which channels lead to downloads.
// A ?ref= tag on the page wins over the referring site; nothing is stored in the browser.
function downloadChannel() {
  const ref = new URLSearchParams(location.search).get('ref');
  if (ref) return ref;
  try {
    const host = new URL(document.referrer).hostname;
    return host === location.hostname ? null : host;
  } catch {
    return null;
  }
}

const channel = downloadChannel();
if (channel) {
  for (const link of document.querySelectorAll('a[href="/download"]')) {
    link.href = `/download?ref=${encodeURIComponent(channel)}`;
  }
}
