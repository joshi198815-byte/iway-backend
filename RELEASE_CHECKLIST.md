# RELEASE CHECKLIST - I-WAY

## 1) Backend production deploy

### Antes de desplegar
- Confirmar variables productivas:
  - `DATABASE_URL`
  - `JWT_SECRET`
  - claves finales/restringidas de Maps/Firebase si aplican
- Confirmar que el backend apunta al schema correcto de Postgres

### Comandos esperados en backend
```bash
cd backend
npm install --include=dev
npm run prisma:generate:postgres
npm run db:push:postgres
npm run typecheck
npm run build
```

### Validación mínima después del deploy
- Login funciona
- Crear envío funciona
- Ver oportunidades funciona
- Crear oferta funciona
- Aceptar oferta funciona
- Chat abre
- Tracking carga

## 2) Android release

### Build esperado
```bash
flutter pub get
flutter build appbundle --release \
  --dart-define=API_BASE_URL=https://api.iway.one/api \
  --dart-define=GOOGLE_MAPS_API_KEY=TU_KEY
```

### Confirmar antes del build
- Flutter SDK real instalado
- Android SDK listo
- keystore/config release correctos
- backend productivo ya arriba

## 3) Smoke QA en teléfono real

### A. Cliente
- Registrarse o iniciar sesión
- Ir a Perfil
- Guardar remitente actual
- Crear remitente nuevo
- Crear envío con remitente guardado
- Guardar destinatario
- Publicar envío

### B. Traveler
- Iniciar sesión como traveler
- Ir a Mi perfil
- Seleccionar rutas de USA desde el selector de estados
- Guardar cambios
- Abrir Oportunidades
- Confirmar que cada envío muestre:
  - departamento/estado de recogida
  - si coincide o no con rutas activas
  - punto sugerido de encuentro
  - distancia aproximada al pickup (si hay permisos + coordenadas)
- Abrir mapa desde Oportunidades
- Entrar a Ofertas
- Confirmar que también muestre pickup/contexto/chat/mapa
- Enviar oferta

### C. Cliente acepta
- Abrir ofertas del envío
- Aceptar traveler
- Confirmar:
  - se crea/asigna correctamente
  - aparece mensaje automático en chat
  - tracking muestra pickup/contacto/punto sugerido

### D. Coordinación y operación
- Abrir chat desde tracking u ofertas
- Confirmar que el draft inicial ayude a coordinar pickup
- Traveler marca recogido
- Tracking avanza
- Mapa abre
- Entrega final funciona

## 4) Criterio de salida

Se considera listo para producción si:
- backend deployado sin errores
- schema nuevo aplicado
- app release compila
- smoke QA completo pasa sin bloqueos críticos
- no hay errores de login, shipment, offer, chat o tracking

## 5) No mezclar en release
- Evitar subir cambios ajenos de tooling/desktop/web si no forman parte del release móvil/backend
- Revisar bien el diff final antes de merge/deploy
