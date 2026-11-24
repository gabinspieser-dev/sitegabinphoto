<#
  Portfolio — étape 3 : remplace les anciennes photos sur les autres pages du site
  (accueil, contact, prestations, reportages) par des photos du nouveau fonds, en gardant
  exactement la même structure HTML (donc la même mise en page), et met à jour les données
  structurées et les images de partage de ces pages.
  À lancer une seule fois après generer-pages.ps1 (le script refuse de tourner deux fois).
#>
param([string]$Site = (Split-Path $PSScriptRoot -Parent))
$ErrorActionPreference = 'Stop'
$utf8 = New-Object Text.UTF8Encoding($false)
$D = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'donnees.json'), [Text.Encoding]::UTF8) | ConvertFrom-Json
$I = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'images.json'), [Text.Encoding]::UTF8) | ConvertFrom-Json
$BASE = $D.site; $PERSON = "$BASE/a-propos.html#gabin"; $LICENSE = "$BASE/mentions-legales.html#propriete"
function Enc([string]$s) { [Net.WebUtility]::HtmlEncode($s) }

# Tout ce qu'on sait d'une photo : artiste, texte alternatif, légende, contexte, liens
$INFO = @{}
foreach ($a in $D.artistes) { foreach ($k in $a.photos.PSObject.Properties) { $INFO[$k.Name] = @{ a = $a; alt = $k.Value.alt; leg = $k.Value.legende; slug = $a.slug } } }
foreach ($a in $D.instantanes.artistes) { foreach ($k in $a.photos.PSObject.Properties) { $INFO[$k.Name] = @{ a = $a; alt = $k.Value.alt; leg = $k.Value.legende; slug = 'instantanes' } } }
foreach ($k in $D.public.photos.PSObject.Properties) { $INFO[$k.Name] = @{ a = $null; alt = $k.Value.alt; leg = 'Le public'; slug = $null } }
function Ctx($a) { if (-not $a -or -not $a.contexte) { return '' }; $c = $a.contexte; (@($c.evenement, $c.lieu, $c.date) | Where-Object { $_ -and $_ -ne $a.nom }) -join ' · ' }
function Largest($x) { "$($x.base)-$(@($x.widths | ForEach-Object { [int]$_ }) | Sort-Object -Descending | Select-Object -First 1).webp" }
function LargestW($x) { @($x.widths | ForEach-Object { [int]$_ }) | Sort-Object -Descending | Select-Object -First 1 }
function Pick($x, $t) { $ws = @($x.widths | ForEach-Object { [int]$_ }); $p = $ws | Where-Object { $_ -le $t } | Sort-Object -Descending | Select-Object -First 1; if (-not $p) { $p = ($ws | Sort-Object)[0] }; "$($x.base)-$p.webp" }

# Icônes des liens d'artiste : reprises telles quelles de l'ancienne page d'accueil
$orig = [IO.File]::ReadAllText('C:\Users\gabin.spieser\Documents\Maintenance\archives-site\avant-portfolio-2026-11-24\index.html', [Text.Encoding]::UTF8)
$ICON = @{}
foreach ($pair in @(@('site', 'Site officiel'), @('instagram', 'Instagram'), @('facebook', 'Facebook'), @('spotify', 'Spotify'))) {
  $m = [regex]::Match($orig, '(?s)title="' + $pair[1] + '">(<svg\b.*?</svg>)</a>')
  if (-not $m.Success) { throw "Icône introuvable : $($pair[1])" }
  $ICON[$pair[0]] = @{ svg = $m.Groups[1].Value; label = $pair[1] }
}
$LBL = @{ site = 'Site officiel de'; instagram = 'Instagram de'; facebook = 'Facebook de'; spotify = 'Spotify de' }

# Nouvelle figure, même structure que l'ancienne (classes, ordre des éléments)
function New-Figure([string]$oldFig, [string]$id, [string]$key) {
  $x = $I.$id; $inf = $INFO[$id]; $a = $inf.a
  $name = if ($a) { $a.nom } else { 'Le public' }
  $sizes = [regex]::Match($oldFig, 'sizes="([^"]+)"').Groups[1].Value
  $srcset = (@($x.widths | ForEach-Object { [int]$_ }) | Sort-Object | ForEach-Object { "./$($x.base)-$_.webp ${_}w" }) -join ', '
  $title = Enc $inf.leg
  $img = "<img class="""" src=""./$(Pick $x 1100)"" srcset=""$srcset"" sizes=""$sizes"" width=""$($x.w)"" height=""$($x.h)"" alt=""$(Enc $inf.alt)"" loading=""lazy"" decoding=""async"" data-tone=""$($x.tone)"">"
  $nameHtml = if ($inf.slug -and $inf.slug -ne 'instantanes') { "<a href=""./portfolio/$($inf.slug)/"">$(Enc $name)</a>" } elseif ($inf.slug -eq 'instantanes') { "<a href=""./portfolio/instantanes/#$($a.slug)"">$(Enc $name)</a>" } else { Enc $name }
  $ctx = Ctx $a; $event = if ($ctx) { "<p class=""artist-event"">$(Enc $ctx)</p>" } else { '' }
  $links = ''
  if ($a -and $a.liens) {
    $li = foreach ($l in $a.liens) { if ($ICON.ContainsKey($l.type)) { "<li><a class=""artist-link"" href=""$(Enc $l.url)"" target=""_blank"" rel=""noopener noreferrer"" aria-label=""$($LBL[$l.type]) $(Enc $name) (nouvel onglet)"" title=""$($ICON[$l.type].label)"">$($ICON[$l.type].svg)</a></li>" } }
    if ($li) { $links = "<ul class=""artist-links"" aria-label=""L’univers de $(Enc $name)"">$($li -join '')</ul>" }
  }
  $btn = [regex]::Match($oldFig, '(?s)<button class="photo-expand".*?</button>').Value
  $btn = [regex]::Replace($btn, 'aria-label="Agrandir : [^"]*"', "aria-label=""Agrandir : $title""")
  $num = '{0:00}' -f $x.n
  "<figure class=""live-photo interactive-photo"" id=""photo-$key""><a class=""photo-open"" href=""./$(Largest $x)"" data-photo=""$key"" data-title=""$title"" aria-label=""Voir en grand : $title"">$img<span class=""photo-zoom"" aria-hidden=""true"">Agrandir</span></a><figcaption class=""photo-caption"" id=""caption-$key""><p class=""artist-name"">$nameHtml</p>$event<div class=""photo-caption-actions"">$links$btn</div><span class=""photo-number"">$num</span></figcaption></figure>"
}
function ImageNode([string]$id, [string]$pageUrl, [string]$key) {
  $x = $I.$id; $inf = $INFO[$id]; $name = if ($inf.a) { "$($inf.a.nom) · $($inf.leg)" } else { $inf.leg }
  $n = [ordered]@{ '@type' = 'ImageObject'; '@id' = "$pageUrl#image-$key"; contentUrl = "$BASE/$(Largest $x)"; thumbnailUrl = "$BASE/$($x.base)-640.webp"; name = $name; caption = $inf.leg; description = $inf.alt
    width = (LargestW $x); height = [int][math]::Round((LargestW $x) * $x.h / $x.w); creator = @{ '@id' = $PERSON }; creditText = 'Gabin Spieser'; copyrightNotice = '© Gabin Spieser. Tous droits réservés.'; license = $LICENSE; acquireLicensePage = $LICENSE }
  if ($inf.a -and $inf.a.contexte -and $inf.a.contexte.lieu) { $n.contentLocation = [ordered]@{ '@type' = 'Place'; name = $inf.a.contexte.lieu } }
  $n
}
# Données structurées : retire les anciennes images, ajoute les nouvelles, répare les renvois
function Fix-JsonLd([string]$html, [string]$pageUrl, $newNodes, [string]$shareUrl) {
  $m = [regex]::Match($html, '(?s)<script type="application/ld\+json">(.*?)</script>')
  if (-not $m.Success) { return $html }
  $obj = $m.Groups[1].Value | ConvertFrom-Json
  $graph = @($obj.'@graph')
  $removed = @($graph | Where-Object { $_.'@type' -eq 'ImageObject' -and $_.contentUrl -match '/assets/photos/' } | ForEach-Object { $_.'@id' })
  $graph = @($graph | Where-Object { -not ($_.'@type' -eq 'ImageObject' -and $_.contentUrl -match '/assets/photos/') })
  $firstNew = if ($newNodes.Count) { $newNodes[0].'@id' } else { $null }
  foreach ($node in $graph) {
    foreach ($prop in @($node.PSObject.Properties)) {
      $v = $prop.Value
      if ($v -is [array]) {
        $keep = @($v | Where-Object { -not ($_ -is [pscustomobject] -and $_.'@id' -and $removed -contains $_.'@id') })
        if ($prop.Name -eq 'hasPart' -or $prop.Name -eq 'image') { $keep += @($newNodes | ForEach-Object { [pscustomobject]@{ '@id' = $_.'@id' } }) }
        $node.($prop.Name) = $keep
      } elseif ($v -is [pscustomobject] -and $v.'@id' -and $removed -contains $v.'@id') {
        if ($firstNew) { $node.($prop.Name) = [pscustomobject]@{ '@id' = $firstNew } } else { $node.PSObject.Properties.Remove($prop.Name) }
      } elseif ($v -is [string] -and $v -match '/assets/seo/partage-') { $node.($prop.Name) = $shareUrl }
    }
  }
  $obj.'@graph' = @($graph) + @($newNodes)
  $json = $obj | ConvertTo-Json -Depth 15
  $html.Substring(0, $m.Groups[1].Index) + "`n" + $json + "`n" + $html.Substring($m.Groups[1].Index + $m.Groups[1].Length)
}
function Fix-Share([string]$html, [string]$shareRel, [string]$alt) {
  $html = [regex]::Replace($html, '(content=")https://gabin-spieser\.com/assets/seo/partage-[^"]+(")', "`${1}$BASE/$shareRel`$2")
  $html = [regex]::Replace($html, '(<meta (?:property="og:image:alt"|name="twitter:image:alt") content=")[^"]*(")', "`${1}$(Enc $alt)`$2")
  $html
}

# Image de partage de l'accueil (photo d'Ina Forsman) et des pages concernées
. (Join-Path $PSScriptRoot 'partage.ps1')
$shareHome = Make-Share $D $I 'GAB06891' 'accueil-1200x630.jpg' $Site
$sharePortrait = Make-Share $D $I 'GAB06739' 'portrait-artiste-1200x630.jpg' $Site
$shareConcert = Make-Share $D $I 'GAB01559-2' 'concert-festival-1200x630.jpg' $Site
$shareFoire = Make-Share $D $I 'GAB02346' 'foire-en-scene-1200x630.jpg' $Site
$shareElectro = 'assets/seo/serie-electro-symphony-1200x630.jpg'

$PLAN = @(
  @{ page = 'index.html'; share = $shareHome; shareAlt = $INFO['GAB06891'].alt; figs = [ordered]@{ '05' = 'GAB02571'; '06' = 'GAB00904'; '07' = 'GAB08678'; '03' = 'GAB00068'; '25' = 'IMG_5512'; '24' = 'IMG_3835' } },
  @{ page = 'portrait-artiste.html'; share = $sharePortrait; shareAlt = $INFO['GAB06739'].alt; figs = [ordered]@{ '10' = 'GAB06739'; '07' = 'GAB08376' } },
  @{ page = 'photographe-concert-festival.html'; share = $shareConcert; shareAlt = $INFO['GAB01559-2'].alt; figs = [ordered]@{ '05' = 'GAB01559-2'; '06' = 'GAB03003' } },
  @{ page = 'foire-en-scene-chalons-en-champagne.html'; share = $shareFoire; shareAlt = $INFO['GAB02346'].alt; figs = [ordered]@{ '05' = 'GAB02346'; '04' = 'GAB02741'; '06' = 'GAB00843' } },
  @{ page = 'electro-symphony-reims-arena.html'; share = $shareElectro; shareAlt = $INFO['GAB00267'].alt; figs = [ordered]@{ '12' = 'IMG_5502'; '19' = 'IMG_5478' } }
)
foreach ($p in $PLAN) {
  $path = Join-Path $Site $p.page
  $html = [IO.File]::ReadAllText($path, [Text.Encoding]::UTF8)
  if ($html -notmatch 'assets/photos/') { throw "$($p.page) : plus aucune ancienne photo, le script a déjà tourné." }
  $url = if ($p.page -eq 'index.html') { "$BASE/" } else { "$BASE/$($p.page)" }
  $nodes = New-Object System.Collections.ArrayList
  $k = 0
  foreach ($old in $p.figs.Keys) {
    $k++; $id = $p.figs[$old]; $key = "n$k"
    $m = [regex]::Match($html, '(?s)<figure class="live-photo interactive-photo" id="photo-' + $old + '">.*?</figure>')
    if (-not $m.Success) { throw "$($p.page) : figure photo-$old introuvable" }
    $html = $html.Substring(0, $m.Index) + (New-Figure $m.Value $id $key) + $html.Substring($m.Index + $m.Length)
    [void]$nodes.Add((ImageNode $id $url $key))
  }
  $html = Fix-JsonLd $html $url @($nodes) "$BASE/$($p.share)"
  $html = Fix-Share $html $p.share $p.shareAlt
  [IO.File]::WriteAllText($path, $html, $utf8)
  "{0,-42} {1} photos remplacées, anciennes références restantes : {2}" -f $p.page, $p.figs.Count, ([regex]::Matches($html, 'assets/photos/')).Count
}

# Page d'accueil : nouvelle image d'ouverture (Ina Forsman), sans recadrage imposé
$path = Join-Path $Site 'index.html'; $html = [IO.File]::ReadAllText($path, [Text.Encoding]::UTF8)
$x = $I.GAB06891
$srcset = (@($x.widths | ForEach-Object { [int]$_ }) | Sort-Object | ForEach-Object { "./$($x.base)-$_.webp ${_}w" }) -join ', '
$hero = "<picture class=""live-hero-picture""><img class=""live-hero-image"" src=""./$(Pick $x 1100)"" srcset=""$srcset"" sizes=""(max-width: 600px) 100vw, (max-width: 900px) 100vw, 50vw"" width=""$($x.w)"" height=""$($x.h)"" alt=""$(Enc $INFO['GAB06891'].alt)"" loading=""eager"" decoding=""async"" fetchpriority=""high"" data-tone=""nb""></picture>"
$html = [regex]::Replace($html, '(?s)<picture class="live-hero-picture">.*?</picture>', [System.Text.RegularExpressions.MatchEvaluator] { param($mm) $hero })
$html = $html.Replace('<div class="live-hero-caption"><span>La musique se vit. Les images restent.</span><span>Châlons-en-Champagne · France</span></div>', '<div class="live-hero-caption"><span>La musique se vit. Les images restent.</span><span>Châlons-en-Champagne · France</span><a href="./portfolio/ina-forsman/">Photo : Ina Forsman · voir la série</a></div>')
$total = @($I.PSObject.Properties).Count
$html = $html.Replace('Entrer dans le portfolio · 32 photographies', "Entrer dans le portfolio · $total photographies")
$heroNode = ImageNode 'GAB06891' "$BASE/" 'ouverture'
$html = Fix-JsonLd $html "$BASE/" @($heroNode) "$BASE/$shareHome"
[IO.File]::WriteAllText($path, $html, $utf8)
"index.html : ouverture remplacée, anciennes références restantes : " + ([regex]::Matches($html, 'assets/photos/')).Count

# Contact : la photo du bloc de contact
$path = Join-Path $Site 'contact.html'; $html = [IO.File]::ReadAllText($path, [Text.Encoding]::UTF8)
$x = $I.GAB00283; $inf = $INFO['GAB00283']
$m = [regex]::Match($html, '(?s)<figure class="contact-photo">.*?</figure>')
$oldImg = [regex]::Match($m.Value, '<img\b[^>]*>').Value
$sizes = [regex]::Match($oldImg, 'sizes="([^"]+)"').Groups[1].Value
$srcset = (@($x.widths | ForEach-Object { [int]$_ }) | Sort-Object | ForEach-Object { "./$($x.base)-$_.webp ${_}w" }) -join ', '
$newImg = [regex]::Replace($oldImg, '\ssrc="[^"]*"', " src=""./$(Pick $x 1100)""")
$newImg = [regex]::Replace($newImg, '\ssrcset="[^"]*"', " srcset=""$srcset""")
$newImg = [regex]::Replace($newImg, '\swidth="\d+"', " width=""$($x.w)""")
$newImg = [regex]::Replace($newImg, '\sheight="\d+"', " height=""$($x.h)""")
$newImg = [regex]::Replace($newImg, '\salt="[^"]*"', " alt=""$(Enc $inf.alt)""")
if ($newImg -notmatch 'data-tone') { $newImg = $newImg.Replace('>', " data-tone=""$($x.tone)"">") }
$newFig = $m.Value.Replace($oldImg, $newImg)
$newFig = [regex]::Replace($newFig, '<figcaption>[^<]*</figcaption>', "<figcaption><a href=""./portfolio/christophe-mae/"">Christophe Maé</a></figcaption>")
$newFig = [regex]::Replace($newFig, '(<a\b[^>]*href=")[^"]*assets/photos/[^"]*(")', "`${1}./$(Largest $x)`$2")
$html = $html.Substring(0, $m.Index) + $newFig + $html.Substring($m.Index + $m.Length)
$html = Fix-JsonLd $html "$BASE/contact.html" @((ImageNode 'GAB00283' "$BASE/contact.html" 'contact')) "$BASE/$shareHome"
$html = Fix-Share $html $shareHome $INFO['GAB06891'].alt
[IO.File]::WriteAllText($path, $html, $utf8)
"contact.html : photo remplacée, anciennes références restantes : " + ([regex]::Matches($html, 'assets/photos/')).Count

# Les autres pages : l'ancienne image de partage (One Night of Queen) remplacée par celle de l'accueil
foreach ($f in Get-ChildItem $Site -Filter *.html) {
  $html = [IO.File]::ReadAllText($f.FullName, [Text.Encoding]::UTF8)
  if ($html -notmatch 'assets/seo/partage-') { continue }
  $html = $html.Replace("$BASE/assets/seo/partage-29.jpg", "$BASE/$shareHome")
  $html = Fix-Share $html $shareHome $INFO['GAB06891'].alt
  [IO.File]::WriteAllText($f.FullName, $html, $utf8)
  "{0,-42} image de partage mise à jour (restes : {1})" -f $f.Name, ([regex]::Matches($html, 'assets/seo/partage-')).Count
}
