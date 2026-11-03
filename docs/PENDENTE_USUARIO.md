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
- Campanhas de declaração **desligadas** até a administração lançar uma.

---

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
| **Cap Stenio** | PIN dentro do Sou PM, esconder "Sair deste aparelho", devolver a fila órfã, matrícula de teste escalada | `docs/PEDIDO_OPERAR_DENTRO_DO_SOUPM.md`, `docs/OPERACOES_PARA_FECHAR.md` |
| **Nós (SSH no servidor do Operar)** | Notificar todos os cenários do Operar pelo Sou PM (escala, dispensa, permuta, mensagem, documento…) e deixar os tipos urgentes furarem o silêncio das 22h às 06h. Os 22 tipos já estão liberados no módulo `operar` desde 03/11 | `docs/PEDIDO_NOTIFICACOES_OPERAR.md` |
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
