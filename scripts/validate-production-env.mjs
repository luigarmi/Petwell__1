import { readFileSync, existsSync } from 'node:fs';

const envPath = process.argv[2] ?? '.env.production';

if (!existsSync(envPath)) {
  console.error(`[deploy-env] Missing ${envPath}. Copy .env.production.example and fill real values.`);
  process.exit(1);
}

const required = [
  'PUBLIC_APP_URL',
  'API_PUBLIC_URL',
  'CORS_ORIGIN',
  'JWT_ACCESS_SECRET',
  'JWT_REFRESH_SECRET',
  'FIELD_ENCRYPTION_KEY',
  'POSTGRES_USER',
  'POSTGRES_PASSWORD',
  'RABBITMQ_DEFAULT_USER',
  'RABBITMQ_DEFAULT_PASS',
  'MINIO_ROOT_USER',
  'MINIO_ROOT_PASSWORD',
  'MAIL_HOST',
  'MAIL_PORT',
  'MAIL_FROM'
];

const weakPatterns = [
  /^$/,
  /replace-with/i,
  /change-me/i,
  /example\.com/i,
  /localhost/i,
  /127\.0\.0\.1/i,
  /^postgres$/,
  /^guest$/,
  /^minioadmin$/
];

const env = Object.fromEntries(
  readFileSync(envPath, 'utf8')
    .split(/\r?\n/)
    .map((line) => line.trim())
    .filter((line) => line && !line.startsWith('#'))
    .map((line) => {
      const separator = line.indexOf('=');
      return separator === -1 ? [line, ''] : [line.slice(0, separator), line.slice(separator + 1)];
    })
);

const failures = [];

for (const key of required) {
  const value = env[key] ?? '';
  if (weakPatterns.some((pattern) => pattern.test(value))) {
    failures.push(`${key} must be set to a production value`);
  }
}

for (const key of ['JWT_ACCESS_SECRET', 'JWT_REFRESH_SECRET', 'FIELD_ENCRYPTION_KEY']) {
  if ((env[key] ?? '').length < 32) {
    failures.push(`${key} must be at least 32 characters`);
  }
}

for (const key of ['PUBLIC_APP_URL', 'API_PUBLIC_URL', 'CORS_ORIGIN']) {
  if (!(env[key] ?? '').startsWith('https://')) {
    failures.push(`${key} must use https://`);
  }
}

if (failures.length > 0) {
  console.error('[deploy-env] Production env is not ready:');
  for (const failure of failures) {
    console.error(`- ${failure}`);
  }
  process.exit(1);
}

console.log(`[deploy-env] ${envPath} looks deployable.`);
