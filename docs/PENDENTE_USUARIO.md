# O que só o usuário pode fazer — SouPM 2.2

Lista do que depende do login, da senha ou da decisão do usuário. O resto do
plano (`docs/SOUPM_2_2.md` §16) segue sem esperar por isto: cada função nova
entra na API **desligada**, e nada muda para quem usa o app da loja até um
item desta lista ser feito.

Os SQL ficam na cópia local da API (`~/code/api-soupmrr/sql/`, fora do git
por conter estrutura do banco de produção). Rodar no phpPgAdmin, com o login
do usuário, **desmarcando "Paginar resultados"**, na ordem da tabela. Todos
podem rodar mais de uma vez sem estragar nada.

Última atualização: 23/10/2026, manhã.

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

## 2b. Chave do app no SISCHAMADOS (Meus chamados, fase 3c)

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

- **Notícias e agenda (P7):** decidir o que da agenda da intranet pode aparecer
  para toda a tropa (hoje a API só tem a agenda dos comandantes, com permissão
  própria) e pedir à intranet uma rota de notícias publicadas. Sem isso a P7
  não entra.
- **Comparar o contracheque** novo com o de hoje com uma conta real (§12.3). O
  modelo já está sem a Diretoria de Recursos Humanos e com o QR (APRENDIZADOS
  §44).
- **Ver a barra lateral no iPad:** liberar o iPad Air 11" no painel do
  simulador do Claude Code. Hoje ela só foi conferida por teste automático.
- **Pasta `sigrh/documentos/` no servidor:** três arquivos de uma tentativa que
  ficaram inacessíveis (o servidor bloqueia esse nome de pasta). Pode apagar a
  pasta pelo cPanel; o que vale está em `sigrh/doc/`.

## 6. Bloqueios do modo automático

Nada bloqueado até agora nesta etapa. Se o verificador barrar alguma ação, ela
entra aqui, com o que faltou fazer.

---

## Onde paramos em 23/10/2026 (fim da tarde)

Tudo o que foi feito está no git (app na `feature/soupm-2-2`, API na `main`) e
no banco de produção. As decisões 1 e 2 foram tomadas (a 1 mudou em 24/10/2026);
a ordem da 3 está combinada com o painel e espera o seu "pode".

### 1. Usuário de banco do painel — decidido: (a), "O mesmo do app", em 24/10/2026

O painel usa a mesma conexão da API (o `conexao.php`). O usuário próprio foi
cancelado: não há nada para criar no cPanel. Falta um SQL só:

1. **Rodar no phpPgAdmin** o `sql/2026-10-24_soupm_painel_permissoes.sql` do
   repositório da API (com `LC_CTYPE=UTF-8 pbcopy`, APRENDIZADOS §45). Ele dá
   ao usuário da API a escrita que o painel precisa, só nas tabelas que o
   painel grava, mais as sequências e o EXECUTE das funções. Não tira nada do
   que a API já tem. O resultado é uma linha por permissão: `ok`, `pulado`
   (não existe neste banco) ou `FALTOU`, com o motivo.
2. **O que der `FALTOU (pedir ao dono do esquema)`** é algo fora das tabelas
   do SouPMRR (`qra`, `intranet`, `sccti`, `recursoshumanos`). A conta do
   cPanel não consegue conceder isso (APRENDIZADOS §46): mande essas linhas
   ao administrador do banco.

Fica a dívida "leitura e escrita no mesmo usuário" (PAINEL_ADMIN §7, item 6).

**Resultado em produção (24/10/2026).** Todas as `soupm_*` deram `ok`. Seis
tabelas do painel vieram `pulado` porque ainda não existem lá
(`soupm_painel_aviso`, `soupm_painel_cache`, `soupm_painel_navegador`,
`soupm_alerta_disparo`, `soupm_alerta_regra`, `soupm_log_filtro`): os SQL do
painel (P0 a P8) não rodaram em produção. A ordem deles vem da sessão do
painel; depois deles, o `_painel_permissoes.sql` roda de novo.

O `FALTOU` só diz que a **conta do cPanel** não enxerga o esquema; não prova
que o usuário da API não lê. Situação de cada um:

| Objeto | O usuário da API lê? | Como se sabe |
|---|---|---|
| `qra.sec_users` | sim | o login do app (`login.php`) lê em produção |
| `recursoshumanos.policial_militar` | sim | e-mail e declarações leem em produção |
| `public.vw_users_unidade_comando_groups` | sim | a ficha (`buscapormatricula.php`) lê em produção |
| `intranet.*` (8 objetos) e `sccti.*` (2) | **não medido** | a API não usa nenhum deles hoje |

Para medir os 10 que faltam é preciso uma sonda temporária no servidor (um
PHP que só testa `SELECT ... LIMIT 0` com o usuário da API e é apagado em
seguida). O modo automático barrou essa sonda por ser leitura de produção: ela
espera a sua autorização. Só depois sai o texto para o administrador do banco,
com o que faltar de verdade. Rascunho, a completar:

> Prezado administrador, o painel do SouPMRR (`/painelsoupmrr`) usa o usuário
> de banco da API do app. Peço conceder a esse usuário, no banco de produção:
> `USAGE` nos esquemas `intranet` e `sccti`; `SELECT` em `intranet.modulos`,
> `intranet.perfis`, `intranet.perfis_recursos`, `intranet.recursos`,
> `intranet.usuarios_perfis`, `intranet.vw_policial`, `sccti.tipos_chamado` e
> `sccti.categorias_chamados`; `SELECT, INSERT` em `intranet.auditoria` e
> `USAGE` em `intranet.auditoria_id_seq`. Obrigado. — DTI/PMRR

### 2. Arquivos de inclusão da API — feito em 24/10/2026

Um `.htaccess` na raiz da API bloqueia pela web os arquivos que só são
incluídos (conexão, `sessao_app.php`, bibliotecas das certidões e do
contracheque, `push_lib.php`, PHPMailer) e os `error_log`. Medido antes e
depois: os 14 arquivos passaram de 200 (ou 500) a 403, e os endpoints públicos
respondem igual, inclusive `certidoes/verificar.php` e `doc/conferir.php`.
Endpoint novo que seja só de inclusão entra na lista do `.htaccess`.

### 3. A virada para o esquema `soupm`

Preparada e **não executada**: `sql/2026-10-23_soupm_esquema_proprio.sql` (o
roteiro completo está no fim do arquivo) e
`tools/reescrever_para_esquema_soupm.sh`.

O administrador **não precisa fazer nada** — o usuário do phpPgAdmin pode
criar esquema e é dono dos 53 tabelas, 26 sequências e 21 funções. O roteiro
não tem janela de indisponibilidade: o PHP deixa de citar o esquema e passa a
depender do `search_path`, que resolve para `public` antes e `soupm` depois.

São 163 referências no PHP, 417 nos `.sql` e 402 no painel.

**Ordem combinada com o painel (23/10/2026), esperando o seu "pode":**

0. Os SQL do painel (P0 a P8) rodam antes, ainda em `public`.
1. `conexao.php` ganha `SET search_path TO soupm, public`. Sobe sozinho e
   não muda nada enquanto `soupm` não existir.
2. Sobem os 31 PHP sem o `public.` na frente. Continuam achando as tabelas em
   `public`.
3. Você roda `2026-10-23_soupm_esquema_proprio.sql`: as tabelas mudam de
   esquema.
4. Você roda os `.sql` reescritos da API. Eles recriam as funções em
   `soupm`. Os do painel não entram aqui, porque não criam função; depois
   do passo 3 não se roda mais nenhum deles como está.
5. Você roda o bloco que apaga as funções velhas de `public`. As duas
   `soupm_conceder_*` ficam.
6. Você roda de novo a concessão do painel no usuário da API: a última
   linha do `2026-10-24_soupm_painel_permissoes.sql` (o nome do usuário está
   no repositório privado da API).
7. Conferir que o app abre o menu e que o painel entra.

Para voltar: os mesmos laços com `SET SCHEMA public` e os PHP do backup.

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
