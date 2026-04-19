# ADMIN_RELEASE_CHECKLIST.md

## Estado general
- [x] Admin Web restringido a sesión `ADMIN` en `admin-web/app/(protected)/layout.tsx` mediante `requireAdminSession()`.
- [x] Configuración de negocio conectada al backend real.
- [x] Revisión de pagos con comprobante visible y aprobación/rechazo operativos.
- [x] Revisión KYC de viajeros con selfie/documento y acciones de aprobación/rechazo.
- [x] Editor real de banner feeds para Usuario y Viajero.

## Endpoints Admin protegidos por rol `ADMIN`

### Tarifas / negocio
- [x] `GET /commissions/settings`
- [x] `PUT /commissions/settings`
- [x] `POST /commissions/weekly-cutoff`
- [x] `POST /commissions/traveler/:travelerId/ledger-adjustments`

### Pagos / wallet
- [x] `GET /transfers/review-queue`
- [x] `PUT /transfers/:transferId/review`
- [x] `GET /transfers/traveler/:travelerId/payout-policy`

### KYC viajeros
- [x] `GET /travelers/review-queue`
- [x] `POST /travelers/:userId/run-kyc-analysis`
- [x] `POST /travelers/:userId/payout-hold`
- [x] `POST /travelers/:userId/review`

### Banners
- [x] `PUT /content/home`
- [x] `PUT /content/traveler`

## Sincronización con App
- [x] La app lee precios desde backend, no desde valores estáticos locales.
- [x] La aprobación de transferencias crea notificación operativa para el viajero, lo que dispara evento realtime `notification_updated`.
- [x] Los feeds `home-banners` y `traveler-banners` ya aceptan payload con `mediaUrl` y `mediaType`.

## Datos limpios hacia Admin
- [x] Transfer review expone `transferId`, `travelerId`, referencia bancaria y comprobante.
- [x] Transfer submission guarda `relatedShipments` en auditoría para relacionar deuda con paquetes.
- [x] Support/KYC conservan `shipmentId` y `userId` limpios para revisión operativa.

## Pendientes no bloqueantes
- [ ] Ejecutar build final en Render después del deploy.
- [ ] Validar con sesión ADMIN real los formularios de tarifas, banners, KYC y pagos en entorno Render.
