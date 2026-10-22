# Painel web do SouPMRR — planejamento

> **Situação (21/10/2026): PROPOSTA, aguardando aprovação do usuário.**
> Este documento foi reescrito junto com o replanejamento do app 2.2
> (`docs/SOUPM_2_2.md`), para os dois serem produzidos juntos. Nada foi
> implementado: nenhuma linha de código, nenhuma branch, nenhuma tabela.
>
> O protótipo navegável do painel fica em `prototipos/painel-admin.html`
> (pasta fora do git) e foi publicado como Artifact privado. Todos os dados do
> protótipo são fictícios.
>
> As seções 2 (chaves da árvore) e 9 (contrato `app_config`) são o ponto de
> encontro com a sessão do app. Mudou uma das duas, avisar a outra sessão
> antes. As mudanças que este plano propõe ao contrato estão juntas no §9.1.

## 0. Resumo

O painel é um **módulo novo da intranet**, `SOUPMRR`, dentro da casca Nexus
2.0 (mesmo menu, mesma barra, mesmo login, mesmos componentes do
SISCHAMADOS). Ele não tem login próprio nem visual próprio. Por ele, quem tem
papel no painel controla **tudo o que o militar vê no app**:

| Área do painel | O que faz | Tela no protótipo |
|---|---|---|
| Painel | Indicadores, o que pede atenção, aberturas, buscas sem resultado | Painel |
| Funções e menu | Árvore de áreas, funções e ações: visível no menu, autorizado (nível mínimo, papéis), disponível (ativo ou bloqueado com motivo), compatível (versão do app), nível mínimo, papéis, agendamento, sinônimos, prévia da folha de bloqueio | Funções e menu |
| Tela inicial | Blocos, ordem, fixos, atalhos padrão por nível, Comando, dicas | Tela inicial |
| Comunicados | Central com categoria e cor, arte, público, período, urgente, destaque de abertura, ciência com prazo, push, relatório de leitura e ciência por unidade, prévia do cartão do app | Comunicados |
| Suas pendências | Catálogo de tipos de **todos** os sistemas, cada um configurável; **todos começam desligados** | Suas pendências |
| Versões do app | Mínima e recomendada **por plataforma**, com textos próprios de cada loja | Versões do app |
| Níveis de acesso | Criar, renomear, reordenar, escopo, regras lidas do SIGRH, prévia de quem entra e sai, histórico | Níveis de acesso |
| Papéis | Administrador, Publicar comunicados (delegável; no início só o administrador), Enviar notificações, Atender feedback, Gerir certidões, Consulta | Papéis |
| Militares | Busca, nível e porquê, aparelhos, últimas ações; resetar senha, desconectar aparelhos, "ver o app como" | Militares |
| Notificações | Só do SouPMRR: um militar, grupo com filtros ou todos; agendadas; lembretes automáticos; modelos; histórico com entrega e abertura | Notificações |
| Feedback | Caixa própria de **sugestões e elogios** (o único canal que chega à equipe do SouPMRR), com anexos, classificação e resposta. Problema técnico vai para o SISCHAMADOS | Feedback |
| Logs e erros | Ações e erros do app e da API, busca por matrícula, código, versão e plataforma; códigos mais frequentes; versões em uso | Logs e erros |
| Certidões | Tipos, textos e ressalvas, emissões, revogação, verificações do QR | Certidões |
| Auditoria do painel | Quem mudou o quê, com antes e depois, em `intranet.auditoria` | Auditoria do painel |
| Suporte e textos | "Preciso de ajuda" (assuntos, perguntas, respostas e função de destino, com indicadores), rodapé, parâmetros de rede e log do app | Suporte e textos |

A regra continua a mesma do app: **o painel edita o banco, a API decide, o app
só desenha.** O app nunca recebe segredo nem grava configuração.

### Skills usadas neste planejamento

| Skill | Para quê |
|---|---|
| `planning-and-task-breakdown` | Fases casadas com o app, fatias verticais, critérios de aceite e pontos de checagem (§10 e §13). O plano fica em `docs/`, não em `tasks/`, como manda o CLAUDE.md |
| `ui-ux-pro-max` | Direção de painel denso (densidade alta, status por cor e nome), hierarquia das telas, estados vazio/erro/carregando. A paleta sugerida pela skill foi descartada: vale a do Nexus/SouPMRR |
| `web-design-guidelines` | WCAG 2.2 no protótipo: rótulo visível, foco, `aria-current`, janela com foco no Cancelar em ação de perigo, `prefers-reduced-motion`, tabela que rola dentro da moldura |
| `php-pro` | Regras de segurança da API de administração: tipos estritos, consulta preparada, senha só com hash forte, nada de configuração fixa no código (sem Laravel/Symfony) |
| `postgresql-code-review` | Rascunho das tabelas (§8): `CHECK` no lugar de `ENUM`, `TIMESTAMPTZ`, índices GIN em `JSONB` de público, privilégios por usuário de banco, limites do PostgreSQL 9.6 |

Além das skills, o protótipo segue o `REGRAS_DESIGN_2.0.md` da intranet
(padrão Nexus, módulo-modelo SISCHAMADOS), que é regra lá e vale mais que
qualquer skill.

---

## 1. Arquitetura

### 1.1 Decisões do usuário que moldam o painel

| Decisão (20 e 21/10/2026) | Consequência no painel |
|---|---|
| Painel e app planejados e produzidos juntos | Fases casadas (§10). Cada fase do app tem a sua tela no painel |
| Nome continua **SouPMRR** | Módulo `SOUPMRR` na intranet, slug `soupm` |
| Só o militar comum (nível 1) não vê o Mapa da Força | Carga inicial: `gestao.mapa_forca` com nível mínimo 2 |
| Feedback vai para um **módulo do painel**, não para o SISCHAMADOS | Tela Feedback (§5.9) e tabelas próprias (§8). O SISCHAMADOS fica só para chamados de suporte |
| Notificações do app são **só do SouPMRR** | O painel não junta as notificações da intranet (`intranet.notificacoes`). Ver o risco R3 (§12) |
| Personalização da Início salva no servidor | `soupm_inicio_preferencia` (SOUPM_2_2 §12) |
| **A partir da 2.3**, app e painel entram com o login da intranet | O painel já nasce no login da intranet; o app migra na 2.3 (§6.4) |
| Pendências: todos os tipos **começam desligados** | `soupm_pendencia_tipo.ativo DEFAULT FALSE` (muda o rascunho do SOUPM_2_2 §12.2) |
| Publicar comunicados: no início, só o administrador | Papel "Publicar comunicados" existe, sem ninguém |

### 1.2 Onde cada peça roda

```
 Intranet (Nexus 2.0)                         API do app (sigrh/)                 App
 ┌──────────────────────────┐   escreve   ┌────────────────────┐   lê     ┌──────────────┐
 │ /painelsoupmrr (painel)   │ ─────────► │  Postgres           │ ◄─────── │ app_config    │ ◄── app
 │  login da intranet        │            │  public.soupm_*     │          │ pendencias    │
 │  ACL intranet.perfis      │            │  (mesmo banco)      │          │ comunicados   │
 │  intranet.auditoria       │            └────────────────────┘          │ log, feedback │
 └──────────────────────────┘                     ▲                      └──────────────┘
              │ grava pedido de envio                │ lê a fila                 │
              └───────────► soupm_notificacao_envio ─┘                           │
                                     │                                            │
                          cron de envio (API do app) ──► FCM HTTP v1 ──► aparelhos
```

- **Painel = módulo da intranet** em `~/code/intranet/painelsoupmrr/`, no
  endereço **`/painelsoupmrr`** (decisão do usuário, 21/10/2026), no molde do
  `sischamados/` (`index.php` com `Router('/painelsoupmrr')`, `routes/web.php`,
  `app/{Controllers,Helpers,Views}`, `database/migrations/NNN_*.sql`). Tela
  nova nasce no padrão 2.0 (`$nexusPronto`, `$nexusMenu`, `nxc-*`,
  `data-nx-parcial`) e passa no `verificar_design.php`.
- **Um banco só.** A intranet conecta com `search_path intranet, public`; as
  tabelas `public.soupm_*` ficam no mesmo banco que a API do app já usa.
  **Conferir antes da fase P0** que a intranet de produção alcança o mesmo
  banco das `soupm_*` (risco R1).
- **O painel não fala com o app.** Ele grava; a API do app lê. O painel nunca
  chama o FCM: grava o pedido em `soupm_notificacao_envio`, e um **cron na API
  do app** (onde fica a conta de serviço do FCM, em `/private`) envia, registra
  o resultado e desativa token vencido. Assim a credencial do FCM fica num
  servidor só.
- **Ações síncronas** que precisam do servidor do app (simular pendências,
  "ver o app como") chamam um endpoint interno da API do app protegido por
  chave de serviço e lista de IPs da intranet, nunca pelo navegador.
- **Uploads** (arte de comunicado, foto do Comando): pasta pública só de
  imagens, sem PHP executável, nome por hash, tipo conferido pelo conteúdo
  (`finfo`, como o `Anexo.php` do SISCHAMADOS). Anexos de feedback ficam
  **fora** da pasta pública e são servidos por rota que confere o papel.

### 1.3 Tolerância a falha

- O app sempre abre: se o `app_config` falhar, usa o último guardado; se nunca
  recebeu, os padrões do código (SOUPM_2_2 §5.3).
- Se o painel cair, o app continua com a última configuração gravada no
  banco. Nada no app depende do painel estar no ar.
- **Dois administradores no mesmo item:** todo registro editável tem
  `versao` (ou `atualizado_em`), que o formulário manda de volta ao salvar. Se
  outro administrador salvou antes, o painel **não sobrescreve**: avisa "Foi
  alterado por 3º SGT QPPM EXEMPLO às 10:52", mostra a diferença entre a
  versão dele e a sua, e deixa escolher (manter a dele, aplicar a sua por
  cima, ou juntar campo a campo).
- Toda gravação do painel é uma transação: ou muda tudo (registro + auditoria)
  ou nada.

### 1.4 Regra: tudo o que entra no app entra no painel

Pedido do usuário (21/10/2026), registrado também no CLAUDE.md: nada é
adicionado ao app sem aparecer no painel. Função, tela, card, módulo, serviço
ou API nova **já nasce** com:

| O quê | Onde | Efeito no painel |
|---|---|---|
| Chave na árvore | `soupm_menu_item` | Funções e menu, busca do painel, "ver o app como", impacto |
| Eventos `<modulo>.<acao>` | `soupm_evento_catalogo` | Logs, catálogo ("Nunca visto"), gráficos de uso |
| Códigos de erro com o significado | `soupm_config`, chave `erros` | Logs, alertas de código |
| Ponto no mapa (se fala com um sistema novo) | `soupm_servico`: chave, nome, ícone, faixa, de quem depende, como a sonda testa | Mapa de conexões, disponibilidade de 24 h, alerta "serviço lento ou fora", incidente com ação sugerida |
| Datas (se tiver) | a própria tabela (início, fim, prazo) | Agenda do app, com aviso de conflito |
| Tipo de pendência (se cobrar algo) | `soupm_pendencia_tipo`, desligado | Suas pendências |

O mapa, a disponibilidade, os alertas e a busca **leem os catálogos**: não há
lista fixa no código do painel. Cadastrar o serviço é o que o faz aparecer.
Uma função não está pronta enquanto não aparecer no painel (mesmo critério da
regra "Tudo tem log").

---

## 2. Inventário: tudo o que o painel vai controlar

> **Atualizado em 20/10/2026 para a árvore de menus do SouPM 2.2**
> (`docs/SOUPM_2_2.md` §3). O grid "Acesso Rápido" e as abas fixas saem; no
> lugar, uma árvore de áreas, funções e ações, com uma chave por nó.

Cada item ganha uma **chave estável**, que é como o painel, o app, a busca, o
push, o log e a ACL se referem a ele. A chave nunca muda depois de publicada.
As chaves da primeira versão deste plano (`contracheques`, `plano_ferias`…)
continuam valendo como **apelido** durante a 2.2 (coluna "Chave antiga").

Cada nó da árvore tem: `tipo` (`area`, `funcao`, `acao`, `bloco_inicio`,
`aba`), `pai`, `rotulo`, `descricao` (uma linha, aparece no menu e na busca),
`icone` (chave do mapa de ícones do app), `ordem`, `rota`, `sinonimos`,
`palavras_chave`, estado e mensagem (§3), `publico`/`recurso_key` (§3.3) e
`versao_min_app`. Tabela: `soupm_menu_item` (SOUPM_2_2 §12.2), que substitui o
`soupm_modulo` do plano anterior.

### 2.1 Áreas e funções (aba Serviços)

| Chave | Tipo | Rótulo | Chave antiga | Dados |
|---|---|---|---|---|
| `rh` | área | Minha vida funcional | — | — |
| `rh.ficha` | função | Ficha Individual | `ficha_individual` | `buscapormatricula.php`, `buscasituacaofuncional` |
| `rh.ficha.contato` | ação | Telefones | `ficha_individual.contato` | `inserecontato.php`, `deletacontato.php` |
| `rh.ficha.endereco` | ação | Endereço | `ficha_individual.endereco` | `listaenderecocompleto.php`, `atualizaendereco.php` |
| `rh.contracheques` | função | Contracheques | `contracheques` | `listamesescontracheque*.php`, `exibecontracheque*.php` |
| `rh.contracheques.grafico` | ação | Análise salarial | `contracheques.grafico` | mesmos endpoints |
| `rh.ferias` | função | Plano de férias | `plano_ferias` | `buscaplanodeferias.php` |
| `rh.tempo_servico` | função | Tempo de serviço e inatividade | `calculo_inatividade` | `listar_policial_iper.php` + regras fixas |
| `rh.certidoes` | função | Certidões | `certidoes` | `certidoes/autoemissao.php` (**já controlado**, Anexo A) |
| `rh.declaracoes` | função | Declarações anuais | `declaracoes` | `buscastatusdeclaracoes.php` |
| `rh.declaracoes.bens` | ação | Declaração de bens | `declaracoes.bens` | `buscabem`, `inserebem`, `excluibem` |
| `rh.declaracoes.irpf` | ação | PDF do IRPF | `declaracoes.irpf` | `buscapdfirpf`, `enviapdfirpf`, `excluipdfirpf` |
| `rh.declaracoes.parentesco` | ação | Parentesco | `declaracoes.parentesco` | `buscaparentescos`, `insereparentesco`, `excluiparentesco` |
| `rh.declaracoes.acumulo` | ação | Acúmulo de cargos | `declaracoes.acumulo` | `buscaacumulocargos`, `insereacumulocargos`, `excluiacumulocargos` |
| `operacional` | área | Serviço operacional | — | — |
| `op.escalas` | função | Minhas escalas | `escalas` | API da intranet `/escala/*` (hoje "Em breve") |
| `op.svi` | função | Serviço voluntário (SVI) | `svi` | API da intranet `/svi/*` (hoje "Em breve") |
| `op.plantao` | função | Meu plantão | `plantao` | **fora do menu na 2.2** (`visivel_menu = false`, continua ativo): o plantão passa a ser parte de Minhas escalas; push para `/plantao` abre `op.escalas` |
| `normas` | área | Normas e procedimentos | — | — |
| `normas.legislacoes` | função | Legislações | `legislacoes` | API de legislações |
| `normas.pops` | função | POPs | `pops` | mesma API |
| `gestao` | área | Gestão (nível 2 em diante) | — | — |
| `gestao.mapa_forca` | função | Mapa da Força | `mapa_forca` | `mapadaforca/*.php` (hoje só `isSuperUser`; passa a nível mínimo 2, com escopo por nível: SOUPM_2_2 §6.3) |
| `gestao.boletins` | função | Boletins | — | futuro (intranet `boletim/`) |
| `gestao.patrimonio` | função | Patrimônio e frota | — | futuro (intranet `patrimonio/`) |
| `atendimento` | área | Atendimento DTI | — | — |
| `atend.chamados` | função | Meus chamados | — | **na 2.2, completo do lado de quem pede** (SOUPM_2_2 §8.3, fase 3c): abrir em 3 passos com até 5 anexos, responder com anexo, confirmar a solução e avaliar de 1 a 5 estrelas, pela API móvel do SISCHAMADOS. O atendimento fica só na intranet |
| `atend.feedback` | função | Sugestões e elogios | — | **novo na 2.2** (SOUPM_2_2 §8) |
| `busca` | função | Busca global | — | **novo na 2.2**, índice local do `menu` |
| `rh.contracheques.mudou` | ação | O que mudou no mês | — | novo (P1), mesmos endpoints do contracheque |
| `rh.documentos` | função | Central de documentos | — | novo (P4) |
| `rh.carreira` | função | Linha do tempo da carreira | — | novo (P5), consultas da Ficha Funcional |
| `rh.validar` | função | Validar documento (QR) | — | novo (P6), `verificar.php` |
| `institucional` | área | Institucional | — | — |
| `com.central` | função | Comunicados | — | novo, `soupm_comunicado` (SOUPM_2_2 §4.2) |
| `inst.noticias` | função | Notícias e agenda | — | novo (P7), módulos `noticias` e `agenda` da intranet |

Área sem função visível para o militar some sozinha; área com uma só função
abre a função direto.

**Nível e papéis por item.** Cada nó tem no painel: nível mínimo (1 Militar,
2 Gestor de subunidade, 3 Gestor de unidade, 4 Gestor de grande comando,
5 Alto Comando), papéis que liberam mesmo abaixo do nível (Administrador do
app, Comunicação Social, Pessoal…), matrículas avulsas e o tratamento de quem
não alcança (oculto ou bloqueado). O escopo dos dados segue o nível
(SOUPM_2_2 §6). Os lembretes (P3) não são item de menu: são configurados só no
painel, junto das notificações (§4), e o militar não os desliga um por um.

### 2.2 Tela inicial (blocos)

| Chave | Bloco | Chave antiga | Fonte hoje → 2.2 |
|---|---|---|---|
| `home.comandantes` | Faixa do Comando (64 pt); ao tocar, expande com foto grande, nome completo, cargo, dados e mensagem | `home.comandantes` | Firestore `stores` → `app_config` |
| `home.anuncio` | **Central de comunicados**: carrossel com barras de progresso, pausa, "Ver todos"; o destaque de abertura volta para o carrossel ao fechar | `home.anuncio` | Firestore `appConfig/anuncio` → `soupm_comunicado` (SOUPM_2_2 §4.2) |
| `home.dicas` | Dica em uma linha, ícone por chave | `home.dicas` | Firestore `dicas_app` → `app_config` |
| `home.pendencias` | **Suas pendências** (só aparece se houver; obrigatórias e lembretes, de todos os sistemas) | — | novo, `pendencias.php` + `soupm_pendencia_tipo` (SOUPM_2_2 §4.3) |
| `home.atalhos` | Atalhos: uma linha que rola de lado, até 12, escolhidos pelo militar; padrão por nível | `home.acesso_rapido` | fixo → painel + preferência |
| `home.contracheque` | Card Contracheque | `home.contracheque` | API |
| `home.tempo_servico` | Card Tempo de serviço | `home.tempo_servico` | API |
| `home.ferias` | Card Plano de férias | `home.plano_ferias` | API |
| `home.rodape_dti` | Rodapé do DTI | `home.rodape_dti` | fixo |

O painel liga, desliga e ordena os blocos; o militar pode esconder e reordenar
os que o painel deixar (`soupm_inicio_preferencia`). Comandantes, comunicados e
pendências são fixos por padrão.

Telas novas ligadas à Início: `com.central` (todos os comunicados, filtros
Todos / Não lidos / Ciência pendente) e `pend.lista` (todas as pendências).
O painel ganha duas áreas para elas: **Comunicados** (texto, arte, categoria,
origem, público, período, ordem, urgente, destaque de abertura, ciência
obrigatória com prazo, push, relatório de leitura e ciência por unidade) e
**Pendências** (por tipo: ligado, obrigatória ou lembrete, prazo e
antecedência, período de cobrança, público, texto, prioridade, dispensável,
push).

### 2.3 Abas e Perfil

| Chave | Item | Observação |
|---|---|---|
| `aba.inicio` | Início | não pode ser ocultada |
| `aba.servicos` | Serviços | |
| `aba.avisos` | Avisos | `avisos` |
| `aba.perfil` | Perfil (absorve Configurações) | |
| `perfil.ficha` | Atalho para `rh.ficha` | |
| `conta.email` | Confirmar/trocar e-mail | antiga `config.email` |
| `conta.senha` | Alterar senha | antiga `config.alterar_senha` |
| `seg.biometria` | Entrar com biometria | antiga `config.biometria` |
| `apar.tema` | Tema e "Personalizar início" | antiga `config.tema` |
| `notif.preferencias` | Ligar/desligar avisos | antiga `config.notificacoes` |
| `ajuda` | "Preciso de ajuda": filtro guiado (assunto → perguntas → resposta → "Isso resolveu?" → chamado técnico). Sem WhatsApp, horário nem e-mail de suporte desde a 2.2 | perguntas e respostas no painel (§5.12) |
| `sair` | Sair | não pode ser desligado; saiu do menu de funções |
| `login.primeiro_acesso`, `login.recuperar_senha` | Tela de login | parte pública do `app_config` |

### 2.4 Outros

- Versão mínima e recomendada **por plataforma** (SOUPM_2_2 §10), com os
  textos da tela de atualização (hoje em `appConfig/versions` e fixos em
  `auth_or_home.dart`).
- Textos fixos que vão para o painel: diálogo de permissão de notificação,
  confirmação ao desligar avisos, "Desenvolvido pelo DTI…", os rótulos do
  Comando.
- **Fica no código (não é do painel):** as regras legais do cálculo de
  inatividade (datas de corte, pedágio, quotas). São regra de negócio e mudam
  com lei, não com clique. O painel pode, no máximo, tirar a função do ar.
---


## 3. Controle de funções: estados e mensagens

### 3.0 Quatro perguntas separadas (revisão de 21/10/2026)

Cada função responde a quatro perguntas, cada uma com o seu campo. Misturar as
quatro num "estado" só fazia ocultar do menu quebrar o card da Início e o push.

| Pergunta | Campo | Quem usa | Se a resposta é "não" |
|---|---|---|---|
| **Visível** no menu e na busca? | `visivel_menu` | Só o app, para desenhar menu, busca e atalhos | Some do menu e da busca. **Continua funcionando** por card, push e link |
| **Autorizado** para este militar? | nível mínimo, papéis, matrículas (§3.3) | API (`app_config` e o endpoint) | A API recusa (`MD-<CHAVE>-RESTRITO`); no menu, oculto ou "Restrito", conforme `fora_do_publico` |
| **Disponível** agora? | `estado` = `ativo` ou `bloqueado` (com motivo, agendamento, volta automática) | API e app | A API recusa com a mensagem do bloqueio; o app mostra a folha |
| **Compatível** com a versão do app? | `versao_min_app` | `app_config` | O app mostra "Atualize o app para usar esta função" (`MD-<CHAVE>-ATUALIZAR`) |

**A API recusa só quando falta autorização ou disponibilidade, nunca por
estar fora do menu.** Exemplos: Contracheques fora do menu continua abrindo
pelo card da Início; `op.plantao` fora do menu continua aceitando o push
antigo, que leva a `op.escalas`.

### 3.1 Disponibilidade (`estado`)

| Estado | O que o militar vê |
|---|---|
| `ativo` | Normal. |
| `bloqueado` | O item aparece apagado (opacidade 0,45) com um selo curto ("Em breve", "Manutenção", "Indisponível"). Ao tocar, abre a **mensagem do bloqueio**. Se o militar chegar à tela por outro caminho (push, card), a tela mostra a mesma mensagem no lugar do conteúdo. |

"Oculto" deixa de ser estado: é `visivel_menu = false` (e, para quem não é
autorizado, `fora_do_publico = oculto`).

**Regra de segurança:** esconder no app não basta. A API recusa pela
autorização e pela disponibilidade, lendo o mesmo registro que o
`app_config` (como as certidões já fazem na emissão). A 2.1.x, que não lê o
menu, recebe a mesma recusa com o código `MD-…` (§9).

### 3.2 Mensagem do bloqueio

Segue a regra do projeto: **nada de "Ocorreu um erro".** Toda mensagem diz o
que aconteceu, o que fazer e tem um código.

| Campo | Exemplo |
|---|---|
| `motivo` | `manutencao`, `em_breve`, `indisponivel`, `restrito`, `atualizar_app`, `personalizado` |
| `selo` | "Manutenção" (curto, aparece no item) |
| `titulo` | "Contracheque em manutenção" |
| `texto` | "Estamos atualizando a folha de outubro. Volte a partir das 18h." |
| `previsao` | `2026-10-21T18:00` (opcional; o app mostra "Volta em 21/10 às 18h") |
| `acao` | `nenhuma`, `avisar_quando_voltar`, `abrir_chamado` (chamado técnico já preenchido com o código), `abrir_link`, `atualizar_app` (opcional) |
| `codigo` | `MD-CONTRACHEQUE-MANUT` (gerado: `MD-<CHAVE>-<MOTIVO>`, vai para o log) |

Cada motivo tem um texto padrão (por exemplo, `em_breve`: "Este recurso estará
disponível em breve."), e o painel pode sobrescrever. O painel mostra uma
**prévia** do aviso exatamente como sai no app (o desenho do `avisoRapido`, ou
do cartão de erro para textos longos).


### 3.3 Público (quem vê)

Cada item da árvore tem, no painel (§6):

- **Nível mínimo** (pelo id do nível, não pelo número: criar um nível no meio
  da escada não desarruma as funções).
- **Papéis que liberam** mesmo abaixo do nível.
- **Matrículas avulsas** (piloto), sempre com data de fim.
- **Versão mínima do app** (`versao_min_app`: função nova só para quem
  atualizou).
- **Quem não alcança:** `oculto` (padrão) ou `bloqueado` com motivo `restrito`.

O antigo perfil `superuser` (nível 1 do SIGRH ou `idPosto < 8`) **sai**. O
Mapa da Força passa a ser "nível mínimo 2" e a tela Níveis de acesso mostra,
antes de ligar, quem ganha e quem perde acesso em relação à regra antiga
(§6.2).

**Como o público é avaliado:** no servidor, a cada `app_config` (com cache
curto). O app manda a credencial da sessão; o servidor resolve nível, papéis e
lotação no SIGRH e devolve a árvore já filtrada. O app nunca decide quem vê o
quê, e cada endpoint de função confere de novo. Antes do login, o
`app_config` devolve só a parte pública.

### 3.4 Agendamento

Todo registro aceita `inicio` e `fim` opcionais. Exemplo: bloquear o
contracheque de 20/10 às 22h até 21/10 às 6h, e voltar sozinho. O
`app_config.php` aplica o agendamento na leitura (sem cron).

---

## 4. Notificações

### 4.1 Regra e caminho

- **Só notificações do SouPMRR.** Comunicados, lembretes, envios do painel e
  avisos automáticos do próprio app (contracheque disponível, certidão
  emitida, resposta de feedback). As notificações dos módulos da intranet
  (`intranet.notificacoes`: SISCHAMADOS, escala, SVI) não entram na aba Avisos
  do app nem no painel (decisão do usuário, 21/10/2026).
- **O push continua pelo FCM**; o armazenamento vai para o Postgres
  (SOUPM_2_2 §13): `soupm_notificacao`, `soupm_notificacao_leitura`,
  `soupm_dispositivo`.
- **Como o painel envia:** grava `soupm_notificacao_envio` (com o filtro e o
  texto) e para. O cron de envio da API do app resolve os destinatários,
  grava uma `soupm_notificacao` por militar (ou uma geral), manda ao FCM em
  lotes de 500 tokens, grava `soupm_notificacao_destino` **por aparelho**
  (aceito pelo FCM, falhou, sem aparelho) e desativa token vencido
  (`UNREGISTERED`). O FCM só confirma que **aceitou** a mensagem, não que ela
  chegou: o painel nunca diz "entregue". "Aberto" vem do evento `push.abrir`
  do app. Ciência de comunicado é outro fluxo (§5.4). O painel acompanha o
  andamento pela mesma linha.
- **Escrita dupla na transição:** enquanto houver 2.1.x, o cron também grava
  no Firestore (SOUPM_2_2 §13, passos 1 a 3). O painel não sabe disso.
- **O que some:** `notificarTodos`, `notificarMilitar` e `notificarEscala`
  (sem autenticação) e o `x-admin-token`, no corte do Firestore.

### 4.1b Push dos módulos da intranet (modelo do SIGE)

Decisão do usuário (21/10/2026): **todos os módulos seguem o modelo do
SIGE**. A intranet não fala com o FCM nem com o app: ela manda o pedido para a
**API do SouPMRR**, que **filtra, gerencia e encaminha** ao app. O filtro
sempre existe:

- só aceita módulos cadastrados, cada um com a sua chave de serviço (em
  `/private`) e ligado no painel;
- confere se o militar tem o app e aparelho com push ativo;
- respeita limite por módulo (por hora e por dia), evita repetido e guarda
  horário silencioso, se configurado;
- registra cada pedido (aceito, recusado e por quê) e cada envio, por
  aparelho, como os do próprio SouPMRR;
- o aviso chega como push e abre a função certa do app (a escala, o chamado),
  mas **não entra na aba Avisos**, que é só do SouPMRR.

No painel, a tela Notificações ganha a aba **Módulos da intranet**: cada
módulo (SIGE, SVI, SISCHAMADOS…) com ligado, limites, tipos de aviso aceitos,
destino no app e o histórico de pedidos. Substitui o `notificarViaSouPM`, que
hoje passa pelas Cloud Functions.

### 4.2 Telas (protótipo: Notificações)

1. **Enviar:** para um militar (busca por matrícula ou nome, mostra aparelhos
   com push ativo), para um grupo (filtros do §4.3) ou para todos. Título,
   texto, destino ao tocar (só chaves da árvore que existem no app) e quando
   (agora ou agendado). Prévia do push no aparelho.
2. **Histórico:** cada envio com autor, data, público (o filtro usado),
   militares alvo, aparelhos, **aceitos pelo FCM**, falhas, sem aparelho e
   quantos **abriram** (`push.abrir` no log).
   "Reenviar para quem falhou".
3. **Agendadas:** com cancelar.
4. **Lembretes automáticos** (P3 do SOUPM_2_2): configurados **só aqui**.
   Cada um com ligado, quando (dias antes) e destino. O militar vê a lista em
   Perfil › Notificações, mas não desliga um por um. Carga inicial: contracheque
   do mês disponível (ligado: é o cron de hoje), férias começam, certidão vai
   vencer, prazo de declaração (segue a pendência), ciência de comunicado, DTI
   respondeu seu feedback (ligado).
5. **Modelos:** textos prontos com campos (`{nome}`, `{posto}`, `{mes}`).

**Confirmação:** todo envio pede confirmação dizendo quantos aparelhos
recebem. Para mais de 500, digitar a quantidade. "Para todos" exige o papel
de Administrador.

### 4.3 Filtros (o máximo de detalhe)

Todos combináveis com **E**; cada filtro aceita vários valores (**OU** dentro
do filtro). E mais: incluir ou excluir matrículas avulsas, e colar uma lista de
matrículas ou importar um CSV.

| Filtro | Exemplo | De onde vem (Postgres) |
|---|---|---|
| Posto/graduação | Cb e Sd | posto ativo: `index_policial_posto_graduacao` (`index_poli_post_grad_activo`) → `posto_quadro` → `posto_graduacao` (`post_grad_sigla`, `post_grad_descricao`); atalho: `recursoshumanos.vw_mapa_forca.posto_graduacao` / `id_posto` |
| Círculo | oficiais, praças, praças especiais | derivado do posto |
| Quadro | QPPM, QOPM, QPC | `posto_quadro.fk_quad_cod` → `quadro.quad_sigla` |
| **Turma (ano de incorporação)** | 2021 | `date_part('year', policial_militar.poli_mili_data_incorporacao)` |
| Período de incorporação | de 01/02/2021 a 30/06/2021 | `poli_mili_data_incorporacao` |
| Tempo de serviço | entre 25 e 30 anos | calculado como em `certidao_dados.php:278-377` (atenção: deduções LTIP/deserção/pena) |
| Comando / unidade / subunidade | CPC, 1º BPM | `vw_mapa_forca.id_comando`, `id_unidade`, `id_subunidade` |
| Situação | serviço ativo, reserva, reformado | `index_policial_status` (`index_poli_stat_activo`; códigos 1 e 8 = ativo) ou `vw_buscar_policial.status` |
| Situação funcional atual | em férias, licença, à disposição | `vw_mapa_forca.id_situacao` → `tipo_situacao_funcional` |
| Sexo | feminino | `policial_militar.fk_tipo_sexo_cod` → `tipo_sexo` |
| Idade | 18 a 30 anos | `age(poli_mili_data_nascimento)` |
| Aniversariantes | do dia, da semana, do mês | `poli_mili_data_nascimento` |
| Cidade de residência | Boa Vista, Rorainópolis | `policial_militar.fk_muni_cod` → `municipios.muni_nome` |
| Naturalidade | — | `fk_cida_nasc_cod` → `cidade_nascimento` |
| Comportamento | excepcional, ótimo | `"Index_policial_comportamento"` (ativo) → `tipo_comportamento` |
| Escolaridade | superior completo | `index_policial_escolaridade` → `tipo_escolaridade` |
| Estado civil / tem dependentes | — | `index_policial_estado_civil`, `policial_dependente` |
| Nível e papel no app | Gestor de unidade; Publicar comunicados | `soupm_nivel` (cálculo do §6.2) e `intranet.usuarios_perfis` (perfis `soupm-*`) |
| E-mail confirmado | sim/não | `qra.sec_users.activation_code` |
| Conta ativa no SIGRH | sim/não | `qra.sec_users.active` |
| Tem o app (aparelho com push) | sim | `soupm_dispositivo` (`ativo`, `matricula`) |
| Versão do app | abaixo de 2.2.0 | `soupm_dispositivo.app_versao` |
| Declaração pendente no ano | sim | a mesma lógica de `buscastatusdeclaracoes.php` |
| Recebeu contracheque no mês | sim | `public.vw_cc_novo_1` |
| Cursos | — | **não existe tabela consultada pela API hoje**; ver com o SIGRH/intranet |

**Cuidados com os dados:** a matrícula é `int` em `policial_militar` e texto em
`qra.sec_users.login`; o CPF aparece com e sem máscara. Aparelho e notificação usam a matrícula
como texto (`VARCHAR(20)`).

**Prévia obrigatória:** antes de enviar, o painel mostra quantos militares o
filtro achou, quantos têm o app, e 20 nomes de amostra (posto, nome, lotação).
Acima de 500 destinatários, pede para digitar a quantidade para confirmar.

**Filtros salvos:** um filtro pode ser salvo com nome ("Turma 2021", "Praças do
CPC") e reaproveitado.

---

## 5. Telas do painel

Todas dentro da casca Nexus 2.0, na ordem de bloco do `REGRAS_DESIGN_2.0` §3:
trilha `SOUPMRR › Tela`, título e uma linha, avisos, explicação (quando há),
ação principal, indicadores que filtram, caixa com busca e tabela, janelas.
Navegação sem recarregar (`data-nx-parcial="/painelsoupmrr"`), confirmação pelo
`NXConfirmar` (perigo com foco no Cancelar), gráficos em HTML/CSS
(`nxc-barras`, `nxc-colunas`), nunca Chart.js nem `alert()`.

Menu lateral do módulo:

| Grupo | Itens |
|---|---|
| Visão geral | Painel |
| O app | Agenda · Funções e menu · Tela inicial · Artes dos cards · Comunicados · Suas pendências · Chamados no app · Versões do app |
| Pessoas e acesso | Níveis de acesso · Papéis · Militares |
| Comunicação | Notificações · Feedback (com contagem de novos) |
| Acompanhamento | Logs e erros (com contagem de erros 24 h) · Alertas (com contagem de abertos) · Bancos e conexões |
| Documentos | Contracheque · Certidões · Declarações (e todo documento que vier) |
| Segurança | Auditoria do painel · Suporte e textos |

Cada item só aparece para quem tem o recurso `soupm.<area>.ver` (§6.3).

Na barra superior não há sino próprio do painel (pedido do usuário): os
avisos do painel (alertas, mudança do Comando) vão para o sino da intranet, e
o feedback se vê na tela Feedback. No lugar, a barra tem **"Buscar no
painel"** (`Ctrl K`, §5.15).

### 5.1 Painel (início do módulo): dashboard do app

A página inicial do módulo é um **dashboard do app**, o mais completo
possível. Por pedido do usuário (21/10/2026), ela **não tem** o bloco "Como
funciona" que o `REGRAS_DESIGN_2.0` §14 pede no topo dos módulos: é uma
exceção aprovada pelo autor do padrão.

**1. Conexões do app (mapa de rede, ao vivo).** Um mapa em SVG em três
faixas: **aparelhos** (Android e iPhone/iPad, com quantidade e versão em uso)
→ **app** (ícone do SouPMRR, militares online) → **serviços**. Cada ponto tem
o ícone do serviço (banco, nuvem do push, intranet, suporte, legislação,
painel), um anel com a cor do status e, quando há problema, um selo no canto.

| Ponto | O que mostra |
|---|---|
| Android, iPhone e iPad | Aparelhos ativos, versões, online agora, tempo de abertura, fechamentos |
| App SouPMRR | Online, sessões hoje, sessões sem fechamento, erros por 1.000 ações, versão do `app_config` |
| API do SouPMRR (`sigrh/`) | Latência, pedidos por minuto, erros; ao abrir, cada módulo com status e tempo (`app_config`, `log.php`, certidões, contracheque, feedback, notificações) |
| Banco SIGRH | Tempo das consultas mais pesadas e o código de erro que isso gera no app |
| FCM (push) | Taxa de entrega, último envio, tokens vencidos removidos, último push silencioso de configuração |
| Firestore (legado) | Só na transição: escrita dupla e quanto falta para o corte |
| API da intranet | Escalas, SVI, férias (e o login a partir da 2.3) |
| SISCHAMADOS | Meus chamados |
| Legislações e POPs | API externa |
| Painel `/painelsoupmrr` | Administradores com sessão, última publicação, fila de envio |

- **Os aparelhos aparecem como "Android" e "iOS"** (o iOS soma iPhone e
  iPad; a divisão fica no detalhe).
- **Faixa de versões** acima do mapa: Android mínimo e alvo, iOS mínimo,
  Flutter e Dart, versão do SouPMRR, FCM e PostgreSQL, numa linha de pílulas.
- **Ficha técnica** em cada ponto (pedido do usuário, 22/10/2026), o máximo
  que se sabe, em grupos, cada um com a origem do dado ("do projeto",
  "registro de versões", "sonda da API", "log do app"):

  | Ponto | O que mostra |
  |---|---|
  | Android | versão mais nova na Play, mínima e recomendada (do painel), versões em uso; `minSdk`, `targetSdk`, `compileSdk`; versões do Android nos aparelhos e fabricantes; build (Flutter, Dart, AGP, Kotlin, Gradle, Java, NDK) |
  | iOS | versão na App Store, mínima e recomendada, em uso; iOS mínimo, SDK e Xcode do build, UIScene; iPhone × iPad e versões do iOS; CocoaPods e Firebase iOS SDK |
  | SouPMRR | versão, build por plataforma, datas de publicação, versão anterior, `versao_config`, funções e módulos; pacotes principais (Provider, http, cofre, biometria, Firebase) com versão; uso agora |
  | API | linguagem e versão (a sonda lê), bibliotecas (TCPDF, PHPMailer), endpoints da 2.2, credencial em uso; pedidos e erros |
  | Banco | versão (`version()`), nome da conexão, tamanho e crescimento, esquemas usados, tabelas `soupm_*` e a maior, retenção, conexões, cache, consulta mais lenta, último backup. **Aviso fixo:** o PostgreSQL 9.6 está sem suporte desde novembro de 2021 |
  | FCM | projeto, como envia hoje (Cloud Functions, Node e versões) e na 2.2 (API HTTP v1 pelo PHP), plugins e SDKs, tópicos legados, entrega em 24 h |
  | Firestore | plugin e SDK, o que ainda está nele (coleções), escrita dupla, corte; aviso de que não há regras no repositório |
  | Intranet, SISCHAMADOS, Legislações, Painel | endereço da rota (sem servidor), autenticação, rotas usadas e que faltam, dono |

  **De onde vem:** o que é do build (SDKs, Flutter, Dart, pacotes) é gravado
  no **registro de versões** a cada publicação (`soupm_versao_app.pilha`, um
  JSONB que o script de build preenche); o que é do servidor (PHP, PostgreSQL,
  tamanho do banco) vem da **sonda**; o resto, do log. Nenhum endereço de
  servidor, usuário ou senha aparece na ficha.
- **Situação de monitoramento de cada serviço:** `monitorado` (tem sonda e
  números reais), `homologado` (ligado ao app, sonda em teste) ou `planejado`
  (o app ainda não usa; hoje, a API da intranet e o SISCHAMADOS). Serviço
  `planejado` aparece em cinza, com linha tracejada, **sem latência nem
  porcentagem inventadas**, e o detalhe diz quando passa a ser medido.
- **Botão "Pausar animação"** no canto do mapa (além de respeitar "reduzir
  movimento"): congela os pontos e os anéis para ler com calma.
- **Linhas vivas:** a cor diz o status (Normal, Lento, Fora do ar,
  Transição, sempre com o nome escrito); a **espessura** diz o volume de
  tráfego; **pontos andam** na direção dos dados (mais devagar quando está
  lento; parados com "reduzir movimento"); e a **latência** fica escrita no
  meio das ligações importantes.
- **Clicar num ponto** destaca o caminho dele (o resto esmaece) e abre o
  detalhe: números, módulos e a **faixa das últimas 24 h** (uma marca a cada
  30 min). "Ver nos logs" abre os Logs já filtrados.
- **Incidente em destaque** acima do mapa quando algo está lento ou fora, com
  o que ele afeta no app ("21 erros CC-LENTO, 340 militares tentaram abrir")
  e a **ação sugerida** de um clique: "Pôr Contracheques em manutenção" (a
  confirmação diz o impacto: quantos militares usam a função por dia e quais
  funções e cards da Início também passam a mostrar a manutenção). A
  manutenção automática volta sozinha quando a sonda medir o serviço normal
  por 10 minutos (ou quando alguém religar).
- **Disponibilidade nas últimas 24 h** logo abaixo, um serviço por linha,
  com a porcentagem.
- **De onde vem:** latência e erro saem dos eventos e erros que o app e a API
  gravam (`soupm_evento`, `soupm_erro`) e da **sonda** da API, que testa cada
  serviço a cada minuto e grava em `soupm_saude` (§8). O painel relê a cada
  15 s, sem recarregar a página.

**2. Agora** (ao lado do mapa): online agora, usaram hoje, ativos em 7 e 30
dias, sessões sem fechamento, erros por 1.000 ações, plataforma (rosca
Android × iOS) e versões em uso.

**3. Gráficos de uso** (logo abaixo, no lugar do gráfico que ficava no fim da
página). No cabeçalho, **"Relatório semanal"** (§5.16):

- aberturas por dia (7 dias, 30 dias, 12 meses), Android e iOS empilhados;
- quando usam: mapa de calor de dia da semana × hora;
- funções mais usadas;
- adoção: militares no SIGRH → com login → com o app → ativos → com e-mail
  confirmado → com biometria;
- erros por hora e códigos mais frequentes;
- tempo de abertura do app (mediana e 95%, por plataforma);
- aparelhos e ambiente: tema, rede, tamanho da fonte, versão do sistema,
  modelos mais comuns;
- buscas sem resultado.

**4. Pede atenção:** código de erro que disparou, mudança do Comando
aguardando aprovação, comunicado com ciência baixa perto do prazo, pendência
com prazo perto e tipo desligado, concessão de nível que vence na semana.

Os gráficos são HTML/CSS e SVG com as cores do tema (`nxc-barras`,
`nxc-colunas`), sem Chart.js, como manda o padrão 2.0. Cada número leva à
tela que o explica (quase sempre Logs e erros, já filtrada). Como os
gráficos de uso agora moram no Painel, a tela de Logs não os repete (regra
"cada gráfico mora em uma tela só").

### 5.2 Funções e menu

Árvore do §2 com busca (nome, chave, sinônimo), selo de estado e nível
mínimo. Ao escolher um item, o editor ao lado:

- nome no app, ícone (só chaves que o app conhece), descrição de uma linha,
  sinônimos e palavras-chave da busca;
- **numa área** (aba Serviços, SOUPM_2_2 §3.3): a **arte de fundo** do cartão
  da área, escolhida no catálogo de artes (§5.3b) ou uma
  imagem aprovada do catálogo de mídia (`soupm_midia`), com a prévia do cartão
  nos dois temas e a conferência do contraste do texto (4,5:1);
- as quatro perguntas do §3.0: **visível no menu** (sim/não), **autorizado**
  (quem vê, abaixo), **disponível** (ativo ou bloqueado) e **compatível**
  (versão mínima do app); se bloqueado, motivo, selo, título,
  texto, previsão de volta, botão da mensagem e o código `MD-…` gerado (§3.2);
- quem vê (§3.3) com a contagem de militares alcançados e o **impacto**:
  quantos usaram a função nos últimos 7 dias, o horário de pico e quantos
  seriam afetados se ela fosse bloqueada agora;
- agendamento (`inicio`/`fim`) e versão mínima do app;
- **"Ver como fica no app"**: a folha de bloqueio desenhada como no app;
- **"Ver o app como…"** um nível ou uma matrícula: menu, Início, o que fica
  bloqueado e o escopo do Mapa da Força. Nada é gravado.

**Mais usados (aba Serviços):** a linha de círculos segue o uso real
(`funcao.tocar` no log). O painel pode **fixar a lista** (escolher e ordenar
até 10 funções) ou deixar automática; função que o militar não pode ver some
sozinha. Fica em `soupm_config`, chave `servicos`
(`{"mais_usados": {"modo": "automatico"|"fixo", "fixos": [...]}}`).

Item com `bloqueavel = false` (`sair`, `aba.inicio`) não mostra o seletor de
estado. Chave nunca se edita: chave nova é cadastro novo, e só vale se o app
tiver o módulo registrado (senão o app mostra "Atualize o app").

### 5.3 Tela inicial

- **Blocos:** lista ordenável (alça com subir e descer, também pelo teclado)
  com os blocos do app e os cards criados no painel. **Todo bloco pode ser
  desligado**, inclusive os fixos: desligado, some do app para todos ou só
  para o público escolhido, e o que está abaixo sobe. "Fixo" quer dizer só que
  o **militar** não pode esconder (SOUPM_2_2 §4.6). Por bloco: ligado,
  público, se o militar pode esconder, a **arte** e o **estilo** (cheio ou discreto, §5.3b).
- **Arte** (novo padrão visual do app, SOUPM_2_2 §4.6; substitui a marca
  d'água): cada bloco escolhe uma arte do catálogo (§5.3b) ou uma **imagem
  aprovada** do catálogo de mídia, que vence a arte (o app põe o mesmo véu
  por cima para o texto manter 4,5:1). Padrões: contracheque `cc`, tempo de
  serviço `ts`, férias `fe`, Dica `dc`, Suas pendências `pe`, Atalhos `cc`,
  card Outubro Rosa `rosa`.
- **Atalhos padrão por nível:** até **12** casas, numa linha só que rola de
  lado no app (SOUPM_2_2 §4.4); o painel mostra a ordem e quantos cabem sem
  rolar num iPhone (cerca de 5). Quem nunca
  personalizou recebe o padrão do seu nível; função que ele não pode ver some
  sozinha.
- **Comando (dados do SIGRH com aprovação; SOUPM_2_2 §4.1).** No app, o
  Comandante-Geral e o Subcomandante-Geral são dois botões separados, e cada
  um abre o próprio cartão. No painel, um cartão por cargo:
  1. **O que o app mostra hoje** (a versão aprovada): foto, posto, nome
     completo, quadro, no cargo desde, na PMRR desde, lotação, cursos e
     mensagem à tropa.
  2. **Do SIGRH:** uma rotina diária (e o botão "Conferir no SIGRH agora")
     busca quem ocupa cada função e traz o máximo que o SIGRH tiver: nome
     completo, posto, quadro, inclusão, data de assunção da função, lotação,
     cursos e foto (`pix_db`). Se algo difere do aprovado, o cartão mostra
     **"Mudança no SIGRH aguardando aprovação"**, com o **antes e o depois**
     campo a campo, e o Painel lista isso em "Pede atenção".
  3. **Aprovar:** o administrador confere e pode ajustar antes: trocar a foto
     pela oficial (envio), escrever a mensagem à tropa, mudar a ordem e
     esconder campos (por exemplo, cursos). **Nada vai para o app sem
     aprovação**; até lá o app continua com a versão aprovada anterior. Recusar
     também é possível (o pendente fica guardado até o SIGRH mudar de novo).
  4. Toda aprovação, ajuste ou recusa vai para `intranet.auditoria`, com antes
     e depois.
  5. Troca de comando sem aprovação não deixa o app errado em silêncio: depois
     de 3 dias pendente, o Painel destaca em vermelho.
  Quem pode aprovar: Administrador do app (e, se o usuário quiser, um papel
  "Aprovar dados do Comando" para a Comunicação Social).
- **Dicas:** texto de uma linha, ícone por chave (sem emoji), tipo, período e
  público.
- **Cards do painel (sem versão nova do app).** "Novo card" abre a escolha
  de um dos 4 modelos que o app já sabe desenhar:

  | Modelo | Para quê | Campos próprios |
  |---|---|---|
  | **Campanha** | campanha, evento, aviso visual (ex.: Outubro Rosa) | selo, título, texto, arte (§5.3b) ou imagem aprovada, botão |
  | **Atalho grande** | levar a uma função com destaque | título, texto, ícone, função de destino |
  | **Número** | um dado de fonte confirmada ("3 escalas este mês") | título, fonte do número (catálogo `soupm_fonte_dados`), texto de apoio, destino |
  | **Lista curta** | até 3 linhas com links | título, linhas (texto + destino) |

  **Nada foge do padrão do app** (pedido do usuário, 21/10/2026): o ícone e a
  imagem vêm do **catálogo de mídia** (`soupm_midia`, só o que foi aprovado);
  a cor vem da **paleta fechada** do DESIGN.md (`soupm_config`, chave
  `paleta`), e o painel confere o **contraste** do texto nos dois temas antes
  de deixar publicar (4,5:1); o card **Número** só usa fontes do **catálogo de
  fontes de dados** (`soupm_fonte_dados`), o mesmo das pendências, e só as
  `confirmada`. Em todos: chave (gerada do título, fixa depois de publicar), público (os
  filtros do §4.3), período, ordem, se o militar pode esconder e o botão
  (abrir função do app, comunicado, link externo `https` ou chamado técnico do
  suporte). Limites de texto por modelo, com contador. **Prévia** do card (com as
  medidas compactas do SOUPM_2_2 §15.2: 14 dentro do card, 6 a 8 do título ao
  conteúdo) nos
  temas claro e escuro e no iPhone e no Android, lado a lado, antes de
  publicar, com o **impacto**: quantos militares e aparelhos o público
  alcança (em destaque quando é "Todos"). **Situação do card:** rascunho,
  **agendado** (início no futuro), publicado e encerrado, como nos
  comunicados. **Publicar** grava o card, invalida o cache do `app_config` e
  tenta um push silencioso só para os aparelhos do público. O texto do painel
  é sempre o mesmo: **"Vale em segundos para quem está com o app aberto, e na
  próxima abertura para os demais"** (o push silencioso é tentativa: o iOS
  limita esses pushes; o que garante é a revalidação da `versao_config`,
  §9.1 nº 12). Modelo de desenho diferente desses 4 exige versão do app.
- **Prioridade na Início (regra única):** um **destaque de abertura** por vez
  (se dois valerem no mesmo dia, vence o publicado primeiro, e o outro fica
  para a abertura seguinte depois que o primeiro for visto); no carrossel,
  urgentes primeiro e depois a ordem do painel; cards e campanhas seguem a
  ordem dos blocos. A Agenda avisa o conflito antes de acontecer (§5.14).
- A personalização de cada militar fica em `soupm_inicio_preferencia`. O
  painel pode "restaurar o padrão" de todos quando mudar a ordem padrão (com
  confirmação).

### 5.3b Artes dos cards

Decisão do usuário (22/10/2026): a arte e as cores dos cartões de Serviços são
o **novo padrão visual de todo o app** (Início, áreas de Serviços e cards do
painel; SOUPM_2_2 §4.6). O painel já vem com as artes configuradas, e o
administrador muda ou cria outras sem versão nova do app.

- **Cada arte tem:** chave (fixa depois de publicada), nome, **três cores da
  paleta fechada** (base, meio e destaque: o degradê vai da base ao meio, e o
  destaque pinta o brilho e as trilhas de circuito) e **três ícones** do
  catálogo do app (um grande e apagado no canto, dois menores).
- **Prévia** nos temas claro e escuro, no iPhone e no Android, e
  **conferência de contraste**: texto branco sobre o véu escuro do pé do
  cartão, no mínimo 4,5:1. Abaixo disso, não publica.
- **Onde é usada:** a lista de blocos, áreas e cards que usam a arte. Editar
  muda todos de uma vez, e a confirmação diz quais.
- **Duplicar, editar, arquivar.** Arte em uso não se arquiva: o painel pede
  para escolher outra nos lugares que a usam.
- **Dois estilos por arte** (decisão do usuário, 22/10/2026): **cheio**, nos
  cards de resumo (degradê, trilhas, ícones e véu), e **discreto**, nas
  superfícies (só a cor de destaque: brilho de 15% no canto, trilhas finas e
  ícones a 9%; o texto segue as cores do tema). A prévia mostra os dois.
- **Arte especial `estrelas`** (decisão do usuário, 22/10/2026; SOUPM_2_2
  §4.1): a arte da Faixa do Comando, que são dois cartões lado a lado no
  **estilo cheio**, como os outros cards. Degradê `#081A36` → `#16396B`,
  brilho dourado `#E0A100` e trilhas finas; no lugar dos 3 ícones, **3
  estrelas de cinco pontas brancas e apagadas no canto direito**, como os
  ícones dos outros cards (uma grande e inclinada, a 30%, e duas menores, a
  24% e 20%); o dourado fica só no brilho e no aro da foto; posto e cargo em
  branco. No cartão aberto, capa azul-marinho com
  brilho dourado e as estrelas grandes e apagadas atrás da foto. O app
  desenha, então o painel não escolhe ícones; as cores ficam guardadas na
  arte (`cor_base`, `cor_meio`, `cor_destaque`). A única configuração é o
  **número de estrelas**, que segue o posto vindo do SIGRH (padrão 3 para
  coronel; a API calcula, §9.1 nº 14). Antes de publicar, o painel mostra o
  aviso **"Confira com o regulamento de uniformes da PMRR"**, porque a
  insígnia muda de corporação para corporação.
- **Superfícies do app** (lista nesta tela): cada lugar fora dos cards de
  resumo escolhe arte e estilo. Padrões: capa do Perfil (`perfil.capa`, `rh`,
  cheio), grupos do Perfil (`rh`, discreto), cartão do nível (`gestao`,
  discreto), Faixa do Comando (`estrelas`, especial, cheio), Suas pendências (`pe`,
  discreto) e Atalhos (`cc`, discreto).
- O desenho (degradê, trilhas, ícones, véu) é do app; o painel só escolhe as
  cores e os ícones. Desenho de arte novo, diferente desse, exige versão do
  app.

**Carga inicial** (cores do protótipo do app, versão 31):

| Chave | Nome | Base · meio · destaque | Ícones |
|---|---|---|---|
| `cc` | Contracheque | `#0A2350` `#1565C0` `#4FD8F0` | payments, receipt_long, savings |
| `ts` | Tempo de serviço | `#251800` `#8A5A00` `#FFC233` | military_tech, hourglass_top, workspace_premium |
| `fe` | Férias | `#00303A` `#00838F` `#80DEEA` | beach_access, flight, wb_sunny |
| `dc` | Dica | `#1A1846` `#4338CA` `#A5B4FC` | tips_and_updates, search, lightbulb |
| `pe` | Pendências | `#2B0F12` `#9F1D2B` `#FF9E9E` | pending_actions, assignment_late, task_alt |
| `rosa` | Outubro Rosa | `#3A0A1E` `#B0225A` `#FF8FB8` | favorite, volunteer_activism, health_and_safety |
| `rh` | Minha vida funcional | `#14205C` `#4338CA` `#38BDF8` | badge, receipt_long, verified |
| `operacional` | Serviço operacional | `#071A33` `#1D4ED8` `#EF4444` | local_police, calendar_month, shield |
| `normas` | Normas e procedimentos | `#2A1704` `#A15C07` `#FCD34D` | gavel, menu_book, balance |
| `gestao` | Gestão | `#1A1405` `#7A5800` `#FFC233` | monitoring, groups, military_tech |
| `atendimento` | Atendimento DTI | `#032A28` `#0F766E` `#5EEAD4` | support_agent, forum, build |
| `institucional` | Institucional | `#06281A` `#15803D` `#86EFAC` | account_balance, campaign, newspaper |

**Sugeridas para campanhas** (cadastradas como sugestão, ativadas com um
clique):

| Chave | Nome | Base · meio · destaque | Ícones |
|---|---|---|---|
| `aniversario_pmrr` | Aniversário da PMRR (cores nacionais) | `#0A2A12` `#15803D` `#FACC15` | celebration, flag, shield |
| `operacao` | Operação (azul policial com vermelho) | `#050B1F` `#1E3A8A` `#EF4444` | local_police, emergency, radar |
| `setembro_amarelo` | Setembro Amarelo | `#2A2200` `#A16207` `#FDE047` | psychology, favorite, diversity_1 |
| `novembro_azul` | Novembro Azul | `#0A1A3A` `#1D4ED8` `#93C5FD` | health_and_safety, man, favorite |

As cores das artes formam a **paleta fechada** (`soupm_config`, chave
`paleta`); cor nova entra na paleta antes, com a conferência de contraste.

### 5.4 Comunicados

- **Lista administrativa:** indicadores (no ar, agendados, ciência pendente,
  encerrados) e tabela com categoria (cor e nome), período, público, leitura %,
  ciência % e situação.
- **Editor com prévia ao vivo** do cartão exatamente como no app (anatomia do
  SOUPM_2_2 §4.2), nos dois temas, com contador de caracteres: **título até
  30, resumo até 70, pílula até 16**. Campos: categoria, origem, título,
  resumo, pílula (data ou prazo), arte opcional (sem arte, vale a ilustração
  da categoria), texto completo, público (os filtros do §4.3, com a contagem),
  início, fim, ordem, urgente, destaque de abertura (e "abrir até dar
  ciência"), ciência obrigatória com prazo, enviar push junto.
- **Alcance e melhor horário:** o editor mostra quantos militares e
  aparelhos o público alcança e sugere o horário de push em que esse público
  mais abre o app (do mapa de calor), com a leitura esperada no primeiro dia.
- **Urgente e ciência são independentes.** Ciência gera a pendência
  `soupm.ciencia_comunicado` até o prazo.
- **Publicar** pede confirmação dizendo quantos militares veem e quantos
  aparelhos recebem push. Depois de publicado, editar o texto cria uma versão
  nova (o militar que já deu ciência continua com a ciência da versão que leu;
  a tela mostra "texto alterado em …").
- **Relatório de leitura e ciência** por grande comando, unidade e
  subunidade, com a lista de quem falta (posto, nome de guerra, lotação) e
  "Lembrar quem falta" (push só para eles). Gestor de nível 3 vê a própria OPM;
  nível 5 vê a PMRR (SOUPM_2_2 §6.3).
- **Categorias:** nome, cor e ícone (a cor tinge o cartão).
- **Quem publica:** papel "Publicar comunicados". No início ninguém tem: só o
  Administrador publica. O papel pode ganhar limite de público (por exemplo,
  só a própria diretoria) quando for delegado.

### 5.5 Suas pendências

**Todos os tipos começam desligados.** O usuário liga um por um no painel.
Cada tipo tem um `fonte_status`:

| `fonte_status` | Quer dizer | Pode ligar? |
|---|---|---|
| `confirmada` | A regra foi escrita e conferida com matrículas reais na simulação | Sim |
| `a_homologar` | O dado existe, mas a regra ainda não foi conferida | Não. "Homologar" roda a simulação com matrículas escolhidas e, se o administrador confirmar, passa a `confirmada` (com auditoria) |
| `futura` | Depende de um módulo que ainda não chegou | Não |

Na carga inicial **nenhum tipo é `confirmada`**: os que o catálogo do
SOUPM_2_2 §4.3 dava como "pronto na 2.2" entram como `a_homologar`
(inclusive SISCHAMADOS e `patrimonio.vistoria_viatura`), e os demais como
`futura`. Tela:
explicação (cada sistema calcula as suas → você liga e ajusta → o app
mostra), indicadores (cadastrados, ligados, confirmadas, a homologar, futuras),
fichas por sistema, tabela com interruptor, e a janela de configuração de cada
tipo com prévia do item no app.

**Configurável por tipo:** ligado; obrigatória ou lembrete; título e texto
com campos (`{prazo}`, `{dias}`, `{numero}`, `{titulo}`, `{pct}`); ícone;
função que resolve; prazo (data fixa ou calculado pela fonte); antecedência
(começa a aparecer N dias antes); período de cobrança (início e fim);
público; prioridade; dispensável (só lembrete); push (dias antes do prazo).
Antes de ligar, o painel diz **quantos militares o tipo cobraria hoje** e em
quais unidades a proporção é maior. Mais **"Simular para uma matrícula"**, que roda os tipos (inclusive os
desligados) e mostra o que o app receberia, com o tempo de cada fonte.

**Catálogo:** o canônico é o do SOUPM_2_2 §4.3: **37 tipos**, com chave,
sistema, o que cobra, sugestão de padrão e quando fica pronto. Os 7 que este
plano propôs (`sigrh.ferias_inicio`, `soupm.senha_antiga`, `soupm.biometria`,
`svi.adesao_aberta`, `sige.falta_justificar`, `patrimonio.vistoria_viatura`,
`gestao.mapa_forca_conferir`) já entraram lá em 21/10/2026. O painel cadastra
os 37, **desligados**, na carga inicial.

Só `confirmada` liga. `a_homologar` mostra "Homologar"; `futura` aparece
travada até o módulo chegar.

"Sugestão" é o valor com que o tipo é cadastrado; quem decide é o painel.
**Módulo novo** que quiser cobrar algo expõe um endpoint de pendências no
formato comum (`{referencia, prazo, dados}` por matrícula, com tempo limite
de 3 s) e registra o tipo pela migração dele, **desligado**. O app não muda.
Fonte que não respondeu vira o item "Não foi possível conferir {sistema}"
com `PD-<SISTEMA>-<falha>`, nunca some.

### 5.6 Versões do app

Android e iOS têm versões separadas, cada uma com o próprio número
(SOUPM_2_2 §10). Um cartão por plataforma, cada um com a sua mínima, a sua
recomendada e **os próprios textos** (título e "o que há de novo"
da tela de atualização). O link da loja é escolhido pelo app. Antes de
salvar, o painel diz quantos aparelhos de cada plataforma passam a ver a tela
obrigatória (de `soupm_dispositivo.app_versao`). Abaixo dos cartões, o
**histórico de versões publicadas** de cada loja (`soupm_versao_app`: versão,
build, data, situação na loja, notas), que o painel atualiza a cada envio.
Até o corte do Firestore (critério do SOUPM_2_2 §13: 30 dias nas duas lojas e
menos de 2% de aberturas em versões antigas, por plataforma, ou 90 dias no
máximo), o painel grava também um **mínimo legado** em `appConfig/versions`,
para as 2.1.x, que leem um `min_version` só, sem plataforma. O valor é **o
menor dos dois mínimos, e nunca acima da última versão publicada em cada
loja**: um mínimo que só existe no Android faria o iPhone 2.1.x pedir uma
versão que a App Store não tem. A tela mostra o mínimo legado calculado e
**avisa e bloqueia** o salvamento quando ele ficaria acima do que uma das lojas
tem publicado.

Cada texto fala só da própria loja (APRENDIZADOS §31): o painel recusa
"Android", "Play" ou "APK" no texto do iOS, e "iPhone" ou "App Store" no do
Android.

### 5.7 Militares (suporte)

Busca por matrícula, nome de guerra ou CPF. Mostra lotação, nível e o
**porquê** (a regra que colocou o militar ali), papéis, e-mail (mascarado) e se
está confirmado, aparelhos (com versão, push ativo, último uso) e as últimas
ações e erros do log.

**Diagnóstico automático** no topo: login no SIGRH ativo ou bloqueado por
tentativas, e-mail confirmado, aparelhos e versões (com aviso de versão
antiga), push ativo e último entregue, erros de hoje (e se o erro é da conta
ou de um serviço) e feedback em aberto. Embaixo, uma **resposta sugerida** para
o suporte ("a conta está certa; o contracheque está lento por causa do SIGRH").

Ações (cada uma pede motivo e vai para a auditoria):

- **Resetar a senha** (só Administrador): invalida a senha atual, tira todos
  os aparelhos da conta e manda um código de 6 dígitos ao e-mail confirmado,
  pelo mesmo fluxo do `recuperar_senha.php`. **Ninguém vê nem digita senha de
  outro militar.** Sem e-mail confirmado, o painel orienta o Primeiro acesso.
  Até a 2.3 a senha é a do SIGRH (`qra.sec_users`); a partir da 2.3, a da
  intranet (`intranet.usuarios.senha_local`), uma só para os dois.
- **Desconectar todos os aparelhos.**
- **Ver o app como este militar.**
- **Enviar notificação** e **ver os logs** dele (atalhos).

### 5.8 Logs e erros

O mais detalhado possível (SOUPM_2_2 §9.2): **toda interação do militar vira
evento** `<modulo>.<acao>`, com a chave da função e o resultado (ok,
cancelado, falhou + código). Cada registro traz matrícula, aparelho, sessão,
plataforma, versão do sistema, modelo, versão e build do app, tipo de rede,
tema, tamanho da fonte e as duas horas (aparelho e servidor). Unidade e nível
o servidor resolve pela matrícula na consulta.

**Filtros sem precisar saber chave nem código** (pedido do usuário,
21/10/2026):

- **"+ Filtro"** abre a lista de campos: militar, unidade, nível, função,
  evento, resultado, código de erro, plataforma, versão do app, modelo do
  aparelho, rede e sessão. Escolhido o campo, aparece a **lista dos valores
  que existem**, com busca e a contagem de cada um, escrita para gente:
  "Contracheques" (com `rh.contracheques` embaixo, em cinza), "Baixou o PDF
  do contracheque" (`contracheque.pdf_baixar`), "CC-LENTO — o banco do SIGRH
  demorou mais de 15 s", "SD QPPM STIVES DA SILVA · Mat. 1234567 · 2ª Cia".
  Cada filtro pode ser **"é"** ou **"não é"**.
- **Facetas** ao lado da tabela: os 5 valores mais frequentes de função,
  evento, resultado, código, unidade, plataforma, versão e rede, com barra de
  proporção e contagem. Um clique filtra; o "−" exclui.
- **Qualquer valor sublinhado na tabela** (militar, unidade, função, evento,
  código, versão, modelo, rede) vira filtro com um clique.
- **Período** em atalhos (última hora, hoje, 7 dias, 30 dias) ou de/até com
  hora.
- Histograma do período logo abaixo dos filtros (erros em vermelho), que
  muda junto com os filtros.
- Os filtros ativos ficam como pílulas removíveis e vão para a URL. **Meus
  filtros** guarda combinações com nome.
- As listas de valores vêm do próprio log do período e do catálogo
  (`soupm_evento_catalogo` para o nome do evento, `soupm_menu_item` para o
  nome da função, `soupm_config`, chave `erros`, para o significado do código, a
  mesma que a API usa; fase App 0). Nada é digitado de cabeça.

**Abas:** Eventos, Erros, Fechamentos (`AP-FATAL-*`), Sessões e Catálogo.

- **Linha do tempo da sessão:** tudo o que o militar fez, na ordem, da
  abertura até o erro ou o fechamento, com o tempo entre cada passo. Abre de
  qualquer evento ou erro (pelo `sessao_id`) e do feedback que veio de uma
  tela de erro.
- **Detalhe do erro:** aparelho, versão, sessão, tela, último evento,
  mensagem técnica, pilha resumida (`AP-FATAL`), se foi mostrado ao militar e
  o feedback ligado.
- **Exportar CSV** do resultado do filtro (até 100 mil linhas, gerado em
  segundo plano; o arquivo sai sem nome, só matrícula, e o pedido vai para a
  auditoria).
- **Filtros salvos** por pessoa ("Erros de contracheque no Android",
  "Sessões do 1º BPM hoje").
- **Catálogo de eventos:** a lista oficial de `<modulo>.<acao>` com
  descrição, dados esperados, desde que versão existe, quantas vezes apareceu
  em 7 dias e quando foi visto por último. Ela serve à regra do CLAUDE.md
  ("função nova só está pronta com os eventos no catálogo e aparecendo no
  painel"): evento do catálogo que nunca chegou fica marcado "Nunca visto" e
  evento que chega sem estar no catálogo fica "Fora do catálogo".
- **Indicadores** ficam no Painel (§5.1), que é onde moram os gráficos de
  uso; a tela de Logs é para investigar.

**Retenção (log leve, aprovado e aplicado em produção em 22/10/2026):** eventos
detalhados **30 dias**, erros **1 ano** (cada erro leva os últimos 20 passos da
sessão em `soupm_erro.passos`, que contam o caminho até a falha depois que o
detalhe some) e resumo diário `soupm_uso_dia` **2 anos** (dia, evento, função,
plataforma, versão: vezes, militares, falhas), montado por um cron noturno da
API que refaz os últimos 3 dias. Não viram linha: `app.fundo`, `app.voltar`,
`tela.sair`, `rede.trocou` e `config.recebida` (só aparecem como passos).
Índices do detalhe: (recebido_em), (matricula, ocorrido_em) e (sessao_id); o
(evento, ocorrido_em) saiu, porque os gráficos leem o resumo. Uma tabela por
tipo, com o mesmo nome lido pelo painel se um dia virar tabela por mês.

**Nada sensível no log** (CLAUDE.md, "Tudo tem log"): o painel não tem como
mostrar senha, MD5, token, CPF completo, valor de contracheque, conteúdo de
documento nem texto de feedback, porque eles nunca chegam lá. Quem vê logs:
Administrador, Atender feedback e Consulta. Cada busca por matrícula fica na
auditoria (quem olhou o quê de quem).

### 5.9 Feedback

Caixa de entrada própria (padrão `nxc-feed`), **fora do SISCHAMADOS**:

- **Abas por situação** (SOUPM_2_2 §8.2): Recebido, Em análise, Planejado,
  Concluído, Arquivado. Fichas por tipo (Melhoria, Função nova, Elogio).
  Desde a 2.2 é **só sugestões e elogios** (decisão do usuário, 22/10/2026):
  o tipo "Problema" saiu, e problema técnico é chamado no SISCHAMADOS. Cada feedback tem protocolo (`FB-2026-00042`).
- **Linha:** tipo, título, trecho, versão e plataforma, anexos, quando.
- **Detalhe:** texto, **anexos** (prints e vídeos, até 5 e 25 MB no total,
  com miniatura e player; **só o Administrador abre**, e os anexos são
  apagados **180 dias** depois que o feedback é concluído ou arquivado), contexto do aparelho (modelo, sistema, versão, tela
  de onde veio, últimos códigos de erro com link para o log).
- **Classificar:** tipo, prioridade, função (chave da árvore), rótulos,
  "duplicado de #…" (soma votos no pedido original).
- **Responder:** a resposta vai como notificação do SouPMRR e aparece em
  **Minhas mensagens** (Sugestões e elogios, no app). O militar
  pode responder de volta (conversa). Pergunta do DTI aguardando o militar
  cria a pendência `soupm.feedback_resposta`.
- **Concluir ou arquivar.** Feedback não vira chamado. Se chegar algo técnico
  (erro, acesso, conta), a equipe responde com a resposta pronta "Isso é um
  problema técnico", que leva ao militar um **botão "Abrir chamado técnico"**
  (o chamado abre já preenchido com o assunto) e arquiva o feedback.
- **Indicadores:** novos, em análise, técnicos encaminhados para chamado em 30 dias, pedidos de função
  mais votados.
- **Assuntos em alta:** o painel agrupa feedbacks parecidos (mesma função,
  mesma tela, mesmo código de erro, palavras em comum) e mostra quantos pedem
  a mesma coisa. Um clique junta o grupo num feedback principal
  (`grupo_id`), e a resposta pode ir para todos de uma vez. Cada militar recebe a
  resposta em Minhas mensagens como uma mensagem normal da equipe, sem saber
  quem mais está no grupo.

Alinhado com o SOUPM_2_2 §8 (atualizado em 21/10/2026): o envio vai para a
API do app e fica em `soupm_feedback`; "Meus chamados" continua no app só para
chamados de suporte do SISCHAMADOS.

### 5.10 Documentos (contracheque, certidões, declarações)

Regra do CLAUDE.md, pedido do usuário de 21/10/2026: **documento é da API, e o
padrão dele é do painel.** Todo documento que o militar vê ou baixa segue o
modelo das certidões (Anexo A): a API monta o PDF, confere os dados antes e
devolve o arquivo pronto com hash; o padrão fica no banco e é editado aqui; o
app só pede, mostra, guarda e compartilha. O contracheque, que hoje é montado
no app (`page_contracheque.dart`, dart_pdf), migra para a API (fase no
SOUPM_2_2). Documento novo nasce na API, nunca no app.

Toda tela de documento tem as mesmas abas (o protótipo mostra o
contracheque):

| Aba | O que configura |
|---|---|
| **Serviço** | Liga e desliga (desligado, o app mostra a mensagem com código), meses ou períodos disponíveis, limite de PDFs por hora, quando o mês novo aparece, push de "disponível", valores escondidos por padrão |
| **Padrão do PDF** | Título, marca d'água (brasão, desenho ou nenhuma), mensagem do mês (opcional, sai no PDF de todos), rodapé, nome do arquivo, cor dos títulos (documento oficial em preto, APRENDIZADOS §24). Cabeçalho oficial fixo: "GOVERNO DO ESTADO DE RORAIMA / POLÍCIA MILITAR DO ESTADO DE RORAIMA / DIRETORIA DE RECURSOS HUMANOS - PMRR" |
| **Blocos e rubricas** | Blocos ligados, desligados e em ordem (cabeçalho, totais, autenticidade e rodapé ficam com cadeado); rubricas em tabela: código (do SIGRH), **nome de exibição**, **ordem**, **grupo** (por exemplo, "Consignados" numa linha só) e **visível**; mais esconder as zeradas e selo P/D. Só o texto muda: código e valor vêm do SIGRH. As rubricas ficam dentro do `padrao` JSON da versão, para cada PDF saber com que nomes saiu |
| **Mensagens** | Cada falha com código e texto (`CC-LENTO`, `CC-SEM-FOLHA`, `CC-DESLIGADO`, `CC-PDF`, `CC-HASH`), gravados em `soupm_config` (`erros`) |
| **Versões** | Rascunho, publicada, substituída; comparar e voltar. Cada PDF guarda a versão do padrão com que saiu |

- **Prévia do PDF** ao lado, gerada pela mesma rotina da API, com o militar
  fictício (SD STIVES DA SILVA), com um caso longo fictício (42 rubricas) e,
  só para o Administrador, com uma matrícula real (o PDF não sai do painel e a
  consulta vai para a auditoria). Antes de publicar, conferir o caso mais
  curto e o mais longo (APRENDIZADOS §14 e §24).
- **Publicar** pede confirmação e vale para os PDFs gerados dali em diante.
  A **versão do padrão sai impressa no PDF** (no quadro de autenticidade).
- **QR de conferência pública** (decisão do usuário, 21/10/2026), como na
  certidão: o PDF traz o código e o QR, que abre uma página pública de
  conferência. Proposta do que a página mostra, para o usuário confirmar na
  implementação: situação (válido, ou substituído por uma retificação da
  folha), mês e tipo de folha, nome com o meio abreviado, matrícula parcial e
  os **totais** (proventos, descontos e líquido) para comparar com o papel.
  **Nunca** as rubricas, o CPF, a conta bancária nem os consignados. Cada
  conferência vai para o log, e o painel mostra as conferências na aba
  Emissões do documento, como já faz com as certidões. O endereço da página,
  depois de impresso, nunca pode mudar (mesma regra do `verificar.php`).
- **API e log:** o app pede o PDF pronto a `contracheque_pdf.php` (mês, ano,
  tipo de folha), que confere os dados e devolve com SHA-256. Eventos:
  `contracheque.pdf_pedir`, `contracheque.pdf_conferir` (hash conferido) e
  `contracheque.pdf_baixar`. O app compara o hash antes de guardar.
- Indicadores: PDFs gerados em 30 dias, tempo para gerar, falhas em 24 h,
  versão em uso.
- **Três prazos diferentes, cada um com o seu campo** (revisão de 21/10/2026;
  hoje o `validade_dias` das certidões faz os três papéis):

  | Prazo | Para quê | Exemplo |
  |---|---|---|
  | Validade do documento | Até quando ele vale para quem recebe | Certidão: 30 dias. Contracheque: não vence (é do mês) |
  | Download no app | Por quanto tempo o militar consegue baixar de novo pelo app | 30 dias (certidão), 24 meses (contracheque) |
  | Retenção do registro de autenticidade | Por quanto tempo o QR continua respondendo e o hash fica guardado | **1 ano** para todos os documentos (decisão do usuário, 21/10/2026: "pode ser 1 ano só o QR Code válido") |

  A página do QR responde durante toda a retenção, mesmo depois da validade
  (mostra "vencido em …"). **Depois de 1 ano**, responde que o registro de
  conferência expirou (com a data de emissão, se o código for válido), nunca
  "não existe".
- **Declarações (por campanha):** decisão do usuário (21/10/2026). Ficam
  **fechadas por padrão**. O painel **abre a campanha de um ano específico**
  (bens, IRPF, parentesco, acúmulo), com início e prazo, como a declaração do
  imposto de renda. Fora da campanha, o app e a API **recusam o envio e dizem
  por quê** (`DC-FECHADA`: "A declaração de bens de 2026 ainda não foi aberta
  pela DRH" ou "O prazo terminou em 31/10/2026"). A pendência
  `sigrh.declaracao_*` **só existe com a campanha aberta** (e só cobra quem
  não enviou). A campanha aparece na Agenda. Comprovante em PDF com código e
  QR, no padrão do painel.

#### Certidões

O que já existe (Anexo A), agora com tela: tipos (liga e desliga, título,
nome curto, descrição, ícone, ordem, etapas, motivo quando desligado), textos
e ressalvas (com a versão da declaração), emissões (busca por matrícula ou
código, **revogar** com motivo), verificações do QR. Texto de documento
oficial só muda com aval da DRH: o painel pede a confirmação "aval da DRH
recebido em …" e registra na auditoria.

### 5.11 Auditoria do painel

Toda alteração e todo envio, com quem, quando, IP, área, chave e **antes e
depois** em JSON. Grava em `intranet.auditoria` pelo
`registrarAuditoria('soupm', …)` que a intranet já tem, em vez de criar a
`soupm_admin_log` do plano anterior. Indicadores: pessoas com papel no painel
(e quando a lista de administradores foi revisada), alterações em 7 dias, senhas resetadas em 30 dias, sessões abertas. Ninguém
apaga registro de auditoria.

**Restaurar (só configuração reversível):** cada linha da auditoria tem o
`antes` e o `depois`. "Restaurar" aparece **só** em mudança de configuração
que pode voltar (estado de função, card, bloco da Início, regra de nível,
papel, padrão de documento, versão mínima, textos). A janela mostra **o antes
e o depois daquele evento exato**, avisa se o item mudou de novo depois dele
(aí oferece comparar com o estado atual) e gera uma linha nova ao restaurar.
**Não há restaurar** em ações que já produziram efeito fora do banco: push
enviado, comunicado publicado (encerrar é outra ação), reset de senha,
revogação de certidão, e-mail enviado. Essas linhas mostram o selo
"Irreversível".

### 5.12 Suporte e textos

**Sem WhatsApp, horário nem e-mail de suporte a partir da 2.2** (decisão do
usuário, 22/10/2026): todo suporte é chamado técnico no SISCHAMADOS. O bloco
`ajuda` do `app_config` deixa de trazer esses campos.

**"Preciso de ajuda" (filtro guiado).** No app: assunto → perguntas comuns →
resposta com botão para a função certa → "Isso resolveu?" → se não, chamado
técnico já preenchido. No painel, tudo isso é cadastrado aqui:

- **Assuntos** (nome, ícone, ordem): por exemplo Acesso e senha, Contracheque,
  Certidões, Férias, O app.
- **Perguntas** de cada assunto (pergunta, resposta curta, ordem, **função de
  destino** da árvore, que vira o botão da resposta, e o tipo e categoria do
  SISCHAMADOS para o chamado, se não resolver).
- **Indicadores por resposta:** quantos abriram, quantos marcaram "resolveu"
  (`ajuda.resolveu`) e quantos terminaram em chamado (`ajuda.abriu_chamado`),
  com a taxa de resolução. Resposta com muitos chamados aparece em destaque
  para ser reescrita.
- Prévia do caminho no app, nos dois temas.

Também ficam aqui o rodapé da Início, textos fixos que vêm para o painel (SOUPM_2_2 §2.4) e os
parâmetros técnicos do app no `app_config` (tempo limite das chamadas, lote e
intervalo do log).

### 5.13 Alertas

Regras que vigiam o app sozinhas e avisam quem precisa agir, no **sino da
intranet** (`intranet.notificacoes`) e, se marcado, por e-mail. Nada vai para
o app do militar.

- **Regras prontas** (carga inicial; cada uma liga e desliga): código de erro
  3× acima da média da mesma hora; serviço lento ou fora (sonda); fechamentos
  do app acima de N numa versão; queda de aberturas contra a mesma hora da
  semana anterior; ciência baixa perto do prazo; feedback com palavra de
  atenção ("não consigo entrar"); mudança do Comando parada há 3 dias.
- **Nova regra** montada por listas (quando, de quê, passar de quanto, em que
  janela, avisar quem, como), com a prévia "teria disparado 2 vezes nos
  últimos 30 dias".
- **Disparos:** aberto ou resolvido, quem viu, quanto tempo até alguém agir,
  e a **ação sugerida** (manutenção, subir a versão recomendada, lembrar quem
  falta).
- Avaliação por um cron do painel a cada minuto, lendo `soupm_erro`,
  `soupm_evento` e `soupm_saude` (§8).

### 5.14 Agenda do app

Tudo o que tem data num calendário só (semana ou mês): comunicados (início,
fim, prazo de ciência), cards, bloqueios e manutenções agendadas, pendências
(período de cobrança e prazo), push agendados, aprovações paradas e versões
mínimas programadas. O painel **avisa conflitos** pela regra de prioridade da
Início (§5.3): dois destaques de abertura no mesmo dia (diz qual vence), card e comunicado sobre o mesmo assunto, manutenção no
horário de pico. Clicar num item abre a tela dele.

### 5.15 Buscar no painel (`Ctrl K`)

Um campo na barra superior que acha qualquer coisa: telas do painel,
militares (nome, matrícula), funções do app (nome, chave, sinônimo),
comunicados, feedbacks (protocolo, texto), códigos de erro (com o
significado) e tipos de pendência. Sem acento e sem caixa. O resultado leva
direto ao lugar: a função já selecionada, o código já filtrado nos Logs, o
feedback já aberto. Só aparece o que o papel da pessoa pode ver.

### 5.16 Relatório semanal

Um resumo do Painel toda segunda de manhã (dia e hora configuráveis), por
e-mail e no sino da intranet, para os administradores e, se o usuário quiser,
para o Alto Comando: uso, disponibilidade e incidentes da semana, leitura e
ciência dos comunicados, assuntos em alta no feedback e os 5 códigos de erro
que mais cresceram. "Enviar prévia para mim" antes de ligar.

### 5.17 Bancos e conexões

Pedido do usuário (21/10/2026). Lista dos **bancos e serviços** que o app usa
(os do `soupm_servico` com tipo banco: o banco do SIGRH, que tem também o
Comando e os cursos, o banco das tabelas `soupm_*` e os que vierem), e, para
cada um, **quais funções dependem dele**, a situação (monitorado, homologado,
planejado), a sonda (tempo e falhas) e a disponibilidade de 24 h.

- **Credenciais nunca saem do servidor.** Ficam só em `/private` no servidor
  da API, com um **nome de conexão** (`sigrh_principal`, `intranet_novo`). O
  painel e o navegador veem só esse nome, a situação, a sonda e as funções
  ligadas. Nenhum endereço, usuário ou senha aparece na tela, no HTML nem no
  log.
- **Migração do SIGRH para a intranet:** a intranet é o sistema novo para onde
  o SIGRH vai migrar, e o banco é o mesmo (uma cópia). Trocar o banco que o app
  usa é **trocar o nome de conexão apontado**, com:
  1. **prévia:** a sonda testa a conexão nova, roda as consultas de cada função
     ligada com matrículas escolhidas e compara com a atual (tempos e
     resultados);
  2. **troca** com confirmação que diz quais funções mudam de banco;
  3. **auditoria** e **voltar** com um clique (a conexão anterior fica
     guardada).
- Pode trocar por função (por exemplo, só Certidões primeiro) ou tudo junto.

### 5.18 Chamados no app (configuração do SISCHAMADOS móvel)

Pedido do usuário (22/10/2026). **O painel não atende chamados e não tem
botão para o SISCHAMADOS.** O lado de quem pede entra completo na 2.2
(SOUPM_2_2 §8.3, fase 3c): abrir em 3 passos com até 5 anexos, responder,
confirmar a solução e avaliar de 1 a 5 estrelas. O atendimento continua na intranet, no módulo
SISCHAMADOS, como hoje: triagem, técnico, fila e resposta. No app, o militar
só abre, acompanha, responde quando pedirem e avalia (`atend.chamados`).

**Chamado vindo de uma tela de erro** (decisão do usuário, 22/10/2026): o
botão "Relatar este problema" das telas de erro virou **"Abrir chamado
técnico"**. A tela de erro do app tem o bloco "Detalhes técnicos" (código,
data e hora, tela, chave da função, origem, versão e build, sistema e
aparelho, conexão, id em `soupm_erro` e id da sessão), e **esse mesmo
conjunto** vai no chamado. No SISCHAMADOS, a
equipe vê esse conjunto e um link "Ver no log do SouPMRR", que recebe o
id do erro e o id da sessão e abre a linha do tempo da sessão no painel
(§5.8). Os chamados que vêm de "Preciso de ajuda"
levam a pergunta que não resolveu.

- **Selo na intranet:** todo chamado aberto pelo app aparece no SISCHAMADOS
  com o selo **"Aberto pelo SOUPM"** (na lista, no painel de atendimento e no
  detalhe), para a equipe saber de onde veio. O chamado guarda a origem
  (`canal = 'soupm'`) e, se o militar permitir, a versão do app e o aparelho.
  Isso é feito do lado da intranet (sessão "Chat Intranet").
- **O que o painel configura** (tela "Chamados no app", grupo O app), o
  máximo possível, para não depender de código:
  - liga e desliga a função no app (`atend.chamados`, com mensagem de
    bloqueio como qualquer função, §3);
  - liga e desliga o acesso móvel do SISCHAMADOS (`api_mobile_ativa`) e o
    prazo da sessão móvel;
  - quais **tipos e categorias** do catálogo do SISCHAMADOS aparecem para
    abrir pelo app (por exemplo, "Senha e acesso" e "Rede", sem "Compra de
    equipamento"), com o texto de orientação de cada um;
  - anexos aceitos no app (quantidade e tamanho, dentro do limite do
    SISCHAMADOS);
  - textos da tela no app (topo, lista vazia, confirmação de envio);
  - avisos ao militar pelo push (resposta da equipe, aguardando você,
    resolvido), pelo filtro do §4.1b;
  - pendências ligadas ao SISCHAMADOS (`sischamados.aguardando_solicitante`,
    `sischamados.avaliar`), como qualquer tipo do §5.5.
- **Indicadores** (sem nomes, só números): chamados abertos pelo app em 7 e
  30 dias, por tipo, tempo até a primeira resposta, soluções confirmadas e
  recusadas e avaliação média (estrelas). Vêm dos eventos `chamado.*` e dos
  erros `CH-` do log (SOUPM_2_2 §9.2).
- **API móvel do SISCHAMADOS:** faltam 4 rotas, pedidas à sessão da intranet
  (a web já faz tudo em `ChamadoController`): `POST v1/chamados/{id}/mensagens`
  (com anexo), `POST v1/chamados/{id}/confirmar` (`resolveu`, `nota`,
  `comentario`), `POST v1/chamados/{id}/reabrir` e
  `GET v1/chamados/{id}/anexos/{n}`. Para ver
  um chamado, a equipe usa o SISCHAMADOS na intranet.
- **Onde fica a configuração:** o que é do app (função, textos, push,
  pendências) fica nas tabelas `soupm_*`; o que é do SISCHAMADOS (acesso móvel,
  tipos e categorias liberados no app) fica nas tabelas do próprio
  SISCHAMADOS (`sccti`), que o painel edita pela permissão de gerência do
  módulo. O desenho dessas colunas é combinado com a sessão "Chat Intranet".


---

## 6. Acesso: níveis, papéis e login

### 6.1 Duas escadas diferentes

| | Níveis de acesso | Papéis |
|---|---|---|
| Para quê | O que o **militar vê no app** e o escopo dos dados (Mapa da Força, relatório de ciência) | O que alguém **faz no painel** (e alguns trabalhos no app, como publicar comunicado) |
| Quem define | Regras que leem o SIGRH + concessões manuais | Concessão no painel |
| Exemplo | Gestor de unidade vê o Mapa da Força da OPM dele | Atender feedback, Publicar comunicados |

### 6.2 Níveis de acesso (SOUPM_2_2 §6.5)

Tela **Níveis de acesso** (protótipo):

- **Escada** ordenável (a ordem é a hierarquia), com nome, nome curto (selo),
  cor, escopo e quantos militares tem cada nível. Criar, renomear, desativar
  e reordenar sem código e sem versão nova do app.
- **Quem faz parte:** regras que se somam, lidas do SIGRH em tempo real —
  função ou cargo, lotação, posto/graduação/quadro, perfil que já existe na
  intranet (SIGE `cmt-unidade`, SISCHAMADOS nível 4…), matrícula avulsa
  (sempre com data de fim e motivo) e exceção ("menos estas matrículas").
- **Prévia obrigatória antes de salvar:** "Esta mudança coloca 37 militares no
  nível X e tira 2", com as duas listas e o porquê de cada um.
- **Militares** do nível com o porquê de cada um.
- **Histórico** na auditoria.
- **Comparar com a regra antiga** (só na transição): quantos são gestores hoje
  pela regra `isSuperUser`, quantos serão pela nova, quem perde (oficiais sem
  função de comando) e quem ganha (subtenentes e sargentos que comandam).
  Ninguém perde ou ganha acesso sem essa conferência.

O cálculo do nível fica numa função só, usada pelo `app_config`, pelos
endpoints de gestão e pelo painel (prévia). Ela segue o molde do
`obterEscopoUsuarioEscala()` da intranet, mas própria do módulo `soupm`, e lê
a lotação de `intranet.vw_lotacao_sigrh`. O resultado vai para um cache por
matrícula de poucos minutos; mudar uma regra no painel limpa o cache.

### 6.3 Papéis e a ACL da intranet

O painel usa a ACL que a intranet já tem, sem inventar outra:

- `intranet.modulos`: linha do módulo `soupm` ("SOUPMRR", "Painel do app dos
  militares").
- `intranet.perfis` (módulo `soupm`): um perfil por **papel** — `soupm-admin`,
  `soupm-comunicados`, `soupm-notificacoes`, `soupm-feedback`,
  `soupm-certidoes`, `soupm-consulta`.
- `intranet.recursos`: `soupm.<area>.<acao>` (`soupm.funcoes.ver`,
  `soupm.funcoes.editar`, `soupm.comunicados.publicar`,
  `soupm.notificacoes.enviar_todos`, `soupm.militares.resetar_senha`,
  `soupm.niveis.editar`…), tipo `PAGINA` ou `ACAO`.
- `intranet.perfis_recursos`: a matriz da tela Papéis.
- `intranet.usuarios_perfis`: quem tem cada papel, com `data_inicio`,
  `data_fim` e `atribuido_por`.
- Toda rota do módulo chama `require_access('soupm.<area>.<acao>')`; o menu
  esconde o que a pessoa não pode, mas **quem decide é o servidor**.
- Cadastro por migração idempotente (`INSERT … WHERE NOT EXISTS`), no molde
  de `sischamados/database/migrations/003_…`, `010_acl_recursos.sql` e
  `011_acl_perfis.sql`.

Papéis da carga inicial:

| Papel | Pode | Quem, no início |
|---|---|---|
| Administrador do app | Tudo, com escopo de toda a PMRR (no app e no painel), com as travas do §7 (bloqueio por tentativas, sessão que expira, aviso de aparelho novo) e todo acesso a dado de militar auditado | **Quem é administrador da intranet acessa e gerencia o painel do SouPMRR automaticamente** (decisão do usuário, 22/10/2026; detalhes a definir por ele) |
| Publicar comunicados | Criar e publicar comunicados (com limite de público, se configurado) | **Ninguém**: desenhado para depois do login pela intranet |
| Enviar notificações | Um militar e grupos; "todos" fica com o Administrador | **Ninguém**: para depois |
| Atender feedback | Ler, classificar e responder feedback (sem abrir anexos); ler os logs das sessões dos feedbacks dele | **Ninguém**: para depois |
| Gerir certidões | Revogar e mudar textos (com aval da DRH) | **Ninguém**: para depois |
| Consulta | Ver indicadores e configurações, sem lista nominal (salvo escopo na concessão) | **Ninguém**: para depois |

**Até o login ir para a intranet, só existe o papel Administrador em uso**
(decisão do usuário, 21/10/2026). Os outros cinco ficam desenhados (matriz e
escopo prontos) e sem ninguém.

**Administrador da intranet é administrador do SouPMRR** (decisão do usuário,
22/10/2026). O login do painel é o da intranet, e **quem é administrador da
intranet entra e gerencia o painel do SouPMRR automaticamente**, sem
concessão à parte. A ligação exata (qual perfil da intranet conta como
administrador, se haverá exceções) o usuário vai detalhar depois; até lá, a
subsessão da intranet usa o perfil de administrador que a intranet já tem e
registra a escolha neste documento.

**Administrador: acesso a tudo, com três travas** (decisão do usuário,
21/10/2026: "um administrador tem acesso a tudo do app mesmo, independente do
comando. É um perfil com autorização para tudo."). O Administrador do app tem
**escopo de toda a PMRR, no app e no painel, com todas as permissões**. É o
único perfil assim. Para compensar:

1. **Poucas pessoas**, numa lista revisada no painel (Papéis › Administrador:
   quem tem, desde quando, última revisão; o painel lembra a revisão a cada 90
   dias).
2. **Proteção de conta** (§7): bloqueio por tentativas erradas, sessão do
   painel que expira sozinha (por inatividade e por prazo máximo) e aviso por
   e-mail quando a conta entra de um aparelho ou navegador novo. Sem 2FA por
   enquanto (decisão do usuário, 21/10/2026: "não vamos ter 2 etapas por
   enquanto"); fica como opção futura, desligada, para a 2.3.
3. **Todo acesso dele a dado de militar vai para a `intranet.auditoria`**:
   quem, quando, de quem (ficha, logs por matrícula, linha do tempo de sessão,
   lista nominal, feedback com autor, emissões). A Auditoria do painel tem o
   filtro "acessos a dados de militar".

**Escopo de dados dos outros papéis (revisão de 21/10/2026).** Permissão diz
**o que** a pessoa pode fazer; escopo diz **sobre quem**. Cada concessão de
papel do painel, **menos a de Administrador**, ganha um escopo, separado das
permissões:

| Escopo | Quem enxerga |
|---|---|
| Próprio nível de comando | Os militares do escopo do nível dela no app (a sua subunidade, unidade, grande comando) |
| Unidades escolhidas | Só as OPMs marcadas na concessão |
| PMRR | Todos (só para quem precisa, com motivo na concessão) |

O escopo vale para tudo que mostra militar com nome ou matrícula: busca de
Militares, Logs por matrícula, linha do tempo de sessão, lista nominal de
quem não deu ciência, relatório por unidade, feedback com o autor, emissões
de certidões e documentos, e a Auditoria (quem olhou o quê). Fora do escopo,
o painel mostra só números agregados. E cada papel lê só o que é dele:
**Atender feedback** não abre Militares nem Logs de quem não mandou feedback
para ele; **Gerir certidões** não abre logs nem feedback; **Consulta** vê
indicadores e configurações, sem lista nominal, salvo se a concessão disser
outro escopo.

Matriz da carga inicial (ver / editar / publicar ou enviar):

| Área | Administrador | Publicar comunicados | Enviar notificações | Atender feedback | Gerir certidões | Consulta |
|---|---|---|---|---|---|---|
| Painel (indicadores) | ver | ver | ver | ver | ver | ver |
| Funções, Tela inicial, Versões, Textos | editar | — | — | — | — | ver |
| Comunicados | publicar | publicar (no escopo) | — | — | — | ver (sem nomes) |
| Notificações | enviar (inclusive todos) | — | enviar (no escopo, sem "todos") | — | — | — |
| Feedback | editar | — | — | editar (os atribuídos a ele) | — | — |
| Logs e erros | ver (tudo, auditado) | — | — | ver (só sessões dos feedbacks dele) | — | — |
| Militares | editar (tudo, auditado) | — | — | — | — | — |
| Certidões e Documentos | editar | — | — | — | editar (emissões no escopo) | — |
| Níveis e Papéis | editar | — | — | — | — | — |
| Auditoria | ver | — | — | — | — | — |

**Impacto antes de dar acesso:** ao dar um papel ou ampliar um escopo, o
painel mostra o que muda: "passa a ver 1.284 militares (1º e 2º BPM) e a
publicar para eles".

**Nível e papel são independentes**, com uma exceção: o **Administrador** vê
todos os dados, no app e no painel (SOUPM_2_2 §6.2), sempre auditado. Os
outros papéis do painel não mudam o que a pessoa vê no app: lá vale o nível
de comando dela.

### 6.4 Login: hoje, 2.2 e 2.3

| Quando | App | Painel |
|---|---|---|
| Hoje (2.1.x) | SouPMRR + SIGRH: `login.php` confere o MD5 do SIGRH | — |
| 2.2 | Igual a hoje, com a senha guardada no Keychain/Keystore (SOUPM_2_2 §6.6, fase 0) | **Login da intranet** (`auth/login.php`), sem 2FA por enquanto (opção futura para a 2.3), com as proteções do §7, para todo perfil `soupm-*` |
| **2.3** | **Login da intranet**: `POST /api/v1/auth/login` devolve JWT e perfis; a API do app passa a aceitar o token; o MD5 deixa de viajar | Igual |

Com isso, **a mesma senha** vale para SouPMRR e intranet. Pré-requisitos da
2.3, que são da intranet (sessão "Chat Intranet") e foram achados no
levantamento de 21/10/2026:

1. O login da API não aplica 2FA (`AuthController` faz `NULL AS tfa_enabled`).
   Hoje isso não pesa: não haverá 2FA por enquanto (decisão de 21/10/2026).
   Se o 2FA for ligado na 2.3, a API precisa passar a aplicá-lo.
2. O JWT tem validade de 12 h e a renovação reassina o mesmo token, sem fim.
   Precisa de refresh token separado, com revogação (logout e "desconectar
   todos os aparelhos" têm de valer).
3. A chave do JWT tem valor padrão fixo no código: precisa vir só do ambiente.
4. `getUserPerfis` devolve perfis inativos e vencidos: filtrar `ativo` e
   `data_fim`.
5. Migração de senha: no primeiro login da 2.3, o MD5 do SIGRH é conferido e a
   senha vira bcrypt em `intranet.usuarios.senha_local` (a intranet já faz
   isso no login web).
6. Reset de senha, primeiro acesso e "esqueci a senha" do app passam a gravar
   na senha da intranet.

---

## 7. Segurança do painel e pré-requisitos

**Do próprio painel (obrigatório antes de ir ao ar):**

1. Login da intranet, sem senha própria do painel. **Sem 2FA por enquanto**
   (decisão do usuário, 21/10/2026); o 2FA fica como opção futura, desligada,
   para a 2.3. No lugar, sobretudo porque o Administrador tem acesso a tudo:
   - **bloqueio por tentativas erradas** (como o `login.php` do app: por
     matrícula e por IP, com a hora em que libera);
   - **sessão do painel que expira sozinha**, por inatividade (sugestão: 30
     min) e por prazo máximo (sugestão: 8 h), mesmo com uso;
   - **aviso por e-mail** quando a conta entra de um aparelho ou navegador novo
     ("Sua conta entrou no painel do SouPMRR de um navegador novo, às …");
   - **todo acesso a dado de militar** registrado na `intranet.auditoria`;
   - **lista curta de administradores**, revisada no painel a cada 90 dias.
2. Sessão da intranet (`session_regenerate_id`), com os limites do item 1.
3. **CSRF** em todo POST, com a `CsrfProtection` do SISCHAMADOS copiada para o
   módulo (a intranet não tem helper central).
4. `require_access` em toda rota e toda ação, inclusive nas respostas parciais
   e nos endpoints JSON do painel.
5. Auditoria de toda alteração e todo envio em `intranet.auditoria`, com antes
   e depois.
6. **Usuário de banco próprio do painel**, com `INSERT/UPDATE/DELETE` só nas
   `soupm_*` que ele edita e `SELECT` no que lê do SIGRH. O usuário da API do
   app continua com `SELECT` na configuração e `INSERT` nos logs.
7. Upload conferido pelo conteúdo, fora da pasta pública quando for anexo.
8. Ações de perigo (resetar senha, revogar, enviar para todos, mudar nível de
   muita gente) com confirmação que diz o que acontece e se dá para desfazer.
9. Consulta preparada sempre; nada de SQL montado com texto de formulário.

**Da API do app (risco atual, independe do painel; com a sessão de segurança
"Corrigir exposição de dados no Mapa da Força e ficha"):**

- Endpoints que respondem sem conferir quem pede, consultas montadas com
  texto, endpoints legados que devolvem hash (APRENDIZADOS §30) e arquivos que
  não deviam estar na pasta pública. **A lista com os nomes fica fora do
  repositório** (que é público), na cópia privada da API, com a sessão de
  segurança.
- `notificarEscala` sem autenticação e Firestore sem regras no repositório.

O painel cria uma porta com poder de escrita sobre os mesmos dados. Por isso a
fase P0 do painel só vai ao ar depois das correções de autenticação da API
que a sessão de segurança está fazendo.

---

## 8. Modelo de dados (rascunho)

As tabelas do app estão no SOUPM_2_2 §12.2 e **não se repetem aqui**
(`soupm_menu_item`, `soupm_evento`, `soupm_erro`, `soupm_dispositivo`,
`soupm_notificacao`, `soupm_notificacao_leitura`, `soupm_inicio_preferencia`,
`soupm_comunicado`, `soupm_comunicado_leitura`, `soupm_pendencia_tipo`,
`soupm_pendencia_dispensa`, `soupm_feedback`) nem as de níveis (SOUPM_2_2
§6.5: `soupm_nivel`, `soupm_nivel_regra`, `soupm_papel`, `soupm_papel_regra`).
Abaixo, só o que o painel acrescenta e o que ele pede para mudar.

**Regras para todo DDL novo** (`postgresql-code-review`). Versões medidas em
22/10/2026: **produção 13.23** (`pmrronline_erp_prod`, onde a API grava) e
**desenvolvimento 9.6.6** (`gitpmrrl_pmrr_erp`, onde a intranet nova e o painel
rodam). Escreve-se para a **menor** das duas (9.6), porque toda migração passa
primeiro por dev; a regra é revista quando o dev subir de versão:

- `TIMESTAMPTZ` em vez de `TIMESTAMP` (o servidor e o app estão em fusos
  diferentes do UTC; APRENDIZADOS §17 já mostrou o custo disso).
- Valores fechados com `CHECK (col IN (…))`, não `ENUM` (ENUM no 9.6 não
  aceita remover valor).
- `JSONB` de público com índice GIN e consulta por `@>`.
- Sem `GENERATED`, sem partição declarativa, `EXECUTE PROCEDURE` nos gatilhos
  (existem no 13 de produção, mas não no 9.6 de dev).
- Script idempotente em `sql/` da API (`CREATE TABLE IF NOT EXISTS`) e coluna
  nova conferida em `pg_attribute` antes de ser lida, como no `titulo_curto`.

```sql
-- Categorias de comunicado (cor e ícone do cartão)
CREATE TABLE IF NOT EXISTS public.soupm_comunicado_categoria (
    chave        VARCHAR(30) PRIMARY KEY,           -- 'operacao'
    nome         VARCHAR(40) NOT NULL,
    cor          CHAR(7) NOT NULL CHECK (cor ~ '^#[0-9A-Fa-f]{6}$'),
    icone        VARCHAR(40) NOT NULL,              -- chave do mapa de ícones do app
    ordem        INT NOT NULL DEFAULT 0,
    ativo        BOOLEAN NOT NULL DEFAULT TRUE
);
-- soupm_comunicado (SOUPM_2_2 §12.2) ganha:
--   categoria  REFERENCES soupm_comunicado_categoria(chave)
--   pilula_icone VARCHAR(40), pilula_texto VARCHAR(16)
--   versao INT NOT NULL DEFAULT 1, status VARCHAR(12) CHECK (status IN ('rascunho','agendado','publicado','encerrado'))
--   CHECK (char_length(titulo) <= 30), CHECK (char_length(resumo) <= 70)
-- soupm_comunicado_leitura ganha: versao_ciente INT

-- Feedback (módulo do painel; desenho final, aceito pela sessão do app em 21/10/2026)
CREATE TABLE IF NOT EXISTS public.soupm_feedback (
    id            BIGSERIAL PRIMARY KEY,
    protocolo     VARCHAR(20) UNIQUE NOT NULL,      -- 'FB-2026-00042'
    matricula     VARCHAR(20) NOT NULL,
    tipo          VARCHAR(12) NOT NULL CHECK (tipo IN ('melhoria','funcao_nova','elogio')),
    texto         TEXT NOT NULL CHECK (char_length(texto) >= 10),
    plataforma    VARCHAR(8) CHECK (plataforma IN ('android','ios')),
    app_versao    VARCHAR(20),
    contexto      JSONB,                            -- aparelho, tela, últimos códigos (sem dado sensível)
    erro_id       BIGINT,                           -- soupm_erro citado pelo militar (o caminho de erro agora é chamado técnico)
    situacao      VARCHAR(12) NOT NULL DEFAULT 'recebido'
                  CHECK (situacao IN ('recebido','em_analise','planejado','concluido','arquivado')),
    aguarda_militar BOOLEAN NOT NULL DEFAULT FALSE, -- a equipe perguntou algo (pendência soupm.feedback_resposta)
    prioridade    VARCHAR(8) CHECK (prioridade IN ('baixa','media','alta')),
    chave_funcao  VARCHAR(80),                      -- soupm_menu_item
    rotulos       TEXT[],
    duplicado_de  BIGINT REFERENCES public.soupm_feedback(id),
    responsavel   VARCHAR(20),
    criado_em     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    atualizado_em TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX ON public.soupm_feedback (situacao, criado_em DESC);
CREATE INDEX ON public.soupm_feedback (matricula, criado_em DESC);
CREATE TABLE IF NOT EXISTS public.soupm_feedback_mensagem (
    id           BIGSERIAL PRIMARY KEY,
    feedback_id  BIGINT NOT NULL REFERENCES public.soupm_feedback(id),
    autor        VARCHAR(8) NOT NULL CHECK (autor IN ('militar','equipe')),
    matricula    VARCHAR(20) NOT NULL,
    texto        TEXT NOT NULL,
    criado_em    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE TABLE IF NOT EXISTS public.soupm_feedback_anexo (
    id           BIGSERIAL PRIMARY KEY,
    feedback_id  BIGINT NOT NULL REFERENCES public.soupm_feedback(id),
    mensagem_id  BIGINT REFERENCES public.soupm_feedback_mensagem(id),  -- nulo = anexo do envio
    caminho      TEXT NOT NULL,                     -- fora da pasta pública, nome aleatório
    tipo_mime    VARCHAR(60) NOT NULL,              -- conferido pelo conteúdo
    bytes        INT NOT NULL CHECK (bytes > 0),
    sha256       CHAR(64) NOT NULL,
    criado_em    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Envios (painel grava; cron da API do app envia)
CREATE TABLE IF NOT EXISTS public.soupm_notificacao_envio (
    id            BIGSERIAL PRIMARY KEY,
    tipo          VARCHAR(10) NOT NULL CHECK (tipo IN ('militar','grupo','todos','lembrete','comunicado')),
    titulo        VARCHAR(120) NOT NULL,
    mensagem      TEXT NOT NULL,
    chave_destino VARCHAR(80),                      -- função que abre ao tocar
    filtro        JSONB,                            -- os filtros do §4.3 (reproduzível)
    agendado_para TIMESTAMPTZ,
    status        VARCHAR(12) NOT NULL DEFAULT 'agendado' CHECK (status IN ('agendado','enviando','concluido','falhou','cancelado')),
    total_alvos   INT, com_app INT, aparelhos INT, aceitos INT, falhas INT, sem_aparelho INT, abertos INT,
    criado_por    VARCHAR(20) NOT NULL,
    criado_em     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    concluido_em  TIMESTAMPTZ
);
CREATE INDEX ON public.soupm_notificacao_envio (status, agendado_para);
CREATE TABLE IF NOT EXISTS public.soupm_notificacao_destino (   -- uma linha por aparelho (ou por militar sem aparelho)
    id          BIGSERIAL PRIMARY KEY,
    envio_id    BIGINT NOT NULL REFERENCES public.soupm_notificacao_envio(id),
    matricula   VARCHAR(20) NOT NULL,
    aparelho_id UUID,                               -- nulo quando o militar não tem aparelho
    resultado   VARCHAR(12) NOT NULL CHECK (resultado IN ('aceito','falhou','sem_aparelho')),
    erro_fcm    VARCHAR(40),                        -- UNREGISTERED, QUOTA_EXCEEDED...
    aberto_em   TIMESTAMPTZ                         -- do evento push.abrir
);
CREATE UNIQUE INDEX ON public.soupm_notificacao_destino (envio_id, matricula, aparelho_id);
CREATE TABLE IF NOT EXISTS public.soupm_lembrete (
    chave         VARCHAR(60) PRIMARY KEY,          -- 'ferias_inicio'
    ativo         BOOLEAN NOT NULL DEFAULT FALSE,
    dias_antes    INT[],                            -- {7,1}
    titulo        VARCHAR(120) NOT NULL,
    mensagem      TEXT NOT NULL,
    chave_destino VARCHAR(80),
    atualizado_por VARCHAR(20), atualizado_em TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE TABLE IF NOT EXISTS public.soupm_notificacao_modelo (id SERIAL PRIMARY KEY, nome VARCHAR(80) NOT NULL,
    titulo VARCHAR(120) NOT NULL, mensagem TEXT NOT NULL, chave_destino VARCHAR(80));
CREATE TABLE IF NOT EXISTS public.soupm_publico_salvo (id SERIAL PRIMARY KEY, nome VARCHAR(80) NOT NULL,
    filtro JSONB NOT NULL, criado_por VARCHAR(20) NOT NULL, criado_em TIMESTAMPTZ NOT NULL DEFAULT NOW());

-- Regra de versão por plataforma (lida pelo app_config, parte pública).
-- O histórico de versões publicadas é a soupm_versao_app do SOUPM_2_2 §10.1.
CREATE TABLE IF NOT EXISTS public.soupm_versao_regra (
    plataforma    VARCHAR(8) PRIMARY KEY CHECK (plataforma IN ('android','ios')),
    minima        VARCHAR(12) NOT NULL,
    recomendada   VARCHAR(12) NOT NULL,
    titulo        VARCHAR(80),
    texto         TEXT,
    novidades     TEXT,                             -- "o que há de novo" só desta loja
    atualizado_por VARCHAR(20), atualizado_em TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Conteúdo da Início (sai do Firestore)
-- Cards criados no painel (home.livre.<chave>)
CREATE TABLE IF NOT EXISTS public.soupm_card (
    chave          VARCHAR(60) PRIMARY KEY,          -- 'outubro_rosa' → bloco 'home.livre.outubro_rosa'
    modelo         VARCHAR(12) NOT NULL CHECK (modelo IN ('campanha','atalho','numero','lista')),
    dados          JSONB NOT NULL,                   -- campos do modelo: selo, titulo, texto, cor, icone, fonte, linhas[]
    arte           VARCHAR(30) REFERENCES public.soupm_arte(chave),  -- §5.3b (substitui marca)
    arte_imagem    INT REFERENCES public.soupm_midia(id),             -- imagem aprovada; vence a arte
    arte_estilo    VARCHAR(8) NOT NULL DEFAULT 'cheio' CHECK (arte_estilo IN ('cheio','discreto')),
    acao           JSONB,                            -- {tipo: funcao|comunicado|link|chamado, destino}
    publico        JSONB,                            -- filtros do §4.3; nulo = todos
    inicio         TIMESTAMPTZ,
    fim            TIMESTAMPTZ,
    ordem          INT NOT NULL DEFAULT 0,
    escondivel     BOOLEAN NOT NULL DEFAULT TRUE,    -- o militar pode esconder
    status         VARCHAR(10) NOT NULL DEFAULT 'rascunho' CHECK (status IN ('rascunho','agendado','publicado','encerrado')),
    versao_reg     INT NOT NULL DEFAULT 1,           -- controle de concorrência (§1.3)
    versao         INT NOT NULL DEFAULT 1,
    criado_por     VARCHAR(20) NOT NULL,
    criado_em      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    atualizado_por VARCHAR(20),
    atualizado_em  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CHECK (acao IS NULL OR acao->>'tipo' IN ('funcao','comunicado','link','chamado'))
);
CREATE INDEX ON public.soupm_card USING gin (publico);
-- Artes dos cards (§5.3b): o novo padrão visual do app; blocos, áreas e cards apontam para cá
CREATE TABLE IF NOT EXISTS public.soupm_arte (
    chave         VARCHAR(30) PRIMARY KEY CHECK (chave ~ '^[a-z_]+$'),
    nome          VARCHAR(60) NOT NULL,
    tipo          VARCHAR(10) NOT NULL DEFAULT 'icones' CHECK (tipo IN ('icones','especial')),  -- especial = desenhada pelo app
    cor_base      CHAR(7) CHECK (cor_base ~ '^#[0-9A-Fa-f]{6}$'),
    cor_meio      CHAR(7) CHECK (cor_meio ~ '^#[0-9A-Fa-f]{6}$'),
    cor_destaque  CHAR(7) CHECK (cor_destaque ~ '^#[0-9A-Fa-f]{6}$'),
    icones        TEXT[] CHECK (array_length(icones, 1) = 3),  -- chaves do catálogo de ícones
    config        JSONB,                            -- só das especiais: estrelas {"estrelas": "posto"} ou um número
    CHECK (tipo = 'especial' OR (cor_base IS NOT NULL AND cor_meio IS NOT NULL AND cor_destaque IS NOT NULL AND icones IS NOT NULL)),
    situacao      VARCHAR(10) NOT NULL DEFAULT 'ativa' CHECK (situacao IN ('ativa','sugerida','arquivada')),
    versao_reg    INT NOT NULL DEFAULT 1,           -- controle de concorrência (§1.3)
    atualizado_por VARCHAR(20),
    atualizado_em TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
-- As cores têm de estar na paleta fechada (soupm_config 'paleta'); o painel confere antes de gravar.
-- Blocos fixos da Início e áreas de Serviços: linhas do soupm_menu_item, que ganha
--   arte VARCHAR(30) REFERENCES soupm_arte(chave), arte_imagem INT REFERENCES soupm_midia(id),
--   arte_estilo VARCHAR(8) NOT NULL DEFAULT 'cheio' CHECK (arte_estilo IN ('cheio','discreto'))
--   (superfícies como perfil.capa, perfil.grupos e perfil.nivel também são linhas do soupm_menu_item)
--   (a imagem aprovada vence a arte) e escondivel BOOLEAN NOT NULL DEFAULT TRUE
--   (desligar o bloco = visivel_menu false; o publico já existe). "Mais usados" fixos: soupm_config 'servicos'.
-- soupm_menu_item ganha visivel_menu BOOLEAN NOT NULL DEFAULT TRUE, separado do estado,
--   que passa a ter CHECK (estado IN ('ativo','bloqueado')) (§3.0).

-- Catálogo de eventos do log (regra do CLAUDE.md)
CREATE TABLE IF NOT EXISTS public.soupm_evento_catalogo (
    evento         VARCHAR(60) PRIMARY KEY CHECK (evento ~ '^[a-z_]+\.[a-z_]+$'),  -- 'contracheque.compartilhar'
    modulo         VARCHAR(30) NOT NULL,
    descricao      VARCHAR(200) NOT NULL,
    dados          JSONB,                            -- campos extras esperados e o tipo de cada um
    desde_versao   VARCHAR(12),
    ativo          BOOLEAN NOT NULL DEFAULT TRUE
);
-- soupm_evento e soupm_erro (SOUPM_2_2 §12.2) ganham: app_build VARCHAR(12), rede VARCHAR(10),
--   tema VARCHAR(6), fonte_escala NUMERIC(3,2), resultado VARCHAR(10) CHECK (resultado IN ('ok','cancelado','falhou')),
--   codigo VARCHAR(40) (no evento que falhou). Índices: (matricula, ocorrido_em), (sessao_id), (evento, ocorrido_em).
-- Alertas (avaliados por um cron do painel a cada minuto)
CREATE TABLE IF NOT EXISTS public.soupm_alerta_regra (
    id            SERIAL PRIMARY KEY,
    nome          VARCHAR(80) NOT NULL,
    metrica       VARCHAR(20) NOT NULL CHECK (metrica IN ('erro_codigo','erro_funcao','servico','aberturas','ciencia','feedback_palavra','comando_pendente','fechamentos')),
    parametros    JSONB NOT NULL,                   -- {codigo, limite, janela_min, comparacao: 'media_hora'|'absoluto'}
    avisar_papel  VARCHAR(40) NOT NULL,             -- perfil soupm-*
    email         BOOLEAN NOT NULL DEFAULT FALSE,
    acao_sugerida VARCHAR(30),                      -- manutencao | subir_recomendada | lembrar_ciencia
    ativo         BOOLEAN NOT NULL DEFAULT TRUE,
    criado_por    VARCHAR(20) NOT NULL,
    criado_em     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE TABLE IF NOT EXISTS public.soupm_alerta_disparo (
    id            BIGSERIAL PRIMARY KEY,
    regra_id      INT NOT NULL REFERENCES public.soupm_alerta_regra(id),
    aberto_em     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    resolvido_em  TIMESTAMPTZ,
    resumo        VARCHAR(200) NOT NULL,            -- 'CC-LENTO: 21 em 10 min'
    visto_por     VARCHAR(20),
    visto_em      TIMESTAMPTZ,
    acao_tomada   VARCHAR(30)
);
CREATE INDEX ON public.soupm_alerta_disparo (aberto_em) WHERE resolvido_em IS NULL;
-- Relatório semanal
CREATE TABLE IF NOT EXISTS public.soupm_relatorio (
    id             SERIAL PRIMARY KEY,
    destinatarios  JSONB NOT NULL,                  -- {papeis:[], niveis:[], matriculas:[]}
    dia_semana     SMALLINT NOT NULL CHECK (dia_semana BETWEEN 0 AND 6),
    hora           TIME NOT NULL,
    secoes         TEXT[] NOT NULL,
    ativo          BOOLEAN NOT NULL DEFAULT TRUE,
    atualizado_por VARCHAR(20)
);
-- Manutenção automática: soupm_menu_item ganha volta_auto BOOLEAN NOT NULL DEFAULT FALSE
--   e servico_dependente VARCHAR(30) (o serviço do soupm_saude de que a função depende).
-- Feedback: soupm_feedback ganha grupo_id BIGINT REFERENCES soupm_feedback(id) (assuntos em alta).
-- Restaurar: usa o "antes" que já fica em intranet.auditoria; nenhuma tabela nova.

-- Documentos (contracheque, declarações e os que vierem; certidões continuam nas tabelas do Anexo A)
CREATE TABLE IF NOT EXISTS public.soupm_documento_padrao (
    documento      VARCHAR(30) NOT NULL CHECK (documento ~ '^[a-z_]+$'),   -- 'contracheque', 'declaracao_bens'
    versao         INT NOT NULL,
    status         VARCHAR(12) NOT NULL DEFAULT 'rascunho' CHECK (status IN ('rascunho','publicada','substituida')),
    padrao         JSONB NOT NULL,                  -- titulo, marca, mensagem, rodape, arquivo, blocos[{chave,ligado,ordem}], rubricas{ocultar_zeradas, agrupar, nomes{}}
    criado_por     VARCHAR(20) NOT NULL,
    criado_em      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    publicado_por  VARCHAR(20),
    publicado_em   TIMESTAMPTZ,
    PRIMARY KEY (documento, versao)
);
CREATE UNIQUE INDEX ON public.soupm_documento_padrao (documento) WHERE status = 'publicada';  -- uma publicada por documento
-- Liga/desliga, limites e textos de serviço ficam em soupm_config (chave = documento), como nas certidões.
-- Cada PDF gerado registra documento, versão do padrão, matrícula, referência (mês), sha256 e quando,
--   em soupm_documento_emissao (mesmo desenho de soupm_certidao_emissao, com código para o QR público; decisão de 21/10/2026).
--   As conferências vão para soupm_documento_verificacao_log (mesmo desenho de soupm_certidao_verificacao_log).

-- Declarações por campanha (§5.10)
CREATE TABLE IF NOT EXISTS public.soupm_declaracao_campanha (
    id            SERIAL PRIMARY KEY,
    tipo          VARCHAR(20) NOT NULL CHECK (tipo IN ('bens','irpf','parentesco','acumulo')),
    ano           SMALLINT NOT NULL,
    abre_em       TIMESTAMPTZ NOT NULL,
    prazo         TIMESTAMPTZ NOT NULL,
    situacao      VARCHAR(10) NOT NULL DEFAULT 'agendada' CHECK (situacao IN ('agendada','aberta','encerrada')),
    texto         TEXT,                             -- orientação ao militar
    criado_por    VARCHAR(20) NOT NULL,
    criado_em     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (tipo, ano),
    CHECK (prazo > abre_em)
);
-- Fontes de dados (cards Número e pendências usam a mesma lista fechada)
CREATE TABLE IF NOT EXISTS public.soupm_fonte_dados (
    chave        VARCHAR(60) PRIMARY KEY,           -- 'escalas_do_mes', 'declaracoes_pendentes'
    nome         VARCHAR(80) NOT NULL,
    servico      VARCHAR(30) NOT NULL REFERENCES public.soupm_servico(chave),
    devolve      VARCHAR(10) NOT NULL CHECK (devolve IN ('numero','lista','sim_nao')),
    status       VARCHAR(12) NOT NULL DEFAULT 'a_homologar' CHECK (status IN ('confirmada','a_homologar','futura')),
    descricao    VARCHAR(200)
);
-- Catálogo de mídia dos cards (ícones e imagens aprovados; paleta fechada fica em soupm_config, chave 'paleta')
CREATE TABLE IF NOT EXISTS public.soupm_midia (
    id           SERIAL PRIMARY KEY,
    tipo         VARCHAR(8) NOT NULL CHECK (tipo IN ('icone','imagem')),
    chave        VARCHAR(60) NOT NULL UNIQUE,
    arquivo      TEXT,                              -- imagem na pasta só de imagens
    descricao    VARCHAR(120) NOT NULL,             -- texto alternativo
    aprovado_por VARCHAR(20), aprovado_em TIMESTAMPTZ
);

-- Catálogo de serviços: o mapa de conexões, a sonda, a disponibilidade e os alertas leem daqui (regra do §1.4)
CREATE TABLE IF NOT EXISTS public.soupm_servico (
    chave        VARCHAR(30) PRIMARY KEY CHECK (chave ~ '^[a-z_]+$'),   -- 'api', 'banco', 'sischamados'
    nome         VARCHAR(60) NOT NULL,
    icone        VARCHAR(40) NOT NULL,              -- chave do mapa de ícones do painel
    faixa        VARCHAR(10) NOT NULL CHECK (faixa IN ('aparelho','app','servico')),
    situacao     VARCHAR(12) NOT NULL DEFAULT 'planejado' CHECK (situacao IN ('planejado','homologado','monitorado')),
    tipo         VARCHAR(10) NOT NULL DEFAULT 'api' CHECK (tipo IN ('api','banco','push','externo')),
    conexao      VARCHAR(40),                       -- NOME da conexão em /private (nunca endereço, usuário ou senha)
    conexao_anterior VARCHAR(40),                   -- para voltar depois de uma troca (§5.17)
    depende_de   TEXT[],                            -- chaves de quem ele chama (desenha as linhas)
    sonda        JSONB,                             -- {tipo: 'http'|'sql'|'fcm', alvo (só em /private), lento_ms, tempo_limite_ms}
    funcoes      TEXT[],                            -- chaves do soupm_menu_item que dependem dele (incidente e manutenção automática)
    ordem        INT NOT NULL DEFAULT 0,
    ativo        BOOLEAN NOT NULL DEFAULT TRUE
);
-- Saúde dos serviços (sonda da API do app a cada minuto; alimenta o mapa de conexões do Painel)
CREATE TABLE IF NOT EXISTS public.soupm_saude (
    servico      VARCHAR(30) NOT NULL REFERENCES public.soupm_servico(chave),
    medido_em    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    status       VARCHAR(6) NOT NULL CHECK (status IN ('ok','lento','fora')),
    latencia_ms  INT,
    detalhe      VARCHAR(200),                     -- sem dado sensível nem endereço interno
    PRIMARY KEY (servico, medido_em)
);  -- guardar 30 dias
CREATE TABLE IF NOT EXISTS public.soupm_log_filtro (
    id SERIAL PRIMARY KEY, dono VARCHAR(20) NOT NULL, nome VARCHAR(80) NOT NULL,
    filtro JSONB NOT NULL, criado_em TIMESTAMPTZ NOT NULL DEFAULT NOW());

-- Comando: o que veio do SIGRH (pendente) e o que o app mostra (aprovado)
CREATE TABLE IF NOT EXISTS public.soupm_comando (
    cargo          VARCHAR(20) PRIMARY KEY CHECK (cargo IN ('cmt_geral','subcmt_geral')),
    titulo_cargo   VARCHAR(60) NOT NULL,             -- 'Comandante-Geral'
    ordem          SMALLINT NOT NULL DEFAULT 0,
    ativo          BOOLEAN NOT NULL DEFAULT TRUE,
    -- versão aprovada (a única que o app_config lê)
    aprovado       JSONB,                            -- {matricula, nome, posto, quadro, desde, inclusao, lotacao, cursos[], foto}
    aprovado_em    TIMESTAMPTZ,
    aprovado_por   VARCHAR(20),
    -- o que o SIGRH diz agora, quando difere do aprovado
    sigrh_atual    JSONB,
    sigrh_lido_em  TIMESTAMPTZ,
    pendente       BOOLEAN NOT NULL DEFAULT FALSE,   -- sigrh_atual ≠ base do aprovado
    pendente_desde TIMESTAMPTZ,
    recusado_hash  CHAR(64),                         -- sha256 do sigrh_atual recusado (não reabre o mesmo)
    -- o que só o painel tem
    foto_oficial   TEXT,                             -- substitui a foto do SIGRH, se enviada
    mensagem       VARCHAR(280),                     -- mensagem à tropa (vazia = a linha some)
    campos_ocultos TEXT[]                            -- {'cursos','inclusao'}
);
-- A comparação usa o sigrh_atual contra a cópia do SIGRH guardada no momento da aprovação
-- (aprovado->'base_sigrh'), para não acusar diferença por causa de ajuste feito no painel.
CREATE TABLE IF NOT EXISTS public.soupm_dica (id SERIAL PRIMARY KEY, texto VARCHAR(120) NOT NULL,
    icone VARCHAR(40) NOT NULL, tipo VARCHAR(12) NOT NULL DEFAULT 'dica', publico JSONB,
    inicio TIMESTAMPTZ, fim TIMESTAMPTZ, ordem INT NOT NULL DEFAULT 0, ativo BOOLEAN NOT NULL DEFAULT TRUE);
-- "Preciso de ajuda" (§5.12): assuntos e perguntas do filtro guiado
CREATE TABLE IF NOT EXISTS public.soupm_ajuda_assunto (chave VARCHAR(40) PRIMARY KEY, nome VARCHAR(60) NOT NULL,
    icone VARCHAR(40) NOT NULL, ordem INT NOT NULL DEFAULT 0, ativo BOOLEAN NOT NULL DEFAULT TRUE);
CREATE TABLE IF NOT EXISTS public.soupm_faq (id SERIAL PRIMARY KEY,
    assunto VARCHAR(40) NOT NULL REFERENCES public.soupm_ajuda_assunto(chave),
    pergunta VARCHAR(160) NOT NULL, resposta TEXT NOT NULL,
    chave_destino VARCHAR(80),                          -- função da árvore que vira o botão da resposta
    chamado_tipo INT, chamado_categoria INT,            -- catálogo do SISCHAMADOS para o chamado, se não resolver
    ordem INT NOT NULL DEFAULT 0, ativo BOOLEAN NOT NULL DEFAULT TRUE);
-- Indicadores por pergunta: eventos ajuda.ver, ajuda.resolveu e ajuda.abriu_chamado (dados: id da pergunta).
-- Atalhos padrão por nível
CREATE TABLE IF NOT EXISTS public.soupm_atalho_padrao (nivel_id INT REFERENCES public.soupm_nivel(id),
    posicao SMALLINT CHECK (posicao BETWEEN 1 AND 12), chave VARCHAR(80) NOT NULL, PRIMARY KEY (nivel_id, posicao));
```

**Mudanças pedidas às tabelas do SOUPM_2_2 §12.2** (avisadas à sessão do
app):

| Tabela | Mudança | Por quê |
|---|---|---|
| `soupm_pendencia_tipo` | `ativo DEFAULT FALSE` (o rascunho do §12.2 ainda diz `TRUE`); colunas `fonte_status` (`confirmada`, `a_homologar`, `futura`; carga inicial sem nenhuma `confirmada`), `homologado_por`, `homologado_em`, `prazo_tipo` (`fixo`, `fonte`), `prazo` | Todos começam desligados; o painel só deixa ligar fonte confirmada |
| `soupm_feedback` | Desenho final acima: sem `chamado_id`, com classificação e `CHECK`; anexos em `soupm_feedback_anexo` | Feedback não vira chamado; classificar e ligar ao log no painel |
| `soupm_versao_app` | Continua como histórico; mínima e recomendada ficam em `soupm_versao_regra` | Separar "o que foi publicado" de "o que o app exige" |
| `soupm_comunicado` | Categoria por chave, pílula, versão, status, limites de tamanho | Prévia e relatório por versão |
| Todas as novas | `TIMESTAMPTZ` | Fuso |
| `soupm_admin_log` (PAINEL antigo) | **Não criar**: usar `intranet.auditoria` | A intranet já tem, com IP e JSONB |

`public.soupm_config` (Anexo A) continua para o que é um JSON por módulo:
`certidoes`, `suporte`, `textos`, `rede`, `log` e `erros` (a tabela de códigos de
erro com o significado de cada um, lida pela API e pelo painel).

---

## 9. Contrato com o app: `sigrh/app_config.php`

> **Atualizado em 20/10/2026 para o SouPM 2.2:** `grid` e `abas` viraram
> `menu` (árvore), a versão mínima é por plataforma e entram `busca`,
> `perfis` e `home` com pendências e atalhos.

POST com a credencial da sessão (MD5 até a fase 5 do SOUPM_2_2; depois, o
token da intranet); sem ela, só a parte pública (`versao`, `login`, `textos`
públicos). Resposta (exemplo):

```json
{
  "code": 1,
  "versao_config": 42,
  "versao": {
    "android": { "minima": "2.2.0", "recomendada": "2.2.1",
                 "titulo": "Atualize o SouPM", "texto": "Esta versão corrige o envio de anexos." },
    "ios":     { "minima": "2.2.0", "recomendada": "2.2.0" }
  },
  "nivel": { "valor": 3, "nome": "Gestor de unidade", "escopo": "1º BPM",
             "origem": "funcao_sigrh" },
  "papeis": [],
  "lotacao": { "subunidade": "2ª Companhia", "unidade": "1º Batalhão de Polícia Militar",
               "comando": "Comando de Policiamento da Capital" },
  "abas": [
    { "chave": "aba.inicio",   "rotulo": "Início" },
    { "chave": "aba.servicos", "rotulo": "Serviços" },
    { "chave": "aba.avisos",   "rotulo": "Avisos" },
    { "chave": "aba.perfil",   "rotulo": "Perfil" }
  ],
  "menu": [
    { "chave": "rh", "tipo": "area", "rotulo": "Minha vida funcional",
      "descricao": "Contracheque, férias, certidões e seus dados", "icone": "pessoa",
      "filhos": [
        { "chave": "rh.contracheques", "tipo": "funcao", "rotulo": "Contracheques",
          "descricao": "Mês a mês, PDF e análise salarial", "icone": "contracheque",
          "rota": "/rh/contracheques", "estado": "ativo",
          "sinonimos": ["salário", "pagamento", "holerite", "folha"] },
        { "chave": "rh.ferias", "tipo": "funcao", "rotulo": "Plano de férias",
          "icone": "ferias", "rota": "/rh/ferias", "estado": "bloqueado", "selo": "Manutenção",
          "mensagem": { "motivo": "manutencao", "titulo": "Plano de férias em manutenção",
                        "texto": "Estamos atualizando o plano de 2027.",
                        "previsao": "2026-10-21T18:00:00-04:00",
                        "acao": "avisar_quando_voltar", "codigo": "MD-RH.FERIAS-MANUT" } }
      ] },
    { "chave": "operacional", "tipo": "area", "rotulo": "Serviço operacional", "icone": "escala",
      "filhos": [
        { "chave": "op.escalas", "tipo": "funcao", "rotulo": "Minhas escalas", "estado": "bloqueado",
          "selo": "Em breve", "mensagem": { "motivo": "em_breve", "titulo": "Em desenvolvimento",
          "texto": "Este recurso estará disponível em breve.", "codigo": "MD-OP.ESCALAS-EM_BREVE" } }
      ] }
  ],
  "home": [
    { "chave": "home.comandantes", "fixo": true,
      "dados": [ { "foto": "https://...", "posto": "CEL QOC PM", "nome": "...", "cargo": "Comandante-Geral",
                   "desde": "2025-01-02", "mensagem": "..." } ] },
    { "chave": "home.anuncio", "fixo": true,
      "dados": { "intervalo_s": 6.5, "nao_lidos": 3,
        "abertura": 1,
        "itens": [ { "id": 1, "titulo": "Operação Eleições 2026: 2º turno", "resumo": "...", "categoria": "operacao",
                     "origem": "Comando-Geral", "data": "2026-10-20", "imagem": null, "icone": "eleicao",
                     "urgente": true, "ciencia": true, "ciente": false, "lido": false } ] } },
    { "chave": "home.dicas", "dados": [ { "texto": "...", "icone": "lampada" } ] },
    { "chave": "home.pendencias", "fixo": true, "dados": [] },
    { "chave": "home.atalhos", "dados": ["rh.contracheques", "rh.certidoes", "rh.ferias", "rh.ficha",
                                         "rh.tempo_servico", "rh.declaracoes", "normas.legislacoes", "atend.feedback"] },
    { "chave": "home.contracheque" },
    { "chave": "home.tempo_servico" },
    { "chave": "home.ferias" }
  ],
  "busca": { "mais_procurados": ["rh.contracheques", "rh.certidoes"] },
  "textos": { "inicio.rodape": "Desenvolvido pelo DTI" },
  "rede": { "timeout_s": 15 },
  "log": { "ativo": true, "lote": 50, "intervalo_s": 30 }
}
```

Regras do contrato:
- **Chave desconhecida é ignorada** pelo app (o painel pode crescer antes do
  app). **Chave ausente** = padrão do app (o app pode crescer antes do
  painel). Chave antiga (§2) é aceita como apelido durante a 2.2.
- `menu` e `home` vêm **filtrados pelo perfil e ordenados** pelo servidor. Item
  fora do público vem `oculto` (some) ou `bloqueado` com motivo `restrito`,
  conforme `fora_do_publico`.
- `nivel`, `papeis` e `lotacao` servem para o app mostrar a lotação completa e
  o selo do nível na Início e em Perfil; **nunca** para decidir acesso. Quem decide é o servidor, aqui e de novo no endpoint da
  função.
- Ícone é sempre uma **chave** do mapa de ícones do app. Ícone novo exige
  versão nova do app; o painel só oferece as chaves publicadas pela equipe do
  app.
- `rota` só é seguida se estiver no registro de módulos do app; rota
  desconhecida mostra "Atualize o app para usar esta função"
  (`MD-<CHAVE>-ATUALIZAR`).
- O app guarda a última resposta e a `versao_config`. Sem rede, usa a guardada;
  sem nenhuma, os padrões do código.
- `home.pendencias` vem **vazio** enquanto nenhum tipo estiver ligado (todos
  começam desligados, §5.5). Quando um tipo for ligado, cada item traz `tipo`,
  `sistema`, `titulo`, `texto`, `obrigatoria`, `dispensavel`, `destino` e
  `referencia`; fonte que não respondeu vem com `erro` (`PD-<SISTEMA>-<falha>`).
- Cada item do `menu` traz `visivel` (menu e busca), `estado` e, se for o
  caso, `mensagem` (§3.0). Item não autorizado vem conforme `fora_do_publico`.
- Comunicados e pendências vêm resumidos no `app_config` (para a Início abrir
  rápido); a lista completa, a leitura e a ciência usam `comunicados.php` e
  `pendencias.php`. Pendência de um sistema que não respondeu vem com `erro` e
  nunca some em silêncio.
- **Versões até 2.1.x** continuam lendo `appConfig/versions` no Firestore
  (SOUPM_2_2 §10 e §13): o painel grava lá o **menor** dos dois mínimos, nunca
  acima da última versão publicada em cada loja, até o corte (§5.6).
- **A 2.1.x não lê o `menu` nem o `home`.** Para ela vale só o que a API
  decide em cada endpoint (autorização e disponibilidade, §3.0): função
  bloqueada responde com a mensagem e o código `MD-…`, que a 2.1.x mostra no
  aviso de erro que já tem. Visibilidade no menu não muda nada nela.
- Tempo de resposta alvo: menos de 300 ms (uma consulta, com cache de alguns
  segundos no servidor).

### 9.1 Mudanças que o painel propõe ao contrato (21/10/2026)

Avisadas à sessão do app. Todas opcionais para o app (chave ausente = padrão
do app), então nenhuma quebra versão antiga.

| # | Mudança | Por quê |
|---|---|---|
| 1 | Novo campo de topo `categorias_comunicado: [{chave, nome, cor, icone}]`; cada item de `home.anuncio.dados.itens` traz `categoria` como chave | A cor e o ícone do cartão vêm do painel (§5.4), não do app |
| 2 | Item de comunicado ganha `pilula: {icone, texto}` e `versao` | Prévia fiel e ciência por versão |
| 3 | Novo bloco `ajuda: {assuntos: [{chave, nome, icone, perguntas: [{id, pergunta, resposta, destino, chamado: {tipo, categoria}}]}]}`, **sem WhatsApp, horário nem e-mail** (suporte só por chamado técnico desde a 2.2) | "Preciso de ajuda" guiado, cadastrado no painel (§5.12) |
| 4 | Feedback pela API do app (enviar com anexos, Minhas mensagens, responder), já no SOUPM_2_2 §8 | Decisão do usuário (§5.9) |
| 5 | Pendência de tipo desligado nunca aparece, nem como erro | Todos os tipos começam desligados (§5.5) |
| 6 | `versao` lida de `soupm_versao_regra` (mesmo formato do exemplo acima) | Uma linha por plataforma; o histórico fica em `soupm_versao_app` |
| 7 | Login pela intranet passa da fase 5 da 2.2 para a **2.3** | Decisão do usuário (§6.4). Até lá, MD5 no POST, como hoje |
| 8 | `papeis` traz as chaves dos papéis (`["soupm-comunicados"]`) só para o app mostrar selo; nunca para decidir acesso | Mesmo princípio do `nivel` |
| 9 | `home.comandantes.dados[]` ganha `cargo`, `quadro`, `desde`, `inclusao`, `lotacao`, `cursos[]` e `mensagem`, todos opcionais e já sem os campos escondidos no painel; vem só da versão aprovada | Comando pelo SIGRH com aprovação (SOUPM_2_2 §4.1) |
| 10 | `home` aceita blocos `home.livre.<chave>` com `modelo` (`campanha`, `atalho`, `numero`, `lista`), `dados`, `acao`, `escondivel` e `arte`. Modelo desconhecido é ignorado pelo app | Cards criados no painel (SOUPM_2_2 §4.6) |
| 11 | Todo bloco de `home` (fixo ou livre) e toda área do `menu` trazem `arte` (chave), `arte_estilo` (`cheio` ou `discreto`; sem ele, o padrão do bloco) e, se houver, `arte_imagem` (endereço da imagem aprovada, que vence a arte). Novo campo de topo `artes: [{chave, cores: [base, meio, destaque], icones: [3]}]` com as artes em uso. Sem `arte`, vale o padrão do app. Substitui o `marca`. Superfícies também: `perfil.capa`, `perfil.grupos`, `perfil.nivel` | Novo padrão visual: artes editáveis no painel (§5.3b)
| 12 | Propagação: `versao_config` com **ETag** (o app revalida com `If-None-Match` e recebe 304 quando nada mudou), novas tentativas com recuo quando a leitura falha, cache do servidor **invalidado ao publicar**, e um push silencioso só de dados `{"tipo": "config", "versao_config": N}` como **tentativa** de acelerar (o iOS limita esses pushes; não é garantia) | Texto único no painel: "Vale em segundos para quem está com o app aberto, e na próxima abertura para os demais" |
| 13 | Item do `menu` com `visivel` separado de `estado` (§3.0); `acao` aceita `avisar_quando_voltar` | Ocultar do menu não pode quebrar card nem push |
| 14 | `home.comandantes` traz `arte: "estrelas"` e `arte_estilo: "cheio"` e cada item de `dados[]` ganha `estrelas: N`, **calculado pela API** a partir do posto do SIGRH (ou o número fixo do painel) | O app só desenha as estrelas (§5.3b)

Exemplo de card no `home`:

```json
{ "chave": "home.livre.outubro_rosa", "modelo": "campanha", "escondivel": true,
  "arte": "rosa",
  "dados": { "selo": "Campanha", "titulo": "Outubro Rosa", "texto": "Exames preventivos na Diretoria de Saúde até 31/10." },
  "acao": { "tipo": "comunicado", "destino": 8, "rotulo": "Saiba mais" } }
```

---

## 10. Fases casadas com o app

Cada fase do painel entrega as telas de que a fase do app correspondente
precisa para ser configurada e conferida. Nenhuma fase do app depende de
editar o banco à mão. As fases do app são as do SOUPM_2_2 §16.

| Painel | Entrega | Casa com o app | Depende de |
|---|---|---|---|
| **P0. Fundação** | Módulo `soupm` na intranet (casca 2.0, menu, rotas, migrações), ACL (módulo, perfis, recursos), bloqueio por tentativas, sessão que expira, aviso de aparelho novo, CSRF, auditoria, usuário de banco; telas **Logs e erros** e **Auditoria**; Painel só com os indicadores de log | **App 0** (log, `FalhaApp`, `log.php`, tabelas de log) | Correções de autenticação da API (sessão de segurança); confirmar o banco único (R1) |
| **P1. O app obedece** | **Funções e menu** (com "ver como fica" e "ver o app como"), **Versões do app**, **Papéis** (acesso ao próprio painel), **Suporte e textos** | **App 1** (`soupm_menu_item`, `app_config.php`, versão por plataforma) | P0 |
| **P2. A nova Início** | **Tela inicial** (blocos, atalhos, Comando, dicas), **Comunicados** (editor com prévia, publicar, relatório), **Suas pendências** (catálogo todo desligado; ligar os de fonte pronta), **Militares** (consulta e "ver o app como") | **App 2** (navegação nova, Início, folha de bloqueio) | P1 |
| **P3. Feedback** | **Feedback** (caixa, anexos, classificar, responder, Minhas mensagens) | **App 3** (busca e feedback; tabelas de feedback) | P2 |
| **P3b. Contracheque pela API** | **Documentos › Contracheque** (Serviço, Padrão do PDF, Blocos e rubricas, Mensagens, Versões) e a prévia do PDF pela rotina da API | **App 3b** (`contracheque_pdf.php` com conferência e SHA-256; app pede o PDF pronto) | P3 |
| **P3c. Chamados no app** | **Chamados no app** (§5.18): ligar, tipos liberados, anexos, textos, avisos e indicadores | **App 3c** (SISCHAMADOS do lado de quem pede) | P3b; as 4 rotas novas da API móvel e o selo "Aberto pelo SOUPM", da intranet |
| **P4. Notificações** | **Notificações** (enviar, histórico, agendadas, lembretes, modelos), cron de envio pelo FCM na API do app, aparelhos, "desconectar" e resetar senha em Militares | **App 4** (fora do Firebase, escrita dupla) | P3; conta de serviço do FCM em `/private` |
| **P5. Níveis de acesso** | **Níveis de acesso** (escada, regras, prévia de entra e sai, membros com porquê, comparação com a regra antiga), papel "Publicar comunicados" valendo no app, relatório de ciência por escopo | **App 5** (níveis e papéis pelo painel, fim do `isSuperUser`) | P4; sessão "Chat Intranet" (ACL) |
| **P6. Acabamento e lançamento** | **Certidões** e **Declarações** com tela, no modelo do contracheque, Painel com todas as análises, conferência de acessibilidade (`web-design-guidelines`) e `verificar_design.php`, carga final revisada item a item | **App 6 e 7** (acabamento, lançamento 2.2.0) | P5 |
| **P7. Login único (2.3)** | Resetar senha passa a gravar na senha da intranet; painel mostra quem já migrou a senha | **App 2.3** (login pela API da intranet) | Itens 1 a 6 do §6.4, da intranet |

Até a P5, o Mapa da Força segue a regra de hoje (carga inicial igual à 2.1.5),
e o "nível mínimo" das funções fica fixo em "Militar" ou "Gestor (regra
antiga)". A tela Níveis de acesso só liga junto com a fase 5 do app.

**Paralelismo** (sessões separadas, como o usuário prefere): o painel é um
módulo novo em pasta própria da intranet, então anda junto com o app depois
que o contrato da fase estiver fixado. A sessão "Chat Intranet" precisa saber
antes, pelas regras de convivência da intranet (módulo novo, migrações, menu
"Todos os sistemas").

**Quem implementa o painel (decisão do usuário, 21/10/2026).** O painel é
feito **pela sessão "Chat Intranet"**, não pelas sessões deste repositório,
porque ele tem de seguir as regras de design e de desenvolvimento da intranet.

1. Esta sessão (do app) manda o módulo para a "Chat Intranet": este documento,
   o protótipo do painel e o contrato (§2 e §9). O usuário autorizou que esta
   sessão passe as instruções direto para ela.
2. A "Chat Intranet" abre uma **subsessão própria** para o painel.
3. A subsessão **lê primeiro as regras da intranet** (`REGRAS_DESIGN_2.0.md`,
   as regras de desenvolvimento e de convivência entre módulos) e o módulo
   SISCHAMADOS, que é o modelo.
4. Desenvolve o painel como **módulo novo da intranet** (`painelsoupmrr/`, em
   `/painelsoupmrr`), igual ao SISCHAMADOS: mesma estrutura de pastas, casca
   Nexus 2.0, ACL, migrações e `verificar_design.php`. **Em conflito, valem
   as regras da intranet**, e o desenho deste documento se adapta a elas.
5. O que é da API do app (`app_config.php`, `log.php`, o cron de envio pelo
   FCM, a sonda de saúde e os endpoints internos do §1.2) continua com as
   sessões deste repositório. Mudança no contrato (§2 e §9) é combinada entre
   as duas antes de ir para o código.

A ordem continua a das fases acima: cada fase do painel começa quando a fase
do app correspondente fixar o contrato dela, e a P0 só vai ao ar depois das
correções de segurança da API (§7).

**Duas frentes, que conversam entre si (decisão do usuário, 22/10/2026).**
- **App Flutter e API do app:** a sessão "SouPM 2.2", neste repositório, na
  branch `feature/soupm-2-2`.
- **Painel web:** a sessão "Chat Intranet" (ou uma subsessão dela), dentro da
  intranet, porque é lá que está todo o contexto e as regras dela. A sessão que
  planejou o painel passa tudo o que sabe para ela.
- As sessões podem e devem trocar mensagens direto: tirar dúvidas, avisar
  mudança no contrato (§2 e §9) antes de mexer no código e devolver o que
  aprenderem para os dois planos.

**Carga inicial = o app de hoje.** A fase P1 grava a árvore e os estados
exatamente como a 2.1.5 se comporta (Escalas e SVI "Em breve", Mapa da Força
para nível 2+). Publicar a 2.2 não muda nada para o militar até alguém mexer
no painel.

---

## 11. Decisões do usuário (todas fechadas em 21/10/2026)

1. ~~Quem é Administrador?~~ **Quem é administrador da intranet** acessa e
   gerencia o painel do SouPMRR automaticamente, com o login da intranet
   (decisão do usuário, 22/10/2026, que substitui a lista do SIGRH; ele vai
   detalhar depois). §6.3.
2. ~~Push dos módulos da intranet?~~ **Modelo do SIGE para todos**: a
   intranet manda para a API do SouPMRR, que filtra, gerencia e encaminha ao
   app; o filtro sempre existe (§4.1b).
3. ~~Resetar senha?~~ **Código de 6 dígitos no e-mail confirmado** (§5.7). O
   login continua como está até a mudança para a intranet (2.3).
4. ~~Comunicado editado?~~ **A ciência continua valendo**, com "texto
   alterado em …" (§5.4).
5. ~~Anexos de feedback?~~ **180 dias**, e **só o Administrador** do SouPMRR
   abre (§5.9).
6. ~~Retenção de logs?~~ **Ações 180 dias, erros 1 ano** (§5.8).
7. ~~Endereço do módulo?~~ **`/painelsoupmrr`** na intranet (§1.2).
8. ~~Comando e cursos?~~ **Tudo no SIGRH.** A intranet é o sistema novo para
   onde o SIGRH vai migrar, com o mesmo banco (uma cópia). Pedido novo: tela
   **Bancos e conexões** (§5.17), com troca de banco por prévia e auditoria.
   A aprovação do Comando fica com o Administrador.
9. ~~Prazos das declarações?~~ **Por campanha**: fechadas por padrão; o painel
   abre a campanha de um ano, com prazo; fora dela, `DC-FECHADA` (§5.10).
10. ~~Contracheque com QR de conferência?~~ **Sim**, como a certidão (§5.10).
11. ~~Retenção do registro de autenticidade?~~ **1 ano** para certidões,
    contracheques e todo documento futuro (`retencao_autenticidade_dias =
    365`). Depois, o QR responde que o registro de conferência expirou, nunca
    "não existe".
12. **Papéis:** até o login ir para a intranet, **só o Administrador** em uso.
    Consulta, Gerir certidões, Atender feedback, Publicar comunicados e Enviar
    notificações ficam desenhados, sem ninguém (§6.3).
13. **Fora da 2.2:** a "fábrica de funções" (blocos montáveis): funções novas
    continuam saindo em versão nova do app; fica como evolução futura,
    opcional, sem telas planejadas. Também não entram ambientes separados nem
    aprovação dupla.

---

## 12. Riscos

| # | Risco | Impacto | O que fazer |
|---|---|---|---|
| R1 | A intranet de produção não alcançar o mesmo banco das `soupm_*` | Médio | O usuário confirmou (21/10/2026) que a intranet usa o mesmo banco (uma cópia do SIGRH). Conferir na P0; a troca de banco, quando vier, é feita pela tela Bancos e conexões (§5.17), com prévia e volta |
| R2 | Abrir uma porta de escrita antes de fechar os endpoints sem autenticação da API | Alto | P0 só vai ao ar depois das correções da sessão de segurança (§7) |
| R3 | Push dos módulos da intranet parar no corte das Cloud Functions | Médio | Resolvido pela decisão 2 (§4.1b): a intranet passa a mandar para a API do SouPMRR antes do corte |
| R4 | A regra de níveis tirar o Mapa da Força de quem usa hoje (131 oficiais sem função de comando, número do protótipo) | Médio | Comparação obrigatória no painel e lista revisada pelo usuário antes de ligar |
| R5 | Volume de log no PostgreSQL 9.6 (sem partição declarativa) | Médio | Tabela por mês + view, índice por código e data, limpeza por mês inteiro, lote de 50 do app |
| R6 | App e painel mudarem o contrato sem combinar | Médio | §2 e §9 como ponto de encontro; toda mudança passa pela outra sessão antes |
| R7 | Outra sessão editando a intranet ao mesmo tempo | Médio | Módulo em pasta própria (`painelsoupmrr/`); arquivos comuns (`header.php`, menu de sistemas) só pela sessão "Chat Intranet" |
| R8 | JWT da intranet sem refresh separado e com chave padrão no código | Alto para a 2.3 | Itens 2 e 3 do §6.4 antes da 2.3 |
| R9 | Vídeos de feedback lotarem o disco | Baixo | Limite de 25 MB por envio, retenção (decisão 5), contagem de espaço no Painel |
| R10 | Texto de comunicado ou de pendência cortado no app | Baixo | Limites no banco (`CHECK`) e contador com prévia no painel |

---

## 13. Tarefas

Fatias verticais (banco + API + tela). Cada tarefa toca no máximo uns 5
arquivos e termina com o painel funcionando. Verificação comum a todas: `php
-l` nos arquivos, `verificar_design.php` sem erro, tela conferida nos dois
temas e a 390 px, `/security-review` em tudo que mexe com login, SQL ou dado
de militar, e a tarefa aparecendo na auditoria quando grava algo.

### P0. Fundação

| Tarefa | Aceite | Tam. |
|---|---|---|
| T0.1 Módulo `soupm` na intranet (pasta, `index.php`, rotas, casca 2.0, menu lateral vazio) | `/painelsoupmrr` abre dentro da casca com trilha e rodapé; sem papel, 403 do padrão | M |
| T0.2 ACL: migração do módulo, 6 perfis, recursos `soupm.*` e matriz | `require_access` barra cada rota; migração roda duas vezes sem erro | M |
| T0.3 Proteção de conta (bloqueio por tentativas, sessão com inatividade e prazo máximo, aviso de aparelho novo) e CSRF copiada do SISCHAMADOS | 5 senhas erradas bloqueiam; sessão parada 30 min cai; navegador novo gera e-mail; POST sem token é recusado | S |
| T0.4 Usuário de banco do painel e grants mínimos | O usuário do painel não consegue `UPDATE` fora das `soupm_*` | S |
| T0.5 Logs: filtros combináveis (com unidade e nível pelo SIGRH), abas, detalhe | Acha um erro por matrícula, código e versão em menos de 1 s com 1 milhão de linhas de teste | M |
| T0.5b Linha do tempo da sessão, CSV, filtros salvos | A linha do tempo mostra os passos até o erro; o CSV vai para a auditoria | M |
| T0.5c Catálogo de eventos ("Nunca visto", "Fora do catálogo") | Evento novo sem catálogo aparece marcado em até 1 min | S |
| T0.5d Filtros por lista (campos, valores com contagem, "é/não é"), facetas e clique na tabela | O usuário acha os erros do contracheque no Android sem digitar nenhuma chave | M |
| T0.7 Painel: mapa de conexões lido do catálogo `soupm_servico`, com sonda (`soupm_saude`) e status ao vivo | Desligar a API de legislações no teste deixa o nó vermelho em até 1 min; cadastrar um serviço novo faz ele aparecer no mapa sem mexer no código | M |
| T0.8 Painel: Agora e gráficos de uso | Cada número leva à tela que o explica | M |
| T0.9 Incidente em destaque com ação sugerida e disponibilidade 24 h | Banco lento abre o incidente com "Pôr em manutenção" de um clique | S |
| T0.10 Buscar no painel (`Ctrl K`) | Acha militar, função, comunicado, feedback e código e leva direto | M |
| T0.11 Alertas: regras prontas, nova regra por listas, disparos, aviso no sino da intranet | CC-LENTO 3× acima da média dispara em até 1 min | M |
| T0.13 Bancos e conexões: lista por `soupm_servico` (tipo banco), funções ligadas, sonda; credencial só por nome de conexão em `/private` | Nenhum endereço, usuário ou senha aparece no painel, no HTML ou no log | M |
| T0.12 Restaurar pela auditoria | Restaurar um bloqueio volta a função e gera linha nova | S |
| T0.6 Tela Auditoria (lê `intranet.auditoria` do módulo `soupm`) | Toda gravação das tarefas seguintes aparece com antes e depois | S |

**Checagem P0:** o usuário entra no painel com o login da intranet, vê os logs da fase App 0 e
a auditoria. Revisão do usuário antes de seguir.

### P1. O app obedece

| Tarefa | Aceite | Tam. |
|---|---|---|
| T1.1 Funções e menu: árvore, busca, editor, estados, mensagem, código `MD-` | Bloquear `rh.ferias` muda o app na próxima abertura e a API da função recusa | M |
| T1.2 Prévia da folha de bloqueio e "Ver o app como…" (nível ou matrícula) | A prévia bate com o app em modo vitrine | M |
| T1.3 Versões do app por plataforma, com contagem de afetados e escrita no Firestore legado | Mínima Android ≠ mínima iOS; 2.1.x lê o menor dos dois, nunca acima do publicado em cada loja; a tela bloqueia quando passaria | S |
| T1.6 Papéis (matriz, quem tem, data de fim) e Suporte e textos | Dar ou tirar papel entra na auditoria; a lista de administradores mostra a última revisão | M |

**Checagem P1:** carga inicial igual ao app de hoje, conferida item a item no
simulador (modo vitrine) com "ver o app como" para militar e gestor.

### P2. A nova Início

| Tarefa | Aceite | Tam. |
|---|---|---|
| T2.1 Tela inicial: blocos (todos desligáveis), ordem, público, arte, atalhos por nível | Desligar o Comando some do app; mudar a ordem padrão aparece para quem nunca personalizou | M |
| T2.1b Cards do painel: 4 modelos, prévia 2 temas × 2 plataformas, publicar com push silencioso | Card publicado aparece no app aberto em menos de 1 min, sem versão nova | M |
| T2.2 Comando: leitura do SIGRH, pendente com antes e depois, aprovar com ajustes | Uma troca no SIGRH só aparece no app depois de aprovada, e a aprovação está na auditoria | M |
| T2.2b Dicas e foto oficial (upload conferido pelo conteúdo) | Foto sobe para a pasta só de imagens com nome por hash | S |
| T2.3 Comunicados: lista, categorias, editor com prévia e limites | Prévia igual ao cartão do app nos dois temas | M |
| T2.4 Publicar, destaque de abertura, ciência com prazo, relatório por unidade | Ciência gravada no app aparece no relatório; gestor N3 vê só a OPM | M |
| T2.5 Suas pendências: catálogo (37 tipos do SOUPM_2_2 §4.3, desligados), configuração, simulação, homologação | Nada liga sem fonte confirmada; homologar a declaração de bens e ligar mostra no app de quem não declarou | M |
| T2.6 Militares: busca, nível e porquê, últimas ações, diagnóstico e resposta sugerida | O diagnóstico separa erro da conta de erro de serviço | M |
| T2.9 Artes dos cards: catálogo com a carga inicial e as sugeridas, editor com prévia e contraste, onde é usada, duplicar e arquivar | Editar a arte `cc` muda o card do contracheque e o atalho sem versão nova do app; arte em uso não arquiva | M |
| T2.8 Catálogos dos cards: mídia aprovada, paleta fechada com conferência de contraste, fontes de dados (`soupm_fonte_dados`) | Cor fora da paleta ou contraste abaixo de 4,5:1 não publica | M |
| T2.7 Agenda do app com aviso de conflito | Dois destaques de abertura no mesmo dia aparecem como conflito | M |

**Checagem P2:** a Início da 2.2 inteira configurada pelo painel, sem SQL à
mão.

### P3 a P7

| Tarefa | Aceite | Tam. |
|---|---|---|
| T3.1 Feedback: caixa, detalhe, anexos servidos com checagem de papel | Anexo não abre por link direto sem sessão | M |
| T3.3 Assuntos em alta (agrupar parecidos, responder ao grupo) | Feedbacks com a mesma função e código caem no mesmo grupo | M |
| T3.2 Classificar, duplicado, responder, conversa, pendência `soupm.feedback_resposta` | Resposta chega ao app como notificação | M |
| T3b.1 Contracheque: abas Serviço, Padrão, Blocos e rubricas, Mensagens, Versões | Mudar o rodapé e publicar muda o PDF seguinte sem versão nova do app; a versão sai impressa no PDF | M |
| T3b.2 Rubricas: nome de exibição, ordem, grupo e visível | Renomear uma rubrica muda o PDF e a tela do app; código e valor continuam os do SIGRH | S |
| T3b.3 Prévia do PDF pela rotina da API (fictício, caso longo, matrícula real com auditoria) | A prévia tem o mesmo conteúdo do PDF que o militar baixa | M |
| T3b.4 Comparação do PDF novo com o de hoje, página por página, antes de trocar | O usuário aprova a comparação com dados fictícios e uma matrícula real | S |
| T3c.1 Chamados no app: ligar, tipos e categorias liberados, anexos, textos, avisos (§5.18); selo "Aberto pelo SOUPM" no SISCHAMADOS (lado da intranet) | Um tipo desmarcado some do app; o chamado aberto pelo app chega na intranet com o selo | M |
| T4.1 Envio: um militar, grupo (filtros §4.3 com contagem e amostra), todos | Confirmação com a quantidade; acima de 500, digitar | M |
| T4.2 Cron de envio na API do app (FCM HTTP v1, lotes, token vencido), destino por aparelho | Histórico com aceitos pelo FCM, falhas, sem aparelho e abertos; nunca "entregue" | M |
| T4.5 Módulos da intranet: cadastro, chave de serviço, limites, tipos aceitos, histórico de pedidos (§4.1b) | Pedido do SIGE passa pelo filtro, chega como push e não entra em Avisos | M |
| T4.3 Agendadas, lembretes automáticos, modelos | Lembrete de férias sai 7 e 1 dia antes, só se ligado | M |
| T4.4 Aparelhos em Militares, desconectar, resetar senha | Reset manda código ao e-mail confirmado e tira os aparelhos | M |
| T5.1 Níveis de acesso: escada e regras lidas do SIGRH | Regra nova grava só depois da prévia | M |
| T5.2 Prévia de quem entra e sai, membros com o porquê | A prévia lista os nomes e o motivo de cada um | M |
| T5.4 Troca de banco (Bancos e conexões): prévia com consultas das funções ligadas, troca por função ou total, auditoria e voltar | A troca de Certidões para a conexão nova mostra a comparação antes e volta com um clique | M |
| T5.3 Comparação com a regra antiga (`isSuperUser`) e exportação | Lista de quem ganha e quem perde revisada pelo usuário antes de ligar | S |
| T6.1 Certidões com tela (tipos, textos com aval da DRH, emissões, revogar) | Revogar mostra "revogada" no QR | M |
| T6.6 Declarações por campanha: abrir o ano com prazo, `DC-FECHADA` fora dela, pendência só com campanha aberta | Fora da campanha, o app e a API recusam com o motivo | M |
| T6.3 Relatório semanal | A prévia chega no e-mail de quem pediu | S |
| T6.2 Painel com todas as análises e revisão de acessibilidade | Navegação por teclado completa; contraste AA nos dois temas | M |
| T7.1 Reset de senha e "migrou a senha" com o login da intranet (2.3) | Uma senha só vale no app e na intranet | M |

---

## Anexo A. Módulo Certidões (já pronto, 16/10/2026)

O primeiro módulo a seguir este modelo. Vale como referência de padrão para os
outros.

| Onde | O quê |
|---|---|
| `public.soupm_config` | Uma linha por módulo (`chave`), com um JSON (`valor`). |
| `public.soupm_certidao_tipo` | Uma linha por tipo de certidão. |
| `sigrh/certidoes/certidao_config.php` | Lê as duas tabelas por cima dos padrões do código. Se a leitura falhar, valem os padrões e nada para. |
| `autoemissao.php` (painel) | Devolve tudo ao app: `servico`, `textos`, `declaracao`, `validade_dias` e, por tipo, `titulo`, `titulo_curto`, `descricao`, `icone`, `etapas`, `situacao`. O `titulo` é também o do PDF, do nome do arquivo e do e-mail. |
| `autoemissao.php` (emitir) | Recusa a emissão com o serviço ou o tipo desligados, mesmo que o app esteja aberto há horas. |
| App (`certidoes_page.dart`) | Usa os textos e ícones da API, mostra o aviso de serviço fora do ar e o selo "Temporariamente indisponível". Sem API (offline), usa os padrões locais. |

SQL: `api-soupmrr/sql/2026-10-16_soupm_config.sql`.

### A.1 `soupm_config`, chave `certidoes`

Campo ausente usa o padrão de `certidaoConfigPadrao()`.

```json
{
  "servico": {
    "ativo": true,
    "titulo": "Emissão de certidões indisponível",
    "mensagem": "A emissão de certidões está temporariamente suspensa. ..."
  },
  "textos": {
    "topo": "Emita suas certidões na hora. Elas ficam salvas aqui por {validade} dias ...",
    "escolha": "Escolha a certidão que você precisa.",
    "lista_vazia": "As certidões que você emitir ficam aqui por {validade} dias.",
    "botao": "Emitir nova certidão"
  },
  "validade_dias": 30,
  "limite_hora": 15,
  "declaracao": { "versao": 2, "texto": "Declaro que conferi ..." },
  "motivo_tipo_desativado": "Esta certidão está temporariamente indisponível. ...",
  "etapas_finais": ["Validando os dados da certidão", "Lavrando o documento", "..."],
  "ressalvas": {
    "tempo_servico": [
      { "titulo": "Da finalidade administrativa", "texto": "Esta certidão possui natureza exclusivamente administrativa, ..." },
      { "titulo": "Da validade para fins do processo seletivo", "texto": "Esta Certidão Administrativa ... CFS QPC PM." }
    ]
  }
}
```

- `{validade}` nos textos é trocado por `validade_dias`.
- **Revisão de 21/10/2026:** `validade_dias` passa a ser só a validade do
  documento. Entram `download_dias` (quanto tempo o app deixa baixar de novo)
  e `retencao_autenticidade_dias` (quanto tempo o QR responde e o registro
  fica guardado; carga inicial **365**, decisão de 21/10/2026). Sem os campos novos, vale o
  comportamento de hoje.
- **Ressalvas:** lista de seções impressas no fim do PDF, abaixo da data, por
  tipo e na ordem. A lista do banco substitui a do código inteira. Texto vazio =
  seção pulada. É texto de documento oficial: mudar só com aval da DRH.
- **Declaração:** mudou o texto, aumente a `versao`. O app manda a versão que
  o militar leu, a API recusa versão antiga e a versão fica gravada em cada
  emissão e impressa no PDF.

### A.2 `soupm_certidao_tipo`

| Coluna | Uso |
|---|---|
| `tipo` | Chave fixa (`tempo_servico`, `vinculo_funcional`, `comportamento`, `ficha_funcional`). Tipo novo precisa de código: o PDF de cada um é escrito em `certidao_pdf.php`. |
| `titulo`, `descricao` | O que o militar lê na lista. Nulo = padrão. |
| `titulo_curto` | Nome curto da barra do topo quando o militar abre a certidão ("Tempo de Serviço"). Nulo = padrão do código. Coluna criada pelo SQL `2026-10-19_certidao_titulo_curto.sql`; a API funciona sem ela. |
| `icone` | Chave: `tempo`, `escudo`, `medalha`, `ficha`, `documento`, `relogio`, `calendario`, `diploma`, `balanca`, `casa`, `saude`, `arma`. Chave nova exige incluir no mapa `_icones` do app. |
| `ordem` | Posição na lista. |
| `ativo`, `motivo_inativo` | Liga/desliga. Desligado, o app mostra o selo "Temporariamente indisponível" com o motivo e a API recusa a emissão. |
| `etapas` | JSON com as etapas do botão (as finais são somadas). |

### A.3 Operações de hoje (enquanto o painel não existe)

```sql
-- Tirar um tipo do ar
UPDATE public.soupm_certidao_tipo
   SET ativo = false, motivo_inativo = 'Em manutenção. Volta hoje às 18h.', atualizado_em = NOW()
 WHERE tipo = 'comportamento';

-- Voltar
UPDATE public.soupm_certidao_tipo SET ativo = true, motivo_inativo = NULL WHERE tipo = 'comportamento';

-- Serviço inteiro fora do ar
UPDATE public.soupm_config
   SET valor = jsonb_set(valor, '{servico,ativo}', 'false'), atualizado_em = NOW()
 WHERE chave = 'certidoes';
```

A mudança vale na próxima vez que o militar abrir a tela (ou puxar para
atualizar). Na emissão vale na hora.

## Anexo B. Modelos de certidão editáveis (futuro, não prioritário)

**Hoje.** O PDF já é todo montado na API (`certidao_pdf.php`), e o app só
recebe o arquivo pronto. Corrigir ou mudar o layout é só alterar a API, sem
publicar versão nova do app. Mas cada modelo é desenhado em código PHP: mudar o
PDF ou criar um tipo novo exige editar esse arquivo no servidor.

**Objetivo.** Ajustar o desenho ou criar um tipo novo pelo painel, sem mexer em
código.

**Como.**
- Tabela `soupm_certidao_modelo`: `tipo`, `versao`, `conteudo` (HTML do modelo,
  que o TCPDF já sabe renderizar), `status` (`rascunho` | `publicado` |
  `arquivado`), `criado_por`, `publicado_por`, `publicado_em`.
- Campos no modelo: `{nome}`, `{matricula}`, `{cpf}`, `{posto}`,
  `{data_inclusao}`, `{tempo_total}`. Para listas, blocos prontos, como
  `{tabela_anos}`, `{tabela_nao_computados}`, `{tabela_averbado}`,
  `{tabela_punicoes}`, `{tabela_dependentes}` e `{foto}`. Os dados continuam
  vindo de `certidao_dados.php` e passando por `certidao_validacao.php`. O
  modelo decide só como aparece, nunca o que é verdade.
- Ficam fora do modelo e são sempre impressos pelo código: o cabeçalho oficial
  (brasão, Estado, PMRR, unidade), o quadro de autenticidade com o QR Code e o
  código, e o rodapé com a paginação. Assim nenhum modelo editado sai sem
  autenticação.
- Tipo novo = cadastrar o tipo em `soupm_certidao_tipo`, escolher as seções
  obrigatórias da validação e publicar um modelo. Sem PHP novo.
- Os 4 modelos atuais são convertidos primeiro, comparando o PDF novo com o
  atual página por página antes de trocar.

**Cuidados (documento com fé pública).**
- **Pré-visualização obrigatória:** o painel gera o PDF com dados de teste e
  com uma matrícula real escolhida pelo administrador. Só se publica o que foi
  visto.
- **Versões:** cada publicação vira uma versão nova. Voltar para a anterior é
  um clique. A emissão grava `modelo_versao` em `soupm_certidao_emissao`, para
  saber com qual modelo cada certidão saiu.
- **Validação do modelo antes de publicar:** campo desconhecido, bloco
  obrigatório faltando ou HTML que quebra o PDF impedem a publicação.
- **Quem pode:** só o perfil de administrador de certidões publica. Tudo vai
  para `soupm_admin_log`.
- **Proteção:** se o modelo publicado falhar ao gerar, a emissão é cancelada
  como hoje (`certidaoCancelarEmissao`) e o militar recebe a mensagem. Nunca
  sai PDF pela metade.
