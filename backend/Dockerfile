FROM node:24-alpine AS deps
WORKDIR /app
COPY package*.json ./
RUN npm ci

FROM deps AS builder
WORKDIR /app
COPY prisma ./prisma
COPY tsconfig.json ./
COPY src ./src
RUN npx prisma generate --schema prisma/schema.postgres.prisma
RUN npm run build

FROM node:24-alpine AS runner
WORKDIR /app
ENV NODE_ENV=production
COPY package*.json ./
RUN npm ci --omit=dev
COPY --from=builder /app/node_modules/.prisma /app/node_modules/.prisma
COPY --from=builder /app/node_modules/@prisma /app/node_modules/@prisma
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/prisma ./prisma
COPY scripts ./scripts
RUN chmod +x ./scripts/docker-entrypoint.sh ./scripts/backup_postgres.sh ./scripts/restore_postgres.sh ./scripts/validate_production_env.sh ./scripts/smoke_deploy.sh
EXPOSE 3000
CMD ["sh", "./scripts/docker-entrypoint.sh"]
