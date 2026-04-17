# ADMIN WEB NEXTJS PLAN

## Decisión

La web admin de iWay se construirá en **código**, con `admin-web/` como proyecto principal.

Appsmith queda fuera de la ruta principal.

## Stack elegido

- Next.js
- TypeScript
- backend actual NestJS + Prisma
- auth por JWT de `/auth/login`
- despliegue sugerido en subdominio tipo `admin.iway.one`

## MVP operativo

### Ya montado
- Login
- Dashboard
- Travelers Review
- Transfers Review
- Shipments
- Shipment Detail
- Finance Dashboard

### Próximo bloque
- Admin Collaborators
- mejoras de UX en tablas y filtros
- estados de carga / error más pulidos
- validación de previews protegidos con datos reales
- refinamiento de KPIs y gráficas

## Orden de cierre recomendado

1. validar login real
2. validar Travelers Review
3. validar Transfers Review
4. validar Shipments + Shipment Detail
5. validar Finance Dashboard
6. agregar Collaborators
7. endurecer permisos admin/support
8. pulir UI final

## Resultado esperado

Una admin web propia, versionable, mantenible y lista para operación diaria sin dependencia de Appsmith.
