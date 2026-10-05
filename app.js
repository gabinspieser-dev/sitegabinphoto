'use strict';
(() => {
  const year = document.querySelector('#year');
  if (year) year.textContent = new Date().getFullYear();
  const dialog = document.querySelector('#lightbox');
  const links = Array.from(document.querySelectorAll('a[data-photo]'));
  if (!dialog || typeof dialog.showModal !== 'function' || !links.length) return;
  const image = dialog.querySelector('#lightbox-image');
  const status = dialog.querySelector('#image-status');
  const counter = dialog.querySelector('#image-counter');
  const title = dialog.querySelector('#lightbox-title');
  const artist = dialog.querySelector('#lightbox-artist');
  const stage = dialog.querySelector('.lightbox-photo-stage');
  const details = dialog.querySelector('#lightbox-details');
  let current = 0;
  let opener;
  let savedOverflow = '';
  let request = 0;
  let statusTimer;

  function showPhoto(index) {
    current = (index + links.length) % links.length;
    const link = links[current];
    const token = ++request;
    clearTimeout(statusTimer);
    image.hidden = true;
    status.hidden = true;
    image.removeAttribute('src');
    image.alt = link.querySelector('img').alt;
    title.textContent = link.dataset.title;
    // Crédit lié à cette photo seulement : aucune recherche ni attribution automatique.
    if (artist && stage && details) {
      const caption = link.closest('figure').querySelector('.photo-caption');
      const name = caption?.querySelector('.artist-name');
      if (artist.contains(document.activeElement)) {
        (name ? details : dialog.querySelector('#close-lightbox')).focus({ preventScroll: true });
      }
      artist.replaceChildren();
      artist.hidden = !name;
      details.hidden = !name;
      stage.classList.remove('is-caption-open', 'is-caption-dismissed');
      details.setAttribute('aria-expanded', 'false');
      if (name) {
        ['.artist-name', '.artist-event', '.artist-links'].forEach(selector => {
          const node = caption.querySelector(selector);
          if (node) artist.append(node.cloneNode(true));
        });
        details.setAttribute('aria-label', `Informations sur ${name.textContent}`);
      }
    }
    counter.textContent = `${String(current + 1).padStart(2, '0')} / ${String(links.length).padStart(2, '0')}`;
    statusTimer = setTimeout(() => {
      if (token !== request) return;
      status.textContent = 'Chargement de la photographie…';
      status.hidden = false;
    }, 350);
    const preload = new Image();
    preload.onload = () => {
      if (token !== request) return;
      clearTimeout(statusTimer);
      image.src = link.href;
      image.hidden = false;
      status.hidden = true;
    };
    preload.onerror = () => {
      if (token !== request) return;
      clearTimeout(statusTimer);
      status.textContent = 'Cette photo n’a pas pu se charger. Passez à la suivante ou réessayez en ouvrant l’image depuis la galerie.';
      status.hidden = false;
    };
    preload.src = link.href;
  }

  function openPhoto(index, trigger) {
    if (dialog.open) return;
    opener = trigger;
    savedOverflow = document.body.style.overflow;
    showPhoto(index);
    dialog.showModal();
    document.body.style.overflow = 'hidden';
  }

  links.forEach((link, index) => {
    link.setAttribute('aria-haspopup', 'dialog');
    link.addEventListener('click', event => {
      if (event.button !== 0 || event.ctrlKey || event.metaKey || event.shiftKey || event.altKey) return;
      event.preventDefault();
      openPhoto(index, link);
    });
    link.closest('figure').querySelector('[data-photo-expand]')?.addEventListener('click', event => {
      // La légende se masque à l'ouverture : rendre ensuite le focus à la photo.
      openPhoto(index, link);
    });
  });
  if (details && stage) {
    details.addEventListener('click', () => {
      const open = !stage.classList.contains('is-caption-open');
      stage.classList.toggle('is-caption-open', open);
      stage.classList.toggle('is-caption-dismissed', !open);
      details.setAttribute('aria-expanded', String(open));
    });
    stage.addEventListener('pointerenter', event => {
      if (event.pointerType === 'mouse') stage.classList.remove('is-caption-dismissed');
    });
    dialog.addEventListener('keydown', event => {
      if (event.key !== 'Escape' || artist.hidden || getComputedStyle(artist).visibility !== 'visible') return;
      event.preventDefault();
      details.focus({ preventScroll: true });
      stage.classList.remove('is-caption-open');
      stage.classList.add('is-caption-dismissed');
      details.setAttribute('aria-expanded', 'false');
    });
  }
  dialog.querySelector('#close-lightbox').addEventListener('click', () => dialog.close());
  dialog.querySelector('#previous').addEventListener('click', () => showPhoto(current - 1));
  dialog.querySelector('#next').addEventListener('click', () => showPhoto(current + 1));
  dialog.addEventListener('keydown', event => {
    if (event.key === 'ArrowRight' || event.key === 'ArrowLeft') {
      event.preventDefault();
      showPhoto(current + (event.key === 'ArrowRight' ? 1 : -1));
    }
  });
  dialog.addEventListener('close', () => {
    ++request;
    clearTimeout(statusTimer);
    document.body.style.overflow = savedOverflow;
    opener?.focus({ preventScroll: true });
  });
})();
