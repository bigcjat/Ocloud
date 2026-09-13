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
    console.log('Initiating snapshot backup...');
    const res = await backupEngine.runBackup();
    console.log(`Backup finished with status: ${res.status} (ID: ${res.id})`);
    return;
  }

  if (subcmd === 'schedule') {
    const enable = args.includes('--enable');
    const disable = args.includes('--disable');
    let interval = 'daily';
    for (const a of args) {
      if (a.startsWith('--interval=')) interval = a.split('=')[1];
    }
    const sched = backupEngine.setSchedule({
      enabled: enable ? true : disable ? false : true,
      interval
    });
    console.log(`Backup schedule updated: ${JSON.stringify(sched, null, 2)}`);
  }
}

module.exports = { cmdBackup };
