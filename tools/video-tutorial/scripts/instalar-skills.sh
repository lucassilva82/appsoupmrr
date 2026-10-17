#!/bin/bash
# Baixa as skills oficiais do Remotion (remotion-dev/skills) para .claude/skills/
# na raiz do repositório, onde o Claude Code as encontra. Elas não são
# versionadas aqui (o repositório delas não declara licença); ficam fixadas no
# commit usado no vídeo de 17/10/2026.
#
# O instalador oficial (`npx skills add remotion-dev/skills`) exige Node 22+;
# este script faz o mesmo só com git.
set -e
COMMIT=1441a11e95db35443bd76bb318386c0d3ca00053
RAIZ="$(cd "$(dirname "$0")/../../.." && pwd)"
TMP="$(mktemp -d)"
git clone -q https://github.com/remotion-dev/skills "$TMP/skills"
git -C "$TMP/skills" checkout -q "$COMMIT"
mkdir -p "$RAIZ/.claude/skills"
for s in "$TMP"/skills/skills/remotion-*; do
  rm -rf "$RAIZ/.claude/skills/$(basename "$s")"
  cp -R "$s" "$RAIZ/.claude/skills/"
done
rm -rf "$TMP"
ls "$RAIZ/.claude/skills"
