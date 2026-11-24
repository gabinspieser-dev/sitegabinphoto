<#
  Portfolio — étape 1 : images.
  Lit donnees.json, crée les tailles WebP de chaque photo à partir des originaux (jamais modifiés),
  calcule la couleur d'accent de chaque photo et écrit le manifeste images.json.
  Relancer après avoir ajouté des photos : les fichiers déjà à jour ne sont pas refaits.

  Lancer :
    powershell -NoProfile -ExecutionPolicy Bypass -File _portfolio\generer-images.ps1
#>
param(
  [string]$Site = (Split-Path $PSScriptRoot -Parent),
  [string]$Cwebp = 'C:\Users\gabin.spieser\Documents\Maintenance\outils\libwebp\libwebp-1.6.0-windows-x64\bin\cwebp.exe'
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$data = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'donnees.json'), [Text.Encoding]::UTF8) | ConvertFrom-Json
if (-not (Test-Path $Cwebp)) { throw "cwebp introuvable : $Cwebp" }

# --- Liste des photos dans l'ordre de lecture ---
$jobs = New-Object System.Collections.Generic.List[object]
function Add-Photo($slug, $dossier, $ctx, $id, $n) {
  $jobs.Add([pscustomobject]@{ slug = $slug; dossier = $dossier; ctx = $ctx; id = $id; n = $n })
}
foreach ($a in $data.artistes) {
  $n = 0
  if ($a.scenes) {
    # Séries construites en scènes : l'ordre de lecture suit les scènes (une scène « texte » n'affiche pas de photo)
    foreach ($sc in $a.scenes) { foreach ($id in @(@($sc.photo) + @($sc.photos) | Where-Object { $_ })) { $n++; Add-Photo $a.slug $a.dossier $a.contexte_fichier $id $n } }
  } else {
    foreach ($c in $a.chapitres) { foreach ($p in $c.plans) { foreach ($id in $p.photos) { $n++; Add-Photo $a.slug $a.dossier $a.contexte_fichier $id $n } } }
  }
}
foreach ($a in $data.instantanes.artistes) { $n = 0; foreach ($id in $a.ordre) { $n++; Add-Photo $a.slug $a.dossier $a.contexte_fichier $id $n } }
$n = 0; foreach ($prop in $data.public.photos.PSObject.Properties) { $n++; Add-Photo $data.public.slug $data.public.dossier $data.public.contexte_fichier $prop.Name $n }

# --- Couleur d'accent (même règle que la refonte : contraste d'au moins 6:1 sur #08090A ; "nb" = noir et blanc) ---
function Get-Lum([double]$r, [double]$g, [double]$b) {
  $f = { param($c) $c = $c / 255; if ($c -le 0.03928) { $c / 12.92 } else { [math]::Pow(($c + 0.055) / 1.055, 2.4) } }
  0.2126 * (& $f $r) + 0.7152 * (& $f $g) + 0.0722 * (& $f $b)
}
function Get-Tone([string]$path) {
  $img = [System.Drawing.Image]::FromFile($path)
  $bmp = New-Object System.Drawing.Bitmap 64, ([int](64 * $img.Height / $img.Width))
  $gr = [System.Drawing.Graphics]::FromImage($bmp); $gr.DrawImage($img, 0, 0, $bmp.Width, $bmp.Height); $gr.Dispose(); $img.Dispose()
  $sr = 0.0; $sg = 0.0; $sb = 0.0; $sw = 0.0; $count = 0; $total = $bmp.Width * $bmp.Height
  for ($y = 0; $y -lt $bmp.Height; $y++) { for ($x = 0; $x -lt $bmp.Width; $x++) {
    $c = $bmp.GetPixel($x, $y); $s = $c.GetSaturation(); $v = [math]::Max($c.R, [math]::Max($c.G, $c.B)) / 255
    if ($s -gt 0.35 -and $v -gt 0.25) { $wgt = $s * $v; $sr += $c.R * $wgt; $sg += $c.G * $wgt; $sb += $c.B * $wgt; $sw += $wgt; $count++ }
  } }
  $bmp.Dispose()
  if ($count / $total -lt 0.03) { return 'nb' }
  $r = $sr / $sw; $g = $sg / $sw; $b = $sb / $sw
  $bg = Get-Lum 8 9 10
  for ($i = 0; $i -lt 40; $i++) {
    $ratio = ((Get-Lum $r $g $b) + 0.05) / ($bg + 0.05)
    if ($ratio -ge 6) { break }
    $r = $r + (255 - $r) * 0.08; $g = $g + (255 - $g) * 0.08; $b = $b + (255 - $b) * 0.08
  }
  '#{0:x2}{1:x2}{2:x2}' -f [int]$r, [int]$g, [int]$b
}

# --- Encodage ---
$manifestPath = Join-Path $PSScriptRoot 'images.json'
$old = @{}
if (Test-Path $manifestPath) { ([IO.File]::ReadAllText($manifestPath) | ConvertFrom-Json).PSObject.Properties | ForEach-Object { $old[$_.Name] = $_.Value } }
$manifest = [ordered]@{}
$done = 0; $made = 0
foreach ($j in $jobs) {
  $src = Get-ChildItem -LiteralPath (Join-Path $data.source $j.dossier) -File | Where-Object { $_.BaseName -eq $j.id } | Select-Object -First 1
  if (-not $src) { throw "Original introuvable : $($j.dossier)\$($j.id)" }
  $img = [System.Drawing.Image]::FromFile($src.FullName); $W = $img.Width; $H = $img.Height; $img.Dispose()
  $base = '{0}-{1}-{2:00}' -f $j.slug, $j.ctx, $j.n
  $dir = Join-Path $Site "assets\portfolio\$($j.slug)"
  New-Item -ItemType Directory -Force $dir | Out-Null
  $cands = @(640, 1024, 1600); if ($W -gt $H * 1.05) { $cands += 2400 }
  $widths = @($cands | Where-Object { $_ -le $W })
  if ($W -lt 1600 -and ($widths -notcontains $W)) { $widths += $W }
  # Si la photo change de place dans la série, son nom change : on refait ses fichiers (un ancien fichier du même nom peut contenir une autre photo)
  $moved = (-not $old.ContainsKey($j.id)) -or ($old[$j.id].base -ne "assets/portfolio/$($j.slug)/$base")
  foreach ($wd in $widths) {
    $out = Join-Path $dir "$base-$wd.webp"
    if (-not $moved -and (Test-Path $out) -and (Get-Item $out).LastWriteTime -gt $src.LastWriteTime) { continue }
    $q = if ($wd -ge 1600) { 78 } else { 80 }
    & $Cwebp -quiet -q $q -m 5 -mt -metadata none -resize $wd 0 $src.FullName -o $out
    if ($LASTEXITCODE -ne 0) { throw "cwebp a échoué : $out" }
    $made++
  }
  $tone = if ($old.ContainsKey($j.id) -and $old[$j.id].source -eq $src.Name -and $old[$j.id].tone) { $old[$j.id].tone } else { Get-Tone $src.FullName }
  $manifest[$j.id] = [ordered]@{ slug = $j.slug; n = $j.n; base = "assets/portfolio/$($j.slug)/$base"; widths = @($widths | Sort-Object); w = $W; h = $H; tone = $tone; source = $src.Name; dossier = $j.dossier }
  $done++
  if ($done % 10 -eq 0) { Write-Host "$done / $($jobs.Count) photos" }
}
[IO.File]::WriteAllText($manifestPath, ($manifest | ConvertTo-Json -Depth 5), (New-Object Text.UTF8Encoding($false)))
"Terminé : $done photos, $made fichiers WebP créés. Manifeste : $manifestPath"
$sz = (Get-ChildItem (Join-Path $Site 'assets\portfolio') -Recurse -File | Measure-Object Length -Sum)
"Dossier assets/portfolio : {0} fichiers, {1:N1} Mo" -f $sz.Count, ($sz.Sum / 1MB)
