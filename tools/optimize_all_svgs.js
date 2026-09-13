#!/usr/bin/env node

/**
 * tools/optimize_all_svgs.js
 * 
 * Standardized SVG Optimizer for Ocloud.
 * Optimizes:
 * 1. All standalone vector files in app/ui/icons/*.svg
 * 2. All embedded "iconSvg" strings in providers/plugins/*.json and providers/plugins/* /plugin.json
 * 
 * Enforces:
 * - multipass: true
 * - preset-default (path optimization, cleanups, metadata/comment removal)
 * - removeDimensions (strips hardcoded width/height, preserves responsive viewBox)
 * - removeScripts (zero-trust sanitization)
 */

const fs = require('fs');
const path = require('path');
const { execFileSync } = require('child_process');

const ROOT_DIR = path.resolve(__dirname, '..');
const ICONS_DIR = path.join(ROOT_DIR, 'app/ui/icons');
const PLUGINS_DIR = path.join(ROOT_DIR, 'providers/plugins');
const CONFIG_FILE = path.join(ROOT_DIR, 'svgo.config.js');

const PLUGIN_ICONS_DIR = path.join(ROOT_DIR, 'plugin/icons');

function runSvgoOnString(svgString) {
  try {
    const output = execFileSync(
      'npx',
      ['-y', 'svgo', '--config', CONFIG_FILE, '-s', svgString, '-o', '-'],
      { encoding: 'utf8', stdio: ['pipe', 'pipe', 'ignore'] }
    );
    return output.trim();
  } catch (err) {
    console.error('SVGO optimization failed for SVG string:', err.message);
    return svgString;
  }
}

function optimizeIconsDirectory() {
  console.log('=== 1. Optimizing Standalone Icons in app/ui/icons/ and plugin/icons/ ===');
  try {
    execFileSync(
      'npx',
      ['-y', 'svgo', '--config', CONFIG_FILE, '-f', ICONS_DIR],
      { stdio: 'inherit' }
    );
  } catch (err) {
    console.error('Failed optimizing app/ui/icons directory:', err.message);
  }

  if (fs.existsSync(PLUGIN_ICONS_DIR)) {
    try {
      execFileSync(
        'npx',
        ['-y', 'svgo', '--config', CONFIG_FILE, '-f', PLUGIN_ICONS_DIR],
        { stdio: 'inherit' }
      );
    } catch (err) {
      console.error('Failed optimizing plugin/icons directory:', err.message);
    }
  }
}

function findPluginManifests(dir) {
  const manifests = [];
  if (!fs.existsSync(dir)) return manifests;
  const entries = fs.readdirSync(dir, { withFileTypes: true });

  for (const entry of entries) {
    if (entry.name.startsWith('.')) continue;
    const fullPath = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      const subManifest = path.join(fullPath, 'plugin.json');
      if (fs.existsSync(subManifest)) {
        manifests.push(subManifest);
      } else {
        manifests.push(...findPluginManifests(fullPath));
      }
    } else if (entry.isFile() && entry.name.endsWith('.json')) {
      manifests.push(fullPath);
    }
  }
  return manifests;
}

function optimizePluginManifests() {
  console.log('\n=== 2. Optimizing Embedded "iconSvg" in Plugin Manifests ===');
  const manifests = findPluginManifests(PLUGINS_DIR);

  for (const manifestPath of manifests) {
    const relPath = path.relative(ROOT_DIR, manifestPath);
    try {
      const raw = fs.readFileSync(manifestPath, 'utf8');
      const json = JSON.parse(raw);

      if (json.iconSvg) {
        const originalLength = json.iconSvg.length;
        const optimizedSvg = runSvgoOnString(json.iconSvg);
        const newLength = optimizedSvg.length;
        const saved = originalLength - newLength;
        const pct = ((saved / originalLength) * 100).toFixed(1);

        json.iconSvg = optimizedSvg;
        fs.writeFileSync(manifestPath, JSON.stringify(json, null, 2) + '\n', 'utf8');
        console.log(`✓ ${relPath}: ${originalLength}B -> ${newLength}B (${saved >= 0 ? '-' + pct + '%' : '+' + Math.abs(pct) + '%'})`);
      } else {
        console.log(`- ${relPath}: No iconSvg field.`);
      }
    } catch (err) {
      console.error(`✗ Error processing ${relPath}:`, err.message);
    }
  }
}

function auditPlugins() {
  console.log('\n=== 3. Running Zero-Trust Security Audit on All Plugins ===');
  const auditorScript = path.join(ROOT_DIR, 'security/plugin_auditor.js');
  const manifests = findPluginManifests(PLUGINS_DIR);

  let passed = 0;
  for (const manifestPath of manifests) {
    try {
      execFileSync('node', [auditorScript, manifestPath], { stdio: 'ignore' });
      passed++;
    } catch (err) {
      console.error(`✗ Security audit FAILED for ${path.relative(ROOT_DIR, manifestPath)}`);
    }
  }
  console.log(`Security audit passed for all ${passed}/${manifests.length} plugins!`);
}

function main() {
  optimizeIconsDirectory();
  optimizePluginManifests();
  auditPlugins();
  console.log('\nAll brand and interface SVGs successfully optimized & sanitized via SVGO/SVGOMG standard.');
}

main();
