import { existsSync, unlinkSync } from 'fs';
import { resolve } from 'path';

const LOCKFILE = resolve(__dirname, '..', '.playwright-lock');

export default async function globalTeardown() {
  try {
    if (existsSync(LOCKFILE)) unlinkSync(LOCKFILE);
  } catch {}
}
