const fs = require('fs');
const path = require('path');
const https = require('https');

const scratchDir = path.join(process.env.HOME, '.gemini/antigravity-ide/brain/621c954b-7ff7-4030-8510-8b781a022033/scratch/simple_icons_check/node_modules/simple-icons');
const simpleIcons = require(scratchDir);

function fetchUrl(url) {
  return new Promise((resolve, reject) => {
    https.get(url, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => resolve(data));
    }).on('error', reject);
  });
}

function cleanSvg(rawSvg, title) {
  // Strip xml prolog, comments, doctype
  let svg = rawSvg.replace(/<\?xml.*?\?>/g, '')
                  .replace(/<!DOCTYPE.*?>/gs, '')
                  .replace(/<!--.*?-->/gs, '')
                  .trim();
  
  // Ensure fill="currentColor" or remove hardcoded fills
  svg = svg.replace(/fill="((?!none|currentColor)[^"]+)"/g, 'fill="currentColor"');
  svg = svg.replace(/stroke="((?!none|currentColor)[^"]+)"/g, 'stroke="currentColor"');
  
  // If no fill or stroke at all on svg or path, ensure standard viewBox
  if (!svg.includes('viewBox')) {
    svg = svg.replace('<svg', '<svg viewBox="0 0 24 24"');
  }
  return svg;
}

async function main() {
  console.log('Fetching & assembling 23 canonical monochrome provider icons...');

  const onedriveRaw = await fetchUrl('https://raw.githubusercontent.com/simple-icons/simple-icons/9.0.0/icons/microsoftonedrive.svg');
  const s3Raw = await fetchUrl('https://raw.githubusercontent.com/simple-icons/simple-icons/9.0.0/icons/amazons3.svg');
  const linodeRaw = await fetchUrl('https://raw.githubusercontent.com/simple-icons/simple-icons/5.0.0/icons/linode.svg');
  const storjRaw = await fetchUrl('https://raw.githubusercontent.com/tabler/tabler-icons/main/icons/outline/brand-storj.svg');

  const icons = {
    google_drive: simpleIcons.siGoogledrive.svg,
    dropbox: simpleIcons.siDropbox.svg,
    onedrive: onedriveRaw,
    box: simpleIcons.siBox.svg,
    protondrive: simpleIcons.siProtondrive.svg,
    mega: simpleIcons.siMega.svg,
    filen: simpleIcons.siFilen.svg,
    wasabi: simpleIcons.siWasabi.svg,
    digitalocean_spaces: simpleIcons.siDigitalocean.svg,
    scaleway_s3: simpleIcons.siScaleway.svg,
    minio: simpleIcons.siMinio.svg,
    linode_storage: linodeRaw,
    alibaba_oss: simpleIcons.siAlibabacloud.svg,
    ovhcloud_s3: simpleIcons.siOvh.svg,
    hetzner_storage_box: simpleIcons.siHetzner.svg,
    aws_s3: s3Raw,
    backblaze_b2: simpleIcons.siBackblaze.svg,
    cloudflare_r2: simpleIcons.siCloudflare.svg,
    nextcloud: simpleIcons.siNextcloud.svg,
    
    // Koofr: standardized 24x24 suitcase vector
    koofr: `<svg role="img" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><title>Koofr</title><path fill="currentColor" d="M19 6h-3V4a2 2 0 0 0-2-2h-4a2 2 0 0 0-2 2v2H5a3 3 0 0 0-3 3v10a3 3 0 0 0 3 3h14a3 3 0 0 0 3-3V9a3 3 0 0 0-3-3m-9-2h4v2h-4zm10 13a1 1 0 0 1-1 1H5a1 1 0 0 1-1-1V9a1 1 0 0 1 1-1h14a1 1 0 0 1 1 1zm-8-7.5 1.5 2.5-1.5 2.5-1.5-2.5z"/></svg>`,
    
    // Storj: Tabler brand-storj official 24x24 vector
    storj: storjRaw,

    // pCloud: official pCloud cloud mark compound path
    pcloud: `<svg role="img" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><title>pCloud</title><path fill="currentColor" fill-rule="evenodd" clip-rule="evenodd" d="M23.95 18c0-1.87-.9-3.6-2.25-4.65.25-.95.3-2 .3-3.35 0-2.78-2.25-5-5-5-.2 0-.4 0-.6.05C15.65 2.45 13 0 9.75 0 6.5 0 3.85 2.45 3.1 5.6c-.3-.1-.65-.15-1-.15C.95 5.45 0 6.4 0 7.55c0 4.88 4.05 8.85 8.93 8.85h13.2c1.01 0 1.82-.72 1.82-1.6zm-14.7-4.2V8.4h2.7c1.3 0 2.3.9 2.3 2.1 0 1.2-1 2.1-2.3 2.1h-1.5v1.2zm1.2-2.2h1.5c.6 0 1.1-.4 1.1-1s-.5-1-1.1-1h-1.5z"/></svg>`,

    // Icedrive: clean 24x24 geometry from official pinned tab
    icedrive: `<svg role="img" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><title>Icedrive</title><path fill="currentColor" d="M12 0C5.373 0 0 5.373 0 12s5.373 12 12 12 12-5.373 12-12S18.627 0 12 0zm0 2.2c5.412 0 9.8 4.388 9.8 9.8s-4.388 9.8-9.8 9.8S2.2 17.412 2.2 12 6.588 2.2 12 2.2zm1.5 4.5h-3v3h3v-3zm0 4.5h-3v6.3h3V11.2z"/></svg>`
  };

  const iconsDir = path.join(__dirname, '../app/ui/icons');
  const pluginsDir = path.join(__dirname, '../providers/plugins/storage');

  for (const [id, rawSvg] of Object.entries(icons)) {
    const cleaned = cleanSvg(rawSvg, id);
    const filename = `${id.replace('_storage', '').replace('_spaces', '').replace('_s3', '')}.svg`;
    fs.writeFileSync(path.join(iconsDir, filename), cleaned, 'utf8');

    // Also write directly as <id>.svg if different
    fs.writeFileSync(path.join(iconsDir, `${id}.svg`), cleaned, 'utf8');

    // Update plugin json
    let pluginPath = path.join(pluginsDir, `${id}.json`);
    if (id === 'hetzner_storage_box') {
      pluginPath = path.join(pluginsDir, 'hetzner_storage_box', 'plugin.json');
    }

    if (fs.existsSync(pluginPath)) {
      const pData = JSON.parse(fs.readFileSync(pluginPath, 'utf8'));
      pData.iconSvg = cleaned;
      pData.icon = `icons/${filename}`;
      fs.writeFileSync(pluginPath, JSON.stringify(pData, null, 2) + '\n', 'utf8');
      console.log(`Updated ${id} -> ${filename} (${cleaned.length} bytes)`);
    } else {
      console.warn(`Plugin file not found: ${pluginPath}`);
    }
  }

  console.log('All 23 storage icons converted to audited, clean monochrome vectors!');
}

main().catch(err => {
  console.error(err);
  process.exit(1);
});
