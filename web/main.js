// Interactive keyboard demo: click a key to see which app ⇪ + key opens.
const apps = {
  c: 'Chrome', s: 'Slack', f: 'Finder', t: 'Terminal', n: 'Notes', m: 'Mail',
  x: 'Xcode', z: 'Zoom', w: 'WhatsApp', p: 'Photos', l: 'Linear', a: 'Arc',
  g: 'Figma', o: 'Obsidian', k: 'Calendar',
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
