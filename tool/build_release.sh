#!/usr/bin/env bash
# Build AAB rilis production (siap unggah ke Play Console) dengan obfuscation kode Dart.
#
# - R8 (shrink kode & resource Java/Kotlin) sudah aktif otomatis di build release oleh Flutter Gradle Plugin.
# - --obfuscate mengacak nama kelas/fungsi Dart; --split-debug-info memisahkan simbolnya ke
#   build/symbols/<stempel>. SIMPAN folder itu (backup di luar mesin ini): tanpanya stack trace crash
#   dari build ini tidak bisa dibaca. Unggah juga ke Play Console (App bundle explorer > Downloads >
#   "Native debug symbols" / "Dart symbols" bila diminta).
# - Penandatanganan memakai android/key.properties (tidak ada di git).
#
# Pakai: tool/build_release.sh
set -euo pipefail
cd "$(dirname "$0")/.."

if [ ! -f android/key.properties ]; then
  echo "android/key.properties tidak ada -- build akan ditandatangani kunci DEBUG dan TIDAK bisa diunggah ke Play." >&2
  exit 1
fi

STAMP="$(date +%Y%m%d-%H%M)"
SYMBOLS="build/symbols/$STAMP"
mkdir -p "$SYMBOLS"

flutter build appbundle --release --flavor production --obfuscate --split-debug-info="$SYMBOLS"

AAB="build/app/outputs/bundle/productionRelease/app-production-release.aab"
echo
echo "AAB     : $AAB"
echo "Simbol  : $SYMBOLS  (WAJIB di-backup)"
