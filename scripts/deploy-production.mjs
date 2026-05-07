import { spawnSync } from 'node:child_process';
import { existsSync } from 'node:fs';

const action = process.argv[2] ?? 'status';
const composeArgs = ['--env-file', '.env.production', '-f', 'docker-compose.yml', '-f', 'docker-compose.prod.yml'];
const services = [
  '@petwell/user-service',
  '@petwell/pet-service',
  '@petwell/appointment-service',
  '@petwell/ehr-service',
  '@petwell/billing-service',
  '@petwell/telemed-service',
  '@petwell/notification-service',
  '@petwell/analytics-service'
];

function run(command, args, options = {}) {
  const result = spawnSync(command, args, { stdio: 'inherit', shell: process.platform === 'win32', ...options });
  if (result.status !== 0) {
    process.exit(result.status ?? 1);
  }
}

function ensureEnv() {
  if (!existsSync('.env.production')) {
    console.error('[deploy] Missing .env.production. Copy .env.production.example and fill real production values.');
    process.exit(1);
  }
  run('node', ['scripts/validate-production-env.mjs', '.env.production']);
  run('docker', ['compose', ...composeArgs, 'config', '--quiet']);
}

function migrate() {
  for (const service of services) {
    const composeService = service.replace('@petwell/', '');
    console.log(`[deploy] Running migrations for ${service}`);
    run('docker', [
      'compose',
      ...composeArgs,
      'run',
      '--rm',
      composeService,
      'pnpm',
      '--filter',
      service,
      'prisma:migrate:deploy'
    ]);
  }
}

switch (action) {
  case 'up':
    ensureEnv();
    run('docker', ['compose', ...composeArgs, 'up', '-d', '--build']);
    migrate();
    run('docker', ['compose', ...composeArgs, 'ps']);
    break;
  case 'migrate':
    ensureEnv();
    migrate();
    break;
  case 'status':
    ensureEnv();
    run('docker', ['compose', ...composeArgs, 'ps']);
    break;
  case 'down':
    ensureEnv();
    run('docker', ['compose', ...composeArgs, 'down']);
    break;
  default:
    console.error('[deploy] Usage: node scripts/deploy-production.mjs <up|migrate|status|down>');
    process.exit(1);
}
