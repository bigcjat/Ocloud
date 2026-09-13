const { execSync } = require('child_process');
const path = require('path');
const os = require('os');

function formatBytes(bytes) {
  const b = Number(bytes);
  if (isNaN(b) || b <= 0) return '0 B';
  const units = ['B', 'KB', 'MB', 'GB', 'TB', 'PB'];
  let val = b;
  for (const u of units) {
    if (val < 1024 || u === 'PB') return `${val.toFixed(1)} ${u}`;
    val /= 1024;
  }
  return `${b} B`;
}

function isDriveMounted(mountPoint) {
  try {
    const out = execSync('mount', { encoding: 'utf8' });
    return out.includes(mountPoint);
  } catch (e) {
    return false;
  }
}

function resolveMountPath(p) {
  if (!p) return path.join(os.homedir(), 'Cloud');
  if (p.startsWith('~/')) return path.join(os.homedir(), p.slice(2));
  if (p === '~') return os.homedir();
  return path.resolve(p);
}

function safeUnmount(mountPoint, timeoutMs = 8000) {
  const p = resolveMountPath(mountPoint);
  try {
    execSync(`fusermount3 -u "${p}" 2>/dev/null || fusermount -u "${p}" 2>/dev/null || umount "${p}" 2>/dev/null`, {
      timeout: timeoutMs,
      stdio: 'ignore'
    });
    return true;
  } catch (e) {
    try {
      execSync(`fusermount3 -u -z "${p}" 2>/dev/null || fusermount -u -z "${p}" 2>/dev/null || umount -l "${p}" 2>/dev/null`, {
        timeout: timeoutMs,
        stdio: 'ignore'
      });
      return true;
    } catch (err) {
      return false;
    }
  }
}

module.exports = {
  formatBytes,
  isDriveMounted,
  resolveMountPath,
  safeUnmount
};
