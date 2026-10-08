// Снимки экранов для отчёта: каждый экран при четырёх значениях ширины.
//
//   node api/mock-server.js --port 8080
//   py tools/serve.py 5555 build/web
//   node tools/capture.mjs --url http://127.0.0.1:5555
//   py tools/compose.py
//
// Вход выполняется не через поля формы, а запросом к серверу: ответ с токенами
// кладётся в localStorage под теми же ключами, которые использует
// AuthNotifier (приставку flutter. добавляет shared_preferences на вебе).
// После перехода приложение восстанавливает сессию само.
import { mkdirSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import { launchChrome, newPage, waitFor, sleep } from './cdp.mjs';

function arg(name, fallback) {
  const i = process.argv.indexOf(`--${name}`);
  return i >= 0 && process.argv[i + 1] ? process.argv[i + 1] : fallback;
}

const base = arg('url', 'http://127.0.0.1:5555').replace(/\/$/, '');
const api = arg('api', 'http://localhost:8080/api');
const outDir = arg('out', 'отчёт/screenshots');

const CREDENTIALS = {
  admin: ['admin', 'admin123'],
  manager: ['manager', 'manager123'],
  client: ['client', 'client123'],
};

// Ширина окна и высота, при которой экран виден целиком.
const SIZES = [
  { width: 360, height: 780 },
  { width: 768, height: 1024 },
  { width: 1280, height: 820 },
  { width: 1920, height: 1000 },
];

// Экраны отчёта: имя файла, адрес и роль, под которой экран снимается.
const SCREENS = [
  { name: '1-vhod', path: '/login', role: null },
  { name: '2-glavnaya-admin', path: '/admin/stats', role: 'admin' },
  { name: '3-spisok-krossovok', path: '/sneakers', role: 'manager' },
  { name: '4-kartochka-krossovok', path: '/sneakers/1', role: 'manager' },
  { name: '5-forma-izmeneniya', path: '/sneakers/1/edit', role: 'manager' },
  { name: '6-spisok-pokupatelei', path: '/customers', role: 'manager' },
];

function signInScript(role) {
  const [login, password] = CREDENTIALS[role];
  return `(async () => {
    const r = await fetch('${api}/auth/login', {
      method: 'POST',
      headers: {'Content-Type': 'application/json'},
      body: JSON.stringify({login: '${login}', password: '${password}'}),
    });
    if (!r.ok) return 'сервер ответил ' + r.status;
    const d = await r.json();
    const now = new Date().toISOString();
    localStorage.setItem('flutter.auth_access_token', d.accessToken);
    localStorage.setItem('flutter.auth_refresh_token', d.refreshToken);
    localStorage.setItem('flutter.auth_user', JSON.stringify(d.user));
    localStorage.setItem('flutter.auth_login_at', now);
    localStorage.setItem('flutter.auth_last_activity', now);
    return 'ok';
  })()`;
}

const { browser, close } = await launchChrome({ windowSize: '1920,1080', headless: false });
try {
  const page = await newPage(browser);
  await page.send('Page.enable');
  await page.send('Runtime.enable');
  // Отметка первого кадра: по ней видно, что приложение успело отрисоваться
  // и на снимок не попадёт экран-заглушка.
  await page.send('Page.addScriptToEvaluateOnNewDocument', {
    source: `
      window.__ready = null;
      window.addEventListener('flutter-first-frame', () => { window.__ready = true; });
    `,
  });

  await page.send('Page.navigate', { url: `${base}/` });
  await waitFor(page, 'window.location.origin');

  mkdirSync(outDir, { recursive: true });
  let currentRole = 'нет';

  for (const screen of SCREENS) {
    const role = screen.role ?? 'нет';
    if (role !== currentRole) {
      const expression =
        screen.role === null
          ? `(async () => { localStorage.clear(); return 'ok'; })()`
          : signInScript(screen.role);
      const r = await page.send('Runtime.evaluate', {
        expression,
        awaitPromise: true,
        returnByValue: true,
      });
      if (r.result.value !== 'ok') {
        throw new Error(`смена роли не удалась: ${r.result.value}. Запущен ли ${api}?`);
      }
      currentRole = role;
    }

    for (const { width, height } of SIZES) {
      await page.send('Emulation.setDeviceMetricsOverride', {
        width,
        height,
        deviceScaleFactor: 1,
        mobile: width < 600,
      });
      await page.send('Page.navigate', { url: `${base}${screen.path}` });
      await waitFor(page, 'window.__ready', 30000);
      // Даём приложению дорисовать данные, пришедшие с сервера.
      await sleep(1800);
      const { data } = await page.send('Page.captureScreenshot', {
        format: 'png',
        captureBeyondViewport: false,
      });
      const file = join(outDir, `${screen.name}-${width}.png`);
      writeFileSync(file, Buffer.from(data, 'base64'));
      console.log(file);
    }
  }
  await page.close();
} finally {
  await close();
}
