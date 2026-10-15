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
