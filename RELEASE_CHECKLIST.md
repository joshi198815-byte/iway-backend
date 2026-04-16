# IWAY Release Checklist

## Estado validado en esta sesión

- Frontend Flutter conectado al backend real NestJS + Prisma
- `flutter pub get` ejecutado
- `flutter analyze` sin errores
- Smoke test backend completado para:
  - register customer
  - register traveler
  - create shipment
  - create offer
  - accept offer
  - chat create/send
  - tracking send/latest/timeline/eta
  - ratings create/list
  - notifications list/mark-read
- Prueba visual manual reportada como correcta por el usuario

## Pre-release manual QA

### Auth
- [ ] Login correcto
- [ ] Error visible con credenciales inválidas
- [ ] Registro cliente correcto
- [ ] Registro viajero correcto
- [ ] Logout correcto

### Core flow
- [ ] Crear envío
- [ ] Ver ofertas del envío
- [ ] Crear oferta como traveler
- [ ] Aceptar oferta como customer
- [ ] Abrir chat del envío
- [ ] Enviar mensaje
- [ ] Abrir tracking
- [ ] Cambiar estado a assigned
- [ ] Cambiar estado a delivered

### Activity
- [ ] Rating enviado correctamente
- [ ] Notifications visibles
- [ ] Notifications se marcan como leídas
- [ ] Debt summary carga sin error

### UX
- [ ] No loaders infinitos
- [ ] No pantallas vacías sin contexto
- [ ] Navegación back consistente
- [ ] Home, map y profile se sienten consistentes con el tema premium

## Configuración esperada

### Backend
Archivo: `backend/.env`

Valores mínimos:

```env
PORT=3000
DATABASE_URL="postgresql://iway:iway_staging_change_me@127.0.0.1:5432/iway_staging?schema=public"
JWT_SECRET="replace-with-a-long-random-secret-at-least-32-chars"
```

### Frontend API
Por defecto:
- Android emulator -> `http://10.0.2.2:3000/api`
- Desktop/local -> `http://127.0.0.1:3000/api`

Override opcional:

```bash
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:3000/api
```

### Web Maps
Archivo local no versionado: `web/maps-config.js`

Crear desde `web/maps-config.example.js` y colocar:

```js
window.GOOGLE_MAPS_API_KEY = 'TU_GOOGLE_MAPS_API_KEY';
```

## Dependencias a revisar después, no urgentes

No se recomienda actualizar ahora mismo si el foco es estabilidad.

Direct dependencies con versiones más nuevas disponibles:
- `cupertino_icons`
- `geolocator`
- `google_maps_flutter`
- `image_picker`
- `shared_preferences`

Notas:
- `geolocator` tiene salto fuerte hasta `14.x`, mejor probarlo aparte.
- `google_maps_flutter` también conviene evaluarlo con smoke test visual antes de subir versión.

## Riesgos conocidos

- Linux desktop requiere toolchain del sistema (`cmake`, `clang`, `ninja-build`, `pkg-config`, `libgtk-3-dev`).
- El repo en este entorno no estaba inicializado como git, así que el cierre de cambios no pudo dejar commit desde esta sesión.

## Recomendación de siguiente fase

1. QA manual corta de release
2. Inicializar o conectar repo git correctamente
3. Hacer commit limpio de cierre
4. Si el producto sigue creciendo, recién ahí revisar upgrades de dependencias por lotes


### Production infra
- [ ] `.env.production` creado con secretos reales
- [ ] `docker compose -f backend/docker-compose.production.yml up -d --build` validado
- [ ] `/api/health` responde en entorno productivo
- [ ] backup PostgreSQL probado
- [ ] almacenamiento persistente de `uploads/` confirmado
- [ ] reverse proxy + HTTPS configurados
- [ ] Firebase production keys cargadas si push nativo estará activo
