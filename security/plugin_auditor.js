const fs = require('fs');
const path = require('path');
const { URL } = require('url');

/**
 * Plugin Security Auditor for Ocloud.
 * Implements zero-trust static analysis, manifest policy validation,
 * domain boundary checking, multi-root anomaly detection, and SVG sanitization.
 */
class PluginAuditor {
  /**
   * Sanitizes an embedded SVG logo string to prevent XXE, XML bombs,
   * script injection, iframes, and event handlers.
   * 
   * @param {string} rawSvg 
   * @returns {{ safeSvg: string, violations: string[] }}
   */
  static sanitizeSvg(rawSvg) {
    const violations = [];
    if (!rawSvg || typeof rawSvg !== 'string') {
      return { safeSvg: '', violations: ['Empty or invalid SVG input'] };
    }

    let svg = rawSvg.trim();

    // 1. Check for XML External Entity (XXE) and DTD injection
    if (/<!doctype/i.test(svg)) {
      violations.push('Blocked <!DOCTYPE> declaration in SVG (potential XXE attack)');
      svg = svg.replace(/<!doctype[^>]*>/gi, '');
    }
    if (/<!entity/i.test(svg)) {
      violations.push('Blocked <!ENTITY> declaration in SVG (potential XML expansion bomb)');
      svg = svg.replace(/<!entity[^>]*>/gi, '');
    }

    // 2. Check for script and dangerous executable tags
    const dangerousTags = [
      'script', 'foreignObject', 'iframe', 'embed', 'object',
      'applet', 'meta', 'link', 'audio', 'video'
    ];
    for (const tag of dangerousTags) {
      const tagRegex = new RegExp(`<\\s*${tag}\\b[^>]*>([\\s\\S]*?<\\s*\\/\\s*${tag}\\s*>)?`, 'gi');
      if (tagRegex.test(svg)) {
        violations.push(`Blocked dangerous tag <${tag}> in SVG`);
        svg = svg.replace(tagRegex, '');
      }
    }

    // 3. Strip all inline JavaScript event handlers (e.g. onload, onclick, onerror)
    const eventHandlerRegex = /\s(on[a-z]+)\s*=\s*(['"]).*?\2/gi;
    const eventMatches = svg.match(eventHandlerRegex);
    if (eventMatches) {
      violations.push(`Blocked inline event handler(s) (${eventMatches.map(m => m.trim().split('=')[0]).join(', ')}) in SVG`);
      svg = svg.replace(eventHandlerRegex, '');
    }

    // 4. Strip javascript: and data: URIs from href and xlink:href
    const dangerousUriRegex = /(href|xlink:href)\s*=\s*(['"])\s*(javascript:|data:text\/html).*?\2/gi;
    if (dangerousUriRegex.test(svg)) {
      violations.push('Blocked dangerous javascript:/data: URI in SVG href');
      svg = svg.replace(dangerousUriRegex, '');
    }

    // 5. Verify it is still an SVG element
    if (!/<svg\b[^>]*>[\s\S]*<\/svg>/i.test(svg)) {
      violations.push('Invalid SVG structure after sanitization');
      return { safeSvg: '', violations };
    }

    return { safeSvg: svg, violations };
  }

  /**
   * Helper: Extracts base root domain (e.g. "hetzner.cloud" from "api.hetzner.cloud").
   */
  static getRootDomain(hostname) {
    if (!hostname) return '';
    const clean = hostname.toLowerCase().replace(/^\*?\./, '');
    const parts = clean.split('.');
    if (parts.length <= 2) return clean;
    // Handle standard two-part TLDs (e.g. co.uk, com.au) vs single TLD (com, net, cloud)
    const secondLevelTlds = ['co.uk', 'com.au', 'com.br', 'co.jp'];
    const lastTwo = parts.slice(-2).join('.');
    if (secondLevelTlds.includes(lastTwo) && parts.length >= 3) {
      return parts.slice(-3).join('.');
    }
    return parts.slice(-2).join('.');
  }

  /**
   * Audits a plugin manifest (plugin.json or *.json).
   * 
   * @param {object} manifest 
   * @returns {{ status: 'PASSED'|'WARNING'|'BLOCKED', violations: string[], warnings: string[] }}
   */
  static auditManifest(manifest) {
    const violations = [];
    const warnings = [];

    if (!manifest.id || typeof manifest.id !== 'string') {
      violations.push('Manifest missing required string property "id"');
    }
    if (!manifest.name || typeof manifest.name !== 'string') {
      violations.push('Manifest missing required string property "name"');
    }

    // Check SVG logo if present
    if (manifest.iconSvg) {
      const { safeSvg, violations: svgViolations } = this.sanitizeSvg(manifest.iconSvg);
      if (svgViolations.length > 0) {
        violations.push(...svgViolations.map(v => `SVG Logo: ${v}`));
      }
    }

    // Check allowedDomains declaration
    const allowedDomains = manifest.allowedDomains || [];
    if (!Array.isArray(allowedDomains)) {
      violations.push('"allowedDomains" must be an array of domain strings');
    } else {
      // Multi-Root Domain Anomaly Detection
      const rootDomains = new Set();
      for (const d of allowedDomains) {
        if (typeof d !== 'string') {
          violations.push(`Invalid non-string domain entry in allowedDomains: ${d}`);
          continue;
        }
        // Dynamic variables like {{host}} or {{server_url}} are user-anchored
        if (/^\{\{.*\}\}$/.test(d.trim())) continue;

        try {
          const host = d.startsWith('http://') || d.startsWith('https://') 
            ? new URL(d).hostname 
            : d.replace(/^\*?\./, '');
          const root = this.getRootDomain(host);
          if (root) rootDomains.add(root);
        } catch (e) {
          violations.push(`Cannot parse domain string in allowedDomains: "${d}"`);
        }
      }

      // If a plugin lists multiple distinct root domains (e.g. digitalocean.com and badsite.net), flag warning
      if (rootDomains.size > 2) {
        warnings.push(`Multi-Root Domain Anomaly: Plugin declares multiple distinct root domains (${Array.from(rootDomains).join(', ')}). Verify all endpoints are authentic.`);
      }
    }

    const status = violations.length > 0 ? 'BLOCKED' : (warnings.length > 0 ? 'WARNING' : 'PASSED');
    return { status, violations, warnings };
  }

  /**
   * Performs deep static analysis on a driver.js file.
   * 
   * @param {string} code - Source code of driver.js
   * @param {object} manifest - Parsed plugin.json
   * @returns {{ status: 'PASSED'|'WARNING'|'BLOCKED', violations: string[], warnings: string[], extractedDomains: string[] }}
   */
  static auditDriverCode(code, manifest = {}) {
    const violations = [];
    const warnings = [];
    const extractedDomains = [];

    if (!code || typeof code !== 'string') {
      return { status: 'BLOCKED', violations: ['Driver source code is empty or missing'], warnings: [], extractedDomains: [] };
    }

    const lines = code.split('\n');

    // 1. AST / Pattern Analysis: Dangerous execution & sandbox escape attempts
    const criticalPatterns = [
      {
        pattern: /\beval\s*\(/,
        message: 'Dynamic code execution via eval() is strictly forbidden.'
      },
      {
        pattern: /\bnew\s+Function\s*\(|\bFunction\s*\(/,
        message: 'Dynamic constructor execution via new Function() is strictly forbidden.'
      },
      {
        pattern: /constructor\s*\.\s*constructor/,
        message: 'Prototype climbing / sandbox escape attempt via constructor.constructor detected.'
      },
      {
        pattern: /__proto__/,
        message: 'Direct prototype tampering via __proto__ detected.'
      },
      {
        pattern: /\bvm\s*\.\s*(runIn|createContext|Script)/,
        message: 'Unsanctioned VM context creation detected.'
      },
      {
        pattern: /process\s*\.\s*(exit|kill|abort)/,
        message: 'Unauthorized process lifecycle disruption detected.'
      },
      {
        pattern: /process\s*\.\s*(binding|dlopen|mainModule)/,
        message: 'Unauthorized low-level internal process access detected.'
      },
      {
        pattern: /(?:\/etc\/shadow|\/etc\/passwd|\.bash_history|\.zsh_history|vault\.enc)/i,
        message: 'Unauthorized attempt to target sensitive host filesystem paths.'
      },
      {
        pattern: /fs\s*\.\s*(?:readFile|readFileSync|createReadStream)\s*\(\s*.*(?:id_rsa|id_ed25519|\.ssh)/i,
        message: 'Unauthorized attempt to directly read SSH private keys or .ssh directory into memory.'
      },
      {
        pattern: /\\x[0-9a-fA-F]{2}\\x[0-9a-fA-F]{2}/,
        message: 'Potential obfuscation via consecutive hex escape sequences detected.'
      },
      {
        pattern: /['"`]\s*\+\s*['"`](_?process|eval|Function|child_process|require|_process)['"`]/,
        message: 'String concatenation obfuscation targeting protected keywords detected.'
      },
      {
        pattern: /['"`](child|eval|func|pro)['"`]\s*\+\s*['"`]/i,
        message: 'String concatenation obfuscation targeting protected keywords detected.'
      },
      {
        pattern: /\b(sudo\s+|rm\s+-rf\s+|mkfs\b|curl\s+.*\|\s*(?:bash|sh)\b)/i,
        message: 'Dangerous destructive shell command pattern detected.'
      }
    ];

    const hasProcessPermissions = Boolean(
      manifest.permissions && (
        manifest.permissions.ssh ||
        manifest.permissions.rclone ||
        manifest.permissions.mount
      )
    );

    for (let i = 0; i < lines.length; i++) {
      const line = lines[i];
      const lineNum = i + 1;

      for (const check of criticalPatterns) {
        if (check.pattern.test(line)) {
          violations.push(`Line ${lineNum}: ${check.message}`);
        }
      }

      // Check for child_process if not permitted in manifest
      if (!hasProcessPermissions && /child_process/.test(line)) {
        violations.push(`Line ${lineNum}: Unauthorized child_process import. Manifest must declare "permissions.ssh" or "permissions.rclone: true".`);
      }
    }

    // 2. Extract static URL/domain endpoints in code
    const urlMatches = code.matchAll(/https?:\/\/([a-zA-Z0-9.-]+(?::[0-9]+)?)[^\s'"`]*/g);
    const foundHosts = new Set();
    for (const match of urlMatches) {
      if (match[1]) {
        const hostname = match[1].split(':')[0].toLowerCase();
        foundHosts.add(hostname);
        if (!extractedDomains.includes(hostname)) {
          extractedDomains.push(hostname);
        }
      }
    }

    // 3. Cross-check extracted domains against manifest.allowedDomains
    const allowed = (manifest.allowedDomains || []).map(d => d.toLowerCase().trim());

    for (const host of foundHosts) {
      // Localhost/loopback or user parameter templates are checked
      if (host === 'localhost' || host === '127.0.0.1') continue;

      const isPermitted = allowed.some(pattern => {
        if (pattern === host) return true;
        if (pattern.startsWith('*.') && host.endsWith(pattern.slice(1))) return true;
        // User template parameter (e.g. {{host}} or {{server_url}}) matches dynamic inputs
        if (/^\{\{.*\}\}$/.test(pattern)) return true;
        return false;
      });

      if (!isPermitted) {
        violations.push(`Undeclared network endpoint: Code connects to "${host}", but it is not listed in manifest allowedDomains.`);
      }
    }

    const status = violations.length > 0 ? 'BLOCKED' : (warnings.length > 0 ? 'WARNING' : 'PASSED');
    return { status, violations, warnings, extractedDomains };
  }

  /**
   * Audits an entire plugin directory on disk.
   * 
   * @param {string} pluginDir - Path to plugin folder
   * @returns {object} Full audit report
   */
  static auditPluginDir(pluginDir) {
    const report = {
      pluginDir,
      id: path.basename(pluginDir),
      status: 'PASSED',
      manifestCheck: null,
      driverCheck: null,
      violations: [],
      warnings: [],
      extractedDomains: []
    };

    const manifestPath = path.join(pluginDir, 'plugin.json');
    if (!fs.existsSync(manifestPath)) {
      report.status = 'BLOCKED';
      report.violations.push('Missing plugin.json manifest');
      return report;
    }

    let manifest = {};
    try {
      manifest = JSON.parse(fs.readFileSync(manifestPath, 'utf8'));
      report.id = manifest.id || report.id;
    } catch (e) {
      report.status = 'BLOCKED';
      report.violations.push(`Invalid plugin.json syntax: ${e.message}`);
      return report;
    }

    // 1. Audit Manifest & SVG
    report.manifestCheck = this.auditManifest(manifest);
    report.violations.push(...report.manifestCheck.violations);
    report.warnings.push(...report.manifestCheck.warnings);

    // 2. Audit Driver if defined
    if (manifest.driver) {
      const driverPath = path.join(pluginDir, manifest.driver);
      if (!fs.existsSync(driverPath)) {
        report.violations.push(`Driver file defined in manifest not found: ${manifest.driver}`);
      } else {
        const code = fs.readFileSync(driverPath, 'utf8');
        report.driverCheck = this.auditDriverCode(code, manifest);
        report.violations.push(...report.driverCheck.violations);
        report.warnings.push(...report.driverCheck.warnings);
        report.extractedDomains = report.driverCheck.extractedDomains;
      }
    }

    report.status = report.violations.length > 0 ? 'BLOCKED' : (report.warnings.length > 0 ? 'WARNING' : 'PASSED');
    return report;
  }

  /**
   * Audits a pure JSON storage plugin file.
   * 
   * @param {string} filePath - Path to *.json plugin file
   * @returns {object} Full audit report
   */
  static auditJsonPluginFile(filePath) {
    const report = {
      filePath,
      id: path.basename(filePath, '.json'),
      status: 'PASSED',
      violations: [],
      warnings: []
    };

    try {
      const manifest = JSON.parse(fs.readFileSync(filePath, 'utf8'));
      report.id = manifest.id || report.id;
      const res = this.auditManifest(manifest);
      report.violations.push(...res.violations);
      report.warnings.push(...res.warnings);
      report.status = res.status;
    } catch (e) {
      report.status = 'BLOCKED';
      report.violations.push(`Invalid JSON syntax: ${e.message}`);
    }

    return report;
  }
}

module.exports = { PluginAuditor };
