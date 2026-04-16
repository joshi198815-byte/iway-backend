@echo off
setlocal

if "%~1"=="" (
  echo Uso: scripts\build-android-release.bat https://api.tudominio.com/api
  exit /b 1
)

set API_BASE_URL=%~1

echo [I-WAY] Limpiando proyecto...
call flutter clean || exit /b 1

echo [I-WAY] Descargando dependencias...
call flutter pub get || exit /b 1

echo [I-WAY] Generando AAB release...
call flutter build appbundle --release --dart-define=API_BASE_URL=%API_BASE_URL% || exit /b 1

echo.
echo OK. AAB generado en:
echo build\app\outputs\bundle\release\app-release.aab
