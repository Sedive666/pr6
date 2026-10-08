// Управление Chrome по протоколу DevTools без внешних зависимостей:
// в Node 22 класс WebSocket уже встроен, устанавливать пакеты не требуется.
import { spawn } from 'node:child_process';
import { mkdtempSync, rmSync, existsSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

const CHROME_CANDIDATES = [
  'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe',
  'C:\\Program Files (x86)\\Google\\Chrome\\Application\\chrome.exe',
  'C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe',
  '/usr/bin/google-chrome',
  '/usr/bin/chromium',
];

export function findChrome() {
  const found = CHROME_CANDIDATES.find((p) => existsSync(p));
  if (!found) throw new Error('Chrome не найден');
  return found;
}

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

/** Запускает Chrome с чистым профилем и подключается к нему. */
export async function launchChrome({ port = 9333, windowSize = '1280,900', headless = true } = {}) {
  const profile = mkdtempSync(join(tmpdir(), 'pr6-chrome-'));
  const bin = findChrome();
  const child = spawn(
    bin,
    [
      ...(headless ? ['--headless=new'] : []),
      `--remote-debugging-port=${port}`,
      `--user-data-dir=${profile}`,
      `--window-size=${windowSize}`,
      '--no-first-run',
      '--no-default-browser-check',
      '--disable-extensions',
      '--hide-scrollbars',
      '--disable-features=TranslateUI',
      'about:blank',
    ],
    { stdio: 'ignore' },
  );

  let version = null;
  for (let i = 0; i < 100 && !version; i++) {
    try {
      version = await (await fetch(`http://127.0.0.1:${port}/json/version`)).json();
    } catch {
      await sleep(100);
    }
  }
  if (!version) throw new Error('Chrome не ответил на отладочном порту');

  const browser = await connect(version.webSocketDebuggerUrl);
  return {
    browser,
    close: async () => {
      try {
        await browser.send('Browser.close');
      } catch {}
      browser.socket.close();
      child.kill();
      await sleep(200);
      try {
        rmSync(profile, { recursive: true, force: true });
      } catch {}
    },
  };
}

/** Одно соединение на весь браузер; вкладки различаются по sessionId. */
async function connect(url) {
  const socket = new WebSocket(url);
  await new Promise((res, rej) => {
    socket.addEventListener('open', res, { once: true });
    socket.addEventListener('error', rej, { once: true });
  });

  let nextId = 1;
  const pending = new Map();
  const handlers = new Set();

  socket.addEventListener('message', (event) => {
    const msg = JSON.parse(event.data);
    if (msg.id && pending.has(msg.id)) {
      const { resolve, reject } = pending.get(msg.id);
      pending.delete(msg.id);
      msg.error ? reject(new Error(JSON.stringify(msg.error))) : resolve(msg.result);
      return;
    }
    for (const h of handlers) h(msg);
  });

  const send = (method, params = {}, sessionId) =>
    new Promise((resolve, reject) => {
      const id = nextId++;
      pending.set(id, { resolve, reject });
      socket.send(JSON.stringify({ id, method, params, sessionId }));
    });

  return {
    socket,
    send,
    on: (fn) => handlers.add(fn),
    off: (fn) => handlers.delete(fn),
  };
}

/** Открывает новую вкладку и возвращает обёртку с её sessionId. */
export async function newPage(browser) {
  const { targetId } = await browser.send('Target.createTarget', { url: 'about:blank' });
  const { sessionId } = await browser.send('Target.attachToTarget', {
    targetId,
    flatten: true,
  });
  return {
    targetId,
    sessionId,
    send: (method, params) => browser.send(method, params, sessionId),
    on: (fn) => browser.on((msg) => (msg.sessionId === sessionId ? fn(msg) : undefined)),
    close: () => browser.send('Target.closeTarget', { targetId }),
  };
}

/** Ждёт, пока выражение в странице не вернёт значение, отличное от null. */
export async function waitFor(page, expression, timeoutMs = 60000) {
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    const { result } = await page.send('Runtime.evaluate', {
      expression,
      returnByValue: true,
    });
    if (result.value !== null && result.value !== undefined && result.value !== false) {
      return result.value;
    }
    await sleep(100);
  }
  return null;
}

export { sleep };
