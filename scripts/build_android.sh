#!/usr/bin/env sh
set -eu

echo "[1/5] Verificando Flutter"
flutter --version

echo "[2/5] Descargando dependencias"
flutter pub get

echo "[3/5] Analizando proyecto"
flutter analyze

echo "[4/5] Ejecutando prueba rápida"
flutter test

echo "[5/5] Generando APK release"
flutter build apk --release

echo "APK generado en build/app/outputs/flutter-apk/"
