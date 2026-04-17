# RELEASE STATUS - I-WAY

## ✅ Listo

### Backend base
- Compila correctamente (`npm run typecheck`, `npm run build`)
- Flujo principal probado en local con datos temporales:
  - registro customer
  - registro traveler
  - aprobación traveler
  - crear shipment
  - crear y aceptar offer
  - chat
  - tracking
  - rating
  - notifications

### Seguridad / acceso corregido
- `POST /shipments` ya no depende de `customerId` manual en cliente
- `POST /offers/:id/accept` ya no permite doble aceptación
- `GET /shipments/:id` ya no expone envíos ajenos
- `GET /users/:id` ya no expone email/teléfono/flags privados
- errores de permisos relevantes corregidos a `403 Forbidden`

### Config móvil base
- Android bundle id: `com.iway.gt`
- Display name: `I-WAY`
- Android manifest alineado para release
- iOS bundle/name alineados
- Maps config externalizada en Android / iOS / web
- Docs y scripts de release preparados

## 🟡 Listo con dependencia externa

### Android release real
Queda muy cerca, pero depende de:
- compilar en la máquina del usuario con Flutter/Android SDK real
- definir `API_BASE_URL` final HTTPS
- usar keys finales restringidas de Maps/Firebase

Comando esperado al final:

```bash
flutter build appbundle --release --dart-define=API_BASE_URL=https://api.iway.one/api --dart-define=GOOGLE_MAPS_API_KEY=TU_KEY
```

### iOS prep
- Proyecto prearmado
- Firebase plist y bundle preparados
- Falta cierre real de signing/provisioning en Xcode

## 🔴 Pendiente crítico

### Infraestructura productiva
- No existe todavía dominio/API HTTPS final
- `JWT_SECRET` real fuerte todavía debe definirse en entorno productivo
- Conviene restringir o rotar keys expuestas de Maps/Firebase

### Toolchain de build en este entorno
- Aquí no hay Flutter SDK/Xcode/CocoaPods/Android build chain funcional para validar binarios finales
- La validación de builds reales debe hacerse en la máquina del usuario

### iOS/App Store
- Bloqueado hasta que exista Apple Developer / Team ID

## Riesgos restantes relevantes
- `android/app/google-services.json` y `ios/Runner/GoogleService-Info.plist` siguen versionados como config de cliente
- `backend/.env` local contiene credenciales reales, aunque está ignorado por git
- Falta una pasada final de validación visual/UX en app Flutter real

## Recomendación inmediata
1. Definir backend HTTPS final
2. Compilar Android App Bundle real en máquina del usuario
3. Hacer smoke QA sobre build instalada
4. Después cerrar iOS cuando exista Apple Developer
