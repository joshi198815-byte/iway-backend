# Admin Web Deployment

## Objetivo

Desplegar `admin-web` en un subdominio como `admin.iway.one`.

## Variables mínimas

```bash
NEXT_PUBLIC_API_BASE_URL=https://api.iway.one/api
PORT=3001
```

## Opción recomendada

### Docker + Nginx

```bash
cd admin-web
cp .env.production.example .env.production

docker build -t iway-admin-web .
docker run -d \
  --name iway-admin-web \
  --restart unless-stopped \
  --env-file .env.production \
  -p 3001:3001 \
  iway-admin-web
```

Después poner Nginx delante, apuntando `admin.iway.one` a `http://127.0.0.1:3001`.

## Checklist

- DNS de `admin.iway.one` apuntando al servidor
- SSL activo
- backend `api.iway.one` accesible desde el navegador
- login admin funcionando
- CORS del backend validado si hace falta en algún flujo browser-specific

## Smoke test post-deploy

1. abrir `/login`
2. iniciar sesión
3. abrir Travelers Review
4. abrir Transfers Review
5. abrir Shipments
6. abrir Finance Dashboard
7. abrir Admin Collaborators si eres admin
