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
      status.textContent = 'Cette photo n’a pas pu se charger. Passe à la suivante ou réessaie en ouvrant l’image depuis la galerie.';
      status.hidden = false;
    };
    preload.src = link.href;
  }

  links.forEach((link, index) => {
    link.setAttribute('aria-haspopup', 'dialog');
    link.addEventListener('click', event => {
      if (event.button !== 0 || event.ctrlKey || event.metaKey || event.shiftKey || event.altKey) return;
      event.preventDefault();
      opener = link;
      savedOverflow = document.body.style.overflow;
      showPhoto(index);
      dialog.showModal();
      document.body.style.overflow = 'hidden';
    });
  });
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
