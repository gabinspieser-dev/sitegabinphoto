<#
  Versions des fichiers CSS et JS (?v=) : les 12 premiers caractères de l'empreinte SHA-256 de chaque fichier.
  À lancer après chaque modification d'un CSS ou d'un JS, pour que les navigateurs prennent la nouvelle version.
#>
param([string]$Site = (Split-Path $PSScriptRoot -Parent))
$u = New-Object Text.UTF8Encoding($false); $n = 0; $files = 0
foreach ($f in Get-ChildItem $Site -Recurse -Filter *.html | Where-Object { $_.FullName -notmatch '\\_portfolio\\' }) {
  $html = [IO.File]::ReadAllText($f.FullName, [Text.Encoding]::UTF8)
  $new = [regex]::Replace($html, '((?:href|src)=")((?:\./|(?:\.\./)+)?)([^"?:]+\.(?:css|js))\?v=([^"]*)(")', {
    param($m)
    $target = [IO.Path]::GetFullPath((Join-Path $f.DirectoryName ($m.Groups[2].Value + $m.Groups[3].Value)))
    if (-not (Test-Path $target)) { Write-Warning "$($f.Name) : fichier introuvable $($m.Groups[3].Value)"; return $m.Value }
    $h = (Get-FileHash $target -Algorithm SHA256).Hash.Substring(0, 12).ToLower()
    if ($h -ne $m.Groups[4].Value) { $script:n++ }
    $m.Groups[1].Value + $m.Groups[2].Value + $m.Groups[3].Value + '?v=' + $h + $m.Groups[5].Value
  })
  if ($new -ne $html) { [IO.File]::WriteAllText($f.FullName, $new, $u); $files++ }
}
"Versions mises à jour : $n références dans $files pages"