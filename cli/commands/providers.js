async function cmdPluginAudit(targetId = null, args = [], registry) {
  const isJson = args.includes('--json') || process.argv.includes('--json');
  const isStrict = args.includes('--strict') || process.argv.includes('--strict');

  if (!targetId || targetId === 'all') {
    const reports = registry.auditAll();
    if (isJson) {
      console.log(JSON.stringify(reports, null, 2));
      return;
    }

    console.log('\n\x1b[1;36m🛡️  Ocloud Plugin Security Audit (All Plugins)\x1b[0m');
    console.log('━'.repeat(70));
    let hasFailures = false;

    for (const r of reports) {
      const statusColor = r.status === 'PASSED' ? '\x1b[32m✔ PASSED\x1b[0m' 
        : (r.status === 'WARNING' ? '\x1b[33m⚠ WARNING\x1b[0m' : '\x1b[31m✖ BLOCKED\x1b[0m');
      console.log(`${r.id.padEnd(24)} ${statusColor}`);
      if (r.violations.length > 0) {
        hasFailures = true;
        for (const v of r.violations) {
          console.log(`  \x1b[31m✖ ${v}\x1b[0m`);
        }
      }
      if (r.warnings.length > 0) {
        for (const w of r.warnings) {
          console.log(`  \x1b[33m⚠ ${w}\x1b[0m`);
        }
      }
    }
    console.log('━'.repeat(70));
    if (hasFailures && isStrict) {
      process.exit(1);
    }
    return;
  }

  const report = registry.auditPlugin(targetId);
  if (!report) {
    if (isJson) console.log(JSON.stringify({ error: `Plugin "${targetId}" not found.` }));
    else console.error(`\x1b[31mPlugin "${targetId}" not found.\x1b[0m`);
    return;
  }

  if (isJson) {
    console.log(JSON.stringify(report, null, 2));
    return;
  }

  const statusColor = report.status === 'PASSED' ? '\x1b[1;32mPASSED\x1b[0m' 
    : (report.status === 'WARNING' ? '\x1b[1;33mWARNING\x1b[0m' : '\x1b[1;31mBLOCKED\x1b[0m');

  console.log(`\n\x1b[1;36m🛡️  Ocloud Plugin Security Audit: ${report.id}\x1b[0m`);
  console.log('━'.repeat(65));
  console.log(`Status:               ${statusColor}`);
  if (report.pluginDir) console.log(`Path:                 ${report.pluginDir}`);
  if (report.extractedDomains && report.extractedDomains.length > 0) {
    console.log(`Extracted Endpoints:  ${report.extractedDomains.join(', ')}`);
  }

  console.log('\n\x1b[1mSecurity Checks:\x1b[0m');
  const checks = [
    { name: 'Dynamic Code Execution (eval, Function)', passed: !report.violations.some(v => v.includes('eval') || v.includes('Function')) },
    { name: 'Prototype Climbing & Sandbox Escape', passed: !report.violations.some(v => v.includes('constructor') || v.includes('proto')) },
    { name: 'Destructive Shell Invocations', passed: !report.violations.some(v => v.includes('destructive shell') || v.includes('child_process')) },
    { name: 'Sensitive Path Traversal (~/.ssh, /etc)', passed: !report.violations.some(v => v.includes('sensitive host filesystem')) },
    { name: 'Domain Boundary & Whitelist Alignment', passed: !report.violations.some(v => v.includes('Undeclared network endpoint')) },
    { name: 'Vector SVG Sanitization (XXE/Scripts)', passed: !report.violations.some(v => v.includes('SVG')) },
    { name: 'Multi-Root Domain Anomaly Check', passed: !report.warnings.some(w => w.includes('Multi-Root')) }
  ];

  for (const c of checks) {
    if (c.passed) {
      console.log(`  \x1b[32m✔ ${c.name}\x1b[0m`);
    } else {
      console.log(`  \x1b[31m✖ ${c.name}\x1b[0m`);
    }
  }

  if (report.violations.length > 0) {
    console.log('\n\x1b[1;31mViolations:\x1b[0m');
    for (const v of report.violations) {
      console.log(`  \x1b[31m• ${v}\x1b[0m`);
    }
  }

  if (report.warnings.length > 0) {
    console.log('\n\x1b[1;33mWarnings:\x1b[0m');
    for (const w of report.warnings) {
      console.log(`  \x1b[33m• ${w}\x1b[0m`);
    }
  }
  console.log('━'.repeat(65) + '\n');

  if (report.status === 'BLOCKED' && isStrict) {
    process.exit(1);
  }
}

async function cmdProviders(subcmd = 'list', args = [], { registry }) {
  if (subcmd === 'audit') {
    const target = args[0] || 'all';
    await cmdPluginAudit(target, args.slice(1), registry);
    return;
  }

  if (subcmd === 'verify') {
    const target = args[0] || 'gcp';
    await cmdPluginVerify(target, args.slice(1), { registry });
    return;
  }

  const isJson = args.includes('--json') || process.argv.includes('--json');
  const showSecurity = args.includes('--security') || process.argv.includes('--security');
  const typeFilter = (args.find((a) => a.startsWith('--type=')) || process.argv.find((a) => a.startsWith('--type=')))?.split('=')[1]
    || (args.includes('compute') || process.argv.includes('compute') ? 'compute' : null)
    || (args.includes('storage') || process.argv.includes('storage') ? 'storage' : null);

  const compute = registry.listComputePlugins();
  const storage = registry.listStoragePlugins();

  if (isJson) {
    if (typeFilter === 'compute') console.log(JSON.stringify(compute, null, 2));
    else if (typeFilter === 'storage') console.log(JSON.stringify(storage, null, 2));
    else console.log(JSON.stringify({ compute, storage }, null, 2));
    return;
  }

  console.log('\n\x1b[1;36mAvailable Ocloud Plugins\x1b[0m');
  console.log('━'.repeat(70));
  if (!typeFilter || typeFilter === 'compute') {
    console.log('\x1b[1mCompute Providers:\x1b[0m');
    for (const p of compute) {
      const secTag = showSecurity 
        ? (p.securityStatus === 'PASSED' ? '\x1b[32m[PASSED]\x1b[0m' : (p.securityStatus === 'WARNING' ? '\x1b[33m[WARN]\x1b[0m' : '\x1b[31m[BLOCKED]\x1b[0m'))
        : '';
      console.log(`  • ${p.id.padEnd(16)} ${p.name.padEnd(24)} [${p.badge || 'Compute'}] ${secTag}`);
    }
  }
  if (!typeFilter || typeFilter === 'storage') {
    console.log('\n\x1b[1mStorage Providers:\x1b[0m');
    for (const p of storage) {
      const secTag = showSecurity 
        ? (p.securityStatus === 'PASSED' ? '\x1b[32m[PASSED]\x1b[0m' : (p.securityStatus === 'WARNING' ? '\x1b[33m[WARN]\x1b[0m' : '\x1b[31m[BLOCKED]\x1b[0m'))
        : '';
      console.log(`  • ${p.id.padEnd(20)} ${p.name.padEnd(24)} [${p.badge || 'Storage'}] ${secTag}`);
    }
  }
  console.log('');
}

async function cmdPluginVerify(targetId = 'gcp', args = [], { registry }) {
  const isJson = args.includes('--json') || process.argv.includes('--json');
  const plugin = registry.getComputePlugin(targetId) || registry.getStoragePlugin(targetId);
  if (!plugin || !plugin.driver) {
    const res = { ok: false, error: `Provider '${targetId}' not found or has no active driver.` };
    if (isJson) console.log(JSON.stringify(res));
    else console.error(res.error);
    process.exit(1);
  }

  const pName = (plugin.manifest && plugin.manifest.name) || plugin.name || targetId;

  if (typeof plugin.driver.verifyCredentials === 'function') {
    const result = await plugin.driver.verifyCredentials();
    if (isJson) {
      console.log(JSON.stringify(result));
    } else {
      if (result.ok) {
        console.log(`\x1b[32m✔ ${pName} credentials verified successfully!\x1b[0m`);
      } else {
        console.error(`\x1b[31m✖ ${pName} verification failed:\x1b[0m ${result.error}`);
        if (result.needsApiEnable && result.enableUrl) {
          console.log(`\x1b[33m👉 Enable Compute Engine API here: ${result.enableUrl}\x1b[0m`);
        }
      }
    }
    process.exit(result.ok ? 0 : 1);
  } else {
    const ok = plugin.driver.isConfigured ? plugin.driver.isConfigured() : true;
    const res = { ok, error: ok ? null : 'Provider is not configured.' };
    if (isJson) console.log(JSON.stringify(res));
    else console.log(ok ? `✔ ${pName} configured.` : `✖ ${pName} not configured.`);
    process.exit(ok ? 0 : 1);
  }
}

module.exports = { cmdProviders, cmdPluginAudit, cmdPluginVerify };
