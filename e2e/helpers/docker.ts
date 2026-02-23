import { execSync } from 'child_process';
import { resolve } from 'path';

const REPO_ROOT = resolve(__dirname, '..', '..');

export interface DockerExecOptions {
  /** Working directory inside the container */
  workdir?: string;
  /** Timeout in milliseconds (default: 30_000) */
  timeout?: number;
  /** Suppress errors and return empty string on failure */
  ignoreError?: boolean;
}

/**
 * Run a command inside a Docker Compose service container.
 */
export function dockerExec(
  service: string,
  command: string,
  opts: DockerExecOptions = {},
): string {
  const { workdir, timeout = 30_000, ignoreError = false } = opts;
  const parts = ['docker', 'compose', 'exec', '-T'];
  if (workdir) {
    parts.push('-w', workdir);
  }
  // Single-quote the command so $ and other special characters are passed
  // literally to the container's shell (no host-side expansion).
  const escaped = command.replace(/'/g, "'\\''");
  parts.push(service, 'bash', '-c', `'${escaped}'`);

  try {
    return execSync(parts.join(' '), {
      cwd: REPO_ROOT,
      timeout,
      encoding: 'utf-8',
      stdio: ['pipe', 'pipe', 'pipe'],
    }).trim();
  } catch (err) {
    if (ignoreError) return '';
    throw err;
  }
}
