$ErrorActionPreference = "Continue"
$ProjectRoot = Split-Path -Parent $PSScriptRoot
$PathFile = Join-Path $PSScriptRoot "_converter\exporter_path.txt"
if (-not (Test-Path $PathFile)) {
  Write-Host "Conversor ainda nao preparado. Execute PREPARAR_CONVERSOR.bat primeiro." -ForegroundColor Red
  Read-Host "ENTER"
  exit 1
}
$Exporter = (Get-Content $PathFile -Raw).Trim()
if (-not (Test-Path $Exporter)) {
  Write-Host "AssetExporter.exe nao existe no caminho salvo." -ForegroundColor Red
  Read-Host "ENTER"
  exit 1
}

Write-Host "=== IMPORTADOR PRISTON -> GODOT ===" -ForegroundColor Cyan
Write-Host "Informe a pasta raiz do cliente do Priston."
Write-Host "Exemplo: C:\PristonTale"
$Root = (Read-Host "Pasta").Trim('"')
if (-not (Test-Path $Root)) {
  Write-Host "Pasta invalida." -ForegroundColor Red
  Read-Host "ENTER"
  exit 1
}

$OutRoot = Join-Path $ProjectRoot "assets\imported"
$OutPlayer = Join-Path $OutRoot "player"
$OutMonster = Join-Path $OutRoot "monsters"
$OutWeapon = Join-Path $OutRoot "weapons"
New-Item -ItemType Directory -Force -Path $OutPlayer,$OutMonster,$OutWeapon | Out-Null

$log = Join-Path $PSScriptRoot "import_log.txt"
"Import iniciado: $(Get-Date)" | Set-Content $log

function SafeName([string]$p) {
  $n = [IO.Path]::GetFileNameWithoutExtension($p)
  return ($n -replace '[^a-zA-Z0-9_-]','_')
}
function Convert-One([string]$input,[string]$folder,[string]$prefix) {
  if (-not (Test-Path $input)) { return $false }
  $name = "$(SafeName $input)"
  $out = Join-Path $folder ($prefix + $name + ".glb")
  Write-Host "Convertendo: $input" -ForegroundColor Gray
  & $Exporter --input $input --output $out 2>&1 | Tee-Object -FilePath $log -Append
  if (Test-Path $out) {
    Write-Host "  OK -> $([IO.Path]::GetFileName($out))" -ForegroundColor Green
    return $true
  }
  Write-Host "  Falhou." -ForegroundColor DarkYellow
  return $false
}

$tmDirs = Get-ChildItem $Root -Recurse -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -ieq "tmABCD" } | Select-Object -First 2
$playerCandidates = @()
foreach($d in $tmDirs) {
  $all = Get-ChildItem $d.FullName -Recurse -File -Filter *.inx -ErrorAction SilentlyContinue
  $playerCandidates += $all | Where-Object { $_.Length -eq 95268 } | Select-Object -First 16
  if ($playerCandidates.Count -lt 4) { $playerCandidates += $all | Select-Object -First 12 }
}
$playerCandidates = $playerCandidates | Sort-Object FullName -Unique | Select-Object -First 16
$pok=0
foreach($f in $playerCandidates) { if(Convert-One $f.FullName $OutPlayer "player_"){ $pok++ } }

$monsterKeys = @("icegoblin","ice_goblin","d_magi","dmagi","bguardian","ziddane")
$monsterCandidates = @()
foreach($key in $monsterKeys) {
  $dirs = Get-ChildItem $Root -Recurse -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -like "*$key*" } | Select-Object -First 3
  foreach($d in $dirs) {
    $inx = Get-ChildItem $d.FullName -Recurse -File -Filter *.inx -ErrorAction SilentlyContinue | Select-Object -First 3
    if($inx){ $monsterCandidates += $inx } else {
      $monsterCandidates += Get-ChildItem $d.FullName -Recurse -File -Filter *.smd -ErrorAction SilentlyContinue | Select-Object -First 2
    }
  }
}
$monsterCandidates = $monsterCandidates | Sort-Object FullName -Unique | Select-Object -First 20
$mok=0
foreach($f in $monsterCandidates) { if(Convert-One $f.FullName $OutMonster "monster_"){ $mok++ } }

$weaponDirs = Get-ChildItem $Root -Recurse -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -ieq "weapons" } | Select-Object -First 3
$weaponCandidates = @()
foreach($d in $weaponDirs) {
  $weaponCandidates += Get-ChildItem $d.FullName -File -Filter *.smd -ErrorAction SilentlyContinue | Select-Object -First 30
}
$weaponCandidates = $weaponCandidates | Sort-Object FullName -Unique | Select-Object -First 30
$wok=0
foreach($f in $weaponCandidates) { if(Convert-One $f.FullName $OutWeapon "weapon_"){ $wok++ } }

Write-Host ""
Write-Host "=== RESULTADO ===" -ForegroundColor Cyan
Write-Host "Players:  $pok"
Write-Host "Monstros: $mok"
Write-Host "Armas:    $wok"
Write-Host "Destino:  $OutRoot"

if ($pok -eq 0 -or $mok -eq 0) {
  Write-Host ""
  Write-Host "Nao consegui gerar player + monstro automaticamente." -ForegroundColor Yellow
  Write-Host "Veja tools\import_log.txt. Nada foi substituido por boneco procedural."
} else {
  Write-Host ""
  Write-Host "PRONTO. Abra project.godot no Godot, aguarde a importacao e aperte F5." -ForegroundColor Green
}
Read-Host "ENTER para fechar"
