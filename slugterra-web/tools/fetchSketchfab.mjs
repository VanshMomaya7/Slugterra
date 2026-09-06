#!/usr/bin/env node
/**
 * Fetches the Slugterra models from Sketchfab and prepares them for the build.
 *
 *   SKETCHFAB_TOKEN=xxxx npm run assets
 *
 * For each model the manifest needs:
 *   1. ask Sketchfab for a (short-lived) download URL
 *   2. download and unzip the glTF bundle
 *   3. simplify it down to its triangle budget
 *   4. write a single packed `.glb` into `public/assets/sketchfab/`
 *
 * Step 3 is not optional. Every one of these models is far over budget as
 * uploaded — `slug hop rock` is 500k triangles against a 600k *whole scene*
 * ceiling (TDD v2.0 §7). Shipping them raw would blow the frame budget and the
 * 15 MB first-load budget several times over.
 *
 * The token is a personal API token from https://sketchfab.com/settings/password
 * It is read from the environment or `.env.local`, and never written to disk by
 * this script.
 */

import { createWriteStream } from 'node:fs';
import { mkdir, readFile, rm, writeFile, readdir, stat } from 'node:fs/promises';
import { existsSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { Readable } from 'node:stream';
import { pipeline } from 'node:stream/promises';

import AdmZip from 'adm-zip';
import { NodeIO } from '@gltf-transform/core';
import { ALL_EXTENSIONS } from '@gltf-transform/extensions';
import { dedup, prune, weld, simplify, resample } from '@gltf-transform/functions';
import { MeshoptSimplifier } from 'meshoptimizer';

const HERE = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(HERE, '..');
const OUT_DIR = path.join(ROOT, 'public', 'assets', 'sketchfab');
const TMP_DIR = path.join(ROOT, '.asset-cache');
const API = 'https://api.sketchfab.com/v3';

/**
 * Mirrors `src/assets/sketchfabCatalog.ts`. Kept as a plain object here so the
 * tool runs under plain Node with no TypeScript build step.
 */
const MODELS = {
  eliShane: { uid: 'f273b2800f644db4832093eb6336429f', name: 'eli_shane', budget: 8000 },
  burpy: { uid: '8c27c713fe51439dbe8c52cce241b245', name: 'Burpy', budget: 6000 },
  frostslug: { uid: '63cddf71f8274228828bff526a9e06b3', name: 'frostslug', budget: 1500 },
  frostcrawlerVelocimorph: {
    uid: '14835264d2b443bab0533e58d4515e5d',
    name: 'FROSTCRAWLER_ Velocimorph',
    budget: 6000,
  },
  hopRock: { uid: '50ad1ebbd50948eab9d0f22dfff5312e', name: 'slug hop rock', budget: 1500 },
  slugShell: { uid: '4c73eda559c243a894cf419466eb2e3a', name: 'Slug Shell', budget: 1500 },
  blasterRenegade: {
    uid: '1573da9e38a14029a41aa838e6155924',
    name: 'RENEGADE ULTRA QLC Blaster',
    budget: 2500,
  },
};

async function readToken() {
  if (process.env.SKETCHFAB_TOKEN) return process.env.SKETCHFAB_TOKEN.trim();

  const envFile = path.join(ROOT, '.env.local');
  if (existsSync(envFile)) {
    const text = await readFile(envFile, 'utf8');
    const match = text.match(/^\s*SKETCHFAB_TOKEN\s*=\s*(.+)\s*$/m);
    if (match) return match[1].trim().replace(/^["']|["']$/g, '');
  }
  return null;
}

async function requestDownloadUrl(uid, token) {
  const response = await fetch(`${API}/models/${uid}/download`, {
    headers: { Authorization: `Token ${token}` },
  });

  if (response.status === 401) {
    throw new Error('Sketchfab rejected the token (401). Check SKETCHFAB_TOKEN.');
  }
  if (response.status === 403) {
    throw new Error(`Not permitted to download ${uid} (403).`);
  }
  if (response.status === 404) {
    throw new Error(`Model ${uid} not found or no longer downloadable (404).`);
  }
  if (!response.ok) {
    throw new Error(`Sketchfab returned ${response.status} for ${uid}.`);
  }

  const body = await response.json();
  const target = body.gltf ?? body.glb;
  if (!target?.url) throw new Error(`No glTF archive offered for ${uid}.`);
  return target.url;
}

async function downloadTo(url, filePath) {
  const response = await fetch(url);
  if (!response.ok || !response.body) {
    throw new Error(`Download failed with ${response.status}.`);
  }
  await pipeline(Readable.fromWeb(response.body), createWriteStream(filePath));
}

async function findSceneFile(dir) {
  const candidates = [];
  async function walk(current) {
    for (const entry of await readdir(current, { withFileTypes: true })) {
      const full = path.join(current, entry.name);
      if (entry.isDirectory()) await walk(full);
      else if (/\.(gltf|glb)$/i.test(entry.name)) candidates.push(full);
    }
  }
  await walk(dir);
  if (candidates.length === 0) throw new Error('No .gltf/.glb inside the archive.');
  // Prefer a packed .glb, else the shallowest .gltf.
  candidates.sort((a, b) => {
    const glb = Number(b.toLowerCase().endsWith('.glb')) - Number(a.toLowerCase().endsWith('.glb'));
    return glb !== 0 ? glb : a.split(path.sep).length - b.split(path.sep).length;
  });
  return candidates[0];
}

function countTriangles(document) {
  let total = 0;
  for (const mesh of document.getRoot().listMeshes()) {
    for (const primitive of mesh.listPrimitives()) {
      const indices = primitive.getIndices();
      const position = primitive.getAttribute('POSITION');
      if (indices) total += indices.getCount() / 3;
      else if (position) total += position.getCount() / 3;
    }
  }
  return Math.round(total);
}

async function processModel(key, model, token) {
  const workDir = path.join(TMP_DIR, key);
  await rm(workDir, { recursive: true, force: true });
  await mkdir(workDir, { recursive: true });

  process.stdout.write(`  ${key.padEnd(24)} `);

  const url = await requestDownloadUrl(model.uid, token);
  const zipPath = path.join(workDir, 'model.zip');
  await downloadTo(url, zipPath);

  new AdmZip(zipPath).extractAllTo(workDir, true);
  const scenePath = await findSceneFile(workDir);

  await MeshoptSimplifier.ready;
  const io = new NodeIO().registerExtensions(ALL_EXTENSIONS);
  const document = await io.read(scenePath);

  const before = countTriangles(document);
  const ratio = before > 0 ? Math.min(1, model.budget / before) : 1;

  const transforms = [dedup(), prune(), resample()];
  if (ratio < 1) {
    // `weld` first: simplification needs shared vertices to collapse edges, and
    // Sketchfab exports are frequently fully unwelded.
    transforms.push(weld(), simplify({ simplifier: MeshoptSimplifier, ratio, error: 0.01 }));
  }
  await document.transform(...transforms);

  const after = countTriangles(document);
  await mkdir(OUT_DIR, { recursive: true });
  const outPath = path.join(OUT_DIR, `${key}.glb`);
  await io.write(outPath, document);

  const { size } = await stat(outPath);
  const kb = Math.round(size / 1024);
  const verdict = after <= model.budget * 1.1 ? 'ok' : 'OVER BUDGET';
  console.log(
    `${before.toLocaleString()} -> ${after.toLocaleString()} tris ` +
      `(budget ${model.budget.toLocaleString()}), ${kb} kB  ${verdict}`,
  );

  await rm(workDir, { recursive: true, force: true });
  return { key, before, after, bytes: size };
}

async function main() {
  const token = await readToken();
  if (!token) {
    console.error(
      [
        '',
        'No Sketchfab API token found.',
        '',
        'Downloading models needs one — the endpoint returns 401 without it.',
        '',
        '  1. open https://sketchfab.com/settings/password  (log in)',
        '  2. copy the "API Token" value',
        '  3. either:',
        '       set SKETCHFAB_TOKEN=<token>   (this shell only)',
        '     or write it into slugterra-web/.env.local:',
        '       SKETCHFAB_TOKEN=<token>',
        '  4. re-run:  npm run assets',
        '',
        'Until then the game runs on greybox primitives, which is a working',
        'build - just not the real models.',
        '',
      ].join('\n'),
    );
    process.exitCode = 1;
    return;
  }

  console.log(`Fetching ${Object.keys(MODELS).length} models from Sketchfab\n`);
  await mkdir(TMP_DIR, { recursive: true });

  const results = [];
  const failures = [];
  for (const [key, model] of Object.entries(MODELS)) {
    try {
      results.push(await processModel(key, model, token));
    } catch (error) {
      failures.push({ key, message: error.message });
      console.log(`FAILED - ${error.message}`);
    }
  }

  await rm(TMP_DIR, { recursive: true, force: true });

  const tris = results.reduce((sum, r) => sum + r.after, 0);
  const bytes = results.reduce((sum, r) => sum + r.bytes, 0);
  console.log(
    `\n${results.length} model(s) written to public/assets/sketchfab/` +
      `\ntotal ${tris.toLocaleString()} tris, ${(bytes / 1024 / 1024).toFixed(2)} MB`,
  );
  if (tris > 600_000) console.warn('WARNING: over the 600k visible-triangle budget.');
  if (bytes > 15 * 1024 * 1024) console.warn('WARNING: over the 15 MB first-load budget.');

  if (failures.length > 0) {
    console.error(`\n${failures.length} model(s) failed:`);
    for (const failure of failures) console.error(`  ${failure.key}: ${failure.message}`);
    process.exitCode = 1;
  }

  await writeFile(
    path.join(OUT_DIR, 'CREDITS.txt'),
    [
      'Models fetched from Sketchfab (https://sketchfab.com/tags/slugterra).',
      'All licensed CC Attribution - credit is required wherever they are shown.',
      '',
      'Burpy - Zhi Ying - https://sketchfab.com/zhiying-loo',
      'eli_shane - nayzen - https://sketchfab.com/tahasouhail2324',
      'FROSTCRAWLER_ Velocimorph - nayzen - https://sketchfab.com/tahasouhail2324',
      'slug hop rock - nayzen - https://sketchfab.com/tahasouhail2324',
      'frostslug - mullm - https://sketchfab.com/simonmull7',
      'Slug Shell - Starkster - https://sketchfab.com/parmaryash2599',
      'RENEGADE ULTRA QLC Blaster - Starkster - https://sketchfab.com/parmaryash2599',
      '',
      'These are fan-made models of WildBrain IP. The CC-BY grant covers each',
      "uploader's own work, not the underlying character rights.",
      '',
    ].join('\n'),
    'utf8',
  );
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
