# Notificações do Operar pelo Sou PM: todos os cenários

**Data:** 03/11/2026
**Quem faz:** a própria equipe do Sou PM, pelo acesso SSH ao servidor do
Operar (decisão do Lucas, 03/11/2026). Não é mais pedido a terceiro.

**Regra que saiu da aplicação do r17 e vale para tudo aqui:** antes de alterar
um arquivo do Operar, conferir em qual seção do `MANIFESTO-SHA256.txt` ele
está. Seção 2 (os 18 trocados pelo pacote) **para a instalação** do pacote
seguinte; seção 3 (os 27 de referência) só **avisa**. O que der para fazer fora
da árvore deles — como o vigia da escala — é feito fora.

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
| 5 | Aviso pessoal (`autoriza._avisa_militar`): dispensa, permuta, mudança de escala, digital substituída, encerramento antecipado, novo documento, avisos ao chefe | **o texto real do aviso**, com título próprio (03/11) | `avisos` | `alteracao` |
| 6 | Chamada (urgente) | — | `chamada` | **não passa pelo Sou PM**: só Web Push, por decisão da coordenação |
| 7 | **Novo endereço do sistema** (`aviso_link.py:115`) | "Novo endereço do sistema" | (url) | `aviso` |
| 8 | Teste (`push_web.teste`) | "Teste de notificação" | `mais` | `aviso` |
| 9 | **Militar lançado numa escala** | "Você foi escalado" | `inicio` | `escalado` |

**Medido no código instalado em 03/11/2026, não lido de documento.** Todas as
notificações passam por **um portão único**, no `_processa0` do `push_web.py`:

```python
if soupm_push.ligado() and job.get("url") != "?abrir=chamada":
    return _processa_soupm(job, mats)
```

Tudo que chama `push_web.avisar` vai para o Sou PM; só a chamada de voz é
exclusão deliberada. Não existe caminho paralelo mandando push por fora.

**Os três problemas, e onde cada um está em 03/11/2026:**

1. ~~**O aviso pessoal não diz o que aconteceu.**~~ **RESOLVIDO em 03/11.** O
   texto já era específico (`"Você foi ESCALADO em …"`, `"Você foi PERMUTADO: …"`,
   `"A sua digital foi SUBSTITUÍDA…"`) e era **descartado na saída**. Agora o
   `push_web.py` lê o texto do próprio aviso, **depois** da confirmação de
   commit, e o põe no corpo do push, com título por padrão de texto. Uma
   mudança consertou sete cenários; nenhum chamador foi tocado. Detalhe em
   `/root/backup_dti_push_texto_20261103_103415/RELATORIO.md` no servidor.
2. **O tipo se perde — mas a causa não é a tupla `TIPOS`.** Ampliar a tupla do
   `soupm_push.py` sozinha não muda nada: `avisar(..., tipo=None)` é o padrão e
   **seis dos sete chamadores não passam tipo**, então tudo vira `aviso` antes
   de chegar lá. O conserto é passar o tipo em **cada chamada**. (Do lado do
   Sou PM os 22 tipos já estão aceitos: medido no banco em 03/11.)
3. **A escala não notifica sozinha** — contornado em 03/11, **sem tocar no
   `escala.py`**, e a medição de 03/11 confirmou que essa foi a escolha certa:
   o caminho de dentro alcançaria **18 militares a mais** (os que têm assinatura
   de Web Push e não têm o Sou PM; 1.505 têm o Sou PM), ao custo de **parar a
   instalação de todo pacote futuro**, porque o `escala.py` é seção 2 do
   manifesto. A chamada de três linhas está pronta em
   `api-soupmrr/operar/propostas/escalado_nativo.py.txt`, para o GAPE
   incorporar — aí não há divergência nunca mais. Medição inteira em
   `api-soupmrr/operar/relatorios/2026-11-03_vigia_ou_nativo.md`. O `escala.py` é um dos 18 arquivos que os pacotes do GAPE
   substituem (seção 2 do `MANIFESTO-SHA256.txt`): alterá-lo faria a
   pré-validação do próximo pacote **parar**. Em vez disso, um vigia da DTI em
   `/opt/dti-soupm/aviso_escala.py` lê a tabela `lancamento` e chama o
   `push_modulo.php` com tipo `escalado`. Marca d'água no maior id existente,
   então **nada do que já estava escalado é notificado**; e ele se cala quando
   o militar já recebeu o aviso pessoal daquele lançamento (permuta,
   movimentação, dispensa), para não avisar duas vezes. Documentação em
   `/opt/dti-soupm/LEIA-ME.md`. Ainda falta: **sair** da escala
   (`desescalado`) e o lembrete de apresentação.

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

**Buraco achado em 03/11, ainda aberto:** a substituição feita pelo
`setor.py` (quem sai / quem entra) **não avisa ninguém** — o arquivo tem zero
referências a `push_web`. Quem entra o vigia pega (é um `lancamento` novo);
**quem sai não é avisado por nada**. O `setor.py` está **fora do manifesto**,
então consertar não custa divergência nenhuma. Ficou fora do escopo de hoje
("somente novas escalas"), e é o próximo item.

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
  **Decidido pelo Lucas (03/11/2026) e FEITO no mesmo dia:** os tipos urgentes
  furam o silêncio. A lista fica no cadastro do módulo
  (`soupm_push_modulo.tipos_urgentes`), não fixa no código, e o pedido registra
  `furou_silencio`. Junto saiu um defeito real: o `agendado_para` saía como
  carimbo pelado e o Postgres o lia como −03, então o que devia sair 06:00 em
  Roraima saía 05:00. Corrigido com o `P` do `format()`.
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
