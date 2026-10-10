const http = require("http");
const fs = require("fs");
const path = require("path");

const PORT = process.env.PORT || 4173;
const ROOT = __dirname;

const MIME = {
  ".html": "text/html; charset=utf-8",
  ".css": "text/css; charset=utf-8",
  ".js": "application/javascript; charset=utf-8",
  ".json": "application/json; charset=utf-8",
  ".png": "image/png",
  ".jpg": "image/jpeg",
  ".jpeg": "image/jpeg",
  ".webp": "image/webp",
  ".svg": "image/svg+xml",
  ".ico": "image/x-icon",
  ".mp4": "video/mp4",
  ".webm": "video/webm",
  ".apk": "application/vnd.android.package-archive",
  ".ipa": "application/octet-stream",
  ".woff2": "font/woff2",
  ".txt": "text/plain; charset=utf-8",
};

const server = http.createServer((req, res) => {
  const url = new URL(req.url, `http://${req.headers.host}`);
  let filePath = decodeURIComponent(url.pathname);

  if (filePath === "/") filePath = "/index.html";
  if (filePath === "/download-android" || filePath === "/download-apk") {
    filePath = "/downloads/FitGuru-Android.apk";
  }
  if (filePath === "/download-ios") {
    filePath = "/downloads/FitGuru-iOS.ipa";
  }

  const safePath = path.normalize(filePath).replace(/^(\.\.[/\\])+/, "");
  const abs = path.join(ROOT, safePath);

  if (!abs.startsWith(ROOT)) {
    res.writeHead(403);
    res.end("Forbidden");
    return;
  }

  fs.stat(abs, (err, stat) => {
    if (err || !stat.isFile()) {
      if (filePath === "/downloads/FitGuru-iOS.ipa") {
        res.writeHead(404, { "Content-Type": "application/json" });
        res.end(JSON.stringify({
          error: "ios_build_pending",
          message: "Drop FitGuru-iOS.ipa into web-landing/downloads to enable this button.",
        }));
        return;
      }
      res.writeHead(404, { "Content-Type": "text/plain; charset=utf-8" });
      res.end("Not found");
      return;
    }

    const ext = path.extname(abs).toLowerCase();
    const type = MIME[ext] || "application/octet-stream";
    const download = ext === ".apk" || ext === ".ipa";

    res.writeHead(200, {
      "Content-Type": type,
      "Content-Length": stat.size,
      ...(download ? { "Content-Disposition": `attachment; filename="${path.basename(abs)}"` } : {}),
    });
    fs.createReadStream(abs).pipe(res);
  });
});

server.listen(PORT, () => {
  console.log(`FitGuru landing page → http://localhost:${PORT}`);
});
