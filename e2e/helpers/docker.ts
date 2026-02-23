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
  parts.push(service, 'bash', '-c', JSON.stringify(command));

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
