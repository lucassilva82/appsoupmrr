# O Operar dentro do Sou PM — o que falta do lado do Operar

**Para:** Cap Stenio — responsável pelo OPERAR · PMRR
**De:** DTI / equipe do Sou PM
**Data:** 30/10/2026

Este documento **complementa** o `PEDIDO_PUSH_OPERAR.md`, que trata só das
notificações. Aqui são quatro pedidos curtos: três mudanças no
`operacoes/app_campo/app.js` e uma matrícula de teste.

Os números de linha são os do pacote **r14 (28/10)**.

---

## O que já está funcionando

O módulo **Operações** está dentro do Sou PM e abre o seu app de campo numa
tela interna, em `/app/?soupm=1`. Testado hoje no iPhone, com conta real:

- **O militar não faz login no Operar.** O Sou PM pede o token de aparelho à
  nossa API e o planta antes de a sua página rodar. Quem abre o módulo cai
  direto na tela do app, já identificado.
- Escolha de evento, Documentos, abrir e baixar PDF: tudo funcionando.
- O `?soupm=1` que você criou está sendo usado e o banner "Você já está no
  Sou PM" aparece certo.

Nada do que pedimos abaixo muda o funcionamento para quem abre o `/app/` no
navegador ou pela PWA. É tudo condicionado ao `SOUPM`, que já existe no seu
arquivo (linha 29).

---

## 1. O PIN não deve ser pedido dentro do Sou PM

**Por quê.** O militar acabou de desbloquear o Sou PM — com senha, digital ou
rosto. Pedir um segundo PIN logo em seguida é uma tranca a mais na mesma
porta, e é a primeira coisa que ele vê ao tocar em "Operações". Hoje, quem
entra pela primeira vez cai em "Crie um PIN de 4 dígitos" antes de ver
qualquer coisa do Operar.

**Onde.** No `render()`, linhas 4159 e 4160:

```js
// hoje
else if (ler('token', null) && !ler('pin', null)) tela = S.tela = 'criarPin';
else if (ler('token', null) && !S.desbloqueado && tela !== 'criarPin') tela = S.tela = 'pin';

// pedido
else if (!SOUPM && ler('token', null) && !ler('pin', null)) tela = S.tela = 'criarPin';
else if (!SOUPM && ler('token', null) && !S.desbloqueado && tela !== 'criarPin') tela = S.tela = 'pin';
```

**Atenção a um detalhe:** pular as telas não basta. O `S.desbloqueado` segue
`false`, e ele é quem libera as abas (linha 4180) e várias telas. É preciso
nascer `true` dentro do Sou PM — por exemplo na linha 270
(`desbloqueado: false` → `desbloqueado: SOUPM`), ou logo depois de o `SOUPM`
ser calculado.

**O que NÃO pedimos:** mexer na linha 4158, a do `login`. Ela precisa
continuar valendo. Se a nossa API falhar — rede, senha da operação trocada —
o militar cai no seu login de matrícula, CPF e senha da operação, e é assim
que queremos. Falha nossa não pode deixar o militar de fora no dia da
operação.

Com isso, o "Esqueci o PIN" (linha 4445) sai junto, porque vive na tela de
PIN.

### Um efeito colateral que é seu para decidir

Sem PIN criado, o **"Autorizar por PIN"** do autorizador (linha 4076) passa a
recusar sempre: ele confere o `pin` local (`!pp` → "PIN do app incorreto"), e
dentro do Sou PM esse `pin` não vai existir.

Isso atinge só quem autoriza pedidos e usa esse caminho como plano B. Não
sabemos qual é o peso dele na prática — é o seu fluxo, você decide. Três saídas
que enxergamos:

- pedir o PIN **só ao autorizador**, na primeira vez que ele abre a tela de
  autorização dentro do Sou PM (não na entrada do app);
- dentro do Sou PM, autorizar só com a senha do sistema, já que o militar
  passou pelo desbloqueio do celular para chegar ali;
- deixar o plano B de fora do Sou PM e manter o método principal.

Se nenhuma servir, diga: o pedido 1 vale a pena mesmo com o PIN ficando para
os autorizadores.

---

## 2. "Sair deste aparelho" não pode aparecer dentro do Sou PM

**Por quê.** Dentro do Sou PM o militar entra com a matrícula dele e só pode
usar a conta daquela matrícula. O único "sair" é o do Sou PM — é regra da
DTI, para o acesso ao Operar ser sempre do dono da conta que logou.

E hoje **o botão não desloga de nada**: ele chama `limparAparelho()`, que
apaga os dados do aparelho; na abertura seguinte o Sou PM planta o token outra
vez. Resultado: o militar perde a escala guardada, a fila e o que estava
offline, e volta logado do mesmo jeito. É um botão que só faz estrago.

Confirmado hoje no iPhone, na versão **1.1.52-dti**: o botão vermelho aparece
em "Mais", abaixo de "O que este app não faz".

**Onde.** Linha 2377:

```js
// hoje
h += (MEUAPP ? '' : '<button class="btn red" id="bSair">Sair deste aparelho</button>') + ...

// pedido
h += (MEUAPP || SOUPM ? '' : '<button class="btn red" id="bSair">Sair deste aparelho</button>') + ...
```

É o mesmo que a linha 2368 já faz com o "Instalar na tela inicial".

---

## 3. Devolver a fila órfã também no caminho do Sou PM

**O problema.** O `entrar()` (linhas 4256–4269) é quem cuida do aparelho
compartilhado: quando a matrícula muda, põe de lado os registros não enviados
do dono anterior em `e26.filaOrfa[matrícula]` e devolve os do militar que
está entrando. Mas no Sou PM **o `entrar()` não roda** — o token é plantado
direto no `localStorage`, sem passar pelo `/acesso`.

**O nosso lado já faz a primeira metade.** Quando o aparelho troca de dono, o
Sou PM guarda a fila em `e26.filaOrfa`, na mesma chave e no mesmo formato que
o seu `entrar()` usa. Não apagamos registro de campo: é fato, não cache.

**Falta a devolução.** Na partida, com token já presente, se houver
`filaOrfa[matricula]`, concatenar na `fila` e remover a entrada — as mesmas
quatro linhas que já estão no `entrar()`:

```js
var guardadas = ler('filaOrfa', {});
if (guardadas[matricula]) {
  gravar('fila', fila().concat(guardadas[matricula]));
  delete guardadas[matricula]; gravar('filaOrfa', guardadas);
}
```

Sem isso, registros feitos no campo por quem usou o aparelho antes ficam
esperando um acesso pelo navegador para voltarem a subir.

---

## 4. Uma matrícula de teste que esteja escalada

**Por quê.** O Lucas não está em escala nenhuma, e o app mostra "Você ainda
não está escalado". Com isso não conseguimos exercitar as telas que só
existem para quem tem serviço:

- **"Cheguei"**, que lê o GPS — é o registro de presença no posto;
- **foto de alteração** e os anexos, que abrem a câmera;
- **assumir viatura**.

São justamente as que mais dependem do aparelho, e as que não dá para garantir
por teste automático. Precisamos de uma matrícula escalada na Expoferr (ou de
pôr o Lucas numa escala de teste) para conferir antes de a tropa usar.

---

## 5. O que não muda

- O Web Push de hoje continua como está (o outro documento trata disso).
- Quem abre o `/app/` no navegador ou pela PWA não é afetado por nada aqui:
  os três pedidos são condicionados ao `SOUPM`.
- O login de matrícula, CPF e senha da operação continua valendo, e é o nosso
  plano B quando o login automático falha.
- Fora do Sou PM, o PIN continua exatamente como é hoje — inclusive o
  "Autorizar por PIN". O pedido 1 é só sobre a tela de entrada, e só dentro do
  Sou PM (veja a ressalva no fim daquele item).

---

**Contato:** DTI / equipe do Sou PM, pelo Lucas.
