import * as fs from 'fs';
import * as path from 'path';
import * as https from 'https';
import { getCurriculumDir, getMentorHome } from './paths';

/**
 * Repo coordinates for fetching curriculum. v1 source-of-truth.
 *
 * Public repo — anyone with the extension installed can pull from here,
 * no auth required. If the repo is renamed or moved, bump these constants
 * and ship a new extension version.
 */
export const CURRICULUM_OWNER = 'jay-steenbergen';
export const CURRICULUM_REPO = 'MSSAMentorAgent';
export const CURRICULUM_BRANCH = 'master';

/** How often to re-download the manifest + files (ms). */
const REFRESH_INTERVAL_MS = 60 * 60 * 1000; // 1 hour

interface Manifest {
  version: string;
  generated: string;
  files: string[];
}

export interface FetchResult {
  fetched: number;
  failed: number;
  skipped: number;
  source: 'remote' | 'cache-only' | 'cache-fallback';
  errors: string[];
}

/**
 * Pluggable HTTP fetcher. Returns the response body as a string.
 * Throws on non-200 or network failure.
 */
export type Fetcher = (url: string) => Promise<string>;

/**
 * Default fetcher — wraps https.get with redirect support.
 */
export const httpsFetcher: Fetcher = (url: string) =>
  new Promise((resolve, reject) => {
    const req = https.get(url, { timeout: 10000 }, res => {
      if (
        res.statusCode &&
        res.statusCode >= 300 &&
        res.statusCode < 400 &&
        res.headers.location
      ) {
        resolve(httpsFetcher(res.headers.location));
        return;
      }
      if (res.statusCode !== 200) {
        reject(new Error(`HTTP ${res.statusCode} for ${url}`));
        return;
      }
      const chunks: Buffer[] = [];
      res.on('data', c => chunks.push(c));
      res.on('end', () => resolve(Buffer.concat(chunks).toString('utf8')));
      res.on('error', reject);
    });
    req.on('timeout', () => {
      req.destroy(new Error(`Timeout fetching ${url}`));
    });
    req.on('error', reject);
  });

function rawUrl(filePath: string): string {
  return `https://raw.githubusercontent.com/${CURRICULUM_OWNER}/${CURRICULUM_REPO}/${CURRICULUM_BRANCH}/${filePath}`;
}

function manifestUrl(): string {
  return rawUrl('.github/curriculum-manifest.json');
}

function lastFetchSentinelPath(): string {
  return path.join(getMentorHome(), '.last-fetch');
}

/**
 * Returns true if the curriculum should be re-fetched (no sentinel or
 * sentinel is older than REFRESH_INTERVAL_MS).
 */
export function isStale(now: number = Date.now()): boolean {
  const sentinel = lastFetchSentinelPath();
  if (!fs.existsSync(sentinel)) return true;
  try {
    const ts = parseInt(fs.readFileSync(sentinel, 'utf8').trim(), 10);
    if (isNaN(ts)) return true;
    return now - ts > REFRESH_INTERVAL_MS;
  } catch {
    return true;
  }
}

function writeSentinel(now: number = Date.now()): void {
  fs.writeFileSync(lastFetchSentinelPath(), String(now), 'utf8');
}

/**
 * Returns true if the curriculum cache has at least the manifest plus
 * one file — enough to call it a usable cache.
 */
export function hasUsableCache(): boolean {
  const dir = getCurriculumDir();
  if (!fs.existsSync(dir)) return false;
  const manifestPath = path.join(dir, '.github/curriculum-manifest.json');
  if (!fs.existsSync(manifestPath)) return false;
  try {
    const m = JSON.parse(fs.readFileSync(manifestPath, 'utf8')) as Manifest;
    if (!m.files || m.files.length === 0) return false;
    // Spot-check: first non-manifest file exists.
    const sample = m.files.find(f => !f.endsWith('curriculum-manifest.json'));
    if (!sample) return true;
    return fs.existsSync(path.join(dir, sample));
  } catch {
    return false;
  }
}

/**
 * Fetch (or refresh) the curriculum into ~/.mssa-mentor/curriculum/.
 *
 * Behavior:
 *   - If `force` is false and last fetch was within REFRESH_INTERVAL_MS,
 *     returns immediately with source='cache-only'.
 *   - Otherwise fetches the manifest and every file it lists.
 *   - On manifest fetch failure with no usable cache → throws.
 *   - On manifest fetch failure WITH usable cache → returns
 *     source='cache-fallback' and logs the error.
 *   - Per-file fetch failures are counted in `failed` but don't abort.
 *
 * Caller can inject a custom `fetcher` for testing.
 */
export async function fetchCurriculum(
  opts: { fetcher?: Fetcher; force?: boolean; now?: number } = {}
): Promise<FetchResult> {
  const fetcher = opts.fetcher ?? httpsFetcher;
  const now = opts.now ?? Date.now();
  const dir = getCurriculumDir();
  fs.mkdirSync(dir, { recursive: true });

  if (!opts.force && !isStale(now) && hasUsableCache()) {
    return { fetched: 0, failed: 0, skipped: 0, source: 'cache-only', errors: [] };
  }

  let manifestText: string;
  try {
    manifestText = await fetcher(manifestUrl());
  } catch (err) {
    const msg = err instanceof Error ? err.message : String(err);
    if (hasUsableCache()) {
      return {
        fetched: 0,
        failed: 0,
        skipped: 0,
        source: 'cache-fallback',
        errors: [`manifest fetch failed: ${msg}`]
      };
    }
    throw new Error(
      `Failed to fetch curriculum manifest and no cache available: ${msg}`
    );
  }

  let manifest: Manifest;
  try {
    manifest = JSON.parse(manifestText) as Manifest;
  } catch (err) {
    throw new Error(
      `Invalid manifest JSON: ${err instanceof Error ? err.message : String(err)}`
    );
  }

  // Save manifest first so hasUsableCache() reflects this run.
  const manifestPath = path.join(dir, '.github/curriculum-manifest.json');
  fs.mkdirSync(path.dirname(manifestPath), { recursive: true });
  fs.writeFileSync(manifestPath, manifestText, 'utf8');

  const result: FetchResult = {
    fetched: 0,
    failed: 0,
    skipped: 0,
    source: 'remote',
    errors: []
  };

  for (const rel of manifest.files) {
    const target = path.join(dir, rel);
    try {
      const body = await fetcher(rawUrl(rel));
      fs.mkdirSync(path.dirname(target), { recursive: true });
      fs.writeFileSync(target, body, 'utf8');
      result.fetched++;
    } catch (err) {
      const msg = err instanceof Error ? err.message : String(err);
      result.failed++;
      result.errors.push(`${rel}: ${msg}`);
    }
  }

  writeSentinel(now);
  return result;
}
