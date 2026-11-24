<#
  Portfolio — étape 2 : pages.
  Lit donnees.json (artistes, ordre, textes) et images.json (fichiers créés par generer-images.ps1),
  puis écrit : series/index.html (page d'entrée des séries), series/<série>/index.html (une page par artiste
  à partir de 4 photos), series/instantanes/index.html, et les images de partage (assets/seo).
  Aucune règle de style ni aucun script dans le HTML : compatible avec la politique de sécurité du site.

  Lancer (après generer-images.ps1) :
    powershell -NoProfile -ExecutionPolicy Bypass -File _portfolio\generer-pages.ps1
#>
param([string]$Site = (Split-Path $PSScriptRoot -Parent))
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$utf8 = New-Object Text.UTF8Encoding($false)
$D = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'donnees.json'), [Text.Encoding]::UTF8) | ConvertFrom-Json
$I = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'images.json'), [Text.Encoding]::UTF8) | ConvertFrom-Json
$MODELE = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'modele.html'), [Text.Encoding]::UTF8)
$BASE = $D.site
$PERSON = "$BASE/a-propos.html#gabin"; $BUSINESS = "$BASE/contact.html#photographe"
$LICENSE = "$BASE/mentions-legales.html#propriete"

function Enc([string]$txt) { [Net.WebUtility]::HtmlEncode($txt) }
function ShortHash([string]$rel) { (Get-FileHash (Join-Path $Site $rel) -Algorithm SHA256).Hash.Substring(0, 12).ToLower() }
function Img($id) { $x = $I.$id; if (-not $x) { throw "Image absente du manifeste : $id" }; $x }
function RatioCode($x) {
  $r = $x.w / $x.h
  $codes = [ordered]@{ '57' = 0.714; '45' = 0.8; '23' = 0.667; '54' = 1.25; '75' = 1.4; '32' = 1.5; '169' = 1.778; '21' = 2.0 }
  ($codes.GetEnumerator() | Sort-Object { [math]::Abs($_.Value - $r) } | Select-Object -First 1).Key
}
function IsLandscape($x) { $x.w -gt $x.h * 1.05 }
function Src($x, [int]$target, [string]$P) {
  $ws = @($x.widths | ForEach-Object { [int]$_ })
  $pick = ($ws | Where-Object { $_ -le $target } | Sort-Object -Descending | Select-Object -First 1)
  if (-not $pick) { $pick = ($ws | Sort-Object | Select-Object -First 1) }
  "$P$($x.base)-$pick.webp"
}
function Largest($x) { "$($x.base)-$(@($x.widths | ForEach-Object { [int]$_ }) | Sort-Object -Descending | Select-Object -First 1).webp" }
function LargestW($x) { @($x.widths | ForEach-Object { [int]$_ }) | Sort-Object -Descending | Select-Object -First 1 }
function ImgTag($id, [string]$alt, [string]$sizes, [string]$P, [bool]$eager = $false, [string]$cls = '') {
  $x = Img $id
  $srcset = (@($x.widths | ForEach-Object { [int]$_ }) | Sort-Object | ForEach-Object { "$P$($x.base)-$_.webp ${_}w" }) -join ', '
  $load = if ($eager) { 'loading="eager" fetchpriority="high"' } else { 'loading="lazy"' }
  $tone = if ($x.tone) { " data-tone=""$($x.tone)""" } else { '' }
  $c = if ($cls) { " class=""$cls""" } else { '' }
  "<img$c src=""$(Src $x 1024 $P)"" srcset=""$srcset"" sizes=""$sizes"" width=""$($x.w)"" height=""$($x.h)"" alt=""$(Enc $alt)"" $load decoding=""async""$tone>"
}
$LABELS = @{ site = 'Site officiel'; instagram = 'Instagram'; facebook = 'Facebook'; tiktok = 'TikTok'; youtube = 'YouTube'; spotify = 'Spotify'; apple = 'Apple Music'; deezer = 'Deezer'; soundcloud = 'SoundCloud' }
$SCHEMA_TYPE = @{ 'feu-chatterton' = 'MusicGroup'; 'electro-symphony' = 'PerformingGroup' }
function ContextLine($a) {
  $c = $a.contexte; if (-not $c) { return '' }
  (@($c.evenement, $c.lieu, $c.date) | Where-Object { $_ -and ($_ -ne $c.evenement -or $c.evenement -ne $a.nom) }) -join ' · '
}

# Tailles d'affichage (attribut sizes) selon le plan
$SIZES = @{
  'ouverture-portrait' = '(max-width: 700px) 100vw, 46vw'; 'ouverture-rideau' = '(max-width: 700px) 100vw, 46vw'
  'ouverture-cinema' = '100vw'; 'ouverture-large' = '(max-width: 1300px) 100vw, 1200px'
  'decale' = '(max-width: 700px) 86vw, 44vw'; 'diptyque' = '(max-width: 700px) 88vw, 42vw'
  'triptyque' = '(max-width: 700px) 78vw, 30vw'; 'plein' = '100vw'; 'plein-texte' = '(max-width: 1300px) 100vw, 1200px'
  'respiration' = '(max-width: 700px) 62vw, 26vw'; 'planche' = '(max-width: 700px) 78vw, 22vw'
  'sequence' = '(max-width: 700px) 92vw, 46vw'; 'final' = '(max-width: 700px) 100vw, 60vw'; 'final-paysage' = '(max-width: 1300px) 100vw, 1200px'
}

# --- Image de partage 1200 x 630 (recadrage centré, un peu au-dessus du milieu pour garder les visages) ---
function Make-Share($id, [string]$name) {
  $x = Img $id
  $src = Join-Path (Join-Path $D.source $x.dossier) $x.source
  $out = Join-Path $Site "assets\seo\$name"
  if ((Test-Path $out) -and (Get-Item $out).LastWriteTime -gt (Get-Item $src).LastWriteTime) { return "assets/seo/$name" }
  $img = [System.Drawing.Image]::FromFile($src)
  $tw = 1200; $th = 630; $k = [math]::Max($tw / $img.Width, $th / $img.Height)
  $sw = $tw / $k; $sh = $th / $k
  $sx = ($img.Width - $sw) / 2; $sy = [math]::Max(0, [math]::Min($img.Height - $sh, ($img.Height - $sh) * 0.3))
  $bmp = New-Object System.Drawing.Bitmap $tw, $th
  $g = [System.Drawing.Graphics]::FromImage($bmp); $g.InterpolationMode = 'HighQualityBicubic'
  $g.DrawImage($img, (New-Object System.Drawing.Rectangle 0, 0, $tw, $th), [single]$sx, [single]$sy, [single]$sw, [single]$sh, [System.Drawing.GraphicsUnit]::Pixel)
  $enc = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object MimeType -eq 'image/jpeg'
  $ep = New-Object System.Drawing.Imaging.EncoderParameters 1; $ep.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter ([System.Drawing.Imaging.Encoder]::Quality, [long]82)
  $bmp.Save($out, $enc, $ep); $g.Dispose(); $bmp.Dispose(); $img.Dispose()
  "assets/seo/$name"
}

# --- Bloc SEO de la page (canonique, partage, données structurées) ---
function Seo($url, $title, $desc, $shareRel, $shareAlt, $graph) {
  $ld = [ordered]@{ '@context' = 'https://schema.org'; '@graph' = $graph } | ConvertTo-Json -Depth 12
  @"
<link rel="canonical" href="$url">
<meta name="robots" content="index,follow,max-image-preview:large">
<meta property="og:type" content="website"><meta property="og:site_name" content="Gabin Spieser"><meta property="og:locale" content="fr_FR">
<meta property="og:title" content="$(Enc $title)"><meta property="og:description" content="$(Enc $desc)"><meta property="og:url" content="$url">
<meta property="og:image" content="$BASE/$shareRel"><meta property="og:image:type" content="image/jpeg"><meta property="og:image:width" content="1200"><meta property="og:image:height" content="630"><meta property="og:image:alt" content="$(Enc $shareAlt)">
<meta name="twitter:card" content="summary_large_image"><meta name="twitter:title" content="$(Enc $title)"><meta name="twitter:description" content="$(Enc $desc)"><meta name="twitter:image" content="$BASE/$shareRel"><meta name="twitter:image:alt" content="$(Enc $shareAlt)">
<script type="application/ld+json">
$ld
</script>
"@
}
function Common-Graph() {
  @(
    [ordered]@{ '@type' = 'WebSite'; '@id' = "$BASE/#site"; url = "$BASE/"; name = 'Gabin Spieser'; inLanguage = 'fr'; publisher = @{ '@id' = $BUSINESS } },
    [ordered]@{ '@type' = 'Person'; '@id' = $PERSON; name = 'Gabin Spieser'; url = "$BASE/a-propos.html"; jobTitle = "Photographe de concerts et d’artistes"; sameAs = @('https://www.instagram.com/spieraw/', 'https://www.facebook.com/spieraw/', 'https://www.behance.net/gabinspieserphoto') }
  )
}
function ImageNode($id, $pageUrl, $num, $name, $caption, $alt, $place) {
  $x = Img $id
  $n = [ordered]@{ '@type' = 'ImageObject'; '@id' = "$pageUrl#photo-$('{0:00}' -f $num)"; contentUrl = "$BASE/$(Largest $x)"; thumbnailUrl = "$BASE/$($x.base)-640.webp"
    name = $name; caption = $caption; description = $alt; width = (LargestW $x); height = [int][math]::Round((LargestW $x) * $x.h / $x.w)
    creator = @{ '@id' = $PERSON }; creditText = 'Gabin Spieser'; copyrightNotice = '© Gabin Spieser. Tous droits réservés.'; license = $LICENSE; acquireLicensePage = $LICENSE }
  if ($place) { $n.contentLocation = [ordered]@{ '@type' = 'Place'; name = $place } }
  $n
}

# --- Assemblage d'une page à partir du modèle ---
function Page([string]$P, [string]$title, [string]$desc, [string]$body, [string]$seo, [string]$main, [string]$css, [string]$js) {
  $h = $MODELE.Replace('{{TITLE}}', (Enc $title)).Replace('{{DESCRIPTION}}', (Enc $desc)).Replace('{{BODY}}', $body)
  $h = $h.Replace('{{SEO}}', $seo).Replace('{{CSS}}', $css).Replace('{{JS}}', $js)
  $h = $h.Replace('{{V_AMB_CSS}}', (ShortHash 'assets\css\ambiance.css')).Replace('{{V_AMB_JS}}', (ShortHash 'ambiance.js'))
  $h = $h.Replace('{{MAIN}}', $main)
  $h.Replace('{{P}}', $P)
}
$CSS_SERIE = { param($P) "<link rel=""stylesheet"" href=""${P}assets/css/series.css?v=$(ShortHash 'assets\css\series.css')"">" }
$JS_SERIE = { param($P) "<script src=""${P}series.js?v=$(ShortHash 'series.js')"" defer></script>" }

# --- Une photo de série ---
function Fig($a, $id, $sizesKey, [string]$P, [bool]$eager = $false, [bool]$vue = $false) {
  $x = Img $id; $meta = $a.photos.$id
  $num = '{0:00}' -f $x.n
  $title = "$($meta.legende) · $($a.nom)"
  $vueTxt = if ($vue) { "<span class=""serie-vue"">Vue $(($id -replace '\D', '').TrimStart('0'))</span>" } else { '' }
  @"
<figure class="serie-photo" id="photo-$num" data-r="$(RatioCode $x)"><a class="photo-open" href="$P$(Largest $x)" data-photo="$($x.n)" data-title="$(Enc $title)">$(ImgTag $id $meta.alt $SIZES[$sizesKey] $P $eager)</a><figcaption class="serie-legende"><span class="serie-num">$num</span><span>$(Enc $meta.legende)</span>$vueTxt</figcaption></figure>
"@
}
function Plan($a, $pl, [string]$P) {
  $t = $pl.type
  switch ($t) {
    'decale' { "<div class=""serie-plan serie-plan--decale"" data-cote=""$($pl.cote)"">$(Fig $a $pl.photos[0] 'decale' $P)</div>" }
    'diptyque' { $inv = if ($pl.variante -eq 'inverse') { ' is-inverse' } else { '' }; "<div class=""serie-plan serie-plan--diptyque$inv"">$(($pl.photos | ForEach-Object { Fig $a $_ 'diptyque' $P }) -join '')</div>" }
    'triptyque' { $esc = if ($pl.variante -eq 'escalier') { ' is-escalier' } else { '' }; "<div class=""serie-plan serie-plan--triptyque$esc"">$(($pl.photos | ForEach-Object { Fig $a $_ 'triptyque' $P }) -join '')</div>" }
    'plein' {
      $x = Img $pl.photos[0]
      $texte = ($pl.variante -eq 'texte') -or ((LargestW $x) -lt 2400)
      $cls = if ($texte) { ' is-texte' } else { '' }; $key = if ($texte) { 'plein-texte' } else { 'plein' }
      "<div class=""serie-plan serie-plan--plein$cls"">$(Fig $a $pl.photos[0] $key $P)</div>" }
    'respiration' { "<div class=""serie-plan serie-plan--respiration"">$(Fig $a $pl.photos[0] 'respiration' $P)</div>" }
    'planche' { "<div class=""serie-plan serie-plan--planche"">$(($pl.photos | ForEach-Object { Fig $a $_ 'planche' $P $false $true }) -join '')</div>" }
    'sequence' {
      $n = @($pl.photos).Count
      $marks = (1..$n | ForEach-Object { '<li></li>' }) -join ''
      "<div class=""serie-plan serie-plan--sequence"" data-n=""$n""><div class=""serie-seq-cadre"">$(($pl.photos | ForEach-Object { Fig $a $_ 'sequence' $P }) -join '')<ol class=""serie-seq-reperes"" aria-hidden=""true"">$marks</ol></div></div>" }
    'final' { $x = Img $pl.photos[0]; $key = if (IsLandscape $x) { 'final-paysage' } else { 'final' }; "<div class=""serie-plan serie-plan--final"">$(Fig $a $pl.photos[0] $key $P)</div>" }
    default { throw "Type de plan inconnu : $t ($($a.slug))" }
  }
}
function Links-List($liens) {
  if (-not $liens -or @($liens).Count -eq 0) { return '' }
  $items = ($liens | ForEach-Object { "<li><a href=""$(Enc $_.url)"" target=""_blank"" rel=""noopener noreferrer"">$($LABELS[$_.type]) <span aria-hidden=""true"">Ouvrir →</span><span class=""caption-sr-only""> (nouvel onglet)</span></a></li>" }) -join ''
  "<ul class=""serie-liens"">$items</ul>"
}

# --- Ordre des séries (pour « Série suivante ») ---
$seriesOrder = @($D.ordre_index | Where-Object { $_ -notlike '@*' -or $_ -eq '@ina' } | ForEach-Object { if ($_ -eq '@ina') { 'ina-forsman' } else { $_ } })
$bySlug = @{}; foreach ($a in $D.artistes) { $bySlug[$a.slug] = $a }
function CoverId($a) { if ($a.slug -eq 'instantanes') { return 'GAB09552-2' }; (PhotoIds $a)[0] }

# Séries construites en scènes (nouveau système du 25/11/2026)
. (Join-Path $PSScriptRoot 'scenes.ps1')

# ======================= Pages des séries =======================
$written = New-Object System.Collections.Generic.List[string]
foreach ($a in $D.artistes) {
  if ($a.scenes) { Build-ScenePage $a; continue }
  $P = '../../'; $url = "$BASE/series/$($a.slug)/"
  $total = 0; foreach ($c in $a.chapitres) { foreach ($pl in $c.plans) { $total += @($pl.photos).Count } }
  $ctx = ContextLine $a
  $first = $a.chapitres[0]; $open = $first.plans[0]
  if ($open.type -ne 'ouverture') { throw "La série $($a.slug) doit commencer par une ouverture" }
  $variant = $open.variante
  $openFig = Fig $a $open.photos[0] "ouverture-$variant" $P $true
  $ctxHtml = if ($ctx) { "<p class=""serie-contexte"">$(Enc $ctx)</p>" } else { '' }
  $sb = New-Object Text.StringBuilder
  [void]$sb.Append("<main id=""contenu"" class=""serie"">")
  [void]$sb.Append("<nav class=""serie-fil"" data-fond=""$($a.chapitres[0].fond)"" aria-label=""Fil d’Ariane""><a href=""${P}"">Accueil</a> / <a href=""${P}series/"">Séries</a> / <span aria-current=""page"">$(Enc $a.nom)</span></nav>")
  [void]$sb.Append("<header class=""serie-ouverture serie-ouverture--$variant"" data-fond=""$($first.fond)""><div class=""serie-ouverture-texte""><p class=""serie-kicker"">Série · $total photographies</p><h1 class=""serie-nom"">$(Enc $a.nom)</h1><p class=""serie-titre"">$(Enc $a.titre_serie)</p>$ctxHtml</div>$openFig</header>")
  [void]$sb.Append("<section class=""serie-intro"" data-fond=""$($first.fond)"" aria-label=""Présentation de la série""><p class=""serie-kicker"">La série</p><p>$(Enc $a.presentation)</p></section>")
  $romans = @('I', 'II', 'III', 'IV', 'V', 'VI', 'VII', 'VIII')
  for ($ci = 0; $ci -lt $a.chapitres.Count; $ci++) {
    $c = $a.chapitres[$ci]
    $plans = @($c.plans); if ($ci -eq 0) { $plans = @($plans | Select-Object -Skip 1) }
    if ($plans.Count -eq 0) { continue }
    $hid = "chapitre-$($ci + 1)"
    $sous = if ($c.sous_titre) { "<p class=""serie-sous"">$(Enc $c.sous_titre)</p>" } else { '' }
    [void]$sb.Append("<section class=""serie-chapitre"" data-fond=""$($c.fond)"" aria-labelledby=""$hid""><header class=""serie-chapitre-tete""><p class=""serie-chapitre-num"" aria-hidden=""true"">$($romans[$ci])</p><h2 id=""$hid"">$(Enc $c.titre)</h2>$sous</header>")
    foreach ($pl in $plans) { [void]$sb.Append((Plan $a $pl $P)) }
    [void]$sb.Append('</section>')
    $next = if ($ci + 1 -lt $a.chapitres.Count) { $a.chapitres[$ci + 1].fond } else { $null }
    if ($next -and $next -ne $c.fond) { [void]$sb.Append("<div class=""serie-fondu"" data-de=""$($c.fond)"" data-vers=""$next"" aria-hidden=""true""></div>") }
  }
  # Verso : crédits, liens officiels, suite
  $cred = "<dt>Artiste</dt><dd>$(Enc $a.nom)</dd><dt>Série</dt><dd>$(Enc $a.titre_serie)</dd>"
  if ($a.contexte.evenement -and $a.contexte.evenement -ne $a.nom) { $cred += "<dt>Événement</dt><dd>$(Enc $a.contexte.evenement)</dd>" }
  if ($a.contexte.lieu) { $cred += "<dt>Lieu</dt><dd>$(Enc $a.contexte.lieu)</dd>" }
  if ($a.contexte.date) { $cred += "<dt>Date</dt><dd>$(Enc $a.contexte.date)</dd>" }
  $cred += "<dt>Photographies</dt><dd>Gabin Spieser · $total images</dd>"
  $links = Links-List $a.liens
  $linksBlock = if ($links) { "<div><h2 id=""ecouter"">Écouter, suivre</h2>$links</div>" } else { '' }
  $k = [array]::IndexOf($seriesOrder, $a.slug); $nextSlug = $seriesOrder[($k + 1) % $seriesOrder.Count]
  if ($nextSlug -eq 'instantanes') { $nextName = 'Instantanés'; $nextCover = 'GAB09552-2'; $nextImgAlt = '' } else { $na = $bySlug[$nextSlug]; $nextName = $na.nom; $nextCover = CoverId $na }
  $nx = Img $nextCover
  [void]$sb.Append("<section class=""serie-verso"" aria-labelledby=""verso-titre""><div class=""serie-verso-grille""><div><h2 id=""verso-titre"">Crédits</h2><dl class=""serie-credits"">$cred</dl><p class=""serie-liens-vide"">Publier une image ? Précisez la photographie et le support envisagés. Les droits d’utilisation et le crédit du photographe se définissent ensemble avant publication. <a href=""${P}contact.html"">Parlons de votre projet</a>.</p></div>$linksBlock</div>")
  [void]$sb.Append("<nav class=""serie-suite"" aria-label=""Autres séries""><a class=""serie-retour"" href=""${P}series/""><span><span class=""serie-kicker"">← Retour</span><strong>Toutes les séries</strong></span></a><a href=""${P}series/$nextSlug/""><img src=""$P$($nx.base)-640.webp"" width=""96"" height=""120"" alt="""" loading=""lazy"" decoding=""async""><span><span class=""serie-kicker"">Série suivante →</span><strong>$(Enc $nextName)</strong></span></a></nav></section>")
  [void]$sb.Append("<p class=""serie-compteur"" aria-hidden=""true"">01 / $('{0:00}' -f $total)</p></main>")

  # Données structurées
  $graph = New-Object System.Collections.ArrayList
  $place = if ($a.contexte.lieu) { $a.contexte.lieu } else { $null }
  $nodes = New-Object System.Collections.ArrayList
  foreach ($c in $a.chapitres) { foreach ($pl in $c.plans) { foreach ($id in $pl.photos) { $x = Img $id; [void]$nodes.Add((ImageNode $id $url $x.n "$($a.nom) · $($a.photos.$id.legende)" $a.photos.$id.legende $a.photos.$id.alt $place)) } } }
  $about = [ordered]@{ '@type' = $(if ($SCHEMA_TYPE[$a.slug]) { $SCHEMA_TYPE[$a.slug] } else { 'Person' }); name = $a.nom }
  $same = @($a.liens | ForEach-Object { $_.url }); if ($same.Count) { $about.sameAs = $same }
  [void]$graph.Add([ordered]@{ '@type' = 'ImageGallery'; '@id' = "$url#page"; url = $url; name = $a.seo.title; description = $a.seo.description; inLanguage = 'fr'; isPartOf = @{ '@id' = "$BASE/#site" }; author = @{ '@id' = $PERSON }; about = $about; primaryImageOfPage = @{ '@id' = $nodes[0].'@id' }; hasPart = @($nodes | ForEach-Object { @{ '@id' = $_.'@id' } }) })
  [void]$graph.Add([ordered]@{ '@type' = 'BreadcrumbList'; itemListElement = @(
    [ordered]@{ '@type' = 'ListItem'; position = 1; name = 'Accueil'; item = "$BASE/" },
    [ordered]@{ '@type' = 'ListItem'; position = 2; name = 'Séries'; item = "$BASE/series/" },
    [ordered]@{ '@type' = 'ListItem'; position = 3; name = $a.nom; item = $url }) })
  foreach ($g in Common-Graph) { [void]$graph.Add($g) }
  foreach ($nd in $nodes) { [void]$graph.Add($nd) }
  $share = Make-Share $open.photos[0] "serie-$($a.slug)-1200x630.jpg"
  $seo = Seo $url $a.seo.title $a.seo.description $share $a.photos.($open.photos[0]).alt @($graph)
  $html = Page $P $a.seo.title $a.seo.description "live-site page-serie serie--$($a.theme)" $seo $sb.ToString() (& $CSS_SERIE $P) (& $JS_SERIE $P)
  $dir = Join-Path $Site "series\$($a.slug)"; New-Item -ItemType Directory -Force $dir | Out-Null
  [IO.File]::WriteAllText((Join-Path $dir 'index.html'), $html, $utf8)
  $written.Add("series/$($a.slug)/index.html ($total photos)")
}

# ======================= Instantanés : le carnet de fosse (instantanes.ps1) =======================
$S = $D.instantanes
$nb = 0; foreach ($ia in $S.artistes) { $nb += @($ia.ordre).Count }
. (Join-Path $PSScriptRoot 'instantanes.ps1')
Build-InstantanesPage $S

# ======================= Page d'entrée des séries : le kiosque (kiosque.ps1) =======================
. (Join-Path $PSScriptRoot 'kiosque.ps1')
Build-Kiosque
"Pages écrites :"; $written | ForEach-Object { "  $_" }
