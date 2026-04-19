# PROJECT_STRUCTURE.md

## Raíz
- `lib/`: App Flutter principal para cliente y viajero.
- `backend/`: API NestJS, lógica de negocio, realtime, matching, wallet y soporte.
- `admin-web/`: Panel web de administración.
- `android/`, `ios/`, `web/`, `linux/`, `macos/`, `windows/`: runners/plataformas de Flutter.
- `scripts/`: utilidades operativas del proyecto.

## Flutter `lib/`
- `core/`: arranque global de la app, locale y configuración transversal.
- `config/`: tema visual y ajustes estáticos de app.
- `routes/`: tabla central de rutas/navegación.
- `services/`: servicios globales de sesión, API y realtime.
- `shared/`: modelos, helpers y componentes reutilizables.
- `features/auth/`: login, registro, verificación y catálogos de ubicación.
- `features/home/`: dashboards, banners y campana de notificaciones.
- `features/shipment/`: crear envío, tracking, pedidos y oportunidades.
- `features/matching/`: ofertas y flujo comercial entre cliente y viajero.
- `features/traveler/`: workspace real del viajero y gestión de rutas.
- `features/profile/`: perfil editable del usuario/viajero.
- `features/rating/`: calificaciones recibidas y envío de rating.
- `features/payments/`: wallet, deuda pendiente y reporte de comprobantes.
- `features/disputes/`: soporte técnico y tickets hacia admin.
- `features/notifications/`: listado de notificaciones reales.
- `features/chat/`, `features/map/`, `features/tracking/`: vistas operativas complementarias.
- `debug/`: utilidades diagnósticas activas solo para depuración.

## Backend `backend/src/`
- `app.module.ts`: composición principal de módulos.
- `auth/`: registro, login, sesión y perfil base.
- `users/`: lectura/actualización de usuarios y sesión.
- `travelers/`: workspace del viajero, online real y rutas activas.
- `shipments/`: creación, consulta y transición oficial de estados de envío.
- `offers/`: creación, aceptación y rechazo de ofertas.
- `tracking/`: tracking operativo y puntos de seguimiento.
- `chat/`: apertura y control del chat por envío.
- `notifications/`: device tokens, push y eventos visibles.
- `realtime/`: socket gateway y fan-out por usuario/envío.
- `transfers/`: wallet del viajero, comprobantes y cola de revisión admin.
- `commissions/`: generación y control de comisiones por envío.
- `disputes/`: tickets/incidencias de soporte vinculadas a envíos.
- `ratings/`: reseñas entre cliente y viajero.
- `content/`: feeds de banners para home y traveler dashboard.
- `database/`: Prisma service y acceso a PostgreSQL.
- `common/`: constantes y utilidades compartidas del backend.
- `health/`: métricas/estado general del sistema.

## Prisma `backend/prisma/`
- `schema.prisma`: modelo principal de datos.
- `schema.postgres.prisma`: variante alineada para entorno PostgreSQL.
- `migrations/` (si existe): historial de cambios estructurales.

## Admin Web `admin-web/`
- `app/`: páginas/rutas del panel.
- `components/`: UI reutilizable del admin.
- `lib/`: clientes, helpers y lógica compartida del panel.
- `public/`: archivos públicos del admin.
- `scripts/` y `deploy/`: utilidades de build/despliegue.
