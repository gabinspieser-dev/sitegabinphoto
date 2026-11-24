/* Séries photographiques (24-25/11/2026) — petit script commun, sans bibliothèque.
   1. dévoilement des photos sous la ligne de flottaison (une seule fois) ;
   2. séquences : un cadre fixe dont l'image change au fil du défilement (instants successifs d'un même geste) ;
   3. compteur « 07 / 19 » et rail de progression qui suivent la photo la plus visible ;
   4. scènes : le fond de page prend en douceur les couleurs de la scène en cours (préparées d'avance,
      aucun calcul de couleur pendant le défilement).
   Rien ne bouge si le visiteur a demandé moins d'animations dans son système.
   Sans ce script, tout reste visible et chaque scène garde son propre fond. */
(() => {
  'use strict';
  const root = document.documentElement;
  const reduce = window.matchMedia('(prefers-reduced-motion: reduce)');
  const calm = () => reduce.matches;
  root.classList.add('serie-js');
  root.classList.toggle('serie-calme', calm());
  if (reduce.addEventListener) reduce.addEventListener('change', () => root.classList.toggle('serie-calme', calm()));
  const scenes = Array.from(document.querySelectorAll('.sc[data-sc]'));
  if (scenes.length) root.classList.add('sc-js');
  const photos = Array.from(document.querySelectorAll('.serie .serie-photo, .serie .sc-photo'));
  if (!photos.length || !('IntersectionObserver' in window)) { root.classList.remove('sc-js'); return; }

  /* 1. Dévoilement */
  if (!calm()) {
    const fold = window.innerHeight;
    const reveal = new IntersectionObserver((entries) => {
      entries.forEach((entry) => {
        if (!entry.isIntersecting) return;
        entry.target.classList.add('est-vu');
        entry.target.classList.remove('est-cache');
        reveal.unobserve(entry.target);
      });
    }, { rootMargin: '0px 0px -10% 0px' });
    photos.forEach((fig) => {
      if (fig.closest('.serie-seq-cadre') || fig.getBoundingClientRect().top < fold) return;
      fig.classList.add('est-cache');
      reveal.observe(fig);
    });
    // L'accès aux photos ne dépend jamais de l'animation : à l'impression, tout est montré.
    window.addEventListener('beforeprint', () => photos.forEach((fig) => { fig.classList.remove('est-cache'); fig.classList.add('est-vu'); }));
  }

  /* 2. Séquences */
  const sequences = Array.from(document.querySelectorAll('.serie-plan--sequence'));
  const active = new Set();
  let ticking = false;
  function update() {
    ticking = false;
    if (root.classList.contains('serie-calme')) return;
    active.forEach((plan) => {
      const frames = plan.querySelectorAll('.serie-seq-cadre > .serie-photo, .serie-seq-cadre > .sc-photo');
      const marks = plan.querySelectorAll('.serie-seq-reperes li');
      const rect = plan.getBoundingClientRect();
      const run = Math.max(1, rect.height - window.innerHeight);
      const p = Math.min(0.999, Math.max(0, -rect.top / run));
      const index = Math.floor(p * frames.length);
      frames.forEach((f, i) => f.classList.toggle('is-actif', i === index));
      marks.forEach((m, i) => m.classList.toggle('is-actif', i === index));
    });
  }
  function onScroll() { if (!ticking) { ticking = true; window.requestAnimationFrame(update); } }
  if (sequences.length) {
    sequences.forEach((plan) => {
      const first = plan.querySelector('.serie-seq-cadre > .serie-photo, .serie-seq-cadre > .sc-photo');
      if (first) first.classList.add('is-actif');
      const marks = plan.querySelector('.serie-seq-reperes li');
      if (marks) marks.classList.add('is-actif');
    });
    const watch = new IntersectionObserver((entries) => {
      entries.forEach((entry) => { if (entry.isIntersecting) active.add(entry.target); else active.delete(entry.target); });
      update();
    });
    sequences.forEach((plan) => watch.observe(plan));
    window.addEventListener('scroll', onScroll, { passive: true });
    window.addEventListener('resize', onScroll, { passive: true });
  }

  /* 3. Compteur et rail */
  const counter = document.querySelector('.serie-compteur');
  const rail = document.querySelector('.sc-rail');
  const railLinks = rail ? Array.from(rail.querySelectorAll('a')) : [];
  if (counter || rail) {
    const total = String(photos.length).padStart(2, '0');
    const opening = document.querySelector('.serie-ouverture, .sc--ouverture');
    const ratios = new Map();
    const seen = new IntersectionObserver((entries) => {
      entries.forEach((entry) => ratios.set(entry.target, entry.intersectionRatio));
      let best = null; let max = 0;
      ratios.forEach((r, el) => {
        if (el.closest('.serie-seq-cadre') && !el.classList.contains('is-actif')) return;
        if (r > max) { max = r; best = el; }
      });
      if (!best || max <= 0.2) return;
      const n = best.querySelector('.serie-num');
      if (n && counter) counter.textContent = `${n.textContent} / ${total}`;
      railLinks.forEach((a) => {
        if (a.getAttribute('href') === `#${best.id}`) a.setAttribute('aria-current', 'true'); else a.removeAttribute('aria-current');
      });
    }, { threshold: [0, 0.2, 0.5, 0.8] });
    photos.forEach((fig) => seen.observe(fig));
    if (opening) {
      new IntersectionObserver((entries) => {
        const away = !entries[0].isIntersecting;
        if (counter) counter.classList.toggle('est-visible', away);
        if (rail) rail.classList.toggle('est-visible', away);
      }).observe(opening);
    }
  }

  /* 4. Scènes : le calque de fond prend les couleurs de la scène qui traverse le milieu de l'écran */
  const layer = document.querySelector('.sc-fond');
  if (layer && scenes.length) {
    const apply = (sc) => {
      const cs = window.getComputedStyle(sc);
      layer.style.setProperty('--fg', cs.getPropertyValue('--g').trim());
      layer.style.setProperty('--fd', cs.getPropertyValue('--d').trim());
      layer.style.setProperty('--fh', cs.getPropertyValue('--h').trim());
      const side = sc.classList.contains('sc--ouverture') ? (sc.dataset.cote === 'gauche' ? 'gauche' : 'droite')
        : sc.classList.contains('sc--asym') ? (sc.dataset.cote === 'droite' ? 'droite' : 'gauche') : 'centre';
      layer.dataset.cote = side;
    };
    apply(scenes[0]);
    const band = new IntersectionObserver((entries) => {
      entries.forEach((entry) => { if (entry.isIntersecting) apply(entry.target); });
    }, { rootMargin: '-48% 0px -48% 0px' });
    scenes.forEach((sc) => band.observe(sc));
  }
})();
