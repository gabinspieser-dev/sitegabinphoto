'use strict';
(() => {
  const header = document.querySelector('.site-header');
  if (!header) return;
  const button = header.querySelector('[data-nav-toggle]');
  const navigation = header.querySelector('.main-nav');
  if (!button || !navigation || button.getAttribute('aria-controls') !== navigation.id) return;

  const phone = window.matchMedia('(max-width: 650px)');
  const label = button.querySelector('.nav-toggle-label');
  let open = false;

  function setOpen(next, returnFocus = false) {
    open = phone.matches && next;
    button.setAttribute('aria-expanded', String(open));
    button.setAttribute('aria-label', open ? 'Fermer le menu' : 'Ouvrir le menu');
    if (label) label.textContent = open ? 'Fermer' : 'Menu';
    navigation.hidden = phone.matches && !open;
    if (returnFocus && phone.matches) button.focus();
  }

  // Sans cette amélioration, tous les liens de navigation restent accessibles.
  header.classList.add('nav-enhanced');
  setOpen(false);
  button.addEventListener('click', () => setOpen(!open));
  navigation.addEventListener('click', (event) => {
    if (event.target instanceof Element && event.target.closest('a')) setOpen(false);
  });
  document.addEventListener('keydown', (event) => {
    if (event.key === 'Escape' && open) {
      event.preventDefault();
      setOpen(false, true);
    }
  });
  document.addEventListener('click', (event) => {
    if (open && event.target instanceof Node && !header.contains(event.target)) setOpen(false);
  });
  phone.addEventListener('change', () => {
    const focusedLink = navigation.contains(document.activeElement);
    setOpen(false, focusedLink);
  });
})();
