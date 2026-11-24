<#
  Portfolio — constructeur des séries « en scènes » (25/11/2026). Chargé par generer-pages.ps1.
  Une série en scènes est une suite de composants, combinés différemment pour chaque artiste :
    ouverture (variantes : portrait par défaut, « paysage », « revelateur »), texte, monumental (variante « pleine »),
    duo (variante « partage »), trio, asymetrique, sequence, planche, carton, respiration, final.
  Chaque scène reçoit les couleurs des bords de sa photo (couleurs.json) : le fond de page les reprend,
  l'image se prolonge dans la page, et le fond change d'une scène à l'autre pendant le défilement.
  Réglages possibles par scène : fond (couleur imposée), halo, accent, encre (« sombre » ; sinon déduite du fond).
  Les couleurs sont écrites dans assets/css/series/<série>-couleurs.css (aucun style dans le HTML).
#>
$COUL = $null
$cp = Join-Path $PSScriptRoot 'couleurs.json'
if (Test-Path $cp) { $COUL = [IO.File]::ReadAllText($cp, [Text.Encoding]::UTF8) | ConvertFrom-Json }
function PhotoIds($a) {
  if ($a.scenes) { return @($a.scenes | ForEach-Object { @($_.photo) + @($_.photos) } | Where-Object { $_ }) }
  @($a.chapitres | ForEach-Object { $_.plans } | ForEach-Object { $_.photos })
}
function Count-Photos($a) { @(PhotoIds $a).Count }
function Col($id, [string]$k, [string]$def = '#06080f') { if ($COUL -and $COUL.$id -and $COUL.$id.$k) { $COUL.$id.$k } else { $def } }
function Halo($id) { $dom = Col $id 'dominante' ''; if ($dom) { $dom } else { Col $id 'moyenne' } }
function Lum([string]$hex) {
  $f = { param($c) $c = $c / 255; if ($c -le 0.03928) { $c / 12.92 } else { [math]::Pow(($c + 0.055) / 1.055, 2.4) } }
  $rr = [Convert]::ToInt32($hex.Substring(1, 2), 16); $gg = [Convert]::ToInt32($hex.Substring(3, 2), 16); $bb = [Convert]::ToInt32($hex.Substring(5, 2), 16)
  0.2126 * (& $f $rr) + 0.7152 * (& $f $gg) + 0.0722 * (& $f $bb)
}
# Mélange de deux couleurs (poids $wA pour $hA), comme color-mix(in srgb) dans scenes.css
function Mix([string]$hA, [double]$wA, [string]$hB) {
  $o = '#'
  foreach ($i in 1, 3, 5) { $va = [Convert]::ToInt32($hA.Substring($i, 2), 16); $vb = [Convert]::ToInt32($hB.Substring($i, 2), 16); $o += '{0:x2}' -f [int][math]::Round($va * $wA + $vb * (1 - $wA)) }
  $o
}
# Garde-fou de lisibilité : sous un texte clair, le fond (bords + halo à 34 %) reste sous une luminance de 0,05 ;
# sous un texte sombre, il reste au-dessus de 0,5. La teinte est gardée, seule la clarté bouge (contraste ≥ 4,5:1).
function Fit-Fond([string]$cG, [string]$cD, [string]$cH, [string]$encre) {
  if ($encre -eq 'sombre') {
    $n = 0; while ((Lum $cG) -lt 0.5 -and $n -lt 60) { $cG = Mix '#ffffff' 0.08 $cG; $n++ }
    $n = 0; while ((Lum $cD) -lt 0.5 -and $n -lt 60) { $cD = Mix '#ffffff' 0.08 $cD; $n++ }
    $n = 0; while (((Lum (Mix $cH 0.34 $cG)) -lt 0.5 -or (Lum (Mix $cH 0.34 $cD)) -lt 0.5) -and $n -lt 60) { $cH = Mix '#ffffff' 0.08 $cH; $n++ }
  } else {
    $n = 0; while ((Lum $cG) -gt 0.05 -and $n -lt 60) { $cG = Mix '#000000' 0.08 $cG; $n++ }
    $n = 0; while ((Lum $cD) -gt 0.05 -and $n -lt 60) { $cD = Mix '#000000' 0.08 $cD; $n++ }
    $n = 0; while (((Lum (Mix $cH 0.34 $cG)) -gt 0.05 -or (Lum (Mix $cH 0.34 $cD)) -gt 0.05) -and $n -lt 60) { $cH = Mix '#000000' 0.08 $cH; $n++ }
  }
  , @($cG, $cD, $cH)
}

$SC_SIZES = @{ ouverture = '(max-width: 700px) 100vw, 46vw'; 'ouverture-paysage' = '(max-width: 700px) 100vw, 92vw'
  'monumental-portrait' = '(max-width: 700px) 100vw, 62vw'; 'monumental-paysage' = '(max-width: 700px) 100vw, 92vw'; 'monumental-pleine' = '100vw'
  duo = '(max-width: 700px) 100vw, 46vw'; partage = '(max-width: 700px) 100vw, 50vw'; trio = '(max-width: 700px) 82vw, 31vw'
  asymetrique = '(max-width: 700px) 100vw, 50vw'; sequence = '(max-width: 700px) 92vw, 52vw'; planche = '(max-width: 700px) 72vw, 22vw'
  respiration = '(max-width: 700px) 72vw, 30vw'; final = '(max-width: 700px) 100vw, 62vw'; 'final-paysage' = '(max-width: 700px) 100vw, 92vw' }

function ScFig($a, $id, [string]$sizesKey, [string]$P, [bool]$eager = $false, [bool]$vue = $false) {
  $x = Img $id; $meta = $a.photos.$id; $num = '{0:00}' -f $x.n
  $title = "$($meta.legende) · $($a.nom)"
  $vueTxt = if ($vue) { "<span class=""sc-vue"">Vue $(($id -replace '\D', '').TrimStart('0'))</span>" } else { '' }
  "<figure class=""sc-photo"" id=""photo-$num"" data-r=""$(RatioCode $x)""><a class=""photo-open"" href=""$P$(Largest $x)"" data-photo=""$($x.n)"" data-title=""$(Enc $title)"">$(ImgTag $id $meta.alt $SC_SIZES[$sizesKey] $P $eager)</a><figcaption class=""sc-legende""><span class=""serie-num"">$num</span><span>$(Enc $meta.legende)</span>$vueTxt</figcaption></figure>"
}

# Maillage interne (25/11/2026) : en fin de série, le reportage de l'événement s'il existe, puis toutes les autres séries
function Voir-Aussi([string]$courant, [string]$P, $a) {
  $rep = New-Object System.Collections.Generic.List[string]
  if ($a -and $a.contexte -and "$($a.contexte.evenement)" -like 'Foire en Sc*') { $rep.Add("<li><a href=""${P}foire-en-scene-chalons-en-champagne.html"">Le reportage Foire en Scène 2026</a></li>") }
  if ($courant -eq 'electro-symphony') { $rep.Add("<li><a href=""${P}electro-symphony-reims-arena.html"">Le reportage à Reims Arena</a></li>") }
  $autres = foreach ($s in $seriesOrder) {
    if ($s -eq $courant) { continue }
    $nom = if ($s -eq 'instantanes') { 'Instantanés' } else { $bySlug[$s].nom }
    "<li><a href=""${P}series/$s/"">$(Enc $nom)</a></li>"
  }
  $ev = if ($rep.Count) { "<ul class=""serie-voir-reportages"">$($rep -join '')</ul>" } else { '' }
  "<nav class=""serie-voir-aussi"" aria-labelledby=""voir-aussi-titre""><h2 id=""voir-aussi-titre"">Les autres séries</h2>$ev<ul class=""serie-autres"">$($autres -join '')</ul></nav>"
}

function Build-ScenePage($a) {
  $P = '../../'; $url = "$BASE/series/$($a.slug)/"
  $ids = PhotoIds $a; $total = $ids.Count
  $ctx = ContextLine $a
  $css = New-Object Text.StringBuilder
  [void]$css.AppendLine("/* Généré par _portfolio/generer-pages.ps1 à partir de couleurs.json et des réglages des scènes : ne pas modifier à la main. */")
  $sb = New-Object Text.StringBuilder
  $rail = New-Object System.Collections.Generic.List[string]
  $romans = @('I', 'II', 'III', 'IV', 'V', 'VI', 'VII', 'VIII', 'IX', 'X', 'XI', 'XII')
  $chap = 0; $k = 0; $prevPhoto = $ids[0]
  [void]$sb.Append("<main id=""contenu"" class=""serie sc-page""><div class=""sc-fond"" aria-hidden=""true""></div>")
  foreach ($sc in $a.scenes) {
    $k++
    $photos = @(@($sc.photo) + @($sc.photos) | Where-Object { $_ })
    # Couleurs de la scène : bord gauche de la première photo, bord droit de la dernière, halo = couleur dominante
    if ($photos.Count) { $cG = Col $photos[0] 'gauche'; $cD = Col $photos[-1] 'droite'; $cH = Halo $photos[0]; $prevPhoto = $photos[-1] }
    else { $ref = if ($sc.photo_couleur) { $sc.photo_couleur } else { $prevPhoto }; $cG = Col $ref 'bas'; $cD = Col $ref 'bas'; $cH = Halo $ref }
    if ($sc.fond) { $cG = $sc.fond; $cD = $sc.fond }
    if ($sc.halo) { $cH = $sc.halo }
    $encre = if ($sc.encre) { $sc.encre } elseif ((((Lum $cG) + (Lum $cD)) / 2) -gt 0.3) { 'sombre' } else { '' }
    $fit = Fit-Fond $cG $cD $cH $encre; $cG = $fit[0]; $cD = $fit[1]; $cH = $fit[2]
    $acc = if ($sc.accent) { ";--sc-acc:$($sc.accent)" } else { '' }
    [void]$css.AppendLine(".serie--$($a.theme) [data-sc=""$k""]{--g:$cG;--d:$cD;--h:$cH$acc}")
    $enc = if ($encre) { " data-encre=""$encre""" } else { '' }
    $attrSc = "id=""sc-$k"" data-sc=""$k""$enc"
    $head = ''; $lab = ''
    if ($sc.chapitre -and $sc.type -ne 'carton') { $head = "<header class=""sc-chapitre""><span class=""sc-chapitre-num"" aria-hidden=""true"">$($romans[$chap])</span><h2 id=""sc-titre-$k"">$(Enc $sc.chapitre)</h2></header>"; $chap++; $lab = " aria-labelledby=""sc-titre-$k""" }
    $mot = if ($sc.mot) { "<p class=""sc-mot"" data-cote=""$(if ($sc.mot_cote) { $sc.mot_cote } else { 'gauche' })"" aria-hidden=""true"">$(Enc $sc.mot)</p>" } else { '' }
    $txt = if ($sc.texte) { "<p class=""sc-note"">$(Enc $sc.texte)</p>" } else { '' }
    switch ($sc.type) {
      'ouverture' {
        $cote = if ($sc.cote) { $sc.cote } else { 'droite' }
        $var = if ($sc.variante) { $sc.variante } else { 'portrait' }
        $ctxHtml = if ($ctx) { "<p class=""sc-contexte"">$(Enc $ctx)</p>" } else { '' }
        $key = if ($var -eq 'paysage') { 'ouverture-paysage' } else { 'ouverture' }
        [void]$sb.Append("<section class=""sc sc--ouverture sc--ouv-$var"" $attrSc data-cote=""$cote"" aria-label=""Ouverture de la série"">")
        [void]$sb.Append("<nav class=""serie-fil"" aria-label=""Fil d’Ariane""><a href=""${P}"">Accueil</a> / <a href=""${P}series/"">Séries</a> / <span aria-current=""page"">$(Enc $a.nom)</span></nav>")
        [void]$sb.Append("<div class=""sc-ouverture-texte""><p class=""sc-kicker"">Série · $total photographies</p><h1 class=""sc-nom"">$(Enc $a.nom)</h1><p class=""sc-titre"">$(Enc $a.titre_serie)</p>$ctxHtml<a class=""sc-cue"" href=""#sc-$($k + 1)"">Entrer dans la série</a></div>")
        [void]$sb.Append((ScFig $a $sc.photo $key $P $true))
        [void]$sb.Append('</section>')
      }
      'texte' {
        $t = if ($sc.texte) { $sc.texte } else { $a.presentation }
        [void]$sb.Append("<section class=""sc sc--texte"" $attrSc aria-label=""Présentation de la série""><p class=""sc-lede"">$(Enc $t)</p></section>")
      }
      'carton' {
        $num = $romans[$chap]; $chap++
        $kick = if ($sc.kicker) { $sc.kicker } else { $num }
        $sous = if ($sc.sous_titre) { "<p class=""sc-carton-sous"">$(Enc $sc.sous_titre)</p>" } else { '' }
        [void]$sb.Append("<section class=""sc sc--carton"" $attrSc aria-labelledby=""sc-titre-$k""><p class=""sc-carton-kicker"" aria-hidden=""true"">$(Enc $kick)</p><h2 class=""sc-carton-titre"" id=""sc-titre-$k"">$(Enc $sc.chapitre)</h2>$sous</section>")
      }
      'monumental' {
        $x = Img $sc.photo; $o = if (IsLandscape $x) { 'paysage' } else { 'portrait' }
        $pleine = ($sc.variante -eq 'pleine') -and ($o -eq 'paysage')
        $cls = if ($pleine) { ' sc--pleine' } else { '' }; $key = if ($pleine) { 'monumental-pleine' } else { "monumental-$o" }
        [void]$sb.Append("<section class=""sc sc--monumental$cls"" $attrSc data-orient=""$o""$lab>$head$mot$(ScFig $a $sc.photo $key $P)$txt</section>")
      }
      'duo' {
        $cls = if ($sc.variante -eq 'partage') { ' sc--partage' } else { '' }; $key = if ($sc.variante -eq 'partage') { 'partage' } else { 'duo' }
        [void]$sb.Append("<section class=""sc sc--duo$cls"" $attrSc$lab>$head$mot<div class=""sc-duo"">$(($sc.photos | ForEach-Object { ScFig $a $_ $key $P }) -join '')</div>$txt</section>")
      }
      'trio' { [void]$sb.Append("<section class=""sc sc--trio"" $attrSc$lab>$head$mot<div class=""sc-trio"" role=""group"" aria-label=""Trois photographies"">$(($sc.photos | ForEach-Object { ScFig $a $_ 'trio' $P }) -join '')</div>$txt</section>") }
      'planche' { [void]$sb.Append("<section class=""sc sc--planche"" $attrSc$lab>$head$mot<div class=""sc-planche"" role=""group"" aria-label=""Planche-contact"">$(($sc.photos | ForEach-Object { ScFig $a $_ 'planche' $P $false $true }) -join '')</div>$txt</section>") }
      'sequence' {
        $n = $photos.Count; $marks = (1..$n | ForEach-Object { '<li></li>' }) -join ''
        [void]$sb.Append("<section class=""sc sc--sequence serie-plan--sequence"" $attrSc data-n=""$n""$lab>$head<div class=""serie-seq-cadre"">$(($sc.photos | ForEach-Object { ScFig $a $_ 'sequence' $P }) -join '')<ol class=""serie-seq-reperes"" aria-hidden=""true"">$marks</ol></div></section>")
      }
      'asymetrique' {
        $cote = if ($sc.cote) { $sc.cote } else { 'gauche' }
        [void]$sb.Append("<section class=""sc sc--asym"" $attrSc data-cote=""$cote""$lab>$(ScFig $a $sc.photo 'asymetrique' $P)<div class=""sc-asym-texte"">$head<p>$(Enc $sc.texte)</p></div></section>")
      }
      'respiration' { [void]$sb.Append("<section class=""sc sc--respiration"" $attrSc$lab>$head$(ScFig $a $sc.photo 'respiration' $P)$txt</section>") }
      'final' {
        $x = Img $sc.photo; $key = if (IsLandscape $x) { 'final-paysage' } else { 'final' }
        [void]$sb.Append("<section class=""sc sc--final"" $attrSc data-orient=""$(if (IsLandscape $x) { 'paysage' } else { 'portrait' })""$lab>$head$mot$(ScFig $a $sc.photo $key $P)$txt</section>")
      }
      default { throw "Type de scène inconnu : $($sc.type) ($($a.slug))" }
    }
    foreach ($id in $photos) { $x = Img $id; $rail.Add("<li><a href=""#photo-$('{0:00}' -f $x.n)""><span>$('{0:00}' -f $x.n) · $(Enc $a.photos.$id.legende)</span></a></li>") }
  }
  # Verso : crédits, liens officiels, série suivante
  $lastId = $ids[-1]
  $vG = if ($a.verso_fond) { $a.verso_fond } else { Col $lastId 'bas' }
  $vfit = Fit-Fond $vG $vG (Halo $lastId) ''
  [void]$css.AppendLine(".serie--$($a.theme) [data-sc=""verso""]{--g:$($vfit[0]);--d:$($vfit[1]);--h:$($vfit[2])}")
  $cred = "<dt>Artiste</dt><dd>$(Enc $a.nom)</dd><dt>Série</dt><dd>$(Enc $a.titre_serie)</dd>"
  if ($a.contexte.evenement -and $a.contexte.evenement -ne $a.nom) { $cred += "<dt>Événement</dt><dd>$(Enc $a.contexte.evenement)</dd>" }
  if ($a.contexte.lieu) { $cred += "<dt>Lieu</dt><dd>$(Enc $a.contexte.lieu)</dd>" }
  if ($a.contexte.date) { $cred += "<dt>Date</dt><dd>$(Enc $a.contexte.date)</dd>" }
  $cred += "<dt>Photographies</dt><dd>Gabin Spieser · $total images</dd>"
  $links = Links-List $a.liens
  $linksBlock = if ($links) { "<div><h2 id=""ecouter"">Écouter, suivre</h2>$links</div>" } else { '' }
  $kk = [array]::IndexOf($seriesOrder, $a.slug); $nextSlug = $seriesOrder[($kk + 1) % $seriesOrder.Count]
  if ($nextSlug -eq 'instantanes') { $nextName = 'Instantanés'; $nextCover = 'GAB09552-2' } else { $na = $bySlug[$nextSlug]; $nextName = $na.nom; $nextCover = CoverId $na }
  $nx = Img $nextCover
  [void]$sb.Append("<section class=""serie-verso sc sc--verso"" data-sc=""verso"" aria-labelledby=""verso-titre""><p class=""serie-verso-intro"">$(Enc $a.seo.description)</p><div class=""serie-verso-grille""><div><h2 id=""verso-titre"">Crédits</h2><dl class=""serie-credits"">$cred</dl><p class=""serie-liens-vide"">Publier une image ? Précisez la photographie et le support envisagés. Les droits d’utilisation et le crédit du photographe se définissent ensemble avant publication. <a href=""${P}contact.html"">Parlons de votre projet</a>.</p></div>$linksBlock</div>$(Voir-Aussi $a.slug $P $a)")
  [void]$sb.Append("<nav class=""serie-suite"" aria-label=""Autres séries""><a class=""serie-retour"" href=""${P}series/""><span><span class=""serie-kicker"">← Retour</span><strong>Toutes les séries</strong></span></a><a href=""${P}series/$nextSlug/""><img src=""$P$($nx.base)-640.webp"" width=""96"" height=""120"" alt="""" loading=""lazy"" decoding=""async""><span><span class=""serie-kicker"">Série suivante →</span><strong>$(Enc $nextName)</strong></span></a></nav></section>")
  [void]$sb.Append("<nav class=""sc-rail"" aria-label=""Photographies de la série""><ol>$($rail -join '')</ol></nav>")
  [void]$sb.Append("<p class=""serie-compteur"" aria-hidden=""true"">01 / $('{0:00}' -f $total)</p></main>")

  # Longueur du mot le plus long du nom : la taille du grand titre s'adapte pour qu'il tienne toujours à l'écran
  $nl = ($a.nom -split '[\s\-]+' | ForEach-Object { $_.Length } | Measure-Object -Maximum).Maximum
  [void]$css.Append(".sc-nom{--nl:$nl}`n")
  $cssDir = Join-Path $Site 'assets\css\series'; New-Item -ItemType Directory -Force $cssDir | Out-Null
  [IO.File]::WriteAllText((Join-Path $cssDir "$($a.slug)-couleurs.css"), $css.ToString(), (New-Object Text.UTF8Encoding($false)))

  # Données structurées
  $place = if ($a.contexte.lieu) { $a.contexte.lieu } else { $null }
  $nodes = New-Object System.Collections.ArrayList
  foreach ($id in $ids) { $x = Img $id; [void]$nodes.Add((ImageNode $id $url $x.n "$($a.nom) · $($a.photos.$id.legende)" $a.photos.$id.legende $a.photos.$id.alt $place)) }
  $about = [ordered]@{ '@type' = $(if ($SCHEMA_TYPE[$a.slug]) { $SCHEMA_TYPE[$a.slug] } else { 'Person' }); name = $a.nom }
  $same = @($a.liens | ForEach-Object { $_.url }); if ($same.Count) { $about.sameAs = $same }
  $graph = New-Object System.Collections.ArrayList
  [void]$graph.Add([ordered]@{ '@type' = 'ImageGallery'; '@id' = "$url#page"; url = $url; name = $a.seo.title; description = $a.seo.description; inLanguage = 'fr'; isPartOf = @{ '@id' = "$BASE/#site" }; author = @{ '@id' = $PERSON }; about = $about; primaryImageOfPage = @{ '@id' = $nodes[0].'@id' }; hasPart = @($nodes | ForEach-Object { @{ '@id' = $_.'@id' } }) })
  [void]$graph.Add([ordered]@{ '@type' = 'BreadcrumbList'; itemListElement = @(
    [ordered]@{ '@type' = 'ListItem'; position = 1; name = 'Accueil'; item = "$BASE/" },
    [ordered]@{ '@type' = 'ListItem'; position = 2; name = 'Séries'; item = "$BASE/series/" },
    [ordered]@{ '@type' = 'ListItem'; position = 3; name = $a.nom; item = $url }) })
  foreach ($gn in Common-Graph) { [void]$graph.Add($gn) }
  foreach ($nd in $nodes) { [void]$graph.Add($nd) }
  $share = Make-Share $ids[0] "serie-$($a.slug)-1200x630.jpg"
  $seo = Seo $url $a.seo.title $a.seo.description $share $a.photos.($ids[0]).alt @($graph)
  $cssLinks = "<link rel=""stylesheet"" href=""${P}assets/css/series.css?v=$(ShortHash 'assets\css\series.css')""><link rel=""stylesheet"" href=""${P}assets/css/scenes.css?v=$(ShortHash 'assets\css\scenes.css')"">"
  $theme = "assets\css\series\$($a.slug).css"
  if (Test-Path (Join-Path $Site $theme)) { $cssLinks += "<link rel=""stylesheet"" href=""${P}$($theme.Replace('\','/'))?v=$(ShortHash $theme)"">" }
  $cssLinks += "<link rel=""stylesheet"" href=""${P}assets/css/series/$($a.slug)-couleurs.css?v=$(ShortHash "assets\css\series\$($a.slug)-couleurs.css")"">"
  $html = Page $P $a.seo.title $a.seo.description "live-site page-serie page-scenes serie--$($a.theme)" $seo $sb.ToString() $cssLinks (& $JS_SERIE $P)
  if (-not $html.StartsWith('<!doctype html>') -or $html -match '\{\{[A-Z_]+\}\}') { throw "Page $($a.slug) mal assemblée : modèle abîmé ou repère non remplacé" }
  $dir = Join-Path $Site "series\$($a.slug)"; New-Item -ItemType Directory -Force $dir | Out-Null
  [IO.File]::WriteAllText((Join-Path $dir 'index.html'), $html, $utf8)
  $written.Add("series/$($a.slug)/index.html ($total photos, en scènes)")
}
