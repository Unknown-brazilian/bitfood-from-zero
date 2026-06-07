#!/usr/bin/env bash
# Builda os 3 APKs release (assinados) e copia pra release/bitfood-<app>-v<VER>.apk
set -e
ROOT="$HOME/Desktop/bitfood"
VER="1.4.4"
GOOGLE_WEB_ID="$(cat "$ROOT/.google-web-client-id" 2>/dev/null || echo '')"
mkdir -p "$ROOT/release"

for app in customer restaurant rider; do
  echo "════════ [$app] flutter pub get ════════"
  cd "$ROOT/apps/$app"
  flutter pub get
  echo "════════ [$app] flutter build apk --release (Google: ${GOOGLE_WEB_ID:+configurado}) ════════"
  flutter build apk --release --dart-define=GOOGLE_SERVER_CLIENT_ID="$GOOGLE_WEB_ID"
  cp build/app/outputs/flutter-apk/app-release.apk "$ROOT/release/bitfood-$app-v$VER.apk"
  echo "════════ [$app] OK → release/bitfood-$app-v$VER.apk ════════"
done
echo "✅ TODOS OS BUILDS CONCLUÍDOS"
ls -la "$ROOT/release/"*.apk