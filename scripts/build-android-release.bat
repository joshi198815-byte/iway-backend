@echo off
setlocal

if "%~1"=="" (
  echo Uso: scripts\build-android-release.bat https://api.tudominio.com/api TU_GOOGLE_MAPS_API_KEY
  exit /b 1
)

if "%~2"=="" (
  echo Falta GOOGLE_MAPS_API_KEY
  echo Uso: scripts\build-android-release.bat https://api.tudominio.com/api TU_GOOGLE_MAPS_API_KEY
  exit /b 1
)

set API_BASE_URL=%~1
set GOOGLE_MAPS_API_KEY=%~2

echo [I-WAY] Limpiando proyecto...
call flutter clean || exit /b 1

echo [I-WAY] Descargando dependencias...
call flutter pub get || exit /b 1

echo [I-WAY] Generando AAB release...
call flutter build appbundle --release --dart-define=API_BASE_URL=%API_BASE_URL% --dart-define=GOOGLE_MAPS_API_KEY=%GOOGLE_MAPS_API_KEY% || exit /b 1

echo.
echo OK. AAB generado en:
echo build\app\outputs\bundle\release\app-release.aab
