// Измерение первой загрузки опубликованной сборки.
//
//   py tools/serve.py 5555 build/web
//   node tools/measure.mjs --url http://127.0.0.1:5555/ --runs 9 --label Обычная
//
// Что считается:
//   «Скачано при входе» — сумма encodedDataLength всех запросов, то есть
//   объём после сжатия gzip, как его видит браузер по сети;
//   «Первая загрузка» — от начала навигации до события flutter-first-frame,
//   которое приложение посылает, нарисовав первый кадр.
//
// Кэш отключён, сеть ограничена 10 Мбит/с с задержкой 40 мс — иначе числа
// зависят от того, насколько прогрет диск, и сравнивать их бессмысленно.
import { launchChrome, newPage, waitFor, sleep } from './cdp.mjs';

function arg(name, fallback) {
  const i = process.argv.indexOf(`--${name}`);
  return i >= 0 && process.argv[i + 1] ? process.argv[i + 1] : fallback;
}

const url = arg('url', 'http://127.0.0.1:5555/');
const runs = Number(arg('runs', 9));
const label = arg('label', 'Сборка');

const THROUGHPUT = (10 * 1024 * 1024) / 8; // 10 Мбит/с в байтах в секунду
const LATENCY = 40;

function median(values) {
  const sorted = [...values].sort((a, b) => a - b);
  const mid = sorted.length >> 1;
  return sorted.length % 2 ? sorted[mid] : (sorted[mid - 1] + sorted[mid]) / 2;
}

async function measureOnce(browser) {
  const page = await newPage(browser);
  const sizes = new Map();
  let bytes = 0;

  page.on((msg) => {
    if (msg.method === 'Network.loadingFinished') {
      bytes += msg.params.encodedDataLength ?? 0;
    }
    if (msg.method === 'Network.responseReceived') {
      const name = msg.params.response.url.split('/').pop().split('?')[0];
      sizes.set(name, msg.params.response.encodedDataLength ?? 0);
    }
  });

  await page.send('Network.enable');
  await page.send('Page.enable');
  await page.send('Runtime.enable');
  await page.send('Network.setCacheDisabled', { cacheDisabled: true });
  await page.send('Network.emulateNetworkConditions', {
    offline: false,
    latency: LATENCY,
    downloadThroughput: THROUGHPUT,
    uploadThroughput: THROUGHPUT,
  });
  await page.send('Page.addScriptToEvaluateOnNewDocument', {
    source: `
      window.__start = performance.now();
      window.__firstFrame = null;
      window.addEventListener('flutter-first-frame', () => {
        window.__firstFrame = performance.now() - window.__start;
      });
    `,
  });

  await page.send('Page.navigate', { url });
  const firstFrame = await waitFor(page, 'window.__firstFrame', 90000);
  // Догрузка того, что приложение запрашивает уже после первого кадра.
  await sleep(500);
  await page.close();
  return { firstFrame, bytes };
}

const { browser, close } = await launchChrome();
try {
  const results = [];
  for (let i = 0; i < runs; i++) {
    const r = await measureOnce(browser);
    results.push(r);
    process.stdout.write(
      `  попытка ${i + 1}/${runs}: ${(r.bytes / 1048576).toFixed(2)} МБ, ` +
        `${r.firstFrame === null ? 'первый кадр не дождались' : (r.firstFrame / 1000).toFixed(2) + ' с'}\n`,
    );
  }
  const frames = results.map((r) => r.firstFrame).filter((v) => v !== null);
  console.log('');
  console.log(`${label}:`);
  console.log(`  скачано при входе: ${(median(results.map((r) => r.bytes)) / 1048576).toFixed(2)} МБ`);
  console.log(
    `  первая загрузка (медиана ${frames.length} из ${runs}): ` +
      (frames.length ? `${(median(frames) / 1000).toFixed(2)} с` : 'нет данных'),
  );
} finally {
  await close();
}
