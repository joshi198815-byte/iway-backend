# Admin Web Validation

## Objetivo

Validar rápidamente que la admin web pueda autenticarse y leer los endpoints principales del backend real.

## Variables requeridas

```bash
export API_BASE_URL=https://api.iway.one/api
export ADMIN_EMAIL=tu-admin@iway.one
export ADMIN_PASSWORD='tu-password'
```

## Script de validación

```bash
cd admin-web
node scripts/validate-admin-api.mjs
```

## Qué valida

- login (`/auth/login`)
- travelers review queue
- transfers review queue
- shipments
- finance overview
- collaborators, si el usuario es `admin`

## Siguiente validación manual recomendada

Después del script:

1. entrar al login web
2. abrir Travelers Review
3. abrir Transfers Review
4. abrir Shipments
5. abrir Finance Dashboard
6. si eres admin, abrir Admin Collaborators

## Resultado esperado

Si el script pasa y las pantallas cargan sin 403/500, la base de la admin está lista para seguir puliéndose con datos reales.
