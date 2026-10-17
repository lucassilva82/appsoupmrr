#!/usr/bin/env python3
"""Gera a narração de cada trecho de narracao.json.

  .venv/bin/python scripts/narrar.py edge [ids...]  # Thalita (pt-BR), voz final
  python3 scripts/narrar.py voicebox [ids...]  # Voicebox local (soou robótico e com sotaque de Portugal)
  python3 scripts/narrar.py say [ids...]       # voz do macOS (rascunho)

Saída: public/audio/<id>.wav e src/audio.json com a duração e o tempo de
cada palavra (para a legenda acompanhar a voz).
"""
import array, json, os, re, subprocess, sys, wave

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
AUDIO = os.path.join(RAIZ, 'public', 'audio')
os.makedirs(AUDIO, exist_ok=True)
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

# Perfil "Locutor PMRR (desenhada)" no Voicebox: Qwen3-TTS 1.7B com a descrição
# "locutor brasileiro, voz grave e clara, tom institucional confiante".
PERFIL_VOICEBOX = os.environ.get('VOICEBOX_PERFIL', 'ac53dbd1-cea1-4c1e-b931-f701cdb0d3f2')
TOM_PADRAO = ('Fale em português do Brasil, como locutor de vídeo para redes sociais: '
              'claro, confiante, didático e com ritmo dinâmico.')

# Como a voz deve pronunciar (a legenda mostra o texto original).
PRONUNCIA = {
    'SouPM': 'Sou PM',  # o app se fala "SouPM", nunca "SouPMRR"
    'SIGRH': 'sig erre agá',
}

# Voz neural pt-BR da Microsoft (edge-tts): natural e com o tempo de cada palavra.
VOZ_EDGE = 'pt-BR-ThalitaMultilingualNeural'
VELOCIDADE_EDGE = '+8%'


def falado(texto):
    for k, v in PRONUNCIA.items():
        texto = texto.replace(k, v)
    return texto


def peso(p):
    return len(p) + (6 if re.search(r'[.?!:]$', p) else 3 if p.endswith(',') else 1)


def trechos_de_voz(caminho, limiar=0.02, pausa_min=0.18):
    """Intervalos (início, fim) em segundos em que há voz no WAV."""
    with wave.open(caminho) as w:
        taxa, canais, n = w.getframerate(), w.getnchannels(), w.getnframes()
        amostras = array.array('h', w.readframes(n))
    if canais > 1:
        amostras = amostras[::canais]
    janela = int(taxa * 0.02)
    pico = max(1, max(abs(x) for x in amostras))
    ativos = []
    for i in range(0, len(amostras), janela):
        bloco = amostras[i:i + janela]
        rms = (sum(x * x for x in bloco) / max(1, len(bloco))) ** 0.5 / pico
        ativos.append(rms > limiar)
    segs, ini = [], None
    for i, a in enumerate(ativos + [False]):
        t = i * 0.02
        if a and ini is None:
            ini = t
        elif not a and ini is not None:
            if segs and ini - segs[-1][1] < pausa_min:
                segs[-1][1] = t
            else:
                segs.append([ini, t])
            ini = None
    return [s for s in segs if s[1] - s[0] > 0.06] or [[0.0, len(amostras) / taxa]]


def palavras_pela_voz(texto, segs):
    """Distribui as palavras só pelo tempo com voz, pulando as pausas."""
    pal = texto.split()
    pesos = [peso(p) for p in pal]
    total_voz = sum(b - a for a, b in segs)

    def real(tv):  # tempo "só de voz" → tempo real
        for a, b in segs:
            if tv <= b - a:
                return a + tv
            tv -= b - a
        return segs[-1][1]

    acc, saida = 0.0, []
    for p, w in zip(pal, pesos):
        d = total_voz * w / sum(pesos)
        saida.append({'p': p, 'i': round(real(acc + 0.001), 3), 'f': round(real(acc + d), 3)})
        acc += d
    return saida


def duracao_wav(caminho):
    with wave.open(caminho) as w:
        return w.getnframes() / w.getframerate()


def com_say(item):
    aiff = os.path.join(AUDIO, item['id'] + '.aiff')
    wav = os.path.join(AUDIO, item['id'] + '.wav')
    subprocess.run(['say', '-v', 'Luciana', '-r', '190', '-o', aiff, falado(item['texto'])], check=True)
    subprocess.run(['afconvert', '-f', 'WAVE', '-d', 'LEI16@44100', aiff, wav], check=True)
    os.remove(aiff)
    return wav


def com_voicebox(item):
    from voicebox import gerar
    wav = os.path.join(AUDIO, item['id'] + '.wav')
    tom = item.get('tom', TOM_PADRAO)
    for tentativa in range(4):  # o MLX às vezes falha ("no Stream in current thread")
        try:
            gerar(PERFIL_VOICEBOX, 'qwen', falado(item['texto']), wav, tom, seed=item.get('seed', 7) + tentativa)
            break
        except SystemExit as e:
            print(f"  {item['id']}: tentativa {tentativa + 1} falhou ({str(e)[-60:]})")
    else:
        sys.exit(f"{item['id']}: o Voicebox não gerou o áudio")
    # Converte para 16 bits (o leitor de WAV do Python e o Remotion aceitam).
    tmp = wav + '.tmp.wav'
    subprocess.run(['afconvert', '-f', 'WAVE', '-d', 'LEI16@44100', wav, tmp], check=True)
    os.replace(tmp, wav)
    return wav


def com_edge(item):
    """Gera com o edge-tts e devolve (wav, palavras) com os tempos da própria voz."""
    import asyncio
    import edge_tts
    mp3 = os.path.join(AUDIO, item['id'] + '.mp3')
    wav = os.path.join(AUDIO, item['id'] + '.wav')
    marcas = []

    async def rodar():
        c = edge_tts.Communicate(falado(item['texto']), VOZ_EDGE, rate=VELOCIDADE_EDGE, boundary='WordBoundary')
        with open(mp3, 'wb') as f:
            async for ch in c.stream():
                if ch['type'] == 'audio':
                    f.write(ch['data'])
                elif ch['type'] == 'WordBoundary':
                    marcas.append((ch['offset'] / 1e7, (ch['offset'] + ch['duration']) / 1e7, ch['text']))

    asyncio.run(rodar())
    subprocess.run(['afconvert', '-f', 'WAVE', '-d', 'LEI16@44100', mp3, wav], check=True)
    os.remove(mp3)
    # Cada palavra da legenda pode virar mais de uma palavra falada ("SouPM" → "Sou PM").
    palavras, k = [], 0
    for p in item['texto'].split():
        n = max(1, len(falado(re.sub(r'[^\wÀ-ú-]', '', p) or p).split()))
        grupo = marcas[k:k + n]
        if len(grupo) < n:
            palavras = None
            break
        palavras.append({'p': p, 'i': round(grupo[0][0], 3), 'f': round(grupo[-1][1], 3)})
        k += n
    if palavras is None or k != len(marcas):
        print(f"  {item['id']}: tempos da voz não bateram com o texto; usando as pausas")
        palavras = None
    return wav, palavras


def main():
    motor = sys.argv[1] if len(sys.argv) > 1 else 'voicebox'
    so = set(sys.argv[2:])
    itens = json.load(open(os.path.join(RAIZ, 'narracao.json')))
    destino = os.path.join(RAIZ, 'src', 'audio.json')
    resultado = json.load(open(destino)) if os.path.exists(destino) else {}
    for item in itens:
        if so and item['id'] not in so:
            continue
        palavras = None
        if motor == 'edge':
            wav, palavras = com_edge(item)
        else:
            wav = com_voicebox(item) if motor == 'voicebox' else com_say(item)
        segs = trechos_de_voz(wav)
        resultado[item['id']] = {
            'arquivo': 'audio/' + item['id'] + '.wav',
            'duracao': round(segs[-1][1] + 0.05, 3),  # termina quando a voz termina
            'palavras': palavras or palavras_pela_voz(item['texto'], segs),
        }
        print(f"{item['id']}: {resultado[item['id']]['duracao']:.2f} s (arquivo {duracao_wav(wav):.2f} s)")
    resultado = {i['id']: resultado[i['id']] for i in itens if i['id'] in resultado}
    json.dump(resultado, open(destino, 'w'), ensure_ascii=False, indent=1)
    print('total', round(sum(v['duracao'] for v in resultado.values()), 1), 's')


if __name__ == '__main__':
    main()
