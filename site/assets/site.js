// Progressive enhancement for cucumberswift.org. Every section works without
// this file: the menu stays open, both install methods show, and the copy
// buttons and the theme button stay hidden.

document.documentElement.classList.add('js');

// Theme button. The page follows the system setting until the visitor picks a
// theme. A pick that matches the system setting is forgotten, so the page
// follows the system again. A script in each page's <head> applies a saved
// pick before the first paint.
const themeButton = document.querySelector('.theme-toggle');
if (themeButton) {
  const root = document.documentElement;
  const systemDark = matchMedia('(prefers-color-scheme: dark)');
  const themeColors = [...document.querySelectorAll('meta[name="theme-color"]')].map((meta) => [meta, meta.content]);
  const systemTheme = () => (systemDark.matches ? 'dark' : 'light');
  const currentTheme = () => root.dataset.theme ?? systemTheme();
  const sync = () => {
    themeButton.setAttribute('aria-pressed', String(currentTheme() === 'dark'));
    const picked = getComputedStyle(root).getPropertyValue('--surface-raised').trim();
    for (const [meta, content] of themeColors) meta.content = root.dataset.theme ? picked : content;
  };
  themeButton.hidden = false;
  sync();
  themeButton.addEventListener('click', () => {
    const next = currentTheme() === 'dark' ? 'light' : 'dark';
    if (next === systemTheme()) delete root.dataset.theme;
    else root.dataset.theme = next;
    try {
      if (root.dataset.theme) localStorage.setItem('theme', next);
      else localStorage.removeItem('theme');
    } catch {}
    sync();
  });
  systemDark.addEventListener('change', sync);
}

// Menu button on narrow screens.
const menuButton = document.querySelector('.menu-toggle');
const nav = document.getElementById('site-nav');
if (menuButton && nav) {
  menuButton.hidden = false;
  const setOpen = (open) => {
    menuButton.setAttribute('aria-expanded', String(open));
    nav.toggleAttribute('data-open', open);
  };
  menuButton.addEventListener('click', () => {
    setOpen(menuButton.getAttribute('aria-expanded') !== 'true');
  });
  nav.addEventListener('click', (event) => {
    if (event.target.closest('a')) setOpen(false);
  });
  document.addEventListener('keydown', (event) => {
    if (event.key === 'Escape' && menuButton.getAttribute('aria-expanded') === 'true') {
      setOpen(false);
      menuButton.focus();
    }
  });
}

// Install tabs.
for (const container of document.querySelectorAll('[data-tabs]')) {
  const list = container.querySelector('[role="tablist"]');
  const tabs = [...container.querySelectorAll('[role="tab"]')];
  const select = (tab, focus) => {
    for (const other of tabs) {
      const selected = other === tab;
      other.setAttribute('aria-selected', String(selected));
      other.tabIndex = selected ? 0 : -1;
      document.getElementById(other.getAttribute('aria-controls')).hidden = !selected;
    }
    if (focus) tab.focus();
  };
  list.hidden = false;
  select(tabs.find((tab) => tab.getAttribute('aria-selected') === 'true') ?? tabs[0], false);
  list.addEventListener('click', (event) => {
    const tab = event.target.closest('[role="tab"]');
    if (tab) select(tab, false);
  });
  list.addEventListener('keydown', (event) => {
    const index = tabs.indexOf(document.activeElement);
    if (index < 0) return;
    const next = {
      ArrowRight: tabs[(index + 1) % tabs.length],
      ArrowLeft: tabs[(index - 1 + tabs.length) % tabs.length],
      Home: tabs[0],
      End: tabs[tabs.length - 1],
    }[event.key];
    if (next) {
      event.preventDefault();
      select(next, true);
    }
  });
}

// Copy buttons on code blocks.
if (navigator.clipboard) {
  for (const block of document.querySelectorAll('[data-copy]')) {
    const button = block.querySelector('.code__copy');
    const label = button?.querySelector('.code__copy-label');
    const code = block.querySelector('pre code');
    if (!button || !label || !code) continue;
    button.hidden = false;
    label.setAttribute('aria-live', 'polite');
    let reset;
    button.addEventListener('click', async () => {
      try {
        await navigator.clipboard.writeText(code.textContent);
        label.textContent = 'Copied';
      } catch {
        label.textContent = 'Copy failed';
      }
      clearTimeout(reset);
      reset = setTimeout(() => { label.textContent = 'Copy'; }, 2000);
    });
  }
}

// Versions. Each package's docs publish /<package>/versions.json on every
// release, so the numbers and the major links update with no change here. If a
// file cannot be read, the page keeps what its HTML says.
const versionFiles = new Map();
const readVersions = (url) => {
  if (!versionFiles.has(url)) {
    versionFiles.set(url, fetch(url).then((response) => (response.ok ? response.json() : Promise.reject(response.status))));
  }
  return versionFiles.get(url);
};
const isVersion = (value) => typeof value === 'string' && /^\d+\.\d+\.\d+$/.test(value);

// Latest version chip in the hero.
const latestVersion = document.querySelector('.latest-version[data-versions]');
if (latestVersion) {
  readVersions(latestVersion.dataset.versions)
    .then(({ version }) => {
      if (!isVersion(version)) return;
      latestVersion.textContent = `Latest version ${version}`;
      latestVersion.href = `https://github.com/cucumberswift/CucumberSwift/releases/tag/${version}`;
    })
    .catch(() => {});
}

// Docs cards: the latest version, and one link per major, newest first.
for (const card of document.querySelectorAll('.doc-card[data-versions]')) {
  const url = card.dataset.versions;
  const base = url.slice(0, url.lastIndexOf('/') + 1);
  readVersions(url)
    .then(({ version, majors }) => {
      if (isVersion(version)) card.querySelector('.doc-card__latest').textContent = `Latest ${version}`;
      const found = (Array.isArray(majors) ? majors : [])
        .filter((m) => /^\d+\.x$/.test(m.major) && isVersion(m.version))
        .sort((a, b) => parseInt(b.major, 10) - parseInt(a.major, 10));
      if (found.length === 0) return;
      // The latest release's major is selected; without it, the newest major.
      const latestMajor = isVersion(version) ? `${parseInt(version, 10)}.x` : found[0].major;
      const current = found.some((m) => m.major === latestMajor) ? latestMajor : found[0].major;
      const label = card.querySelector('.version-menu__current');
      if (label) label.textContent = `v${current}`;
      const list = card.querySelector('.versions');
      list.replaceChildren(...found.map((m) => {
        const link = document.createElement('a');
        link.className = 'version';
        if (m.major === current) link.setAttribute('aria-current', 'true');
        link.href = `${base}${m.major}/documentation/${card.dataset.module}/`;
        link.target = '_blank';
        link.rel = 'noopener';
        link.textContent = `v${m.major}`;
        const hint = document.createElement('span');
        hint.className = 'visually-hidden';
        hint.textContent = ' (opens in a new tab)';
        link.append(hint);
        const item = document.createElement('li');
        item.append(link);
        return item;
      }));
    })
    .catch(() => {});
}

// Version menus close on Escape or a click outside, like any other menu.
const versionMenus = document.querySelectorAll('.version-menu');
document.addEventListener('click', (event) => {
  for (const menu of versionMenus) if (menu.open && !menu.contains(event.target)) menu.open = false;
});
document.addEventListener('keydown', (event) => {
  if (event.key !== 'Escape') return;
  for (const menu of versionMenus) {
    if (!menu.open) continue;
    menu.open = false;
    menu.querySelector('summary').focus();
  }
});
