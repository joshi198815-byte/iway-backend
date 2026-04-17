# iWay Admin Web

Base inicial de admin web en código, hecha con Next.js, conectada al backend actual de iWay.

## Qué incluye hoy

- login con `/auth/login`
- sesión por cookies HttpOnly
- layout protegido
- dashboard inicial con conteos de:
  - travelers review queue
  - transfers review queue
  - shipments
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

## Siguiente implementación recomendada

1. Travelers Review
2. Transfers Review
3. Shipments
4. Shipment Detail
5. Finance Dashboard
6. Admin Collaborators

## Nota

Esto reemplaza mejor a Appsmith si quieres una admin duradera, versionable y más cómoda de operar a diario.
