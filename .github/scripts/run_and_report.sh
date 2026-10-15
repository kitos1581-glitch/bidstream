#!/usr/bin/env bash
# Ejecuta un comando; si falla, publica su salida como anotación de error
# (visible en la pestaña Actions y por la API), y conserva el código de salida.
# Uso: run_and_report.sh "Título" comando args...
title="$1"; shift
out="$(mktemp)"
"$@" 2>&1 | tee "$out"
code=${PIPESTATUS[0]}
if [ "$code" -ne 0 ]; then
  # Últimos ~55 KB, codificados para la anotación (%, CR, LF).
  body="$(tail -c 55000 "$out" | sed -e 's/%/%25/g' | sed -e ':a;N;$!ba;s/\r/%0D/g;s/\n/%0A/g')"
  echo "::error title=${title}::${body}"
fi
exit "$code"
