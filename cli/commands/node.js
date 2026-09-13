async function cmdNode(subcmd, args, { registry }) {
  const plugin = registry.getComputePlugin('custom');
  const driver = plugin ? plugin.driver : null;

  if (!driver) {
    console.error('Error: Custom compute driver not loaded.');
    return;
  }

  if (subcmd === 'list') {
    const nodes = await driver.listServers();
    if (nodes.length === 0) {
      console.log('No custom nodes registered.');
      return;
    }
    console.log(`${'ID'.padEnd(16)} ${'NAME'.padEnd(20)} ${'HOST'.padEnd(18)} ${'STATUS'.padEnd(10)} TYPE`);
    console.log('-'.repeat(75));
    for (const n of nodes) {
      const typeStr = n.isHomeWorkstation ? '🏠 Home Workstation' : '⚡ Bare Metal';
      console.log(`${n.id.padEnd(16)} ${n.name.padEnd(20)} ${n.ipv4.padEnd(18)} ${n.status.padEnd(10)} ${typeStr}`);
    }
    return;
  }

  if (subcmd === 'add') {
    const name = args[0];
    const host = args[1];
    if (!name || !host) {
      console.log('Usage: ocloud node add <name> <host> [--home] [--user=root] [--port=22]');
      return;
    }
    const isHome = args.includes('--home');
    let user = 'root';
    let port = 22;
    for (const a of args) {
      if (a.startsWith('--user=')) user = a.split('=')[1];
      if (a.startsWith('--port=')) port = parseInt(a.split('=')[1], 10);
    }
    const node = await driver.addServer({ name, host, user, port, isHomeWorkstation: isHome });
    console.log(`\x1b[32m✔ Registered node: ${node.name} (${node.host})\x1b[0m`);
    return;
  }

  if (subcmd === 'remove') {
    const target = args[0];
    if (!target) {
      console.log('Usage: ocloud node remove <name-or-id>');
      return;
    }
    const removed = await driver.removeServer(target);
    if (removed) console.log(`\x1b[32m✔ Removed node: ${target}\x1b[0m`);
    else console.log(`Node not found: ${target}`);
  }
}

module.exports = { cmdNode };
