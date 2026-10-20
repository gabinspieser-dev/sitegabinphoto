'use strict';
(() => {
  // Basic consent mode: this local file makes no Google request before opt-in.
  const tag = document.currentScript;
  const measurementId = tag && tag.dataset.measurementId;
  if (!/^G-[A-Z0-9]+$/.test(measurementId || '')) return;
  const disableKey = 'ga-disable-' + measurementId;
  const productionHost = /^(www\.)?gabin-spieser\.com$/.test(window.location.hostname);
  const maxCookieAge = 180 * 24 * 60 * 60;
  let loaded = false;
  let externalScript = null;
  window[disableKey] = true;
  window.dataLayer = window.dataLayer || [];
  window.gtag = window.gtag || function () { window.dataLayer.push(arguments); };
  window.gtag('consent', 'default', {
    analytics_storage: 'denied', ad_storage: 'denied',
    ad_user_data: 'denied', ad_personalization: 'denied'
  });

  function withoutQuery(value) {
    try {
      const url = new URL(value);
      return /^https?:$/.test(url.protocol) ? url.origin + url.pathname : '';
    } catch (_) { return ''; }
  }

  function deleteAnalyticsCookies() {
    let names = [];
    try { names = document.cookie.split(';').map(part => part.trim().split('=')[0]); }
    catch (_) { return; }
    const hostParts = window.location.hostname.split('.');
    const domains = [''];
    for (let i = 0; i < hostParts.length - 1; i++) {
      const domain = hostParts.slice(i).join('.');
      domains.push('; Domain=' + domain, '; Domain=.' + domain);
    }
    const paths = new Set(['/']);
    const parts = window.location.pathname.split('/').filter(Boolean);
    for (let i = 1; i < parts.length; i++) paths.add('/' + parts.slice(0, i).join('/') + '/');
    for (const name of names.filter(name => name === '_ga' || name.startsWith('_ga_'))) {
      for (const domain of domains) for (const path of paths) {
        try {
          document.cookie = name + '=; Max-Age=0; Expires=Thu, 01 Jan 1970 00:00:00 GMT; Path=' + path + domain + '; SameSite=Lax';
        } catch (_) { /* Browsers may block cookie access. */ }
      }
    }
  }

  function setConsent(granted, expiresAt) {
    const remaining = Math.floor((expiresAt - Date.now()) / 1000);
    const allowed = granted === true && Number.isFinite(remaining) && remaining > 0;
    if (!allowed) {
      window[disableKey] = true;
      deleteAnalyticsCookies();
      if (externalScript) externalScript.remove();
      // Reload after the refusal is saved to unload an already-running Google library.
      return {reloadRequired: loaded};
    }
    // Local previews must never create visits in the owner's production property.
    if (!productionHost || loaded) return {reloadRequired: false};
    window[disableKey] = false;
    window.gtag('consent', 'update', {
      analytics_storage: 'granted', ad_storage: 'denied',
      ad_user_data: 'denied', ad_personalization: 'denied'
    });
    window.gtag('set', 'ads_data_redaction', true);
    window.gtag('js', new Date());
    window.gtag('config', measurementId, {
      allow_google_signals: false,
      allow_ad_personalization_signals: false,
      cookie_domain: window.location.hostname,
      cookie_path: '/',
      cookie_expires: Math.min(maxCookieAge, remaining),
      cookie_update: false,
      page_location: withoutQuery(window.location.href),
      page_referrer: withoutQuery(document.referrer)
    });
    loaded = true;
    externalScript = document.createElement('script');
    externalScript.async = true;
    externalScript.src = 'https://www.googletagmanager.com/gtag/js?id=' + measurementId;
    externalScript.id = 'google-analytics-tag';
    document.head.appendChild(externalScript);
    return {reloadRequired: false};
  }

  window.GabinAnalytics = Object.freeze({setConsent});
})();
