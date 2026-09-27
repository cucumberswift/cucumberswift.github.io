// Progressive enhancement for cucumberswift.org. Every section works without
// this file: the menu stays open, both install methods show, and the copy
// buttons stay hidden.

document.documentElement.classList.add('js');

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
