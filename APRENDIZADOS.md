# Aprendizados — SouPMRR

Registro dos erros que já custaram caro neste projeto e do que fazer para não
repeti-los. Cada item nasceu de um problema real, não de boa prática genérica.

Quem chegar aqui depois: **leia antes de publicar uma versão.** A maioria destes
itens só aparece em produção, quando o custo de errar é uma semana de fila.

---

## 1. O simulador iOS não roda release — teste em aparelho físico

**O que aconteceu.** A versão 2.1.0 foi rejeitada pela Apple por fechamento
inesperado na abertura (*Performance: App Completeness*). Não havia crash log
em lugar nenhum da App Store Connect, e a TestFlight mostrava aquele build com
**zero instalações e zero sessões** — ele foi do upload direto para a revisão,
sem nunca ter rodado num iPhone de verdade.

**Por quê.** O simulador recusa release e profile mode (`Releasemode is not
supported by iPhone 17`); só executa debug. Tudo que só quebra em release passa
despercebido em qualquer teste local.

**O que fazer.** Depois de `flutter build ipa`, subir pelo Organizer do Xcode,
instalar pela TestFlight num iPhone físico e **abrir o app**. Só então enviar
para revisão. Uma rejeição custa cerca de uma semana; o teste custa dez minutos.

---

## 2. Desenhe a tela antes de inicializar serviços

**O que aconteceu.** Causa provável do crash acima. O `main()` tinha cerca de
dez `await` sem proteção — Firebase, notificações, permissões — e o `runApp()`
era a última linha. Se qualquer um travasse ou demorasse, o app não desenhava
nada, e o *watchdog* do iOS mata processo que não produz o primeiro frame a
tempo (`0x8badf00d`).

**O que fazer.** `runApp()` primeiro. Inicialização pesada vai depois, fora do
caminho crítico, com tempo limite e isolada em `try/catch` por serviço — uma
falha de um não pode impedir o app de abrir. Nenhum diálogo de permissão do
sistema durante a abertura.

---

## 3. Nunca escreva chave de API no código — este repositório é público

**O que aconteceu.** A chave da API de legislações ficou versionada em texto
claro em `lib/utils/api_services.dart` (entrou em `3522d09`).

**O que importa entender.** Remover a chave do arquivo **não desfaz a
exposição**: ela continua no histórico do Git, público, para sempre. A única
correção real é **rotacionar a chave no servidor**. Tirar do código impede a
próxima exposição, não apaga a anterior.

**Limite da solução atual.** Hoje a chave vem do build
(`--dart-define-from-file=env.json`, com `env.json` fora do Git). Isso resolve
"qualquer pessoa lê no GitHub", mas **não torna a chave secreta para quem
instala o app** — chave compilada em binário é extraível. A correção definitiva
é a API de legislações ser chamada pelo nosso backend, que já autentica o
militar, em vez de pelo aplicativo.

---

## 4. `minSdk` dinâmico muda sozinho

**O que aconteceu.** Um commit trocou o valor literal por
`minSdk = flutter.minSdkVersion`. Numa atualização do Flutter, isso subiu de 21
para 24 sem ninguém decidir, e a Play Store avisou que **1.732 aparelhos**
tinham deixado de ser compatíveis.

**O que fazer.** `minSdk` fica com valor literal e comentário explicando por que
é aquele número. Hoje está travado em 24 porque `local_auth_android` exige — não
dá para voltar a 21.

---

## 5. `ORDER BY ... DESC` no Postgres traz `NULL` primeiro

**O que aconteceu.** O cron que avisa sobre contracheque novo lia o mês mais
recente da base e imprimia `Mês mais recente na base: /0 (0)`. A view tinha sete
linhas com `ano`/`mes` nulos, e no Postgres `NULL` vem antes em ordem
decrescente. O cron teria rodado para sempre sem nunca notificar ninguém, em
silêncio.

**O que fazer.** Filtrar `WHERE ano IS NOT NULL AND mes IS NOT NULL`, ou usar
`NULLS LAST`. E desconfiar de resultado vazio que não acusa erro.

---

## 6. Modo de simulação tem que ser realmente read-only

**O que aconteceu.** O `--simular` do mesmo cron gravava no banco: a rotina que
populava os registros rodava **antes** da checagem do modo simulação.

**O que fazer.** A checagem vem primeiro, antes de qualquer escrita. "Simular"
que escreve é pior que não ter simulação, porque dá falsa confiança.

---

## 7. Descrição da loja só pode citar o que abre de verdade

**O que aconteceu.** Ao reescrever a página da App Store, a descrição listava
escalas de serviço, SVI e consulta de patrimônio. Os três estão no código —
rotas registradas, telas existentes — mas **escalas e SVI estão bloqueados**
(`grid_menu.dart`, conjunto `_emDesenvolvimento`, mostram "Em breve" e não
abrem) e a tela de patrimônio está órfã, sem nada que navegue até ela.

**O que fazer.** Antes de escrever texto de loja, conferir o que o usuário
realmente alcança tocando na interface — a existência da rota não prova nada.
Descrição que promete recurso indisponível é motivo recorrente de rejeição.

---

## 8. Conformidade de criptografia trava o build em silêncio

**O que aconteceu.** Depois do upload da 2.1.2, a compilação não aparecia para
seleção. Não era demora de processamento: estava parada em *"Faltam dados de
conformidade"*, esperando a resposta sobre exportação de criptografia.

**O que fazer.** Já resolvido na raiz — o `Info.plist` declara
`ITSAppUsesNonExemptEncryption = false` (o app só consome o TLS do sistema, o
que cai na isenção). A App Store Connect não pergunta mais.

---

## 9. Detalhes de UI que já geraram retrabalho

- **`InputDecorator` esconde `prefixText`/`suffixText`** enquanto o campo está
  vazio e sem foco. Três campos de duração apareciam só como "0". Rótulo que
  precisa estar sempre visível vai fora da caixa.
- **`withValues(alpha:)` substitui o alfa, não multiplica.** Aplicar sobre uma
  cor que já era translúcida deixa o elemento mais opaco, não mais discreto.
- **`ShaderMask` com `BlendMode.srcATop` e cores transparentes apaga o
  conteúdo.** Para brilho sobre texto, usar cores opacas.
- **Ícone adaptativo Android:** a camada tem 108dp, mas o sistema só garante os
  72dp centrais e ainda aplica zoom. Arte ocupando a camada inteira sai
  esticada. Sem `mipmap-anydpi-v26/ic_launcher.xml`, o Android 8+ aplica o
  tratamento legado e desenha a borda clara em volta.

---

## 10. Não monte o `future:` dentro do `build()`

**O que aconteceu.** A tela do contracheque piscava ao tocar em compartilhar e
piscava de novo ao cancelar a folha do sistema. A causa não era o
compartilhamento: o `FutureBuilder` recebia `future: _buscaDadosSql()`, montado
dentro do `build()`. Cada `setState` criava uma consulta nova, o FutureBuilder
voltava para `ConnectionState.waiting` e a tela inteira virava indicador de
carregamento. Os dois `setState` do fluxo davam as duas piscadas.

O mesmo padrão estava em mais dois lugares. No card de tempo de serviço era
pior: ele era `StatelessWidget` e o `build` observa o Auth com `listen: true`,
então **toda notificação do Auth disparava uma requisição HTTP nova**.

**O que fazer.** O Future vai num campo do State, criado uma vez e refeito só
quando alguma entrada dele muda. Se a entrada muda (como o ano selecionado),
recrie no `setState` que a altera.

**Como medir.** Contar as execuções no log em vez de tentar flagrar a piscada
numa captura. Se abrir a folha e cancelar mantém a contagem parada, acabou.

---

## 11. Toda página precisa pintar o próprio fundo

**O que aconteceu.** Na navegação dava para ver a tela de saída **através** da
tela de entrada, com os dois conteúdos legíveis ao mesmo tempo. Parecia
navegação rápida demais ou falha de renderização.

**Por quê.** O fundo do app era pintado uma vez só, atrás do Navigator, e o
tema define `scaffoldBackgroundColor: Colors.transparent`. Ou seja, **toda**
Scaffold do app é translúcida por padrão — não apenas as que declaram isso
explicitamente. Durante o push, a rota que entra deixa ver a que sai.

**O que fazer.** Toda página retorna `FundoSuave(child: Scaffold(...))`, como a
home sempre fez. O `FundoSuave` é opaco, então o visual não muda e a rota passa
a ser opaca. Página nova no app: envolva, ou o defeito volta.

**Como medir.** `timeDilation = 25.0` (importando com
`show timeDilation`, senão colide com o `Priority` do flutter_local_notifications)
e capturar o meio da transição. Antes: dois conteúdos sobrepostos. Depois:
borda nítida entre as telas.

---

## 12. Confirme a causa antes de culpar a tela

**O que aconteceu.** Numa captura, a Ficha Individual apareceu em tema claro e
eu concluí que a tela estava fora do padrão. Ao verificar, a barra inferior e a
barra de status também estavam claras: era o app inteiro em tema claro naquele
instante, não aquela tela. O arquivo não tem nenhuma cor clara fixa e já usa
`CartaoVidro` e `theme.brightness`.

**O que fazer.** Antes de redesenhar uma tela por "estar fora do padrão",
conferir se o desvio é dela ou do app todo — olhar as barras do sistema, a
configuração de tema e tentar reproduzir. Não foi possível reproduzir aquele
render, e a tela ficou como estava.

---

## 13. No dart_pdf, cor com alfa é pintada cheia

**O que aconteceu.** No redesenho do contracheque em PDF usei cores
translúcidas para os fios, as faixas alternadas e as etiquetas P/D. Saiu tudo
chapado: as linhas pares viraram azul sólido com o texto ilegível, as
etiquetas viraram blocos sem a letra, e o cartão do líquido saiu branco com o
valor branco por cima — invisível.

**Por quê.** O `setFillColor` do pacote emite apenas `r g b rg`. O canal alfa
do `PdfColor` é descartado no preenchimento; não existe nenhuma referência a
`.alpha` no arquivo de gráficos.

**O que fazer.** Pré-misturar a cor contra o fundo real
(`mistura(fundo, frente, t)`). Transparência de verdade só com `pw.Opacity`,
que é o que a marca d'água do brasão usa. Pré-misturar ainda imprime melhor,
porque não depende de grupo de transparência do leitor de PDF.

---

## 14. No dart_pdf, só SpanningWidget quebra entre páginas

**O que aconteceu.** Depois de trocar o encolhimento de fonte por paginação de
verdade, um contracheque de 42 rubricas estourava em
`TooManyPagesException` e o usuário via "Não foi possível gerar o PDF".

**Por quê.** No `MultiPage`, apenas widgets que implementam `SpanningWidget`
— `Table`, `Column`/`Row`, `Wrap`, `GridView`, `Text` — se dividem entre
páginas. Eu tinha envolvido a tabela num `Padding` e num `ClipRRect` para dar
a calha lateral e arredondar os cantos. Qualquer embrulho desses trava a
quebra, e o MultiPage fica gerando páginas até bater no limite de 20.

**O que fazer.** A tabela entra como filha direta do `build:`. A calha lateral
vem da `margin` do `PageTheme`, e o arredondamento vem do `borderRadius` na
decoração da própria linha de cabeçalho.

**Efeito colateral a lembrar.** Quando o PDF passa a ter mais de uma página, a
rasterização para imagem precisa percorrer todas e empilhá-las. Pedir
`pages: [0]` estava certo enquanto o documento sempre cabia numa página; depois
da paginação, faria a imagem perder rubricas sem avisar.

---

## 15. PlistBuddy apaga os comentários do Info.plist

**O que aconteceu.** Ao subir a versão com
`PlistBuddy -c "Set :CFBundleShortVersionString ..."`, o arquivo foi reescrito
inteiro: as chaves saíram reordenadas em ordem alfabética e o comentário que
explicava a chave `ITSAppUsesNonExemptEncryption` desapareceu. Nenhum valor se
perdeu, mas o comentário era justamente o que impedia alguém remover a chave
sem saber por que ela estava ali.

**O que fazer.** Para mexer no Info.plist, editar o XML direto. Se usar o
PlistBuddy por conveniência, conferir o diff depois — `git diff` denuncia na
hora, pela quantidade de linhas alteradas muito maior que a mudança pedida.

---

## 16. O aviso de UIScene no build era a causa de duas rejeições

**O que aconteceu.** A Apple rejeitou a 2.1.0 e a 2.1.2 com "crashed on launch".
Na primeira rejeição não havia crash log nem aparelho informado, e eu atribuí ao
watchdog do iOS — reestruturei o `main()` para desenhar antes de inicializar.
Não resolveu, porque não era isso.

Na segunda rejeição a Apple anexou os logs. O frame 0 da thread principal:

    UIKitCore  __UIApplicationEvaluateRuntimeIssueForNoSceneLifecycleAdoption_block_invoke
    EXC_BREAKPOINT / SIGTRAP · iPad15,3 · iPadOS 27.2

O iPadOS 27.2 derruba na abertura os apps que não adotaram o ciclo de vida
`UIScene`. O UIKit dispara a armadilha **antes de qualquer código nosso rodar** —
nem Dart, nem plugin, nem `main()`. Por isso a reestruturação não alcançava.

**Por que só no iPad.** No iPhone a adoção ainda era apenas um aviso. Os testes
pela TestFlight em iPhone passavam, e isso reforçou a hipótese errada.

**O que eu deveria ter visto.** O `flutter run` imprimia, em todos os builds:

    To ensure your app continues to launch on upcoming iOS versions,
    UIScene lifecycle support will soon be required.

Eu tratei como mais um aviso de depreciação, junto dos de Kotlin e Swift Package
Manager. Era a causa raiz, em texto claro, na saída de todo build.

**A correção.** `UIApplicationSceneManifest` no Info.plist apontando para o
`FlutterSceneDelegate`, que o engine já fornece. Uma janela só, então
`UIApplicationSupportsMultipleScenes` fica falso.

**O que fazer daqui em diante.**

- Ler os avisos de depreciação do build, não só os erros. "Will soon be
  required" tem data de validade, e ela chega sem avisar de novo.
- Rejeição por crash sem log: pedir o log à Apple antes de teorizar. Duas
  semanas de fila se perderam numa hipótese que os logs teriam derrubado em
  minutos.
- Testar em iPad, não só em iPhone. A Apple revisa no aparelho que quiser, e
  escolheu iPad nas duas vezes.


---

## 17. Link de uso único: reabrir o e-mail não pode parecer erro

**O que aconteceu.** Um militar relatou "Link inválido ou expirado" ao confirmar
o e-mail. O log de acesso do servidor mostrou que ele **confirmou no primeiro
clique** e depois reabriu o mesmo e-mail oito vezes. Como o token é apagado na
confirmação, todas as aberturas seguintes caíam na página de erro. Ele ainda
pediu mais cinco links, e cada pedido invalida o anterior, então abriu um link
que já tinha sido substituído.

**O que não era.** A primeira suspeita foi fuso horário (quem cria o link não
ajusta o fuso da conexão; quem valida, sim). Uma consulta ao tipo da coluna
derrubou a hipótese: `timestamp without time zone` com os dois lados no mesmo
fuso. Conferir antes de corrigir economizou uma mudança desnecessária.

**A correção.** O `confirm_email.php`, quando não acha o token mas o cadastro já
está verificado com o mesmo endereço, mostra uma página **informativa** (ícone
azul): "Seu e-mail já foi confirmado". O erro vermelho ficou só para quando o
e-mail realmente não foi confirmado, com o texto avisando que um envio mais
recente substitui o anterior.

**O que fazer daqui em diante.**

- Antes de mexer em código por relato de usuário, olhar o **log de acesso**: ele
  mostra a sequência real de cliques e quem abriu primeiro (pessoa ou robô).
- O robô **Google-Read-Aloud** aparece abrindo links de e-mail. Hoje chegou
  depois da pessoa, mas se chegar antes, gasta o link sozinho. Se voltar a
  acontecer, a saída é a página do link pedir um clique de confirmação (POST).

---

## 18. Deploy na API: backup fora da pasta pública, envio com lftp, conferir

**O que aconteceu.** Um envio por FTP com `curl -T` falhou no meio e deixou o
`confirm_email.php` de produção com **0 bytes**. A página ficou em branco por
cerca de dois minutos, até o reenvio. Além disso, o primeiro backup foi feito
como `.bak` dentro da pasta pública, onde qualquer um baixaria o código-fonte.

**O que fazer, sempre, nesta ordem.**

1. Baixar o arquivo do servidor e comparar com a cópia local (`cmp`): se alguém
   mexeu direto no servidor, não sobrescrever às cegas.
2. Backup na pasta de backups **fora** da pasta pública.
3. Enviar com `lftp` (`set ftp:ssl-force true; put ...`), nunca `curl -T`.
4. Baixar de novo e `cmp` com o local; depois um teste HTTP que não envie e-mail
   nem grave nada.
5. Arquivo novo que outro inclui (`require_once`) sobe **antes** de quem o inclui.

---

## 19. API PHP se testa localmente antes de subir

**O que aconteceu.** O fluxo "Não lembro minha senha atual" mexeu no
`recuperar_senha.php`, que atende a tela de login de todo mundo. Subir sem
testar seria testar em produção.

**Como foi testado.** PostgreSQL local (Homebrew) com as mesmas tabelas e
colunas usadas pela API, `php -S` servindo uma cópia da pasta da API, e o
PHPMailer trocado por um stub que grava o e-mail em arquivo (assim dá para ler o
código de 6 dígitos sem enviar nada). O app rodou no simulador apontando **só**
esse endpoint para o servidor local, por um `--dart-define` temporário, removido
depois do teste.

**O que o teste pegou.** Depois de um código errado o campo continuava cheio, e
redigitar exigia apagar os seis dígitos. Agora ele limpa sozinho.

**Detalhes que custaram tempo.** O PostgreSQL recusa socket em caminho com mais
de 103 bytes (usar TCP em 127.0.0.1) e precisa de `LC_ALL=en_US.UTF-8` para
subir no macOS.

---

## 20. "Já confirmado" precisa provar que é o dado novo

**O que aconteceu.** A tela de e-mail decidia que a confirmação tinha chegado
quando o servidor respondia `verificado = true` e `aguardando = false`. Para
quem já tinha e-mail verificado e pedia a troca, isso também acontecia sem
clique nenhum: bastava o link de 15 minutos vencer. A tela diria "E-mail
confirmado!" com o endereço antigo ainda no cadastro.

**A correção.** Além dos dois sinais, o e-mail que o servidor devolve (mascarado)
tem que ser o novo. Sem isso, a tela continua aguardando.

**O que fazer daqui em diante.** Quando a tela espera um estado mudar, conferir
se esse estado não podia **já** ser verdadeiro antes da ação do usuário. Se
podia, comparar o próprio dado que muda (aqui, o endereço), não só uma flag.

---

## 21. Regra de segurança tem que valer em todas as portas de entrada

**O que aconteceu.** O Primeiro acesso já recusava e-mail de teste e e-mail de
outra matrícula. A tela "Meu e-mail" usava outro endpoint, que só conferia o
formato: `teste@gmail.com` passou e o link de confirmação foi parar na caixa de
um desconhecido. Se ele clicasse, a recuperação de senha do militar passaria a
ser dele.

**A correção.** As regras foram para um arquivo comum da API
(`validacao_email.php`), usado antes de enviar o link e de novo na confirmação:
e-mail de teste ou descartável, domínio digitado errado, domínio sem servidor de
e-mail, o próprio e-mail já verificado e e-mail que pertence a outra matrícula.
Na confirmação, a checagem se repete porque, entre o envio e o clique, outro
militar pode ter confirmado o mesmo endereço. Links antigos para e-mail de teste
também passaram a ser recusados.

**O que fazer daqui em diante.** Antes de criar ou mexer num caminho que grava
um dado sensível (e-mail, senha, telefone), procurar **todos** os outros pontos
da API que gravam o mesmo dado e conferir se seguem as mesmas regras. A regra
nova fica no arquivo comum, nunca copiada para um só endpoint.

---

## 22. Certidões: o módulo antigo falhava em silêncio havia dois meses

**O que aconteceu.** A tela de Certidões pedia a certidão e esperava duas
aprovações (chefia e DRH). O `error_log` da pasta `certidoes/` da API tinha
**2.577 linhas** desde agosto com `relation "recursoshumanos.solicitacao_certidao"
does not exist`: a tabela só existia no banco da intranet. Ninguém conseguia
pedir certidão pelo app, e a tela só mostrava "erro".

**A substituição (16/10/2026).** Autoemissão, porta fiel da intranet (branch
`feature/sigrh-modulo`): Tempo de Serviço, Vínculo Funcional e Ficha Funcional,
com a mesma Declaração de Conferência (v2), o mesmo layout TCPDF, o QR Code e a
validade de 30 dias. O PDF é gerado no servidor e entregue na hora.

- **API:** `sigrh/certidoes/autoemissao.php` (painel e emitir, sempre com
  matrícula + MD5 da senha), `verificar.php` (página pública do QR) e as
  bibliotecas `certidao_lib.php`, `certidao_dados.php` (somente leitura) e
  `certidao_pdf.php`. O TCPDF fica em `~/private/vendor/tcpdf`, fora da pasta
  pública.
- **Banco:** `public.soupm_certidao_emissao` e
  `public.soupm_certidao_verificacao_log`, com as mesmas colunas da tabela da
  intranet (para migrar linha a linha) + `pdf_sha256` e `canal`. SQL guardado na
  cópia da API, em `sql/2026-10-16_certidoes_autoemissao.sql`.
- **Diferença da intranet, decidida:** o Vínculo só sai para "SERVIÇO ATIVO",
  porque o texto afirma que o militar não foi demitido nem teve aposentadoria
  cassada.

**O que fazer daqui em diante.**

- O endereço `https://pmrr.online/flutter/sigrh/certidoes/verificar.php` está
  impresso em QR Codes. **Nunca pode ser removido nem mudar de lugar**, mesmo
  quando o app passar a usar a API da intranet: no máximo vira um
  redirecionamento para a verificação nova.
- Ler o `error_log` de cada pasta da API de tempos em tempos. Um endpoint que
  falha sempre não aparece em lugar nenhum além dele.

---

## 23. Certidão se revisa com dados reais, e valor de exemplo não é dado

**O que aconteceu.** A primeira versão das certidões copiava a intranet fielmente
e passou em todos os testes com dados fictícios. Emitida com dados reais, mostrou
o que os testes não mostravam:

- **Tempo de serviço incoerente.** A view `vw_certidao_pm` deduz **15 dias fixos
  por ano** (um valor de exemplo que ficou no SQL), e o "Total de Tempo Líquido"
  vinha de outra view sem dedução nenhuma. O mesmo documento trazia três números
  diferentes. O próprio banco tem a regra certa em `vw_certidao_pm_regras`: só
  não contam LTIP (situação 9), deserção (22) e pena em regime fechado (51). A
  conta agora é feita assim em `certidao_dados.php`, e tabela, total e frase de
  certificação usam o mesmo número.
- **Dado no lugar errado.** O endereço que o militar edita pelo app fica em
  `policial_militar` (`atualizaendereco.php`), não em `index_policial_endereco`,
  que é a tabela que a intranet lê. A foto do perfil está em
  `rh.pmrr.online/_lib/file/img/wc2/pix_db/`, com nome que pode ter espaço.
- **Campo que é flag.** `policial_contato.poli_cont_whats` é "sim/não", e aparecia
  como "1" no lugar do celular.
- **Lixo de cadastro.** "acrescentar", "NÃO INFORMADO", caixa alta misturada com
  caixa baixa, "SSPRR" sem barra. Agora tudo passa por normalização e o vazio vira
  um "Não informado" uniforme.

**O que fazer daqui em diante.** Todo documento oficial gerado a partir do banco
se valida emitindo com uma matrícula real e lendo o PDF linha por linha. Número
redondo e repetido (como 15 em todos os anos) é sinal de valor de exemplo, não
de dado.

---

## 24. Documento oficial segue o padrão de documento oficial, não o do app

**O que aconteceu.** A segunda versão do PDF tinha a cara do app: azul, cantos
arredondados, faixas coloridas. Ficou bonita, mas não parecia documento de uma
instituição. A terceira segue o padrão da administração pública (o mesmo da
Declaração de Residência da intranet): brasão centralizado, "Estado de Roraima /
Polícia Militar do Estado de Roraima / Diretoria de Pessoal" em Times, filete
duplo, texto todo em preto, número do documento abaixo do título, tabelas com
grade completa, texto de certificação justificado e quadro de autenticidade
discreto no fim.

Junto veio a **Certidão de Comportamento** (`Index_policial_comportamento` +
`index_policial_punicao`), que oficial não emite porque não tem classificação, e
a Certidão de Tempo de Serviço passou a listar os períodos não computados (LTIP,
deserção, pena em regime fechado) ao lado do tempo averbado.

**Detalhe que só apareceu com dado real.** Com seis anos de serviço e nada a
deduzir, o quadro de autenticidade passava 2 mm do limite e ia sozinho para a
página 2. Agora o texto de certificação, o local e data e a autenticidade andam
juntos (`_certidaoManterFecho`): se não cabem, vão os três para a página seguinte.

**O que fazer daqui em diante.** Documento que sai para fora da PMRR (banco,
INSS, outro órgão) usa a identidade do Estado, não a do aplicativo. E todo layout
se testa nos dois extremos: o caso mais curto e o mais longo.

---

## 25. Certidões: uma ação por tela, e o usuário vê o servidor trabalhando

**O que mudou.** A tela de certidões tinha a lista de tipos e a lista de emitidas
juntas. Agora tem um só botão, "Emitir nova certidão", que abre a escolha do
tipo. Na emissão, o botão mostra as etapas (consultando o SIGRH, conferindo os
assentamentos, alinhando os dados, gerando o documento, registrando a
autenticação, enviando por e-mail), com uma barra fina no pé. Ao terminar, volta
para a lista, onde a certidão nova entra subindo, com a borda acesa por um
instante, e um aviso diz para qual e-mail foi a cópia.

- **E-mail só para o endereço confirmado** (`certidao_email.php`), o mesmo
  critério da recuperação de senha: a Ficha tem conta bancária. Sem e-mail
  confirmado, a certidão sai normalmente e o aviso pede para confirmar. Falha no
  envio nunca desfaz a emissão.
- **E-mail oculto com tamanho fixo** (`lu*****6@gmail.com`): asteriscos na
  quantidade real revelariam o tamanho do nome.
- **PDF sem cor de marca**: textos, linhas e tabelas em preto; só o brasão e a
  foto ficam em cores (uma versão em tons de cinza foi testada e descartada: o
  que incomodava era o azul do app, não a cor do brasão). QR Code de 20 mm
  e quadro de autenticidade mais baixo; sem averbação, uma linha substitui a
  tabela vazia. Com isso, a Certidão de Tempo de Serviço com LTIP cabe numa
  página.

**O que fazer daqui em diante.** Espera de mais de 2 segundos mostra o que está
acontecendo, não só um círculo girando. E o tempo mínimo das etapas (2,6 s)
existe para elas não passarem num piscar quando o servidor responde rápido.

**Ajuste (16/10/2026): verificação só pelo QR Code.** O endereço de verificação
saiu do PDF, o botão "Verificar autenticidade" saiu do e-mail e o "copiar link"
saiu do app. A página `verificar.php` **continua no ar**, porque é ela que o QR
Code abre (inclusive nas certidões já emitidas). Quando a verificação for para o
SIGRH na intranet, `verificar.php` deve redirecionar para lá, nunca ser apagada
enquanto houver certidão válida em circulação (30 dias depois da última emitida
com este QR).

---

## 26. Certidão nova revoga a anterior; remover do aparelho não revoga nada

**O caso.** O militar emite uma certidão, vê um dado errado, pede a correção à
DRH e emite de novo. A nova sai certa, mas a antiga pode já estar com um banco
ou outro órgão. Quem conferir a antiga pelo QR Code precisa saber que ela não
vale mais.

**Como ficou.**
- Ao emitir, a API revoga as certidões ainda válidas **do mesmo tipo e da mesma
  matrícula** (`certidaoRevogarAnteriores`), só **depois** de o PDF novo ficar
  pronto: se a geração falhar, a anterior continua valendo. O QR da antiga
  mostra "Documento revogado", com a data e o motivo ("Substituída por uma
  certidão mais recente do mesmo tipo…").
- O painel devolve `vigente_desde` por tipo, e a folha de emissão avisa antes:
  "A certidão emitida em … deixará de valer."
- "Remover do aparelho" (lixeira na tela da certidão) apaga só o arquivo local,
  depois de confirmar. A mensagem diz que ela continua válida e que o PDF está
  no e-mail enviado (o e-mail oculto fica guardado junto da certidão).
- O botão "Emitir nova certidão" deixou de redefinir raio e fonte: usa o
  `elevatedButtonTheme`, como manda o DESIGN §5.

**Para o deploy.** Laço de arquivos em script de deploy roda em `bash -c`: no
zsh, `for f in $F` não separa a lista, e o backup não foi feito na primeira
tentativa (refeito a partir das cópias baixadas antes do envio).

**E-mail e nome do arquivo (16/10/2026).** No Gmail do celular a coluna de
rótulo (`width:42%`) é ignorada e o rótulo encosta no valor ("DocumentoCertidão
de…"): agora o rótulo fica em cima do valor. O cabeçalho ganhou o logo do
SouPMRR à direita, como nos outros e-mails. O PDF passa a se chamar
"Certidão de Tempo de Serviço - NOME DO MILITAR.pdf" (`certidaoNomeArquivo`).

**Bug que apagava certidões do aparelho.** Depois de remover uma certidão e
emitir outra, as demais sumiram (arquivo e lista). A limpeza de "PDF sem
registro" confiava numa leitura da lista que podia estar vazia ou cruzada com
outra gravação. Corrigido em três frentes: leitura, gravação e limpeza passam
por uma fila (`_emFila`), uma de cada vez; a limpeza só roda se a lista foi lida
inteira e nunca apaga PDF de menos de 10 minutos; e o índice guarda só o código,
não o caminho completo, que no iPhone muda quando o app é atualizado (todas as
certidões teriam "perdido o arquivo" na primeira atualização).
**Regra:** rotina que apaga arquivo "que não está na lista" precisa provar que
leu a lista certa antes de apagar qualquer coisa.

---

## 27. Certidão só sai se os dados passarem na conferência

**O que estava errado.** Cada consulta ao SIGRH ficava isolada num `try/catch`
que, se falhasse, devolvia "vazio" em silêncio. Numa certidão oficial isso é
afirmar o que não se sabe: se a consulta de punições caísse, a certidão dizia
"não constam punições". E isso **acontecia em produção**: a consulta de
dependentes usava a coluna `poli_depe_activo`, que vem de uma migração da
intranet ainda não aplicada no banco. Falhou 34 vezes no log, e toda Ficha
Funcional saiu dizendo "Nenhum dependente registrado" (a do usuário tem dois).

**Como ficou (API).**
- Falha de consulta fica registrada (`_falhas`) e não vira dado vazio. Cada tipo
  lista as seções indispensáveis (`CERTIDAO_SECOES_OBRIGATORIAS`); se uma delas
  falhou, a certidão não sai e o militar lê que o SIGRH não respondeu.
- `certidao_validacao.php` barra dado faltante ou impossível: nome incompleto,
  CPF inválido (dígito verificador), inclusão no futuro ou antes do nascimento
  + 16 anos, ano com dedução maior que o bruto, soma dos anos diferente do
  período, licença com fim antes do início, averbação com dias inválidos,
  comportamento sem classificação, punição com data futura. O painel já mostra
  o tipo bloqueado, com o motivo.
- Depois de registrar o código, qualquer falha (PDF, hash, revogação) **cancela
  a emissão**: o QR nunca mostra "válida" para um documento que não foi
  entregue, e a certidão anterior continua valendo. O PDF é conferido antes de
  sair (`%PDF-`, `%%EOF`, tamanho, número de páginas) e o hash vai na resposta.
- A consulta de dependentes verifica se a coluna existe (`pg_attribute`).

**Como ficou (app).** A requisição de certidões é própria e diferencia "sem
internet, nada foi emitido" de "a conexão caiu esperando" (aí o servidor pode
ter emitido e mandado por e-mail, e o app avisa para conferir o e-mail antes de
emitir de novo). O PDF recebido é comparado com o SHA-256 do servidor, e nada é
guardado se não bater. Falha ao gravar (aparelho cheio) também é explicada. As
etapas do botão falam a língua da tropa ("Calculando seu tempo de serviço",
"Verificando postos e graduações", "Apurando punições disciplinares",
"Lavrando o documento").

**Regra:** em documento com fé pública, "não consegui consultar" nunca pode ser
impresso como "não existe". Falhou, não emite, e diz por quê.

**Push e revogação (16/10/2026).** A certidão emitida agora gera uma notificação
push só para o militar que a emitiu, pela Cloud Function `notificarMilitar`
(publicada em `us-central1-minhapm-5ff71`). Ela exige o mesmo token secreto da
`notificarTodos`, que o servidor já tem em `/private/config_notificacao.php`, e
não passa pela lista de autorizados da `notificarEscala`, que é de teste e tem
7 matrículas. A API responde ao app primeiro e só depois chama a função, então a
emissão não fica mais lenta. Ao abrir a tela, o app tira do aparelho a certidão
que o servidor revogou e mostra o motivo. O quadro de autenticidade do PDF ficou
com contorno cinza de 0,1 mm.

---

## 28. O app desenha, a API decide, o banco guarda

**O pedido.** Mudar textos, ligar e desligar certidões ou tirar o serviço do ar
sem publicar versão nova, preparando o terreno para um painel de administração
(web e dentro do app).

**Como ficou.** Duas tabelas novas: `soupm_config` (um JSON por módulo) e
`soupm_certidao_tipo` (uma linha por certidão). `certidao_config.php` lê as duas
por cima dos padrões do código, e se a leitura falhar valem os padrões. O painel
devolve ao app nome, descrição, ícone, ordem, etapas do botão, textos da tela,
validade, declaração e a situação de cada tipo (`disponivel`, `desativado` ou
`bloqueado`). O app só desenha: selo "Temporariamente indisponível" no tipo
desligado e aviso no lugar do botão com o serviço fora do ar. A emissão confere
os interruptores de novo, para um app aberto há horas não emitir o que já saiu
do ar. Plano completo e operações de hoje: `docs/PAINEL_ADMIN.md`.

**Cuidados.**
- A versão da declaração é gravada em cada emissão e impressa no PDF; mudou o
  texto, aumente a versão.
- Tipo novo de certidão ainda exige código: o PDF de cada tipo é escrito à mão.
- O usuário da API só tem `SELECT` nessas tabelas. Quem altera é o painel, com
  usuário próprio.
- Testado em produção desligando um tipo e depois o serviço, por poucos
  minutos, e religando.

---

## 29. Lançamento 2.1.4 (16/10/2026)

**O que saiu.** Certidões automáticas (4 tipos, PDF oficial, QR Code, e-mail,
push, revogação, validação dos dados, configuração pela API), avisos curtos
padronizados, notificações não lidas com barra de destaque e o detalhe da
notificação opaco.

- **Android:** 2.1.4, `versionCode` 54, gerado em
  `build/app/outputs/bundle/release/app-release.aab` e assinado com a chave de
  upload (SHA-1 `64:4C:9C:A6:…:9F:92`). O 53 foi gerado antes das últimas
  mudanças e não foi usado.
- **iOS:** 2.1.4 (build 2.1.4), enviado pelo Organizer ao App Store Connect,
  aguardando aprovação da Apple.
- **APK de teste** para o chefe: `build/app/outputs/flutter-apk/SouPMRR-2.1.4-teste.apk`.

**Como lançar.** A versão está fixa em três lugares, e os três mudam juntos:
`pubspec.yaml`, `android/app/build.gradle.kts` (`versionCode` e `versionName`)
e `ios/Runner/Info.plist` (os dois campos). As chaves do Android estão no Google
Drive, em "Arquivos SouPMRR", e são copiadas para `android/key.properties` e
`android/app/upload-keystore.jks`. Os dois arquivos são ignorados pelo git.

**Senha pedida a cada arquivo no build do iOS.** O Keychain perguntava a cada
`codesign`. Resolve-se uma vez por Mac, no terminal do usuário (ele digita a
senha de login):
`security set-key-partition-list -S apple-tool:,apple:,codesign: -s ~/Library/Keychains/login.keychain-db`.
Depois disso, `flutter build ipa --release` roda sem perguntar e
`open build/ios/archive/Runner.xcarchive` abre o Organizer para o Distribute.

**Pendência visual do iOS (não bloqueou o envio):** a tela de abertura ainda é
o placeholder do Flutter e um ícone está com tamanho fora do padrão.

**Identificação da unidade (16/10/2026).** O padrão oficial é **"Polícia
Militar / Diretoria de Recursos Humanos - PMRR"**. No PDF, o cabeçalho é
"GOVERNO DO ESTADO DE RORAIMA / POLÍCIA MILITAR DO ESTADO DE RORAIMA /
DIRETORIA DE RECURSOS HUMANOS - PMRR", e o rodapé começa com "Diretoria de
Recursos Humanos - PMRR". "Diretoria de Pessoal" e
"Departamento de Pessoal" não se usam mais.
- **E-mails:** confirmação, troca e recuperação de senha, senha alterada,
  primeiro acesso (dois) e certidão trazem essas duas linhas no cabeçalho, no
  lugar de "POLÍCIA MILITAR DE RORAIMA / Aplicativo SouPMRR".
- **PDF:** a unidade no cabeçalho é "DIRETORIA DE RECURSOS HUMANOS"
  (`CertidaoPdf::ORGAO`). O rodapé passou a começar com "PMRR", porque o nome
  por extenso encostava na numeração de páginas.
- **Mensagens de bloqueio:** "Procure a Diretoria de Recursos Humanos".
- O rodapé dos e-mails continua "Departamento de Tecnologia da Informação —
  DTI/PMRR", que é quem dá o suporte.
