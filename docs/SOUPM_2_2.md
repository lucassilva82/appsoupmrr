# SouPMRR 2.2 — replanejamento do app

> **Situação (20/10/2026): PROPOSTA, aguardando aprovação do usuário.**
> Nada deste documento está implementado. Nenhuma linha do app foi mudada,
> nenhuma branch foi criada. Depois da aprovação: branch
> `feature/soupm-2-2` e implementação pelas fases da seção 14.
>
> O protótipo navegável que acompanha este plano fica em
> `prototipos/soupm-2-2.html` (pasta fora do git) e foi publicado como
> Artifact privado. Os prints do app atual ficam em `prototipos/prints/`,
> também fora do git, porque a tela inicial mostra os comandantes (pessoas
> reais). Tudo foi gravado no modo vitrine (militar fictício SD STIVES DA
> SILVA).

## 0. Resumo

O SouPMRR ganha a **versão 2.2**: a versão mobile, resumida, da intranet da PMRR.
Esta versão **não traz módulo novo**. Ela reorganiza o app para aguentar
dezenas de módulos (SISCHAMADOS primeiro), com quatro mudanças grandes:

1. **Navegação por áreas** ("Serviços", no estilo de bancos e do gov.br) no
   lugar do grid "Acesso Rápido", e uma **tela inicial que é um resumo
   personalizável**. Comandantes continuam em destaque, numa faixa de 64 pt.
2. **Tudo vem da API** (`app_config`): menus, cards, textos, estado de cada
   função (ativa, bloqueada com motivo, oculta), perfis e versão mínima por
   plataforma. O app só desenha.
3. **Perfis e permissões calculados no servidor**, pela mesma ACL da intranet
   (`intranet.perfis` / `intranet.recursos`). Acaba o `isSuperUser` calculado
   no aparelho.
4. **Fundação técnica**: cliente HTTP único, erros com código em todo o app,
   log de ações e erros no nosso banco, sessão guardada com segurança e saída
   do Firestore (fica só o FCM).

Três novidades entram junto, porque dependem dessa fundação: **busca global**,
**feedback com anexo ligado ao SISCHAMADOS** e as **funções propostas** da
seção 11, que só entram se o usuário aprovar cada uma.

### Skills usadas neste planejamento

| Skill | Para quê |
|---|---|
| `planning-and-task-breakdown` | Fases, fatias verticais, critérios de aceite e pontos de checagem (o plano fica em `docs/`, não em `tasks/`, como manda o CLAUDE.md) |
| `ui-ux-pro-max` | Hierarquia da tela inicial, alvos de toque, estados de carregamento, vazio e erro, contraste |
| `ios-design-guidelines` | Barra de abas que não some no push, títulos grandes, gesto de voltar, folhas com alturas, hápticos |
| `ipados-design-guidelines` | Barra lateral no iPad, duas colunas, atalhos de teclado, Split View |
| `android-design-guidelines` | NavigationBar do Material 3, voltar preditivo, edge-to-edge, FAB estendido |
| `flutter-apply-architecture-best-practices` | Pastas por módulo, camadas (serviço, repositório, view model), injeção pelo Provider |

`frontend-design` e `flutter-theming-apps`, citadas no pedido, saíram do
projeto em 20/10 (APRENDIZADOS §36): a primeira é coberta pela
`ui-ux-pro-max` e a segunda pela `material-3`. A `material-3`,
`flutter-animating-apps`, `flutter-build-responsive-layout` e
`web-design-guidelines` entram na implementação (fases 2 e 6); para o plano
bastaram as diretrizes acima e o DESIGN.md, que vale mais que qualquer skill.

---

## 1. Diagnóstico do app atual (2.1.5)

### 1.1 O que se vê (prints em `prototipos/prints/`)

| Print | O que mostra | Problema |
|---|---|---|
| `01-login` | Login com vidro sobre o fundo de circuito | Bom. Marca ainda é "SOU PMRR" |
| `02-biometria` | Convite "Entrar com Touch ID?" | Num iPhone com Face ID diz Touch ID (§33) |
| `03-anuncio` | Popup de anúncio em tela cheia na abertura | Abre toda vez que o app abre; tapa a tela |
| `04-inicio-topo` | Saudação, comandantes, dica, contracheque, tempo de serviço | **Comandantes ocupam ~25% da primeira tela** (cards de 180–235 pt) |
| `05-inicio-grid` / `06` | Plano de férias e só então o "Acesso Rápido" | **O menu fica abaixo de três cards**: é preciso rolar duas telas para achar uma função. 12 itens fixos, "Sair" no meio do menu, dois "Em breve" |
| `07-perfil` | Ficha Individual | Bom. Matrícula repetida três vezes |
| `08-avisos` | Lista de notificações | Vem do Firestore |
| `09-config` | Conta, aparência, segurança | Mostra "Mat. 1001" (o que foi digitado), a ficha mostra 1234567 |
| `10-certidoes` | Lista e "Emitir nova certidão" | Padrão a seguir: textos vêm da API |
| `11-contracheques` | Anos em abas, lista por mês, "Análise Salarial" | Ao entrar numa função **a barra de abas some** (no iOS, anti-padrão da HIG) |
| `12`, `13` | Declarações, Cálculo de inatividade | Telas longas, sem busca dentro |
| (sem print) | Toque em Escalas ou SVI | Aviso curto genérico "Em desenvolvimento", sem motivo nem previsão |

### 1.2 Código (120 arquivos Dart, ~47 mil linhas)

- **Tudo dentro de `pages/`.** 40 telas com rede, regra e desenho no mesmo
  arquivo. As maiores: `calculo_inatividade_page.dart` (2.025 linhas),
  `escala_page.dart` (1.933), `page_contracheque.dart` (1.784),
  `certidoes_page.dart` (1.456).
- **Duplicatas:** `plano_de_ferias.dart` e `planodeferias.dart`,
  `pdf_view_page.dart` e `Pdf_Viewer_Page.dart`, `contracheque.dart` e
  `page_contracheque.dart`, `utils/store.dart` e `data/store.dart`. Pastas
  legadas: `components/`, `data/`, `view/`, `animation/`.
- **Sem cliente HTTP central.** Três classes (`api_services.dart`,
  `dados_sql.dart`, `escala_service.dart`) e chamadas `http.get` soltas em
  mais de dez telas. Timeouts de 4 a 30 s, vários sem nenhum. Algumas passam
  matrícula e e-mail na URL (GET).
- **Erros:** só o login (`LG-`) e o card de tempo de serviço (`TS-IPER-`) têm
  código. O resto cai em `catch (error)` genérico.
- **Nenhum log remoto.** Só `print`/`debugPrint`. Sem Crashlytics. A regra
  "Tudo tem log" (CLAUDE.md) ainda não tem implementação.
- **Perfil no aparelho.** `isSuperUser` = nível 1, ou `idPosto < 8` (exceto
  nível 10), calculado em `auth_model.dart`. Essa regra **não existe na
  intranet**. A tela do Mapa da Força não confere nada: só o menu esconde a
  entrada.
- **Navegação:** rotas nomeadas num mapa em `main.dart`, `switch` por id no
  grid, `MainShell` com `IndexedStack` de 4 abas. As telas internas são
  empilhadas no navegador raiz, por isso a barra de abas some.
- **Tela inicial fixa** em `home_page.dart`. No Android, o `initState` pede
  permissão de armazenamento (`manageExternalStorage`) na abertura.

### 1.3 Segurança (somando o PAINEL_ADMIN §7)

| Achado | Gravidade | Onde |
|---|---|---|
| **Senha guardada em texto puro** no SharedPreferences (`userData`) | Alta | `auth_model.dart` (`saveUserData`) |
| MD5 da senha como credencial de todos os endpoints | Alta | API (§30) |
| Endpoints que não conferem quem pede e consultas montadas com texto (nomes na lista privada da API, fora do repositório) | Alta | API, PAINEL_ADMIN §7 |
| Mapa da Força e ficha de outro militar: acesso decidido só no aparelho; a tela e os endpoints não conferem quem pede nem limitam ao escopo dele (revisão de 21/10/2026; detalhes fora do repositório, com a sessão de segurança) | Alta | `mapa_da_forca.dart`, `militar_detalhe_full_page.dart` e a API |
| Regra de "gestor" errada: `idPosto < 8` são os oficiais de Coronel a Aspirante. Ficam de fora Subtenente, cadetes e praças que comandam; e todo oficial vira gestor, mesmo sem função de comando | Média | `auth_model.dart` |
| Firestore sem regras no repositório e sem Firebase Auth | Média | console Firebase |
| `notificarEscala` sem autenticação | Média | `functions/` |
| Matrícula e e-mail em query string | Baixa | API (lista privada) |

As correções da API continuam numa sessão própria (PAINEL_ADMIN §11, item 6).
O que é do app (senha em texto puro, checagem na tela) entra na fase 0.

### 1.4 O que a intranet já tem e o app vai usar

Levantado em `~/code/intranet` (só leitura):

- **ACL moderna:** `intranet.modulos` → `intranet.perfis` (por módulo) →
  `intranet.usuarios_perfis` (matrícula, perfil, ativo, data_fim);
  `intranet.recursos` (`modulo.entidade.acao`) → `intranet.perfis_recursos`.
  Funções `usuarioTemPermissao()`, `require_access()`. Escopo por
  TODAS / COMANDO / UNIDADE / SUBUNIDADE, com a lotação lida do SIGRH.
- **API JSON da intranet** (`/api/v1/`, JWT com renovação, 2FA
  opcional, migração de MD5 para hash forte no primeiro login). O login
  devolve os **perfis** do usuário. Já tem rotas de escala, SVI, certidões,
  férias, perfil, agenda, legislação, POP e dispositivo (push).
- **SISCHAMADOS** (schema `sccti`): escada de papéis 1 Solicitante,
  2 Técnico, 3 Supervisor, 4 Chefe do DTI, 5 Administrador; 14 estados;
  catálogo (tipos, categorias, subcategorias, campos dinâmicos); anexos de até
  25 MB conferidos pelo conteúdo; **API própria** `/sischamados/api/v1` com
  chave do aplicativo + token da pessoa: sessão, catálogo, abrir chamado com
  anexo, listar, detalhar, notificações. Ainda não há rotas de técnico.
- **Notificações dos módulos** em `intranet.notificacoes`, com catálogo de
  códigos já pensado para o SouPM.

Consequência para o plano: o app **não precisa inventar** perfis, sessão nem
abertura de chamado. Precisa de um lugar único onde juntar isso
(`app_config`) e de uma camada no app que fale com as duas APIs.

---

## 2. Princípios da 2.2

1. **O app desenha, a API decide, o banco guarda** (APRENDIZADOS §28).
2. **Toda função tem uma chave estável** (`rh.contracheques`), que é a mesma no
   menu, na busca, no push, no log, no painel e na ACL.
3. **Cada módulo é uma pasta** que se registra sozinho. Módulo novo da
   intranet = pasta nova + linha no banco, sem mexer no menu, na busca nem no
   roteador.
4. **Nada quebra versão antiga:** campo novo é opcional, chave desconhecida é
   ignorada, chave ausente usa o padrão do app.
5. **Erro sempre explicado, tudo com log** (CLAUDE.md).
6. **Tudo o que entra no app entra no painel** (CLAUDE.md): função, tela,
   card, módulo, serviço ou API nova só está pronta quando tem chave em
   `soupm_menu_item`, eventos no catálogo, códigos de erro em `soupm_config`
   (`erros`), ponto no mapa de conexões se fala com um sistema novo
   (`soupm_servico`, com sonda), lugar na Agenda se tem data, e tipo de
   pendência (desligado) se cobra algo do militar. Detalhe no PAINEL_ADMIN §1.4.
7. **Documento é da API, e o padrão dele é do painel** (CLAUDE.md, decisão do
   usuário de 21/10/2026): contracheque, declarações e todo documento futuro
   seguem o modelo das certidões. A API confere os dados, monta o PDF e devolve
   com hash; o padrão (títulos, rubricas visíveis, ordem, textos, rodapé, marca
   d'água, liga/desliga, mensagens de erro com código) fica no banco e é
   editado pelo painel. O app só pede, mostra, guarda e compartilha (seção 12.3).
8. **Cada plataforma no seu padrão**, com a identidade do DESIGN.md.

---

## 3. Nova navegação

### 3.1 Esqueleto

| Abas (iPhone e Android) | Para quê |
|---|---|
| **Início** | Resumo personalizável (seção 4) |
| **Serviços** | Todas as funções, por áreas e submenus |
| **Avisos** | Notificações e comunicados (com contador) |
| **Perfil** | Ficha, conta, segurança, aparência, ajuda e feedback, sair |

- **Busca** (lupa) no topo das quatro abas e dentro de Serviços como campo
  fixo. No iPad, também `⌘F`.
- **Sair** sai do menu de funções e vai para o fim de Perfil, com confirmação.
- **Configurações** deixa de ser aba: vira seções de Perfil (como bancos e
  gov.br fazem). Libera a aba para Serviços sem passar de 4.
- **A barra de abas não some** ao abrir uma função: cada aba tem o próprio
  navegador (iOS: exigência da HIG; Android: padrão do Material 3).
- **Voltar sempre volta para onde o militar estava:** uma função aberta a partir
  de Avisos, de um comunicado ou de uma pendência abre **dentro da aba atual**,
  e voltar retorna a ela. Push com o app fechado abre a função sobre a aba
  Início (voltar leva à Início); com o app aberto, abre sobre a aba em que ele
  está. No Android, voltar na raiz de uma aba que não é a Início leva à Início
  antes de sair do app.
- **Avisos, Comunicados e Suas pendências** têm papéis diferentes, ditos numa
  linha no topo de cada tela: **Avisos** são mensagens do SouPMRR para você (ex.:
  contracheque disponível, resposta da equipe); **Comunicados** são publicações
  oficiais do Comando e das diretorias para a tropa; **Suas pendências** são o
  que falta você fazer em algum sistema.
- **iPad e Android largo (≥ 840 pt):** barra lateral com as abas e as áreas de
  Serviços, conteúdo à direita (duas colunas). Entre 600 e 840: trilho de
  navegação (Android) / barra lateral recolhível (iPad).

### 3.2 Árvore de menus (com as chaves)

`área` agrupa; `função` abre tela; `ação` é uma coisa dentro da função. A
coluna "Hoje" usa as chaves do PAINEL_ADMIN §2.

```
servicos
├── rh                        Minha vida funcional
│   ├── rh.ficha              Ficha Individual            (hoje: ficha_individual)
│   │   ├── rh.ficha.contato     · telefones
│   │   └── rh.ficha.endereco    · endereço
│   ├── rh.contracheques      Contracheques               (contracheques)
│   │   ├── rh.contracheques.grafico · análise salarial
│   │   └── rh.contracheques.mudou   · o que mudou no mês   NOVO (P1)
│   ├── rh.ferias             Plano de férias             (plano_ferias)
│   ├── rh.tempo_servico      Tempo de serviço e inatividade (calculo_inatividade)
│   ├── rh.certidoes          Certidões                   (certidoes)
│   ├── rh.documentos         Central de documentos       NOVO (P4)
│   ├── rh.carreira           Linha do tempo da carreira  NOVO (P5)
│   ├── rh.validar            Validar documento (QR)      NOVO (P6)
│   └── rh.declaracoes        Declarações anuais          (declaracoes)
│       ├── rh.declaracoes.bens
│       ├── rh.declaracoes.irpf
│       ├── rh.declaracoes.parentesco
│       └── rh.declaracoes.acumulo
├── operacional               Serviço operacional
│   ├── op.escalas            Minhas escalas              (escalas)        hoje "Em breve"
│   └── op.svi                Serviço voluntário (SVI)    (svi)            hoje "Em breve"
│       (op.plantao "Meu plantão" fica OCULTO: o plantão passa a ser parte de Minhas escalas;
│        push antigo para /plantao abre op.escalas)
├── normas                    Normas e procedimentos
│   ├── normas.legislacoes    Legislações                 (legislacoes)
│   └── normas.pops           POPs                        (pops)
├── gestao                    Gestão (nível 2 em diante, seção 6)
│   ├── gestao.mapa_forca     Mapa da Força               (mapa_forca)
│   ├── gestao.boletins       Boletins                    futuro
│   └── gestao.patrimonio     Patrimônio e frota          futuro
├── atendimento               Atendimento DTI
│   ├── atend.chamados        Meus chamados (SISCHAMADOS: só abrir e acompanhar)
│   └── atend.feedback        Sugestões e problemas       NOVO nesta versão
└── institucional             Institucional
    ├── com.central           Comunicados                 NOVO (seção 4.2)
    └── inst.noticias         Notícias e agenda           NOVO (P7)

inicio                        Tela inicial (ordem padrão)
├── home.comandantes          faixa compacta, abre o Comando  (home.comandantes)
├── home.anuncio              central de comunicados (carrossel) (home.anuncio)
├── home.dicas                uma linha                   (home.dicas)
├── home.pendencias           "Suas pendências"           NOVO
├── home.atalhos              favoritos, 2 linhas de 4    NOVO
├── home.contracheque         card                        (home.contracheque)
├── home.tempo_servico        card                        (home.tempo_servico)
└── home.ferias               card                        (home.plano_ferias)
com.central                   Comunicados (lista completa) NOVO
pend.lista                    Suas pendências (lista completa) NOVO

avisos                        (avisos)
perfil
├── perfil.ficha              atalho para rh.ficha
├── conta.email               (config.email)
├── conta.senha               (config.alterar_senha)
├── seg.biometria             (config.biometria)
├── apar.tema                 (config.tema)
├── notif.preferencias        (config.notificacoes)
├── ajuda                     (ajuda)
├── atend.feedback            atalho
└── sair                      não desligável

login                         (login.primeiro_acesso, login.recuperar_senha)
busca                         NOVO
```

**Regras da árvore**

- As chaves antigas (`contracheques`, `plano_ferias`…) continuam aceitas pela
  API como **apelido** da chave nova durante a 2.2, para o painel e as
  versões antigas não quebrarem. A tabela de apelidos fica no
  `app_config.php`.
- Área sem nenhuma função visível para aquele militar **some sozinha**.
- Área com uma só função visível abre a função direto.
- Cada nó tem, no banco: `rotulo`, `descricao` (uma linha, aparece no menu e
  na busca), `icone` (chave), `ordem`, `sinonimos`, `palavras_chave`,
  `estado`, `publico`, `versao_min_app`.

### 3.3 Como é a tela Serviços

- Campo de busca fixo no topo.
- **Áreas como cartões** (`CartaoVidro`, raio 16), cada um com ícone, título,
  uma linha de descrição e as 3–4 funções mais usadas daquela área como
  linhas tocáveis (44 pt). "Ver tudo" abre a área.
- Dentro da área: lista agrupada (iOS: *inset grouped*; Android: `ListItem`),
  com selo de estado à direita ("Em breve", "Manutenção", "Proposta").
- Tocar numa função bloqueada abre a **folha de bloqueio** (seção 5.2), nunca
  um aviso genérico.
- **Manutenção automática** (pelo painel): quando a sonda mede um serviço fora
  do ar, o painel oferece pôr as funções que dependem dele em manutenção; se
  marcado "volta sozinha", a função volta quando o serviço passar 10 minutos
  normal. Para o app, é só o estado bloqueado com motivo manutenção.

---

## 4. Nova tela inicial

Ordem padrão, de cima para baixo (todos os blocos são `home.*` no
`app_config`; o painel liga, desliga e reordena):

1. **Barra do topo:** "Bom dia, SD STIVES", lupa e sino com contador.
2. **Faixa do Comando** (`home.comandantes`, seção 4.1).
3. **Comunicados** (`home.anuncio`, seção 4.2): carrossel da central de
   comunicados oficiais.
4. **Dica** (`home.dicas`): uma linha discreta, com ícone (sem emoji, §8).
5. **Suas pendências** (`home.pendencias`, seção 4.3): só aparece quando há
   algo.
6. **Atalhos** (`home.atalhos`, seção 4.4): duas linhas de quatro.
7. **Cards de dado** (contracheque, tempo de serviço, férias), na gramática do
   DESIGN §2b.

O militar esconde e reordena os blocos que o painel deixar (seção 4.5);
comandantes, comunicados e pendências são fixos por padrão.

### 4.1 Faixa do Comando

- Uma linha de 64 pt com **dois botões independentes**, o Comandante-Geral e
  o Subcomandante-Geral, cada um com foto redonda (40 pt), posto e cargo. Hoje
  são cards de até 235 pt: cai para ~27% do espaço. Os Comunicados vêm logo
  abaixo, quase encostados.
- **Sem seta.** Tocar num deles faz **só aquele** se expandir num cartão por
  cima da tela (*container transform*, 400 ms, `easeOutCubic`; no Flutter,
  `OpenContainer` do pacote `animations` ou uma rota com `Hero` na foto). Fechar
  faz o caminho de volta até o botão de onde saiu.
- O cartão mostra: foto grande (112 pt, aro dourado), cargo, posto, **nome
  completo**, mensagem à tropa (se houver) e uma lista com quadro, no cargo
  desde, na PMRR desde, lotação e cursos. No iPad, o cartão abre centralizado.

**De onde vêm os dados (decisão do usuário, 21/10/2026):** do **SIGRH**, o
máximo possível, com aprovação no painel antes de aparecer no app.

1. O painel consulta no SIGRH quem ocupa as funções de Comandante-Geral e
   Subcomandante-Geral e traz nome completo, posto, quadro, data de
   inclusão, data de assunção da função, lotação, cursos e foto.
2. Quando o SIGRH muda (troca de comando, promoção, foto nova), o painel mostra
   **"Mudança no SIGRH aguardando aprovação"**, com o antes e o depois.
3. O administrador **aprova** (e pode ajustar foto, texto da mensagem, ordem ou
   esconder um campo). Só então o app passa a mostrar. Nada vai para o app
   sozinho.
4. Campos que o SIGRH não tem (mensagem à tropa, foto oficial diferente) são
   escritos no painel e ficam guardados junto da aprovação.
5. Toda aprovação fica na auditoria da intranet.

Desenho no painel (PAINEL_ADMIN §5.3 e §8): tabela `soupm_comando`, uma linha
por cargo, com o aprovado (a única parte que o `app_config` lê), a cópia atual
do SIGRH e a marca de pendente; conferência diária e botão "Conferir no SIGRH";
Aprovar, Recusar ou Depois. No `app_config`, `home.comandantes.dados[]` traz
cargo, quadro, desde, inclusao, lotacao, `cursos[]` e mensagem, todos
opcionais e já sem os campos que o administrador escondeu.

### 4.2 Central de comunicados

Comunicados oficiais para a tropa, todos geridos pelo painel. Substitui o
"anúncio" único de hoje (`appConfig/anuncio`) por uma central.

**Na tela inicial: carrossel**

- Cartões de 264 pt, ocupando 86% da largura, com o próximo aparecendo na
  borda (o dedo entende que dá para deslizar). Desenho na "Anatomia do
  cartão", abaixo.
- Passa sozinho a cada 6,5 s; a pílula do ponto ativo se enche nesse tempo.
- **Pontos do carrossel com área de toque de 44 pt** (o desenho continua
  pequeno); pelo leitor de tela, o carrossel é um controle ajustável ("deslize
  para cima ou para baixo para trocar"). Depois que o militar desliza à mão, o
  tempo do próximo recomeça do zero.
- **Controle do militar:** botão de pausar/continuar (exigência de
  acessibilidade para conteúdo que se move sozinho), pausa ao tocar e segurar,
  ao focar com leitor de tela e com "Reduzir movimento" ligado (aí não passa
  sozinho). Deslizar troca à mão. "Ver todos" abre a central.
- Contador "3 novos" no título do bloco.
- **Sem nenhum comunicado no ar** (para aquele militar), o bloco **some** e os
  blocos de baixo sobem. Diferente de Suas pendências, que continua com "Sem
  pendências" (decisão do usuário, 21/10/2026).

**Anatomia do cartão (padrão aprovado em 20/10/2026, a partir da referência
do usuário):**

- Fundo de vidro **tingido pela cor da categoria** (cada categoria tem uma cor
  no painel), com um brilho no canto superior direito e borda fina da mesma
  cor. No tema claro, o mesmo tom bem mais suave, com texto escuro.
- Linha de cima: ícone da categoria em contorno, um traço vertical e o nome da
  categoria em caixa alta espaçada; selo "Novo" quando não lido.
- **Título grande** (24 pt, negrito, até 2 linhas) e **resumo** (14 pt, até 2
  linhas) na coluna da esquerda (66% da largura).
- À direita, **ilustração de vidro**: duas folhas inclinadas com o ícone do
  assunto, sobre um anel de luz; flutua de leve no cartão ativo.
- Pílulas de informação: data ou prazo (ícone de calendário) e, se houver,
  "Ciência pendente" (âmbar) ou "Urgente" (vermelho).
- Rodapé separado por um fio: origem · data ("Comando-Geral · 20 out") e o
  botão redondo com seta.
- Embaixo do carrossel: botão de pausa, **pontos com a pílula do ativo**
  (que se enche durante os 6,5 s) e o contador "01 / 06".
- Cabeçalho do bloco: "Comunicados" grande, pílula "2 novos" e "Ver todos ›".
  As outras seções da Início (Suas pendências, Atalhos) usam o mesmo
  cabeçalho.
- **Limites para o painel** (para o cartão não cortar): título até 30
  caracteres, resumo até 70, texto da pílula até 16. O painel mostra a prévia
  do cartão enquanto se escreve.

**Ao tocar num cartão:** ele se expande até virar a tela do comunicado (o
mesmo *container transform* da faixa do Comando): arte no topo, título,
origem ("Comando-Geral", "Diretoria de Saúde"…), data e o texto completo.
**Urgente e ciência são coisas separadas:** um comunicado pode ser urgente e
não pedir confirmação, ou pedir ciência sem ser urgente. Só quando o painel
marca **ciência obrigatória** aparece "Estou ciente"; a
ciência fica gravada com matrícula, data e hora (e gera evento no log), e a
pendência correspondente some (seção 4.3).

**Na abertura do app:** o comunicado marcado como **destaque de abertura**
aparece por cima, como hoje. Ao fechar, ele **encolhe até o seu cartão no
carrossel**, para o militar entender onde ele ficou guardado. Aparece uma vez
por comunicado (não a cada abertura), salvo se o painel pedir "mostrar até dar
ciência".

**Central (`com.central`):** lista completa, com filtros Todos / Não lidos /
Ciência pendente, miniatura, categoria e situação. Também acha pela busca
("comunicado", "aviso oficial", "informe").

**O painel controla, por comunicado:** título, resumo, texto, imagem ou arte,
categoria, origem, público (os mesmos filtros de notificação do PAINEL §4.3),
início e fim da exibição, ordem, urgente, destaque de abertura, ciência
obrigatória (com prazo), e se manda push junto. Relatório de quem leu e de quem
deu ciência, por unidade.

### 4.3 Suas pendências

O que falta o militar fazer, vindo de **qualquer sistema** da PMRR. Nome
formal, à altura de uma instituição militar.

- **Sem nada pendente**, o bloco continua lá com "Sem pendências" (o militar
  sabe que foi conferido, em vez de achar que o bloco sumiu). **Enquanto
  nenhum tipo estiver ligado no painel** (como no começo, com todos
  desligados), o bloco não aparece: "Sem pendências" seria uma afirmação que
  ninguém conferiu.
- **Destino da pendência:** cada tipo aponta para uma função que resolve. Se
  essa função estiver oculta ou bloqueada para o militar, a pendência aparece
  com o texto e o código, sem botão, em vez de abrir uma tela vazia.
- **Na tela inicial:** até 3 itens, com contador, e "Ver todas". Cada item diz
  o quê, o prazo, o sistema de origem e se é **Obrigatória** (vermelho) ou
  **Lembrete** (azul). Tocar leva direto à função que resolve.
- **Lista completa (`pend.lista`):** obrigatórias primeiro, depois lembretes.
  Lembrete pode ser dispensado pelo militar ("volta se o prazo ficar perto");
  obrigatória só sai quando for resolvida.
- **Cada sistema informa as suas.** Um **tipo de pendência** é cadastrado no
  painel e aponta para quem a calcula. Exemplos de hoje e de amanhã:

  | Tipo | Sistema | Quem calcula |
  |---|---|---|
  **Declarações abrem por campanha** (decisão do usuário, 21/10/2026): ficam
  **fechadas por padrão**, como a declaração do imposto de renda. O painel abre
  a campanha de um ano específico, com prazo; fora dela, o app e a API recusam o
  envio e explicam o motivo (`DC-FECHADA`), e as pendências `sigrh.declaracao_*`
  só existem com campanha aberta.

  | `sigrh.declaracao_bens` | SIGRH | a mesma regra de `buscastatusdeclaracoes.php` |
  | `sigrh.declaracao_parentesco`, `sigrh.declaracao_acumulo` | SIGRH | idem |
  | `comando.ciencia_comunicado` | SouPM | comunicado com ciência obrigatória e sem ciência |
  | `soupm.certidao_vencendo` | SouPM | certidão emitida que vence em menos de N dias |
  | `sischamados.aguardando_solicitante` | SISCHAMADOS | chamado no estado 9 |
  | `sige.escala_sem_ciencia` | SIGE | escala publicada sem ciência (quando as escalas entrarem) |
  | `cursos.matricula_pendente`, `patrimonio.termo_pendente`… | futuros módulos | a API de cada um |

- **Catálogo de tipos (todos começam desligados).** Decisão do usuário
  (21/10/2026): o painel lista todos os 37 tipos, **desligados**, e o
  administrador liga um a um quando quiser. Módulos novos registram tipos
  novos no mesmo catálogo. Na coluna "Quando": **"a homologar na 2.2"** quer dizer
  que a fonte provavelmente existe, mas ainda precisa ser conferida no banco
  (tabela, coluna, regra) antes de ligar; "futuro" depende do módulo chegar ao
  app. No painel, cada tipo tem `fonte_status` (confirmada, a homologar,
  futura) e **só um tipo com fonte confirmada pode ser ligado** (revisão de
  21/10/2026).

  | Chave | Sistema | O que cobra | Sugestão de padrão | Quando |
  |---|---|---|---|---|
  | `sigrh.declaracao_bens` | SIGRH | declaração anual de bens não enviada | obrigatória | a homologar na 2.2 |
  | `sigrh.declaracao_irpf` | SIGRH | PDF do IRPF do ano não enviado | obrigatória | a homologar na 2.2 |
  | `sigrh.declaracao_parentesco` | SIGRH | declaração de parentesco não enviada | obrigatória | a homologar na 2.2 |
  | `sigrh.declaracao_acumulo` | SIGRH | declaração de acúmulo de cargos não enviada | obrigatória | a homologar na 2.2 |
  | `sigrh.cadastro_desatualizado` | SIGRH | endereço, telefone ou dependentes sem atualização há N meses | lembrete | a homologar na 2.2 |
  | `sigrh.recadastramento` | SIGRH | recadastramento anual (inativos, pensionistas) | obrigatória | a homologar na 2.2, se a DRH usar |
  | `sigrh.ferias_escolher` | SIGRH | plano de férias sem escolha no prazo | obrigatória | quando a escolha estiver no SIGRH |
  | `sigrh.documento_entregar` | SIGRH / DRH | documento pedido pela DRH e não entregue | obrigatória | futuro |
  | `soupm.email_nao_confirmado` | SouPMRR | e-mail não cadastrado ou não confirmado (recuperação de senha e certidões) | lembrete | a homologar na 2.2 |
  | `soupm.ciencia_comunicado` | SouPMRR | comunicado com ciência obrigatória e sem ciência | obrigatória | a homologar na 2.2 |
  | `soupm.certidao_vencendo` | SouPMRR | certidão emitida que vence em menos de N dias | lembrete | a homologar na 2.2 |
  | `soupm.feedback_resposta` | SouPMRR | a equipe respondeu e pediu mais informação | lembrete | a homologar na 2.2 |
  | `soupm.app_desatualizado` | SouPMRR | versão abaixo da recomendada para a plataforma | lembrete | a homologar na 2.2 |
  | `sige.escala_sem_ciencia` | SIGE | escala publicada sem ciência | obrigatória | com Minhas escalas |
  | `sige.impossibilidade_resposta` | SIGE | pedido de impossibilidade aguardando o militar | lembrete | com Minhas escalas |
  | `sige.permuta_aceitar` | SIGE | permuta proposta por outro militar aguardando aceite | lembrete | com Minhas escalas |
  | `svi.termo_assinar` | SVI | termo de adesão novo para assinar | obrigatória | com o SVI |
  | `svi.confirmar_servico` | SVI | escala de SVI aguardando confirmação | lembrete | com o SVI |
  | `sischamados.aguardando_solicitante` | SISCHAMADOS | chamado esperando resposta do militar (estado 9) | lembrete | a homologar na 2.2 |
  | `sischamados.avaliar` | SISCHAMADOS | chamado resolvido e não avaliado | lembrete | a homologar na 2.2 |
  | `boletim.mencao_ciencia` | Boletim | publicação em boletim que cita o militar e pede ciência | obrigatória | com Boletins |
  | `patrimonio.cautela_assinar` | Patrimônio | termo de cautela ou responsabilidade para assinar | obrigatória | com Patrimônio |
  | `patrimonio.devolucao_vencida` | Patrimônio | material cautelado com devolução vencida | obrigatória | com Patrimônio |
  | `cursos.matricula_confirmar` | Cursos | matrícula em curso aguardando confirmação | obrigatória | futuro |
  | `cursos.atividade_pendente` | Cursos | atividade ou avaliação de curso em atraso | lembrete | futuro |
  | `saude.inspecao_periodica` | Saúde | inspeção de saúde periódica vencida | obrigatória | futuro |
  | `instrucao.taf_agendar` | Instrução | teste de aptidão física a agendar ou realizar | obrigatória | futuro |
  | `gestao.tropa_declaracoes` | Gestão (nível 2+) | militares do escopo com declaração pendente | lembrete | a homologar na 2.2 |
  | `gestao.tropa_ciencia` | Gestão (nível 2+) | militares do escopo sem ciência de comunicado obrigatório | lembrete | a homologar na 2.2 |
  | `gestao.aprovar_pedidos` | Gestão (nível 2+) | férias, permutas ou impossibilidades da tropa aguardando o gestor | obrigatória | com Minhas escalas |
  | `sigrh.ferias_inicio` | SIGRH | as férias começam em N dias (lembrete de apresentação e retorno) | lembrete | a homologar na 2.2 |
  | `soupm.senha_antiga` | SouPMRR | senha sem troca há muito tempo ou ainda no formato antigo | lembrete (obrigatória na 2.3) | a homologar na 2.2 |
  | `soupm.biometria` | SouPMRR | biometria ainda não ligada neste aparelho | lembrete | a homologar na 2.2 |
  | `svi.adesao_aberta` | SVI | período de adesão ao SVI aberto | lembrete | com o SVI |
  | `sige.falta_justificar` | SIGE | falta ou ausência na escala sem justificativa | obrigatória | com Minhas escalas |
  | `patrimonio.vistoria_viatura` | Patrimônio | vistoria da viatura sob responsabilidade vencida | obrigatória | com Patrimônio |
  | `gestao.mapa_forca_conferir` | Gestão (nível 2+) | conferir a situação do efetivo do escopo no Mapa da Força (por exemplo, todo dia 1º) | lembrete | a homologar na 2.2 |

- **O painel controla, por tipo:** ligado ou desligado (ex.: **cobrar ou não a
  declaração de bens neste ano**), obrigatória ou lembrete, prazo e com quantos
  dias de antecedência começa a aparecer, público (perfil, posto, unidade,
  matrículas), texto, ícone, prioridade na ordem, se pode ser dispensada, se
  manda push (e quando) e o período de cobrança (início e fim).
- **Como o app recebe:** `pendencias.php` junta os tipos ligados para aquele
  militar e devolve a lista já filtrada e ordenada (seção 12). Um tipo cujo
  sistema não respondeu **não some em silêncio**: o item vira "Não foi possível
  conferir [sistema]" com código `PD-<SISTEMA>-<falha>` (regra do §27 do
  APRENDIZADOS: "não consegui consultar" não é "não existe").
- **Módulo novo da intranet** que quiser cobrar algo só precisa expor um
  endpoint de pendências no formato comum e ser cadastrado como tipo no
  painel. O app não muda.

### 4.4 Atalhos

Duas linhas de quatro (8 atalhos), escolhidos pelo militar em "Editar". O
padrão vem do painel por perfil (para o militar: Contracheques, Certidões,
Férias, Minha ficha, Tempo de serviço, Declarações, Legislações, Sugestões; o
gestor troca um deles pelo Mapa da Força). Função sem acesso ou oculta some
do atalho sozinha.

### 4.5 Personalizar o início

No lugar da lista com setas, a tela inicial **entra em modo de edição** (como
os widgets do iPhone e do Android):

- "Personalizar início" (no fim da tela ou em Perfil › Aparência) deixa os
  blocos com contorno e uma alça; no iOS eles tremem de leve, no Android ficam
  elevados (cada um no padrão da plataforma).
- **Arrastar pela alça** muda a ordem, com háptico e um espaço reservado onde
  o bloco vai cair; a tela rola sozinha perto das bordas. Pelo teclado ou
  leitor de tela, a alça aceita "subir" e "descer".
- **Esconder:** botão vermelho no canto do bloco. Os escondidos vão para a
  bandeja "Escondidos", no fim, de onde voltam com um toque.
- **Fixos pelo painel** (Comando, Comunicados, Suas pendências) mostram um
  cadeado e não podem ser escondidos.
- **Atalhos se editam no lugar:** "−" em cada ícone para tirar e "+ Adicionar"
  abre a escolha, com busca. Limite de 8.
- "Restaurar o padrão da PMRR" e "Concluído" no topo. Salva no aparelho e na
  API.
- O carrossel de comunicados para de passar enquanto a tela está em edição.
- **Quando o painel muda os blocos**, a escolha do militar é preservada: bloco
  novo entra na posição que o painel definiu; bloco desligado some e, se voltar,
  volta para onde estava; o que o militar escondeu continua escondido. Atalho de
  função que ficou oculta ou bloqueada some do atalho e volta sozinho quando a
  função voltar.

### 4.6 Blocos e cards criados no painel

**Todo bloco da Início pode ser desligado no painel**, inclusive os que o
militar não pode esconder (Comando, Comunicados, Suas pendências). Desligado,
ele **some** para todos (ou só para o público escolhido) e o que está abaixo
sobe. "Fixo" quer dizer só que o militar não pode esconder.

**Cards novos sem versão nova do app** (decisão do usuário, 21/10/2026): o
administrador cria cards no painel e eles aparecem para os militares do
público na próxima leitura do `app_config` (abertura, volta depois de 5
minutos, puxar para atualizar). Para valer **o quanto antes**, o painel manda junto
um push silencioso só de dados (`{"tipo":"config","versao_config":N}`), e o
app aberto relê o `app_config` sem mostrar nada. O push silencioso é uma
**tentativa, não garantia** (o iOS limita esse tipo de push): o que garante é
a revalidação da seção 5.3. Texto do painel: "Vale em segundos para quem está
com o app aberto e na próxima abertura para os demais". Modelo de card desconhecido é
ignorado pelo app (versão antiga não quebra). Formato no `app_config`: blocos
`home.livre.<chave>` com `modelo`, `dados`, `acao`, `escondivel` e `marca`
(PAINEL_ADMIN §9.1).

O app tem alguns **modelos** prontos, e o painel só preenche:

| Modelo | Para quê | Campos no painel |
|---|---|---|
| **Campanha** | campanha, evento, aviso visual (ex.: Outubro Rosa) | selo, título, texto, cor, marca d'água ou imagem de fundo, botão |
| **Atalho grande** | levar a uma função do app com destaque | título, texto, ícone, função de destino |
| **Número** | um dado de uma fonte do catálogo `soupm_fonte_dados` (ex.: "3 escalas este mês") | título, fonte do número, texto de apoio, destino |
| **Lista curta** | até 3 linhas com links (ex.: documentos do curso) | título, linhas (texto + destino) |

Em todos: público (nível, unidade, posto, matrículas), período de exibição,
ordem, se o militar pode esconder, e o botão de ação (abrir uma função do app,
um comunicado, um link externo ou o WhatsApp do suporte). O painel mostra a
**prévia do card** nos temas claro e escuro, no iPhone e no Android, antes de
publicar. Modelo novo, de desenho diferente, aí sim exige versão do app.

**Nada foge do padrão do app** (decisão do usuário, 21/10/2026), e entra na
2.2: o painel monta os cards a partir de um **catálogo de ícones** (a família
Material Symbols levada inteira no app, escolhida pelo nome), de um **catálogo
de imagens** aprovadas, da **paleta fechada** do DESIGN.md (sem cor livre) com
conferência de contraste antes de publicar, e de um **catálogo de fontes de
dados** (`soupm_fonte_dados`: endereço, método, autenticação guardada só no
servidor, campo da resposta, cache, tempo limite, prefixo de erro), usado pelo
modelo "Número" e pelas pendências.

**Marca d'água em todo card** (DESIGN §2c, que volta a valer na 2.2): todo
card de resumo tem o desenho grande, inclinado e quase apagado no canto. Já
existem cédula (contracheque), medalha (tempo de serviço) e calendário
(férias); entram prancheta (Suas pendências), grade (Atalhos), lâmpada (Dica)
e laço, escudo, viatura, livro, cruz da saúde (cards do painel). O painel
escolhe o desenho de cada bloco num catálogo (chave, como os ícones) ou envia
uma imagem de fundo; com imagem, o app põe um véu por cima para o texto
continuar legível (4,5:1). Os tons seguem o `_Tons` do
`marca_dagua_cartao.dart`, iguais em todos os cards.

---

## 5. Configuração pelo painel (`app_config`)

O contrato completo está no PAINEL_ADMIN §9 (atualizado para a árvore).
Resumo do que muda em relação ao plano anterior:

### 5.1 O que vem do servidor

- `menu`: a árvore da seção 3.2, **já filtrada pelo perfil e ordenada**.
- `home`: os blocos da seção 4, com os dados (comandantes, comunicado, dicas,
  pendências).
- `modulos`: estado de cada chave (`ativo`, `bloqueado`, `oculto`) com a
  mensagem.
- `busca`: sinônimos e palavras-chave de cada chave (vem junto do menu).
- `versao`: mínima e recomendada **por plataforma** (seção 10).
- `textos`: os textos de tela que hoje estão fixos.
- Campos novos propostos pelo painel (PAINEL_ADMIN §9.1), todos opcionais:
  `categorias_comunicado` (nome, cor e ícone de cada categoria), `pilula` e
  `versao` em cada comunicado, e o bloco `ajuda` (WhatsApp, horário, e-mail,
  perguntas frequentes).
- `perfis`: os perfis do militar (para o app mostrar o selo do nível e
  dos papéis; nunca para decidir acesso).

### 5.2 Estados e mensagens

Os três estados e os motivos do PAINEL_ADMIN §3 continuam. O que a 2.2
acrescenta é o **desenho único** do bloqueio:

- No menu e na busca: item a 45% de opacidade com selo curto.
- Ao tocar: **folha** (iOS: *sheet* de altura média; Android: *bottom sheet*
  com alça) com ícone do motivo, título, texto, previsão de volta, botão da
  ação (Avisar quando voltar, Falar com o suporte, Atualizar o app) e o código
  (`MD-RH.CONTRACHEQUES-MANUT`).
- Se o militar chegar por outro caminho (push, atalho): a tela mostra o mesmo
  conteúdo no lugar dela.
- Toda exibição de bloqueio gera o evento `modulo.bloqueio_visto` no log.

### 5.3 Quando o app lê

Na abertura (antes do login, só a parte pública), logo depois do login, ao
voltar para o app depois de 5 minutos, ao puxar para atualizar (Início e
Serviços) e ao receber o push silencioso de configuração. Sem rede, usa a
última guardada; sem nenhuma, os padrões do código.

- **Cache versionado:** o app guarda a última resposta com a `versao_config` e
  manda a versão que tem (`If-None-Match`); o servidor responde "não mudou" sem
  corpo quando é a mesma. Falhou a leitura: nova tentativa com recuo (2 s, 8 s,
  30 s), sem travar a tela. O servidor limpa o próprio cache na hora em que o
  painel publica.
- **Dado guardado não se passa por atual:** quando a tela mostra o que estava
  guardado (sem rede ou servidor fora), os cards dizem "Atualizado hoje às
  07:30" e a faixa do topo diz que está sem conexão. Nas telas de função, se
  houver dado guardado, ele aparece com o mesmo aviso, em vez da tela de erro.

### 5.4 Visível, autorizado, disponível e compatível

A revisão de 21/10/2026 mostrou que "ocultar" e "proibir" estavam misturados.
São quatro coisas separadas, cada uma com o seu campo:

| Conceito | Pergunta | Onde | O que acontece |
|---|---|---|---|
| **Visível** | Aparece no menu, na busca e nos atalhos? | `visivel_menu` | Só esconde a entrada. A API **não** recusa por isso: o card da Início que usa os mesmos dados continua funcionando, e um push para a função (ex.: `op.plantao`) é redirecionado |
| **Autorizado** | Este militar pode usar? | nível, papéis, matrículas (seção 6) | Fora do público: oculto ou bloqueado com motivo `restrito`. A API **recusa** |
| **Disponível** | A função está funcionando agora? | `estado` (ativo ou bloqueado com motivo) | Bloqueada: folha de bloqueio no app. A API **recusa** com o código `MD-` |
| **Compatível** | A versão do app sabe abrir? | `versao_min_app` e o registro de módulos | Versão antiga: "Atualize o app para usar esta função" |

No `app_config`, cada item do menu traz `visivel` e `estado` separados
(PAINEL_ADMIN §3.0 e §9.1 nº 13); "oculto" deixa de ser um estado.

**Versões até 2.1.x** não leem o menu: para elas só valem a disponibilidade e
a autorização, aplicadas pela API, com a mensagem do código `MD-` que elas já
mostram como erro.

---

## 6. Níveis de acesso

### 6.1 Duas ideias separadas: nível e papel

- **Nível** responde "até onde você enxerga". É uma escada: quem está num
  degrau vê tudo dos degraus de baixo. Cada nível tem um **escopo** (os
  próprios dados, a subunidade, a unidade, o grande comando, a PMRR inteira),
  e o servidor filtra os dados por ele.
- **Papel** responde "que trabalho especial você faz", independente do posto
  e do degrau: publicar comunicados, responder pela seção de pessoal, editar o
  painel. Um militar pode ter nível 1 e o papel "Comunicação Social".

Misturar os dois foi o problema do `isSuperUser` de hoje: ele mistura posto
(`idPosto < 8`, ou seja, todo oficial) com nível da intranet. Um capitão numa
seção administrativa vira "gestor" e vê o Mapa da Força de todos, e um
sargento comandante de pelotão destacado não vê nada.

### 6.2 Os níveis (carga inicial)

| Nível | Nome | Escopo dos dados | Quem, normalmente |
|---|---|---|---|
| 1 | **Militar** | os próprios dados | todo militar com login |
| 2 | **Gestor de subunidade** | a sua companhia, pelotão destacado ou seção | comandante e subcomandante de Cia, Pel destacado, chefe de seção |
| 3 | **Gestor de unidade** | a sua OPM (batalhão, CIPM, diretoria) | comandante, subcomandante, P1 da OPM |
| 4 | **Gestor de grande comando** | o grande comando (CPC, CPI, CPE…) | comandante e chefe do EM do grande comando |
| 5 | **Alto Comando** | toda a PMRR | Comandante-Geral, Subcomandante-Geral, Chefe do EMG, Corregedor-Geral e diretores |
| — | **Administrador** (papel) | tudo: configuração do app e do painel e todos os dados da PMRR | DTI |

- **Papéis iniciais** (decisão do usuário, 21/10/2026): **só o
  Administrador** até o login ir para a intranet (configura o app e o painel,
  reseta a senha de outros militares, vê logs, feedback e anexos e publica
  comunicados). Os outros papéis (Publicar comunicados, Atender feedback,
  Gerir certidões, Consulta) ficam desenhados, sem ninguém, para depois.
- **Quem é Administrador:** na carga inicial, **só quem o SIGRH já indica hoje
  como administrador**, e mais ninguém; a lista é mantida à mão. Quando o login
  for para a intranet (2.3), valem os administradores de lá.
- O **Administrador tem acesso a tudo** (decisão do usuário, 21/10/2026):
  todas as funções do app e do painel e **todos os dados, com escopo de toda a
  PMRR**, independente do comando dele. É o único perfil assim. Como é um poder
  grande, vem com travas: poucas pessoas (lista revisada no painel), **todo
  acesso dele a dado de militar registrado na auditoria** (quem, quando, de
  quem), bloqueio por tentativas erradas, sessão do painel que expira sozinha
  e aviso por e-mail quando a conta entra de um aparelho novo. **Sem
  verificação em duas etapas por enquanto** (decisão do usuário, 21/10/2026);
  fica planejada para quando o login passar para a intranet (2.3). "Ver o app como…" continua
  disponível para conferir o que cada nível vê.
- Na tela inicial, abaixo do nome, a **lotação completa em siglas** ("2ª Cia ·
  1º BPM · CPC": subunidade, unidade e grande comando, vindas do SIGRH) e, do nível 2 para cima, um selo
  dourado com o **nome curto do nível** ("Admin", "Unidade"), sem a palavra
  "Nível". O militar comum não tem selo. A lotação por extenso, o nível por extenso, o escopo e o caminho para corrigir ficam em
  Perfil (decisão do usuário, 21/10/2026). O nome curto é o `nome_curto` do
  nível, editável no painel.

### 6.3 Como cada função usa o nível (configurado no painel)

Cada item da árvore (seção 3.2) tem no painel: **nível mínimo**, **papéis**
que liberam mesmo abaixo desse nível, **matrículas avulsas** (piloto) e o que
fazer com quem não alcança (oculto ou bloqueado com motivo `restrito`).

| Função | Nível mínimo | O que muda com o nível |
|---|---|---|
| Minha vida funcional, normas, comunicados, chamados | 1 | nada: são dados do próprio militar |
| **Mapa da Força** | 2 (todo gestor) | N2 vê a subunidade (por pelotão); N3 a OPM (por subunidade); N4 o grande comando (por unidade); N5 a PMRR inteira (por grande comando e diretoria) |
| Mapa da Força › ficha de outro militar | 2 | todo gestor abre a ficha dos militares **dentro do próprio escopo** (decisão do usuário, 21/10/2026); fora do escopo, o servidor recusa |
| Boletins (futuro) | 3 | publicar pede papel "Boletim" |
| Patrimônio e frota (futuro) | 3 | dados da própria OPM |
| Escalas da unidade, como gestor (futuro) | 2 | escopo igual ao do SIGE |
| Relatório de ciência dos comunicados | 3 | só da própria OPM; N5 vê a PMRR |
| Publicar comunicado | papel "Publicar comunicados" | no início, só o Administrador publica; depois o papel pode ser dado a outros militares pelo painel |

O servidor aplica o escopo nos dados; o app só desenha o que recebeu. Cada
endpoint de gestão confere de novo o nível e o escopo (hoje a tela do Mapa da
Força não confere nada, §1.2).

### 6.4 De onde vem o nível

Em ordem, e o maior vence:

1. **Automático pelo SIGRH** (função, cargo, lotação: comandante de Cia → N2,
   comandante de OPM → N3…), pelas regras de cada nível no painel (seção 6.5). Mudou de função, muda de nível sozinho
   (inclusive para baixo, que é o que mais falha hoje).
2. **Perfis que o militar já tem na intranet** (SIGE: `cmt-unidade` → N3,
   `cmt-comando` → N4, `cmt-geral`/`subcmt` → N5; mesma lógica de escopo do
   `obterEscopoUsuarioEscala`).
3. **Concessão manual no painel**, com motivo, data de fim obrigatória e
   registro na auditoria da intranet (`intranet.auditoria`, pela `registrarAuditoria()`; substituto temporário, interino).

Papéis são sempre concedidos no painel (ou vêm de perfis da intranet, como o
do SISCHAMADOS). Tecnicamente, nível e papéis viram perfis do módulo `soupm`
em `intranet.perfis` e recursos `soupm.<chave>.ver` em `intranet.recursos`,
para usar a ACL que a intranet já tem.

- **`isSuperUser` sai do app.** O selo dourado passa a vir do nível.
- **Transição:** antes de ligar, o painel mostra a lista de quem hoje é
  "gestor" pela regra antiga e qual nível cada um teria pela regra nova, para
  revisão. Ninguém perde ou ganha acesso sem essa conferência.
- **"Ver o app como…"** (só administrador): confere o que cada nível vê antes
  de publicar uma mudança no painel.

### 6.5 Níveis no painel (tudo configurável)

Os cinco níveis acima são só a **carga inicial**. No painel, a área **Níveis
de acesso** permite, sem código e sem versão nova do app:

- **Criar, renomear, desativar e reordenar níveis** (arrastar na lista). A
  ordem é a hierarquia: quem está mais acima vê o que os de baixo veem. Cada
  nível tem nome, nome curto (para o selo), cor do selo, descrição e **tipo de
  escopo**: os próprios dados, subunidade, unidade, grande comando, toda a PMRR
  ou uma lista de OPMs escolhida à mão.
- **Dizer quem faz parte**, com regras que leem o SIGRH em tempo real (o SouPMRR
  já tem acesso a esses dados). Cada regra é uma linha, e as regras se somam:

  | Regra | Exemplo |
  |---|---|
  | Função ou cargo no SIGRH | "Comandante de Companhia", "Chefe da P1" |
  | Lotação | todos da Corregedoria, todos da DRH |
  | Posto, graduação ou quadro | Coronel QOC (se o usuário quiser) |
  | Perfil que já existe na intranet | SIGE `cmt-unidade`, SISCHAMADOS nível 4 |
  | Matrícula avulsa | interino, substituto, piloto, sempre com data de fim |
  | Exceção | "menos estas matrículas" |

- **Prévia antes de salvar:** "Esta mudança coloca 37 militares no nível
  Gestor de unidade e tira 2", com a lista. Nada muda sem a conferência.
- **Quem é de cada nível hoje**, com busca por matrícula e o porquê ("Gestor de
  unidade porque é Comandante da 2ª Cia no SIGRH desde 03/2026").
- **Histórico** de toda mudança na auditoria da intranet (quem, quando, antes e
  depois).
- **Papéis** têm a mesma tela: criar, renomear e dizer quem tem.
- Nas funções (seção 6.3), o painel mostra os níveis pelo nome; criar um nível
  novo no meio da escada não quebra a configuração das funções, porque cada
  função guarda o nível mínimo pelo id, não pelo número.

Quando um militar cai em mais de um nível, vale o mais alto. A conta é feita no
servidor a cada `app_config` (com cache curto), então mudar de função no SIGRH
muda o nível na próxima abertura do app.

Tabelas (rascunho):

```sql
CREATE TABLE public.soupm_nivel (
    id            SERIAL PRIMARY KEY,
    nome          VARCHAR(60) NOT NULL,         -- 'Gestor de unidade'
    nome_curto    VARCHAR(20) NOT NULL,         -- 'Unidade'
    ordem         INT NOT NULL,                 -- hierarquia: maior vê mais
    escopo        VARCHAR(20) NOT NULL,         -- proprio | subunidade | unidade | comando | pmrr | lista
    escopo_lista  INT[],                        -- ids de OPM quando escopo = lista
    cor           VARCHAR(9),
    descricao     TEXT,
    ativo         BOOLEAN NOT NULL DEFAULT TRUE
);
CREATE TABLE public.soupm_nivel_regra (
    id            SERIAL PRIMARY KEY,
    nivel_id      INT NOT NULL REFERENCES public.soupm_nivel(id),
    tipo          VARCHAR(20) NOT NULL,         -- funcao_sigrh | lotacao | posto | quadro | perfil_intranet | matricula
    valor         VARCHAR(80) NOT NULL,
    exceto        BOOLEAN NOT NULL DEFAULT FALSE,
    inicio        DATE,
    fim           DATE,                         -- obrigatório quando tipo = matricula
    motivo        TEXT,
    criado_por    VARCHAR(20) NOT NULL,
    criado_em     TIMESTAMP NOT NULL DEFAULT NOW()
);
CREATE TABLE public.soupm_papel (id SERIAL PRIMARY KEY, nome VARCHAR(60) NOT NULL, descricao TEXT, ativo BOOLEAN NOT NULL DEFAULT TRUE);
CREATE TABLE public.soupm_papel_regra (LIKE public.soupm_nivel_regra INCLUDING ALL);  -- com papel_id no lugar de nivel_id
```

### 6.6 Sessão e login

**Na 2.2 (sem mudar o login de hoje):** o militar continua entrando com o
login do SouPMRR + SIGRH (`login.php`). Muda só o que é do aparelho:

1. A senha sai do SharedPreferences (hoje fica em texto puro) e vai para o
   Keychain/Keystore (`flutter_secure_storage`), enquanto a API ainda exigir
   MD5. Nenhuma tela lê `auth.password` direto: tudo passa pelo `Sessao`.
2. O `Sessao` já nasce pronto para trocar de credencial (MD5 hoje, token
   amanhã), para a 2.3 não mexer nas telas.

**Na 2.3: um login só, o da intranet** (planejado agora, implementado depois;
decisão do usuário, 21/10/2026). Hoje o SouPMRR e o SIGRH usam o mesmo login;
na 2.3 o SouPMRR e a intranet passam a usar o mesmo login.

| Passo | Como fica |
|---|---|
| Entrar | O app manda matrícula e senha para `POST /api/v1/auth/login` da intranet (já existe). A intranet confere a senha com hash forte, aplica o 2FA quando ligado e devolve um **token de acesso (JWT)** e os perfis. |
| Senha antiga | Se a conta ainda estiver no MD5 legado, a intranet já sabe migrar (`/auth/migrar-senha`): o app mostra a tela "Atualize sua senha" uma vez. |
| Guardar | Só o token e o token de renovação, no Keychain/Keystore. **A senha não fica mais no aparelho.** |
| Renovar | O app renova sozinho quando faltar menos de 2 h (`/auth/refresh`). Falhou a renovação: volta para o login com a mensagem certa (`LG-SESSAO-EXPIRADA`). |
| Biometria | Passa a destravar o token guardado, em vez de reenviar a senha. |
| Esqueci a senha, primeiro acesso | Passam a usar os fluxos da intranet, com as mesmas telas do app (o texto vem do painel). |
| API do SouPMRR | Todo endpoint aceita o token no cabeçalho `Authorization` e confere com a chave pública da intranet. Matrícula, nível e escopo saem do token, nunca do que o app manda. |
| Painel | Entra com o mesmo login da intranet. A verificação em duas etapas fica para quando o usuário decidir ligar (hoje, sem). |
| Sair | Revoga o token (`/auth/logout`), apaga o registro do aparelho e para os push daquela conta. |

**Pré-requisitos na intranet** (achado da sessão do painel no código, 21/10;
lista em PAINEL_ADMIN §6.4): hoje o JWT vale 12 h, a renovação reassina o
mesmo token sem fim, a chave de assinatura tem um valor padrão no código e o
2FA está desligado no login da API. Antes da 2.3: token curto com renovação
separada e com prazo e chave só no servidor (fora do código). Ligar o 2FA
fica como opção futura, por decisão do usuário (21/10/2026: "não vamos ter
duas etapas por enquanto").

**Transição (2.2 → 2.3):**
- Durante a 2.2 a API aceita as duas credenciais: MD5 (versões até 2.2) e
  token (2.3 em diante). Cada endpoint passa a ler a credencial pelo mesmo
  arquivo comum.
- A 2.3 vai para as lojas; quando as versões antigas caírem abaixo de 2% (o
  log da fase 0 mostra), sobe a versão mínima por plataforma e o MD5 é
  desligado de vez. Junto saem o `loginrh.php` e os endpoints que devolvem hash
  (APRENDIZADOS §30).
- Pendências na intranet (sessão da intranet, não nesta): conferir se o JWT
  carrega matrícula e perfis suficientes, publicar a chave de verificação para
  a API do SouPMRR e expor a revogação do token.

---

## 7. Busca global

- **Onde:** lupa no topo de todas as abas; campo fixo em Serviços; `⌘F` no
  iPad.
- **O que acha:** funções e ações da árvore (pelo `rotulo`, `descricao`,
  `sinonimos` e `palavras_chave`), itens de Perfil, e — quando o módulo
  permitir — conteúdo (legislações e POPs pelo título, que já têm API).
- **Como:** índice local montado do `menu` do `app_config` (já filtrado pelo
  perfil, então não aparece o que o militar não pode ver). Busca sem acento,
  sem caixa, por prefixo de palavra e com tolerância a um erro de digitação
  ("contraxeque"). Sem rede a cada tecla.
- **Resultado:** ícone, nome, área ("Minha vida funcional › Contracheques"),
  descrição e o selo de estado. Bloqueado aparece, com o selo, e abre a folha
  de bloqueio.
- **Sem resultado:** "Não achamos 'X'." com dois botões: "Ver todos os
  serviços" e "Sugerir esta função" (abre o feedback já preenchido).
- **Recentes e sugeridas:** últimas 5 buscas (no aparelho) e "Mais
  procurados" (do painel).
- **Log:** `busca.executar` (termo, quantidade de resultados) e
  `busca.abrir_resultado`. Busca sem resultado é o melhor indicador do que
  falta no app.

Exemplos de sinônimos que já entram na carga inicial: contracheque =
"salário, pagamento, holerite, folha"; certidões = "tempo de serviço,
declaração, documento"; plano de férias = "férias, descanso"; cálculo de
inatividade = "reserva, aposentadoria, inatividade"; ficha = "meus dados,
cadastro, endereço, telefone".

---

## 8. Feedback e solicitações (módulo do painel)

Decisão do usuário (21/10/2026): **o feedback vai para um módulo próprio do
painel**, onde a equipe do SouPMRR lê e responde. O **SISCHAMADOS fica só para
chamados de suporte** (Serviços › Atendimento DTI › Meus chamados).

### 8.0 Uma porta só: "Preciso de ajuda"

O militar não precisa saber se o caso é feedback ou chamado do DTI (revisão de
21/10/2026). Em Serviços › Atendimento e em Perfil › Ajuda, o primeiro item é
**"Preciso de ajuda"**, que pergunta o que ele quer e encaminha:

| Resposta do militar | Vai para |
|---|---|
| "O app deu problema" ou "Tenho uma sugestão ou elogio" | Sugestões e problemas (feedback, seção 8.1) |
| "Preciso de suporte: senha, acesso a sistema, rede, equipamento" | Novo chamado no SISCHAMADOS (seção 8.3) |
| "Tenho uma dúvida" | Perguntas frequentes e contato do suporte (`ajuda`) |

As entradas diretas (Sugestões e problemas, Meus chamados) continuam no menu.
As telas de erro com "Relatar este problema" vão direto para o feedback, já com
o código.

### 8.1 O que o militar faz

Perfil › Ajuda e feedback, ou Serviços › Atendimento DTI › Sugestões e
problemas, ou "Sugerir esta função" na busca, ou "Relatar este problema" em
qualquer tela de erro.

1. Escolhe o tipo: **Relatar um problema**, **Sugerir melhoria**, **Pedir
   função nova**, **Elogio**.
2. Escreve (rótulo visível, contador, mínimo de 10 caracteres).
3. Anexa até 5 arquivos (guardados por **180 dias** depois de encerrado o
   feedback e vistos **só pelo Administrador**; decisão do usuário, 21/10/2026): prints e vídeos da galeria (seletor do sistema, sem
   pedir permissão de armazenamento) ou captura da tela atual. Até 25 MB no
   total.
4. Marca "Enviar dados do aparelho" (vem marcado; mostra o que vai: modelo,
   sistema, versão do app, tela de onde veio, últimos 3 códigos de erro).
5. Envia e recebe um protocolo (`FB-2026-00042`). Acompanha em **Minhas
   mensagens**, dentro de Sugestões e problemas: situação, resposta da equipe
   e campo para responder.

### 8.2 Como funciona por trás

- Grava em `soupm_feedback` (seção 12), com os anexos numa pasta fora da área
  pública, servidos só por uma rota que confere quem pede.
- **No painel:** lista com filtros (tipo, situação, versão do app,
  plataforma, módulo, período), detalhe com anexos, dados do aparelho e o log
  dos erros citados, resposta ao militar, classificação (situação: Recebido,
  Em análise, Planejado, Concluído, Arquivado), marcação de duplicado e
  indicadores (o que mais pedem, que tela mais dá problema).
- A resposta da equipe vira **notificação do SouPMRR** para o militar e
  aparece em Minhas mensagens.
- "Relatar um problema" vindo de uma tela de erro leva o código e o id do
  registro em `soupm_erro`, para a equipe ver o log inteiro.
- Feedback não vira chamado: se for problema de suporte (conta, acesso a
  outro sistema), a equipe responde orientando o militar a abrir um chamado em
  Meus chamados.
- Tabelas `soupm_feedback`, `soupm_feedback_mensagem` e `soupm_feedback_anexo`
  (o desenho final está no PAINEL_ADMIN §8).

### 8.3 SISCHAMADOS no app

Só do solicitante: abrir chamado de suporte, acompanhar, responder quando a
equipe pedir e avaliar, pela API que o SISCHAMADOS já tem
(`/sischamados/api/v1`). Triagem, técnico e fila continuam na intranet. As
notificações do SISCHAMADOS são da intranet e **não entram na aba Avisos** do
SouPMRR, que é só do SouPMRR (decisão do usuário).

---

## 9. Erros e logs

### 9.1 Erros

Todo erro segue o padrão do `erro_login.dart`: título, o que aconteceu, de
quem é o problema (aparelho, servidor, conta), o que fazer, botão da ação certa
e um código. Na 2.2 isso sai do login e vira peça comum
(`core/erros/`):

- **`FalhaApp`**: tipo único com `codigo`, `origem` (aparelho, rede,
  servidor, conta, dado), `titulo`, `texto`, `acao` e `detalhe` (só log).
- **Cliente HTTP único** (`core/rede/ApiClient`): timeout padrão de 15 s
  (configurável pelo `app_config`), conversão de toda falha em `FalhaApp`
  com o prefixo do módulo, cabeçalhos com versão e plataforma, envio do log.
- **Três desenhos:** aviso curto (`avisoErro`), cartão de erro (o do login,
  generalizado) e **tela de erro** no lugar do conteúdo (com "Tentar de novo",
  "Relatar este problema" e o código).
- **Captura global:** `FlutterError.onError` e
  `PlatformDispatcher.instance.onError` gravam em `soupm_erro` com o código
  `AP-FATAL-<tipo>`. É o nosso "Crashlytics", sem sair do Postgres.

Prefixos por módulo (o sufixo segue o padrão `LG-`: `REDE`, `FORA`,
`LENTO`, `SSL`, `SRV-nnn`, `RESP`, `API`, `DADOS`, `X-<tipo>`):

| Prefixo | Módulo | Prefixo | Módulo |
|---|---|---|---|
| `LG` | login e sessão | `DC` | declarações |
| `CF` | app_config | `NR` | legislações e POPs |
| `CC` | contracheques | `MF` | Mapa da Força |
| `TS` | tempo de serviço (`TS-IPER` já existe) | `AV` | avisos |
| `CT` | certidões | `BU` | busca |
| `FE` | férias | `FB` | feedback |
| `FI` | ficha individual | `CH` | SISCHAMADOS |
| `DC-FECHADA` | declaração fora da campanha aberta pelo painel | `PD` | pendência de um sistema que não respondeu |
| `MD` | bloqueio pelo painel | `AP` | app (falha geral) |

### 9.2 Logs

**Regra para todo o app, hoje e nas funções novas** (decisão do usuário,
21/10/2026): **toda interação vira evento**. Abrir o app, abrir uma tela, ver
um contracheque, baixar, compartilhar, emitir, enviar, tocar num card, num
atalho, num comunicado, errar. Função nova só está pronta quando os eventos
dela estão neste catálogo e aparecem no painel (regra no CLAUDE.md). O
catálogo fica no banco (`soupm_evento_catalogo`), e o painel marca evento
"Nunca visto" (está no catálogo, mas o app não manda) e "Fora do catálogo" (o
app manda, mas ninguém cadastrou).

**Formato do nome:** `<modulo>.<acao>` (`contracheque.compartilhar`). Todo
evento leva a `chave` da função (`rh.contracheques`) e o `resultado` (ok,
cancelado, falhou + código).

**Eventos gerais:**

| Evento | Quando | Dados extras |
|---|---|---|
| `app.abrir`, `app.fundo`, `app.voltar`, `app.fechar` | ciclo de vida | tempo de abertura (ms), abertura a frio ou a quente |
| `sessao.entrar`, `sessao.sair`, `sessao.expirar`, `sessao.biometria` | login e saída | método, resultado |
| `tela.abrir`, `tela.sair` | toda tela | chave, de onde veio (menu, busca, atalho, card, push, link), tempo na tela |
| `funcao.tocar` | item de menu, atalho, card | chave, estado (ativo, bloqueado) |
| `modulo.bloqueio_visto` | folha de bloqueio | chave, motivo |
| `busca.executar`, `busca.abrir_resultado`, `busca.sem_resultado` | busca | termo, total, posição |
| `inicio.personalizar`, `inicio.card_tocar` | Início | ordem nova; chave do card |
| `comunicado.ver`, `comunicado.abrir`, `comunicado.ciencia`, `comunicado.popup_fechar` | comunicados | id, tempo de leitura |
| `pendencia.abrir`, `pendencia.dispensar` | Suas pendências | tipo |
| `push.receber`, `push.abrir` | notificação | id, rota |
| `config.recebida` | `app_config` lido | versão, origem (rede, cache, padrão) |
| `rede.trocou` | perdeu ou voltou a conexão | tipo (Wi-Fi, dados) |

**Eventos por função** (exemplos; cada função nova acrescenta os seus):

| Função | Eventos |
|---|---|
| Contracheques | `contracheque.lista_ver` (ano), `contracheque.ver` (mês, tipo de folha), `contracheque.valores_mostrar`, `contracheque.pdf_pedir` (tempo de geração na API), `contracheque.pdf_conferir` (hash bateu ou não), `contracheque.pdf_baixar`, `contracheque.compartilhar` (app de destino quando o sistema informar), `contracheque.grafico_ver`, `contracheque.mudou_ver` |
| Certidões | `certidao.tipos_ver`, `certidao.emitir` (tipo, tempo), `certidao.abrir`, `certidao.compartilhar`, `certidao.remover` |
| Férias, tempo de serviço | `ferias.ver`, `tempo_servico.ver`, `inatividade.simular` (só os parâmetros escolhidos, sem valores) |
| Declarações | `declaracao.ver`, `declaracao.enviar` (tipo), `declaracao.anexo_enviar` |
| Ficha | `ficha.ver`, `ficha.contato_alterar`, `ficha.endereco_alterar` |
| Mapa da Força | `mapa.ver` (escopo), `mapa.filtrar`, `mapa.ficha_abrir` (só a matrícula de quem foi aberta) |
| Feedback e chamados | `feedback.abrir`, `feedback.enviar` (tipo, anexos), `chamado.abrir`, `chamado.responder` |
| Conta | `conta.email_alterar`, `conta.senha_alterar`, `conta.biometria_ligar` |

**Erros:** todo `FalhaApp` (mostrado ou não) vai para `soupm_erro` com
código, módulo, mensagem técnica curta, pilha resumida (para `AP-FATAL`),
tela, último evento e o id da sessão, para o painel mostrar o caminho que levou
ao erro.

**Campos de todo registro:** matrícula (quando logado), id do aparelho
(aleatório, gerado na instalação), id da sessão, plataforma, versão do sistema,
modelo do aparelho, versão e build do app, tipo de rede, tema (claro/escuro),
tamanho de fonte do sistema, data e hora do aparelho e do servidor. Unidade e
nível são resolvidos no servidor pela matrícula (não viajam no log).

**Retenção:** ações 180 dias, erros 1 ano (decisão do usuário, 21/10/2026).

**Nunca no log:** senha, MD5, token, CPF completo, valores de contracheque,
conteúdo de documentos, texto livre do feedback (fica no feedback, não no log).

**No painel (tela Logs e erros), com filtros combináveis:** matrícula ou nome,
unidade, nível, evento, função (chave), resultado, código de erro, plataforma,
versão do app, modelo do aparelho, tipo de rede, período (de/até, com hora),
sessão. Ações: **linha do tempo de uma sessão** (tudo o que o militar fez, na
ordem, até o erro), exportar o resultado (CSV), salvar filtros, e indicadores
(aberturas por dia, funções mais usadas, erros mais frequentes, versões em
uso, buscas sem resultado). Desenho da tela: PAINEL_ADMIN.

**Como o app envia:** fila local (até 500 registros, os mais antigos saem
primeiro), enviada em lote de até 50 a cada 30 s, ao ir para o fundo e ao
abrir. Sem rede, espera. Erro de envio do log não gera log (evita laço).

---

## 10. Versões por plataforma

Decisão do usuário (21/10/2026): **Android e iOS têm versões separadas**, cada
uma com o próprio número, a própria publicação e a própria versão mínima. Às
vezes uma correção sai só para uma das duas.

### 10.1 Número de cada plataforma

- **Android:** `versionName` e `versionCode` em
  `android/app/build.gradle.kts`. **iOS:** `CFBundleShortVersionString` e
  `CFBundleVersion` em `ios/Runner/Info.plist`. Cada plataforma sobe o seu
  número só quando publica.
- O `pubspec.yaml` deixa de ser a fonte da versão: o build passa a usar
  `--build-name`/`--build-number` por plataforma, lidos desses arquivos.
- O app manda a própria versão e a plataforma em todo pedido e em todo log,
  então o painel sabe quantos militares estão em cada versão de cada loja.
- "O que há de novo" escrito separado para cada loja (já é regra, §31).
- O painel guarda o histórico de versões publicadas por plataforma
  (`soupm_versao_app`: plataforma, versão, build, data, situação na loja,
  notas). Mínima e recomendada ficam à parte, em `soupm_versao_regra`
  (uma linha por plataforma: mínima, recomendada, título, texto, novidades),
  que o `app_config` lê no formato da seção 10.2.
- **Muda o processo de lançar versão do CLAUDE.md** (hoje "versão nos três
  arquivos, juntos"). A regra nova entra no CLAUDE.md e no APRENDIZADOS quando
  a 2.2 for aprovada para implementação.

### 10.2 Versão mínima e recomendada

No `app_config` (parte pública, antes do login):

```json
"versao": {
  "android": { "minima": "2.2.0", "recomendada": "2.2.1",
               "titulo": "Atualize o SouPMRR", "texto": "Esta versão corrige o envio de anexos." },
  "ios":     { "minima": "2.2.0", "recomendada": "2.2.0" }
}
```

- **Mínima:** abaixo dela, tela de atualização obrigatória (só "Atualizar"),
  com animação no estilo do SouPMRR (seção 10.3).
- **Recomendada:** abaixo dela, um cartão dispensável no topo do Início, uma
  vez por versão.
- O link da loja é escolhido no app pela plataforma, e o texto fala só da
  loja certa (APRENDIZADOS §31).
- **Transição:** as versões até 2.1.x leem `appConfig/versions` no Firestore.
  Esse documento continua existindo até as versões antigas saírem (seção 13),
  com **o menor dos dois mínimos, e nunca acima da última versão publicada em
  cada loja**. O app 2.1.x lê um `min_version` só, para as duas plataformas: se
  valesse o maior, um mínimo só do Android obrigaria o iPhone a atualizar para
  uma versão que não existe na App Store (revisão de 21/10/2026). O painel
  avisa e não deixa salvar um valor acima do que alguma das lojas tem.

---

### 10.3 A tela de atualização obrigatória

É uma tela rara (o militar a vê uma vez por versão), por isso pode ter
encanto, seguindo as skills `flutter-animating-apps` e `review-animations`:
só `transform` e opacidade, curva de saída forte (`cubic-bezier(.23,1,.32,1)`),
nada nasce de `scale(0)` (parte de 0,9) e tudo para com "Reduzir movimento".

Sequência (protótipo, "Simular › Atualização obrigatória"):

1. Linhas de circuito no fundo (as mesmas do login), com pontos de luz
   correndo por elas, sem parar.
2. O ícone do SouPMRR sobe e cresce de 0,9 para 1 (0,7 s); ondas saem dele em
   volta, como um sinal, e um reflexo passa pelo ícone a cada 3,6 s.
3. Um selo dourado com seta para cima entra no canto do ícone e fica
   flutuando.
4. A pílula "Versão 2.1.5" aparece, é **riscada** em vermelho e cai; no lugar
   sobe "Versão 2.2.0" em verde, com o visto (a mensagem "o seu está antigo"
   sem precisar de texto).
5. Entram em sequência: "ATUALIZAÇÃO OBRIGATÓRIA" (dourado), o título "Seu
   SouPMRR ficou para trás", a explicação com a versão instalada, as três
   novidades da versão e o botão "Atualizar na App Store" ou "no Google Play"
   (só a loja da plataforma), com um reflexo passando de tempos em tempos.
6. Rodapé com "Leva menos de um minuto" e o código `CF-VERSAO-IOS` ou
   `CF-VERSAO-ANDROID`.

Título, texto e novidades vêm do painel (`versao.<plataforma>.titulo`,
`texto` e uma lista `novidades`), separados por plataforma; sem eles, o app usa
os padrões do código.

**No Flutter:** um `AnimationController` de 1,8 s com `Interval` para cada
peça (animação em etapas da skill `flutter-animating-apps`), mais dois
controladores em repetição (ondas e seta) parados quando
`MediaQuery.disableAnimationsOf(context)` é verdadeiro. Circuito e ondas com
`CustomPainter`. Sem Lottie nem pacote novo. A tela não reinicia a animação
se o app voltar do fundo.

## 11. Funções novas (aprovadas em 20/10/2026)

Todas usam o que já existe (SIGRH, certidões, contracheque, notificações,
intranet). O usuário aprovou todas; no protótipo aparecem com o selo **Novo**,
cada uma na sua área. A P8 (widget) fica para depois da 2.2.

| # | Função | O que faz | Usa |
|---|---|---|---|
| P1 | **O que mudou no contracheque** | Ao abrir o mês, mostra as rubricas que entraram, saíram ou mudaram de valor em relação ao mês anterior | endpoints de contracheque que já existem |
| ~~P2~~ | **Suas pendências** | Entrou na 2.2 a pedido do usuário (20/10/2026): seção 4.3 | — |
| P3 | **Lembretes e prazos** | Push antes de férias começarem, certidão vencer, prazo de declaração, comunicado com ciência. **Configurado só no painel** (quais, quando, para quem); o militar vê a lista em Perfil › Notificações, mas não desliga um por um. Só desliga todas as notificações do app no sistema do aparelho | cron + `notificarMilitar` / FCM |
| P4 | **Central de documentos** | Certidões, contracheques em PDF e declarações num só lugar, com busca | certidões e contracheques |
| P5 | **Linha do tempo da carreira** | Incorporação, promoções, lotações, cursos, em ordem | SIGRH (as mesmas consultas da Ficha Funcional) |
| P6 | **Validar documento** | Ler o QR Code de uma certidão e ver se é válida | `verificar.php` |
| P7 | **Notícias e agenda da PMRR** | Notícias e agenda institucional | módulos `noticias` e `agenda` da intranet (agenda já tem API) |
| P8 | **Widget na tela do aparelho** | Próximas férias e último contracheque (sem valor) | os mesmos cards (iOS WidgetKit, Android Glance); fica para depois da 2.2 |

---

## 12. Mudanças na API e no banco

### 12.1 Endpoints novos (API do app, `sigrh/`)

| Endpoint | O quê |
|---|---|
| `app_config.php` | POST. Sem login: parte pública (versão, login, textos). Com login: tudo da seção 5 |
| `log.php` | POST em lote: `{eventos: [...], erros: [...]}`. Responde rápido, grava sem bloquear |
| `notificacoes.php` | Listar, marcar lida, excluir (substitui o Firestore) |
| `dispositivo.php` | Registrar e remover token FCM do aparelho (substitui `militares/{m}.fcmToken`) |
| `inicio_preferencias.php` | Guardar a personalização da tela inicial |
| `pendencias.php` | "Suas pendências": junta os tipos ligados no painel para o militar (seção 4.3) |
| `comunicados.php` | Listar os comunicados do militar, marcar lido, registrar ciência (seção 4.2) |
| `contracheque_pdf.php` | Gera o PDF do contracheque no servidor, pelo padrão do painel, e devolve com SHA-256 (seção 12.3) |
| `feedback.php` | Enviar feedback com anexos, listar "Minhas mensagens", responder (seção 8) |

Todos com consulta preparada, POST, sem dado na URL e passando pelo
`/security-review` antes de subir. Roteiro de deploy do APRENDIZADOS §18.

### 12.2 Tabelas novas (rascunho; DDL final no `sql/` da API)

> **O desenho final das tabelas fica no `docs/PAINEL_ADMIN.md` §8**, combinado
> com a sessão do painel em 21/10/2026: `TIMESTAMPTZ` em vez de `TIMESTAMP`,
> `CHECK` em vez de `ENUM` (o banco é PostgreSQL 9.6), log em tabela por mês
> com uma view (o 9.6 não tem partição declarativa), auditoria na
> `intranet.auditoria` (sem `soupm_admin_log`), `soupm_pendencia_tipo` com
> `fonte_status`, `prazo_tipo` e `prazo`, e `soupm_feedback_anexo`. Os
> rascunhos abaixo mostram a ideia; em conflito, vale o PAINEL_ADMIN.

```sql
-- Árvore de menus e estado de cada função (substitui o soupm_modulo do PAINEL §8)
CREATE TABLE public.soupm_menu_item (
    chave          VARCHAR(80) PRIMARY KEY,   -- 'rh.contracheques'
    pai            VARCHAR(80) REFERENCES public.soupm_menu_item(chave),
    tipo           VARCHAR(12) NOT NULL,      -- area | funcao | acao | bloco_inicio | aba
    rotulo         VARCHAR(60) NOT NULL,
    descricao      VARCHAR(140),
    icone          VARCHAR(40),
    ordem          INT NOT NULL DEFAULT 0,
    rota           VARCHAR(80),               -- rota do app; nulo para área
    sinonimos      TEXT[],
    palavras_chave TEXT[],
    visivel_menu   BOOLEAN NOT NULL DEFAULT TRUE,  -- aparece no menu, na busca e nos atalhos (seção 5.4)
    estado         VARCHAR(12) NOT NULL DEFAULT 'ativo',  -- disponibilidade: ativo | bloqueado (oculto = visivel_menu falso; seção 5.4)
    motivo         VARCHAR(20),
    selo           VARCHAR(20),
    msg_titulo     VARCHAR(120),
    msg_texto      TEXT,
    previsao       TIMESTAMP,
    acao           VARCHAR(20),
    acao_destino   TEXT,
    recurso_key    VARCHAR(120),              -- 'soupm.rh.contracheques.ver' (intranet.recursos)
    fora_do_publico VARCHAR(12) NOT NULL DEFAULT 'oculto',
    versao_min_app VARCHAR(12),
    inicio         TIMESTAMP,
    fim            TIMESTAMP,
    bloqueavel     BOOLEAN NOT NULL DEFAULT TRUE,
    apelidos       TEXT[],                    -- chaves antigas: '{contracheques}'
    volta_auto     BOOLEAN NOT NULL DEFAULT FALSE, -- manutenção automática: volta sozinha quando o serviço normaliza
    servico_dependente VARCHAR(30) REFERENCES public.soupm_servico(chave), -- serviço de que a função depende
    atualizado_em  TIMESTAMP NOT NULL DEFAULT NOW(),
    atualizado_por VARCHAR(20)
);

-- Log de ações (particionar por mês; guardar 180 dias)
CREATE TABLE public.soupm_evento (
    id           BIGSERIAL,
    recebido_em  TIMESTAMP NOT NULL DEFAULT NOW(),
    ocorrido_em  TIMESTAMP NOT NULL,
    matricula    VARCHAR(20),
    aparelho_id  UUID NOT NULL,
    sessao_id    UUID,
    plataforma   VARCHAR(10) NOT NULL,        -- android | ios
    so_versao    VARCHAR(20),
    modelo       VARCHAR(60),
    app_versao   VARCHAR(20) NOT NULL,
    app_build    VARCHAR(20),
    rede         VARCHAR(10),                 -- wifi | dados | nenhuma
    tema         VARCHAR(6),                  -- claro | escuro
    fonte_escala NUMERIC(3,2),                -- tamanho de fonte do sistema
    evento       VARCHAR(60) NOT NULL,        -- 'tela.abrir' (tem de existir em soupm_evento_catalogo)
    chave        VARCHAR(80),                 -- 'rh.contracheques'
    resultado    VARCHAR(10),                 -- ok | cancelado | falhou (CHECK)
    codigo       VARCHAR(40),                 -- código do erro quando falhou
    dados        JSONB,
    PRIMARY KEY (id, recebido_em)
) PARTITION BY RANGE (recebido_em);
-- Atenção: o banco de produção é PostgreSQL 9.6 (lado da intranet). Se a API do
-- app usar o mesmo servidor, partição declarativa não existe no 9.6: usar tabela
-- por mês (soupm_evento_2026_11) com uma view de união. Conferir a versão antes.

-- Log de erros (mesmas colunas de identificação)
CREATE TABLE public.soupm_erro (
    id           BIGSERIAL PRIMARY KEY,
    recebido_em  TIMESTAMP NOT NULL DEFAULT NOW(),
    ocorrido_em  TIMESTAMP NOT NULL,
    matricula    VARCHAR(20),
    aparelho_id  UUID NOT NULL,
    plataforma   VARCHAR(10) NOT NULL,
    app_versao   VARCHAR(20) NOT NULL,
    origem       VARCHAR(10) NOT NULL,        -- app | api
    codigo       VARCHAR(40) NOT NULL,        -- 'CC-LENTO'
    modulo       VARCHAR(20),
    tela         VARCHAR(80),
    mensagem     TEXT,                        -- técnica, sem dado sensível
    pilha        TEXT,
    mostrado     BOOLEAN NOT NULL DEFAULT TRUE
);
CREATE INDEX ON public.soupm_erro (codigo, recebido_em);
-- soupm_erro também leva app_build, rede, tema, fonte_escala e sessao_id.
-- Índices de soupm_evento e soupm_erro: (matricula, ocorrido_em), (sessao_id), (evento, ocorrido_em).
-- Catálogo de eventos e filtros salvos do painel: soupm_evento_catalogo e soupm_log_filtro (PAINEL_ADMIN §8).
-- Catálogo de serviços do mapa de conexões: soupm_servico (chave PK, nome, icone, faixa aparelho|app|servico,
--   depende_de TEXT[], sonda JSONB, funcoes TEXT[], ordem, ativo). Sem lista fixa no código.
-- Saúde dos serviços para o Painel (mapa de conexões ao vivo): soupm_saude (PAINEL_ADMIN §8), servico REFERENCES soupm_servico(chave),
--   gravada por uma sonda da API do app a cada minuto (servico, medido_em, status ok|lento|fora, latencia_ms, detalhe; 30 dias).
-- Significado dos códigos de erro (tabela da seção 9.1): soupm_config, chave 'erros', lido pela API e pelo painel, sem texto duplicado.
-- Só do painel, sem efeito no app: soupm_alerta_regra, soupm_alerta_disparo, soupm_relatorio (PAINEL_ADMIN §8).
-- Documentos gerados na API (contracheque, declarações, futuros): soupm_documento_padrao (PK documento+versao,
--   status rascunho|publicada|substituida, padrao JSONB, um único publicado por documento) e
--   soupm_documento_emissao (documento, versao do padrão, matricula, referencia, sha256, data) (PAINEL_ADMIN §8).
-- Campanhas de declaração: soupm_declaracao_campanha (tipo, ano, abre_em, prazo, situacao agendada|aberta|encerrada, UNIQUE tipo+ano).
-- Mídia aprovada para cards: soupm_midia; paleta fechada do DESIGN.md em soupm_config 'paleta'; fontes de dados: soupm_fonte_dados.
-- soupm_servico também guarda tipo (api, banco, push, externo), conexao e conexao_anterior (nome da conexão; a credencial fica em /private).
-- Cards criados no painel: soupm_card (PAINEL_ADMIN §8); blocos fixos são linhas bloco_inicio de soupm_menu_item com marca, marca_imagem e escondivel.

-- Aparelhos e tokens (sai do Firestore)
CREATE TABLE public.soupm_dispositivo (
    token        TEXT PRIMARY KEY,
    matricula    VARCHAR(20),                 -- nulo quando deslogado
    aparelho_id  UUID NOT NULL,
    plataforma   VARCHAR(10) NOT NULL,
    app_versao   VARCHAR(20),
    criado_em    TIMESTAMP NOT NULL DEFAULT NOW(),
    ultimo_uso   TIMESTAMP NOT NULL DEFAULT NOW(),
    ativo        BOOLEAN NOT NULL DEFAULT TRUE
);

-- Notificações (sai do Firestore)
CREATE TABLE public.soupm_notificacao (
    id           BIGSERIAL PRIMARY KEY,
    matricula    VARCHAR(20),                 -- nulo = aviso geral
    titulo       VARCHAR(120) NOT NULL,
    mensagem     TEXT NOT NULL,
    rota         VARCHAR(80),
    tipo_evento  VARCHAR(40),
    envio_id     BIGINT,                      -- soupm_notificacao_envio (PAINEL §8)
    criado_em    TIMESTAMP NOT NULL DEFAULT NOW(),
    expira_em    TIMESTAMP
);
CREATE TABLE public.soupm_notificacao_leitura (
    notificacao_id BIGINT REFERENCES public.soupm_notificacao(id),
    matricula      VARCHAR(20),
    lida_em        TIMESTAMP,
    excluida_em    TIMESTAMP,
    PRIMARY KEY (notificacao_id, matricula)
);

CREATE TABLE public.soupm_feedback_mensagem (
    id            BIGSERIAL PRIMARY KEY,
    feedback_id   BIGINT NOT NULL REFERENCES public.soupm_feedback(id),
    autor         VARCHAR(10) NOT NULL,       -- militar | equipe
    matricula     VARCHAR(20) NOT NULL,
    texto         TEXT NOT NULL,
    anexos        JSONB,
    criado_em     TIMESTAMP NOT NULL DEFAULT NOW()
);

-- Preferência da tela inicial
CREATE TABLE public.soupm_inicio_preferencia (
    matricula     VARCHAR(20) PRIMARY KEY,
    blocos        JSONB NOT NULL,             -- [{"chave":"home.ferias","visivel":true}, ...]
    atalhos       TEXT[],
    atualizado_em TIMESTAMP NOT NULL DEFAULT NOW()
);

-- Comunicados oficiais (substitui appConfig/anuncio)
CREATE TABLE public.soupm_comunicado (
    id             BIGSERIAL PRIMARY KEY,
    titulo         VARCHAR(120) NOT NULL,
    resumo         VARCHAR(200),
    texto          TEXT NOT NULL,
    categoria      VARCHAR(30) NOT NULL,      -- operacao | saude | rh | instrucao | institucional...
    origem         VARCHAR(80) NOT NULL,      -- 'Comando-Geral', 'Diretoria de Saúde'
    imagem         TEXT,                      -- caminho na pasta só de imagens; nulo = arte padrão da categoria
    icone          VARCHAR(40),
    publico        JSONB,                     -- mesmos filtros das notificações (PAINEL §4.3)
    inicio         TIMESTAMP NOT NULL,
    fim            TIMESTAMP,
    ordem          INT NOT NULL DEFAULT 0,
    urgente        BOOLEAN NOT NULL DEFAULT FALSE,
    destaque_abertura BOOLEAN NOT NULL DEFAULT FALSE,   -- abre por cima ao entrar no app
    abertura_ate_ciencia BOOLEAN NOT NULL DEFAULT FALSE,
    ciencia        BOOLEAN NOT NULL DEFAULT FALSE,      -- exige "Estou ciente"
    ciencia_prazo  TIMESTAMP,
    envia_push     BOOLEAN NOT NULL DEFAULT FALSE,
    criado_por     VARCHAR(20) NOT NULL,
    criado_em      TIMESTAMP NOT NULL DEFAULT NOW()
);
CREATE TABLE public.soupm_comunicado_leitura (
    comunicado_id  BIGINT REFERENCES public.soupm_comunicado(id),
    matricula      VARCHAR(20),
    lido_em        TIMESTAMP,
    ciente_em      TIMESTAMP,
    aparelho_id    UUID,
    PRIMARY KEY (comunicado_id, matricula)
);

-- Tipos de pendência (um por regra de cada sistema; o painel liga e configura)
CREATE TABLE public.soupm_pendencia_tipo (
    chave          VARCHAR(80) PRIMARY KEY,   -- 'sigrh.declaracao_bens'
    sistema        VARCHAR(30) NOT NULL,      -- SIGRH | SouPM | SISCHAMADOS | SIGE | ...
    fonte          VARCHAR(120) NOT NULL,     -- função PHP ou endpoint do sistema que calcula
    ativo          BOOLEAN NOT NULL DEFAULT FALSE,  -- todos começam desligados (decisão do usuário)
    obrigatoria    BOOLEAN NOT NULL DEFAULT FALSE,
    dispensavel    BOOLEAN NOT NULL DEFAULT TRUE,   -- só vale para lembrete
    titulo         VARCHAR(120) NOT NULL,     -- aceita campos: {prazo}, {dias}, {numero}
    texto          VARCHAR(200),
    icone          VARCHAR(40),
    chave_destino  VARCHAR(80),               -- função que resolve (soupm_menu_item)
    antecedencia_dias INT,                    -- começa a aparecer N dias antes do prazo
    periodo_inicio TIMESTAMP,                 -- janela de cobrança (ex.: outubro)
    periodo_fim    TIMESTAMP,
    publico        JSONB,
    prioridade     INT NOT NULL DEFAULT 0,
    push           JSONB,                     -- {"dias_antes":[15,3]} ou nulo
    atualizado_em  TIMESTAMP NOT NULL DEFAULT NOW(),
    atualizado_por VARCHAR(20)
);
CREATE TABLE public.soupm_pendencia_dispensa (
    tipo           VARCHAR(80) REFERENCES public.soupm_pendencia_tipo(chave),
    matricula      VARCHAR(20),
    referencia     VARCHAR(80),               -- qual ocorrência (ano, nº do chamado...)
    dispensada_em  TIMESTAMP NOT NULL DEFAULT NOW(),
    PRIMARY KEY (tipo, matricula, referencia)
);

-- Feedback dos militares (módulo do painel, seção 8)
CREATE TABLE public.soupm_feedback (
    protocolo     VARCHAR(20) UNIQUE NOT NULL, -- 'FB-2026-00042'
    situacao      VARCHAR(20) NOT NULL DEFAULT 'recebido', -- recebido | em_analise | planejado | concluido | arquivado
    duplicado_de  BIGINT,
    grupo_id      BIGINT REFERENCES public.soupm_feedback(id), -- "Assuntos em alta": resposta ao grupo chega a cada militar
    prioridade    VARCHAR(10),                -- baixa | media | alta (CHECK)
    chave_funcao  VARCHAR(80),                -- função do app de que trata
    rotulos       TEXT[],
    responsavel   VARCHAR(20),                -- matrícula de quem atende no painel
    erro_id       BIGINT,                     -- soupm_erro citado, quando veio de uma tela de erro
    atualizado_em TIMESTAMPTZ,
    plataforma    VARCHAR(10),
    app_versao    VARCHAR(20),
    id            BIGSERIAL PRIMARY KEY,
    matricula     VARCHAR(20) NOT NULL,
    tipo          VARCHAR(20) NOT NULL,       -- problema | melhoria | funcao_nova | elogio
    texto         TEXT NOT NULL,
    contexto      JSONB,                      -- aparelho, tela, códigos de erro
    anexos        JSONB,                      -- [{caminho, tipo_mime, bytes, sha256}], fora da pasta pública
    criado_em     TIMESTAMP NOT NULL DEFAULT NOW()
);
```

O usuário da API do app só tem `INSERT` nas tabelas de log e `SELECT` no menu;
quem altera o menu é o painel (PAINEL_ADMIN §7).

---

### 12.3 Contracheque e documentos gerados na API

Hoje o PDF do contracheque é montado **no aparelho**
(`lib/pages/page_contracheque.dart`, com `dart_pdf` e o brasão em
`lib/assets`). Na 2.2 ele passa a seguir o modelo das certidões
(APRENDIZADOS §22 a §28):

- **API:** `contracheque_pdf.php` recebe mês, ano e tipo de folha, confere os
  dados (soma de proventos e descontos igual ao líquido, rubricas sem valor
  impossível, falha de consulta nunca vira "sem rubrica", §27), monta o PDF
  com o padrão do banco e devolve com SHA-256. O app compara o hash antes de
  guardar, como já faz com as certidões.
- **Padrão no banco, editado pelo painel** (grupo "Documentos" do painel,
  PAINEL_ADMIN §5.10): `soupm_documento_padrao` (documento, versão, situação
  rascunho/publicada/substituída, padrão em JSON com títulos, cabeçalho
  oficial, textos, rodapé, marca d'água, blocos e rubricas visíveis com nome,
  ordem e agrupamento; só uma publicada por documento). Liga/desliga e limites
  em `soupm_config`, chave do documento. Cada PDF fica registrado em
  `soupm_documento_emissao` (documento, versão do padrão, matrícula,
  referência, SHA-256, data), no desenho da `soupm_certidao_emissao`. A versão
  do padrão sai impressa no PDF.
- **Códigos de erro:** `CC-SEM-FOLHA` (mês sem folha), `CC-DESLIGADO` (serviço
  desligado no painel), `CC-PDF` (falha ao montar), `CC-HASH` (o arquivo
  recebido não confere), além do `CC-LENTO` que já existe.
- **Três prazos separados** (revisão de 21/10/2026), para o contracheque, as
  certidões e todo documento: **validade** do documento (quanto tempo ele vale
  para quem recebe; o contracheque não vence, a certidão vale 30 dias),
  **disponível para baixar** no app (quanto tempo fica em "Minhas
  certidões"/histórico) e **retenção do registro de autenticidade** (quanto
  tempo o QR continua respondendo; precisa durar enquanto o papel pode
  circular). Retenção: **1 ano** (decisão do usuário, 21/10/2026); depois disso
  o QR responde que o registro de conferência expirou.
- **QR Code de conferência pública** (decisão do usuário, 21/10/2026): o
  contracheque sai com QR, como a certidão. A página pública **mostra** a
  situação (válido, ou substituído por retificação da folha), mês e tipo de
  folha, nome com o meio abreviado, matrícula parcial e os totais (proventos,
  descontos, líquido); **nunca mostra** rubricas, CPF, conta nem consignados.
  Cada conferência vai para `soupm_documento_verificacao_log`, no desenho do
  log das certidões, e o endereço impresso nunca muda (como o `verificar.php`).
  A lista do que a página mostra é proposta e o usuário confirma na
  implementação; o endpoint passa pela revisão de segurança antes de ir ao ar,
  porque expõe dado de folha a quem tiver o QR.
- **App:** só pede, mostra, guarda e compartilha. A tela continua mostrando os
  valores na própria tela (dados da API, sem PDF) e o PDF vem pronto.
- **Vale para declarações e todo documento futuro.**
- **Versões antigas** (até 2.1.x) continuam gerando o PDF no aparelho até o
  corte por versão mínima; a API antiga de dados do contracheque fica no ar
  até lá.
- **Riscos:** PDF diferente do que o militar já conhece (comparar o PDF novo
  com o atual página por página, com dados fictícios e uma matrícula real
  escolhida pelo usuário, antes de trocar); servidor mais carregado no dia em
  que a folha sai (gerar sob pedido, com cache por mês e hash); contracheque
  sem conexão (o último PDF baixado fica guardado no aparelho, como as
  certidões).

### 12.4 Bancos e conexões no painel

O app usa vários bancos (SIGRH e outros). Pedido do usuário (21/10/2026): o
painel tem a tela **"Bancos e conexões"**, com a lista dos bancos, a situação
de cada um (pela sonda), e **quais funções usam cada banco**. As credenciais
ficam **só no servidor** (`/private`), nunca no painel nem no navegador: o
painel mostra só nome, situação e funções ligadas. Os dados do Comando e dos
cursos já estão no SIGRH. Quando o SIGRH migrar para a intranet (o banco é uma
cópia), basta trocar o banco apontado, com prévia e auditoria.

## 13. Saída do Firebase

### 13.0 Para o militar, as notificações continuam iguais

A entrega do push **continua pelo Firebase Cloud Messaging (FCM)**: é ele que
faz a mensagem chegar no Android e, pelo serviço da Apple (APNs), no iPhone,
com o app fechado. Isso não muda e não tem substituto gratuito.

O que sai do Firebase é o resto: **onde a notificação fica guardada** (a lista
da aba Avisos, o lido/não lido, o histórico), **a lista de aparelhos** (tokens)
e **quem dispara** (hoje as Cloud Functions; amanhã a nossa API em PHP, que
chama o FCM direto). Fluxo de um envio na 2.2:

1. O painel (ou a API, ao emitir uma certidão) grava a notificação em
   `soupm_notificacao` e o pedido de envio em `soupm_notificacao_envio`, no
   Postgres. **O painel nunca chama o FCM.**
2. Um cron na API do app pega os envios pendentes e busca os tokens dos
   aparelhos em `soupm_dispositivo`.
3. A API manda para o FCM (API HTTP v1), que entrega no aparelho como hoje, e
   grava o resultado (enviado, falhou, sem aparelho).
4. O app mostra o push; com o app aberto, mostra o aviso na hora (`onMessage`)
   e recarrega a aba Avisos de `notificacoes.php`.

**Atenção (achado da sessão do painel):** a intranet já manda push pelo app
hoje (`fcm_helper.php`, `notificarViaSouPM`, pelas Cloud Functions), por
exemplo do SISCHAMADOS e da escala. Desligar as Functions para isso. **Decidido**
(21/10/2026): todos os módulos seguem o modelo do SIGE. A intranet manda para a
API do SouPMRR, que sempre filtra, gerencia e encaminha ao app; o push chega no
celular, mas **não entra na aba Avisos**, que é só do SouPMRR.

**Estados de cada envio, por aparelho** (não por matrícula): "aceito pelo
FCM", "falhou" (com o motivo do FCM), "sem aparelho" e "aberto" (evento
`push.abrir`). Nunca "entregue": o FCM aceitar não prova que chegou. A ciência
de comunicado é outro fluxo.

Ganhos: um lugar só para filtrar e cruzar dados (posto, unidade, nível), o
painel vê quem recebeu e quem leu, vários aparelhos por militar, e logout
para de mandar push para o aparelho que saiu da conta.


Fica: **`firebase_core` + `firebase_messaging`** (o FCM é o único jeito
gratuito e confiável de entregar push nas duas plataformas; o APNs passa por
ele). Sai todo o resto.

| Hoje (Firestore/Functions) | Vai para | Observação |
|---|---|---|
| `appConfig/versions` | `app_config.versao` por plataforma | O documento fica, com o maior mínimo, até as 2.1.x saírem |
| `appConfig/anuncio` | `soupm_comunicado` (central de comunicados, seção 4.2) | Painel edita; o anúncio de hoje vira o primeiro comunicado com destaque de abertura |
| `dicas_app` | `app_config.home` (`home.dicas`) | Ícone por chave, sem emoji |
| `stores` (comandantes) | `app_config.home` (`home.comandantes`) | Foto no servidor (pasta só de imagens) |
| `militares/{m}.fcmToken` | `soupm_dispositivo` | Vários aparelhos por militar; logout desativa |
| `militares/{m}/notificacoes` | `soupm_notificacao` | |
| `avisos_gerais` | `soupm_notificacao` com `matricula` nula | |
| `militares/{m}/avisos_status` | `soupm_notificacao_leitura` | |
| Banner com o app aberto (stream do Firestore) | `onMessage` do FCM + recarga da lista | |
| Cloud Functions `notificarMilitar`, `notificarTodos` | PHP chamando a **API HTTP v1 do FCM** direto, com a conta de serviço em `/private` | Some o `x-admin-token` e o `notificarEscala` sem autenticação |
| Tópicos `todos_militares`, `pmrr_usuarios` | Envio por token (lote de 500) a partir de `soupm_dispositivo`; tópico só como reserva | Tópico não sabe quem saiu da conta |

**Plano sem quebrar quem está na 2.1.x**

1. **Escrita dupla.** A API passa a gravar cada notificação no Postgres **e**
   no Firestore. Painel e Functions continuam funcionando.
2. **2.2 lê só do Postgres** e registra o token em `soupm_dispositivo` (e
   continua gravando no Firestore enquanto houver envio pelas Functions).
3. **Corte** (critério escolhido pelo planejamento, já que o usuário deixou
   a decisão aberta): só depois de **30 dias** com a 2.2 publicada nas duas
   lojas **e** com menos de **2% das aberturas da última semana** em versões
   antigas, contado por plataforma. Se em **90 dias** os 2% não chegarem, o
   corte acontece mesmo assim: a versão mínima sobe e quem ficou para trás é
   obrigado a atualizar. Detalhe original: quando os logs mostrarem menos de 2% de aberturas com versão
   anterior à 2.2 (o `soupm_evento` passa a dizer isso) ou 60 dias depois da
   publicação: `min_version` do Firestore sobe para 2.2.0 (as antigas pedem
   atualização), as Functions são desligadas, a escrita dupla para e o
   Firestore vira só leitura por mais 30 dias antes de apagar.
4. Exportar o histórico de notificações do Firestore para o Postgres antes do
   corte (script único, conferido por contagem).

---

## 14. Organização do código

### 14.1 Pastas

```
lib/
├── main.dart                  só inicia (runApp primeiro, §2 do APRENDIZADOS)
├── app/
│   ├── app.dart               MaterialApp, tema, Provider
│   ├── rotas.dart             monta as rotas a partir do registro de módulos
│   ├── shell/                 abas, barra lateral do iPad, navegador por aba
│   └── registro_modulos.dart  lista de ModuloApp (um por pasta de features/)
├── core/
│   ├── rede/                  ApiClient, interceptadores, vitrine
│   ├── erros/                 FalhaApp, códigos, tela/cartão de erro
│   ├── log/                   fila, envio, eventos
│   ├── config/                AppConfig (modelo, cache, padrões)
│   ├── sessao/                Sessao (armazenamento seguro, token, perfis)
│   ├── busca/                 índice e normalização
│   ├── navegacao/             árvore de menus, estado, folha de bloqueio
│   └── design/                tokens, CartaoVidro, componentes do DESIGN.md
├── features/
│   ├── inicio/                data/ (repositório), ui/ (view model + telas)
│   ├── servicos/
│   ├── avisos/
│   ├── perfil/
│   ├── login/
│   ├── busca/
│   ├── feedback/
│   ├── rh_ficha/  rh_contracheques/  rh_ferias/  rh_tempo_servico/
│   ├── rh_certidoes/  rh_declaracoes/
│   ├── op_escalas/  op_svi/
│   ├── normas/  gestao_mapa_forca/
│   └── atend_chamados/        (o SISCHAMADOS entra aqui depois da 2.2)
└── vitrine/
```

Cada `features/<modulo>/modulo.dart` declara um `ModuloApp`:

```dart
const moduloContracheques = ModuloApp(
  chave: 'rh.contracheques',
  rotas: {'/rh/contracheques': ContrachequesPage.new},
  icone: 'contracheque',
  rotuloPadrao: 'Contracheques',
  sinonimosPadrao: ['salário', 'pagamento', 'holerite'],
  prefixoErro: 'CC',
);
```

O menu, a busca, o push e o log leem o registro e o `app_config`. Módulo
novo = pasta nova + uma linha em `registro_modulos.dart` + uma linha no
banco.

**Camadas** (skill de arquitetura, adaptada ao que já existe): serviço (fala
com a API pelo `ApiClient`) → repositório (cache, conversão para modelo) →
view model (`ChangeNotifier`, no Provider que o app já usa) → tela. Sem
`freezed`, sem `get_it`, sem trocar o Provider. Lógica de negócio grande (o
cálculo de inatividade) vai para `domain/` dentro do próprio módulo.

### 14.2 Migração gradual (sem reescrever tudo)

- **Primeiro a fundação** (`core/`), sem mudar nada que o militar vê.
- **Depois o esqueleto novo** (shell, Serviços, Início, busca), que abre as
  telas antigas como estão.
- **Cada tela antiga muda de pasta numa fatia própria**: vai para
  `features/<modulo>`, troca `http` solto pelo `ApiClient`, ganha códigos de
  erro e log. Uma fatia por módulo, testada no simulador em modo vitrine.
- **Duplicatas e pastas legadas** (`components/`, `data/`, `view/`,
  `animation/`) somem quando a última tela que as usa migrar.
- O nome do pacote (`projetonovo`) fica: trocar mexe em todos os imports e não
  traz nada para o militar.

---

## 15. Design: o que muda e o que fica

### 15.1 Fica (DESIGN.md)

Vidro (iOS) e superfície tonal (Android) pelo `CartaoVidro`, `FundoSuave`
global, `AppColors.acao` nos botões cheios, `AppIconSize`, raios, gramática
dos cards (§2b), marca d'água (§2c), `avisoRapido`, regras de contraste e
movimento.

### 15.2 Entra

| Peça | Para quê |
|---|---|
| `BarraBusca` | Campo da busca (topo e Serviços) |
| `CartaoArea` | Área de Serviços com as funções principais |
| `LinhaFuncao` | Item de menu (44/48 pt, ícone, rótulo, descrição, selo, chevron) |
| `SeloEstado` | Em breve, Manutenção, Indisponível, Proposta, Novo |
| `FolhaBloqueio` | Mensagem do painel ao tocar num item bloqueado |
| `TelaErro`, `EstadoVazio` | Erro e vazio no lugar do conteúdo, com ação e código |
| `Esqueleto` | Carregamento com a forma do conteúdo (no lugar do círculo girando) |
| `FaixaComando` | Comandantes compactos |
| `GradeAtalhos` | Atalhos da Início, com modo editar |
| `TokensTexto` | Escala do DESIGN §3b ligada ao `TextTheme`, respeitando o tamanho de fonte do sistema (limite 1,3× nos cards herói, sem limite no corpo) |
| `TokensMovimento` | Durações e curvas do DESIGN §7 como constantes; desligadas com "Reduzir movimento" |
| `Haptico` | Toque leve ao selecionar, sucesso ao emitir, aviso no erro (iOS); `HapticFeedback` equivalente no Android |

**Marca:** continua **SouPMRR** no ícone, na abertura, no login e nas lojas
(decisão do usuário, 21/10/2026). "SouPM" só na fala dos vídeos tutoriais.
Nada muda em `CFBundleDisplayName`, `android:label` nem nos identificadores.

**Espaçamento compacto (decisão do usuário, 21/10/2026).** Um padrão só, na
escala 4 · 8 · 12 · 16, ligado ao DESIGN §3 (que passa a ter esta tabela na
implementação):

| Onde | Valor |
|---|---|
| Entre blocos da Início e entre cards | 12 |
| Título da seção (ex.: "Comunicados") até o conteúdo | 6 a 8; altura do título 36 |
| Dentro de card | 14 (cartão de comunicado 16) |
| Linha de lista | 52 de altura (48 em Suas pendências), sem espaço entre linhas, só o divisor |
| Atalho | ícone 44, célula 68 |
| Carrossel até os pontos e o contador | 2 |
| Margem lateral da tela | 16 |

Alvos de toque continuam com no mínimo 44 pt (iOS) / 48 dp (Android): onde o
desenho encolhe, a área de toque é mantida com espaço invisível.

### 15.3 Android × iOS

| Assunto | iOS | Android |
|---|---|---|
| Abas | **Barra solta de vidro** (padrão novo do iOS, como Instagram e Banco do Brasil): cápsula afastada das bordas e acima da barra de início, vidro translúcido de verdade (desfoque com saturação, deixa ver o conteúdo por baixo, borda de luz; nunca branco chapado). **A aba ativa cresce**, ganha uma cápsula clara e mostra o nome ao lado do ícone, **empurrando as outras** (que ficam só com o ícone, com o nome para o leitor de tela); a troca anima a largura com um leve quique. Ícones encolhem ao apertar e dão um pulo ao serem escolhidos. A barra **não encolhe ao rolar** e não tem lupa (a busca fica no topo das telas). Com "Reduzir transparência" fica opaca; com "Reduzir movimento", sem animação. No Flutter: widget próprio (`BackdropFilter` + cápsula + `AnimatedContainer`/`Flexible` animados), porque o `CupertinoTabBar` ainda é a barra antiga, colada embaixo |
| Título | Título grande na raiz de cada aba, encolhe ao rolar | `TopAppBar` média na raiz, pequena nas internas |
| Voltar | Deslizar da borda esquerda (nunca bloquear) | Voltar preditivo (Android 13+), `enableOnBackInvokedCallback` |
| Folhas | *Sheet* com alturas média e grande, alça | *Bottom sheet* modal com alça |
| Ação principal | Botão cheio no pé da tela | FAB estendido quando a tela tem uma ação principal (ex.: "Novo chamado") |
| Toque | Realce + háptico leve | Ripple |
| Listas | *Inset grouped* | `ListItem` com divisores |
| Borda a borda | Áreas seguras | Edge-to-edge (Android 15 obriga), barras transparentes |
| Busca | Campo no topo que vira tela de busca | `SearchBar` / `SearchView` do Material 3 |
| Ícones | Família arredondada (estilo SF) | Material Symbols *outlined*/*rounded* |
| Fonte | Sistema (SF Pro) | Sistema (Roboto) |
| Permissões | Só na hora de usar, com explicação antes | Igual; seletor de fotos sem permissão de armazenamento (tira o pedido da abertura) |

### 15.4 iPad e telas largas

Barra lateral com as abas e as áreas de Serviços; conteúdo em duas colunas
(lista à esquerda, detalhe à direita) em Serviços, Avisos e Contracheques;
nunca um detalhe vazio ("Escolha um item"). Atalhos de teclado: `⌘F` busca,
`⌘1`–`⌘4` abas, `⌘R` atualizar. Testar em Split View 1/3, 1/2 e 2/3 (as duas
rejeições por crash foram em iPad, §16). Corrige a pendência das dicas no
tablet (§32).

### 15.5 Movimento e microinterações

- Troca de aba: esmaecer 180 ms. Abrir função: transição da plataforma (iOS
  desliza, Android 3.x *shared axis*).
- Card que vira tela (contracheque): *container transform* 300 ms.
- Busca: resultados entram em cascata curta (40 ms entre itens, no máximo 6).
- Atalhos em modo editar: tremor leve só no iOS; arrastar para reordenar com
  háptico.
- Folha de bloqueio: 240 ms `easeOutCubic`.
- Números do herói contam até o valor só na primeira exibição.
- Tudo desligado com "Reduzir movimento".

---

## 16. Fases de implementação

Cada fase termina com o app funcionando, `flutter analyze` limpo, teste no
simulador (iPhone e iPad) e no emulador Android em modo vitrine, e revisão do
usuário antes da próxima.

| Fase | Entrega | Fatias (cada uma ≤ 5 arquivos) | Riscos |
|---|---|---|---|
| **0. Fundação** | Nada muda na tela | `ApiClient` + `FalhaApp`; log local + `log.php` + tabelas; sonda de saúde dos serviços (`soupm_saude`, mapa de conexões do Painel); códigos de erro em `soupm_config` (`erros`); `Sessao` com armazenamento seguro (senha sai do SharedPreferences); captura global de erros; registro de módulos | Migrar a sessão guardada sem deslogar ninguém (ler o antigo, gravar no novo, apagar o antigo). `log.php` lento atrasando o app (envio sempre em segundo plano) |
| **1. app_config** | API decide | `soupm_menu_item` com carga igual ao app de hoje; `app_config.php` (público e logado); app lê, guarda e usa padrões; versão por plataforma | Carga inicial diferente do app atual muda o que o militar vê: comparar item a item. PostgreSQL 9.6 (sem alguns recursos) |
| **2. Navegação nova** | Abas, Serviços, Início, comandantes compactos, iPad | shell com navegador por aba; Serviços e áreas; nova Início (sem personalizar ainda); folha de bloqueio; barra lateral do iPad | Push que abre rota precisa achar a aba certa. Telas antigas que assumem o navegador raiz. Rejeição da Apple por iPad: testar em iPad Air 11" (onde a Apple revisou) |
| **3. Busca e feedback** | Busca e "Sugestões e problemas" | índice e tela de busca; `feedback.php` e as tabelas de feedback; "Minhas mensagens"; tela Feedback no painel (P3) | Anexo grande em rede ruim: envio com progresso e retomada |
| **3b. Contracheque na API** | PDF do contracheque gerado no servidor | `contracheque_pdf.php` com conferência e hash; padrão em `soupm_documento_padrao`; grupo "Documentos" do painel (casa com esta fase); app passa a pedir o PDF pronto; eventos `contracheque.pdf_*` | PDF diferente do de hoje: comparação página por página antes de trocar. Carga no dia da folha: cache por mês |
| **4. Fora do Firebase** | Só FCM | `notificacoes.php` e `dispositivo.php`; Avisos lendo do Postgres; envio FCM pelo PHP; conteúdo da Início pelo `app_config`; escrita dupla | Perder notificação na troca: escrita dupla e conferência por contagem. Conta de serviço do FCM no servidor (fora da pasta pública) |
| **5. Níveis e papéis pelo painel** | Fim do `isSuperUser` | níveis e papéis calculados no servidor (seção 6.5); módulo `soupm` na ACL da intranet; endpoints de gestão conferem nível e escopo. **O login pela intranet não entra aqui: vai para a 2.3** (seção 6.6) | Depende da sessão "Chat Intranet". Quem hoje é gestor perder acesso: comparação obrigatória no painel e lista revisada pelo usuário |
| **6. Acabamento** | Bonito e acessível | migração das telas grandes para `features/`; esqueletos; movimento; Dynamic Type; leitor de tela; contraste nos dois temas | Escopo grande: limitar às telas mais usadas (log da fase 0 mostra quais) |
| **7. Lançamento 2.2.0** | Lojas | versão nos três arquivos; capturas novas em todos os tamanhos (§31–32); "O que há de novo" separado por loja; TestFlight em iPhone e iPad físicos (§1) | Mudança grande de navegação confunde quem já usa: vídeo tutorial (§33) e um cartão "Conheça o novo SouPM" na primeira abertura |

**Paralelismo possível** (sessões separadas, como o usuário prefere): a API
(fases 1 e 4, em `~/code/api-soupmrr`) anda junto com o app (fases 0 e 2),
porque o contrato do `app_config` fica fixado antes. A fase 5 depende da
intranet.

---

## 17. Decisões que dependem do usuário

**Todas as decisões do plano foram tomadas** (20 e 21/10/2026):

- Ordem da Início, "Suas pendências", atalhos em duas linhas, Comando que se
  expande, central de comunicados no padrão aprovado; ciência só quando o
  painel pedir; urgente e ciência separados.
- Abas Início · Serviços · Avisos · Perfil, com a seção Configurações em
  Perfil. Nome continua **SouPMRR**.
- Níveis: os 5 da carga inicial, todos configuráveis no painel (seção 6.5);
  diretores e Corregedor no Alto Comando; nível vindo do SIGRH; só o militar
  comum não vê o Mapa da Força; todo gestor vê a ficha do próprio escopo.
- Papéis: Administrador (configura, reseta senha, publica comunicados no
  início) e Publicar comunicados (delegável depois).
- Feedback vai para um módulo do painel; SISCHAMADOS só para suporte; aba
  Avisos só com notificações do SouPMRR.
- Login pela intranet planejado agora e implementado na **2.3** (seção 6.6).
- Pendências: catálogo completo, todos os tipos desligados no início.
- Corte do Firestore pelo critério da seção 13; personalização da Início salva
  no servidor; versões Android e iOS separadas.
- Correções de segurança da API: em andamento numa sessão própria.
- Painel web: planejado numa sessão própria, junto com o app.

**Decididas por último** (21/10/2026; detalhes no PAINEL_ADMIN §11): push dos
módulos da intranet pela API do SouPMRR; reset de senha por código no e-mail
(o login continua como está até a 2.3); comunicado editado mantém a ciência;
anexos de feedback por 180 dias, só o Administrador vê; logs 180 dias e erros
1 ano; painel em `/painelsoupmrr`; Comando e cursos lidos do SIGRH; bancos e
conexões no painel; declarações por campanha; só o papel Administrador, com os
administradores que o SIGRH já indica; catálogo de ícones, imagens, paleta e
fontes de dados na 2.2.

**Fora da 2.2, como evolução futura e opcional:** a "fábrica de funções"
(blocos de tela fixos no app combinados pelo painel com fontes de dados, por
exemplo para os boletins do SABER). Decisão do usuário: **funções novas
continuam saindo em versão nova do app**, desenvolvidas e testadas. Se um dia
for feita: blocos versionados no app, intermediário na API (o app nunca fala
direto com o sistema), ações e assinatura escritas uma vez, rascunho → piloto
→ publicada, e as regras 2.5.2 da Apple e de código executável do Google Play.

**Não há decisão pendente.**
