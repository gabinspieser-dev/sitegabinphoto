// Ne pas ajouter defer : ce script applique l'ambiance et le niveau d'animation choisis
// avant l'affichage de la page, pour éviter un éclair de la mauvaise ambiance.
// Le choix est gardé six mois dans le stockage local du navigateur, sans identifiant.
'use strict';
(() => {
  try {
    const saved = JSON.parse(window.localStorage.getItem('gs-affichage') || 'null');
    if (!saved || typeof saved.t !== 'number' || Date.now() - saved.t > 183 * 864e5) return;
    const root = document.documentElement;
    if (['scene', 'nuit', 'os'].indexOf(saved.a) !== -1) root.dataset.ambiance = saved.a;
    if (['marquee', 'discrete', 'none'].indexOf(saved.m) !== -1) root.dataset.motion = saved.m;
  } catch (e) { /* stockage indisponible : ambiance par défaut */ }
})();
