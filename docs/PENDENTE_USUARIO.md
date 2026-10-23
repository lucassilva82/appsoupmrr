# O que só o usuário pode fazer — SouPM 2.2

Lista do que depende do login, da senha ou da decisão do usuário. O resto do
plano (`docs/SOUPM_2_2.md` §16) segue sem esperar por isto: cada função nova
entra na API **desligada**, e nada muda para quem usa o app da loja até um
item desta lista ser feito.

Os SQL ficam na cópia local da API (`~/code/api-soupmrr/sql/`, fora do git
por conter estrutura do banco de produção). Rodar no phpPgAdmin, com o login
do usuário, **desmarcando "Paginar resultados"**, na ordem da tabela. Todos
podem rodar mais de uma vez sem estragar nada.

Última atualização: 22/10/2026, noite.

## 1. SQL de produção (phpPgAdmin)

| # | Arquivo | Para quê | Situação |
|---|---|---|---|
| 1 | `2026-10-22_soupm_log.sql`, `2026-10-22_soupm_servico_saude.sql`, `2026-10-23_soupm_cron_log.sql` | Fase 0 (log, sonda) | Feito |
| 2 | `2026-10-23_soupm_app_config.sql` | Fase 1 (menu e app_config) | Feito |
| 3 | `2026-10-23_soupm_inicio.sql` | Fase 2 (blocos da Início, atalhos, Mais usados) | Feito |
| 4 | `2026-10-23_soupm_feedback.sql`, `2026-10-23_soupm_atendimento.sql` | Fase 3 (Sugestões e elogios, Preciso de ajuda, área Atendimento) | Feito |
| 5 | `2026-10-23_soupm_documentos.sql` | Fase 3b (contracheque pela API, QR e conferência) | **Pendente** |
| 6 | `2026-10-23_soupm_notificacoes.sql` | Fase 4 (aparelhos e Avisos pelo Postgres) | **Pendente** |
| 7 | `2026-10-23_soupm_conta_resumo.sql` | Tela Militares do painel (bloco Conta) | **Pendente** — e depois `ALTER FUNCTION public.soupm_conta_resumo(TEXT) OWNER TO` um usuário que leia o esquema `qra` (o do cPanel não lê) |

| 8 | `2026-10-23_soupm_artes.sql` | Artes dos cards editáveis pelo painel, mídia aprovada e paleta fechada | **Pendente** |
| 9 | `2026-10-23_soupm_comunicados.sql` | Central de comunicados (categorias, comunicados, leitura e ciência) | **Pendente** — o `comunicados.php` já está no ar e responde erro até este SQL rodar; o app 2.2 só usa com o interruptor abaixo |
| 10 | `2026-10-23_soupm_painel_filas.sql` | Reset de senha pelo painel (fila), lembretes automáticos, modelos de mensagem e módulos da intranet que pedem push | **Pendente** |
| 11 | `2026-10-23_soupm_cards.sql` | Cards criados no painel, Comando aprovado no painel e dicas (depois do 8, que cria as artes) | **Pendente** — sem ele, o Comando e as dicas continuam vindo do Firestore |
| 12 | `2026-10-23_soupm_pendencias.sql` | Suas pendências: catálogo dos 37 tipos, **todos desligados**, dispensas e fontes de dados | **Pendente** — depois dele, cada tipo só liga pelo painel, depois de homologado |
| 13 | `2026-10-23_soupm_declaracao_campanha.sql` | Declarações por campanha. Nasce **desligado** (`declaracoes.campanhas_ligadas = false`) | **Pendente** — antes de ligar, cadastrar pelo painel a campanha do ano em curso, senão ninguém consegue declarar |
| 14 | `2026-10-23_soupm_inicio_preferencia.sql` | A tela inicial de cada militar guardada no servidor (vale em outro aparelho) | **Pendente** — sem ele, a escolha fica só no aparelho |
| 15 | `2026-10-23_soupm_niveis.sql` | Níveis de acesso e papéis (fase 5). Nasce **desligado** (`niveis.ligado = false`): o app e o menu seguem com a regra de hoje | **Pendente** — ligar só depois da comparação no painel |
| 16 | `2026-10-23_soupm_chamados_config.sql` | Textos e limites da tela "Meus chamados" pelo painel | **Pendente** |
| 17 | `2026-10-23_soupm_funcoes_novas.sql` | Funções novas no menu com o selo "Novo" (só para o app 2.2): O que mudou no contracheque, Central de documentos, Linha do tempo da carreira e Validar documento | **Pendente** — sem ele, só o menu de reserva do app mostra essas funções |
| 18 | `2026-10-23_soupm_lembretes.sql` | Lembretes automáticos (P3): controle para não repetir o mesmo lembrete | **Pendente** — os lembretes continuam desligados até alguém ligar no painel |
| 19 | `2026-10-23_soupm_uso_hora.sql` | Aberturas por hora para o mapa de calor "Quando usam" do painel (refaz a rotina noturna do log com esse passo a mais) | **Pendente** |
| 20 | `2026-10-23_soupm_niveis_rapido.sql` | Níveis de acesso mais rápidos: a prévia do painel caiu de cerca de 2 minutos para menos de 1 segundo, com o mesmo resultado; o `app_config` lê a visão do SIGRH uma vez só | **Pendente** — rodar depois do SQL 15 |
| 21 | `2026-10-23_soupm_feedback_retencao.sql` | Deixa o cron noturno apagar os anexos de sugestões 180 dias depois de concluídas ou arquivadas (decisão de 21/10/2026) | **Pendente** — sem ele, os anexos ficam guardados e o cron só avisa no log |

O item 11 (`2026-10-23_soupm_cards.sql`) ganhou o que o Comando precisa: a matrícula de cada cargo (o painel grava) e o "Conferir no SIGRH agora". Se já tiver rodado, rode de novo: ele não estraga nada.

Os itens novos que forem entrando vão para o fim desta tabela, com o mesmo
formato.

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
| `php ~/public_html/flutter/sigrh/cron/lembretes.php >> ~/logs/lembretes.log 2>&1` | Todo dia às 08:00 | Lembretes automáticos (SQL 18): férias que começam e certidão que vence. Só manda os que o painel ligou; para conferir antes, rode com `--simular` |
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
