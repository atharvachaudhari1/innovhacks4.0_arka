const http = require('http');
const fs = require('fs');
const path = require('path');
const os = require('os');

const PORT = process.env.PORT || 3000;
const PUBLIC_DIR = path.join(__dirname, 'public');

const MIME_TYPES = {
  '.html': 'text/html; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.js': 'application/javascript; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.gif': 'image/gif',
  '.svg': 'image/svg+xml',
  '.ico': 'image/x-icon',
  '.apk': 'application/vnd.android.package-archive',
  '.woff2': 'font/woff2',
  '.woff': 'font/woff',
  '.ttf': 'font/ttf'
};

function getLocalIpAddresses() {
  const interfaces = os.networkInterfaces();
  const addresses = [];
  for (const name of Object.keys(interfaces)) {
    for (const net of interfaces[name]) {
      if (net.family === 'IPv4' && !net.internal) {
        addresses.push({ name, ip: net.address });
      }
    }
  }
  return addresses;
}

const server = http.createServer((req, res) => {
  const parsedUrl = new URL(req.url, `http://${req.headers.host}`);
  let pathname = decodeURIComponent(parsedUrl.pathname);

  // CORS headers
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS');

  if (req.method === 'OPTIONS') {
    res.writeHead(204);
    res.end();
    return;
  }

  // Cloud & DigitalOcean health check endpoints
  if (pathname === '/health' || pathname === '/healthz') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ status: 'ok', uptime: process.uptime(), timestamp: new Date().toISOString() }));
    return;
  }

  // API endpoint for network info
  if (pathname === '/api/info') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({
      appName: 'FitGuru AI Coach',
      hackathon: 'Innovhacks 4.0',
      version: '1.0.0',
      port: PORT,
      ipAddresses: getLocalIpAddresses(),
      apkAvailable: fs.existsSync(path.join(PUBLIC_DIR, 'downloads', 'app-debug.apk'))
    }));
    return;
  }

  // Dedicated APK download endpoint
  if (pathname === '/download-apk') {
    const localApk = path.join(PUBLIC_DIR, 'downloads', 'app-debug.apk');
    const rootApk = path.join(__dirname, '..', 'apk', 'FitGuru-Innovhacks4.apk');
    const targetApk = fs.existsSync(localApk) ? localApk : (fs.existsSync(rootApk) ? rootApk : null);

    if (targetApk) {
      const stat = fs.statSync(targetApk);
      res.writeHead(200, {
        'Content-Type': 'application/vnd.android.package-archive',
        'Content-Disposition': 'attachment; filename="FitGuru-Innovhacks4.0-debug.apk"',
        'Content-Length': stat.size
      });
      const stream = fs.createReadStream(targetApk);
      stream.pipe(res);
      return;
    } else {
      // Graceful fallback: Redirect cloud users directly to the GitHub-hosted APK
      res.writeHead(302, {
        'Location': 'https://github.com/atharvachaudhari1/innovhacks4.0-demo/raw/main/apk/FitGuru-Innovhacks4.apk'
      });
      res.end();
      return;
    }
  }

  // Map root to index.html
  if (pathname === '/' || pathname === '') {
    pathname = '/index.html';
  }

  const safePath = path.normalize(pathname).replace(/^(\.\.[\/\\])+/, '');
  const filePath = path.resolve(PUBLIC_DIR, '.' + path.sep + safePath);

  if (!filePath.startsWith(PUBLIC_DIR)) {
    res.writeHead(403, { 'Content-Type': 'text/plain' });
    res.end('403 Forbidden');
    return;
  }

  // Check if file exists
  fs.stat(filePath, (err, stats) => {
    if (err || !stats.isFile()) {
      // Fallback to index.html for SPA routes
      const indexPath = path.join(PUBLIC_DIR, 'index.html');
      fs.readFile(indexPath, (indexErr, data) => {
        if (indexErr) {
          res.writeHead(404, { 'Content-Type': 'text/plain' });
          res.end('404 Not Found');
        } else {
          res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
          res.end(data);
        }
      });
      return;
    }

    const ext = path.extname(filePath).toLowerCase();
    const contentType = MIME_TYPES[ext] || 'application/octet-stream';

    // Ranged streaming for video/binary files
    const range = req.headers.range;
    if (range && (ext === '.mp4' || ext === '.apk')) {
      const parts = range.replace(/bytes=/, '').split('-');
      const start = parseInt(parts[0], 10);
      const end = parts[1] ? parseInt(parts[1], 10) : stats.size - 1;
      const chunksize = (end - start) + 1;
      const fileStream = fs.createReadStream(filePath, { start, end });

      res.writeHead(206, {
        'Content-Range': `bytes ${start}-${end}/${stats.size}`,
        'Accept-Ranges': 'bytes',
        'Content-Length': chunksize,
        'Content-Type': contentType
      });
      fileStream.pipe(res);
    } else {
      res.writeHead(200, {
        'Content-Type': contentType,
        'Content-Length': stats.size,
        'Cache-Control': 'no-cache'
      });
      const fileStream = fs.createReadStream(filePath);
      fileStream.pipe(res);
    }
  });
});

server.listen(PORT, '0.0.0.0', () => {
  const addresses = getLocalIpAddresses();
  console.log(`=======================================================`);
  console.log(`🚀 FitGuru AI Coach Web Server is running (Innovhacks 4.0)!`);
  console.log(`💻 Local access:      http://localhost:${PORT}`);
  addresses.forEach(addr => {
    console.log(`📱 Mobile/LAN access: http://${addr.ip}:${PORT} (${addr.name})`);
  });
  console.log(`📥 Download APK:      http://localhost:${PORT}/download-apk`);
  console.log(`=======================================================`);
});
