const { execSync, spawn } = require('child_process');
const path = require('path');

const backendDir = path.resolve(__dirname, '..');

function main() {
  const env = {
    ...process.env,
    DATABASE_URL: process.env.DATABASE_URL || 'file:./dev.db',
    PORT: process.env.PORT || '3000',
  };

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
