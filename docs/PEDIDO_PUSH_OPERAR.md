# Notificações do Operar dentro do Sou PM — o que o Operar precisa fazer

**Para:** o responsável pelo OPERAR · PMRR
**De:** DTI / equipe do Sou PM
**Data:** 30/10/2026 · **atualizado em 03/11/2026**

> **03/11/2026:** a DTI passou a ter acesso SSH ao servidor do Operar e é quem
> aplica as atualizações. A parte "o que o Operar precisa fazer" deixou de ser
> um pedido a terceiro: é trabalho nosso. O contrato das seções 3 a 8 continua
> valendo como está — é ele que descreve a API do Sou PM.

---

## 1. O problema, em uma frase

O app de campo do Operar passou a ser aberto **dentro do Sou PM**, numa tela
interna (WebView). **WebView não recebe Web Push.** Então, hoje, nenhuma
notificação do Operar chega ao militar que entra por ali — nem com o app
aberto, nem com o app fechado.

Quem abre o `/app/` direto no navegador continua recebendo normalmente. Não há
nada quebrado no Operar; é limitação da tecnologia de WebView.

## 2. A solução, em uma frase

O Sou PM tem Firebase (FCM) e já sabe entregar notificação a um militar pelo
número da matrícula. **O Operar passa a pedir ao Sou PM que entregue**, em vez
de tentar entregar sozinho.

Do lado do Operar isso é **uma chamada HTTP**, no mesmo lugar onde hoje ele
dispara o Web Push.

O Operar **não precisa** de conta no Firebase, nem de chave do Google, nem de
guardar token de aparelho. Nada disso passa a existir do lado de lá.

---

## 3. O contrato

### Requisição

```
POST https://pmrr.online/flutter/sigrh/push_modulo.php
Content-Type: application/json
```

```json
{
  "modulo": "operar",
  "chave": "<o segredo do módulo>",
  "matricula": "0041096009",
  "tipo": "escalado",
  "titulo": "Você foi escalado",
  "mensagem": "Expoferr 2026 — Portão 2, dia 03/11, das 18h às 23h.",
  "rota": "/op/operacoes?abrir=inicio"
}
```

| Campo | Obrigatório | O que é |
|---|---|---|
| `modulo` | sim | sempre `operar` — é o módulo já cadastrado do lado de cá |
| `chave` | sim | o segredo do módulo (seção 7) |
| `matricula` | sim | a **matrícula curta, a que aparece na escala**, só dígitos: `45.295-5` → `452955`. Zeros à esquerda são ignorados. **Uma** por pedido: a notificação é individual, não por grupo |
| `tipo` | sim | um dos tipos aceitos (seção 5) |
| `titulo` | sim | o título da notificação, como o militar vê |
| `mensagem` | sim | o corpo da notificação |
| `rota` | não | para onde o toque leva (seção 4). Sem ela, abre o módulo na tela inicial |

### Resposta

```json
{"code": 1, "pedido_id": 123, "envio_id": 456, "agendado_para": null}
{"code": 1, "pedido_id": 123, "envio_id": 456, "agendado_para": "2026-10-31 06:00:00-04:00"}
{"code": 0, "erro": "SEM_APARELHO", "message": "..."}
```

`agendado_para` **nulo** = sai agora. Com data = aceito, mas guardado até
aquela hora (é o horário de silêncio, seção 5). A data vem **com o
deslocamento** (`-04:00`, Roraima) desde 03/11/2026: sem ele, o Postgres —
cuja sessão está em `Brazil/East` (−03) — lia a hora como se fosse −03 e
soltava o aviso às 05:00 em vez das 06:00. Nos dois casos a notificação
**será entregue**; muda só o quando. Nada é perdido por chegar de madrugada.

### Os motivos de recusa

| `erro` | O que significa | O que fazer |
|---|---|---|
| `DADOS_INVALIDOS` | falta campo ou formato errado | corrigir a chamada |
| `CHAVE_INVALIDA` | o segredo não confere | conferir a chave |
| `MODULO_DESCONHECIDO` | `modulo` não é `operar` | corrigir |
| `DESLIGADO` | o módulo foi desligado do lado de cá | avisar a DTI |
| `TIPO_RECUSADO` | `tipo` ausente ou fora da lista | ver seção 5 — o campo é obrigatório |
| `MATRICULA_DESCONHECIDA` | a matrícula não existe no cadastro da PMRR | quase sempre é **formato**: mande a curta, a da escala (`452955`), não a de dez dígitos interna do Operar |
| `LIMITE_HORA` / `LIMITE_DIA` | cota do módulo estourada | ver seção 5 |
| `SEM_APARELHO` | aquela matrícula não tem aparelho registrado | **normal**: o militar não usa o Sou PM, ou não entrou ainda. Não é erro |
| `ERRO_SERVIDOR` | falha do nosso lado | tentar de novo mais tarde |

**`SEM_APARELHO` e `MATRICULA_DESCONHECIDA` são coisas diferentes, de
propósito.** Antes de responder `SEM_APARELHO`, o Sou PM confere no SIGRH se a
matrícula existe. Então:

- `MATRICULA_DESCONHECIDA` = o número não é de ninguém. **Confira o formato.**
- `SEM_APARELHO` = a pessoa existe, mas não tem o Sou PM instalado e logado.

Sem essa separação, um erro de formato apareceria como "ninguém instalou o
app" — uma explicação plausível e falsa, que mandaria a investigação para o
lado errado.

**`SEM_APARELHO` vai acontecer bastante, e está certo.** Militar que não
instalou o Sou PM não tem para onde receber. Trate como resultado esperado, não
como falha — e, se o Operar ainda mantiver o Web Push, é exatamente o caso em
que ele deve ser usado (seção 6).

---

## 4. O campo `rota`: levar o militar à tela certa

O Sou PM abre o módulo Operações e, de dentro dele, a WebView carrega:

```
https://operar.pmrr.online/app/?abrir=<tela>&soupm=1
```

Ou seja: **o `abrir=` é o mesmo que o Operar já usa** na notificação de hoje. A
única diferença é que ele viaja dentro do campo `rota`:

```
"rota": "/op/operacoes?abrir=inicio"     →  /app/?abrir=inicio&soupm=1
"rota": "/op/operacoes"                  →  /app/
(sem o campo)                            →  /app/
```

Use os mesmos nomes de tela que o seu `?abrir=` já aceita. O Sou PM não
interpreta o valor: ele repassa inteiro.

**Por que não um campo separado:** o contrato de notificação do Sou PM tem três
campos fixos e nenhum bloco de dados livre, e ele já está publicado nas lojas.
Mudar o contrato obrigaria a tropa a atualizar o app antes de qualquer
notificação funcionar. A rota com query resolve sem mexer em nada publicado.

**Só sete nomes valem depois do `?abrir=`**, e a lista autoritativa está no
`app_campo/push.js:19` do Operar:

```js
var TELAS = { avisos: 1, conversa: 1, comunicados: 1, encaminhar: 1, mais: 1, inicio: 1, mapa: 1 };
```

O `abreTela(t)` **retorna sem fazer nada** quando o nome não está aí. Nome
inventado não dá erro, não entra em log e não aparece em teste: a notificação
chega, o militar toca e **nada abre** — ele cai na tela padrão e ninguém
descobre por quê. Aconteceu com a gente em 03/11: o vigia da escala nasceu com
`?abrir=escala`, que não existe. Para a escala, o nome certo é **`inicio`**, que
é onde o card do serviço aparece no app de campo. Rota nova pede tela nova no
`TELAS` e no `sw.js` (que valida com `^\?abrir=[a-z]+$`), do lado do Operar.

---

## 5. Tipos, limites e horário de silêncio

Já cadastrados do lado de cá, e conferidos no banco:

| | |
|---|---|
| **Tipos aceitos** (22) | `escalado`, `desescalado`, `alteracao`, `troca`, `permuta`, `dispensa`, `remanejamento`, `substituicao`, `apresentacao`, `presenca`, `falta`, `atestado`, `autorizacao`, `mensagem`, `comunicado`, `documento`, `despacho`, `viatura`, `pagamento`, `chamada`, `aviso`, `teste` |
| **Limite** | 1.000.000 por hora e por dia (do módulo inteiro, não por militar) — na prática, sem limite |
| **Silêncio** | 22:00 às 06:00, hora de Roraima (−04) |
| **Tipos que furam o silêncio** (10) | `escalado`, `desescalado`, `alteracao`, `remanejamento`, `substituicao`, `dispensa`, `permuta`, `troca`, `autorizacao`, `apresentacao` — saem na hora mesmo de madrugada, porque perdem o sentido às 06h. Os demais (mensagem, comunicado, documento, viatura, pagamento…) esperam o amanhecer |

> **Medido no banco em 03/11/2026.** Até 30/10 eram 5 tipos e 120/h; o painel
> ampliou para os 22 acima em 03/11, às 07:55. Esta tabela e o
> `sql/2026-11-03_push_modulo_operar_tipos.sql` da API são a mesma coisa; se
> divergirem, vale o banco (a consulta está no fim desta seção).

- **`tipo` é obrigatório.** Não há valor padrão: pedido sem `tipo`, ou com um
  fora da lista, é recusado com `TIPO_RECUSADO` e o motivo fica registrado.
  Acrescentar um tipo novo é uma linha no banco do nosso lado, sem publicar
  versão — basta pedir.
- **O limite é do módulo.** Com a cota atual (1.000.000/h) um comunicado para
  a tropa inteira passa sem esforço. Se um dia a cota voltar a ser apertada,
  o excedente volta como `LIMITE_HORA` e aquelas pessoas não recebem.
- **Para conferir a cota e os tipos de verdade**, sem acreditar em documento:
  `SELECT tipos, limite_hora, limite_dia, silencio_inicio, silencio_fim
   FROM soupm_push_modulo WHERE chave = 'operar';`
- **Horário de silêncio: adia, não descarta.** Pedido feito entre 22h e 6h é
  **aceito** (`code: 1`) e entregue às 06:00; a resposta traz
  `agendado_para` com a hora em que vai sair. Um "você foi escalado" disparado
  às 3h da manhã **não se perde** — chega quando o militar acordar.

---

## 6. Como conviver com o Web Push que já existe

O Web Push do Operar **continua funcionando** para quem abre o `/app/` no
navegador ou instalou a PWA. Nada precisa ser desligado.

A regra que sugerimos, para o militar não receber a mesma coisa duas vezes:

1. Se o militar tem assinatura de Web Push **e** o Sou PM aceitou o pedido
   (`code: 1`), ele pode receber duas notificações. Para evitar, escolha uma:
   - mandar primeiro para o Sou PM e, **só se vier `SEM_APARELHO`**, cair no
     Web Push; ou
   - manter os dois e aceitar a duplicidade para quem usa os dois caminhos.
2. Se a resposta for `SEM_APARELHO`, o Web Push é o caminho certo.

A primeira opção é a que entrega sem repetir, e usa o `SEM_APARELHO` como o
sinal que ele já é.

---

## 7. O segredo do módulo

- O segredo foi gerado pela DTI e **entregue ao Lucas**, que o repassa a você
  pelo canal que combinarem. No nosso servidor ficou guardado só o hash
  (SHA-256) — nem nós conseguimos lê-lo de volta.
- Do lado do Operar, guarde-o como os outros segredos do sistema: num arquivo
  fora da árvore pública, lido pelo processo, **fora do pacote de instalação** e
  fora de qualquer log.
  Cabe bem como uma variável no `/etc/operar/operar.env` (0600, root) ou um
  arquivo em `/etc/operar/segredos/`, no mesmo padrão da chave do SSO da Frota.
- **Nunca** no `env.exemplo`, no repositório, em e-mail ou em mensagem.
- Se vazar ou houver dúvida, peça a troca: a DTI gera outro e o antigo morre na
  hora.

---

## 8. Saída de rede

O Operar passa a precisar de saída HTTPS para:

```
pmrr.online:443
```

É o único destino novo. O `INSTALAR.md` (seção 1) tem a tabela de saídas do
sistema; vale acrescentar essa linha, com a observação de que, **se for
bloqueada, o efeito é só a notificação não chegar ao Sou PM** — nada mais do
Operar depende dela.

---

## 9. Onde isso entra no código do Operar

O lugar natural é o `servidor/app/push_web.py`, onde hoje nasce o envio VAPID.
A forma mínima:

1. Uma função que monta o JSON da seção 3 e faz o POST, com tempo limite curto
   (uns 10 s) e **sem** derrubar o fluxo se falhar — notificação que não sai não
   pode impedir o que a gerou (escalar, trocar, registrar).
2. Chamar essa função nos mesmos pontos em que hoje o Web Push é disparado.
3. Registrar no log **o resultado** (`code` e `erro`), a matrícula e a hora —
   **nunca** a chave, nunca o corpo inteiro da notificação.

Sugestão de desligamento rápido: uma variável de ambiente (por exemplo
`ELEICOES_PUSH_SOUPM=0|1`) que corte a chamada sem publicar versão nova, no
mesmo espírito do `ELEICOES_PUSH` que já existe.

---

## 10. Como testar

1. Matrícula de teste: **452955** (do Lucas, com o Sou PM instalado e logado).
   Use **uma** matrícula no primeiro disparo, nunca a tropa inteira.
2. Dispare um pedido só, tipo `aviso`, com `rota` apontando para uma tela que
   você queira conferir.
3. Esperado: `{"code": 1, ...}`, a notificação chega ao celular em segundos, e o
   toque abre o módulo Operações **já na tela que você mandou**, sem pedir
   login.
4. Se vier `SEM_APARELHO`, aquela matrícula não tem aparelho registrado —
   peça outra.
5. Se chegar a notificação mas o toque abrir a tela inicial do app de campo em
   vez da tela pedida, o problema está no valor do `abrir=`: ele precisa ser um
   nome de tela que o seu `/app/` já reconheça.

---

## 11. O que NÃO muda

- O Web Push de hoje continua como está.
- O Operar não ganha dependência de Firebase nem de Google.
- Nenhum dado pessoal novo sai do Operar: vão a matrícula, o título e a
  mensagem — os mesmos que já iriam na notificação.
- O login do módulo dentro do Sou PM não é afetado por nada disto.

---

## 12. Dois pontos a combinar

1. **Formato da matrícula.** Mande a mesma que o cadastro do Operar usa. Se não
   casar com a que o Sou PM guarda, o retorno é `SEM_APARELHO` **para todo
   mundo**, e o sintoma parece "ninguém instalou o app". Por isso o teste da
   seção 10 com **uma** matrícula real, antes de ligar para a tropa inteira.
2. **Volume previsto.** Se algum disparo seu for para centenas de militares de
   uma vez, diga o número antes, para a cota ser ajustada — senão o excedente
   volta como `LIMITE_HORA` e aquelas pessoas não recebem.

---

**Contato:** DTI / equipe do Sou PM, pelo Lucas.
