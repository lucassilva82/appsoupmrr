#!/bin/bash
# Instala ou atualiza as skills de tools/skills.txt em .claude/skills/ (fora do
# git). Sem commit na terceira coluna, baixa a versão mais recente do
# repositório; com commit, baixa exatamente aquele (a versão conferida).
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

# Lista mudou desde a última instalação (ou nunca instalou): instala agora.
LISTA="$DEST/.lista"
falta=0
cmp -s "$RAIZ/tools/skills.txt" "$LISTA" || falta=1

velho=0
if [ ! -f "$MARCA" ] || [ -n "$(find "$MARCA" -mtime +7 2>/dev/null)" ]; then velho=1; fi

if [ "$1" != "--agora" ] && [ $falta = 0 ] && [ $velho = 0 ]; then
  exit 0
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
while read -r repo padrao commit; do
  [ -z "$repo" ] || [ "${repo#\#}" != "$repo" ] && continue
  # Um clone por repositório e commit, reaproveitado pelas linhas seguintes.
  dir="$TMP/$(echo "$repo" | tr -c 'A-Za-z0-9' _)${commit:+-$commit}"
  if [ ! -d "$dir" ]; then
    if [ -n "$commit" ]; then
      git init -q "$dir"
      git -C "$dir" fetch -q --depth 1 "$repo" "$commit"
      git -C "$dir" checkout -q FETCH_HEAD
    else
      git clone -q --depth 1 "$repo" "$dir"
    fi
  fi
  achou=0
  for origem in "$dir"/$padrao; do
    [ -d "$origem" ] || continue
    achou=1
    # Nome declarado no SKILL.md (algumas pastas se chamam só "ios" ou "web").
    nome="$(sed -n 's/^name:[[:space:]]*//p' "$origem/SKILL.md" 2>/dev/null | head -1 | tr -d '"'"'"'\r')"
    case "$nome" in ''|*[!a-z0-9-]*) nome="$(basename "$origem")" ;; esac
    rm -rf "$DEST/$nome"
    cp -R "$origem" "$DEST/$nome"
    rm -rf "$DEST/$nome/scripts/tests"
    echo "$repo @ $(git -C "$dir" rev-parse --short HEAD)" > "$DEST/$nome/ORIGEM.txt"
    echo "$nome" >> "$TMP/instaladas"
    echo "✔ $nome ($(git -C "$dir" rev-parse --short HEAD))"
  done
  [ $achou = 1 ] || echo "⚠ $padrao não existe mais em $repo${commit:+ @ $commit}" >&2
done < "$RAIZ/tools/skills.txt"

# Skill que saiu da lista não pode continuar valendo: apaga as instaladas por
# este script (têm ORIGEM.txt) que não vieram agora. Outras pastas ficam.
for d in "$DEST"/*/; do
  nome="$(basename "$d")"
  [ -f "$d/ORIGEM.txt" ] || continue
  grep -qx "$nome" "$TMP/instaladas" 2>/dev/null && continue
  rm -rf "$d"
  echo "✘ $nome (saiu de tools/skills.txt)"
done
cp "$RAIZ/tools/skills.txt" "$LISTA"
touch "$MARCA"
