<#
  Portfolio — analyse des couleurs de chaque photo (lecture seule sur les originaux).
  Pour chaque photo : couleur des bords (gauche, droite, haut, bas), couleur moyenne, couleur dominante saturée,
  luminosité. Sert à construire la direction chromatique des séries : le fond de page reprend la couleur
  du bord de la photo, pour que l'image se prolonge dans la page, et change d'une scène à l'autre.
  Écrit couleurs.json. Lancer : powershell -NoProfile -ExecutionPolicy Bypass -File _portfolio\analyser-couleurs.ps1 [-Artiste silda]
#>
param([string]$Site = (Split-Path $PSScriptRoot -Parent), [string]$Artiste = '')
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$I = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'images.json'), [Text.Encoding]::UTF8) | ConvertFrom-Json
$D = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'donnees.json'), [Text.Encoding]::UTF8) | ConvertFrom-Json
$outPath = Join-Path $PSScriptRoot 'couleurs.json'
$all = [ordered]@{}
if (Test-Path $outPath) { ([IO.File]::ReadAllText($outPath) | ConvertFrom-Json).PSObject.Properties | ForEach-Object { $all[$_.Name] = $_.Value } }
function Hex($r, $g, $b) { '#{0:x2}{1:x2}{2:x2}' -f [int][math]::Min(255, [math]::Max(0, $r)), [int][math]::Min(255, [math]::Max(0, $g)), [int][math]::Min(255, [math]::Max(0, $b)) }
function Avg($bmp, $x0, $y0, $x1, $y1) {
  $r = 0.0; $g = 0.0; $b = 0.0; $n = 0
  for ($y = $y0; $y -lt $y1; $y++) { for ($x = $x0; $x -lt $x1; $x++) { $c = $bmp.GetPixel($x, $y); $r += $c.R; $g += $c.G; $b += $c.B; $n++ } }
  Hex ($r / $n) ($g / $n) ($b / $n)
}
foreach ($p in $I.PSObject.Properties) {
  $x = $p.Value
  if ($Artiste -and $x.slug -ne $Artiste) { continue }
  $src = Join-Path (Join-Path $D.source $x.dossier) $x.source
  $img = [System.Drawing.Image]::FromFile($src)
  $W = 120; $H = [int](120 * $img.Height / $img.Width)
  $bmp = New-Object System.Drawing.Bitmap $W, $H
  $g = [System.Drawing.Graphics]::FromImage($bmp); $g.InterpolationMode = 'HighQualityBilinear'; $g.DrawImage($img, 0, 0, $W, $H); $g.Dispose(); $img.Dispose()
  $e = [int][math]::Max(2, $W * 0.04)
  $left = Avg $bmp 0 0 $e $H; $right = Avg $bmp ($W - $e) 0 $W $H; $top = Avg $bmp 0 0 $W $e; $bottom = Avg $bmp 0 ($H - $e) $W $H
  $mean = Avg $bmp 0 0 $W $H
  # Dominante saturée : moyenne pondérée des pixels vifs, par tranche de teinte la plus chargée
  $buckets = @{}; $lum = 0.0
  for ($yy = 0; $yy -lt $H; $yy++) { for ($xx = 0; $xx -lt $W; $xx++) {
    $c = $bmp.GetPixel($xx, $yy); $lum += (0.2126 * $c.R + 0.7152 * $c.G + 0.0722 * $c.B) / 255
    $s = $c.GetSaturation(); $v = [math]::Max($c.R, [math]::Max($c.G, $c.B)) / 255
    if ($s -gt 0.3 -and $v -gt 0.2) { $k = [int]($c.GetHue() / 20); if (-not $buckets[$k]) { $buckets[$k] = @(0.0, 0.0, 0.0, 0.0) }; $wgt = $s * $v; $bk = $buckets[$k]; $bk[0] += $c.R * $wgt; $bk[1] += $c.G * $wgt; $bk[2] += $c.B * $wgt; $bk[3] += $wgt }
  } }
  $bmp.Dispose()
  $dom = $null; $part = 0
  if ($buckets.Count) { $best = $buckets.GetEnumerator() | Sort-Object { $_.Value[3] } -Descending | Select-Object -First 1; $v = $best.Value; $dom = Hex ($v[0] / $v[3]) ($v[1] / $v[3]) ($v[2] / $v[3]); $part = [math]::Round($v[3] / ($W * $H), 3) }
  $all[$p.Name] = [ordered]@{ slug = $x.slug; gauche = $left; droite = $right; haut = $top; bas = $bottom; moyenne = $mean; dominante = $dom; part_vive = $part; luminosite = [math]::Round($lum / ($W * $H), 3) }
  "{0,-12} {1,-14} bords G {2} D {3} H {4} B {5} | moy {6} | dominante {7} ({8}) | lum {9}" -f $p.Name, $x.slug, $left, $right, $top, $bottom, $mean, $dom, $part, $all[$p.Name].luminosite
}
[IO.File]::WriteAllText($outPath, ($all | ConvertTo-Json -Depth 4), (New-Object Text.UTF8Encoding($false)))
