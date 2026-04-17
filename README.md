# IWAY App

Aplicación Flutter para logística y envíos Guatemala ↔ USA, conectada a un backend NestJS + Prisma.

## Estado actual

El proyecto ya cubre el flujo principal:
- login y registro real contra backend
- registro de viajeros
- creación de envíos
- ofertas y aceptación
- chat interno
- tracking
- rating persistido en backend
- notifications persistidas en backend
- panel administrativo básico

## Estructura

- `lib/` → frontend Flutter
- `backend/` → API NestJS + Prisma

## Configuración de API

El frontend usa por defecto esta API productiva:
- `https://api.iway.one/api`
- Si ese prefijo devuelve `404`, el cliente reintenta automáticamente contra `https://api.iway.one`

También puedes sobreescribirla con `--dart-define`:

```bash
flutter run --dart-define=API_BASE_URL=https://api.iway.one/api
```

Si pasas una URL sin `/api`, la app la normaliza automáticamente.

## Cómo correr el backend

```bash
cd backend
npm install --include=dev
npm run start:dev
```

Backend esperado en producción:

```bash
https://api.iway.one/api
```

## Cómo correr Flutter

```bash
flutter pub get
flutter analyze
flutter run
```

Ejemplo Linux desktop:

```bash
flutter run -d linux
```

## Smoke test recomendado

1. login / registro cliente
2. registro viajero
3. crear envío
4. crear oferta
5. aceptar oferta
6. abrir chat
7. enviar tracking
8. enviar rating
9. abrir notifications

## Notas

- `flutter analyze` ya quedó limpio durante esta sesión.
- ratings y notifications ya no son mock, ahora usan backend real.
- para Linux desktop necesitas toolchain del sistema (`cmake`, `clang`, `ninja-build`, `pkg-config`, `libgtk-3-dev`).
