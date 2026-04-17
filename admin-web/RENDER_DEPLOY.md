# Render Deploy for Admin Web

## Objetivo

Publicar `admin-web` en Render y luego apuntar `admin.iway.one` a ese servicio.

## Archivo preparado

- `admin-web/render.yaml`

## Opción A: Blueprint en Render

1. Entrar a Render
2. New +
3. Blueprint
4. seleccionar este repo
5. usar `admin-web/render.yaml`
6. crear servicio `iway-admin-web`

## Opción B: Web Service manual

Si prefieres crear el servicio manualmente:

- **Root Directory:** `admin-web`
- **Runtime:** Node
- **Build Command:** `npm install --no-fund --no-audit && npm run build`
- **Start Command:** `npm run start`
- **Environment Variables:**
  - `NEXT_PUBLIC_API_BASE_URL=https://api.iway.one/api`
  - `NODE_ENV=production`
  - `PORT=10000`

## Dominio custom

Después de que Render te dé una URL tipo:

- `https://iway-admin-web.onrender.com`

hacer esto:

1. agregar custom domain `admin.iway.one` en Render
2. crear el registro DNS que Render pida
3. esperar SSL automático

## Validación final

- abrir `https://admin.iway.one/login`
- iniciar sesión
- revisar Travelers Review
- revisar Transfers Review
- revisar Shipments
- revisar Finance Dashboard
- revisar Admin Collaborators con usuario admin

## Nota

En este host local el build de producción dio un crash tipo `Bus error`, pero eso no necesariamente significa que Render falle. En un entorno limpio de build de Render suele resolverse bien si el servicio Node compila normalmente.
