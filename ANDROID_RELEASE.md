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
4. Reemplazar `API_BASE_URL` por tu dominio real

Ejemplo esperado:

```bash
https://api.tudominio.com/api
```

## Comando release recomendado
Desde la raíz del proyecto:

```bash
flutter clean
flutter pub get
flutter build appbundle --release --dart-define=API_BASE_URL=https://api.tudominio.com/api
```

## APK firmado opcional
```bash
flutter build apk --release --dart-define=API_BASE_URL=https://api.tudominio.com/api
```

## Resultado esperado
- AAB: `build/app/outputs/bundle/release/app-release.aab`
- APK: `build/app/outputs/flutter-apk/app-release.apk`

## Checklist rápida
- [ ] Login funciona en release
- [ ] Registro funciona en release
- [ ] Crear envío funciona
- [ ] Ofertar funciona
- [ ] Chat funciona
- [ ] Tracking funciona
- [ ] Notifications llegan
- [ ] Maps carga
- [ ] API usa HTTPS productivo

## Nota importante
El proyecto en desarrollo usa URLs locales por defecto. Para release, siempre compilar con `--dart-define=API_BASE_URL=...` apuntando al backend productivo.
