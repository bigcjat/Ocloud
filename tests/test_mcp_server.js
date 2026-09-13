const assert = require('assert');
const { handleRpcRequest } = require('../mcp/server');
const { PluginAuditor } = require('../security/plugin_auditor');

console.log('\x1b[1;36mRunning Secure MCP Server Test Suite...\x1b[0m\n');

let passedTests = 0;

async function test(name, fn) {
  try {
    await fn();
    console.log(`\x1b[32m✔ [PASS]\x1b[0m ${name}`);
    passedTests++;
  } catch (err) {
    console.error(`\x1b[31m✖ [FAIL]\x1b[0m ${name}:`, err.message);
    process.exit(1);
  }
}

async function runSuite() {
  // 1. Handshake & Protocol
  await test('MCP Handshake: initialize returns protocolVersion 2024-11-05 and serverInfo', async () => {
    const res = await handleRpcRequest({ id: 1, method: 'initialize', params: {} });
    assert.strictEqual(res.protocolVersion, '2024-11-05');
    assert.strictEqual(res.serverInfo.name, 'ocloud-mcp');
    assert.ok(res.capabilities.tools);
    assert.ok(res.capabilities.resources);
  });

  // 2. Tools List
  await test('MCP Tools List: returns all 10 safe cloud tools', async () => {
    const res = await handleRpcRequest({ id: 2, method: 'tools/list', params: {} });
    assert.ok(Array.isArray(res.tools));
    assert.strictEqual(res.tools.length, 10);
    const names = res.tools.map(t => t.name);
    assert.ok(names.includes('ocloud_status'));
    assert.ok(names.includes('ocloud_query_catalog'));
    assert.ok(names.includes('ocloud_provision_vm'));
    assert.ok(names.includes('ocloud_launch_app'));
    assert.ok(names.includes('ocloud_get_plugin_template'));
  });

  // 3. Catalog Query with Filters (RHEL in Singapore, 4GB RAM)
  await test('MCP Catalog Query: filters for dedicated 4GB RAM with Rocky/RHEL in Singapore', async () => {
    const res = await handleRpcRequest({
      id: 3,
      method: 'tools/call',
      params: {
        name: 'ocloud_query_catalog',
        arguments: {
          provider: 'hetzner',
          location: 'sin',
          min_ram_gb: 4,
          cpu_type: 'dedicated',
          os_flavor: 'rocky'
        }
      }
    });

    assert.ok(!res.isError);
    const parsed = JSON.parse(res.content[0].text);
    assert.strictEqual(parsed.provider, 'hetzner');
    assert.ok(parsed.matching_server_types.length >= 1, 'Expected at least 1 matching dedicated server type in Singapore');
    assert.ok(parsed.matching_server_types.some(t => t.id === 'ccx13'));
    assert.ok(parsed.available_locations.some(l => l.id === 'sin'));
    assert.ok(parsed.available_images.some(img => img.flavor === 'rocky'));
  });

  // 4. Credential Redaction in Status
  await test('MCP Zero-Leak Guardrail: ocloud_status scrubs all tokens and passwords', async () => {
    const res = await handleRpcRequest({
      id: 4,
      method: 'tools/call',
      params: {
        name: 'ocloud_status',
        arguments: {}
      }
    });

    assert.ok(!res.isError);
    const rawText = res.content[0].text;
    assert.ok(!rawText.includes('Bearer '), 'Bearer token leaked in status output!');
    assert.ok(!rawText.includes('api_token: "'), 'Plain API token leaked in status output!');
  });

  // 5. Waypipe App Launch
  await test('MCP App Launch: triggers Waypipe streaming descriptor for remote apps', async () => {
    const res = await handleRpcRequest({
      id: 5,
      method: 'tools/call',
      params: {
        name: 'ocloud_launch_app',
        arguments: {
          server_id_or_ip: '167.233.151.104',
          command: 'firefox',
          stream_gui: true
        }
      }
    });

    assert.ok(!res.isError);
    const parsed = JSON.parse(res.content[0].text);
    assert.strictEqual(parsed.status, 'launched');
    assert.strictEqual(parsed.streaming, 'waypipe');
    assert.strictEqual(parsed.target_server, '167.233.151.104');
  });

  // 6. AI Plugin Template Generation & Audit
  await test('MCP Plugin Authoring: generated boilerplate passes security audit with 100% score', async () => {
    const res = await handleRpcRequest({
      id: 6,
      method: 'tools/call',
      params: {
        name: 'ocloud_get_plugin_template',
        arguments: {
          plugin_type: 'storage',
          provider_id: 'wasabi',
          provider_name: 'Wasabi Hot Storage'
        }
      }
    });

    assert.ok(!res.isError);
    const parsed = JSON.parse(res.content[0].text);
    assert.strictEqual(parsed.filename, 'wasabi.json');

    // Run security auditor on generated JSON content
    const manifest = JSON.parse(parsed.content);
    const auditRes = PluginAuditor.auditManifest(manifest);
    assert.strictEqual(auditRes.status, 'PASSED', `Generated template failed audit: ${auditRes.violations.join(', ')}`);
  });

  // 7. Resource Read: Plugin Guide
  await test('MCP Resources: ocloud://docs/plugin-guide delivers full markdown specification', async () => {
    const res = await handleRpcRequest({
      id: 7,
      method: 'resources/read',
      params: {
        uri: 'ocloud://docs/plugin-guide'
      }
    });

    assert.ok(res.contents && res.contents.length > 0);
    assert.ok(res.contents[0].text.includes('Ocloud Plugin Development Guide'));
    assert.ok(res.contents[0].text.includes('Zero-Trust Security Requirements'));
  });

  console.log(`\n\x1b[1;32mAll ${passedTests} MCP server tests passed successfully!\x1b[0m\n`);
}

runSuite();
