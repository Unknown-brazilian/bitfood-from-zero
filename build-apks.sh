#!/usr/bin/env bash
# Builda os 3 APKs release (assinados) e copia pra release/bitfood-<app>-v1.4.2.apk
set -e
ROOT="$HOME/Desktop/bitfood"
VER="1.4.2"
mkdir -p "$ROOT/release"

for app in customer restaurant rider; do
  echo "════════ [$app] flutter pub get ════════"
  cd "$ROOT/apps/$app"
  flutter pub get
  echo "════════ [$app] flutter build apk --release ════════"
  flutter build apk --release
  cp build/app/outputs/flutter-apk/app-release.apk "$ROOT/release/bitfood-$app-v$VER.apk"
  echo "════════ [$app] OK → release/bitfood-$app-v$VER.apk ════════"
done
echo "✅ TODOS OS BUILDS CONCLUÍDOS"
ls -la "$ROOT/release/"*.apk