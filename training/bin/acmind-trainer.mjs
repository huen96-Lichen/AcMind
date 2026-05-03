#!/usr/bin/env node

import fs from 'node:fs/promises';
import path from 'node:path';
import crypto from 'node:crypto';

function usage(message) {
  if (message) {
    console.error(`error: ${message}`);
  }
  console.error(`
acmind-trainer

Usage:
  acmind-trainer snapshot validate <manifest>
  acmind-trainer train sft <manifest> --base-model <model>
  acmind-trainer eval <run-or-artifact> <eval-manifest>
  acmind-trainer package ollama <artifact>
`);
  process.exit(message ? 1 : 0);
}

function parseArgs(argv) {
  const args = [...argv];
  const flags = {};
  const positional = [];
  while (args.length > 0) {
    const value = args.shift();
    if (!value) continue;
    if (value.startsWith('--')) {
      const key = value.slice(2);
      const next = args[0];
      if (next && !next.startsWith('--')) {
        flags[key] = args.shift();
      } else {
        flags[key] = true;
      }
      continue;
    }
    positional.push(value);
  }
  return { positional, flags };
}

async function fileExists(filePath) {
  try {
    await fs.access(filePath);
    return true;
  } catch {
    return false;
  }
}

async function resolveManifestLocation(input) {
  const stat = await fs.stat(input).catch(() => null);
  if (!stat) {
    throw new Error(`manifest path not found: ${input}`);
  }
  if (stat.isDirectory()) {
    return path.join(input, 'manifest.json');
  }
  return input;
}

async function loadJson(filePath) {
  const text = await fs.readFile(filePath, 'utf8');
  return JSON.parse(text);
}

function validateSnapshotManifest(manifest, manifestPath) {
  const requiredStringFields = ['id', 'name', 'status'];
  for (const field of requiredStringFields) {
    if (typeof manifest[field] !== 'string' || !manifest[field].trim()) {
      throw new Error(`invalid manifest: missing string field "${field}"`);
    }
  }
  if (typeof manifest.createdAt !== 'number') {
    throw new Error('invalid manifest: createdAt must be a number');
  }
  if (!manifest.counts || typeof manifest.counts !== 'object') {
    throw new Error('invalid manifest: counts must be present');
  }
  for (const key of ['total', 'train', 'eval']) {
    if (typeof manifest.counts[key] !== 'number') {
      throw new Error(`invalid manifest: counts.${key} must be a number`);
    }
  }
  if (!manifest.splitConfig || typeof manifest.splitConfig !== 'object') {
    throw new Error('invalid manifest: splitConfig must be present');
  }

  const snapshotDir = path.dirname(manifestPath);
  const trainPath = path.join(snapshotDir, 'train.jsonl');
  const evalPath = path.join(snapshotDir, 'eval.jsonl');

  return { snapshotDir, trainPath, evalPath };
}

async function validateJsonl(filePath) {
  if (!(await fileExists(filePath))) {
    throw new Error(`missing file: ${filePath}`);
  }
  const text = await fs.readFile(filePath, 'utf8');
  const lines = text.split(/\r?\n/).filter(Boolean);
  for (const [index, line] of lines.entries()) {
    try {
      JSON.parse(line);
    } catch (error) {
      throw new Error(`invalid JSONL at ${path.basename(filePath)}:${index + 1}: ${error instanceof Error ? error.message : String(error)}`);
    }
  }
  return lines.length;
}

async function snapshotValidate(manifestInput) {
  const manifestPath = await resolveManifestLocation(manifestInput);
  const manifest = await loadJson(manifestPath);
  const { snapshotDir, trainPath, evalPath } = validateSnapshotManifest(manifest, manifestPath);
  const trainCount = await validateJsonl(trainPath);
  const evalCount = await validateJsonl(evalPath);
  return {
    ok: true,
    manifestPath,
    snapshotDir,
    counts: {
      manifest: manifest.counts,
      trainLines: trainCount,
      evalLines: evalCount,
    },
  };
}

function slugify(value) {
  return String(value)
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '')
    .slice(0, 48) || 'snapshot';
}

async function ensureDir(dirPath) {
  await fs.mkdir(dirPath, { recursive: true });
}

async function trainSft(manifestInput, baseModel) {
  if (!baseModel || typeof baseModel !== 'string') {
    throw new Error('missing required flag: --base-model <model>');
  }
  const manifestPath = await resolveManifestLocation(manifestInput);
  const manifest = await loadJson(manifestPath);
  const validation = validateSnapshotManifest(manifest, manifestPath);
  const snapshotDir = validation.snapshotDir;
  const runId = crypto.randomUUID();
  const runSlug = `${new Date().toISOString().slice(0, 19).replace(/[:T]/g, '-')}-${slugify(manifest.name)}`;
  const runDir = path.join(snapshotDir, '..', 'runs', runSlug);
  await ensureDir(runDir);

  const trainCount = await validateJsonl(validation.trainPath);
  const evalCount = await validateJsonl(validation.evalPath);
  const startedAt = Math.floor(Date.now() / 1000);
  const finishedAt = startedAt + 1;

  const run = {
    id: runId,
    snapshotId: manifest.id,
    baseModel,
    status: 'done',
    manifestPath,
    artifactPath: path.join(runDir, 'artifact.json'),
    metrics: {
      mode: 'stub',
      trainSamples: trainCount,
      evalSamples: evalCount,
      baseModel,
    },
    createdAt: startedAt,
    finishedAt,
  };

  const artifact = {
    id: crypto.randomUUID(),
    runId,
    snapshotId: manifest.id,
    baseModel,
    status: 'stub',
    createdAt: startedAt,
    files: {
      modelfile: path.join(runDir, 'Modelfile'),
    },
  };

  const modelfile = [
    `FROM ${baseModel}`,
    `# AcMind trainer stub`,
    `# snapshot: ${manifest.id}`,
    `# samples: train=${trainCount} eval=${evalCount}`,
  ].join('\n') + '\n';

  await fs.writeFile(path.join(runDir, 'run.json'), JSON.stringify(run, null, 2), 'utf8');
  await fs.writeFile(path.join(runDir, 'metrics.json'), JSON.stringify(run.metrics, null, 2), 'utf8');
  await fs.writeFile(path.join(runDir, 'artifact.json'), JSON.stringify(artifact, null, 2), 'utf8');
  await fs.writeFile(path.join(runDir, 'Modelfile'), modelfile, 'utf8');

  return { ok: true, runDir, run, artifact };
}

async function evalRun(targetInput, evalManifestInput) {
  const targetPath = path.resolve(targetInput);
  const evalManifestPath = await resolveManifestLocation(evalManifestInput);
  const evalManifest = await loadJson(evalManifestPath);
  const { snapshotDir } = validateSnapshotManifest(evalManifest, evalManifestPath);
  const trainCount = await validateJsonl(path.join(snapshotDir, 'train.jsonl'));
  const evalCount = await validateJsonl(path.join(snapshotDir, 'eval.jsonl'));
  const metrics = {
    mode: 'stub',
    target: targetPath,
    evalSamples: evalCount,
    trainSamples: trainCount,
    score: Math.max(0, 1 - Math.abs(trainCount - evalCount) / Math.max(1, trainCount + evalCount)),
  };
  return { ok: true, metrics };
}

async function packageOllama(artifactInput) {
  const artifactPath = path.resolve(artifactInput);
  const artifact = await loadJson(artifactPath);
  const outputDir = path.join(path.dirname(artifactPath), 'ollama');
  await ensureDir(outputDir);
  const modelfilePath = path.join(outputDir, 'Modelfile');
  const modelfile = [
    `FROM ${artifact.baseModel ?? 'unknown-base-model'}`,
    `# Packaged from ${path.basename(artifactPath)}`,
    `# runId: ${artifact.runId ?? artifact.id ?? 'unknown'}`,
  ].join('\n') + '\n';
  await fs.writeFile(modelfilePath, modelfile, 'utf8');
  const packageManifest = {
    id: crypto.randomUUID(),
    artifactPath,
    modelfilePath,
    provider: 'ollama',
    status: 'candidate',
    createdAt: Math.floor(Date.now() / 1000),
  };
  await fs.writeFile(path.join(outputDir, 'artifact.package.json'), JSON.stringify(packageManifest, null, 2), 'utf8');
  return { ok: true, outputDir, modelfilePath };
}

async function main() {
  const { positional, flags } = parseArgs(process.argv.slice(2));
  if (positional.length === 0) {
    usage();
  }

  const [group, command, ...rest] = positional;
  try {
    if (group === 'snapshot' && command === 'validate') {
      const manifest = rest[0];
      if (!manifest) usage('missing manifest path');
      const result = await snapshotValidate(manifest);
      console.log(JSON.stringify(result, null, 2));
      return;
    }

    if (group === 'train' && command === 'sft') {
      const manifest = rest[0];
      if (!manifest) usage('missing manifest path');
      const result = await trainSft(manifest, flags['base-model']);
      console.log(JSON.stringify(result, null, 2));
      return;
    }

    if (group === 'eval') {
      const target = command;
      const evalManifest = rest[0];
      if (!target || !evalManifest) usage('missing target or eval manifest path');
      const result = await evalRun(target, evalManifest);
      console.log(JSON.stringify(result, null, 2));
      return;
    }

    if (group === 'package' && command === 'ollama') {
      const artifact = rest[0];
      if (!artifact) usage('missing artifact path');
      const result = await packageOllama(artifact);
      console.log(JSON.stringify(result, null, 2));
      return;
    }

    usage(`unknown command: ${[group, command].filter(Boolean).join(' ')}`);
  } catch (error) {
    console.error(error instanceof Error ? error.message : String(error));
    process.exit(1);
  }
}

await main();
