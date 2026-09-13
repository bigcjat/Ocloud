async function cmdBackup(subcmd, args, { backupEngine }) {
  if (subcmd === 'status') {
    const sched = backupEngine.getSchedule();
    const history = backupEngine.getHistory();
    console.log(JSON.stringify({ schedule: sched, recent: history.slice(0, 5) }, null, 2));
    return;
  }

  if (subcmd === 'history') {
    const history = backupEngine.getHistory();
    if (history.length === 0) {
      console.log('No backups recorded.');
      return;
    }
    console.log(`${'SNAPSHOT ID'.padEnd(30)} ${'TIMESTAMP'.padEnd(25)} ${'STATUS'.padEnd(10)} DURATION`);
    console.log('-'.repeat(75));
    for (const h of history) {
      console.log(`${h.id.padEnd(30)} ${h.timestamp.padEnd(25)} ${h.status.padEnd(10)} ${h.duration_seconds}s`);
    }
    return;
  }

  if (subcmd === 'run') {
    let source = null;
    let destination = null;
    for (let i = 0; i < args.length; i++) {
      if (args[i] === '--source' && args[i+1]) source = args[++i];
      else if (args[i].startsWith('--source=')) source = args[i].split('=')[1];
      else if (args[i] === '--dest' && args[i+1]) destination = args[++i];
      else if (args[i].startsWith('--dest=')) destination = args[i].split('=')[1];
    }
    console.log(`Initiating snapshot backup${source ? ` (Source: ${source})` : ''}${destination ? ` (Dest: ${destination})` : ''}...`);
    const res = await backupEngine.runBackup({ source, destination });
    console.log(`Backup finished with status: ${res.status} (ID: ${res.id})`);
    return;
  }

  if (subcmd === 'schedule') {
    const enable = args.includes('--enable');
    const disable = args.includes('--disable');
    let interval = 'daily';
    let source = null;
    let destination = null;
    for (let i = 0; i < args.length; i++) {
      const a = args[i];
      if (a.startsWith('--interval=')) interval = a.split('=')[1];
      else if (a === '--source' && args[i+1]) source = args[++i];
      else if (a.startsWith('--source=')) source = a.split('=')[1];
      else if (a === '--dest' && args[i+1]) destination = args[++i];
      else if (a.startsWith('--dest=')) destination = a.split('=')[1];
    }
    const sched = backupEngine.setSchedule({
      enabled: enable ? true : disable ? false : true,
      interval,
      source,
      destination
    });
    console.log(`Backup schedule updated: ${JSON.stringify(sched, null, 2)}`);
    return;
  }
}

module.exports = { cmdBackup };
