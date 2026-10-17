# SouPMRR

Aplicativo institucional da Polícia Militar do Estado de Roraima. Reúne as
informações funcionais do militar — contracheque, tempo de serviço, plano de
férias, declarações, certidões — e a consulta à base normativa da corporação.

Flutter (Android e iOS). O acesso é restrito aos militares da PMRR.

## Documentação

| Documento | Para quê |
|---|---|
| [SETUP.md](SETUP.md) | Montar o projeto numa máquina nova, versões validadas das ferramentas, arquivos que não vêm no clone e comandos de build |
| [APRENDIZADOS.md](APRENDIZADOS.md) | Erros que já custaram caro e como evitá-los. **Leia antes de publicar uma versão.** |
| [DESIGN.md](DESIGN.md) | Padrão visual: cores, tipografia, espaçamentos e a gramática dos cartões |
| [CLAUDE.md](CLAUDE.md) | Regras de trabalho do projeto, lidas pelo Claude Code em qualquer máquina |
| [tools/video-tutorial](tools/video-tutorial) | Modelo dos vídeos tutoriais do app (Remotion); instalação no SETUP.md §10 |

## Build

Os builds precisam das chaves de API, que não estão no repositório:

```bash
cp env.example.json env.json   # preencha com as chaves reais
flutter build appbundle --release --dart-define-from-file=env.json
```

Sem o `--dart-define-from-file` o app compila, mas as telas de Legislações e
POPs param de carregar. Detalhes na seção 5 do [SETUP.md](SETUP.md).

## Atenção

Este repositório é **público**. Nunca commite chaves, senhas, keystores ou
dados de militares. O que fica de fora está listado na seção 3 do
[SETUP.md](SETUP.md), e o motivo está no item 3 do
[APRENDIZADOS.md](APRENDIZADOS.md).
