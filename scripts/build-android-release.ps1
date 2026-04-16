param(
  [Parameter(Mandatory = $true)]
  [string]$ApiBaseUrl
)

$ErrorActionPreference = 'Stop'

Write-Host '[I-WAY] Limpiando proyecto...'
flutter clean

Write-Host '[I-WAY] Descargando dependencias...'
flutter pub get

Write-Host '[I-WAY] Generando AAB release...'
flutter build appbundle --release --dart-define="API_BASE_URL=$ApiBaseUrl"

Write-Host ''
Write-Host 'OK. AAB generado en:'
Write-Host 'build/app/outputs/bundle/release/app-release.aab'
