'use strict';
(() => {
  // This version has no optional trackers. A saved choice never authorizes future tools.
  const COOKIE_NAME = 'gabin_cookie_choices';
  const POLICY = 'technical-only-20261004';
  const VERSION = 1;
  const DECISIONS = ['accept', 'reject', 'necessary'];
  let scopePath = '/';
  try {
    const src = document.currentScript && document.currentScript.src;
    if (src) scopePath = new URL('.', src).pathname;
  } catch (_) { /* Root hosting is the fallback. */ }

  function sixMonthsFrom(timestamp) {
    const date = new Date(timestamp);
    const day = date.getUTCDate();
    date.setUTCDate(1);
    date.setUTCMonth(date.getUTCMonth() + 6);
    const lastDay = new Date(Date.UTC(date.getUTCFullYear(), date.getUTCMonth() + 1, 0)).getUTCDate();
    date.setUTCDate(Math.min(day, lastDay));
    return date.getTime();
  }

  function validRecord(record, now) {
    return record && typeof record === 'object' && !Array.isArray(record)
      && Object.keys(record).sort().join(',') === 'decision,expiresAt,policy,savedAt,scopePath,version'
      && record.version === VERSION && record.policy === POLICY && record.scopePath === scopePath
      && DECISIONS.includes(record.decision) && Number.isSafeInteger(record.savedAt)
      && record.savedAt > 0 && record.savedAt <= now + 60000
      && Number.isSafeInteger(record.expiresAt) && record.expiresAt > now
      && record.expiresAt === sixMonthsFrom(record.savedAt);
  }

  function readChoice(now = Date.now()) {
    try {
      if (window.location.protocol === 'file:') return null;
      for (const part of document.cookie.split(';')) {
        const trimmed = part.trim();
        if (!trimmed.startsWith(COOKIE_NAME + '=')) continue;
        const encoded = trimmed.slice(COOKIE_NAME.length + 1);
        if (encoded.length > 1500) continue;
        try {
          const record = JSON.parse(decodeURIComponent(encoded));
          if (validRecord(record, now)) return record;
        } catch (_) { /* Invalid or outdated data is never treated as a choice. */ }
      }
    } catch (_) { /* Browsing also works when cookies are blocked. */ }
    return null;
  }

  function saveChoice(decision, now = Date.now()) {
    if (!DECISIONS.includes(decision)) throw new TypeError('Unknown cookie choice');
    const record = {version: VERSION, policy: POLICY, decision, savedAt: now,
      expiresAt: sixMonthsFrom(now), scopePath};
    let persisted = false;
    try {
      if (window.location.protocol !== 'file:') {
        const secure = window.location.protocol === 'https:' ? '; Secure' : '';
        const age = Math.floor((record.expiresAt - now) / 1000);
        document.cookie = COOKIE_NAME + '=' + encodeURIComponent(JSON.stringify(record))
          + '; Path=' + scopePath + '; Max-Age=' + age
          + '; Expires=' + new Date(record.expiresAt).toUTCString() + '; SameSite=Lax' + secure;
        const stored = readChoice(now);
        persisted = !!stored && stored.savedAt === now && stored.decision === decision;
      }
    } catch (_) { /* Report an unavailable preference cookie in the UI. */ }
    return {record, persisted};
  }

  // UI starts here. Storage helpers are tested separately without browser automation.
  const banner = document.getElementById('cookie-banner');
  const settings = document.getElementById('cookie-settings');
  const status = document.getElementById('cookie-status');
  const feedback = document.getElementById('cookie-feedback');
  const currentChoice = document.getElementById('cookie-current-choice');
  const policyLink = document.querySelector('[data-cookie-policy]');
  if (!banner || !settings || !status || !feedback || !currentChoice || !policyLink) return;
  const supportsDialog = typeof settings.showModal === 'function';
  const footerButtons = [...document.querySelectorAll('[data-cookie-open]')];
  let choice = readChoice();
  let opener = null;
  let previousOverflow = '';
  let feedbackAfterClose = false;
  let reserveFrame = 0;
  const labels = {accept: 'Acceptés', reject: 'Refusés', necessary: 'Nécessaires uniquement'};

  function reserveSpace() {
    const height = banner.hidden ? 0 : Math.ceil(banner.getBoundingClientRect().height);
    document.documentElement.style.setProperty('--cookie-banner-space', height + 'px');
  }

  function renderBanner() {
    banner.hidden = !!choice || settings.open;
    reserveSpace();
  }

  function describeChoice() {
    currentChoice.textContent = choice
      ? 'Votre choix : ' + labels[choice.decision] + '. Aucun cookie facultatif n’est utilisé.'
      : 'Vous n’avez pas encore enregistré de choix. Aucun cookie facultatif n’est utilisé.';
  }

  function restorePageFocus(preferred) {
    if (preferred && !preferred.closest('[hidden]')) {
      preferred.focus();
      return;
    }
    const visible = [...document.querySelectorAll('a[href], button:not([hidden])')].find(element => {
      if (element.closest('#cookie-settings, .cookie-banner, .cookie-feedback, [hidden]')) return false;
      const rect = element.getBoundingClientRect();
      return rect.width > 0 && rect.top >= 0 && rect.bottom <= window.innerHeight;
    });
    if (visible) visible.focus({preventScroll: true});
    else if (footerButtons[0] && !footerButtons[0].hidden) footerButtons[0].focus();
  }

  function openSettings(event) {
    if (!supportsDialog) {
      window.location.href = policyLink.href;
      return;
    }
    if (settings.open) return;
    opener = event.currentTarget;
    describeChoice();
    previousOverflow = document.body.style.overflow;
    settings.showModal();
    document.body.style.overflow = 'hidden';
    renderBanner();
    document.getElementById('cookie-settings-title').focus({preventScroll: true});
  }

  function closeSettings() { if (settings.open) settings.close(); }

  function choose(decision) {
    const clicked = document.activeElement;
    const result = saveChoice(decision);
    choice = result.record;
    feedback.hidden = result.persisted;
    status.textContent = result.persisted
      ? 'Votre choix est enregistré pour six mois. Vous pouvez le modifier dans « Gérer les cookies ».'
      : 'Votre choix est appliqué pour cette page. Votre navigateur ne permet pas de le mémoriser.';
    describeChoice();
    if (settings.open) {
      feedbackAfterClose = !result.persisted;
      closeSettings();
    }
    renderBanner();
    // Do not leave keyboard focus on a now-hidden banner button.
    if (banner.contains(clicked)) {
      const target = result.persisted ? null : document.querySelector('[data-cookie-feedback-close]');
      restorePageFocus(target);
    }
  }

  document.querySelectorAll('[data-cookie-choice]').forEach(button => {
    button.addEventListener('click', () => choose(button.dataset.cookieChoice));
  });
  document.querySelector('[data-cookie-personalize]').addEventListener('click', openSettings);
  footerButtons.forEach(button => {
    button.hidden = !supportsDialog;
    button.addEventListener('click', openSettings);
  });
  document.querySelector('[data-cookie-close]').addEventListener('click', closeSettings);
  document.querySelector('[data-cookie-feedback-close]').addEventListener('click', () => {
    feedback.hidden = true;
    if (footerButtons[0] && !footerButtons[0].hidden) footerButtons[0].focus({preventScroll: true});
  });
  settings.addEventListener('keydown', event => {
    if (event.key === 'Tab') {
      const controls = [...settings.querySelectorAll('a[href], button:not([disabled])')];
      const first = controls[0];
      const last = controls[controls.length - 1];
      if (event.shiftKey && (document.activeElement === first || document.activeElement === document.getElementById('cookie-settings-title'))) {
        event.preventDefault();
        last.focus();
      } else if (!event.shiftKey && document.activeElement === last) {
        event.preventDefault();
        first.focus();
      }
    }
    if (event.key === 'Escape') {
      event.preventDefault();
      event.stopPropagation();
      closeSettings();
    }
  });
  settings.addEventListener('cancel', event => { event.preventDefault(); closeSettings(); });
  settings.addEventListener('close', () => {
    document.body.style.overflow = previousOverflow;
    renderBanner();
    restorePageFocus(feedbackAfterClose ? document.querySelector('[data-cookie-feedback-close]') : opener);
    feedbackAfterClose = false;
  });
  // Keep focus in view when the nonmodal bottom strip is still displayed.
  document.addEventListener('focusin', event => {
    if (banner.hidden || settings.open || !(event.target instanceof Element)
        || banner.contains(event.target) || event.target.closest('dialog[open]')) return;
    cancelAnimationFrame(reserveFrame);
    reserveFrame = requestAnimationFrame(() => {
      const rect = event.target.getBoundingClientRect();
      const top = banner.getBoundingClientRect().top;
      if (rect.bottom > top && rect.top < window.innerHeight) {
        event.target.scrollIntoView({block: 'center', behavior: 'instant'});
      }
    });
  });
  if (typeof ResizeObserver === 'function') new ResizeObserver(reserveSpace).observe(banner);
  else window.addEventListener('resize', reserveSpace);
  renderBanner();
})();
