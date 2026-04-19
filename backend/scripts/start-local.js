const { execSync, spawn } = require('child_process');
const path = require('path');
const dotenv = require('dotenv');

const backendDir = path.resolve(__dirname, '..');
const shellDatabaseUrl = process.env.DATABASE_URL;
dotenv.config({ path: path.join(backendDir, '.env') });

function main() {
  const env = {
    ...process.env,
    DATABASE_URL:
      shellDatabaseUrl ||
      process.env.LOCAL_DATABASE_URL ||
      'postgresql://iway:iway_staging_change_me@127.0.0.1:5432/iway_staging?schema=public',
    PORT: process.env.PORT || '10000',
  };

  execSync('npx prisma generate', {
    cwd: backendDir,
    stdio: 'inherit',
    env,
  });

  execSync('npx prisma db push --skip-generate', {
    cwd: backendDir,
    stdio: 'inherit',
    env,
  });

  const appProcess = spawn('npx', ['ts-node', 'src/main.ts'], {
    cwd: backendDir,
    stdio: 'inherit',
    env,
  });

  const shutdown = () => {
    if (!appProcess.killed) {
      appProcess.kill('SIGINT');
    }
    process.exit(0);
  };

  process.on('SIGINT', shutdown);
  process.on('SIGTERM', shutdown);

  appProcess.on('exit', (code) => {
    process.exit(code ?? 0);
  });
}

main();
