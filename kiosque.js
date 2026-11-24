/* Le kiosque — page d'entrée des séries (25/11/2026), sans bibliothèque.
   1. Le fond de page prend les couleurs de la couverture survolée, touchée ou au centre de l'écran.
   2. Souris : la couverture s'incline légèrement vers le pointeur.
   3. Téléphone : la couverture au centre de l'écran montre sa seconde image.
   Rien ne bouge si le visiteur a demandé moins d'animations dans son système.
   Sans ce script, chaque couverture reste un simple lien et la seconde image apparaît au survol (CSS). */
(() => {
  'use strict';
  const layer = document.querySelector('.kq-fond');
  const covers = Array.from(document.querySelectorAll('.kq-couv'));
  if (!layer || !covers.length) return;
  const reduce = window.matchMedia('(prefers-reduced-motion: reduce)');
  const calm = () => reduce.matches;
  const touch = window.matchMedia('(hover: none)');

  /* 1. Couleurs du fond */
  const apply = (cover) => {
    const cs = window.getComputedStyle(cover);
    layer.style.setProperty('--fg', cs.getPropertyValue('--g').trim());
    layer.style.setProperty('--fd', cs.getPropertyValue('--d').trim());
    layer.style.setProperty('--fh', cs.getPropertyValue('--h').trim());
  };
  covers.forEach((cover) => {
    cover.addEventListener('pointerenter', () => apply(cover));
    cover.addEventListener('focusin', () => apply(cover));
  });

  /* 3. Au défilement : la couverture qui traverse le milieu de l'écran */
  if ('IntersectionObserver' in window) {
    const band = new IntersectionObserver((entries) => {
      entries.forEach((entry) => {
        if (!entry.isIntersecting) { entry.target.classList.remove('kq-actif'); return; }
        apply(entry.target);
        if (touch.matches && !calm()) entry.target.classList.add('kq-actif');
      });
    }, { rootMargin: '-45% 0px -45% 0px' });
    covers.forEach((cover) => band.observe(cover));
  }

  /* 2. Inclinaison vers le pointeur (souris seulement) */
  covers.forEach((cover) => {
    cover.addEventListener('pointermove', (event) => {
      if (event.pointerType !== 'mouse' || calm()) return;
      const r = cover.getBoundingClientRect();
      const x = (event.clientX - r.left) / r.width - 0.5;
      const y = (event.clientY - r.top) / r.height - 0.5;
      cover.style.setProperty('--ry', `${(x * 5).toFixed(2)}deg`);
      cover.style.setProperty('--rx', `${(-y * 5).toFixed(2)}deg`);
    });
    cover.addEventListener('pointerleave', () => {
      cover.style.removeProperty('--rx');
      cover.style.removeProperty('--ry');
    });
  });
})();
