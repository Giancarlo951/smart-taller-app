#!/usr/bin/env bash
# Compila la versión web de Smart Taller (la usa vercel.json).
#
# Las claves de Supabase NO están en el repositorio (supabase/claves.json se
# ignora): llegan como variables de entorno del proyecto en Vercel
# (Settings → Environment Variables):
#   SUPABASE_URL   https://<ref>.supabase.co
#   SUPABASE_KEY   la clave publicable (sb_publishable_...), nunca la secreta
#
# Para probarlo en la PC con el Flutter instalado:
#   FLUTTER=flutter SUPABASE_URL=... SUPABASE_KEY=... bash scripts/vercel_compilar.sh
set -euo pipefail

if [ -z "${SUPABASE_URL:-}" ] || [ -z "${SUPABASE_KEY:-}" ]; then
  echo "Faltan SUPABASE_URL y SUPABASE_KEY en las variables de entorno de Vercel." >&2
  echo "Sin ellas la web quedaría en modo demo (datos de ejemplo, sin Supabase)." >&2
  exit 1
fi
case "$SUPABASE_KEY" in
  sb_secret_*)
    echo "SUPABASE_KEY es la clave secreta: usa la publicable (sb_publishable_...)." >&2
    exit 1
    ;;
esac

FLUTTER="${FLUTTER:-flutter/bin/flutter}"
"$FLUTTER" pub get
"$FLUTTER" build web --release --no-wasm-dry-run \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_KEY="$SUPABASE_KEY"
