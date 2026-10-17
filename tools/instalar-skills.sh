#!/bin/bash
# Instala ou atualiza as skills de tools/skills.txt em .claude/skills/ (fora do
# git), sempre na versão mais recente de cada repositório.
#
#   tools/instalar-skills.sh            instala o que falta e atualiza se a última
#                                       atualização tiver mais de 7 dias
#   tools/instalar-skills.sh --agora    atualiza tudo agora
#
# Roda sozinho no início de cada sessão do Claude Code (.claude/settings.json).
set -e
RAIZ="$(cd "$(dirname "$0")/.." && pwd)"
DEST="$RAIZ/.claude/skills"
MARCA="$DEST/.atualizado-em"
mkdir -p "$DEST"

falta=0
while read -r repo padrao; do
  [ -z "$repo" ] || [ "${repo#\#}" != "$repo" ] && continue
  ls -d "$DEST"/$(basename "$padrao") >/dev/null 2>&1 || falta=1
done < "$RAIZ/tools/skills.txt"

velho=0
if [ ! -f "$MARCA" ] || [ -n "$(find "$MARCA" -mtime +7 2>/dev/null)" ]; then velho=1; fi

if [ "$1" != "--agora" ] && [ $falta = 0 ] && [ $velho = 0 ]; then
  exit 0
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
while read -r repo padrao; do
  [ -z "$repo" ] || [ "${repo#\#}" != "$repo" ] && continue
  dir="$TMP/$(basename "$repo")"
  git clone -q --depth 1 "$repo" "$dir"
  for origem in "$dir"/$padrao; do
    [ -d "$origem" ] || continue
    nome="$(basename "$origem")"
    rm -rf "$DEST/$nome"
    cp -R "$origem" "$DEST/$nome"
    rm -rf "$DEST/$nome/scripts/tests"
    echo "$repo @ $(git -C "$dir" rev-parse --short HEAD)" > "$DEST/$nome/ORIGEM.txt"
    echo "✔ $nome ($(git -C "$dir" rev-parse --short HEAD))"
  done
done < "$RAIZ/tools/skills.txt"
touch "$MARCA"
