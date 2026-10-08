#!/bin/bash
# Сборка варианта и измерение первой загрузки. Каждая сборка в своём каталоге,
# чтобы варианты можно было сравнивать и снимать с них скриншоты.
#   bash tools/bench.sh rel-js "Обычная"            -- обычная сборка
#   bash tools/bench.sh rel-wasm "С --wasm" --wasm  -- сборка на WebAssembly
set -e
DIR="build/$1"; LABEL="$2"; shift 2
flutter build web --release -o "$DIR" --dart-define=API_BASE_URL=http://localhost:8080/api "$@" >/dev/null 2>&1
echo "### $LABEL"
echo "каталог: $(du -sm "$DIR" | cut -f1) МБ"
for f in main.dart.js main.dart.wasm; do
  [ -f "$DIR/$f" ] && echo "$f: $(( $(stat -c%s "$DIR/$f") / 1024 )) КБ"
done
PARTS=$(ls "$DIR"/main.dart.js_*.part.js 2>/dev/null | wc -l)
[ "$PARTS" -gt 0 ] && echo "отложенных частей: $PARTS ($(( $(cat "$DIR"/main.dart.js_*.part.js | wc -c) / 1024 )) КБ)"
py tools/serve.py 5599 "$DIR" >/dev/null 2>&1 &
SRV=$!
sleep 2
node tools/measure.mjs --url http://127.0.0.1:5599/ --runs 5 --label "$LABEL" 2>&1 | grep -v "попытка"
kill $SRV 2>/dev/null || true
