<#
  Portfolio — étape 4 : plan du site (sitemap.xml) avec les images de chaque page.
  Garde les pages existantes et leur date, ajoute les séries, et liste pour chaque page
  la plus grande version de chaque photo du portfolio qu'elle affiche.
  Lancer après generer-pages.ps1 : powershell -NoProfile -ExecutionPolicy Bypass -File _portfolio\generer-sitemap.ps1
#>
param([string]$Site = (Split-Path $PSScriptRoot -Parent), [string]$Today = (Get-Date -Format 'yyyy-MM-dd'))
$ErrorActionPreference = 'Stop'
$D = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'donnees.json'), [Text.Encoding]::UTF8) | ConvertFrom-Json
$I = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'images.json'), [Text.Encoding]::UTF8) | ConvertFrom-Json
$BASE = $D.site
$largest = @{}
foreach ($p in $I.PSObject.Properties) { $ws = @($p.Value.widths | ForEach-Object { [int]$_ }) | Sort-Object; $largest[$p.Value.base] = "$($p.Value.base)-$($ws[-1]).webp" }
$old = @{}
$sm = Join-Path $Site 'sitemap.xml'
if (Test-Path $sm) { ([xml][IO.File]::ReadAllText($sm)).urlset.url | ForEach-Object { $old[$_.loc] = $_.lastmod } }
# Pages : celles du plan actuel, puis les séries
$pages = New-Object System.Collections.Generic.List[object]
foreach ($loc in $old.Keys) {
  $rel = $loc.Substring($BASE.Length + 1); $file = if ($rel -eq '') { 'index.html' } elseif ($rel.EndsWith('/')) { $rel + 'index.html' } else { $rel }
  $pages.Add([pscustomobject]@{ loc = $loc; file = $file })
}
foreach ($dir in Get-ChildItem (Join-Path $Site 'series') -Directory) {
  $loc = "$BASE/series/$($dir.Name)/"
  if (-not $old.ContainsKey($loc)) { $pages.Add([pscustomobject]@{ loc = $loc; file = "series/$($dir.Name)/index.html" }) }
}
if (-not ($pages | Where-Object { $_.loc -eq "$BASE/series/" })) { $pages.Add([pscustomobject]@{ loc = "$BASE/series/"; file = 'series/index.html' }) }
# Date de modification : une page reçoit la date du jour si elle diffère de la version publiée (dossier GitHub), sinon elle garde sa date
$publie = 'C:\Users\gabin.spieser\Documents\GitHub\sitegabinphoto'
function Modifiee([string]$file) {
  $ici = Join-Path $Site ($file -replace '/', '\'); $la = Join-Path $publie ($file -replace '/', '\')
  if (-not (Test-Path $la)) { return $true }
  (Get-FileHash $ici).Hash -ne (Get-FileHash $la).Hash
}
$sb = New-Object Text.StringBuilder
[void]$sb.AppendLine("<?xml version='1.0' encoding='utf-8'?>")
[void]$sb.AppendLine('<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9" xmlns:image="http://www.google.com/schemas/sitemap-image/1.1">')
$nImg = 0
foreach ($p in ($pages | Sort-Object { if ($_.loc -eq "$BASE/") { '' } else { $_.loc } })) {
  $path = Join-Path $Site ($p.file -replace '/', '\')
  if (-not (Test-Path $path)) { Write-Warning "Page absente, retirée du plan : $($p.loc)"; continue }
  $html = [IO.File]::ReadAllText($path, [Text.Encoding]::UTF8)
  $main = [regex]::Replace([regex]::Match($html, '(?s)<main.*?</main>').Value, '(?s)<nav class="serie-suite".*?</nav>', '')   # la vignette « série suivante » appartient à une autre série
  $bases = [regex]::Matches($main, 'assets/portfolio/[a-z0-9-]+/[a-z0-9-]+?-\d{2}(?=-\d+\.webp)') | ForEach-Object Value | Select-Object -Unique
  $isNew = -not $old.ContainsKey($p.loc)
  $last = if ($isNew -or (Modifiee $p.file)) { $Today } else { $old[$p.loc] }
  [void]$sb.AppendLine('  <url>')
  [void]$sb.AppendLine("    <loc>$($p.loc)</loc>")
  [void]$sb.AppendLine("    <lastmod>$last</lastmod>")
  foreach ($b in $bases) { if ($largest.ContainsKey($b)) { [void]$sb.AppendLine("    <image:image><image:loc>$BASE/$($largest[$b])</image:loc></image:image>"); $nImg++ } }
  [void]$sb.AppendLine('  </url>')
}
[void]$sb.AppendLine('</urlset>')
[IO.File]::WriteAllText($sm, $sb.ToString(), (New-Object Text.UTF8Encoding($false)))
[void][xml]$sb.ToString()
"sitemap.xml : $($pages.Count) pages, $nImg images (XML valide)"
