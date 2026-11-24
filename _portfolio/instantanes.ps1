<#
  Page « Instantanés » (25/11/2026), chargée par generer-pages.ps1.
  Thème : le carnet de fosse. Chaque artiste a son « pass photo », ses images sont des tirages instantanés
  scotchés qui se révèlent comme un tirage qui développe. Un flash d'appareil photo ouvre la page.
  Même moteur que les autres séries : calque de fond (sc-fond), rail, compteur, visionneuse, aucune bibliothèque.
#>
function InstFig($ia, $id, [int]$num, [string]$sizes, [string]$P) {
  $x = Img $id; $meta = $ia.photos.$id; $nn = '{0:00}' -f $num
  "<figure class=""sc-photo inst-tirage"" id=""photo-$($ia.slug)-$nn"" data-r=""$(RatioCode $x)""><a class=""photo-open"" href=""$P$(Largest $x)"" data-photo=""$num"" data-title=""$(Enc "$($meta.legende) · $($ia.nom)")"">$(ImgTag $id $meta.alt $sizes $P $false)</a><figcaption class=""sc-legende inst-legende""><span class=""serie-num"">$nn</span><span>$(Enc $meta.legende)</span></figcaption></figure>"
}

function Build-InstantanesPage($S) {
  $P = '../../'; $url = "$BASE/series/instantanes/"
  $arts = @($S.artistes)
  $nb = 0; foreach ($ia in $arts) { $nb += @($ia.ordre).Count }
  $css = New-Object Text.StringBuilder
  [void]$css.AppendLine("/* Généré par _portfolio/generer-pages.ps1 (instantanes.ps1) à partir de couleurs.json : ne pas modifier à la main. */")
  $sb = New-Object Text.StringBuilder
  $rail = New-Object System.Collections.Generic.List[string]
  [void]$sb.Append("<main id=""contenu"" class=""serie sc-page inst-page""><div class=""sc-fond"" aria-hidden=""true""></div>")

  # 1. Ouverture : titre, texte, pile de tirages, sommaire des pass
  $fit = Fit-Fond '#0d0b09' '#14100c' '#4a3f30' ''
  [void]$css.AppendLine(".serie--instantanes [data-sc=""1""]{--g:$($fit[0]);--d:$($fit[1]);--h:$($fit[2])}")
  $pile = (0..($arts.Count - 1) | ForEach-Object { $ia = $arts[$_]; $id = @($ia.ordre)[0]; $x = Img $id; "<span class=""inst-pile-tirage""><img src=""$P$($x.base)-640.webp"" width=""$($x.w)"" height=""$($x.h)"" alt="""" decoding=""async""></span>" }) -join ''
  $som = (0..($arts.Count - 1) | ForEach-Object { $ia = $arts[$_]; $c = @($ia.ordre).Count; "<li><a href=""#$($ia.slug)""><span class=""inst-som-num"">N° $('{0:00}' -f ($_ + 1))</span><span class=""inst-som-nom"">$(Enc $ia.nom)</span><span class=""inst-som-n"">$c image$(if ($c -gt 1) { 's' })</span></a></li>" }) -join ''
  [void]$sb.Append("<section class=""sc sc--ouverture sc--inst-ouverture"" id=""sc-1"" data-sc=""1"" data-cote=""droite"" aria-label=""Ouverture de la série"">")
  [void]$sb.Append("<nav class=""serie-fil"" aria-label=""Fil d’Ariane""><a href=""${P}"">Accueil</a> / <a href=""${P}series/"">Séries</a> / <span aria-current=""page"">Instantanés</span></nav>")
  [void]$sb.Append("<div class=""inst-ouverture-texte""><p class=""sc-kicker"">$($arts.Count) artistes · $nb photographies</p><h1 class=""sc-nom inst-nom"">Instantanés</h1><p class=""sc-titre"">$(Enc $S.titre_serie)</p><p class=""inst-lede"">$(Enc $S.presentation)</p></div>")
  [void]$sb.Append("<div class=""inst-pile"" aria-hidden=""true"">$pile</div>")
  [void]$sb.Append("<nav class=""inst-sommaire"" aria-label=""Les artistes""><ol>$som</ol></nav>")
  [void]$sb.Append("<div class=""inst-flash"" aria-hidden=""true""></div></section>")

  # 2. Un pass + des tirages par artiste
  $k = 1; $g = 0; $nodes = New-Object System.Collections.ArrayList
  foreach ($ia in $arts) {
    $k++
    $ids = @($ia.ordre); $n = $ids.Count
    $cG = Col $ids[0] 'gauche'; $cD = Col $ids[-1] 'droite'; $cH = Halo $ids[0]
    # Bande du pass : la couleur dominante des images, éclaircie si elle disparaîtrait sur le fond sombre
    $acc = Halo $ids[0]; $n2 = 0; while ((Lum $acc) -lt 0.12 -and $n2 -lt 40) { $acc = Mix '#ffffff' 0.1 $acc; $n2++ }
    $f = Fit-Fond $cG $cD $cH ''
    [void]$css.AppendLine(".serie--instantanes [data-sc=""$k""]{--g:$($f[0]);--d:$($f[1]);--h:$($f[2]);--inst-acc:$acc}")
    $sizes = if ($n -eq 1) { '(max-width: 700px) 86vw, 46vw' } else { '(max-width: 700px) 86vw, 30vw' }
    $figs = foreach ($id in $ids) {
      $g++
      $rail.Add("<li><a href=""#photo-$($ia.slug)-$('{0:00}' -f $g)""><span>$('{0:00}' -f $g) · $(Enc $ia.nom), $(Enc $ia.photos.$id.legende)</span></a></li>")
      $x = Img $id
      [void]$nodes.Add((ImageNode $id $url "$($ia.slug)-$('{0:00}' -f $x.n)" "$($ia.nom) · $($ia.photos.$id.legende)" $ia.photos.$id.legende $ia.photos.$id.alt $null))
      InstFig $ia $id $g $sizes $P
    }
    $l = Links-List $ia.liens
    $lBlock = if ($l) { "<div class=""inst-pass-liens""><p class=""inst-pass-label"">Écouter, suivre</p>$l</div>" } else { '' }
    $num = '{0:00}' -f ($k - 1)
    [void]$sb.Append("<section class=""sc inst-artiste"" id=""$($ia.slug)"" data-sc=""$k"" data-n=""$n"" aria-labelledby=""inst-titre-$($ia.slug)"">")
    [void]$sb.Append("<p class=""sc-mot inst-mot"" data-cote=""$(if ($k % 2) { 'gauche' } else { 'droite' })"" aria-hidden=""true"">N°$num</p>")
    [void]$sb.Append("<header class=""inst-pass""><span class=""inst-pass-fente"" aria-hidden=""true""></span><p class=""inst-pass-label"">Pass photo · Instantané n° $num</p><h2 id=""inst-titre-$($ia.slug)"">$(Enc $ia.nom)</h2><p class=""inst-pass-meta"">$n image$(if ($n -gt 1) { 's' })</p><p class=""inst-pass-texte"">$(Enc $ia.presentation)</p>$lBlock</header>")
    [void]$sb.Append("<div class=""inst-tirages"" data-n=""$n"">$($figs -join '')</div></section>")
  }

  # 3. La règle, puis le verso
  $k++
  $last = @($arts[-1].ordre)[-1]
  $f = Fit-Fond '#0d0b09' '#0d0b09' (Halo $last) ''
  [void]$css.AppendLine(".serie--instantanes [data-sc=""$k""]{--g:$($f[0]);--d:$($f[1]);--h:$($f[2])}")
  [void]$sb.Append("<section class=""sc sc--texte inst-fin"" id=""sc-$k"" data-sc=""$k"" aria-label=""La règle des instantanés""><p class=""sc-lede"">$(Enc $S.fin)</p></section>")
  [void]$css.AppendLine(".serie--instantanes [data-sc=""verso""]{--g:$($f[0]);--d:$($f[1]);--h:$($f[2])}")
  $cred = "<dt>Artistes</dt><dd>$(($arts | ForEach-Object { Enc $_.nom }) -join ', ')</dd><dt>Série</dt><dd>$(Enc $S.titre_serie)</dd><dt>Photographies</dt><dd>Gabin Spieser · $nb images</dd>"
  $kk = [array]::IndexOf($seriesOrder, 'instantanes'); $nextSlug = $seriesOrder[($kk + 1) % $seriesOrder.Count]
  $na = $bySlug[$nextSlug]; $nx = Img (CoverId $na)
  [void]$sb.Append("<section class=""serie-verso sc sc--verso"" data-sc=""verso"" aria-labelledby=""verso-titre""><div class=""serie-verso-grille""><div><h2 id=""verso-titre"">Crédits</h2><dl class=""serie-credits"">$cred</dl><p class=""serie-liens-vide"">Publier une image ? Précisez la photographie et le support envisagés. Les droits d’utilisation et le crédit du photographe se définissent ensemble avant publication. <a href=""${P}contact.html"">Parlons de votre projet</a>.</p></div></div>")
  [void]$sb.Append("<nav class=""serie-suite"" aria-label=""Autres séries""><a class=""serie-retour"" href=""${P}series/""><span><span class=""serie-kicker"">← Retour</span><strong>Toutes les séries</strong></span></a><a href=""${P}series/$nextSlug/""><img src=""$P$($nx.base)-640.webp"" width=""96"" height=""120"" alt="""" loading=""lazy"" decoding=""async""><span><span class=""serie-kicker"">Série suivante →</span><strong>$(Enc $na.nom)</strong></span></a></nav></section>")
  [void]$sb.Append("<nav class=""sc-rail"" aria-label=""Photographies de la série""><ol>$($rail -join '')</ol></nav>")
  [void]$sb.Append("<p class=""serie-compteur"" aria-hidden=""true"">01 / $('{0:00}' -f $nb)</p></main>")
  [void]$css.Append(".sc-nom{--nl:11}`n")
  $cssDir = Join-Path $Site 'assets\css\series'; New-Item -ItemType Directory -Force $cssDir | Out-Null
  [IO.File]::WriteAllText((Join-Path $cssDir 'instantanes-couleurs.css'), $css.ToString(), (New-Object Text.UTF8Encoding($false)))

  # Données structurées (inchangées dans leur principe : une page collection et une image par photo)
  $graph = @([ordered]@{ '@type' = 'CollectionPage'; '@id' = "$url#page"; url = $url; name = $S.seo.title; description = $S.seo.description; inLanguage = 'fr'; isPartOf = @{ '@id' = "$BASE/#site" }; author = @{ '@id' = $PERSON } },
    [ordered]@{ '@type' = 'BreadcrumbList'; itemListElement = @([ordered]@{ '@type' = 'ListItem'; position = 1; name = 'Accueil'; item = "$BASE/" }, [ordered]@{ '@type' = 'ListItem'; position = 2; name = 'Séries'; item = "$BASE/series/" }, [ordered]@{ '@type' = 'ListItem'; position = 3; name = 'Instantanés'; item = $url }) }) + @(Common-Graph) + @($nodes)
  $share = Make-Share 'GAB09552-2' 'serie-instantanes-1200x630.jpg'
  $seo = Seo $url $S.seo.title $S.seo.description $share $S.artistes[1].photos.'GAB09552-2'.alt $graph
  $cssLinks = "<link rel=""stylesheet"" href=""${P}assets/css/series.css?v=$(ShortHash 'assets\css\series.css')""><link rel=""stylesheet"" href=""${P}assets/css/scenes.css?v=$(ShortHash 'assets\css\scenes.css')""><link rel=""stylesheet"" href=""${P}assets/css/series/instantanes.css?v=$(ShortHash 'assets\css\series\instantanes.css')""><link rel=""stylesheet"" href=""${P}assets/css/series/instantanes-couleurs.css?v=$(ShortHash 'assets\css\series\instantanes-couleurs.css')"">"
  $html = Page $P $S.seo.title $S.seo.description 'live-site page-serie page-scenes serie--instantanes' $seo $sb.ToString() $cssLinks (& $JS_SERIE $P)
  if (-not $html.StartsWith('<!doctype html>') -or $html -match '\{\{[A-Z_]+\}\}') { throw 'Page instantanes mal assemblée' }
  $dir = Join-Path $Site 'series\instantanes'; New-Item -ItemType Directory -Force $dir | Out-Null
  [IO.File]::WriteAllText((Join-Path $dir 'index.html'), $html, $utf8)
  $written.Add("series/instantanes/index.html ($nb photos, carnet de fosse)")
}
