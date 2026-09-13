const fs = require('fs');
const path = require('path');

function cmdDocs(subcmd) {
  const docFile = subcmd === 'waypipe' ? 'WAYPIPE_STREAMING_REFERENCE.md' : 'PLUGIN_DEVELOPMENT_GUIDE.md';
  const docPath = path.join(__dirname, '..', '..', 'docs', docFile);
  if (fs.existsSync(docPath)) console.log(fs.readFileSync(docPath, 'utf8'));
  else console.error(`Document "${docFile}" not found.`);
}

module.exports = { cmdDocs };
