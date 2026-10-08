"""Статический сервер для проверки релизной сборки.

Простой файловый сервер не подходит для проверки: маршрутизацию выполняет
приложение, а не сервер, поэтому обновление страницы на внутреннем экране
вида /sneakers/1 даёт 404 — такого файла на диске нет. Этот сервер отдаёт на
неизвестный путь index.html, как это делает настоящий хостинг (а на GitHub
Pages ту же роль играет копия index.html под именем 404.html).

Ответы сжимаются gzip, как на хостинге: иначе измеренный объём загрузки
оказывается в три-четыре раза больше настоящего.

    py tools/serve.py 5555 build/web
"""

import gzip
import mimetypes
import os
import sys
from http.server import HTTPServer, SimpleHTTPRequestHandler

mimetypes.add_type("application/wasm", ".wasm")
mimetypes.add_type("text/javascript", ".js")
mimetypes.add_type("text/javascript", ".mjs")
mimetypes.add_type("application/json", ".json")
mimetypes.add_type("text/plain", ".symbols")

COMPRESSIBLE = (
    "text/",
    "text/javascript",
    "application/json",
    "application/wasm",
    "image/svg+xml",
)


class Handler(SimpleHTTPRequestHandler):
    root = "build/web"
    isolate = False

    def translate_path(self, path):
        rel = path.split("?", 1)[0].split("#", 1)[0].lstrip("/")
        full = os.path.join(self.root, rel)
        if rel == "" or os.path.isdir(full):
            return os.path.join(self.root, "index.html")
        if not os.path.exists(full):
            # Путь разбирает приложение: отдаём ему оболочку страницы.
            return os.path.join(self.root, "index.html")
        return full

    def do_GET(self):
        full = self.translate_path(self.path)
        try:
            with open(full, "rb") as f:
                body = f.read()
        except OSError:
            self.send_error(404)
            return

        ctype = self.guess_type(full)
        accepts_gzip = "gzip" in self.headers.get("Accept-Encoding", "")
        gzipped = accepts_gzip and ctype.startswith(COMPRESSIBLE)
        if gzipped:
            body = gzip.compress(body, 6)

        self.send_response(200)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(body)))
        if gzipped:
            self.send_header("Content-Encoding", "gzip")
        self.send_header("Cache-Control", "no-store")
        # Сборка на WebAssembly использует многопоточную отрисовку skwasm,
        # а она работает только в изолированном источнике. Обычной сборке эти
        # заголовки, наоборот, мешают: под ними браузер отказывается грузить
        # отложенные части кода, и приложение падает при открытии раздела.
        if Handler.isolate:
            self.send_header("Cross-Origin-Opener-Policy", "same-origin")
            self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *args):
        pass


def main():
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 5555
    Handler.root = sys.argv[2] if len(sys.argv) > 2 else "build/web"
    Handler.isolate = "--isolate" in sys.argv
    print(f"http://127.0.0.1:{port}/  ->  {Handler.root}", flush=True)
    HTTPServer(("127.0.0.1", port), Handler).serve_forever()


if __name__ == "__main__":
    main()
