'use strict';
(() => {
  // A new policy invalidates technical-only choices made before Analytics was added.
  const COOKIE_NAME = 'gabin_cookie_choices';
  const POLICY = 'analytics-opt-in-20261020';
  const VERSION = 2;
  const DECISIONS = ['accept', 'reject', 'necessary'];
  let scopePath = '/';
  try {
    const src = document.currentScript && document.currentScript.src;
    if (src) scopePath = new URL('.', src).pathname;
  } catch (_) { /* Root hosting is the fallback. */ }
  const DENIAL_KEY = COOKIE_NAME + '_session_denial_' + scopePath;

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
      && Object.keys(record).sort().join(',') === 'analytics,decision,expiresAt,policy,savedAt,scopePath,version'
      && record.version === VERSION && record.policy === POLICY && record.scopePath === scopePath
      && DECISIONS.includes(record.decision) && typeof record.analytics === 'boolean'
      && record.analytics === (record.decision === 'accept') && Number.isSafeInteger(record.savedAt)
      && record.savedAt > 0 && record.savedAt <= now + 60000
      && Number.isSafeInteger(record.expiresAt) && record.expiresAt > now
      && record.expiresAt === sixMonthsFrom(record.savedAt);
  }

  function readChoice(now = Date.now(), ignoreSessionDenial = false) {
    if (!ignoreSessionDenial) {
      try { if (window.sessionStorage.getItem(DENIAL_KEY) === '1') return null; }
      catch (_) { /* Preference storage can also be blocked. */ }
    }
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
    const record = {version: VERSION, policy: POLICY, decision, analytics: decision === 'accept', savedAt: now,
      expiresAt: sixMonthsFrom(now), scopePath};
    let persisted = false;
    try {
      if (window.location.protocol !== 'file:') {
        const secure = window.location.protocol === 'https:' ? '; Secure' : '';
        const age = Math.floor((record.expiresAt - now) / 1000);
        document.cookie = COOKIE_NAME + '=' + encodeURIComponent(JSON.stringify(record))
          + '; Path=' + scopePath + '; Max-Age=' + age
          + '; Expires=' + new Date(record.expiresAt).toUTCString() + '; SameSite=Lax' + secure;
        const stored = readChoice(now, true);
        persisted = !!stored && stored.savedAt === now && stored.decision === decision;
      }
    } catch (_) { /* Report an unavailable preference cookie in the UI. */ }
    try {
      if (!persisted && decision !== 'accept') window.sessionStorage.setItem(DENIAL_KEY, '1');
      else window.sessionStorage.removeItem(DENIAL_KEY);
    } catch (_) { /* An unsaved refusal is still retained for the current page. */ }
    return {record, persisted};
  }

  // UI starts here. Storage helpers are tested separately without browser automation.
  const banner = document.getElementById('cookie-banner');
  const settings = document.getElementById('cookie-settings');
  const status = document.getElementById('cookie-status');
  const feedback = document.getElementById('cookie-feedback');
  const currentChoice = document.getElementById('cookie-current-choice');
  const policyLink = document.querySelector('[data-cookie-policy]');
  const analyticsChoice = document.getElementById('cookie-analytics');
  if (!banner || !settings || !status || !feedback || !currentChoice || !policyLink || !analyticsChoice) return;
  const supportsDialog = typeof settings.showModal === 'function';
  const footerButtons = [...document.querySelectorAll('[data-cookie-open]')];
  let choice = readChoice();
  let choicePersisted = true;
  let forceBanner = false;
  let opener = null;
  let previousOverflow = '';
  let feedbackAfterClose = false;
  let reserveFrame = 0;
  let expiryTimer = 0;
  let consentChannel = null;
  try { consentChannel = new BroadcastChannel('gabin-cookie-consent-' + scopePath); } catch (_) { /* Optional tab sync. */ }

  function applyAnalytics(allowReload = true) {
    const result = window.GabinAnalytics && window.GabinAnalytics.setConsent(
      !!choice && choice.analytics, choice ? choice.expiresAt : 0);
    if (result && result.reloadRequired && allowReload) window.location.reload();
  }

  function watchExpiry() {
    clearTimeout(expiryTimer);
    if (!choice) return;
    const remaining = choice.expiresAt - Date.now();
    if (remaining <= 0) {
      choice = null;
      applyAnalytics();
      describeChoice();
      renderBanner();
      return;
    }
    expiryTimer = setTimeout(watchExpiry, Math.min(remaining + 50, 2147483647));
  }

  function reserveSpace() {
    const height = banner.hidden ? 0 : Math.ceil(banner.getBoundingClientRect().height);
    document.documentElement.style.setProperty('--cookie-banner-space', height + 'px');
  }

  function renderBanner() {
    banner.hidden = (!!choice && !forceBanner) || settings.open;
    reserveSpace();
  }

  function describeChoice() {
    analyticsChoice.checked = !!choice && choice.analytics;
    currentChoice.textContent = choice
      ? 'Votre choix : mesure d’audience ' + (choice.analytics ? 'acceptée.' : 'refusée. Seuls les cookies nécessaires sont utilisés.')
      : 'Aucun choix enregistré. La mesure d’audience reste désactivée.';
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
      forceBanner = true;
      renderBanner();
      banner.querySelector('[data-cookie-choice="reject"]').focus();
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
    choicePersisted = result.persisted;
    forceBanner = false;
    applyAnalytics(result.persisted);
    watchExpiry();
    if (consentChannel) consentChannel.postMessage('choice-changed');
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
  document.querySelector('[data-cookie-save]').addEventListener('click', () => choose(analyticsChoice.checked ? 'accept' : 'necessary'));
  document.querySelector('[data-cookie-personalize]').addEventListener('click', openSettings);
  footerButtons.forEach(button => {
    button.hidden = false;
    button.addEventListener('click', openSettings);
  });
  document.querySelector('[data-cookie-close]').addEventListener('click', closeSettings);
  document.querySelector('[data-cookie-feedback-close]').addEventListener('click', () => {
    feedback.hidden = true;
    if (footerButtons[0] && !footerButtons[0].hidden) footerButtons[0].focus({preventScroll: true});
  });
  settings.addEventListener('keydown', event => {
    if (event.key === 'Tab') {
      const controls = [...settings.querySelectorAll('a[href], button:not([disabled]), input:not([disabled])')];
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
  function syncChoice() {
    if (!choicePersisted && choice) { watchExpiry(); return; }
    const latest = readChoice();
    if (JSON.stringify(latest) === JSON.stringify(choice)) { watchExpiry(); return; }
    choice = latest;
    applyAnalytics();
    watchExpiry();
    if (!settings.open) describeChoice();
    renderBanner();
  }
  if (consentChannel) consentChannel.addEventListener('message', syncChoice);
  document.addEventListener('visibilitychange', () => { if (!document.hidden) syncChoice(); });
  window.addEventListener('focus', syncChoice);
  applyAnalytics();
  watchExpiry();
  describeChoice();
  renderBanner();
})();
