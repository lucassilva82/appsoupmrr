#!/bin/bash
# Prepara o projeto: dependências, logos e fontes do app, efeitos sonoros e
# o link para as gravações (que ficam em videos-tutoriais/, fora do git).
set -e
cd "$(dirname "$0")/.."
npm install --no-audit --no-fund
mkdir -p public/img public/audio public/sfx ../../videos-tutoriais/gravacoes
cp ../../assets/imagens/{iconesoupm.png,logo_dti.jpeg,rodape_marcas.png,entradacapa.png,logo_pmrr.png} public/img/
cp ../../assets/fonts/Lato-*.ttf public/img/
for f in whoosh whip mouse-click ding switch; do
  [ -f public/sfx/$f.wav ] || curl -sSL -o public/sfx/$f.wav https://remotion.media/$f.wav
done
ln -sfn ../../../videos-tutoriais/gravacoes public/gravacoes
# Python: OpenCV (análise de quadros) e edge-tts (voz) num venv próprio.
[ -d .venv ] || python3 -m venv .venv
.venv/bin/pip install -q opencv-python-headless numpy edge-tts
