param(
  [string]$AppName = "self-study-client"
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")
$client = Join-Path $root "apps/fyne-client"
$dist = Join-Path $root "dist"
New-Item -ItemType Directory -Force $dist | Out-Null

Push-Location $client
try {
  go mod tidy

  $env:GOOS = "windows"
  $env:GOARCH = "amd64"
  go build -o (Join-Path $dist "$AppName-windows-amd64.exe") ./cmd/client

  $env:GOOS = "linux"
  $env:GOARCH = "amd64"
  go build -o (Join-Path $dist "$AppName-linux-amd64") ./cmd/client

  Remove-Item Env:GOOS -ErrorAction SilentlyContinue
  Remove-Item Env:GOARCH -ErrorAction SilentlyContinue

  if (Get-Command fyne -ErrorAction SilentlyContinue) {
    fyne package -os android -appID com.selfstudy.tool.client -name SelfStudyTool
    Write-Host "Android package generated under apps/fyne-client"
  } else {
    Write-Host "Skip Android package: fyne CLI not found"
  }
}
finally {
  Pop-Location
}

Write-Host "Done. Desktop artifacts in $dist"
