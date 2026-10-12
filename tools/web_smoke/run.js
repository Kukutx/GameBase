const fs = require("node:fs");
const http = require("node:http");
const path = require("node:path");
const { parseArgs } = require("node:util");
const { chromium } = require("playwright");

const { artifactsPath, buildPath, resolveGame } = require("../lib/games");

// The game comes from --game <id>, else GAMEBASE_GAME, else is the only
// registered one: npm run --prefix tools/web_smoke smoke:web -- --game <id>
const { values: options } = parseArgs({ options: { game: { type: "string" } } });
const game = resolveGame(options.game);
const artifactDir = artifactsPath(game, "web-smoke");
const viewportProfiles = [
  { name: "720p-16x9", width: 1280, height: 720 },
  { name: "xga-4x3", width: 1024, height: 768 },
  { name: "ultrawide-21x9", width: 2560, height: 1080 },
  { name: "small-desktop-4x3", width: 800, height: 600 },
];
const webRoot = buildPath(game, "web");
const host = "127.0.0.1";
const port = Number(process.env.GAMEBASE_WEB_PORT || 8123);

const mimeTypes = {
  ".html": "text/html; charset=utf-8",
  ".js": "text/javascript; charset=utf-8",
  ".wasm": "application/wasm",
  ".pck": "application/octet-stream",
  ".png": "image/png",
  ".svg": "image/svg+xml",
  ".ico": "image/x-icon",
  ".json": "application/json; charset=utf-8",
};

function createStaticServer() {
  if (!fs.existsSync(path.join(webRoot, "index.html"))) {
    throw new Error(
      `Web export is missing: ${path.join(webRoot, "index.html")}`,
    );
  }

  const server = http.createServer((request, response) => {
    try {
      const requestUrl = new URL(request.url || "/", `http://${host}:${port}`);
      const relative = decodeURIComponent(
        requestUrl.pathname === "/" ? "/index.html" : requestUrl.pathname,
      );
      const normalized = path.normalize(relative).replace(/^([/\\])+/, "");
      const filePath = path.resolve(webRoot, normalized);

      if (!filePath.startsWith(webRoot + path.sep) && filePath !== webRoot) {
        response.writeHead(403);
        response.end("Forbidden");
        return;
      }
      if (!fs.existsSync(filePath) || !fs.statSync(filePath).isFile()) {
        response.writeHead(404);
        response.end("Not found");
        return;
      }

      const stat = fs.statSync(filePath);
      const contentType =
        mimeTypes[path.extname(filePath).toLowerCase()] ||
        "application/octet-stream";
      const range = request.headers.range;

      if (range) {
        const match = /^bytes=(\d*)-(\d*)$/.exec(range);
        if (!match) {
          response.writeHead(416, { "Content-Range": `bytes */${stat.size}` });
          response.end();
          return;
        }
        const start = match[1] ? Number(match[1]) : 0;
        const end = match[2] ? Number(match[2]) : stat.size - 1;
        if (start < 0 || end >= stat.size || start > end) {
          response.writeHead(416, { "Content-Range": `bytes */${stat.size}` });
          response.end();
          return;
        }
        response.writeHead(206, {
          "Accept-Ranges": "bytes",
          "Content-Range": `bytes ${start}-${end}/${stat.size}`,
          "Content-Length": end - start + 1,
          "Content-Type": contentType,
          "Cache-Control": "no-store",
        });
        if (request.method === "HEAD") {
          response.end();
        } else {
          fs.createReadStream(filePath, { start, end }).pipe(response);
        }
        return;
      }

      response.writeHead(200, {
        "Content-Length": stat.size,
        "Content-Type": contentType,
        "Cache-Control": "no-store",
        "Accept-Ranges": "bytes",
      });
      if (request.method === "HEAD") {
        response.end();
      } else {
        fs.createReadStream(filePath).pipe(response);
      }
    } catch (error) {
      response.writeHead(500);
      response.end("Server error");
      console.error(error);
    }
  });

  return new Promise((resolve, reject) => {
    server.once("error", reject);
    server.listen(port, host, () => resolve(server));
  });
}

async function main() {
  fs.mkdirSync(artifactDir, { recursive: true });

  let server = null;
  const externalUrl = process.env.GAMEBASE_WEB_URL;
  const url = externalUrl || `http://${host}:${port}/index.html`;
  if (!externalUrl) {
    server = await createStaticServer();
  }

  const browser = await chromium.launch({ headless: true });
  const page = await browser.newPage({
    viewport: {
      width: viewportProfiles[0].width,
      height: viewportProfiles[0].height,
    },
  });
  const consoleErrors = [];
  const pageErrors = [];
  const failedRequests = [];
  const benignAbortedRequests = [];

  page.on("console", (message) => {
    if (message.type() === "error") consoleErrors.push(message.text());
  });
  page.on("pageerror", (error) => pageErrors.push(String(error)));
  page.on("requestfailed", (request) => {
    const errorText = request.failure()?.errorText || "failed";
    const requestUrl = request.url();
    // Godot's Web loader may cancel an initial core-asset request after
    // issuing a replacement range request. Chromium can also report the
    // explicit HEAD probes below as aborted after the 200 response is already
    // available to fetch(). Only these exact resources are eligible; their
    // final HTTP status is still asserted below.
    if (
      errorText === "net::ERR_ABORTED" &&
      [
        "index.js",
        "index.wasm",
        "index.pck",
        "BUILD_INFO.json",
        "THIRD_PARTY_NOTICES.md",
        "licenses/GODOT_LICENSE.txt",
        "licenses/GODOT_VERSION.txt",
      ].some((asset) => requestUrl.endsWith(asset))
    ) {
      benignAbortedRequests.push(requestUrl);
      return;
    }
    failedRequests.push(`${requestUrl} :: ${errorText}`);
  });

  try {
    const response = await page.goto(url, {
      waitUntil: "load",
      timeout: 60000,
    });
    if (!response || !response.ok()) {
      throw new Error(
        `Web export returned HTTP ${response?.status() ?? "no response"}`,
      );
    }

    await page.waitForSelector("canvas", { state: "visible", timeout: 60000 });
    await page.waitForTimeout(5000);

    const state = await page.evaluate(() => {
      const canvas = document.querySelector("canvas");
      const status = document.querySelector("#status");
      const rect = canvas?.getBoundingClientRect();
      return {
        readyState: document.readyState,
        title: document.title,
        engineType: typeof window.Engine,
        canvasWidth: canvas?.width ?? 0,
        canvasHeight: canvas?.height ?? 0,
        cssWidth: rect?.width ?? 0,
        cssHeight: rect?.height ?? 0,
        statusDisplay: status ? getComputedStyle(status).display : "missing",
        statusText: status?.textContent?.trim() ?? "",
      };
    });

    const assetChecks = await page.evaluate(async () => {
      const results = {};
      for (const asset of [
        "index.js",
        "index.wasm",
        "index.pck",
        "BUILD_INFO.json",
        "THIRD_PARTY_NOTICES.md",
        "licenses/GODOT_LICENSE.txt",
        "licenses/GODOT_VERSION.txt",
      ]) {
        const response = await fetch(asset, {
          method: "HEAD",
          cache: "no-store",
        });
        results[asset] = response.status;
      }
      return results;
    });

    const viewportChecks = [];
    for (const profile of viewportProfiles) {
      await page.setViewportSize({
        width: profile.width,
        height: profile.height,
      });
      await page.waitForTimeout(500);
      const viewportState = await page.evaluate(() => {
        const canvas = document.querySelector("canvas");
        const rect = canvas?.getBoundingClientRect();
        return {
          innerWidth: window.innerWidth,
          innerHeight: window.innerHeight,
          canvasWidth: canvas?.width ?? 0,
          canvasHeight: canvas?.height ?? 0,
          cssWidth: rect?.width ?? 0,
          cssHeight: rect?.height ?? 0,
          left: rect?.left ?? 0,
          top: rect?.top ?? 0,
          right: rect?.right ?? 0,
          bottom: rect?.bottom ?? 0,
        };
      });
      viewportChecks.push({ profile, state: viewportState });
      await page.screenshot({
        path: path.join(artifactDir, `web-export-${profile.name}.png`),
        fullPage: true,
      });
    }

    const failures = [];
    if (state.readyState !== "complete")
      failures.push(`document.readyState=${state.readyState}`);
    if (state.engineType !== "function")
      failures.push(`window.Engine type=${state.engineType}`);
    if (
      state.canvasWidth < 1 ||
      state.canvasHeight < 1 ||
      state.cssWidth < 1 ||
      state.cssHeight < 1
    ) {
      failures.push(`invalid canvas size ${JSON.stringify(state)}`);
    }
    if (state.statusDisplay !== "none" && state.statusDisplay !== "missing") {
      failures.push(`Godot status overlay still visible: ${state.statusText}`);
    }
    for (const check of viewportChecks) {
      const { profile, state: viewportState } = check;
      if (
        viewportState.innerWidth !== profile.width ||
        viewportState.innerHeight !== profile.height
      ) {
        failures.push(
          `${profile.name} viewport mismatch ${JSON.stringify(viewportState)}`,
        );
      }
      if (
        viewportState.canvasWidth < 1 ||
        viewportState.canvasHeight < 1 ||
        viewportState.cssWidth < 1 ||
        viewportState.cssHeight < 1
      ) {
        failures.push(
          `${profile.name} canvas has invalid size ${JSON.stringify(viewportState)}`,
        );
      }
      if (
        viewportState.left < -1 ||
        viewportState.top < -1 ||
        viewportState.right > profile.width + 1 ||
        viewportState.bottom > profile.height + 1
      ) {
        failures.push(
          `${profile.name} canvas escapes viewport ${JSON.stringify(viewportState)}`,
        );
      }
    }
    if (consoleErrors.length)
      failures.push(`console errors: ${consoleErrors.join(" | ")}`);
    if (pageErrors.length)
      failures.push(`page errors: ${pageErrors.join(" | ")}`);
    for (const [asset, status] of Object.entries(assetChecks)) {
      if (status !== 200)
        failures.push(`${asset} HEAD returned HTTP ${status}`);
    }
    if (failedRequests.length)
      failures.push(`failed requests: ${failedRequests.join(" | ")}`);

    console.log(
      JSON.stringify(
        {
          state,
          viewportChecks,
          assetChecks,
          consoleErrors,
          pageErrors,
          failedRequests,
          benignAbortedRequests,
        },
        null,
        2,
      ),
    );

    if (failures.length) {
      throw new Error(failures.join("\n"));
    }

    console.log("WEB_BROWSER_SMOKE_OK");
  } finally {
    await browser.close();
    if (server) {
      await new Promise((resolve) => server.close(resolve));
    }
  }
}

main().catch((error) => {
  console.error(error && error.stack ? error.stack : String(error));
  process.exit(1);
});
