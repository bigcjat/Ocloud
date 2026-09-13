async function cmdCatalog(provider = 'hetzner', args = [], { registry }) {
  const isJson = args.includes('--json') || process.argv.includes('--json');
  const forceRefresh = args.includes('--refresh') || process.argv.includes('--refresh');

  try {
    const catalog = await registry.getCatalog(provider, forceRefresh);
    if (isJson) {
      console.log(JSON.stringify(catalog, null, 2));
    } else {
      console.log(`\x1b[36m${provider.toUpperCase()} Cloud Catalog\x1b[0m (${(catalog.server_types || []).length} server types, ${(catalog.locations || []).length} locations)`);
      console.log(`Updated: ${new Date(catalog.timestamp || Date.now()).toLocaleString()}`);
      console.log('---------------------------------------------------------');
      const sym = catalog.currencySymbol || (provider === 'gcp' ? '$' : '€');
      (catalog.server_types || []).forEach((s) => {
        const sSym = s.currencySymbol || sym;
        console.log(`- ${s.name.padEnd(14)} [${s.cpuType.toUpperCase()}/${s.architecture}] ${s.cores} vCPU, ${s.memory}GB RAM, ${s.disk}GB Disk -> ${sSym}${s.priceHourlyNet}/hr (${sSym}${s.priceMonthlyNet}/mo)`);
      });
    }
  } catch (err) {
    if (isJson) console.log(JSON.stringify({ error: err.message }));
    else console.error(`Failed to load catalog for '${provider}': ${err.message}`);
  }
}

module.exports = { cmdCatalog };
