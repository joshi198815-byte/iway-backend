# iWay Admin Web

Admin web principal de iWay, hecha en código con Next.js y conectada al backend actual.

## Estado de la dirección técnica

- **esta es la ruta principal**
- **Appsmith ya no forma parte del plan de producto**
- el objetivo es tener una admin durable, versionable y cómoda para operar todos los días

## Qué incluye hoy

- login con `/auth/login`
- sesión por cookies HttpOnly
- layout protegido
- dashboard operativo
- pantallas base de:
  - Travelers Review
  - Transfers Review
  - Shipments
  - Shipment Detail
  - Finance Dashboard
  - Admin Collaborators
- fallback automático `https://api.iway.one/api` -> `https://api.iway.one`

## Variables de entorno

Copia `.env.example` a `.env.local` y ajusta si hace falta:

```bash
NEXT_PUBLIC_API_BASE_URL=https://api.iway.one/api
```

## Desarrollo

```bash
cd admin-web
npm install
npm run dev
```

## Próxima fase recomendada

1. validar login y payloads reales
2. pulir tablas, filtros y estados vacíos
3. endurecer permisos por rol
4. mejorar visualización de finanzas y charts
5. validar end-to-end con credenciales reales

## Validación rápida

```bash
npm run validate:api
```

Requiere `API_BASE_URL`, `ADMIN_EMAIL` y `ADMIN_PASSWORD` en el entorno. Más detalle en `VALIDATION.md`.

## Nota

La meta ya no es migrar a una herramienta low-code. La meta es cerrar una admin web propia, mantenible y lista para operación real.
