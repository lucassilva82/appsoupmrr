# O que só o usuário pode fazer — SouPM 2.2

Lista do que depende do login, da senha ou da decisão do usuário. O resto do
plano (`docs/SOUPM_2_2.md` §16) segue sem esperar por isto: cada função nova
entra na API **desligada**, e nada muda para quem usa o app da loja até um
item desta lista ser feito.

Os SQL ficam na cópia local da API (`~/code/api-soupmrr/sql/`, fora do git
por conter estrutura do banco de produção). Rodar no phpPgAdmin, com o login
do usuário, **desmarcando "Paginar resultados"**, na ordem da tabela. Todos
podem rodar mais de uma vez sem estragar nada.

Última atualização: 25/10/2026 (onde paramos, para continuar no iMac: seção logo abaixo do §6).

## 1. SQL de produção (phpPgAdmin)

| # | Arquivo | Para quê | Situação |
|---|---|---|---|
| 1 | `2026-10-22_soupm_log.sql`, `2026-10-22_soupm_servico_saude.sql`, `2026-10-23_soupm_cron_log.sql` | Fase 0 (log, sonda) | Feito |
| 2 | `2026-10-23_soupm_app_config.sql` | Fase 1 (menu e app_config) | Feito |
| 3 | `2026-10-23_soupm_inicio.sql` | Fase 2 (blocos da Início, atalhos, Mais usados) | Feito |
| 4 | `2026-10-23_soupm_feedback.sql`, `2026-10-23_soupm_atendimento.sql` | Fase 3 (Sugestões e elogios, Preciso de ajuda, área Atendimento) | Feito |
| 5 | `2026-10-23_soupm_documentos.sql` | Fase 3b (contracheque pela API, QR e conferência) | Feito (23/10/2026) |
| 6 | `2026-10-23_soupm_notificacoes.sql` | Fase 4 (aparelhos e Avisos pelo Postgres) | Feito (23/10/2026) |
| 7 | `2026-10-23_soupm_conta_resumo.sql` | Tela Militares do painel (bloco Conta) | Feito (23/10/2026) — e depois `ALTER FUNCTION public.soupm_conta_resumo(TEXT) OWNER TO` um usuário que leia o esquema `qra` (o do cPanel não lê) |

| 8 | `2026-10-23_soupm_artes.sql` | Artes dos cards editáveis pelo painel, mídia aprovada e paleta fechada | Feito (23/10/2026) |
| 9 | `2026-10-23_soupm_comunicados.sql` | Central de comunicados (categorias, comunicados, leitura e ciência) | Feito (23/10/2026) — o `comunicados.php` já está no ar e responde erro até este SQL rodar; o app 2.2 só usa com o interruptor abaixo |
| 10 | `2026-10-23_soupm_painel_filas.sql` | Reset de senha pelo painel (fila), lembretes automáticos, modelos de mensagem e módulos da intranet que pedem push | Feito (23/10/2026) |
| 11 | `2026-10-23_soupm_cards.sql` | Cards criados no painel, Comando aprovado no painel e dicas (depois do 8, que cria as artes) | Feito (23/10/2026) — sem ele, o Comando e as dicas continuam vindo do Firestore |
| 12 | `2026-10-23_soupm_pendencias.sql` | Suas pendências: catálogo dos 37 tipos, **todos desligados**, dispensas e fontes de dados | Feito (23/10/2026) — depois dele, cada tipo só liga pelo painel, depois de homologado |
| 13 | `2026-10-23_soupm_declaracao_campanha.sql` | Declarações por campanha. Nasce **desligado** (`declaracoes.campanhas_ligadas = false`) | Feito (23/10/2026) — antes de ligar, cadastrar pelo painel a campanha do ano em curso, senão ninguém consegue declarar |
| 14 | `2026-10-23_soupm_inicio_preferencia.sql` | A tela inicial de cada militar guardada no servidor (vale em outro aparelho) | Feito (23/10/2026) — sem ele, a escolha fica só no aparelho |
| 15 | `2026-10-23_soupm_niveis.sql` | Níveis de acesso e papéis (fase 5). Nasce **desligado** (`niveis.ligado = false`): o app e o menu seguem com a regra de hoje | Feito (23/10/2026) — ligar só depois da comparação no painel |
| 16 | `2026-10-23_soupm_chamados_config.sql` | Textos e limites da tela "Meus chamados" pelo painel | Feito (23/10/2026) |
| 17 | `2026-10-23_soupm_funcoes_novas.sql` | Funções novas no menu com o selo "Novo" (só para o app 2.2): O que mudou no contracheque, Central de documentos, Linha do tempo da carreira e Validar documento | Feito (23/10/2026) — sem ele, só o menu de reserva do app mostra essas funções |
| 18 | `2026-10-23_soupm_lembretes.sql` | Lembretes automáticos (P3): controle para não repetir o mesmo lembrete | Feito (23/10/2026) — os lembretes continuam desligados até alguém ligar no painel |
| 19 | `2026-10-23_soupm_uso_hora.sql` | Aberturas por hora para o mapa de calor "Quando usam" do painel (refaz a rotina noturna do log com esse passo a mais) | Feito (23/10/2026) |
| 20 | `2026-10-23_soupm_niveis_rapido.sql` | Níveis de acesso mais rápidos: a prévia do painel caiu de cerca de 2 minutos para menos de 1 segundo, com o mesmo resultado; o `app_config` lê a visão do SIGRH uma vez só | Feito (23/10/2026) — rodar depois do SQL 15 |
| 21 | `2026-10-23_soupm_feedback_retencao.sql` | Deixa o cron noturno apagar os anexos de sugestões 180 dias depois de concluídas ou arquivadas (decisão de 21/10/2026) | Feito (23/10/2026) — sem ele, os anexos ficam guardados e o cron só avisa no log |

O item 11 (`2026-10-23_soupm_cards.sql`) ganhou o que o Comando precisa: a matrícula de cada cargo (o painel grava) e o "Conferir no SIGRH agora". Se já tiver rodado, rode de novo: ele não estraga nada.

Os itens novos que forem entrando vão para o fim desta tabela, com o mesmo
formato.

### Rodados em 23/10/2026

Os 17 SQL acima foram para o banco de produção pelo phpPgAdmin, um a um, com
"Paginar resultados" desmarcado. O banco foi de 24 para 53 tabelas `soupm_`.

Na mesma passada apareceu e foi consertado um estrago antigo: 73 textos com
acento gravados como Mac Roman (`Certidões`), 71 em colunas de texto e 2
dentro do JSON de `soupm_config`. A causa e a regra para não repetir estão em
`APRENDIZADOS.md` §45 — em resumo, **`LC_CTYPE=UTF-8 pbcopy`** e conferir o
texto já colado antes de executar.

**Os interruptores continuam todos desligados**, de propósito. Cada um muda o
que o militar vê e tem uma condição antes:

| Interruptor | Antes de ligar |
|---|---|
| `comunicados.fonte_app` (`firestore` → `api`) | cadastrar as categorias e ao menos um comunicado pelo painel |
| `notificacoes.envio_fcm` | `~/private/soupm_fcm.json` no servidor e o cron `envio_push.php` de pé |
| `notificacoes.fonte_app` (`firestore` → `api`) | só depois do corte, com a 2.2 na loja |
| `declaracoes.campanhas_ligadas` | cadastrar a campanha do ano em curso, senão ninguém consegue declarar |
| `niveis.ligado` | comparar no painel a regra nova com a de hoje |
| contracheque pela API | homologar o PDF gerado pela API contra o de hoje |

Falta ainda, do item 7: `ALTER FUNCTION public.soupm_conta_resumo(TEXT) OWNER
TO` um usuário que leia o esquema `qra` — o do cPanel não lê.

## 2. Arquivos em `~/private` no servidor (cPanel › Gerenciador de arquivos)

| Arquivo | Para quê | Como |
|---|---|---|
| `~/private/config_painel.php` | Segredo do link assinado dos anexos e da prévia do PDF (painel ↔ API) | `<?php return ['segredo' => '<64+ caracteres aleatórios>'];` — o **mesmo valor** vai no `conex/painelsoupmrr_local.php` do painel |
| `~/private/soupm_fcm.json` | Conta de serviço do Firebase, para a API mandar push sem as Cloud Functions (fase 4) | Console do Firebase › Configurações do projeto › Contas de serviço › Gerar nova chave privada. Permissão 600. Nunca no git |

## 2b. Chave do app no SISCHAMADOS (Meus chamados, fase 3c) — fase futura, quando o painel for para a intranet

1. Na intranet, SISCHAMADOS › Configurações › API Mobile: criar a chave do
   aplicativo "SouPM" (aparece uma vez só) e ligar a API Mobile.
2. Pôr no `env.json` da máquina, na linha `SISCHAMADOS_APP_CHAVE` (modelo em
   `env.example.json`), e guardar uma cópia no Drive, em "Arquivos SouPMRR".
   **Nunca no git.**
3. Só então liberar `atend.chamados` no painel (hoje fica "Em breve"). Sem a
   chave no build, a tela explica e mostra o código `CH-CHAVE`.

## 3. Cron do cPanel

| Comando | Quando | Para quê |
|---|---|---|
| `php ~/public_html/flutter/sigrh/cron/envio_push.php >> ~/logs/envio_push.log 2>&1` | A cada minuto | Fila de push (fase 4). Sem a conta de serviço e com `envio_fcm` desligado, sai sem fazer nada |
| `php ~/public_html/flutter/sigrh/cron/reset_senha.php >> ~/logs/reset_senha.log 2>&1` | A cada minuto | Reset de senha pedido pelo painel (SQL 10). Sem pedido na fila, não faz nada |
| `php ~/public_html/flutter/sigrh/cron/comando_sigrh.php >> ~/logs/comando_sigrh.log 2>&1` | A cada minuto | Comando pelo SIGRH (SQL 11): confere uma vez por dia e na hora em que o painel pede |
| `php ~/public_html/flutter/sigrh/cron/lembretes.php >> ~/logs/lembretes.log 2>&1` | Todo dia às 08:00 | Lembretes automáticos (SQL 18): férias que começam, certidão que vence, prazo de declaração (com as campanhas ligadas) e ciência de comunicado. Só manda os que o painel ligou; para conferir antes, rode com `--simular`. O de contracheque disponível fica no cron do contracheque que já existe: com o lembrete e o `envio_fcm` ligados, ele passa da Cloud Function para a fila de push |
| `php ~/public_html/flutter/sigrh/cron/versao_legada.php >> ~/logs/versao_legada.log 2>&1` | A cada 10 minutos | Leva para o Firestore das 2.1.x o mínimo legado que o painel definir, nunca acima do que as lojas têm publicado. Sem valor no painel, não mexe em nada; para conferir antes, rode com `--simular`. Precisa da conta de serviço em `~/private/soupm_fcm.json` |

## 4. Interruptores (depois dos itens acima)

Ligar pelo painel, ou por SQL (`UPDATE public.soupm_config SET valor = valor || '{...}' WHERE chave = '...'`):

| Chave | Campo | Quando ligar |
|---|---|---|
| `contracheque` | `pdf_api_matriculas: ["<sua matrícula>"]` | Para comparar o PDF novo com a sua conta (piloto) |
| `contracheque` | `pdf_api: true` | Depois de aprovar a comparação: o app passa a pedir o PDF à API |
| `comunicados` | `fonte_app: "api"` | Depois do SQL 9 e de publicar o primeiro comunicado pelo painel: a Início troca o anúncio do Firestore pela central |
| `declaracoes` | `campanhas_ligadas: true` | Depois do SQL 13 e de abrir pelo painel a campanha de cada tipo do ano em curso |
| `niveis` | `ligado: true` | Depois do SQL 15, de cadastrar as regras de cada nível no painel e conferir a lista de quem ganha e quem perde o Mapa da Força |
| `notificacoes` | `envio_fcm: true` | Depois da conta de serviço e do cron. A partir daí, o push da certidão emitida também passa pela fila (antes ia pela Cloud Function) |
| `notificacoes` | `fonte_app: "api"` | Depois de copiar o histórico do Firestore: no terminal do cPanel, `php ~/public_html/flutter/sigrh/cron/exportar_firestore.php` (só conta) e depois com `--gravar`; ele mostra a conferência por contagem no fim (§13, passo 4) |

## 5. Decisões e conferências

- **Notícias e agenda (P7), fase futura:** decidir o que da agenda da intranet pode aparecer
  para toda a tropa (hoje a API só tem a agenda dos comandantes, com permissão
  própria) e pedir à intranet uma rota de notícias publicadas. Sem isso a P7
  não entra.
- **Comparar o contracheque** novo com o de hoje com uma conta real (§12.3). O
  modelo já está sem a Diretoria de Recursos Humanos e com o QR (APRENDIZADOS
  §44).
- ~~**Ver a barra lateral no iPad**~~ **visto em 27/10/2026**, num iPad
  físico, no teste do build 4. Antes só havia passado por teste automático.
- **"Avisar quando voltar" na folha de bloqueio:** o app já mostra o botão
  quando o painel escolhe essa ação e grava o pedido no log
  (`modulo.avisar_quando_voltar`, com o código `MD-` da função). Falta a API
  mandar o push quando a função voltar a `ativo`. Até lá, o painel não deve
  escolher essa ação.
- **Pasta `sigrh/documentos/` no servidor:** três arquivos de uma tentativa que
  ficaram inacessíveis (o servidor bloqueia esse nome de pasta). Pode apagar a
  pasta pelo cPanel; o que vale está em `sigrh/doc/`.

## 6. Bloqueios do modo automático

- **25/10/2026:** publicar mudança no painel de **produção** (Funções e menu,
  "Salvar e publicar") foi barrado pelo verificador. Nada foi salvo; o painel
  ficou como estava (Linha do tempo da carreira: Ativo, selo "Novo"). A
  autorização tem de vir do usuário **direto na sessão do teste** (mensagem de
  outra sessão não vale), ou o usuário mexe no painel e a sessão confere no app.

---

## Onde paramos em 26/10/2026 (2.2.0 enviada às lojas)

- **Android:** 2.2.0 (`versionCode` 58) enviada pelo usuário à Play Store.
- **iOS:** 2.2.0, **build 4**, enviada para revisão da Apple às 20:13. Foi do
  mesmo arquivo do iOS de 26/10 à tarde, já com a entrada suave na Início. O
  "O que há de novo" é o resumido e não cita Android. As capturas novas (modo
  vitrine, 6 no iPhone e 5 no iPad) estão em todos os tamanhos. Os arquivos
  ficam em `appstore-capturas/jpg22/`, fora do git, com cópia no Drive em
  "Arquivos SouPMRR/capturas-2.2.0".
- Os dois builds saíram da branch `feature/soupm-2-2`, que **ainda não foi
  juntada no `main`**. Juntar depois de aprovada nas duas lojas.

**Falta (depende do usuário)**
1. ~~Instalar o build 4 pela TestFlight num iPhone e num iPad e abrir o
   app~~ **feito em 27/10/2026**: o usuário testou nos dois aparelhos
   físicos e estava tudo certo. O teste saiu **depois** do envio, não
   antes, como manda o APRENDIZADOS §1 — deu certo, mas a ordem foi a de
   risco: se tivesse quebrado, a correção pegaria a fila da Apple de novo.
2. Acompanhar a revisão da Apple, que leva até 48 h. As notas para a revisão
   são antigas: citam "escalas", que estão "Em breve", e as rejeições da
   2.1.x. Se a Apple questionar as funções "Em breve", responder que Escalas,
   SVI e Meus chamados estão assim de propósito, até a versão 2.3.
3. Depois de aprovada nas duas lojas: juntar a `feature/soupm-2-2` no `main`
   e subir a versão mínima e a recomendada no painel, quando for a hora.
4. Continuam valendo os itens abaixo: homologar um tipo de pendência, a conta
   de serviço do FCM em `~/private` e o cron `versao_legada.php`.

---

## Onde paramos em 25/10/2026 (para continuar no iMac)

Tudo no git: app na `feature/soupm-2-2` (não juntar no `main`: o usuário testa
no aparelho primeiro), API na `main` do repositório privado. Os 36 arquivos da
API mexidos no dia estão iguais no servidor (conferido com `cmp`). No iMac:
`git pull` nos dois repositórios e seguir o SETUP.md.

**Feito em 25/10/2026**
- Função em manutenção ou bloqueada vale em todo caminho: card da Início,
  push, link, dica, comunicado e rota direta (guarda na rota,
  `lib/core/navegacao/guarda_funcao.dart`); a API recusa com o código `MD-`
  (`sigrh/funcao_estado.php`, em férias, contracheque, tempo de serviço,
  carreira, declarações, Mapa da Força e emissão de certidão).
- Comunicado também como card fixo na Início (painel: "Card na Início" no
  editor do comunicado; SQL `2026-10-25_soupm_comunicado_card.sql` rodado).
- Tema mais usado guardado por 2 anos (`soupm_tema_dia`, SQL rodado; o app
  passou a mandar o tema da tela e a escolha em Aparência).
- Tema claro: selo "Admin" e textos com contraste (regra no DESIGN.md §6).
- Teste de ponta a ponta na vitrine (Android): 61 itens, falhas corrigidas;
  dois AP-FATAL do painel corrigidos (teclado no login do Android e contagem
  da tela de entrada). Entrada por Face ID/digital e login do Android no
  padrão 2.2.

**Falta (depende do usuário)**
1. Testar no aparelho (TestFlight e APK) a branch `feature/soupm-2-2`.
2. ~~Teste dos interruptores do painel~~ **feito em 26/10/2026**: manutenção,
   "Em breve", fora do menu, card do painel, comunicado como card e bloco da
   Início conferidos no app e desfeitos; um defeito da API corrigido
   (e6c62d4). Falta: **homologar um tipo de pendência** (só tipo com fonte
   confirmada pode ser ligado). O "Simular para uma matrícula" voltou a
   funcionar em 26/10 (faltava o `config_painel.php` em `~/private`).
3. ~~Rodar o SQL do catálogo~~ rodado em 25/10/2026.
5. ~~Revisão no iPad~~ **feita em 26/10/2026** (iPad Air 11", vitrine): Início,
   Serviços em 3 colunas, Contracheque, compartilhar (balão do sistema, sem
   travar), Perfil e horizontal, sem erro de layout no log. Corrigido: o Perfil
   dizia "iPhone" no iPad (1520a19). Fica para depois: lista e detalhe lado a
   lado no iPad (§15.4) e o teste em Split View, que o simulador não faz por
   comando.
4. Antes da loja: TestFlight em iPhone e iPad físicos, capturas novas em
   todos os tamanhos (vitrine), "O que há de novo" separado por loja
   (APRENDIZADOS §31–32).

Relatório completo do teste: pasta de notas das sessões
(`e2e-roteiro-2-2.md` e `e2e-android-vitrine.md`), fora do git.

---

## Onde paramos em 23/10/2026 (fim da tarde)

Tudo o que foi feito está no git (app na `feature/soupm-2-2`, API na `main`) e
no banco de produção. As decisões 1 e 2 foram tomadas (a 1 mudou em 24/10/2026);
a ordem da 3 está combinada com o painel e espera o seu "pode".

### 1. Roteiro único de SQL de produção (fase sem intranet, 24/10/2026)

Decisão do usuário: "Esqueça intranet por enquanto." Painel e app ficam no
mesmo banco, com o usuário de banco da API, e **tudo roda com a conta do
cPanel** no phpPgAdmin. Nada depende dos esquemas `intranet` nem `sccti`, e
não há nada para pedir ao administrador do banco. Cada arquivo pode rodar
mais de uma vez. Ordem:

| # | Arquivo | Onde está | Para quê |
|---|---|---|---|
| 1 | Os SQL da tabela do §1 acima que ainda não rodaram, **com o `_niveis.sql` e o `_niveis_rapido.sql`** | `sql/` da API | Tudo do app 2.2. O passo 3 usa `soupm_papel`, `soupm_papel_regra` e `soupm_papeis_para`, que nascem nos SQL de níveis |
| 2 | `A_tabelas_painel_producao.sql` | `painelsoupmrr/database/producao/` da intranet | As 7 tabelas do painel. Termina com uma conferência: as 7 têm de aparecer como "existe" |
| 3 | `C_acesso_proprio_producao.sql` | mesma pasta (commit b3f37d83) | Quem entra no painel e o que pode: 58 recursos, 33 permissões, a auditoria própria (`soupm_painel_auditoria`) e os Administradores (o nível 1 do SIGRH e a matrícula que o usuário indicou). No fim, lista os Administradores. Se a conta do cPanel não ler a visão do SIGRH, ele avisa e segue só com a matrícula indicada |
| 4 | `D_telas_prototipo_producao.sql` | mesma pasta (commit c497f463) | A imagem aprovada nas áreas do menu (`arte_imagem`) e os textos do rodapé e do botão das telas de erro |
| 5 | `2026-10-24_soupm_painel_permissoes.sql`, de novo | `sql/` da API | Dá ao usuário da API a escrita nas tabelas novas dos passos 2 a 4 (auditoria, papéis) e a leitura de `recursoshumanos.vw_buscar_policial`. O que ele já tinha aparece como `ok (já tinha)`; tabela que ainda não existe aparece como "pulado" |

Depois:
- Entrar no painel com a **matrícula e a senha do app** e conferir a tela
  Papéis. Se aparecer `PSP-DB-03`, a mensagem diz qual tabela falta.
- Publicar em pmrr.online os dois arquivos que o painel corrigiu (as telas
  abriam sem estilo e o tema escuro não pegava): `nucleo/casca.php` e
  `assets/nexus/nexus2-componentes.css`.
- Criar `~/public_html/painelsoupmrr/midia/`, com gravação pelo PHP, e
  publicar o `midia/.htaccess` do painel. As imagens aprovadas ficam lá e o
  app as busca em `https://pmrr.online/painelsoupmrr/midia/`.

**Não rodar:** os P0 a P8 antigos do painel (estão em `substituidos/`) e o
`intranet_depois/B_intranet_acl_producao.sql`, que fica para quando o painel
for para a intranet.

Fica a dívida "leitura e escrita no mesmo usuário" (PAINEL_ADMIN §7, item 6).

### Publicado em 24/10/2026

- `sigrh/app_config.php` e `sigrh/sessao_app.php` (backup em
  `/backups_api/sigrh/*.bak-20261024-v1`, conferidos com `cmp` depois do
  envio, parte pública respondendo 200). Trazem: a lotação para a linha da
  saudação, os textos de tela do painel (`soupm_config` 'textos'), a imagem
  aprovada nas áreas do menu (quando o SQL D do painel tiver rodado) e a mídia
  servida de `https://pmrr.online/`. A parte de quem entrou não foi testada
  com conta real: conferir no app ou no `error_log` de `sigrh/`.
- No `error_log` de `sigrh/` há um erro das 11:21 de 23/10:
  `permission denied for function soupm_e_gestor_legado`. O passo 5 do
  roteiro acima (permissões) dá EXECUTE em todas as funções `soupm_*`; se
  voltar a aparecer depois dele, a função precisa de dono que leia o SIGRH
  (APRENDIZADOS §46).

### O que o painel ainda não mostra por falta da API ou do app

- **Blocos do contracheque** (`soupm_documento_padrao`, campo `blocos`): o
  painel grava, o `contracheque_doc.php` ainda não lê. Até ler, o PDF não muda.
  Só importa quando o contracheque pela API for ligado.
- **Chamados no app** (`soupm_config` 'chamados': `acesso_movel`,
  `sessao_dias`, `tipos`): só valem quando o SISCHAMADOS voltar (2.3).
- **Rede no `app.abrir`**: o app manda tempo de abertura, tema, tamanho da
  fonte e modelo; a rede (Wi-Fi ou dados) pediria um pacote nativo novo.
- **Sem fonte, mostrados como "—" no painel:** tempo e falhas do PDF do
  contracheque, recusas `DC-FECHADA`, os números de chamados e as sessões
  abertas do painel.

### Fase futura: quando o painel for para a intranet

Nada disto entra agora. No app, as funções ficam "Em breve", com a folha de
bloqueio e o código `MD-`:

- **Login único pela intranet** (2.3, SOUPM_2_2 §6.6).
- **Minhas escalas e SVI** (`op.escalas`, `op.svi`) e os avisos do SIGE: usam a
  API da intranet. Desde o commit 0a7e485 o app não entra mais na intranet em
  segundo plano enquanto as duas estiverem bloqueadas.
- **Meus chamados** (SISCHAMADOS, `atend.chamados`) e o "Abrir chamado
  técnico" das telas de erro e do "Preciso de ajuda": a chave do app (§2b
  abaixo) e as rotas da API móvel.
- **Notícias e agenda** (P7, `inst.noticias`): rotas da intranet (§5).
- **No banco:** o `B_intranet_acl_producao.sql` (cadastro do módulo na ACL da
  intranet) e a leitura de `sccti` (medido em 24/10: o usuário da API não tem;
  as de `intranet` ele já tem). A regra de nível "perfil da intranet"
  (`soupm_nivel_para`) só vale quando a intranet existir no banco.

### 2. Arquivos de inclusão da API — feito em 24/10/2026

Um `.htaccess` na raiz da API bloqueia pela web os arquivos que só são
incluídos (conexão, `sessao_app.php`, bibliotecas das certidões e do
contracheque, `push_lib.php`, PHPMailer) e os `error_log`. Medido antes e
depois: os 14 arquivos passaram de 200 (ou 500) a 403, e os endpoints públicos
respondem igual, inclusive `certidoes/verificar.php` e `doc/conferir.php`.
Endpoint novo que seja só de inclusão entra na lista do `.htaccess`.

### 3. A virada para o esquema `soupm` — feita em 24/10/2026

Pedido do usuário: "tudo deve ficar no nosso esquema do soupm e nao no
public". Feita sem tirar nada do ar:

- `conexao.php` da API com `SET search_path TO soupm, public`; os 31 PHP da
  API sem o `public.` (commit 91284f9 da API); o painel publicado com o mesmo
  ajuste (commit 2a2daa44 da intranet).
- No banco, numa transação só: `2026-10-23_soupm_esquema_proprio.sql` +
  `2026-10-24_soupm_funcoes_para_esquema.sql`. Ficaram em `soupm` as 63
  tabelas, as 32 sequências e 21 funções (com as mesmas permissões); em
  `public` só as duas `soupm_conceder_*`. O gatilho do protocolo do feedback
  aponta para a função nova. A concessão ao usuário da API rodou de novo, sem
  falha.
- Conferido: `app_config` e `log.php` respondem, o `log.php` gravou um evento
  de teste (`teste.virada_esquema`), `/painelsoupmrr/entrar` responde 200 e o
  `error_log` de `sigrh/` não tem erro novo.
- Backup dos PHP de antes: `/backups_api/virada-soupm-20261024/`.

**Daqui em diante:** SQL novo cria em `soupm.` (os `.sql` versionados já
foram reescritos, commit 0ab86b9 da API). Os SQL A, C e D do painel criam em
`public.` e não rodam de novo como estão.

**Falta:** entrar no painel com a matrícula do Administrador e abrir algumas
telas (leitura e gravação).

### O que já está no ar

- Os 17 SQL da 2.2 (banco de 24 para 53 tabelas `soupm_`).
- O conserto dos 73 textos gravados como Mac Roman (APRENDIZADOS §45).
- A árvore de menus do protótipo, com a área Institucional nova.
- As 9 funções que liam o SIGRH passaram a `SECURITY INVOKER` — era o que
  fazia a área Gestão sumir do menu para todo mundo (APRENDIZADOS §46).
- O painel no ar em `/painelsoupmrr`, com a matrícula normalizada nos dois
  lados.

### Falta conferir no app (um toque)

A área **Gestão** deve ter voltado ao menu depois do conserto das funções,
mas o simulador caiu para a tela de login antes de eu confirmar. Entrar e
abrir Serviços: devem aparecer **6 áreas**, não 5.
