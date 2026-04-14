# iway-backend

Backend base de iway con NestJS + Prisma.

## Incluye
- NestJS bootstrap
- Prisma schema inicial para iway
- módulos base de negocio
- DTOs iniciales
- validación global
- estructura preparada para comisiones semanales y anti-fraude
- modo local funcional con SQLite

## Comandos

```bash
npm install
npm run prisma:validate
npm run prisma:generate
npm run typecheck
npm run start:dev
npm run start:local
```

## Start local
`npm run start:local` hace esto:
- aplica `prisma db push`
- crea/actualiza la base SQLite local
- levanta el backend NestJS en puerto `3000`

## Producción
La meta de producción sigue siendo PostgreSQL.
Este modo local con SQLite es para desarrollo rápido en este entorno.

## Postgres-ready
Se agregó preparación de entorno para el corte a PostgreSQL:
- `.env.example`
- `docker-compose.postgres.yml`
- `POSTGRES_READY.md`

Notas importantes:
- para este dominio recomendamos PostgreSQL, no Firestore
- Prisma no cambia entre SQLite/PostgreSQL solo con una env var en este proyecto, así que el cutover debe hacerse de forma deliberada

## Variables básicas
Ver `.env.example`

## Modelo de negocio contemplado
- pago contra entrega
- comisión semanal del viajero
- corte semanal
- bloqueo automático por deuda
- traveler types
- rutas Guatemala ↔ USA
- base anti-robo de usuarios


## Production-ready deploy
- `prisma/schema.postgres.prisma` para corte limpio a PostgreSQL
- `.env.production.example` para secrets de despliegue
- `.env.staging.example` para staging separado
- `docker-compose.production.yml` para stack backend + postgres
- `docker-compose.staging.yml` para staging en puertos separados
- `Dockerfile` listo para contenedor
- `scripts/validate_production_env.sh` para preflight de secrets/env
- `scripts/smoke_deploy.sh` para smoke check de health
- `scripts/backup_postgres.sh` para backups simples
- `scripts/restore_postgres.sh` para drill de restore
- guía: `DEPLOY_PRODUCTION.md`
