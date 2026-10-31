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
| **Avisos lidos pela API** | Hoje o push já sai pela API, e cada aviso é gravado também no Firestore (`escrita_firestore`). A aba Avisos ainda **lê** do Firestore (`notificacoes.fonte_app = firestore`). Para trocar: no terminal do cPanel, `php ~/public_html/flutter/sigrh/cron/exportar_firestore.php` (só conta) e depois com `--gravar`; então `fonte_app = api` e ligar o lembrete de contracheque (senão o aviso de contracheque, que ainda sai pela Cloud Function, some da aba). Depois disso: desligar as Cloud Functions e a escrita no Firestore |
| **Nível por função ou lotação no SIGRH** | A fonte existe e foi medida (`docs/MEDICAO_NIVEIS_SIGRH.md`). A decisão do usuário foi estudar antes de montar a regra |

## 2. Esperando terceiros

| Com quem | O quê | Documento |
|---|---|---|
| **Cap Stenio** | PIN dentro do Sou PM, esconder "Sair deste aparelho", devolver a fila órfã, push do Operar pelo `push_modulo.php`, matrícula de teste escalada | `docs/PEDIDO_OPERAR_DENTRO_DO_SOUPM.md`, `docs/PEDIDO_PUSH_OPERAR.md`, `docs/OPERACOES_PARA_FECHAR.md` |
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
