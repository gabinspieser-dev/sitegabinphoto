'use strict';
(() => {
  const figures = Array.from(document.querySelectorAll('.interactive-photo'));
  if (!figures.length) return;
  const gallery = document.querySelector('#lightbox');
  if (!gallery || typeof gallery.showModal !== 'function') return;
  const hoverless = window.matchMedia('(hover: none)');
  const touchPointers = new WeakMap();

  function close(figure, dismiss = false) {
    figure.classList.remove('is-caption-open');
    figure.classList.toggle('is-caption-dismissed', dismiss);
  }
  function reveal(figure) {
    figures.forEach(other => { if (other !== figure) close(other, true); });
    figure.classList.remove('is-caption-dismissed');
    figure.classList.add('is-caption-open');
  }

  figures.forEach(figure => {
    const photo = figure.querySelector('.photo-open');
    const expand = figure.querySelector('[data-photo-expand]');
    if (!photo) return;
    if (expand) expand.hidden = false;
    photo.setAttribute('aria-describedby', 'photo-interaction-help');
    figure.addEventListener('pointerenter', event => {
      if (event.pointerType === 'mouse') figure.classList.remove('is-caption-dismissed');
    });
    figure.addEventListener('focusin', () => figure.classList.remove('is-caption-dismissed'));
    figure.addEventListener('focusout', event => {
      if (!figure.contains(event.relatedTarget)) close(figure);
    });
    photo.addEventListener('pointerdown', event => {
      touchPointers.set(photo, { type: event.pointerType, at: Date.now() });
    });
    photo.addEventListener('click', event => {
      if (event.button !== 0 || event.ctrlKey || event.metaKey || event.shiftKey || event.altKey) return;
      // Un clic clavier/programmatique conserve l'ouverture directe de la galerie.
      const pointer = touchPointers.get(photo);
      const touch = event.detail > 0 && (event.pointerType === 'touch' || event.pointerType === 'pen' ||
        (pointer && Date.now() - pointer.at < 1500 && ['touch', 'pen'].includes(pointer.type)) || hoverless.matches);
      if (!touch || figure.classList.contains('is-caption-open')) return;
      event.preventDefault();
      event.stopImmediatePropagation();
      reveal(figure);
    });
    figure.addEventListener('keydown', event => {
      if (event.key !== 'Escape') return;
      event.preventDefault();
      event.stopPropagation();
      // Rendre le focus à la photo avant de cacher les liens de sa légende.
      photo.focus({ preventScroll: true });
      close(figure, true);
    });
  });
  document.addEventListener('pointerdown', event => {
    if (event.target.closest('.interactive-photo')) return;
    figures.forEach(figure => close(figure, true));
  });
})();
