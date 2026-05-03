#!/usr/bin/env node
/**
 * Ensures node_modules/esbuild/bin/esbuild is the correct native binary
 * for the current platform. Handles the case where package-lock.json was
 * generated on a different OS (e.g. macOS) but the project is built on
 * Linux or vice versa.
 *
 * Key detail: npm may hard-link esbuild/bin/esbuild to the platform-specific
 * package binary. We must unlink the target before copying to break the
 * hard link and avoid corrupting the source.
 *
 * Usage: node scripts/fix-esbuild-binary.mjs
 * Called automatically by `npm run build` and `npm run dev`.
 */

import { existsSync, copyFileSync, chmodSync, unlinkSync, statSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const root = join(__dirname, '..');

const platform = process.platform;   // 'linux', 'darwin', 'win32'
const arch = process.arch;           // 'arm64', 'x64', …

// Map Node platform/arch to esbuild package name
const pkgMap = {
  'linux-arm64':  '@esbuild/linux-arm64',
  'linux-x64':    '@esbuild/linux-x64',
  'linux-arm':    '@esbuild/linux-arm',
  'linux-ia32':   '@esbuild/linux-ia32',
  'darwin-arm64': '@esbuild/darwin-arm64',
  'darwin-x64':   '@esbuild/darwin-x64',
  'win32-arm64':  '@esbuild/win32-arm64',
  'win32-x64':    '@esbuild/win32-x64',
  'win32-ia32':   '@esbuild/win32-ia32',
};

const key = `${platform}-${arch}`;
const pkg = pkgMap[key];

if (!pkg) {
  // Unknown platform — skip silently, let esbuild handle it
  process.exit(0);
}

const targetBin = join(root, 'node_modules', 'esbuild', 'bin', 'esbuild');
const sourceBin = join(root, 'node_modules', pkg, 'bin', 'esbuild');

if (!existsSync(sourceBin)) {
  // Platform package not installed — skip, let esbuild handle it
  process.exit(0);
}

// Check if current binary works
let currentWorks = false;
try {
  execFileSync(targetBin, ['--version'], { stdio: 'pipe' });
  currentWorks = true;
} catch {
  currentWorks = false;
}

if (currentWorks) {
  // Already working — nothing to do
  process.exit(0);
}

// Current binary is broken — replace it.
// IMPORTANT: unlink the target first to break any hard links, so we don't
// corrupt the source binary when writing to the target path.
try {
  if (existsSync(targetBin)) {
    unlinkSync(targetBin);
  }
  copyFileSync(sourceBin, targetBin);
  chmodSync(targetBin, 0o755);
  // Verify the fix
  execFileSync(targetBin, ['--version'], { stdio: 'pipe' });
  console.log(`[fix-esbuild-binary] Replaced with ${pkg} binary for ${key}`);
} catch (err) {
  console.error(`[fix-esbuild-binary] Failed to fix esbuild binary: ${err.message}`);
  process.exit(1);
}
