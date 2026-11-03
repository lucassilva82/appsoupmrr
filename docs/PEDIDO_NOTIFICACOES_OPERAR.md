# Notificações do Operar pelo Sou PM: todos os cenários

**Data:** 03/11/2026
**Quem faz:** a própria equipe do Sou PM, pelo acesso SSH ao servidor do
Operar (decisão do Lucas, 03/11/2026). Não é mais pedido ao Cap Stenio.

Pedido do Lucas: **toda mudança que afeta o militar deve chegar como
notificação no Sou PM.** Isso inclui escala, dispensa, permuta, mensagem e
documento.

Do lado do Sou PM, os tipos abaixo **já estão liberados** no módulo `operar`
desde 03/11/2026, no painel, em Notificações › Configuração › Módulos. Basta o
Operar mandar o `tipo` certo, pelo mesmo contrato do
`PEDIDO_PUSH_OPERAR.md`. Nada do contrato muda.

---

## 1. O que chega hoje (r15, conferido no código)

| # | Quando | Título | Abre | Tipo enviado |
|---|---|---|---|---|
| 1 | Comunicado geral novo | "Comunicado do {nome}" | `comunicados` | `aviso` |
| 2 | Mensagem direta nova | "Nova mensagem de {nome}" | `conversa` | `aviso` |
| 3 | Documento recebido ou encaminhado | "Documento recebido" | `encaminhar` | `aviso` |
| 4 | Documento despachado | "Documento despachado" | `encaminhar` | `aviso` |
| 5 | Aviso pessoal (`autoriza._avisa_militar`): dispensa, permuta, mudança de escala, digital substituída | "Aviso novo", com texto fixo | `avisos` | `alteracao` |
| 6 | Chamada (urgente) | — | `chamada` | **não passa pelo Sou PM**: só Web Push, por decisão da coordenação |
| — | "Você foi escalado: Expoferr 2026" | envio único por script em 02/11, não automático | `inicio` | `escalado` |

**Três problemas no que existe hoje:**

1. **O aviso pessoal não diz o que aconteceu.** Dispensa autorizada, dispensa
   negada, permuta e mudança de escala chegam todas como "Aviso novo. Você tem
   um aviso novo no app". O militar só fica sabendo do que se trata se abrir o
   app.
2. **O tipo se perde.** O `soupm_push.py` troca qualquer tipo que não esteja
   na tupla `TIPOS` por `aviso`. Para os tipos novos chegarem, é preciso
   ampliar essa tupla.
3. **A escala não notifica sozinha.** Ser escalado, sair da escala ou ter o
   posto ou o horário mudados não gera notificação automática. O envio de
   02/11 foi feito à mão.

## 2. Todos os cenários que devem notificar

Os tipos já estão liberados no Sou PM. As colunas "Título" e "Mensagem" são
sugestões, sem CPF e sem texto de atestado.

### Escala

| Cenário | Tipo | Título | Mensagem (exemplo) | `abrir=` |
|---|---|---|---|---|
| Foi escalado | `escalado` | Você foi escalado | Expoferr 2026, Portão 2, 03/11, das 18h às 23h. | `inicio` |
| Saiu da escala | `desescalado` | Você saiu da escala | O serviço de 03/11 (18h às 23h) foi retirado da sua escala. | `inicio` |
| Mudou posto, horário ou função | `alteracao` | Sua escala mudou | 03/11: agora Portão 4, das 19h às 23h. | `inicio` |
| Remanejado por um chefe ("Mover para…") | `remanejamento` | Você foi remanejado | 03/11: do Portão 2 para o Portão 4, por {posto nome}. | `inicio` |
| Chamado como substituto | `substituicao` | Você vai substituir um colega | 03/11, Portão 2, das 18h às 23h. | `inicio` |
| Foi substituído | `substituicao` | Você foi substituído | O serviço de 03/11 passou para outro militar. | `inicio` |
| Lembrete de apresentação (ex.: 2 h antes) | `apresentacao` | Seu serviço começa às 18h | Apresentação no Portão 2. Toque em "Cheguei" ao chegar. | `inicio` |

### Pedidos (dispensa, permuta, mover)

| Cenário | Tipo | Título | Para quem |
|---|---|---|---|
| Dispensa autorizada | `dispensa` | Dispensa autorizada | quem pediu |
| Dispensa negada | `dispensa` | Dispensa não autorizada | quem pediu, com o motivo, se houver |
| Permuta proposta | `permuta` | {nome} quer trocar de serviço com você | o colega, que precisa aceitar |
| Permuta aceita ou recusada pelo colega | `permuta` | Permuta aceita / recusada | quem propôs |
| Permuta autorizada ou negada pela chefia | `permuta` | Permuta autorizada / não autorizada | os dois militares |
| Pedido aguardando autorização | `autorizacao` | Pedido aguardando você | o chefe que autoriza (dispensa, permuta, mover) |
| Pedido cancelado por quem pediu | `autorizacao` | Pedido cancelado | o chefe que ia autorizar |

### Presença e ocorrências

| Cenário | Tipo | Título | Para quem |
|---|---|---|---|
| Presença não registrada ("Cheguei" faltando) depois do horário | `presenca` | Registre a sua chegada | o militar |
| Falta registrada | `falta` | Falta registrada no serviço de 03/11 | o militar |
| Atestado recebido ou analisado | `atestado` | Atestado recebido / analisado | o militar (sem o conteúdo do atestado) |
| Digital substituída | `alteracao` | Sua digital foi substituída | o militar |
| Militar escalado não chegou | `presenca` | {nome} ainda não registrou chegada | o chefe da área |

### Comunicação e documentos

| Cenário | Tipo | Título | `abrir=` |
|---|---|---|---|
| Comunicado geral | `comunicado` | Comunicado do {nome} | `comunicados` |
| Mensagem direta | `mensagem` | Nova mensagem de {nome} | `conversa` |
| Mensagem em sala ou grupo | `mensagem` | Nova mensagem em {sala} | `conversa` |
| Documento recebido ou encaminhado | `documento` | Documento recebido | `encaminhar` |
| Documento despachado | `despacho` | Documento despachado | `encaminhar` |

### Viatura e pagamento

| Cenário | Tipo | Título |
|---|---|---|
| Viatura atribuída, transferida ou devolvida | `viatura` | Viatura VTR {prefixo} sob sua responsabilidade |
| Pagamento do TRE ou diária: situação mudou | `pagamento` | Pagamento do TRE atualizado |

### Fora do Sou PM por decisão

| Cenário | Tipo liberado | Situação |
|---|---|---|
| Chamada urgente | `chamada` | Liberado do nosso lado, mas **continua só no Web Push** até a coordenação decidir o contrário |

## 3. O que mudar no Operar (nós, por SSH)

1. **`soupm_push.py`:** ampliar `TIPOS` para a lista da seção 2. Hoje o tipo
   desconhecido vira `aviso`.
2. **`push_web.avisar(..., tipo=...)`:** passar o tipo em cada chamada. Os
   quatro primeiros disparos de hoje não passam tipo nenhum.
3. **`autoriza._avisa_militar`:** em vez de "Aviso novo", mandar título e
   mensagem do caso (dispensa autorizada, permuta proposta…), com o tipo
   próprio.
4. **Escala:** notificar automaticamente ao escalar, tirar da escala, mudar,
   remanejar e substituir.
5. **Novos disparos:** pedido aguardando o chefe, lembrete de apresentação,
   presença faltando, falta, atestado, viatura e pagamento.

Os textos vão como hoje: sem CPF, sem conteúdo de atestado e sem texto de
mensagem. Para mensagem, basta "Nova mensagem de {nome}".

## 4. Pontos a combinar

- **Horário de silêncio (22h às 06h):** vale para o módulo inteiro. Uma
  dispensa autorizada às 23h para um serviço às 05h só chegaria às 06h.
  **Decidido pelo Lucas (03/11/2026): os tipos urgentes furam o silêncio.**
  A fazer no `push_modulo.php` da API: uma lista de tipos que ignoram o
  silêncio, por exemplo `dispensa`, `alteracao`, `remanejamento`,
  `substituicao`, `desescalado`, `escalado` e `autorizacao`. A lista fica no
  cadastro do módulo, não fixa no código.
- **Limite:** hoje o módulo está sem limite prático, 1.000.000 por hora.
- **Duplicidade:** continua a regra do `PEDIDO_PUSH_OPERAR.md`. Primeiro vai
  para o Sou PM; o Web Push só entra se vier `SEM_APARELHO`.

## 5. Roteiro para fazer no servidor

1. Ler, só para conferir, `escala.py`, `autoriza.py`, `salas.py`,
   `comunicado_geral.py` e os demais pontos que chamam `push_web.avisar` em
   `/opt/operar-pmrr/operacoes/servidor/app/`. Montar a tabela final:
   cenário, função e linha.
2. Fazer backup dos arquivos que vão mudar em `/root/backup_<data>`, no
   mesmo padrão do r15 (`ANALISE_SERVIDOR.md` §9).
3. **Produção e homologação usam a mesma pasta de código.** Testar antes numa
   cópia local, com o servidor falso do teste (`ELEICOES_SOUPM_URL` em
   127.0.0.1).
4. Reiniciar o `operar-producao`, que fica parado uns 90 s, de preferência
   fora do horário de serviço. Depois reiniciar o `operar-homolog`.
5. Conferir no `soupm_push_pedido` que cada tipo novo chega como aceito,
   usando a matrícula de teste.
6. Registrar no `~/code/operar/ANALISE_SERVIDOR.md` §9, como foi feito no
   r15.
