# O que está pendente — SouPM

Lista do que ainda falta fazer e do que depende do usuário ou de terceiros:
login, senha, decisão ou servidor.

Limpa em 31/10/2026. As listas de antes (SQL já rodados, "onde paramos", o
contracheque de outubro, o crash ao fechar no iPhone) estão no histórico do
git. A medição das fontes de nível no SIGRH foi para
`docs/MEDICAO_NIVEIS_SIGRH.md`.

## Situação em 31/10/2026

- **2.3.0** publicada nas duas lojas. **Mínima e recomendada são 2.3.0** no
  Android e no iOS. No Firestore, `min_version = 2.3.0` foi gravado pelo
  usuário, então as 2.1.x também pedem atualização. Por isso o cron
  `versao_legada.php` não é mais necessário.
- No ar e ligado:
  - contracheque em PDF montado pela API, para todos;
  - níveis de acesso;
  - 5 pendências do SouPMRR;
  - push pela API (FCM v1);
  - central de comunicados (`comunicados.fonte_app = api`).
- Comunicado nº 3, "Operação Expoferr 2026": modo cartaz, aparece ao abrir o
  app e abre Operações.

**Medido em 03/11/2026, 11h20** (retrato, não verdade permanente — a consulta
para refazer está em `api-soupmrr/operar/relatorios/2026-11-03_estado_medido.md`):

| | |
|---|---|
| Militares com aparelho registrado | **1.503** (1.552 tokens ativos) |
| Fila de push | 350 envios, **todos `concluido`**, nada travado |
| Pendências | 37 cadastradas, 5 confirmadas, **5 ligadas** |
| Ainda no Firestore | a aba Avisos (`notificacoes.fonte_app = firestore`) e a escrita dupla |

O histórico de notificações **não foi importado**: as 350 linhas de
`soupm_notificacao` são só as novas, de 30/10 para cá. A saída do Firestore
continua sendo o item aberto da seção 1a.
- Campanhas de declaração **desligadas** até a administração lançar uma.

---

## Operar: o que a DTI fez em 03/11/2026

Com o acesso SSH, a DTI passou a aplicar as atualizações e a mexer no Operar.

| O quê | Onde fica o registro |
|---|---|
| **r17 aplicado** (18 arquivos, chave `apresentacao`, UPDATE de 18 postos, DELETE de 6 escalas vazias, reinício das duas unidades) | `/root/backup_r17_20261103_095649/RELATORIO.md` |
| **Aviso pessoal com o texto real** (`push_web.py`): 7 cenários deixaram de chegar como "Aviso novo" | `/root/backup_dti_push_texto_20261103_103415/RELATORIO.md` |
| **Vigia do lançamento na escala** (`/opt/dti-soupm/aviso_escala.py`) — **desligado no mesmo dia**, quando o aviso passou para dentro do Operar; fica como reserva | `/opt/dti-soupm/LEIA-ME.md` |
| **"Você foi escalado" dentro do Operar** (`escala.py` → `push_web.escalado`): alcança Sou PM **e** Web Push | `api-soupmrr/operar/mudancas/README.md` |
| **Substituição deixou de ser muda** (`setor.py`): quem sai e quem entra passam a ser avisados | idem |
| **`conferir_mudancas.sh`**: confere as 7 marcas da DTI no Operar; sai 1 se um pacote apagou alguma | idem |

**Regra do usuário (03/11/2026): antes de lançar uma atualização do Operar,
sempre conferir incompatibilidades.** Não é ritual: foi o passo 1 do roteiro do
r17 que provou, por SHA-256, que os 18 arquivos no servidor eram exatamente os
do r15 e que não havia nenhuma modificação local nos outros 27. Sem essa
conferência, uma mudança nossa teria sido sobrescrita em silêncio — e é
exatamente o que vai acontecer com o `push_web.py` se um pacote futuro o
incluir sem avisar.

**Regra que nasceu daí:** antes de alterar arquivo do Operar, ver em que seção
do `MANIFESTO-SHA256.txt` ele está. Seção 2 (os 18 do pacote) **para** a
instalação seguinte; seção 3 (os 27 de referência) só **avisa**. O
`push_web.py` está na 3 — por isso foi alterado; o `escala.py` e o
`app_campo/app.js` estão na 2 — por isso o vigia ficou fora da árvore deles.

**Pedir ao GAPE:** incorporar a mudança do `push_web.py` no código-fonte dele,
ou avisar quando esse arquivo entrar num pacote, senão ela é sobrescrita em
silêncio. **E incorporar a chamada de três linhas do "escalado"** no
`escala.py` deles (pronta em `api-soupmrr/operar/propostas/escalado_nativo.py.txt`):
é o que faria o aviso nascer dentro do Operar, alcançando também quem usa a PWA
no navegador. Nós **não** mexemos nesse arquivo porque ele é seção 2 e a
medição de 03/11 mostrou que o ganho são **18 militares** (os com Web Push e
sem o Sou PM; 1.505 têm o Sou PM) contra parar a instalação de todo pacote
futuro — a conta inteira está no APRENDIZADOS §54 e em
`api-soupmrr/operar/relatorios/2026-11-03_vigia_ou_nativo.md`.

**Buraco medido e ainda aberto, de graça:** a substituição feita pelo
`setor.py` (quem sai / quem entra) **não avisa ninguém** — o arquivo tem zero
referências a `push_web`. Quem entra o vigia pega (é um `lancamento` novo);
**quem sai não é avisado por nada**. E o `setor.py` está **fora do manifesto**
(o pacote nem troca nem confere), então consertar não custa divergência
nenhuma. Ficou fora do escopo de 03/11, que o usuário limitou a "somente novas
escalas".

## 1. Próxima versão do app

| Item | O que fazer |
|---|---|
| **Mapa da Força: segurança** | Os cinco endpoints de `sigrh/mapadaforca/` respondem a qualquer um que tenha o endereço; os níveis só escondem o menu. O app passa a mandar matrícula e senha, e a API passa a conferir `soupm_e_gestor`. É o primeiro item da próxima branch (`feature/mapa-da-forca`) |
| **Sair do Firestore** | Ver a seção abaixo. O **FCM fica**, porque é ele que entrega o push. Sai só o **Firestore** (banco) |
| **Nível por função ou lotação no SIGRH** | A fonte existe e foi medida (`docs/MEDICAO_NIVEIS_SIGRH.md`). A decisão do usuário foi estudar antes de montar a regra |

### 1a. Centralizar na nossa API (decisão do usuário, 01/11/2026)

O app fala com o **mínimo de serviços possível**. O que for dado ou
configuração passa pela nossa API em `pmrr.online` (`/flutter/sigrh/`), que
lê do nosso banco. A regra está no CLAUDE.md.

**Sair do Firestore.** Fica no app só `firebase_core` + `firebase_messaging`
(FCM, entrega do push); sai o pacote `cloud_firestore`. Os quatro usos da
2.3.0, todos com substituto na API já pronto:

| Uso no app | Arquivo | Vai para |
|---|---|---|
| Lista da aba Avisos (lida e não lida) | `lib/services/notification_service.dart` | `notificacoes.php`. Antes: no cPanel, `php ~/public_html/flutter/sigrh/cron/exportar_firestore.php` (só conta), depois com `--gravar`; então `notificacoes.fonte_app = api` e ligar o lembrete de contracheque (o aviso de contracheque ainda sai pela Cloud Function) |
| Token do push gravado em `militares/{m}` | `lib/models/auth_model.dart`, `lib/main.dart` | Só `dispositivo.php` (`soupm_dispositivo`), que o app já chama |
| Comando e dicas da Início quando o painel não tem nada aprovado; carrossel antigo | `lib/features/inicio/faixa_comando.dart`, `lib/widgets/widget_dicas_app.dart`, `lib/widgets/carouselSlider.dart` | Só o `app_config` (sem nada aprovado, o bloco some) |
| `min_version` quando o app não leu o `app_config` | `lib/pages/auth_or_home.dart` (`_checkVersionFromFirestore`) | Só o `app_config` e a cópia guardada |

Depois que a versão nova for a mínima nas duas lojas, no servidor:
1. `notificacoes.escrita_firestore = false`.
2. O `envio_push.php` para de usar os tokens do Firestore como reserva.
3. Desligar as Cloud Functions (`notificarTodos`, `notificarMilitar`, `notificarEscala`).
4. Deixar o Firestore só para leitura por 30 dias e então apagar.

**Outros serviços que o app ainda chama direto:**

| Serviço | Hoje | Proposta |
|---|---|---|
| Legislações e POPs | `pm.rr.gov.br/api/legislacoes.php`, com a chave compilada no app (APRENDIZADOS §3 e §41) | Endpoint na nossa API que repassa o pedido com a chave guardada no servidor. A chave sai do `env.json` e do binário |
| Fotos dos militares | `rh.pmrr.online/_lib/file/img/wc2/pix_db/...` (ficha, Mapa da Força) | Avaliar uma rota da API que entrega a foto conferindo quem pede: hoje a foto é pública para quem tem o endereço |

Ficam como estão, porque são sistemas próprios: o Operar
(`operar.pmrr.online`, do Cap Stenio), a intranet e o SISCHAMADOS (fase da
intranet) e os links das lojas.

## 2. Esperando terceiros

| Com quem | O quê | Documento |
|---|---|---|
| **GAPE / nós, com cuidado** | PIN dentro do Sou PM, esconder "Sair deste aparelho", devolver a fila órfã, matrícula de teste escalada. Com o SSH isto passou a ser possível do nosso lado, **mas mexe no `app_campo/app.js`, que é um dos 18 arquivos trocados pelos pacotes** (seção 2 do manifesto): alterá-lo faz a pré-validação do pacote seguinte **parar**. Ou o GAPE incorpora, ou combinamos antes | `docs/PEDIDO_OPERAR_DENTRO_DO_SOUPM.md`, `docs/OPERACOES_PARA_FECHAR.md` |
| **Nós (SSH no servidor do Operar)** | **Feito em 03/11:** o aviso pessoal passou a levar o texto real (7 cenários de uma vez) e um vigia da DTI notifica quem é lançado numa escala. **Também feito em 03/11:** o tipo é deduzido da etiqueta no próprio `push_web` (um lugar, em vez de 7 chamadores), e os tipos urgentes furam o horário de silêncio (`soupm_push_modulo.tipos_urgentes`, no cadastro, não no código) — junto saiu um defeito real: o `agendado_para` saía como carimbo pelado e o Postgres o lia como −03, então o que devia sair 06:00 em Roraima saía 05:00. **Falta:** os disparos que não existem (`desescalado`, lembrete de apresentação, presença, falta, atestado, viatura, pagamento) | `docs/PEDIDO_NOTIFICACOES_OPERAR.md` |
| **Teste com escala** | GPS do "Cheguei", foto de alteração e "Assumir viatura": só aparecem para quem está escalado | `docs/OPERACOES_PARA_FECHAR.md` §2 |
| **DTI** | `apple-app-site-association` e `assetlinks.json` em `pmrr.online/.well-known/` (conferido em 31/10: os dois **404**). Sem eles, o QR da viatura e o chip NFC abrem no navegador | — |
| **DBA** | `ALTER FUNCTION public.soupm_conta_resumo(text) OWNER TO <usuário que lê qra>;`. A conta do cPanel não lê `qra`. Sem isso, a tela Militares do painel mostra a conta como indisponível | — |

## 3. Depois, com a intranet

Login único (2.3 da intranet, `SOUPM_2_2` §6.6), Minhas escalas, SVI, Meus
chamados (SISCHAMADOS) e Notícias e agenda (P7). Todos aparecem no app como
"Em breve", com a folha de bloqueio. Para o SISCHAMADOS:

1. Criar a chave do app "SouPM" na intranet, em SISCHAMADOS › Configurações ›
   API Mobile.
2. Pôr a chave no `env.json` (`SISCHAMADOS_APP_CHAVE`), com cópia no Drive.
   Nunca no git.
3. Liberar `atend.chamados` no painel.

## 4. Opcional

- **Cron de alertas do painel** (`database/avaliar_alertas.php`): não é
  necessário. O painel aberto avalia os alertas a cada 15 s. O script é da
  época da intranet e não roda no servidor do painel como está; só vale
  reescrever se alguém quiser alerta com o painel fechado.
- **Pasta `sigrh/documentos/` no servidor**: sobra de uma tentativa (o
  servidor bloqueia esse nome). Pode ser apagada pelo cPanel; o que vale está
  em `sigrh/doc/`.
- **Contracheque pela API**: se o PDF der erro para alguém, o app mostra o erro
  com código e não volta para o PDF montado no aparelho. Para voltar,
  desligar em Documentos › Contracheque.

---

## Referência

### Como rodar SQL de produção

Os SQL ficam em `~/code/api-soupmrr/sql/` (repositório privado
`lucassilva82/api-soupmrr`). O usuário roda no phpPgAdmin do cPanel, com o
login dele:

1. Desmarcar "Paginar resultados".
2. Testar antes num Postgres local, se mexe em várias peças (APRENDIZADOS §19
   e §47).
3. Depois de rodar, conferir o dono das funções (§46).

### Crons no cPanel (rodando)

`sonda` (a cada minuto), `envio_push` (a cada minuto), `reset_senha` (a cada
minuto), `comando_sigrh` (a cada minuto; confere uma vez por dia),
`lembretes` (08:00), `cron_log` (02:10). Logs em `~/logs/`.

### Arquivos em `~/private` no servidor

`config_painel.php` (segredo dos links assinados painel ↔ API),
`soupm_fcm.json` (conta de serviço do FCM), `config_sonda.php` (alvos da
sonda). Nunca no git.

### Ao publicar uma versão: avisar o painel

O painel não lê as lojas, então só sabe o que foi publicado se alguém
registrar. Ao publicar:

1. Registrar a versão em `soupm_versao_app`, com a ficha técnica do build.
   Hoje é por SQL, porque o painel não tem formulário para isso.
2. Ajustar a recomendada em Versões do app.
3. Subir a mínima só quando for preciso obrigar todo mundo a atualizar. O
   painel mostra quantos aparelhos passam a ver a tela obrigatória antes de
   salvar.

O `min_version` do Firestore é o que as 2.1.x leem. Ele nunca pode ficar acima
da versão publicada em cada loja. Se ficar, o iPhone pede uma versão que a App
Store não tem.

### Modo automático do Claude Code

Publicar mudança no painel de produção precisa de autorização do usuário
**na própria sessão**. Mensagem vinda de outra sessão não vale.
