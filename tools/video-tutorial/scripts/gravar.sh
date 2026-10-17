#!/bin/bash
# Grava a tela do simulador: gravar.sh <udid> <arquivo.mp4>  (Ctrl+C ou kill -INT para parar)
# Ao parar, remuxa para o arquivo ter índice (sem isso o seek falha).
set -e
UDID=$1; SAIDA=$2
xcrun simctl io "$UDID" recordVideo --codec=h264 --force "$SAIDA.tmp.mp4" || true
npx remotion ffmpeg -hide_banner -y -i "$SAIDA.tmp.mp4" -c copy -movflags +faststart "$SAIDA"
rm -f "$SAIDA.tmp.mp4"
