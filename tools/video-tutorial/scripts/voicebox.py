#!/usr/bin/env python3
"""Gera fala pelo Voicebox local (http://127.0.0.1:17493).

  python3 scripts/voicebox.py <perfil_id> <engine> <saida.wav> "texto" [instrucao]
"""
import json, sys, time, urllib.request

B = 'http://127.0.0.1:17493'


def req(metodo, caminho, corpo=None):
    r = urllib.request.Request(B + caminho, method=metodo,
                               data=json.dumps(corpo).encode() if corpo is not None else None,
                               headers={'Content-Type': 'application/json'})
    with urllib.request.urlopen(r, timeout=600) as resp:
        return resp.read()


def gerar(perfil, engine, texto, saida, instrucao=None, seed=7):
    corpo = {'profile_id': perfil, 'text': texto, 'language': 'pt', 'engine': engine, 'seed': seed, 'normalize': True}
    if engine.startswith('qwen'):
        corpo['model_size'] = '1.7B'
    if instrucao:
        corpo['instruct'] = instrucao
    g = json.loads(req('POST', '/generate', corpo))
    gid = g['id']
    for _ in range(600):
        st = json.loads(req('GET', f'/history/{gid}'))
        estado = st.get('status')
        if estado in ('completed', 'complete', 'done'):
            break
        if estado in ('failed', 'error', 'cancelled'):
            raise SystemExit(f'falhou: {st}')
        time.sleep(1)
    open(saida, 'wb').write(req('GET', f'/audio/{gid}'))
    return gid


if __name__ == '__main__':
    perfil, engine, saida, texto = sys.argv[1:5]
    gerar(perfil, engine, texto, saida, sys.argv[5] if len(sys.argv) > 5 else None)
    print(saida)
