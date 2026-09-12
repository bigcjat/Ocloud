const net = require('net');

/**
 * Datacenter Latency Prober
 * Performs fast TCP handshakes against public speedtest/API endpoints of Hetzner datacenters
 * and returns results sorted by lowest latency.
 */
const HETZNER_LOCATIONS = [
  {
    id: 'nbg1',
    name: 'Nuremberg',
    country: '🇩🇪 Germany',
    flag: '🇩🇪',
    region: 'Central Europe',
    host: 'nbg1-speed.hetzner.com',
    fallbackHost: 'speed.hetzner.de',
    port: 80,
    optimalFor: 'High-FPS Gaming & Ultra-Low Latency'
  },
  {
    id: 'fsn1',
    name: 'Falkenstein',
    country: '🇩🇪 Germany',
    flag: '🇩🇪',
    region: 'Central Europe',
    host: 'fsn1-speed.hetzner.com',
    fallbackHost: 'speed.hetzner.de',
    port: 80,
    optimalFor: 'Central European Workloads'
  },
  {
    id: 'hel1',
    name: 'Helsinki',
    country: '🇫🇮 Finland',
    flag: '🇫🇮',
    region: 'Northern Europe',
    host: 'hel1-speed.hetzner.com',
    fallbackHost: 'hel1.your-objectstorage.com',
    port: 80,
    optimalFor: 'Nordic & Baltic Low Latency'
  },
  {
    id: 'sin',
    name: 'Singapore',
    country: '🇸🇬 Singapore',
    flag: '🇸🇬',
    region: 'Asia-Pacific',
    host: 'sin-speed.hetzner.com',
    fallbackHost: 'sin.your-objectstorage.com',
    port: 80,
    optimalFor: 'Asia-Pacific Direct Route'
  },
  {
    id: 'ash',
    name: 'Ashburn, VA',
    country: '🇺🇸 United States',
    flag: '🇺🇸',
    region: 'US East Coast',
    host: 'ash-speed.hetzner.com',
    fallbackHost: 'ash.your-objectstorage.com',
    port: 80,
    optimalFor: 'North American East'
  },
  {
    id: 'hil',
    name: 'Hillsboro, OR',
    country: '🇺🇸 United States',
    flag: '🇺🇸',
    region: 'US West Coast',
    host: 'hil-speed.hetzner.com',
    fallbackHost: 'hil.your-objectstorage.com',
    port: 80,
    optimalFor: 'North American West'
  }
];

function pingHost(host, port = 80, timeoutMs = 2500) {
  return new Promise((resolve) => {
    const start = Date.now();
    const socket = new net.Socket();
    let settled = false;

    const cleanup = () => {
      if (!socket.destroyed) socket.destroy();
    };

    socket.setTimeout(timeoutMs);

    socket.connect(port, host, () => {
      if (!settled) {
        settled = true;
        const latency = Date.now() - start;
        cleanup();
        resolve(latency);
      }
    });

    socket.on('timeout', () => {
      if (!settled) {
        settled = true;
        cleanup();
        resolve(9999);
      }
    });

    socket.on('error', () => {
      if (!settled) {
        settled = true;
        cleanup();
        resolve(9999);
      }
    });
  });
}

async function probeLocations(locations = HETZNER_LOCATIONS) {
  const promises = locations.map(async (loc) => {
    let latency = await pingHost(loc.host, loc.port);
    if (latency >= 9999 && loc.fallbackHost) {
      latency = await pingHost(loc.fallbackHost, loc.port);
    }
    let quality = 'poor';
    let qualityBadge = '🔴';
    if (latency < 60) {
      quality = 'great';
      qualityBadge = '🟢';
    } else if (latency < 160) {
      quality = 'good';
      qualityBadge = '🟡';
    }

    return {
      ...loc,
      ping: latency < 9999 ? latency : null,
      pingDisplay: latency < 9999 ? `${latency}ms` : 'Timeout',
      quality,
      qualityBadge
    };
  });

  const results = await Promise.all(promises);
  // Sort from lowest ping to highest
  results.sort((a, b) => {
    const pA = a.ping !== null ? a.ping : 99999;
    const pB = b.ping !== null ? b.ping : 99999;
    return pA - pB;
  });

  return results;
}

module.exports = { probeLocations, HETZNER_LOCATIONS };
