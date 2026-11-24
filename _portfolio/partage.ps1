# Image de partage 1200 x 630 pour les réseaux sociaux, tirée de l'original (jamais modifié).
# Recadrage centré, un peu au-dessus du milieu pour garder les visages. Utilisé par maj-pages.ps1.
Add-Type -AssemblyName System.Drawing
function Make-Share($D, $I, [string]$id, [string]$name, [string]$Site) {
  $x = $I.$id
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
