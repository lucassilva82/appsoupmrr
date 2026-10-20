# Painel web do SouPMRR — planejamento

> **Para quem é este documento.** A sessão que cuida do desenvolvimento web na
> intranet vai construir o painel. Este plano diz **o que** o painel controla,
> **como o app obedece** e **em que ordem** fazer. Foi escrito em 20/10/2026, a
> partir do levantamento completo do app (Flutter), da API PHP (`sigrh/`) e do
> Firebase. Os números de linha citados são dessa data.

## 0. Resumo

O app cresceu e quase tudo nele é fixo no código: o grid "Acesso Rápido", a
lista "Em breve", os cards da tela inicial, as abas, os textos de suporte e as
regras de quem vê o quê. Hoje só três coisas mudam sem versão nova:
- as **certidões**, pela API (`soupm_config` e `soupm_certidao_tipo`);
- o **anúncio, as dicas, os cards dos comandantes e a versão mínima**, pelo
  Firestore, editados à mão no console;
- os **avisos gerais**, pela Cloud Function `notificarTodos`.

O painel muda isso. **Tudo o que o militar vê passa a ser controlado por ele:**

1. **Funções:** cada tela, card, item do grid, aba e ação pode ficar **ativa**,
   **bloqueada** (aparece, e ao tocar mostra uma mensagem específica do motivo)
   ou **oculta** (some). Também dá para liberar só para um público (perfil,
   posto, lista de matrículas).
2. **Notificações:** para um militar, para um grupo montado com filtros
   detalhados (posto, quadro, turma por ano de incorporação, lotação, sexo,
   idade, situação e outros), ou para todos. Com prévia de quantos vão receber,
   agendamento, modelos e histórico.
3. **Tela inicial:** liga, desliga e ordena cada card; edita o anúncio, as dicas
   e os comandantes.
4. **Conteúdo:** contatos do suporte, perguntas frequentes, textos de telas,
   versão mínima do app.
5. **Certidões:** o que já existe, mais emissões, revogação e log de
   verificações.

A regra é a de sempre: **o painel edita o banco, a API decide, o app só
desenha.** O app nunca recebe segredo e nunca grava configuração.

---

## 1. Arquitetura

```
Painel web (intranet) ──► API de administração (intranet) ──► Postgres (soupm_*)
        │                          │                               │
        │                          └──► Cloud Functions (FCM) ◄────┤ (token só no servidor)
        │                                                          │
App do militar ◄── sigrh/app_config.php (leitura) ◄────────────────┘
               ◄── Firestore (só notificações: histórico e lido/não lido)
```

**Decisões (propostas; confirmar na seção 11):**

- **Uma fonte de verdade só: o Postgres.** O que hoje está no Firestore
  (`appConfig/anuncio`, `appConfig/versions`, `dicas_app`, `stores`) migra para
  tabelas `soupm_*`. O Firestore fica só para o que é de notificação (histórico
  por militar, avisos gerais, lido/não lido, tokens FCM). Motivo: o app não usa
  Firebase Auth e as regras do Firestore estão provavelmente abertas, então
  qualquer um que conheça o projeto pode editar o anúncio. Configuração não pode
  morar ali.
- **O painel e a API de administração ficam na intranet**, com autenticação
  própria de administrador. **Nada de painel dentro da pasta pública da API do
  app.**
- **O app lê um endpoint só de configuração:** `sigrh/app_config.php`, mantido
  junto da API do app. Uma chamada na abertura (e ao voltar para o app depois
  de alguns minutos) devolve tudo: módulos, cards, grid, abas, textos e versão
  mínima. Ver o contrato na seção 9.
- **O token das Cloud Functions (`x-admin-token`) fica só no servidor da API de
  administração.** O navegador do painel nunca o vê.
- **Tolerância a falha:** se o `app_config` falhar, o app usa o último que
  guardou; se nunca recebeu, usa os padrões do código. Configuração nunca
  impede o app de abrir (mesmo padrão do `certidao_config.php`).

---

## 2. Inventário: tudo o que o painel vai controlar

Cada item ganha uma **chave estável**, que é como o painel e o app se referem a
ele. A chave nunca muda depois de publicada.

### 2.1 Telas e funções

| Chave | Função | Onde aparece hoje | Dados |
|---|---|---|---|
| `ficha_individual` | Ficha Individual / Perfil (dados, contato, endereço, situação funcional) | Aba Perfil, grid id 1 | `buscapormatricula.php`, `inserecontato`, `deletacontato`, `atualizaendereco`, `buscasituacaofuncional` |
| `ficha_individual.contato` | Adicionar/excluir telefone | Perfil › Contato | `inserecontato.php`, `deletacontato.php` |
| `ficha_individual.endereco` | Editar endereço | Perfil › Endereço › lápis | `listaenderecocompleto.php`, `atualizaendereco.php` |
| `certidoes` | Emitir e guardar certidões | Grid id 6 | `certidoes/autoemissao.php` (**já controlado**, Anexo A) |
| `contracheques` | Lista de meses, contracheque do mês, PDF | Grid id 4, card da home | `listamesescontracheque*.php`, `exibecontracheque*.php` |
| `contracheques.grafico` | Evolução salarial | Botão flutuante em Contracheques | mesmos endpoints |
| `plano_ferias` | Plano de férias | Grid id 9, card da home | `buscaplanodeferias.php` |
| `declaracoes` | Declarações anuais | Grid id 3 | `buscastatusdeclaracoes.php` |
| `declaracoes.bens` | Declaração de bens | Dentro de Declarações | `buscabem`, `inserebem`, `excluibem` |
| `declaracoes.irpf` | PDF do IRPF | Dentro de Declarações | `buscapdfirpf`, `enviapdfirpf`, `excluipdfirpf` |
| `declaracoes.parentesco` | Declaração de parentesco | Dentro de Declarações | `buscaparentescos`, `insereparentesco`, `excluiparentesco` |
| `declaracoes.acumulo` | Acúmulo de cargos | Dentro de Declarações | `buscaacumulocargos`, `insereacumulocargos`, `excluiacumulocargos` |
| `calculo_inatividade` | Simulador de reserva remunerada | Grid id 12, card Tempo de serviço | `listar_policial_iper.php` + regras fixas |
| `legislacoes` | Legislações | Grid id 8 | `pm.rr.gov.br/api/legislacoes.php` |
| `pops` | POPs | Grid id 10 | mesma API de legislações |
| `mapa_forca` | Mapa da Força (gráficos, mapa geral, comandos, ficha de outro militar) | Grid id 5, **só isSuperUser** | `mapadaforca/*.php` |
| `escalas` | Escalas e ciência | Grid id 2, **"Em breve"** | API da intranet `/escala/*` |
| `svi` | Serviço voluntário | Grid id 11, **"Em breve"** | API da intranet `/svi/*` |
| `plantao` | Meu Plantão (calendário local) | Sem menu; só por push `/plantao` | local |
| `avisos` | Avisos e notificações | Aba Avisos, sino | Firestore |
| `config.email` | Confirmar/trocar e-mail | Configurações › Conta | `status_email.php`, `api_update_email.php` |
| `config.alterar_senha` | Alterar senha | Configurações › Conta | `alterar_senha.php` |
| `config.biometria` | Entrar com biometria | Configurações › Segurança | local |
| `config.tema` | Tema claro/escuro/automático | Configurações › Aparência | local |
| `config.notificacoes` | Ligar/desligar avisos | Configurações › Notificações | FCM |
| `ajuda` | Suporte técnico (WhatsApp, e-mail, perguntas frequentes) | Configurações › Suporte | textos fixos |
| `login.primeiro_acesso` | Primeiro acesso | Tela de login | `primeiro_acesso.php` |
| `login.recuperar_senha` | Esqueci a senha | Tela de login | `recuperar_senha.php` |

### 2.2 Tela inicial (cards, na ordem de hoje)

| Chave | Card | Fonte hoje |
|---|---|---|
| `home.anuncio` | Popup do anúncio institucional (ex.: "Operação Eleições") | Firestore `appConfig/anuncio` (`ativo`, `imagem`, `tipo`, `destino`) |
| `home.comandantes` | Cards Comandante / Sub-Comandante | Firestore `stores` (doc 0 e 1, sem ordem) |
| `home.dicas` | Balão de dicas | Firestore `dicas_app` (+ 10 dicas fixas de reserva) |
| `home.contracheque` | Card Contracheque | API |
| `home.tempo_servico` | Card Tempo de serviço | API |
| `home.plano_ferias` | Card Plano de férias | API |
| `home.acesso_rapido` | Grid "Acesso Rápido" | fixo (`grid_menu.dart`) |
| `home.rodape_dti` | Imagem do DTI no rodapé | fixo |

### 2.3 Grid "Acesso Rápido" (`grid_menu.dart:24-166`)

Os 12 itens: Ficha Individual, Certidões, Contracheques, Mapa da Força (só
isSuperUser), Plano de Férias, Declarações, Cálculo Inatividade, Legislações,
POPS, Escalas ("Em breve"), SVI ("Em breve") e Sair. Cada um vira um registro
com chave da função, rótulo, ícone (chave do mapa de ícones do app), ordem,
estado e público. **Sair** não pode ser desligado.

### 2.4 Abas e outros

- Abas: Início, Perfil, Avisos, Config. (as quatro podem ter rótulo e ordem do
  painel; **Início não pode ser ocultada**).
- Atualização obrigatória: `min_version` e os textos da tela "Nova versão
  disponível" (hoje em `appConfig/versions` e fixos em `auth_or_home.dart`).
- Suporte: WhatsApp, horário, e-mail, 7 perguntas frequentes, cartão do DTI
  (fixos em `ajuda_page.dart`).
- Textos fixos que vale levar para o painel: o diálogo de permissão de
  notificação, a confirmação ao desligar avisos, "Desenvolvido pelo DTI…", os
  rótulos "Comandante"/"Sub-Comandante".
- **Fica no código (não é do painel):** as regras legais do cálculo de
  inatividade (datas de corte, pedágio, quotas). São regra de negócio e mudam
  com lei, não com clique. O painel pode, no máximo, tirar a função do ar.

---

## 3. Controle de funções: estados e mensagens

### 3.1 Os três estados

| Estado | O que o militar vê |
|---|---|
| `ativo` | Normal. |
| `bloqueado` | O item aparece apagado (opacidade 0,45) com um selo curto ("Em breve", "Manutenção", "Indisponível"). Ao tocar, abre a **mensagem do bloqueio**. Se o militar chegar à tela por outro caminho (push, card), a tela mostra a mesma mensagem no lugar do conteúdo. |
| `oculto` | Some do grid, da home e dos menus. Push para a rota dela é ignorado e abre a home. |

**Regra de segurança:** bloquear ou ocultar no app não basta. A API do app
também tem que recusar a ação (como as certidões já fazem na emissão). Para as
funções da fase 1, `app_config.php` e o endpoint da função leem o mesmo
registro.

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
| `acao` | `nenhuma`, `whatsapp_suporte`, `abrir_link`, `atualizar_app` (opcional) |
| `codigo` | `MD-CONTRACHEQUE-MANUT` (gerado: `MD-<CHAVE>-<MOTIVO>`, vai para o log) |

Cada motivo tem um texto padrão (por exemplo, `em_breve`: "Este recurso estará
disponível em breve."), e o painel pode sobrescrever. O painel mostra uma
**prévia** do aviso exatamente como sai no app (o desenho do `avisoRapido`, ou
do cartão de erro para textos longos).

### 3.3 Público (quem vê)

Cada registro tem um `publico` opcional. Sem público, vale para todos.

- **Perfil:** `todos`, `superuser` (hoje: nível 1, ou `idPosto < 8`, exceto
  nível 10), `admin` (nível 1), `gestor`.
- **Posto/graduação, quadro, comando/unidade.**
- **Lista de matrículas** (piloto, testes com poucos militares).
- **Versão do app:** `versao_min_app` (função nova só para quem atualizou).

Quem está fora do público vê o item como `oculto` (padrão) ou `bloqueado` com o
motivo `restrito`, conforme o painel escolher. Exemplo: o Mapa da Força hoje é
`ativo` para `superuser` e `oculto` para os demais; isso sai do código e vai
para o painel.

**Como o público é avaliado:** no servidor. O app manda matrícula + senha (MD5,
o mesmo esquema das certidões) para o `app_config.php`, que resolve o perfil e
os dados do militar no SIGRH e devolve já a lista final. O app não decide
quem vê o quê. Antes do login (tela de login), o `app_config` devolve só a
parte pública (login, primeiro acesso, recuperar senha, versão mínima).

### 3.4 Agendamento

Todo registro aceita `inicio` e `fim` opcionais. Exemplo: bloquear o
contracheque de 20/10 às 22h até 21/10 às 6h, e voltar sozinho. O
`app_config.php` aplica o agendamento na leitura (sem cron).

---

## 4. Notificações

### 4.1 O que existe hoje

- `notificarMilitar` (Cloud Function, `x-admin-token`): um militar. Grava em
  `militares/{matricula}/notificacoes` e manda para **um** token FCM.
- `notificarTodos` (`x-admin-token`): grava em `avisos_gerais` e manda para o
  tópico `todos_militares`. Todo aparelho com o app instalado está nesse
  tópico, inclusive sem login.
- `notificarEscala`: **sem nenhuma autenticação**, com lista de 7 matrículas de
  teste. Não usar no painel; proteger ou desligar (seção 7).
- Rotas que um push pode abrir (`main.dart:413-430`): `/home-page`, `/plantao`,
  `/escalas`, `/svi/escalas`, `/svi/meus-voluntarios`, `/notifications-page`,
  `/contracheque-page`, `/plano-de-ferias-page`, `/certidoes-page`,
  `/declaracoes-page`, `/legislacoes-page`, `/pop-page`, `/mapa-da-forca-page`,
  `/ajuda-page`, `/configuracoes`, `/page-militar`. O painel oferece **um
  select com exatamente essa lista** (rota fora dela é ignorada pelo app).
- Com o app aberto, o aviso só aparece se estiver gravado no Firestore (o
  banner vem do stream, não do FCM). Por isso, **todo envio grava no
  Firestore**.

### 4.2 Telas do painel

1. **Para um militar:** busca por matrícula, nome ou CPF; mostra posto,
   lotação e se tem o app (token). Título, texto, rota de destino, prévia.
2. **Para um grupo (filtros):** monta o público, mostra a contagem e uma
   amostra, depois envia. Detalhes em 4.3.
3. **Para todos:** igual ao `notificarTodos`, com prévia e confirmação dupla.
4. **Modelos:** textos prontos (contracheque disponível, escala publicada,
   campanha), com campos como `{nome}`, `{posto}`.
5. **Histórico:** cada envio, com autor, data, público (filtros usados),
   quantos alvos, quantos com app, enviados, falhas, sem token. Reenviar para
   quem falhou.
6. **Agendados:** envios marcados para data e hora, com cancelar.

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
| Perfil no app | superuser, admin, gestor | `public.vw_users_unidade_comando_groups` (`grupo`, `nivel`, `id_posto`) |
| E-mail confirmado | sim/não | `qra.sec_users.activation_code` |
| Conta ativa no SIGRH | sim/não | `qra.sec_users.active` |
| Tem o app (token FCM) | sim | Firestore `militares/{matricula}.fcmToken` (cruzado depois do filtro) |
| Declaração pendente no ano | sim | a mesma lógica de `buscastatusdeclaracoes.php` |
| Recebeu contracheque no mês | sim | `public.vw_cc_novo_1` |
| Cursos | — | **não existe tabela consultada pela API hoje**; ver com o SIGRH/intranet |

**Cuidados com os dados:** a matrícula é `int` em `policial_militar` e texto em
`qra.sec_users.login`; o CPF aparece com e sem máscara. O FCM é endereçado por
matrícula (texto).

**Prévia obrigatória:** antes de enviar, o painel mostra quantos militares o
filtro achou, quantos têm o app, e 20 nomes de amostra (posto, nome, lotação).
Acima de 500 destinatários, pede para digitar a quantidade para confirmar.

**Filtros salvos:** um filtro pode ser salvo com nome ("Turma 2021", "Praças do
CPC") e reaproveitado.

### 4.4 Como enviar para um grupo

1. A API de administração resolve o filtro no Postgres e obtém a lista de
   matrículas.
2. Chama uma **Cloud Function nova, `notificarGrupo`** (protegida por
   `x-admin-token`, sem lista de autorizados), com a lista em lotes. Ela
   reaproveita `enviarParaMatriculas` (`functions/index.js:28-101`): grava em
   `militares/{m}/notificacoes` (histórico e banner com o app aberto) e manda
   por token.
3. A função devolve enviados, falhas e sem token; a API grava no histórico
   (`soupm_notificacao_envio` e `soupm_notificacao_destino`).
4. Envio para grupo **não** usa `avisos_gerais`: lá todo mundo veria.

Melhorias na função, na mesma entrega: remover tokens inválidos
(`registration-token-not-registered`), aceitar `tipo_evento` opcional (o app já
trata), validar a rota contra a lista do app, usar escrita em lote para
milhares de destinatários.

### 4.5 O que o app precisa mudar (versão 2.1.6 em diante)

- **Logout limpa o token e cancela os tópicos.** Hoje um aparelho deslogado (ou
  passado para outra pessoa) continua recebendo as notificações daquela
  matrícula.
- **Vários aparelhos por militar:** trocar `militares/{m}.fcmToken` (um só) por
  `militares/{m}/tokens/{token}` com plataforma, versão do app e último uso. A
  função manda para todos.
- **Tópicos só depois do login.**
- **Gravar em `militares/{m}`** posto, unidade e versão do app no login ajuda o
  painel a mostrar "tem o app" e "versão", mas **o filtro continua no
  Postgres** (fonte oficial).

---

## 5. Conteúdo

| Tela do painel | O que edita | Hoje |
|---|---|---|
| Anúncio | imagem, destino (link ou WhatsApp), período, público, ligado/desligado | `appConfig/anuncio` |
| Dicas | texto, ícone, tipo (dica, aviso, novidade, suporte), ordem, perfil, período | `dicas_app` (com emoji; trocar por chave de ícone, DESIGN §8) |
| Comandantes | foto, nome, cargo, ordem | `stores` (sem ordem) |
| Suporte | WhatsApp, horário, e-mail, perguntas frequentes | fixo |
| Versão mínima | `min_version` por plataforma, textos da tela de atualização | `appConfig/versions` + fixo |
| Textos de telas | os listados em 2.4 | fixo |

Imagens enviadas pelo painel ficam no servidor (pasta pública só de imagens,
sem PHP executável), com nome por hash.

---

## 6. Certidões e outros módulos de gestão

- Tudo do Anexo A (tipos, textos, ressalvas, declaração, liga/desliga).
- **Emissões:** busca por matrícula, código ou data; ver o PDF (com permissão);
  **revogar** com motivo (`soupm_certidao_emissao` já tem `revogada_em`,
  `revogada_por` e `motivo_revogacao`).
- **Verificações:** log das consultas do QR (`soupm_certidao_verificacao_log`).
- **Login:** bloqueios por tentativas (`soupm_login_tentativa`), com desbloquear.
- **Modelos editáveis de certidão:** Anexo B (futuro, não prioritário).
- **Painel inicial (dashboard):** usuários ativos no app, versões em uso,
  certidões emitidas, notificações enviadas, funções bloqueadas agora.

---

## 7. Pré-requisitos de segurança (antes do painel ir ao ar)

O levantamento da API achou problemas que o painel tornaria mais graves (ele
cria uma porta com poder de escrita sobre os mesmos dados). Ordem sugerida:

**Do próprio painel (obrigatório):**
1. Login de administrador próprio: tabela `soupm_admin_usuario` com senha em
   bcrypt/argon2, sessão no servidor, **2FA**, bloqueio por tentativas. **Não
   reaproveitar o MD5 do SIGRH.**
2. Perfis e permissões no banco (`soupm_admin_perfil`): quem vê, quem edita
   funções, quem envia notificação para grupo, quem envia para todos, quem
   revoga certidão.
3. `soupm_admin_log` em toda alteração e todo envio (quem, quando, o quê, antes
   e depois, IP).
4. Usuário de banco próprio do painel, com `UPDATE` só nas tabelas `soupm_*`
   que edita. O usuário da API do app continua com `SELECT` nelas.
5. CORS restrito à origem do painel, CSRF nos formulários, segredos fora da
   pasta pública (`/private/`).

**Da API do app (risco atual, independe do painel; tratar em sessão própria):**
- Sem autenticação: contracheque, declarações, endereço, contato, plano de
  férias e Mapa da Força respondem a qualquer `cpf`/`matricula`.
- SQL injection em `buscasituacaofuncional`, `inserecontato`, `deletacontato`,
  `atualizaendereco`, `exibecontracheque`, `exibecontracheque_new` e outros.
- Endpoints legados que vazam hash ou token: `loginrh.php` (até as versões
  antigas saírem, APRENDIZADOS §30), `consulta_user.php`, `verifica_token.php`.
- Arquivos para remover da pasta pública: `teste_smtp.php` (senha SMTP no
  código: **trocar a senha**), `diag_mat.php`, `conexaoBancoGov.php`,
  `con_aberta.php`, `con_fechar.php`, `set_permissions.php`,
  `primeiro_acesso.php.bak-20261015`; `DEBUG=true` em
  `mapadaforca/listarsituacao.php`; logs dentro da pasta pública.
- `notificarEscala` sem autenticação (qualquer um manda push para as 7
  matrículas da lista).
- Firestore sem `firestore.rules` no repositório e sem Firebase Auth no app:
  conferir as regras no console.

---

## 8. Modelo de dados (proposta)

```sql
-- Funções, cards, itens do grid e abas: um registro por chave.
CREATE TABLE public.soupm_modulo (
    chave           VARCHAR(60) PRIMARY KEY,      -- 'contracheques', 'home.dicas', 'grid.mapa_forca'
    tipo            VARCHAR(20) NOT NULL,         -- funcao | card | item_grid | aba | acao
    pai             VARCHAR(60),                  -- 'declaracoes' para 'declaracoes.bens'
    nome            VARCHAR(120) NOT NULL,        -- nome no painel
    rotulo          VARCHAR(60),                  -- texto no app (grid, aba); nulo = padrão do app
    icone           VARCHAR(40),                  -- chave do mapa de ícones do app
    ordem           INT,
    estado          VARCHAR(12) NOT NULL DEFAULT 'ativo',   -- ativo | bloqueado | oculto
    motivo          VARCHAR(20),                  -- manutencao | em_breve | indisponivel | restrito | atualizar_app | personalizado
    selo            VARCHAR(20),
    msg_titulo      VARCHAR(120),
    msg_texto       TEXT,
    previsao        TIMESTAMP,
    acao            VARCHAR(20),                  -- nenhuma | whatsapp_suporte | abrir_link | atualizar_app
    acao_destino    TEXT,
    publico         JSONB,                        -- {"perfis":["superuser"],"postos":[..],"matriculas":[..]}
    fora_do_publico VARCHAR(12) DEFAULT 'oculto', -- oculto | bloqueado
    versao_min_app  VARCHAR(12),
    inicio          TIMESTAMP,
    fim             TIMESTAMP,
    bloqueavel      BOOLEAN NOT NULL DEFAULT TRUE, -- false para 'grid.sair', 'aba.inicio'
    atualizado_em   TIMESTAMP NOT NULL DEFAULT NOW(),
    atualizado_por  VARCHAR(20)
);

-- Conteúdo (anúncio, dicas, comandantes, suporte, textos) continua em soupm_config
-- (uma chave por módulo, valor JSONB), como as certidões. Listas com muitos itens
-- ganham tabela: soupm_dica, soupm_comandante.

-- Notificações
CREATE TABLE public.soupm_notificacao_envio (
    id            BIGSERIAL PRIMARY KEY,
    tipo          VARCHAR(10) NOT NULL,          -- militar | grupo | todos
    titulo        VARCHAR(120) NOT NULL,
    mensagem      TEXT NOT NULL,
    rota          VARCHAR(60),
    filtro        JSONB,                         -- os filtros usados (para reproduzir)
    agendado_para TIMESTAMP,
    status        VARCHAR(12) NOT NULL,          -- agendado | enviando | concluido | falhou | cancelado
    total_alvos   INT, com_app INT, enviados INT, falhas INT, sem_token INT,
    criado_por    VARCHAR(20) NOT NULL,
    criado_em     TIMESTAMP NOT NULL DEFAULT NOW(),
    concluido_em  TIMESTAMP
);
CREATE TABLE public.soupm_notificacao_destino (
    envio_id   BIGINT REFERENCES public.soupm_notificacao_envio(id),
    matricula  VARCHAR(20),
    resultado  VARCHAR(12),                      -- enviado | falha | sem_token
    PRIMARY KEY (envio_id, matricula)
);
CREATE TABLE public.soupm_publico_salvo (id SERIAL PRIMARY KEY, nome VARCHAR(80), filtro JSONB,
    criado_por VARCHAR(20), criado_em TIMESTAMP DEFAULT NOW());
CREATE TABLE public.soupm_notificacao_modelo (id SERIAL PRIMARY KEY, nome VARCHAR(80),
    titulo VARCHAR(120), mensagem TEXT, rota VARCHAR(60));

-- Administração
CREATE TABLE public.soupm_admin_usuario (...);   -- login, nome, hash bcrypt, 2FA, perfil, ativo
CREATE TABLE public.soupm_admin_perfil (...);    -- permissões por área
CREATE TABLE public.soupm_admin_log (id BIGSERIAL, quem VARCHAR(20), quando TIMESTAMP,
    area VARCHAR(40), acao VARCHAR(40), chave VARCHAR(120), antes JSONB, depois JSONB, ip INET);
```

Os nomes e colunas finais ficam com a sessão da intranet. O que não pode mudar:
as **chaves** dos módulos (o app depende delas) e o **contrato** da seção 9.

---

## 9. Contrato com o app: `sigrh/app_config.php`

POST com `matricula` e `senha` (MD5) quando logado; sem eles, só a parte
pública. Resposta (exemplo):

```json
{
  "code": 1,
  "versao_config": 42,
  "min_version": { "android": "2.1.5", "ios": "2.1.5",
                   "titulo": "Nova versão disponível", "texto": "Atualize para continuar." },
  "modulos": {
    "contracheques": { "estado": "bloqueado", "selo": "Manutenção",
                       "mensagem": { "titulo": "Contracheque em manutenção",
                                     "texto": "Estamos atualizando a folha de outubro.",
                                     "previsao": "2026-10-21T18:00:00-04:00",
                                     "acao": "nenhuma", "codigo": "MD-CONTRACHEQUE-MANUT" } },
    "mapa_forca":    { "estado": "ativo" },
    "escalas":       { "estado": "bloqueado", "selo": "Em breve",
                       "mensagem": { "titulo": "Em desenvolvimento",
                                     "texto": "Este recurso estará disponível em breve.",
                                     "codigo": "MD-ESCALAS-EM_BREVE" } },
    "svi":           { "estado": "oculto" }
  },
  "home": [
    { "chave": "home.anuncio", "estado": "ativo",
      "dados": { "imagem": "https://...", "tipo": "link", "destino": "https://..." } },
    { "chave": "home.comandantes", "estado": "ativo", "dados": [ { "foto": "...", "nome": "...", "cargo": "Comandante" } ] },
    { "chave": "home.dicas", "estado": "ativo", "dados": [ { "texto": "...", "icone": "lampada", "tipo": "dica" } ] },
    { "chave": "home.contracheque", "estado": "ativo" },
    { "chave": "home.tempo_servico", "estado": "ativo" },
    { "chave": "home.plano_ferias", "estado": "oculto" },
    { "chave": "home.acesso_rapido", "estado": "ativo" }
  ],
  "grid": [
    { "chave": "ficha_individual", "rotulo": "Ficha Individual", "icone": "perfil", "rota": "/page-militar" },
    { "chave": "certidoes", "rotulo": "Certidões", "icone": "certidao", "rota": "/certidoes-page" }
  ],
  "abas": [ { "chave": "aba.inicio", "rotulo": "Início" }, { "chave": "aba.perfil", "rotulo": "Perfil" } ],
  "textos": { "suporte.whatsapp": "5595991298238", "suporte.horario": "Seg–Sex, 8h–17h" }
}
```

Regras do contrato:
- **Chave desconhecida é ignorada** pelo app (permite o painel crescer antes do
  app). **Chave ausente** = padrão do app (permite o app crescer antes do
  painel).
- `home` e `grid` já vêm **filtrados e ordenados** pelo servidor.
- Ícone é sempre uma **chave** do mapa de ícones do app. Ícone novo exige versão
  nova do app; o painel só oferece as chaves que existem (lista publicada pela
  equipe do app).
- O app guarda a última resposta e a `versao_config`. Sem rede, usa a guardada.
- Tempo de resposta alvo: menos de 300 ms (uma consulta, com cache de alguns
  segundos no servidor).

---

## 10. Fases e divisão do trabalho

| Fase | Entrega | Intranet (painel) | App + API do app |
|---|---|---|---|
| **0. Fundação** | Base segura | Login admin com 2FA, perfis, log, usuário de banco do painel | Tabela `soupm_modulo` + carga inicial com todos os itens da seção 2 no estado de hoje; `app_config.php` |
| **1. Funções e home** | Liga/desliga com mensagem | Telas Funções, Tela inicial, Grid, Abas, com prévia | App 2.1.6 lê `app_config`: grid, cards, abas, bloqueio com mensagem, oculto; guarda a última config. Endpoints das funções recusam quando desligadas |
| **2. Notificações** | Um militar, grupo, todos | Telas da seção 4.2 com filtros, prévia, histórico, agendamento | `notificarGrupo`; melhorias da 4.4; app: tokens por aparelho, logout limpa (4.5) |
| **3. Conteúdo** | Anúncio, dicas, comandantes, suporte, versão mínima | Telas da seção 5, upload de imagem | Migrar do Firestore para `app_config`; app lê de lá |
| **4. Gestão** | Certidões, emissões, revogação, login | Telas da seção 6 | Endpoints de leitura/revogação |
| **5. Indicadores** | Dashboard | Painel inicial | Gravar versão do app e último acesso |

A fase 1 só vale para quem tiver a versão 2.1.6. Até lá, o app antigo continua
com o comportamento fixo de hoje. Por isso a carga inicial da fase 0 reproduz
exatamente o estado atual (Escalas e SVI "Em breve", Mapa da Força só
superuser): publicar o app novo não muda nada para o militar até alguém mexer
no painel.

**Como as sessões trabalham juntas:** a sessão da intranet faz o painel e a API
de administração; a sessão do app (este repositório) faz o `app_config.php`, a
Cloud Function `notificarGrupo` e a versão 2.1.6. O contrato da seção 9 e as
chaves da seção 2 são o ponto de encontro: mudou um dos dois, avisar a outra
sessão antes.

---

## 11. Decisões que dependem do usuário

1. **Onde fica a API de administração:** na intranet (proposta) ou em
   `sigrh/admin/`, no mesmo servidor da API do app?
2. **Login do painel:** só usuários cadastrados no painel (proposta), ou login
   pelo SIGRH com perfil de administrador?
3. **Migrar anúncio, dicas, comandantes e versão mínima do Firestore para o
   Postgres** (proposta), ou o painel editar o Firestore pelo servidor?
4. **Perfis iniciais:** quem do DTI e da DRH terá acesso, e com quais
   permissões (por exemplo, só a DRH revoga certidão; só o comando envia para
   todos).
5. **Limites de envio:** a partir de quantos destinatários exigir aprovação de
   um segundo administrador?
6. **Correções de segurança da API do app (seção 7):** abrir uma sessão própria
   para elas agora, antes do painel?

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
