# SouPMRR — instruções para o Claude

App Flutter (Android e iOS) da Polícia Militar de Roraima. Fale sempre em
**português do Brasil** com o usuário.

Este é o arquivo geral de regras de desenvolvimento. O Claude Code o carrega
sozinho ao abrir o projeto em qualquer máquina, e ele traz junto (pelas linhas
`@` abaixo) todos os documentos do projeto. Nenhum deles é opcional.

O que se aprende numa máquina e vale para todas entra aqui ou no
APRENDIZADOS.md, nunca só na memória local do Claude (ela não vem no clone).
Documento novo? Acrescente na lista abaixo com `@`.

## Documentos do projeto (carregados automaticamente)

| Documento | Para quê |
|---|---|
| [SETUP.md](SETUP.md) | Montar a máquina: versões, arquivos fora do git, builds, API (§9), vídeos (§10) |
| [APRENDIZADOS.md](APRENDIZADOS.md) | Erros que já custaram caro: publicar versão, API, login, certidões, capturas, vídeos |
| [DESIGN.md](DESIGN.md) | Qualquer tela nova: cores, tipografia, cartões |
| [docs/PAINEL_ADMIN.md](docs/PAINEL_ADMIN.md) | Plano do painel de administração (configuração vinda do banco) |
| [README.md](README.md) | Visão geral do app |

@SETUP.md
@APRENDIZADOS.md
@DESIGN.md
@docs/PAINEL_ADMIN.md
@README.md

## Máquina nova: o que instalar

Siga o SETUP.md do começo ao fim (checklist no §8). Além do que está lá:

| O quê | Para quê | Como |
|---|---|---|
| Skills do Claude Code | `ui-ux-pro-max` (base do DESIGN.md) e as do Remotion (vídeos) | **Automático.** Os links ficam em `tools/skills.txt`; o gancho de início de sessão (`.claude/settings.json`) roda `tools/instalar-skills.sh`, que instala o que falta e atualiza para a versão mais recente uma vez por semana (`--agora` força). As skills ficam em `.claude/skills/`, fora do git |
| Ferramentas de vídeo | Node, Python, edge-tts, OpenCV | SETUP.md §10 |
| Catálogo pessoal de ferramentas de IA | Claude Desktop, VS Code, Chrome etc. | https://github.com/lucassilva82/minhas-skills-ia (`instalar-mac.sh`) |

Se faltar alguma dessas, avise o usuário e instale antes de começar a tarefa
que depende dela.

## Regras que valem sempre

- **O repositório é público.** Nunca commitar chaves, senhas, keystores,
  `env.json`, dados de militares nem capturas com dados reais. A lista do que
  fica fora está no SETUP.md §3. Nada de endereço de servidor, usuário de
  cPanel ou valor interno da API em arquivo versionado.
- **Senhas, só o usuário digita.** Comandos que pedem senha (Keychain, sudo,
  cPanel) são rodados por ele no terminal dele.
- **Erro sempre explicado.** Nada de "Ocorreu um erro". Toda falha diz o que
  aconteceu, se é do aparelho, do servidor ou da conta, o que fazer (com o
  botão certo) e um código curto que vai também para o log (padrão `LG-...`
  em `lib/widgets/erro_login.dart`). Motivo: rejeição 2.1(a) da Apple
  (APRENDIZADOS §30–31).
- **Cada loja só fala de si.** Na App Store nada de Android/Play/APK (textos,
  capturas, links, notas, textos do app no iPhone); na Play nada de Apple.
  "O que há de novo" escrito separado. Checagem antes de cada envio:
  APRENDIZADOS §31. Capturas: atualizar **todos** os tamanhos, com o app em
  uso e só com o militar fictício (modo vitrine, §32).
- **Identificação da unidade** em e-mails, PDFs e mensagens:
  "Diretoria de Recursos Humanos - PMRR". PDF: "GOVERNO DO ESTADO DE RORAIMA" /
  "POLÍCIA MILITAR DO ESTADO DE RORAIMA" / "DIRETORIA DE RECURSOS HUMANOS - PMRR".
  Nunca "Diretoria/Departamento de Pessoal". Suporte técnico é o DTI.
- **Nada de texto ou configuração fixa no app.** Nomes, descrições, títulos,
  textos de tela e liga/desliga vêm da API, que lê do banco (`soupm_*`) por cima
  dos padrões do código, porque tudo isso vai ser gerenciado pelo painel de
  administração (docs/PAINEL_ADMIN.md). O app só guarda um padrão de reserva
  para quando está sem internet. Campo novo na API não pode quebrar versão
  antiga do app nem depender da ordem do deploy (conferir a coluna em
  `pg_attribute`, como no `titulo_curto`).
- **Trabalho independente vai para sessão separada** (o usuário prefere assim);
  ajustes rápidos ficam na sessão atual.

## Lançar versão

- Mudar a versão nos **três** lugares (não vem só do pubspec):
  `pubspec.yaml` (`X.Y.Z+N`), `android/app/build.gradle.kts`
  (`versionCode`/`versionName`) e `ios/Runner/Info.plist`
  (`CFBundleShortVersionString` e `CFBundleVersion`).
- Android: `flutter build appbundle --release --dart-define-from-file=env.json`.
  A chave de upload (`android/key.properties` e `android/app/upload-keystore.jks`)
  vem da pasta "Arquivos SouPMRR" no Google Drive do usuário; nunca mostrar as
  senhas do `key.properties`.
- iOS: `flutter build ipa --release --dart-define-from-file=env.json` e abrir o
  `.xcarchive` no Organizer. Se o Keychain pedir senha a cada arquivo, o
  usuário roda uma vez no terminal dele:
  `security set-key-partition-list -S apple-tool:,apple:,codesign: -s ~/Library/Keychains/login.keychain-db`.

## API (PHP, fora deste repositório)

- A API do app é PHP + PostgreSQL num servidor da PMRR, com cópia local sem
  git. Credenciais de FTP ficam no `~/.netrc` da máquina; nunca ler a linha de
  senha. Onde fica a cópia local: SETUP.md §9.
- Deploy: backup do arquivo original **fora** da pasta pública → envio com
  `lftp` (nunca `curl -T`: já zerou um arquivo de produção) → baixar de volta e
  `cmp` → teste HTTP. Testar antes localmente (APRENDIZADOS §18–19).
- Senha se confere no servidor (`login.php`); nenhum endpoint novo devolve o
  hash da senha (§30). Todo endpoint que grava e-mail usa
  `validacao_email.php` (§21).
- `certidoes/verificar.php` **nunca** pode sumir nem mudar de endereço: está
  impresso nos QR codes das certidões (§22–27).

## Vídeos tutoriais

Modelo pronto em `tools/video-tutorial/`; instalação no SETUP.md §10; receita
passo a passo e o porquê de cada escolha no APRENDIZADOS §33. Leia os três
antes de fazer um vídeo novo. Decisões do usuário:

- **Dados fictícios sempre:** gravar no modo vitrine (militar SD STIVES DA
  SILVA). Pessoas reais que aparecerem (comandantes na tela inicial) são
  borradas. Se a tela chama um endpoint novo, responder em memória no
  `lib/vitrine/vitrine.dart`.
- **Roteiro antes de gravar**, escrito a partir do código das telas e mostrado
  ao usuário.
- **Voz:** `pt-BR-ThalitaMultilingualNeural` (edge-tts), português do Brasil. Na
  fala o app é **"SouPM"**, nunca "SouPMRR". Recusadas: vozes do macOS e do
  Voicebox (robóticas, sotaque de Portugal).
- **Toque:** círculo desenhado à mão em tempo real em volta do botão ou campo
  (`@remotion/rough-notation`), só onde houve toque de verdade na gravação.
  Recusados: bolinha/onda no toque, círculo em texto do encerramento, zoom que
  corta o texto.
- **Estilo de rede social:** abertura animada ("Novidades no app SouPM"), barra
  de passos, legenda grande palavra a palavra, efeitos sonoros discretos.
  Animações seguem as skills oficiais do Remotion
  (instaladas por `tools/instalar-skills.sh`).
- **Entrega:** 1080×1920, H.264 + AAC, abaixo de 16 MB (WhatsApp), em
  `videos-tutoriais/` (fora do git). Mandar prévia, ajustar; quem envia é o
  usuário.
