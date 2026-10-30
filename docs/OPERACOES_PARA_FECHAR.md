# Módulo Operações: o que falta para fechar

Branch `feature/modulo-operacoes`. Atualizado em 30/10/2026.

## Já está pronto e conferido

Testado no iPhone 17 Pro (simulador), com conta real, em claro e escuro:

- **Login automático.** Toca em Operações e abre identificado, sem matrícula
  nem CPF. Se a nossa API falhar, cai no login do próprio Operar.
- **Guarda de dono.** A página não abre com token, PIN, escala ou conversa de
  outro militar. Sair do Sou PM desfaz o acesso ao Operar. Conferido com o JS
  rodando no node, onze casos, e no aparelho: o PIN e o evento sobreviveram a
  uma reinstalação, porque a matrícula é a mesma.
- **Card fixo na Início**, no design da 2.2, com cor própria e a operação
  nomeada no rodapé. Aparece mesmo sem escala.
- **Atalhos** com Contracheque e Operações nos dois primeiros lugares.
- **Liga e desliga pelo painel**, pela chave `op.operacoes`.
- **Documentos e download de PDF.** Estava quebrado (a folha de compartilhar
  não abria por falta da âncora que o iOS exige) e foi corrigido em 30/10.
- **Push abre na tela certa**: a rota com query resolve o módulo pelo caminho.
- 229 testes passando, `flutter analyze` sem erro nem aviso.

---

## 1. ~~Rodar no Android~~ — **feito em 30/10, e achou três defeitos**

Rodado no emulador `Pixel_API_36` (Android 16). Login automático, guarda de
dono, câmera, Documentos, download e o voltar: tudo conferido. Os três
defeitos abaixo só apareciam no Android e foram corrigidos no mesmo dia.

**a) A câmera não abria — nem pedia permissão.** O Operar mostrava "Câmera
indisponível" e nenhum diálogo do sistema aparecia. São duas permissões em
camadas: dizer GRANT ao pedido da página não dá câmera nenhuma se o app em si
não tem a permissão do Android, e o plugin não pede por conta própria. No
iPhone o sistema pergunta sozinho, então o defeito não existia lá. Atinge
também o **GPS do "Cheguei"**, pela mesma razão.

**b) O PDF era salvo com o nome do bilhete.** `A4-gnnuF1RM0z_4O_glQov-l.pdf`.
O servidor do Operar manda o nome de verdade no `Content-Disposition`, em
todas as rotas de arquivo, e a ponte estava ignorando. Agora sai
`cpi-escala-eleicoes-gerais-2026-2t-vespera.pdf`.

**c) O voltar do Android fechava o módulo inteiro.** Em vez de andar para trás
dentro do Operar, um toque no voltar fechava tudo e o militar perdia o lugar.
A causa não era do módulo: o `_voltar` do `MainShell` chamava `nav.pop()`, que
tira a rota do topo **sem perguntar nada a ela** — e com isso todo `PopScope`
de página aqui dentro era ignorado. Trocado por `nav.maybePop()`.

> **Isso conserta outras quatro telas junto**, que tinham o mesmo problema sem
> ninguém ter notado. Conferidas no emulador em 30/10:
>
> - **Comunicado:** volta a fechar com a animação de encolher para o card
>   (peguei no meio do caminho). Antes o `pop` cortava a animação.
> - **Chamado:** o voltar agora anda **um passo** — do grupo para a lista de
>   assuntos — e só fecha a tela no passo seguinte. Antes fechava tudo de uma
>   vez.
> - **Certidões:** a folha fecha normalmente, sem prender ninguém.
> - **Personalizar início:** fecha normalmente.
>
> **Não conferido:** os dois estados que BLOQUEIAM o voltar — enquanto a
> certidão é emitida (`_emitindo`) e enquanto a Início é salva (`_salvando`).
> São janelas curtas demais para acertar na mão; o salvamento é local e
> termina antes do toque. Pela leitura do código nenhum dos dois prende o
> usuário (os dois acabam liberando o pop), mas isso é leitura, não teste.

## 2. GPS do "Cheguei", foto de alteração e assumir viatura — **parado, esperando escala**

Você não está em escala nenhuma; o app mostra "Você ainda não está escalado" e
essas telas não existem para quem não tem serviço. É o pedido 4 do documento
do Cap Stenio: uma matrícula escalada na Expoferr, ou você numa escala de
teste.

São as funções que mais dependem do aparelho e as que menos dá para garantir
por teste automático. **Não ponha a tropa para usar antes disto.**

## 3. ~~`WKAppBoundDomains` no iPhone~~ — **feito e conferido em 30/10**

`operar.pmrr.online` declarado no `Info.plist` e o
`limitsNavigationsToAppBoundDomains` ligado na WebView. Conferido no iPhone:
"Guardar para ver sem sinal" agora funciona — o botão vira "Remover a cópia
sem sinal". Antes a Cache API estava bloqueada e a ordem de operações não
ficava no aparelho.

Custo: esta WebView passa a navegar só para o domínio declarado. Não é perda —
qualquer outro endereço já ia para o navegador do sistema.

## 4. Reset da personalização dos atalhos — **não é rápido, e precisa da sua decisão**

Combinado para sair com a versão, mas ao ir fazer vi que não é um apagar
local: a personalização da Início também fica **no servidor**
(`inicio_preferencias.php`), e o `carregar()` dá prioridade à cópia de lá.
Limpar só no aparelho não resolve — na próxima abertura a preferência volta.

O caminho que funciona é o `restaurar()`, que é uma chamada de rede que
**apaga a preferência do militar no servidor**. Na abertura seguinte a cada
versão nova, para toda a tropa, com a falha de rede como modo de erro.

Três coisas a decidir, e são suas:

1. Apagar mesmo a cada versão, ou só quando o painel mudar a ordem?
2. Apagar tudo (blocos e atalhos) ou só os atalhos?
3. O que fazer quando a chamada falhar: tentar de novo na próxima abertura, ou
   desistir daquela versão?

Não fiz por conta própria porque apagar a Início de todo mundo no servidor não
é coisa que se decide sozinho.

## 5. Antes do merge

- **Conferir no painel** que a chave `op.operacoes` está registrada e ligada
  em produção — é o que liga e desliga o módulo.
- ~~**Versão nos três arquivos**~~ **feito**: `2.3.0+60` no `pubspec.yaml`, no
  `Info.plist` (as duas chaves) e no `build.gradle.kts` (`versionCode = 60`).
  Subi o minor porque entra um módulo inteiro; troque se preferir outro número.
- Merge do `feature/modulo-operacoes`.

---

## Fora do nosso código, mas bloqueia função

| O quê | Com quem | Sem isso |
|---|---|---|
| PIN, "Sair deste aparelho", fila órfã, matrícula de teste | **Cap Stenio** — `docs/PEDIDO_OPERAR_DENTRO_DO_SOUPM.md` | O militar cria um segundo PIN, vê um botão que só faz estrago, e registros de campo ficam presos |
| Push do Operar pelo `push_modulo.php` | **Cap Stenio** — `docs/PEDIDO_PUSH_OPERAR.md` | Nenhuma notificação do Operar chega a quem entra pelo Sou PM |
| `apple-app-site-association` e `assetlinks.json` em `pmrr.online/.well-known/` | **DTI** | Conferido hoje: os dois seguem **404**. O QR da viatura e o chip NFC abrem no navegador em vez do Sou PM |
