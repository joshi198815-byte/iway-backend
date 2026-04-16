# iOS Release Prep (I-WAY)

## Estado actual
- bundle id configurado: `com.iway.gt`
- nombre visible: `I-WAY`
- Firebase plist ubicado en `ios/Runner/GoogleService-Info.plist`
- Google Maps key ya no queda hardcodeada en el repo

## Config local requerida
Crear este archivo local, no versionado:

`ios/Flutter/MapsConfig.xcconfig`

Contenido:

```xcconfig
GOOGLE_MAPS_API_KEY=TU_GOOGLE_MAPS_API_KEY
```

Puedes copiar desde:

`ios/Flutter/MapsConfig.example.xcconfig`

## Pendiente externo
- Apple Developer activo
- Team ID
- firma / provisioning desde Xcode

## Cuando toque compilar
1. abrir `ios/Runner.xcworkspace` en Xcode
2. seleccionar team
3. validar signing
4. archive de release
