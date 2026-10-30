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
> ninguém ter notado: o fechamento animado do comunicado, o passo a passo do
> chamado (o voltar fechava o formulário em vez de voltar um passo) e o
> bloqueio do voltar enquanto a certidão é emitida ou a Início é salva. Vale
> um olhar nessas quatro antes de publicar.

## 2. GPS do "Cheguei", foto de alteração e assumir viatura — **parado, esperando escala**

Você não está em escala nenhuma; o app mostra "Você ainda não está escalado" e
essas telas não existem para quem não tem serviço. É o pedido 4 do documento
do Cap Stenio: uma matrícula escalada na Expoferr, ou você numa escala de
teste.

São as funções que mais dependem do aparelho e as que menos dá para garantir
por teste automático. **Não ponha a tropa para usar antes disto.**

## 3. `WKAppBoundDomains` no iPhone — **decisão sua, e eu recomendo fazer**

Sem essa declaração no `Info.plist`, o "Guardar para ver sem sinal" do Operar
não funciona dentro do módulo: ele usa a Cache API, que o WKWebView só libera
para domínios declarados. Quem está em operação sem sinal não abre a ordem de
operações nem a escala guardada — que é exatamente para o que aquele botão
existe.

Declarar custa pouco **no nosso caso**: a regra do iOS limita o que a WebView
pode fazer fora dos domínios declarados, e a nossa só carrega o
`operar.pmrr.online` — qualquer outro endereço já abre no navegador do
sistema, de propósito. São duas linhas no `Info.plist` mais o
`limitsNavigationsToAppBoundDomains` no plugin.

Não testei ainda. Se autorizar, faço e confiro no mesmo dia.

## 4. Reset da personalização dos atalhos — **combinado para sair com a versão**

Quando o painel muda a ordem dos atalhos, a escolha que o militar tinha feito
é apagada. Ficou para entrar junto com a versão, não antes.

## 5. Antes do merge

- **Conferir no painel** que a chave `op.operacoes` está registrada e ligada
  em produção — é o que liga e desliga o módulo.
- **Versão nos três arquivos**, como manda o CLAUDE.md.
- Merge do `feature/modulo-operacoes`.

---

## Fora do nosso código, mas bloqueia função

| O quê | Com quem | Sem isso |
|---|---|---|
| PIN, "Sair deste aparelho", fila órfã, matrícula de teste | **Cap Stenio** — `docs/PEDIDO_OPERAR_DENTRO_DO_SOUPM.md` | O militar cria um segundo PIN, vê um botão que só faz estrago, e registros de campo ficam presos |
| Push do Operar pelo `push_modulo.php` | **Cap Stenio** — `docs/PEDIDO_PUSH_OPERAR.md` | Nenhuma notificação do Operar chega a quem entra pelo Sou PM |
| `apple-app-site-association` e `assetlinks.json` em `pmrr.online/.well-known/` | **DTI** | Conferido hoje: os dois seguem **404**. O QR da viatura e o chip NFC abrem no navegador em vez do Sou PM |
