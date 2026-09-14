const fs = require('fs');
const path = require('path');
const os = require('os');
const { spawnSync } = require('child_process');
const { resolveMountPath } = require('./format');
const { isFleaDefault, findBinary } = require('./file_manager');

function getFleaStateFile() {
  return path.join(os.homedir(), '.local', 'state', 'flea', 'ui.json');
}

function readFleaFavourites() {
  const statePath = getFleaStateFile();
  if (!fs.existsSync(statePath)) return [];
  try {
    const data = JSON.parse(fs.readFileSync(statePath, 'utf8'));
    return (data.places && Array.isArray(data.places.favourites)) ? data.places.favourites : [];
  } catch (e) {
    return [];
  }
}

function formatLabel(name, targetPath) {
  if (!name) return path.basename(targetPath);
  const lower = name.toLowerCase();
  if (lower === 'mega') return 'MEGA';
  if (lower === 'koofr') return 'Koofr';
  if (lower === 'onedrive') return 'OneDrive';
  if (lower === 'dropbox') return 'Dropbox';
  if (lower === 'googledrive' || lower === 'google-drive') return 'Google Drive';
  if (lower === 'storagebox' || lower === 'hetzner_storage_box') return 'Hetzner Storage Box';
  if (lower === 'pcloud') return 'pCloud';
  if (lower === 'protondrive' || lower === 'proton-drive') return 'Proton Drive';
  return name.charAt(0).toUpperCase() + name.slice(1);
}

function addFleaBookmark(label, mountPath) {
  const resolved = resolveMountPath(mountPath);
  const fleaBin = findBinary('flea');
  const favs = readFleaFavourites();

  // If already present, don't duplicate
  if (favs.some(f => f && resolveMountPath(f.path) === resolved)) {
    return true;
  }

  const cleanLabel = formatLabel(label, resolved);
  const payload = JSON.stringify({
    op: 'add',
    record: {
      label: cleanLabel,
      path: resolved
    }
  });

  try {
    const env = Object.assign({}, process.env);
    const localBin = path.join(os.homedir(), '.local', 'bin');
    if (!env.PATH || !env.PATH.includes(localBin)) {
      env.PATH = `${localBin}:${env.PATH || ''}`;
    }
    const res = spawnSync(fleaBin, ['--favourites', payload], {
      env,
      encoding: 'utf8',
      timeout: 3000
    });
    return res.status === 0;
  } catch (e) {
    return false;
  }
}

function removeFleaBookmark(mountPath) {
  const resolved = resolveMountPath(mountPath);
  const fleaBin = findBinary('flea');
  const favs = readFleaFavourites();

  const idx = favs.findIndex(f => f && resolveMountPath(f.path) === resolved);
  if (idx < 0) return true; // Already not present

  const payload = JSON.stringify({
    op: 'remove',
    index: idx
  });

  try {
    const env = Object.assign({}, process.env);
    const localBin = path.join(os.homedir(), '.local', 'bin');
    if (!env.PATH || !env.PATH.includes(localBin)) {
      env.PATH = `${localBin}:${env.PATH || ''}`;
    }
    const res = spawnSync(fleaBin, ['--favourites', payload], {
      env,
      encoding: 'utf8',
      timeout: 3000
    });
    return res.status === 0;
  } catch (e) {
    return false;
  }
}

function syncStorageBookmark(label, mountPath, action = 'add') {
  if (!isFleaDefault()) {
    return;
  }

  if (action === 'add') {
    addFleaBookmark(label, mountPath);
  } else if (action === 'remove') {
    removeFleaBookmark(mountPath);
  }
}

module.exports = {
  getFleaStateFile,
  readFleaFavourites,
  addFleaBookmark,
  removeFleaBookmark,
  syncStorageBookmark
};
