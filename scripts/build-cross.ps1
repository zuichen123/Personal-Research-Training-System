param(
  [string]$AppName = "prts"
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")
$dist = Join-Path $root "dist"
New-Item -ItemType Directory -Force $dist | Out-Null

$targets = @(
  @{ GOOS = "windows"; GOARCH = "amd64"; EXT = ".exe" },
  @{ GOOS = "linux"; GOARCH = "amd64"; EXT = "" },
  @{ GOOS = "android"; GOARCH = "arm64"; EXT = "" }
)

foreach ($target in $targets) {
  $out = Join-Path $dist ("{0}-{1}-{2}{3}" -f $AppName, $target.GOOS, $target.GOARCH, $target.EXT)
  Write-Host "Building $out"

  $env:CGO_ENABLED = "0"
  $env:GOOS = $target.GOOS
  $env:GOARCH = $target.GOARCH

  go build -o $out "./cmd/server"
}

Write-Host "Done. Artifacts in $dist"
