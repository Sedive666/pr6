// Снимки экранов при четырёх значениях ширины для отчёта.
//
//   node api/mock-server.js --port 8080
//   py tools/serve.py 5555 build/rel-js
//   node tools/capture.mjs --url http://127.0.0.1:5555 --role manager
//
// Вход выполняется не через поля формы, а запросом к серверу: ответ с токенами
// кладётся в localStorage под теми же ключами, которые использует
// AuthNotifier (приставку flutter. добавляет shared_preferences на вебе).
// После перезагрузки приложение восстанавливает сессию само.
import { mkdirSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import { launchChrome, newPage, waitFor, sleep } from './cdp.mjs';

function arg(name, fallback) {
  const i = process.argv.indexOf(`--${name}`);
  return i >= 0 && process.argv[i + 1] ? process.argv[i + 1] : fallback;
}

const base = arg('url', 'http://127.0.0.1:5555').replace(/\/$/, '');
const api = arg('api', 'http://localhost:8080/api');
const role = arg('role', 'manager');
const outRoot = arg('out', 'отчёт/screenshots');

const CREDENTIALS = {
  admin: ['admin', 'admin123'],
  manager: ['manager', 'manager123'],
  client: ['client', 'client123'],
};

const WIDTHS = [360, 768, 1280, 1920];

// Экраны: имя файла → адрес. Набор зависит от роли.
const SCREENS = {
  manager: {
    'spisok-krossovok': '/sneakers',
    'kartochka-krossovok': '/sneakers/1',
    'forma-izmeneniya': '/sneakers/1/edit',
    'spisok-zakazov': '/orders',
    'spisok-pokupatelei': '/customers',
    'spisok-brendov': '/brands',
  },
  admin: {
    statistika: '/admin/stats',
    polzovateli: '/admin/users',
    'spisok-krossovok': '/sneakers',
    otzyvy: '/reviews',
  },
  client: {
    'moi-zakazy': '/my/orders',
    'spisok-krossovok': '/sneakers',
    'kartochka-krossovok': '/sneakers/1',
  },
};

const [login, password] = CREDENTIALS[role] ?? CREDENTIALS.manager;
const screens = SCREENS[role] ?? SCREENS.manager;

const signIn = `(async () => {
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

const { browser, close } = await launchChrome({ windowSize: '1920,1080' });
try {
  const page = await newPage(browser);
  await page.send('Page.enable');
  await page.send('Runtime.enable');

  await page.send('Page.navigate', { url: `${base}/` });
  await waitFor(page, 'window.location.origin');
  const signed = await page.send('Runtime.evaluate', {
    expression: signIn,
    awaitPromise: true,
    returnByValue: true,
  });
  if (signed.result.value !== 'ok') {
    throw new Error(`вход не выполнен: ${signed.result.value}. Запущен ли ${api}?`);
  }

  for (const width of WIDTHS) {
    const dir = join(outRoot, String(width));
    mkdirSync(dir, { recursive: true });
    await page.send('Emulation.setDeviceMetricsOverride', {
      width,
      height: width < 600 ? 780 : 900,
      deviceScaleFactor: 2,
      mobile: width < 600,
    });

    for (const [name, path] of Object.entries(screens)) {
      await page.send('Page.navigate', { url: `${base}${path}` });
      // Ждём первый кадр, затем даём приложению дорисовать данные с сервера.
      await waitFor(page, 'window.__ff === undefined ? true : true', 5000);
      await sleep(2200);
      const { data } = await page.send('Page.captureScreenshot', {
        format: 'png',
        captureBeyondViewport: false,
      });
      const file = join(dir, `${role}-${name}.png`);
      writeFileSync(file, Buffer.from(data, 'base64'));
      console.log(`${width} ${path} -> ${file}`);
    }
  }
  await page.close();
} finally {
  await close();
}
