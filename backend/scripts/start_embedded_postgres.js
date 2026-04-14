const EmbeddedPostgres = require('embedded-postgres').default;
const path = require('node:path');
const fs = require('node:fs');

const port = Number(process.env.EMBEDDED_POSTGRES_PORT || 5432);
const databaseDir = path.resolve(process.env.EMBEDDED_POSTGRES_DIR || '.embedded-postgres');
const user = process.env.EMBEDDED_POSTGRES_USER || 'iway';
const password = process.env.EMBEDDED_POSTGRES_PASSWORD || 'iway_staging_change_me';
const database = process.env.EMBEDDED_POSTGRES_DB || 'iway_staging';

async function main() {
  const pg = new EmbeddedPostgres({
    databaseDir,
    port,
    user,
    password,
    onLog: (message) => process.stderr.write(message),
    onError: (error) => console.error(error),
  });

  if (!fs.existsSync(path.join(databaseDir, 'postgresql.conf'))) {
    if (fs.existsSync(databaseDir)) {
      fs.rmSync(databaseDir, { recursive: true, force: true });
    }
    await pg.initialise();
  }

  await pg.start();
  await pg.createDatabase(database).catch(() => {});

  console.log(JSON.stringify({ ok: true, port, databaseDir, database, user }));

  const shutdown = async () => {
    try {
      await pg.stop();
    } finally {
      process.exit(0);
    }
  };

  process.on('SIGINT', shutdown);
  process.on('SIGTERM', shutdown);
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
