import fs from 'node:fs/promises';
import path from 'node:path';
import { chromium } from 'playwright';

const baseUrl = process.env.WEB_BASE_URL || process.argv[2] || 'http://localhost:3000';
const outDir = process.env.WEB_ROUTE_OUT_DIR || path.resolve(process.cwd(), '..', 'output', 'playwright');
const routeBootstrapDelayMs = Number(process.env.WEB_ROUTE_BOOTSTRAP_DELAY_MS || 5500);

const publicRoutes = ['/', '/search', '/login', '/help', '/about', '/security'];
const protectedRoutes = ['/reservations', '/messages', '/profile', '/create-trip'];

function normalizePath(urlString) {
  try {
    return new URL(urlString).pathname;
  } catch {
    return '';
  }
}

function normalizeQuery(urlString) {
  try {
    return new URL(urlString).searchParams;
  } catch {
    return new URLSearchParams();
  }
}

async function waitForStableUrl(page, {
  timeoutMs = 12000,
  settleMs = 1200,
  pollMs = 250,
} = {}) {
  const startedAt = Date.now();
  let previousUrl = page.url();
  let unchangedForMs = 0;

  while (Date.now() - startedAt < timeoutMs) {
    await page.waitForTimeout(pollMs);
    const nextUrl = page.url();
    if (nextUrl == previousUrl) {
      unchangedForMs += pollMs;
      if (unchangedForMs >= settleMs) {
        return nextUrl;
      }
      continue;
    }
    previousUrl = nextUrl;
    unchangedForMs = 0;
  }

  return page.url();
}

(async () => {
  await fs.mkdir(outDir, { recursive: true });

  const browser = await chromium.launch({ headless: true });
  const context = await browser.newContext({ viewport: { width: 1440, height: 900 } });
  const page = await context.newPage();

  const checks = [];

  for (const route of publicRoutes) {
    const targetUrl = `${baseUrl}${route}`;
    await page.goto(targetUrl, { waitUntil: 'domcontentloaded', timeout: 60000 });
    await page.waitForTimeout(routeBootstrapDelayMs);
    await waitForStableUrl(page, { timeoutMs: 8000 });

    const finalUrl = page.url();
    const finalPath = normalizePath(finalUrl);
    const pass = finalPath === route;

    const fileName = `route-public-${route.replaceAll('/', '_') || 'root'}.png`;
    await page.screenshot({ path: path.join(outDir, fileName), fullPage: true });

    checks.push({
      type: 'public',
      route,
      targetUrl,
      finalUrl,
      pass,
    });
  }

  for (const route of protectedRoutes) {
    const targetUrl = `${baseUrl}${route}`;
    await page.goto(targetUrl, { waitUntil: 'domcontentloaded', timeout: 60000 });
    await page.waitForTimeout(routeBootstrapDelayMs);
    await waitForStableUrl(page, { timeoutMs: 8000 });

    const finalUrl = page.url();
    const finalPath = normalizePath(finalUrl);
    const query = normalizeQuery(finalUrl);
    const next = query.get('next') || '';
    const pass = finalPath === '/login' && decodeURIComponent(next).startsWith(route);

    const fileName = `route-protected-${route.replaceAll('/', '_')}.png`;
    await page.screenshot({ path: path.join(outDir, fileName), fullPage: true });

    checks.push({
      type: 'protected',
      route,
      targetUrl,
      finalUrl,
      pass,
      next,
    });
  }

  const passed = checks.every((check) => check.pass);
  const report = {
    generatedAt: new Date().toISOString(),
    baseUrl,
    passed,
    checks,
  };

  const reportPath = path.join(outDir, 'web-route-check-report.json');
  await fs.writeFile(reportPath, JSON.stringify(report, null, 2), 'utf8');

  await browser.close();

  console.log(JSON.stringify({ passed, reportPath }, null, 2));
  if (!passed) {
    process.exitCode = 1;
  }
})();
