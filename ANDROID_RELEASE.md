# Android Release (I-WAY)

## Estado preparado
- applicationId: `com.iway.gt`
- nombre visible: `I-WAY`
- Firebase Android: `android/app/google-services.json`
- signing release: `android/key.properties`

## Antes de compilar
1. Tener Flutter instalado en Windows
2. Tener Android SDK instalado
3. Confirmar backend HTTPS de producción
4. Tener Google Maps API Key real para release
5. Reemplazar `API_BASE_URL` por tu dominio real

Ejemplos esperados para producción actual:

```bash
https://api.iway.one/api
AIzaSyXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
```

## Comando release recomendado
Desde la raíz del proyecto:

```bash
flutter clean
flutter pub get
flutter build appbundle --release --dart-define=API_BASE_URL=https://api.iway.one/api --dart-define=GOOGLE_MAPS_API_KEY=AIzaSyXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
```

## APK firmado opcional
```bash
flutter build apk --release --dart-define=API_BASE_URL=https://api.iway.one/api --dart-define=GOOGLE_MAPS_API_KEY=AIzaSyXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
```

## Resultado esperado
- AAB: `build/app/outputs/bundle/release/app-release.aab`
- APK: `build/app/outputs/flutter-apk/app-release.apk`

## Checklist rápida
- [ ] Login funciona en release
- [ ] Registro funciona en release
- [ ] Crear envío funciona
- [ ] Autocomplete de direcciones funciona
- [ ] Maps carga
- [ ] Ofertar funciona
- [ ] Chat funciona
- [ ] Tracking funciona
- [ ] Notifications llegan
- [ ] API usa HTTPS productivo

## Nota importante
El proyecto en desarrollo usa URLs locales por defecto. Para release, siempre compilar con `--dart-define=API_BASE_URL=...` apuntando al backend productivo y con `--dart-define=GOOGLE_MAPS_API_KEY=...` para las búsquedas y geocodificación de direcciones.
