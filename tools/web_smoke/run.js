const fs = require("node:fs");
const http = require("node:http");
const path = require("node:path");
const { chromium } = require("playwright");

const root = path.resolve(__dirname, "..", "..");
const artifactDir = path.join(root, "artifacts", "web-smoke");
const screenshotPath = path.join(artifactDir, "web-export.png");
const webRoot = path.join(root, "build", "web");
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
    viewport: { width: 1280, height: 720 },
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
    // Godot's Web loader may cancel an initial pack request after issuing a
    // replacement range request. Treat only that narrow, successful-loader
    // cancellation as benign; all other network failures remain fatal.
    if (
      errorText === "net::ERR_ABORTED" &&
      ["index.js", "index.wasm", "index.pck"].some((asset) =>
        requestUrl.endsWith(asset),
      )
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
      for (const asset of ["index.js", "index.wasm", "index.pck"]) {
        const response = await fetch(asset, {
          method: "HEAD",
          cache: "no-store",
        });
        results[asset] = response.status;
      }
      return results;
    });

    await page.screenshot({ path: screenshotPath, fullPage: true });

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
