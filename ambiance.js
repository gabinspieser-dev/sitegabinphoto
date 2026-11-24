/* Ambiance éditoriale — interactions communes à toutes les pages (refonte du 18/11/2026).
   Sans bibliothèque. Ne s'active que si la balise <html> porte la classe « amb ».
   - couleur d'accent de chaque photo (calculée d'avance, contraste d'au moins 6:1 sur le fond nuit) ;
   - lueur d'ambiance qui prend la couleur de la photo la plus visible ;
   - panneau « Affichage » : ambiance (Scène, Nuit, Os) et animations (marquées, discrètes, aucune) ;
   - barre de lecture, numéros de section, décor de l'ouverture ;
   - image d'ouverture qui réagit à la souris (profondeur, zoom, lumière) et au doigt ;
   - photos qui glissent légèrement dans leur cadre sous le curseur (jamais au défilement) ;
   - galeries en bande sur téléphone, avec filet de progression ; visionneuse qui suit le doigt ;
   - apparitions des textes au défilement, décor qui suit la souris.
   Tout s'arrête si le visiteur a demandé à réduire les animations. */
(() => {
  'use strict';

  const root = document.documentElement;
  if (!root.classList.contains('amb')) return;

  const reduce = window.matchMedia('(prefers-reduced-motion: reduce)');
  const finePointer = window.matchMedia('(hover: hover) and (pointer: fine)');
  const wide = window.matchMedia('(min-width: 901px)');
  const MOTION = { marquee: 1, discrete: 0.5, none: 0 };
  const motion = () => {
    if (reduce.matches) return 0;
    const m = MOTION[root.dataset.motion];
    return m === undefined ? 1 : m;
  };
  const applyMotion = () => root.style.setProperty('--motion', String(motion()));
  applyMotion();
  if (reduce.addEventListener) reduce.addEventListener('change', applyMotion);
  root.classList.add('amb-js');

  /* Couleur dominante de chaque photo. null = photo sans couleur vive (noir et blanc) : ton os. */
  const NEUTRAL = '#d9d2c7';
  const TONES = {
    'bassiste-de-sun-concert-gabin-spieser-live-18': null,
    'chanteur-electro-symphony-concert-gabin-spieser-live-19': '#ce810e',
    'choriste-danna-winkin-concert-gabin-spieser-live-07': null,
    'cut-capers-concert-gabin-spieser-live-09': '#5d91f1',
    'dela-concert-gabin-spieser-live-15': '#d27664',
    'eben-concert-gabin-spieser-live-14': '#cb7b4c',
    'eda-diaz-concert-gabin-spieser-live-11': '#349eb1',
    'electro-symphony-concert-gabin-spieser-live-13': '#8e81f0',
    'electro-symphony-concert-gabin-spieser-live-20': null,
    'electro-symphony-concert-gabin-spieser-live-21': '#ec51b2',
    'electro-symphony-concert-gabin-spieser-live-22': '#5793e2',
    'electro-symphony-concert-gabin-spieser-live-23': '#8f86f8',
    'electro-symphony-concert-gabin-spieser-live-24': '#cd7954',
    'electro-symphony-concert-gabin-spieser-live-25': '#ea647c',
    'feu-chatterton-concert-gabin-spieser-live-06': null,
    'guitariste-de-rori-concert-gabin-spieser-live-16': null,
    'ina-forsman-concert-gabin-spieser-live-10': null,
    'julien-dore-concert-gabin-spieser-live-04': '#fce57b',
    'lokyto-concert-gabin-spieser-live-02': '#db737e',
    'luiza-concert-gabin-spieser-live-27': '#0292ee',
    'mika-concert-gabin-spieser-live-05': '#d469c8',
    'noa-sax-concert-gabin-spieser-live-08': null,
    'one-night-of-queen-concert-gabin-spieser-live-29': '#149dd5',
    'one-night-of-queen-concert-gabin-spieser-live-30': '#269ca8',
    'one-night-of-queen-concert-gabin-spieser-live-31': '#cb7a4c',
    'one-night-of-queen-concert-gabin-spieser-live-32': null,
    'pixel-syndrome-concert-gabin-spieser-live-26': null,
    'ridsa-concert-gabin-spieser-live-28': null,
    'saxophoniste-electro-symphony-concert-gabin-spieser-live-12': '#c97b46',
    'stomy-bugsy-concert-gabin-spieser-live-01': null,
    'sun-brutal-pop-concert-gabin-spieser-live-17': null,
    'virginie-rohart-concert-gabin-spieser-live-03': '#cd7c53'
  };
  const BY_NUMBER = {};
  Object.keys(TONES).forEach((key) => {
    const n = /live-(\d\d)$/.exec(key);
    if (n) BY_NUMBER[n[1]] = TONES[key];
  });
  const has = (obj, key) => Object.prototype.hasOwnProperty.call(obj, key);
  function toneOf(img) {
    /* Depuis le 24/11/2026 : la couleur est écrite sur la photo par le générateur du portfolio
       (data-tone="#rrggbb", ou "nb" pour une photo en noir et blanc). */
    const own = img.getAttribute('data-tone');
    if (own) return own === 'nb' ? NEUTRAL : own;
    const m = /\/assets\/photos\/([^/?#]+?)(?:-(?:small|medium|large|800))?\.webp/.exec(img.getAttribute('src') || '');
    if (!m) return undefined;
    if (has(TONES, m[1])) return TONES[m[1]] || NEUTRAL;
    const n = /live-(\d\d)$/.exec(m[1]);
    if (n && has(BY_NUMBER, n[1])) return BY_NUMBER[n[1]] || NEUTRAL;
    return undefined;
  }

  /* 1. Chaque photo reçoit sa couleur */
  const toned = [];
  document.querySelectorAll('main img, body > aside img').forEach((img) => {
    const tone = toneOf(img);
    if (!tone) return;
    const holder = img.closest('figure, .live-hero, .service-hero') || img.parentElement;
    if (holder.classList.contains('amb-toned')) return;
    holder.style.setProperty('--tone', tone);
    holder.classList.add('amb-toned');
    toned.push(holder);
  });

  /* 2. Chaque section prend la couleur de sa première photo, sinon celle de la dernière photo vue.
        Une ouverture sans photo prend la couleur de la première photo de la page. */
  let lastTone = toned.length ? toned[0].style.getPropertyValue('--tone') : null;
  document.querySelectorAll('main > section, main > header, main > div, main > article, main > nav, body > aside.social-stage').forEach((section) => {
    const inside = Array.from(section.querySelectorAll('.amb-toned'));
    if (section.classList.contains('amb-toned')) inside.unshift(section);
    if (inside.length) {
      if (!section.classList.contains('amb-toned')) section.style.setProperty('--tone', inside[0].style.getPropertyValue('--tone'));
      lastTone = inside[inside.length - 1].style.getPropertyValue('--tone');
    } else if (lastTone) {
      section.style.setProperty('--tone', lastTone);
    }
  });
  /* Un bloc qui accompagne une photo (citation finale…) prend la couleur de cette photo */
  document.querySelectorAll('.selection-finale').forEach((block) => {
    const first = block.querySelector('.amb-toned');
    if (first) block.style.setProperty('--tone', first.style.getPropertyValue('--tone'));
  });
  if (toned.length) root.style.setProperty('--amb-tone', toned[0].style.getPropertyValue('--tone'));

  /* 3. Lueur d'ambiance : la photo la plus visible donne sa couleur au fond */
  if ('IntersectionObserver' in window && toned.length) {
    const ratios = new Map();
    const glow = new IntersectionObserver((entries) => {
      entries.forEach((entry) => ratios.set(entry.target, entry.intersectionRatio));
      let best = null;
      let max = 0;
      ratios.forEach((ratio, el) => { if (ratio > max) { max = ratio; best = el; } });
      if (best && max > 0.15) {
        const tone = best.style.getPropertyValue('--tone');
        root.style.setProperty('--amb-glow', tone);
        root.style.setProperty('--amb-tone', tone);
      }
    }, { threshold: [0, 0.15, 0.3, 0.5, 0.7, 1] });
    toned.forEach((el) => glow.observe(el));
  }

  /* 4. Logo adapté au fond clair de l'ambiance « Os » */
  const LOGO_DARK = 'gabin-spieser-compact-dark.svg';
  const LOGO_LIGHT = 'gabin-spieser-compact-light.svg';
  function applyLogo() {
    const os = root.dataset.ambiance === 'os';
    document.querySelectorAll('img.brand-logo').forEach((img) => {
      const overPhoto = wide.matches && document.body.classList.contains('page-home') && img.closest('.site-header');
      const want = os && !overPhoto ? LOGO_LIGHT : LOGO_DARK;
      const src = img.getAttribute('src') || '';
      if (src.indexOf(want) === -1) img.setAttribute('src', src.replace(/gabin-spieser-compact-(dark|light)\.svg/, want));
    });
  }
  applyLogo();
  if (wide.addEventListener) wide.addEventListener('change', applyLogo);

  /* 5. Barre de lecture */
  const bar = document.createElement('div');
  bar.className = 'amb-progress';
  bar.setAttribute('aria-hidden', 'true');
  bar.appendChild(document.createElement('span'));
  document.body.appendChild(bar);

  /* 6. Numéros de section géants, repris des surtitres « 01 / … » */
  document.querySelectorAll('main section, main header, body > aside.social-stage').forEach((section) => {
    const span = section.querySelector(':scope > .live-kicker > span, :scope > div > .live-kicker > span, :scope > .eyebrow > span, .live-heading .live-kicker > span, .social-kicker > span');
    const n = span ? span.textContent.trim() : '';
    if (!/^\d{2}$/.test(n) || section.querySelector('.amb-index')) return;
    const p = document.createElement('p');
    p.className = 'amb-index';
    p.setAttribute('aria-hidden', 'true');
    p.textContent = n;
    section.classList.add('amb-has-index');
    section.prepend(p);
  });

  /* 7. Décor de l'ouverture et invitation à défiler */
  const hero = document.querySelector('.live-hero');
  if (hero) {
    [['ring', 18], ['line', -10]].forEach(([kind, depth]) => {
      const shape = document.createElement('span');
      shape.className = 'amb-deco amb-deco--' + kind;
      shape.setAttribute('aria-hidden', 'true');
      shape.style.setProperty('--depth', String(depth));
      hero.appendChild(shape);
    });
    const target = document.querySelector('main section:not(.live-hero) h2[id]');
    if (target) {
      const cue = document.createElement('a');
      cue.className = 'amb-scroll';
      cue.href = '#' + target.id;
      cue.textContent = 'Découvrir';
      hero.appendChild(cue);
    }
  }

  /* 7 bis. L'image d'ouverture réagit : à la souris (profondeur, zoom, lumière, décor) et au doigt */
  const heroImg = hero && hero.querySelector('.live-hero-image');
  if (hero && heroImg) {
    const holder = heroImg.closest('picture') || heroImg.parentElement;
    const light = document.createElement('span');
    light.className = 'amb-hero-light';
    light.setAttribute('aria-hidden', 'true');
    holder.appendChild(light);
    let hx = 0;
    let hy = 0;
    let heroPending = false;
    const paintHero = () => {
      heroPending = false;
      hero.style.setProperty('--hx', hx.toFixed(3));
      hero.style.setProperty('--hy', hy.toFixed(3));
    };
    hero.addEventListener('pointermove', (e) => {
      if (e.pointerType !== 'mouse' || !finePointer.matches || !motion()) return;
      const r = hero.getBoundingClientRect();
      hx = Math.max(-1, Math.min(1, ((e.clientX - r.left) / r.width) * 2 - 1));
      hy = Math.max(-1, Math.min(1, ((e.clientY - r.top) / r.height) * 2 - 1));
      hero.classList.add('is-engaged');
      if (!heroPending) { heroPending = true; window.requestAnimationFrame(paintHero); }
    }, { passive: true });
    hero.addEventListener('pointerleave', (e) => {
      if (e.pointerType !== 'mouse') return;
      hero.classList.remove('is-engaged');
      hx = 0;
      hy = 0;
      window.requestAnimationFrame(paintHero);
    });
    hero.addEventListener('pointerdown', (e) => {
      if (e.pointerType === 'mouse' || !motion() || e.target.closest('a, button')) return;
      const r = holder.getBoundingClientRect();
      if (e.clientY < r.top || e.clientY > r.bottom) return;
      hero.style.setProperty('--tx', (((e.clientX - r.left) / r.width) * 100).toFixed(1) + '%');
      hero.style.setProperty('--ty', (((e.clientY - r.top) / r.height) * 100).toFixed(1) + '%');
      hero.classList.remove('is-touched');
      void hero.offsetWidth; // relance l'effet à chaque toucher
      hero.classList.add('is-touched');
    }, { passive: true });
    light.addEventListener('animationend', () => hero.classList.remove('is-touched'));
  }

  /* 8. Apparitions au défilement : seulement ce qui est encore sous la ligne de flottaison */
  const revealed = [];
  const revealAll = () => revealed.forEach((el) => el.classList.add('is-visible', 'is-done'));
  if ('IntersectionObserver' in window && motion()) {
    const io = new IntersectionObserver((entries) => {
      entries.forEach((entry) => {
        if (!entry.isIntersecting) return;
        const el = entry.target;
        el.classList.add('is-visible');
        io.unobserve(el);
      });
    }, { rootMargin: '0px 0px -8% 0px', threshold: 0.1 });
    const order = new Map();
    const limit = window.innerHeight * 0.92;
    const tag = (el, cls) => {
      if (el.getBoundingClientRect().top < limit) return;
      const parent = el.parentElement;
      const i = order.get(parent) || 0;
      order.set(parent, i + 1);
      el.style.setProperty('--delay', (Math.min(i, 5) * 0.08).toFixed(2) + 's');
      el.classList.add(cls);
      revealed.push(el);
      io.observe(el);
    };
    const skip = '.live-hero, figure, dialog, .cookie-banner, .editorial-links > a, table, details, .legal-nav';
    document.querySelectorAll('main :is(h1, h2, h3, blockquote, .live-kicker, .eyebrow, p, .live-button, .button-link, .live-text-link, .editorial-links > a), body > aside.social-stage :is(h2, .social-kicker, .social-stage-intro, .social-card, .social-stage-note)')
      .forEach((el) => {
        if (el.matches('.caption-sr-only, .amb-index')) return;
        const inside = el.parentElement && el.parentElement.closest(skip);
        if (inside || (el.closest('figure') && !el.matches('.editorial-links > a'))) return;
        tag(el, 'amb-reveal');
      });
    /* Les photos n'ont pas d'animation au défilement : elles ne réagissent qu'au survol. */
  }

  /* 9. Barre de lecture (les photos ne bougent pas au défilement) */
  let ticking = false;
  const frame = () => {
    ticking = false;
    const vh = window.innerHeight;
    const max = document.documentElement.scrollHeight - vh;
    root.style.setProperty('--progress', max > 0 ? Math.min(1, window.scrollY / max).toFixed(4) : '0');
  };
  const request = () => { if (!ticking) { ticking = true; window.requestAnimationFrame(frame); } };
  window.addEventListener('scroll', request, { passive: true });
  window.addEventListener('resize', request);
  request();

  /* 10. Décor qui suit légèrement la souris (jamais au doigt) */
  let mx = 0;
  let my = 0;
  let pending = false;
  window.addEventListener('pointermove', (e) => {
    if (!finePointer.matches || e.pointerType !== 'mouse' || !motion()) return;
    mx = (e.clientX / window.innerWidth) * 2 - 1;
    my = (e.clientY / window.innerHeight) * 2 - 1;
    if (pending) return;
    pending = true;
    window.requestAnimationFrame(() => {
      pending = false;
      root.style.setProperty('--mx', mx.toFixed(3));
      root.style.setProperty('--my', my.toFixed(3));
    });
  }, { passive: true });

  /* 10 bis. Sous le curseur, chaque photo glisse légèrement dans son cadre */
  document.querySelectorAll('.photo-open, .amb-depth').forEach((frame) => {
    let px = 0;
    let py = 0;
    let wait = false;
    frame.addEventListener('pointermove', (e) => {
      if (e.pointerType !== 'mouse' || !finePointer.matches || !motion()) return;
      const r = frame.getBoundingClientRect();
      px = ((e.clientX - r.left) / r.width) * 2 - 1;
      py = ((e.clientY - r.top) / r.height) * 2 - 1;
      if (wait) return;
      wait = true;
      window.requestAnimationFrame(() => {
        wait = false;
        frame.style.setProperty('--px', px.toFixed(3));
        frame.style.setProperty('--py', py.toFixed(3));
      });
    }, { passive: true });
    frame.addEventListener('pointerleave', () => {
      frame.style.setProperty('--px', '0');
      frame.style.setProperty('--py', '0');
    });
  });

  /* 10 ter. Téléphone : galeries en bande que l'on fait glisser au doigt, avec un filet de progression */
  const strips = Array.from(document.querySelectorAll('.home-mosaique, .editorial-gallery:not(.editorial-gallery-single)'));

  /* 10 ter bis. Portfolio sur téléphone : chaque photo reçoit un format dans un rythme éditorial.
     Les classes n'ont d'effet que sous 600 px (voir ambiance.css) ; l'ordre des photos ne change pas. */
  const isWide = (fig) => {
    const img = fig && fig.querySelector('img');
    return !!img && Number(img.getAttribute('width')) > Number(img.getAttribute('height'));
  };
  document.querySelectorAll('.portfolio-masonry').forEach((gallery) => {
    const figs = Array.from(gallery.children).filter((el) => el.classList.contains('live-photo'));
    const cycle = ['a', 'b', 'c', 'd', 'e'];
    let step = 0;
    let wideCount = 0;
    figs.forEach((fig, k) => {
      if (isWide(fig)) {
        fig.classList.add(wideCount++ % 2 ? 'amb-g-wr' : 'amb-g-w');
        return;
      }
      let slot = cycle[step % cycle.length];
      // Une paire n'a de sens qu'avec deux portraits qui se suivent
      if (slot === 'c' && (!figs[k + 1] || isWide(figs[k + 1]))) {
        slot = 'e';
        step += 2;
      }
      fig.classList.add('amb-g-' + slot);
      step += 1;
    });
  });
  strips.forEach((strip) => {
    if (strip.querySelectorAll('.live-photo').length < 2) return;
    const track = document.createElement('div');
    track.className = 'amb-strip-progress';
    track.setAttribute('aria-hidden', 'true');
    track.appendChild(document.createElement('span'));
    strip.after(track);
    let wait = false;
    const paint = () => {
      wait = false;
      const max = strip.scrollWidth - strip.clientWidth;
      const seen = max > 0 ? (strip.scrollLeft + strip.clientWidth) / strip.scrollWidth : 1;
      track.style.setProperty('--strip', Math.min(1, seen).toFixed(3));
    };
    strip.addEventListener('scroll', () => {
      if (!wait) { wait = true; window.requestAnimationFrame(paint); }
    }, { passive: true });
    window.addEventListener('resize', paint);
    paint();
  });

  /* 10 quater. Visionneuse : la photo suit le doigt ; un geste franc passe à la suivante */
  const viewer = document.querySelector('#lightbox');
  const shot = viewer && viewer.querySelector('#lightbox-image');
  const nextBtn = viewer && viewer.querySelector('#next');
  const prevBtn = viewer && viewer.querySelector('#previous');
  if (shot && nextBtn && prevBtn) {
    let id = null;
    let x0 = 0;
    let y0 = 0;
    let dx = 0;
    let dragging = false;
    let arriving = 0;
    const reset = () => { shot.style.transform = ''; shot.style.opacity = ''; };
    shot.addEventListener('pointerdown', (e) => {
      if (e.pointerType === 'mouse' || !e.isPrimary) return;
      id = e.pointerId;
      x0 = e.clientX;
      y0 = e.clientY;
      dx = 0;
      dragging = false;
    });
    shot.addEventListener('pointermove', (e) => {
      if (e.pointerId !== id) return;
      const mx = e.clientX - x0;
      const my = e.clientY - y0;
      if (!dragging) {
        if (Math.abs(mx) < 10 || Math.abs(mx) < Math.abs(my)) return;
        dragging = true;
        shot.classList.add('is-dragging');
        try { shot.setPointerCapture(id); } catch (err) { /* capture indisponible : le geste continue */ }
      }
      dx = mx;
      shot.style.transform = 'translate3d(' + dx.toFixed(1) + 'px,0,0)';
      shot.style.opacity = String(1 - Math.min(Math.abs(dx) / 700, 0.35));
    });
    const release = (e) => {
      if (e.pointerId !== id) return;
      id = null;
      if (!dragging) return;
      dragging = false;
      shot.classList.remove('is-dragging');
      shot.classList.add('is-settling');
      const go = Math.abs(dx) > Math.min(90, window.innerWidth * 0.18);
      if (go && motion()) {
        arriving = dx < 0 ? 1 : -1;
        shot.style.transform = 'translate3d(' + (dx < 0 ? '-30%' : '30%') + ',0,0)';
        shot.style.opacity = '0';
        window.setTimeout(() => {
          shot.classList.remove('is-settling');
          reset();
          (arriving > 0 ? nextBtn : prevBtn).click();
        }, 180);
      } else if (go) {
        shot.classList.remove('is-settling');
        reset();
        (dx < 0 ? nextBtn : prevBtn).click();
      } else {
        reset();
        window.setTimeout(() => shot.classList.remove('is-settling'), 360);
      }
    };
    shot.addEventListener('pointerup', release);
    shot.addEventListener('pointercancel', release);
    shot.addEventListener('load', () => {
      if (!arriving) return;
      shot.style.setProperty('--from', String(arriving));
      shot.classList.remove('is-arriving');
      void shot.offsetWidth; // relance l'arrivée
      shot.classList.add('is-arriving');
      arriving = 0;
    });
    shot.addEventListener('animationend', () => shot.classList.remove('is-arriving'));
  }

  /* 11. Panneau « Affichage » : ambiance et animations, gardées six mois dans ce navigateur */
  const save = () => {
    try {
      window.localStorage.setItem('gs-affichage', JSON.stringify({ a: root.dataset.ambiance || 'scene', m: root.dataset.motion || 'marquee', t: Date.now() }));
    } catch (e) { /* stockage indisponible : le choix vaut pour cette page */ }
  };
  const panel = document.createElement('details');
  panel.className = 'amb-panel';
  const summary = document.createElement('summary');
  summary.textContent = 'Affichage';
  panel.appendChild(summary);
  const group = (legendText, name, options, current) => {
    const fieldset = document.createElement('fieldset');
    const legend = document.createElement('legend');
    legend.textContent = legendText;
    fieldset.appendChild(legend);
    options.forEach(([value, text, hint]) => {
      const label = document.createElement('label');
      const input = document.createElement('input');
      input.type = 'radio';
      input.name = name;
      input.value = value;
      input.checked = value === current;
      label.appendChild(input);
      label.appendChild(document.createTextNode(' ' + text));
      if (hint) {
        const small = document.createElement('small');
        small.textContent = hint;
        label.appendChild(small);
      }
      fieldset.appendChild(label);
    });
    return fieldset;
  };
  panel.appendChild(group('Ambiance', 'amb-ambiance', [['scene', 'Scène', 'couleurs des photos'], ['nuit', 'Nuit', 'couleurs du site'], ['os', 'Os', 'fond clair']], root.dataset.ambiance || 'scene'));
  panel.appendChild(group('Animations', 'amb-motion', [['marquee', 'Marquées'], ['discrete', 'Discrètes'], ['none', 'Aucune']], root.dataset.motion || 'marquee'));
  panel.addEventListener('change', (e) => {
    const input = e.target;
    if (!(input instanceof HTMLInputElement)) return;
    if (input.name === 'amb-ambiance') { root.dataset.ambiance = input.value; applyLogo(); }
    if (input.name === 'amb-motion') {
      root.dataset.motion = input.value;
      applyMotion();
      if (!motion()) revealAll();
      request();
    }
    save();
  });
  document.body.appendChild(panel);
})();
