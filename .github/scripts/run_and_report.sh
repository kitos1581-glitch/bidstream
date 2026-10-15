#!/usr/bin/env bash
# Ejecuta un comando; si falla, publica en anotaciones de error SOLO las
# líneas relevantes (filtro regex), en bloques de ~3500 caracteres
# (GitHub recorta mensajes largos). Conserva el código de salida.
# Uso: run_and_report.sh "Título" "regex-filtro" comando args...
title="$1"; filter="$2"; shift 2
out="$(mktemp)"
"$@" 2>&1 | tee "$out"
code=${PIPESTATUS[0]}
if [ "$code" -ne 0 ]; then
  rel="$(mktemp)"
  sed -e 's/\x1b\[[0-9;]*m//g' "$out" | grep -E "$filter" > "$rel" || true
  [ -s "$rel" ] || tail -n 60 "$out" > "$rel"
  total=$(wc -l < "$rel")
  part=1; buf=""
  flush() {
    [ -z "$buf" ] && return
    enc="$(printf '%s' "$buf" | sed -e 's/%/%25/g' | sed -e ':a;N;$!ba;s/\r/%0D/g;s/\n/%0A/g')"
    echo "::error title=${title} (${part})::${enc}"
    part=$((part+1)); buf=""
  }
  while IFS= read -r line; do
    line="${line:0:400}"
    if [ $(( ${#buf} + ${#line} )) -gt 3400 ]; then flush; fi
    [ "$part" -gt 9 ] && break
    buf+="${line}"$'\n'
  done < "$rel"
  flush
  echo "::error title=${title} (resumen)::${total} líneas relevantes; código de salida ${code}"
fi
exit "$code"
