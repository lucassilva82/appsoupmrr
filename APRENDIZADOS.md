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

