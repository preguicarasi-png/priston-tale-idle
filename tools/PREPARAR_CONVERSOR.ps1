$ErrorActionPreference = "Stop"
$ProjectRoot = Split-Path -Parent $PSScriptRoot
$Work = Join-Path $PSScriptRoot "_converter"
$RepoDir = Join-Path $Work "3dAssetExporter"
New-Item -ItemType Directory -Force -Path $Work | Out-Null

Write-Host "=== Preparando conversor de assets do Priston ===" -ForegroundColor Cyan

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
  throw "Git nao encontrado. Instale Git for Windows e execute novamente."
}
if (-not (Test-Path (Join-Path $RepoDir ".git"))) {
  git clone https://github.com/wesleyricardi/3dAssetExporter.git $RepoDir
} else {
  Push-Location $RepoDir
  git pull
  Pop-Location
}

$Dep = Join-Path $RepoDir "dependencies\third_party\tinygltf"
New-Item -ItemType Directory -Force -Path $Dep | Out-Null
$downloads = @{
  "tiny_gltf.h"="https://raw.githubusercontent.com/syoyo/tinygltf/release/tiny_gltf.h";
  "tiny_gltf.cc"="https://raw.githubusercontent.com/syoyo/tinygltf/release/tiny_gltf.cc";
  "json.hpp"="https://raw.githubusercontent.com/nlohmann/json/develop/single_include/nlohmann/json.hpp";
  "stb_image.h"="https://raw.githubusercontent.com/nothings/stb/master/stb_image.h";
  "stb_image_write.h"="https://raw.githubusercontent.com/nothings/stb/master/stb_image_write.h"
}
foreach($name in $downloads.Keys) {
  $dst = Join-Path $Dep $name
  if (-not (Test-Path $dst)) {
    Invoke-WebRequest -UseBasicParsing -Uri $downloads[$name] -OutFile $dst
  }
}

$proj = Join-Path $RepoDir "AssetExporter.vcxproj"
$xml = Get-Content $proj -Raw
$xml = $xml.Replace('$(SolutionDir)dependencies\third_party\tinygltf', '$(ProjectDir)dependencies\third_party\tinygltf')
$xml = $xml.Replace('..\..\..\dependencies\third_party\tinygltf\tiny_gltf.cc', 'dependencies\third_party\tinygltf\tiny_gltf.cc')
Set-Content -Path $proj -Value $xml -Encoding UTF8

$vswhere = "$"+"{env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
$vswhere = [Environment]::ExpandEnvironmentVariables("%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe")
if (-not (Test-Path $vswhere)) {
  throw "Visual Studio Build Tools nao encontrado. Instale Visual Studio 2022 Build Tools com Desktop development with C++."
}
$msbuild = & $vswhere -latest -products * -requires Microsoft.Component.MSBuild -find MSBuild\**\Bin\MSBuild.exe | Select-Object -First 1
if (-not $msbuild) { throw "MSBuild nao encontrado." }

Write-Host "Compilando AssetExporter..." -ForegroundColor Yellow
& $msbuild $proj /m /p:Configuration=DebugClient /p:Platform=Win32 /p:SolutionDir="$RepoDir\"
if ($LASTEXITCODE -ne 0) { throw "Falha ao compilar o conversor." }

$exe = Get-ChildItem $RepoDir -Recurse -Filter AssetExporter.exe | Select-Object -First 1
if (-not $exe) { throw "Compilacao terminou, mas AssetExporter.exe nao foi localizado." }
Set-Content -Path (Join-Path $Work "exporter_path.txt") -Value $exe.FullName -Encoding UTF8
Write-Host ""
Write-Host "OK: $($exe.FullName)" -ForegroundColor Green
Write-Host "Agora execute IMPORTAR_PRISTON.bat"
Read-Host "ENTER para fechar"
