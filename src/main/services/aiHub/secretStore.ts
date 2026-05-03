import { execFile } from 'node:child_process';
import { promisify } from 'node:util';

const execFileAsync = promisify(execFile);

// Canonical app identity — aligned with package.json build.appId
const SERVICE_PREFIX = 'com.acore.acmind';
/** @deprecated Legacy Keychain prefix used before identity unification */
const LEGACY_SERVICE_PREFIX = 'com.acmind.ai';

function buildServiceName(provider: string): string {
  return `${SERVICE_PREFIX}.${provider.toLowerCase()}`;
}

function buildLegacyServiceName(provider: string): string {
  return `${LEGACY_SERVICE_PREFIX}.${provider.toLowerCase()}`;
}

async function runSecurity(args: string[]): Promise<{ stdout: string; stderr: string }> {
  const result = await execFileAsync('security', args, {
    timeout: 8000,
    maxBuffer: 1024 * 1024
  });
  return {
    stdout: result.stdout ?? '',
    stderr: result.stderr ?? ''
  };
}

function isNotFoundError(error: unknown): boolean {
  const message = error instanceof Error ? error.message : String(error ?? '');
  return message.includes('could not be found') || message.includes('The specified item could not be found');
}

export async function loadCloudApiKey(provider: string): Promise<string | null> {
  const service = buildServiceName(provider);
  try {
    const { stdout } = await runSecurity(['find-generic-password', '-s', service, '-a', 'apiKey', '-w']);
    const value = stdout.trim();
    return value ? value : null;
  } catch (error) {
    if (!isNotFoundError(error)) {
      throw error;
    }
    // Migration: try legacy prefix, migrate to new prefix if found
    const legacyService = buildLegacyServiceName(provider);
    try {
      const { stdout } = await runSecurity(['find-generic-password', '-s', legacyService, '-a', 'apiKey', '-w']);
      const value = stdout.trim();
      if (value) {
        // Migrate: write under new prefix (don't delete old — user can clean up manually)
        try {
          await saveCloudApiKey(provider, value);
        } catch {
          // Ignore migration write failure — value is still readable from legacy
        }
        return value;
      }
    } catch {
      // Legacy key not found either
    }
    return null;
  }
}

export async function saveCloudApiKey(provider: string, apiKey: string): Promise<void> {
  const service = buildServiceName(provider);
  const value = apiKey.trim();
  if (!value) {
    await deleteCloudApiKey(provider);
    return;
  }

  await runSecurity([
    'add-generic-password',
    '-U',
    '-s',
    service,
    '-a',
    'apiKey',
    '-w',
    value
  ]);
}

export async function deleteCloudApiKey(provider: string): Promise<void> {
  const service = buildServiceName(provider);
  try {
    await runSecurity(['delete-generic-password', '-s', service, '-a', 'apiKey']);
  } catch (error) {
    if (!isNotFoundError(error)) {
      throw error;
    }
  }
}
