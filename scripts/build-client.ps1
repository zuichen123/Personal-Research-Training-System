param(
  [ValidateSet("windows", "web", "apk", "all")]
  [string[]]$Targets = @("windows"),
  [string]$FlutterBin = "flutter",
  [string]$ApiBaseUrl = "",
  [switch]$SkipPubGet,
  [switch]$DryRun
)

$ErrorActionPreference = "Stop"

$root = Resolve-Path (Join-Path $PSScriptRoot "..")
$client = Join-Path $root "apps\flutter_client"
$distRoot = Join-Path $root "dist\flutter-client"

if (-not (Test-Path $client)) {
  throw "Flutter client directory not found: $client"
}

if ($Targets -contains "all") {
  $Targets = @("windows", "web", "apk")
}

$Targets = $Targets | Select-Object -Unique
New-Item -ItemType Directory -Force $distRoot | Out-Null

function Invoke-FlutterCommand {
  param(
    [string[]]$Args,
    [string]$Description
  )

  Write-Host ">> $Description"
  Write-Host "   $FlutterBin $($Args -join ' ')"

  if ($DryRun) {
    return
  }

  & $FlutterBin @Args
  if ($LASTEXITCODE -ne 0) {
    throw "Command failed: $FlutterBin $($Args -join ' ')"
  }
}

function Reset-Destination {
  param([string]$Path)

  if (Test-Path $Path) {
    Remove-Item -Recurse -Force $Path
  }
  New-Item -ItemType Directory -Force $Path | Out-Null
}

function Publish-Directory {
  param(
    [string]$Source,
    [string]$Destination
  )

  if ($DryRun) {
    Write-Host "   [dry-run] copy $Source -> $Destination"
    return
  }

  if (-not (Test-Path $Source)) {
    throw "Build output not found: $Source"
  }

  Reset-Destination $Destination
  Copy-Item -Path (Join-Path $Source "*") -Destination $Destination -Recurse -Force
}

function Publish-File {
  param(
    [string]$Source,
    [string]$Destination
  )

  if ($DryRun) {
    Write-Host "   [dry-run] copy $Source -> $Destination"
    return
  }

  if (-not (Test-Path $Source)) {
    throw "Build output not found: $Source"
  }

  $destinationDir = Split-Path -Parent $Destination
  New-Item -ItemType Directory -Force $destinationDir | Out-Null
  Copy-Item -Path $Source -Destination $Destination -Force
}

$commonArgs = @()
if ($ApiBaseUrl) {
  $commonArgs += "--dart-define=API_BASE_URL=$ApiBaseUrl"
}

Push-Location $client
try {
  if (-not $SkipPubGet) {
    Invoke-FlutterCommand -Args @("pub", "get") -Description "flutter pub get"
  }

  foreach ($target in $Targets) {
    switch ($target) {
      "windows" {
        Invoke-FlutterCommand -Args (@("build", "windows") + $commonArgs) -Description "build Flutter Windows client"
        Publish-Directory -Source (Join-Path $client "build\windows\x64\runner\Release") -Destination (Join-Path $distRoot "windows")
      }
      "web" {
        Invoke-FlutterCommand -Args (@("build", "web") + $commonArgs) -Description "build Flutter Web client"
        Publish-Directory -Source (Join-Path $client "build\web") -Destination (Join-Path $distRoot "web")
      }
      "apk" {
        Invoke-FlutterCommand -Args (@("build", "apk") + $commonArgs) -Description "build Flutter Android APK"
        Publish-File -Source (Join-Path $client "build\app\outputs\flutter-apk\app-release.apk") -Destination (Join-Path $distRoot "apk\app-release.apk")
      }
      default {
        throw "Unsupported target: $target"
      }
    }
  }
}
finally {
  Pop-Location
}

Write-Host "Done. Artifacts staged in $distRoot"
