<#
  Page d'entrée des séries (25/11/2026) : « le kiosque ». Chargée par generer-pages.ps1.
  Un sommaire de magazine, puis une couverture par artiste, chacune dans l'identité graphique de sa série
  (typographie, couleurs, motif). Au survol (ou au centre de l'écran sur téléphone), une seconde image apparaît ;
  le fond de page prend les couleurs de la couverture. Rangées de 12 colonnes : portrait = 4, paysage = 8,
  bandeaux pleine largeur pour Ina Forsman et le hors-série Instantanés.
#>
function KqSecond($a, $cover) {
  $ids = @(PhotoIds $a)
  $fin = @($a.scenes | Where-Object { $_.type -eq 'final' })[0].photo
  if ($fin -and $fin -ne $cover) { return $fin }
  @($ids | Where-Object { $_ -ne $cover })[-1]
}
function KqExtras([string]$theme) {
  switch ($theme) {
    'mika' { '<span class="kq-deco kq-deco--rayures" aria-hidden="true"><i></i><i></i><i></i></span>' }
    'anna' { '<span class="kq-tampon">Reportage</span>' }
    'electro' { '<span class="kq-deco kq-deco--portee" aria-hidden="true"></span>' }
    'mae' { '<span class="kq-deco kq-deco--guirlande" aria-hidden="true"></span>' }
    'pokora' { '<span class="kq-deco kq-deco--leds" aria-hidden="true"></span>' }
    'stomy' { '<span class="kq-deco kq-deco--cinema" aria-hidden="true"></span>' }
    default { '' }
  }
}

function Build-Kiosque {
  $P = '../'; $url = "$BASE/series/"
  $old = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'sections-portfolio.html'), [Text.Encoding]::UTF8)
  $totalPhotos = @($I.PSObject.Properties).Count
  $S = $D.instantanes
  $css = New-Object Text.StringBuilder
  [void]$css.AppendLine("/* Généré par _portfolio/generer-pages.ps1 (kiosque.ps1) à partir de couleurs.json : ne pas modifier à la main. */")
  $sb = New-Object Text.StringBuilder
  [void]$sb.Append("<main id=""contenu"" class=""kq-page""><div class=""kq-fond"" aria-hidden=""true""></div>")

  # Ordre des couvertures (les respirations et la fermeture sont des photos du public, hors numérotation)
  $entries = @($D.ordre_index | ForEach-Object { if ($_ -eq '@ina') { 'ina-forsman' } else { $_ } })
  $covers = @($entries | Where-Object { $_ -notlike '@*' })

  # Sommaire
  $som = New-Object System.Collections.Generic.List[string]
  $num = 0
  foreach ($e in $covers) {
    $num++
    if ($e -eq 'instantanes') { $nom = 'Instantanés'; $tit = $S.titre_serie; $c = 0; foreach ($ia in $S.artistes) { $c += @($ia.ordre).Count } }
    else { $a = $bySlug[$e]; $nom = $a.nom; $tit = $a.titre_serie; $c = Count-Photos $a }
    $som.Add("<li><a href=""./$e/""><span class=""kq-som-num"">$('{0:00}' -f $num)</span><span class=""kq-som-nom"">$(Enc $nom)</span><span class=""kq-som-titre"">$(Enc $tit)</span><span class=""kq-som-n"">$c <span class=""caption-sr-only"">photographies</span></span></a></li>")
  }
  [void]$sb.Append("<section class=""kq-entete"" aria-labelledby=""portfolio-title""><div class=""kq-entete-titre""><p class=""live-kicker"">Séries · $totalPhotos photographies</p><h1 id=""portfolio-title""><span class=""caption-sr-only"">Séries photographiques de concerts de Gabin Spieser : </span>Ça se voit.<br><em>Ça se ressent.</em></h1></div><p class=""kq-lede"">Je veux raconter votre sueur.<br>Votre beauté. Votre rage. Votre scène.<br>Le reste, je vous laisse le regarder.</p>")
  # Sommaire repliable (élément natif details/summary : clavier, lecteurs d'écran, fonctionne sans JavaScript)
  [void]$sb.Append("<details class=""kq-sommaire""><summary><span class=""kq-som-h"">Au sommaire</span><span class=""kq-som-meta"">$($covers.Count) séries</span><span class=""kq-som-icone"" aria-hidden=""true""></span></summary><nav class=""kq-sommaire-liste"" aria-label=""Sommaire des séries""><ol>$($som -join '')</ol></nav></details></section>")
  [void]$sb.Append("<section class=""kq-kiosque"" aria-labelledby=""kq-kiosque-titre""><h2 id=""kq-kiosque-titre"" class=""caption-sr-only"">Les couvertures des séries</h2>")

  # Couvertures, rangée par rangée
  $script:kqRow = New-Object System.Collections.Generic.List[string]
  $script:kqUsed = 0
  $script:kqPending = New-Object System.Collections.Generic.List[string]
  $flush = {
    if ($script:kqRow.Count) { [void]$sb.Append("<div class=""kq-rang"">$($script:kqRow -join '')</div>"); $script:kqRow.Clear(); $script:kqUsed = 0 }
    foreach ($b in $script:kqPending) { [void]$sb.Append($b) }; $script:kqPending.Clear()
  }
  # Entractes (25/11/2026) : entre les rangées, une citation reprise mot pour mot de la page « À propos »,
  # à la place des grandes photos du public. Ces photos sont regroupées à la fin, dans « L'ambiance ».
  $citations = @(
    @("Je ne veux pas faire des photos «$([char]0xA0)jolies$([char]0xA0)». Je veux faire des photos ", "qui cognent."),
    @("Un concert, ce n’est pas juste des morceaux joués dans le bon ordre. ", "C’est une claque.")
  )
  $romEntr = @('01', '02', '03', '04')
  $ambiance = New-Object System.Collections.Generic.List[string]
  $nEntr = 0
  $num = 0; $eagerLeft = 2
  foreach ($e in $entries) {
    if ($e -like '@respiration:*' -or $e -like '@fermeture:*') {
      $ambiance.Add($e.Split(':')[1])
      if ($e -like '@fermeture:*') { continue }
      $q = $citations[$nEntr % $citations.Count]
      $entr = "<aside class=""kq-entracte"" aria-label=""Entracte""><p class=""kq-entracte-kicker""><span>Entracte</span><span class=""kq-entracte-num"" aria-hidden=""true"">$($romEntr[$nEntr])</span></p><figure class=""kq-citation""><blockquote><p>$(Enc $q[0])<em>$(Enc $q[1])</em></p></blockquote><figcaption>Gabin Spieser, <a href=""${P}a-propos.html"">À propos</a></figcaption></figure></aside>"
      $nEntr++
      if ($script:kqRow.Count) { $script:kqPending.Add($entr) } else { [void]$sb.Append($entr) }
      continue
    }
    $num++; $nn = '{0:00}' -f $num
    $eager = $eagerLeft -gt 0; $eagerLeft--

    if ($e -eq 'instantanes') {
      & $flush
      $c = 0; foreach ($ia in $S.artistes) { $c += @($ia.ordre).Count }
      $pile = (@($S.artistes) | ForEach-Object { $id = @($_.ordre)[0]; $x = Img $id; "<span class=""kq-tirage""><img src=""$P$($x.base)-640.webp"" width=""$($x.w)"" height=""$($x.h)"" alt="""" loading=""lazy"" decoding=""async""></span>" }) -join ''
      $f = Fit-Fond '#0d0b09' '#14100c' '#4a3f30' ''
      [void]$css.AppendLine(".kq-couv[data-kq=""instantanes""]{--g:$($f[0]);--d:$($f[1]);--h:$($f[2])}")
      $names = (@($S.artistes) | ForEach-Object { Enc $_.nom }) -join ' · '
      [void]$sb.Append("<article class=""kq-couv kq--instantanes kq-bandeau"" data-kq=""instantanes""><a class=""kq-lien"" href=""./instantanes/"" aria-labelledby=""kq-t-instantanes kq-s-instantanes""><div class=""kq-bandeau-texte""><div class=""kq-tete""><span>Hors-série</span><span class=""kq-num"">N° $nn</span></div><h2 class=""kq-nom"" id=""kq-t-instantanes"">Instantanés</h2><p class=""kq-titre"" id=""kq-s-instantanes"">$(Enc $S.titre_serie)</p><p class=""kq-lignes"">$names · $c photographies</p><span class=""kq-cta"">Ouvrir le carnet <span aria-hidden=""true"">→</span></span></div><div class=""kq-pile"" aria-hidden=""true"">$pile</div></a></article>")
      continue
    }

    $a = $bySlug[$e]
    $cover = if ($e -eq 'ina-forsman') { $a.carte } else { (PhotoIds $a)[0] }
    $second = KqSecond $a $cover
    $x = Img $cover
    $c = Count-Photos $a
    $ctx = ContextLine $a
    $f = Fit-Fond (Col $cover 'gauche') (Col $cover 'droite') (Halo $cover) ''
    [void]$css.AppendLine(".kq-couv[data-kq=""$e""]{--g:$($f[0]);--d:$($f[1]);--h:$($f[2])}")
    $lignes = "$c photographies" + $(if ($ctx) { " · $(Enc $ctx)" } else { '' })

    if ($e -eq 'ina-forsman') {
      & $flush
      $img1 = (ImgTag $cover $a.photos.$cover.alt '(max-width: 700px) 92vw, 44vw' $P $eager 'kq-img kq-img--1')
      $img2 = (ImgTag $second '' '(max-width: 700px) 92vw, 44vw' $P $false 'kq-img kq-img--2')
      [void]$sb.Append("<article class=""kq-couv kq--ina kq-bandeau"" data-kq=""$e""><a class=""kq-lien"" href=""./$e/"" aria-labelledby=""kq-t-$e kq-s-$e""><div class=""kq-bandeau-texte""><div class=""kq-tete""><span>Gabin Spieser · Séries</span><span class=""kq-num"">N° $nn</span></div><h2 class=""kq-nom"" id=""kq-t-$e"">Ina<br>Forsman</h2><p class=""kq-titre"" id=""kq-s-$e"">$(Enc $a.titre_serie)</p><p class=""kq-accroche"">$(Enc $a.accroche)</p><p class=""kq-lignes"">$lignes</p><span class=""kq-cta"">Entrer dans la série <span aria-hidden=""true"">→</span></span></div><div class=""kq-photos"">$img1$img2</div></a></article>")
      continue
    }

    $land = IsLandscape $x
    $kind = if ($land) { 'kq-paysage' } else { 'kq-portrait' }
    # Haut ou bas de la photo clair : voile plus dense sous le titre et les lignes de couverture
    if ((Lum (Col $cover 'haut')) -gt 0.15 -or (Lum (Col $second 'haut')) -gt 0.15) { $kind += ' kq-clair-haut' }
    if ((Lum (Col $cover 'bas')) -gt 0.15 -or (Lum (Col $second 'bas')) -gt 0.15) { $kind += ' kq-clair-bas' }
    $need = if ($land) { 8 } else { 4 }
    $sizes = if ($land) { '(max-width: 700px) 92vw, 66vw' } else { '(max-width: 700px) 92vw, 34vw' }
    $img1 = (ImgTag $cover $a.photos.$cover.alt $sizes $P $eager 'kq-img kq-img--1')
    $img2 = (ImgTag $second '' $sizes $P $false 'kq-img kq-img--2')
    $art = "<article class=""kq-couv kq--$($a.theme) $kind"" data-kq=""$e""><a class=""kq-lien"" href=""./$e/"" aria-labelledby=""kq-t-$e kq-s-$e""><div class=""kq-photos"">$img1$img2</div>$(KqExtras $a.theme)<div class=""kq-une""><div class=""kq-tete""><span>Gabin Spieser · Séries</span><span class=""kq-num"">N° $nn</span></div><div class=""kq-centre""><h2 class=""kq-nom"" id=""kq-t-$e"">$(Enc $a.nom)</h2><p class=""kq-titre"" id=""kq-s-$e"">$(Enc $a.titre_serie)</p></div><div class=""kq-pied""><p class=""kq-accroche"">$(Enc $a.accroche)</p><p class=""kq-lignes"">$lignes</p><span class=""kq-code"" aria-hidden=""true""></span></div></div></a></article>"
    if ($script:kqUsed + $need -gt 12) { & $flush }
    $script:kqRow.Add($art); $script:kqUsed += $need
    if ($script:kqUsed -ge 12) { & $flush }
  }
  & $flush
  # L'ambiance : les photos du public, en cadres égaux et alignés
  if ($ambiance.Count) {
    $figs = ($ambiance | ForEach-Object { "<figure class=""kq-ambiance-photo"">$(ImgTag $_ $D.public.photos.$_.alt '(max-width: 700px) 92vw, 32vw' $P)</figure>" }) -join ''
    [void]$sb.Append("<section class=""kq-ambiance"" aria-labelledby=""kq-ambiance-titre""><div class=""kq-ambiance-tete""><p class=""kq-entracte-kicker""><span>L’ambiance</span></p><h2 id=""kq-ambiance-titre"">Et autour, <em>tout explose.</em></h2></div><div class=""kq-ambiance-grille"">$figs</div></section>")
  }
  [void]$sb.Append('</section>')
  [void]$sb.Append($old.Replace('href="./', "href=""$P"))
  [void]$sb.Append('</main>')
  [IO.File]::WriteAllText((Join-Path $Site 'assets\css\kiosque-couleurs.css'), $css.ToString(), (New-Object Text.UTF8Encoding($false)))

  $title = 'Séries : photographies de concerts | Gabin Spieser'
  $desc = "Les séries photographiques de Gabin Spieser : Ina Forsman, Julien Doré, Mika, Anna Winkin, Electro Symphony et d’autres artistes, en concert et en coulisses."
  $graph = @([ordered]@{ '@type' = 'CollectionPage'; '@id' = "$url#page"; url = $url; name = $title; description = $desc; inLanguage = 'fr'; isPartOf = @{ '@id' = "$BASE/#site" }; publisher = @{ '@id' = $BUSINESS }
      hasPart = @($seriesOrder | ForEach-Object { @{ '@id' = "$BASE/series/$_/#page" } }) },
    [ordered]@{ '@type' = 'BreadcrumbList'; itemListElement = @([ordered]@{ '@type' = 'ListItem'; position = 1; name = 'Accueil'; item = "$BASE/" }, [ordered]@{ '@type' = 'ListItem'; position = 2; name = 'Séries'; item = $url }) }) + @(Common-Graph)
  $share = Make-Share 'GAB06757' 'series-1200x630.jpg'
  $seo = Seo $url $title $desc $share $bySlug['ina-forsman'].photos.GAB06757.alt $graph
  $cssLinks = "<link rel=""stylesheet"" href=""${P}assets/css/series.css?v=$(ShortHash 'assets\css\series.css')"">" + "<link rel=""stylesheet"" href=""${P}assets/css/kiosque.css?v=$(ShortHash 'assets\css\kiosque.css')""><link rel=""stylesheet"" href=""${P}assets/css/kiosque-couleurs.css?v=$(ShortHash 'assets\css\kiosque-couleurs.css')"">"
  $js = "<script src=""${P}kiosque.js?v=$(ShortHash 'kiosque.js')"" defer></script>"
  $html = Page $P $title $desc 'live-site page-portfolio page-series-index page-kiosque' $seo $sb.ToString() $cssLinks $js
  if (-not $html.StartsWith('<!doctype html>') -or $html -match '\{\{[A-Z_]+\}\}') { throw 'Page des séries mal assemblée' }
  New-Item -ItemType Directory -Force (Join-Path $Site 'series') | Out-Null
  [IO.File]::WriteAllText((Join-Path $Site 'series\index.html'), $html, $utf8)
  $written.Add('series/index.html (le kiosque : sommaire + couvertures)')
}
