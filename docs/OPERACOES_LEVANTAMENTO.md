# Operações (operar.pmrr.online) no Sou PM — levantamento

Levantado em 28/10/2026, a partir do sistema no ar e do pacote de entrega à DTI
(`/home/pmrronline/operar_app/pacotes/extraido/`, versão 12/10/2026).
Dono do sistema: **TEN CEL Brunno, Chefe do GAPE/PMRR**. Nada foi alterado no servidor.

**Caminho escolhido: telas nativas em Flutter, com o design do Sou PM, conversando com a
API que o operar já tem.** Fora da primeira entrega fica só a chamada de voz/vídeo.

> Documento de levantamento. As decisões da última seção não estão tomadas.

---

# Parte 1 — O que é o Operações

Sistema de operações da PMRR. A primeira operação foi a Eleições 2026 (1º turno 04/10,
2º turno 25/10) e o nome do banco e das variáveis ficou amarrado a ela — **o sistema é de
operações, o nome é que saiu errado** (Parte 6: o que isso custa).

| Endereço | Para quem | O que é |
|---|---|---|
| `/app/` | tropa (celular) | **App de campo** — PWA, JS ES5 puro, fila offline. **É o que o Sou PM refaz nativo** |
| `/sistema/` | gestores (computador) | escala, efetivo, viaturas, relatórios. **Não vai para o celular** |
| `/painel/` `/escala/` `/disponibilidade/` `/pendencias/` | GAPE, chefes de seção | painéis e páginas auxiliares |
| `/frota/` | DPL | Frota PMRR — sistema irmão, proxy para `127.0.0.1:8040` |

## Arquitetura

```
internet ──HTTPS──> Apache 2.4 (proxy reverso, ProxyPreserveHost On)
                      ├── /        -> 127.0.0.1:8026  uvicorn (FastAPI, 1 worker)  [operar.service]
                      └── /frota/  -> 127.0.0.1:8040  uvicorn (Frota)              [frota.service]
                                                │
                                        MySQL 8.4 (loopback)
                                        banco `eleicoes2026` — 39 tabelas
```

Python 3.12, FastAPI, pymysql, systemd, sem Docker. Código em `/srv/operar/app` (dono root),
dados em `/srv/operar/dados` (0700), acervo em `/srv/operar/acervo`.

- **`--workers 1` é obrigatório.** SSE da chamada, limite de tentativas de login, bilhetes
  de download e fila de push vivem na memória do processo.
- No ar hoje: app **1.1.42-dti**; `GET /api/saude` → `{"servidor":"ok","banco":"ok","locais":356}`.
- O pacote espelhado é o **1.1.27-dti** (12/10) — está atrás do que roda.

## As três ideias do app (do cabeçalho do `app.js`)

1. Tudo que o policial registra vai para uma **fila no aparelho** (id, hora, GPS) e sobe em
   lote em `POST /api/eventos` quando houver sinal. Idempotente (`evento_recebido`).
2. A tela inicial mostra sempre o **próximo passo**, calculado pela hora de Roraima
   (UTC-4, sem horário de verão) e pelo que já foi registrado.
3. "Meu serviço" fica guardado no aparelho — **abre sem sinal**.

**Essas três ideias são o sistema.** Telas se refazem; isso não. Ver Parte 5.

## Perfis (as 9 cartilhas oficiais)
| Perfil | Onde | O que faz |
|---|---|---|
| Militar escalado | app | 1º acesso, PIN, ver serviço, Cheguei, viatura, votar, alimentação, ocorrência, fim de serviço, mensagens, pagamento TRE |
| Motorista de VTR | app | assume/devolve viatura por chip NFC ou QR |
| Comandante de posto | app | reconhecimento, presença da equipe, situação do local, alteração, pedido de apoio, urna entregue |
| Cmt de setor/área/Cia | app (Gestão) | presença verde/âmbar/vermelho, relatórios dos 5 momentos, comunicado geral, autorizações, trocas |
| Gestor CPC/CPI | sistema | monta escala, puxa do QCG, conflitos, viaturas, documentos SEI |
| Chefe de seção / QCG | sistema | indisponibilidades, conclui a seção |
| GAPE / DPO | ambos | painel e Dia D, libera turno no app, ver-como, documentos, pendências OOp, pagamento TRE |
| Entrar no computador | ambos | entra no `/sistema/` pelo celular (QR + código + digital) |
| DPL | sistema | frota, etiqueta QR/chip, adesivo 5×5 cm |

## Autenticação de hoje

- **1º acesso:** `POST /api/acesso` com **matrícula + CPF** (+ senha da operação), ou
  matrícula + **código de uso único** dado pelo comandante.
- Devolve um **token de aparelho**; o banco guarda só o `hash_segredo(token)` na tabela
  `aparelho`. **Aparelho novo revoga todos os anteriores da mesma matrícula** (`campo.py:93`).
- Todas as chamadas: `Authorization: Bearer <token do aparelho>`; `seguranca.militar_atual`
  resolve token → matrícula.
- **PIN fica só no aparelho.** O servidor não o conhece.
- **Digital** = passkey **WebAuthn**, amarrada ao domínio (`assinatura_digital`). Autoriza
  permuta, troca FALTA→PRESENTE e entra no `/sistema/` pelo celular.
- `ELEICOES_SAL` hasheia senha, código e token. **Nunca se troca.**

## Banco — 39 tabelas
Pessoas e contas: `militar`, `usuario_escala`, `sessao_escala`, `aparelho`,
`assinatura_digital`, `codigo_acesso`, `registro_escala`, `secao`, `unidade_fonte`,
`unidade_qde`, `qde_funcao`, `qde_lotacao`, `disponibilidade`, `impedimento`, `afastamento`.
Escala: `escala`, `lancamento`, `substituicao`, `ciencia_escala`, `setor`, `posto_servico`,
`local_votacao`, `porte_local`, `municipio`, `viatura`, `convocacao_tre`, `pedido_autorizacao`.
Campo: `evento_campo`, `evento_recebido`, `ocorrencia`, `reconhecimento`, `saida_posto`,
`relatorio_setor`, `foto`. Comunicação: `aviso`, `aviso_leitura`, `sala_leitura`,
`sala_mensagem`, `config_app`.

Estado fora do banco, em JSON em `OPERAR_DADOS`: `turno_app.json`, `chamada_escopo.json`,
`eventos.json`, `ronda_cobertura.json`, `vespera_pernoite.json`, `ordem_grupos.json`,
`acumulos.json`, `ordem_missao.json`, `diarias_dados.json` (CPF), `pagamento_tre.json`
(dados bancários), `pendencias_oop.json`, `encaminhados.json`, `disp_chefes.json`,
`vtr_chip.json`, `push_vapid.json`, `push_assinaturas.json`.

---

# Parte 2 — O login automático (já existe, é só copiar)

O Operações **já faz login automático com outro sistema**: o militar toca em "Frota" e a
Frota abre já logada. Em produção desde 11/10.

## O "crachá selado"

Os dois servidores guardam a **mesma chave secreta** (arquivo de 64 caracteres hex).

1. O app pede ao servidor do Sou PM um crachá para aquele militar.
2. O servidor monta `{mat, nome_guerra, posto, iat, exp = iat+60, jti, aud, iss}`, serializa
   em base64url e **sela** com `HMAC-SHA256` (hex minúsculo).
3. O Sou PM chama `POST /api/sso/soupm` no operar com o crachá.
4. O operar confere o selo em tempo constante, o prazo (≤ 60 s), o `jti` (uso único) e que a
   matrícula é de militar ativo → devolve o **token do aparelho**, que o app guarda no
   `flutter_secure_storage` (já está no pubspec).

Garantias: **a chave nunca vai para o celular**; **o crachá vale 60 s e uma vez só**.

No caminho nativo o crachá **não passa pela URL** — é corpo de POST entre app e servidor.
Mais simples e mais seguro que no WebView (lá ia depois do `#` para não chegar ao servidor).

**Código a copiar:** `operacoes/servidor/app/frota_sso.py` (166 linhas, quem emite) e
`frota/codigo/servidor/app/rotas_app.py::entrar_sso` (quem recebe).

**O Sou PM já tem o que o crachá precisa:** matrícula e CPF estão no `auth_model.dart`
depois do login.

## Dois cuidados
1. **Não criar aparelho novo a cada abertura.** O operar revoga os anteriores
   (`campo.py:93`) — quem usa a PWA e o Sou PM se derruba sozinho. A Frota guardou os 5 mais
   recentes. Aqui: guardar o token e só usar o crachá quando não houver token válido.
2. **Uso único do `jti`.** A Frota usa tabela `sso_jti`. No operar, ou se cria a tabela
   (DDL → arquivo SQL para a DTI aplicar; o usuário do banco não tem `CREATE`), ou se guarda
   em memória (funciona com 1 worker; perde no restart).

---

# Parte 3 — A API já está pronta

O app de campo **não é site com HTML do servidor: já é cliente REST.** São **~80 endpoints
JSON**, todos com `Authorization: Bearer <token>`. O Flutter chama os mesmos, e **não há
problema de CORS** (CORS é coisa de navegador).

**Não há API nova para escrever além do crachá da Parte 2.** O custo do projeto são as telas.

Por área:

| Área | Endpoints |
|---|---|
| Identidade | `/acesso`, `/api/sso/soupm` (novo), `/desafio`, `/codigo`, `/desligar` |
| Serviço e campo | `/meu-servico`, `/eventos`, `/campo/presenca`, `/campo/escalados`, `/campo/telefone/:id`, `/resumo`, `/saidas/:id`, `/setor/:id`, `/posto/:id` |
| Visão geral e relatório | `/campo/visao-geral`, `/campo/visao-geral/posto/:id`, `/campo/relatorio/meu.pdf`, `/campo/relatorio-foto/:id` |
| Comunicação | `/avisos`, `/campo/salas`, `/campo/salas/mensagem`, `/campo/salas/foto/:id`, `/campo/comunicados`, `/campo/comunicados/previa`, `/campo/comunicados/arquivo/:id` |
| Documentos | `/campo/documentos`, `/campo/documentos/arquivo/:id`, `/campo/documentos/croqui/:id`, `/campo/documentos/escala/:id`, `/campo/documentos/locais`, `/campo/encaminhados`, `/campo/sei-sugestoes/acesso` |
| Autorização | `/autoriza/pedidos`, `/autoriza/pedir-permuta`, `/autoriza/pedir-mover`, `/autoriza/pedir-dispensa`, `/autoriza/impedimentos/:id`, `/autoriza/digital/*`, `/substituicoes` |
| Viatura | `/campo/vtr/minha`, `/campo/vtr/assumir`, `/campo/vtr/devolver`, `/campo/vtr/:id`, `/campo/transferencias-vtr` |
| TRE | `/campo/diarias`, `/campo/pagamento-tre`, `/campo/pagamento-tre/recebi`, `/campo/pagamento-tre/nao-recebi` |
| Pendências | `/campo/pendencias-oop/acesso`, `/anexos`, `/anexo/:id` |
| Mapa | `/campo/mapa-dados`, `/campo/geo`, `/campo/mapa-pernoite`, `/campo/locais/:zona/:ibge/:cod/foto` |
| Entrar no computador | `/campo/qr/desafio`, `/campo/qr/consultar`, `/campo/qr/aprovar`, `/campo/qr/acesso`, `/escala/qr/passkey` |
| Push | `/campo/push/chave`, `/campo/push/assinar`, `/campo/push/cancelar`, `/campo/push/teste` |
| Frota | `/campo/frota/passe` |
| Chamada | `/api/chamada`, `/chamada/escopo`, `/sinal`, `/chamada/eventos` (SSE) |

---

# Parte 4 — As telas: 59, e o que cada uma pesa

A tabela de telas do app (`var T` em `app.js`) tem **59 entradas**. O número 39 de um
levantamento anterior contava só as telas alcançadas por navegação; o certo é 59.

## Não vão para o nativo (7)
`login` e `criarPin`/`pin` (o SSO e o desbloqueio do Sou PM substituem) · `instalar`
(convite de PWA, sem sentido dentro do app) · `vcEspera`/`vcErro` (o "ver como" é do sistema
web) · `entrarSemApp` (navegador sem o app).

**Restam ~52 telas para construir.**

## O peso real, medido arquivo por arquivo

| Módulo | Linhas de JS | Veredito |
|---|---|---|
| `app.js` (o núcleo e a maioria das telas) | 4.895 | o trabalho principal |
| `encaminhar.js` — encaminhar documento | **1.014** | **o maior item individual**; CRUD + anexo + cadeia de comando |
| `chamada.js` + `ligacao.js` — voz/vídeo | **1.078** | **o único realmente pesado**: WebRTC + SSE |
| `acervo.js` — documentos offline | 538 | médio |
| `entrar_pc.js` — entrar no computador | 524 | médio |
| `comunicado.js` | 403 | leve |
| `vtr.js` | 286 | leve |
| `push.js` | 286 | leve (substituído por FCM) |
| `pagamento.js` — pagamento do TRE | 265 | leve |
| `transf_vtr.js` | 187 | leve |
| `cartilhas.js` | 166 | leve |
| `diarias.js` — diárias do TRE | 160 | leve |
| `pend_oop.js` — pendências da OOp | **91** | levíssimo |
| `sei_sug.js` | 63 | levíssimo |

**Relatório, croqui e escala não são trabalho de tela: o servidor entrega pronto.**
`/campo/relatorio/meu.pdf` devolve o PDF; o croqui devolve PNG A4
(`croqui.py:1369`, `media_type="image/png"`). O Sou PM já faz exatamente isso no
`contracheque_pdf_repositorio.dart` — 87 linhas.

**O mapa não é o `mapa2.js`.** Aquelas 2.913 linhas são o mapa do *sistema*, com as
ferramentas de gestor; o app só o embutia porque era de graça. O app precisa de **4 rotas de
leitura** que o servidor **já filtra pelo alcance do militar** (`mapa_app.py`): `mapa-dados`,
`geo` (polígonos, sem dado pessoal), `mapa-pernoite` e a foto do prédio.

## Nomes das telas (do mapa `TITULO` do `app.js`)
Confirmar escala · Impedimento · Onde você vota · Como chegar · Reconhecimento ·
Apresentação no posto · Situação do local · Registrar alteração · Pedir apoio · Saída do
posto · Resumo do dia · Meu setor · Posto · Substituição · Aviso ao setor · Local · Detalhe ·
Relatório do setor · Foto · Participantes · Autorizar · Assinatura · Mover, permutar ou
dispensar · Meus pedidos · QR Code do app · Confeccionar relatório — mais as raízes
(Início, Equipe, Avisos, Conversa, Gestão, Mais, Eventos) e os módulos (documentos, diárias,
pagamento, pendências, comunicados, salas, viatura, mapa, cartilhas).

---

# Parte 5 — O que o Sou PM já tem, e o que falta

## Já está no `pubspec.yaml` — não custa nada
```
pdf: ^3.6.5          printing: ^5.12.0      flutter_pdfview: ^1.3.2    pdfx: ^2.6.0
file_picker: ^8.1.7  share_plus: ^10.0.0    path_provider: ^2.1.3
local_auth: ^2.3.0   mobile_scanner: ^7.4.2 permission_handler
flutter_secure_storage
```
PDF (quatro pacotes), escolher e compartilhar arquivo, biometria, **leitor de QR nativo**,
permissões e cofre. **PDF e arquivo, que eram o problema da WebView, aqui são padrão
resolvido** — e o `blob:` que não baixa simplesmente deixa de existir.

## Falta — capacidade nova, não está no pubspec
| Pacote | Para quê | Leva |
|---|---|---|
| `geolocator` (ou `location`) | **o "Cheguei"** e o GPS de cada evento da fila | 1 |
| `flutter_map` (ou `google_maps_flutter`) | o mapa da operação | 8 |
| `nfc_manager` | assumir viatura encostando o celular | 6 (opcional: o QR já resolve) |
| `flutter_webrtc` + SSE | chamada de voz/vídeo | fora da 1ª entrega |

## A digital: `local_auth` **não** substitui o WebAuthn
Isso é segurança, não código. O `local_auth` prova **ao aparelho** que o dono desbloqueou.
A digital do operar é **WebAuthn**: o servidor guarda a credencial em `assinatura_digital` e
**confere uma assinatura criptográfica** — prova que aquele chefe autorizou, verificável no
servidor. É o que vale para autorizar permuta e trocar FALTA→PRESENTE.

Para o nativo ter equivalente: ou o servidor passa a aceitar uma assinatura do aparelho
(trabalho dos dois lados — é a "ponte" do `INSTALAR.md` §13.4), ou o GAPE aceita a
confirmação local como suficiente. **Decisão do dono do sistema.**

---

# Parte 6 — Ordem de ataque

## Leva 0 — a base (sem tela visível)
O que todas as levas usam. Não entregar nada antes disso estar de pé.

1. **Crachá/SSO** — endpoint PHP no `sigrh`, rota `POST /api/sso/soupm` no operar, arquivo de
   chave em `/etc/operar/segredos/`. Token no `flutter_secure_storage`.
2. **Camada de API** — cliente com Bearer, modelos dos ~80 endpoints, tratamento de erro e a
   semântica do **409 com escolha** (está nos comentários do código do operar).
3. **A fila offline** — registro local com id, hora e **GPS do instante**, envio em lote para
   `POST /api/eventos`, idempotência, reenvio sozinho, "salvo" por item, vermelho na falha.
   **É a peça mais delicada do projeto inteiro** (Parte 7).
4. **Item "Operações" no `app_config.php`** (`ItemMenu`, com `chave` e `apelidos`) — liga e
   desliga pelo painel sem versão nova.

## Leva 1 — o militar escalado (a maior audiência)
`inicio` (o próximo passo) · `ciencia` · `voto` · `rota` · `chegada` (o **Cheguei**, com GPS) ·
`status` · `ocorrencia` · `apoio` · `saida` · `resumo` · fim de serviço / urna entregue ·
`impedimento`
Endpoints: `/meu-servico`, `/eventos`, `/campo/presenca`, `/avisos`.
**Precisa do `geolocator`.** Ao fim desta leva o militar comum já usa o app inteiro pelo Sou PM.

## Leva 2 — comunicação
`avisos` · `avisosTela` · `conversa` · `sala` · `salaMembros` · `salaFoto` · `comunicados` ·
`comunicadoNovo`
Endpoints: `/avisos`, `/campo/salas*`, `/campo/comunicados*`.
**Aqui entra o push por FCM** (o Sou PM já tem Firebase): rota nova no operar para receber o
token do aparelho, e o disparo pelas mesmas regras do Web Push. Tratar como obrigatório —
numa operação a notificação é o megafone do GAPE.

## Leva 3 — quem comanda
`equipe` · `reconhecimento` · `setor` · `postoSetor` · `substituir` · `avisar` · `visao` ·
`vgPosto` · `vgItem` · `relatorio` · `relMeus`
Endpoints: `/campo/escalados`, `/campo/visao-geral*`, `/substituicoes`, `/campo/telefone/:id`,
`/campo/relatorio/meu.pdf` (PDF pronto).

## Leva 4 — TRE e pendências (as leves; podem subir se houver pressa)
`diarias` (160 linhas) · `pagamento` (265) · `pendOop` (91) · `seiSug` (63)
Endpoints: `/campo/diarias`, `/campo/pagamento-tre*`, `/campo/pendencias-oop/acesso`, anexos.
Anexo usa `file_picker`, que já está no pubspec. **Cuidado:** aqui trafegam CPF e dados
bancários.

## Leva 5 — documentos e papel
`docs` · `docEscala` · `docLocais` · `docCroqui` · `comoUsar` (cartilhas) · `encaminhar` ·
`encaminharDoc`
Croqui e escala são PNG/PDF prontos. **`encaminhar` é o maior item individual (1.014 linhas)** —
dá para deixar por último dentro da leva.

## Leva 6 — viatura
`vtrAssumir` · `vtrManual`
Endpoints: `/campo/vtr/*`, `/campo/transferencias-vtr`.
Abrir com o **QR** (`mobile_scanner`, já tem) e o código manual; o `nfc_manager` entra depois
se o GAPE quiser manter o chip.

## Leva 7 — autorização e assinatura
`autorizar` · `assinatura` · `pedirAlt` · `meusPedidos`
Endpoints: `/autoriza/*`.
**Não começar antes da decisão da digital** (Parte 5).

## Leva 8 — mapa
`mapa` — 4 rotas de leitura já filtradas + pacote de mapa novo.

## Leva 9 — entrar no computador
`entrarPc` · `qr` — o militar aprova no celular o login do `/sistema/` no computador.
Usa `mobile_scanner`, que já está lá. Útil e barato; só não é caminho crítico.

## Fora da primeira entrega
**Chamada de voz/vídeo.** 1.078 linhas, WebRTC + SSE, `flutter_webrtc` novo, permissão de
áudio, segundo plano — e hoje **só funciona na mesma rede**, porque falta o servidor TURN
(`FROTA_TURN_URLS` está comentado). Não é WebView: é depois, quando a infraestrutura existir.

---

# Parte 7 — Onde o prazo realmente mora

**O volume de código não é o risco.** ~52 telas a ~500 linhas (densidade medida em
`lib/features`: 12 páginas em 9.939 linhas) + camada de API + fila ≈ **25 a 30 mil linhas de
Dart**. No ritmo medido no `git log` deste repositório — de 2.1.5 (16/10, 120 arquivos,
~47 mil linhas) para 2.2.0 (23/10, 174 arquivos, 63.255 linhas): **+54 arquivos e +16 mil
linhas em 7 dias**, com pico de **+15.509 linhas e 59 commits num dia** — isso é
**2 a 3 semanas de trabalho concentrado**.

O risco é outro:

1. **A fila offline e o "próximo passo" não são tela, são comportamento.** Supressão de
   duplicata, GPS no instante do evento, hora de Roraima, fila que sobe pela metade, modo
   CONSULTA (só leitura em operação encerrada). Essas regras foram assentadas em **dois
   turnos de eleição real**. Refazer é re-derivar decisão de campo, e o teste é a próxima
   operação.
2. **Os ~80 endpoints têm contrato não documentado.** Foram escritos para um cliente só:
   formato de erro, 409 com escolha, `X-Turno`, `X-Ver-Como`, idempotência. Descobre-se
   lendo 10 mil linhas de ES5. É tempo de leitura, não de escrita.
3. **Duas bases para manter em sincronia.** A PWA continua cliente real: o GAPE usa, o
   "Meu app" do `/sistema/` abre o mesmo `/app/`, o "ver como" mostra o mesmo `/app/`. Cada
   pedido do dono do sistema chega duas vezes — e os comentários do código mostram mudanças
   de dias em dias ("06/10 (major)", "11/10 (major)", "12/10 (major)"), **durante** a operação.
   Combinar com o TEN CEL o que é cliente de referência reduz isso.
4. **A janela da DTI.** Rota nova e arquivo de chave no servidor exigem janela com a DTI e o
   "sim" do TEN CEL. Costuma demorar mais que o código.

---

# Parte 8 — O que não é integração: virar multi-operação

O sistema é de operações, mas **o código e o banco ainda não sabem disso**:

- `escala.tipo` é enum fechado: `VESPERA`, **`ELEITORAL`**, `PRONTA_RESPOSTA`, `ORDINARIO`,
  **`POS_ELEICAO`**, **`APOIO_MAGISTRADO`**, `GESTAO`
- `escala.turno` e `disponibilidade.turno`: `enum('1T','2T')` — dois, e só dois
- tabelas `local_votacao`, `porte_local`, `convocacao_tre`; módulos `voto.py`,
  `diarias_tre.py`, `pagamento_tre.py`
- as datas estão **escritas no código**: `config.py` → `DIA_D_1T = date(2026,10,4)` e
  `DIA_D_2T = date(2026,10,25)`
- banco `eleicoes2026`, variáveis `ELEICOES_*`
- **não existe tabela de operação.** O modelo pressupõe **uma operação por vez**

Procurei **Expoferr** e **Enem** no pacote de 12/10, nos arquivos no ar (`app.js`,
`sistema.js`, `escala.js` da 1.1.42) e em todos os projetos do iMac: **nenhuma ocorrência**.
Existem como plano, não como código.

O usuário do banco tem **só DML** (sem `CREATE`/`ALTER`): toda mudança de estrutura é um
arquivo SQL entregue à DTI.

**Isso é projeto do servidor e do banco, não do Sou PM.** Mas tem uma consequência para a
ordem: se a multi-operação vier depois, as telas nativas feitas agora pegam **mudança de
contrato** (turno que deixa de ser `1T`/`2T`, tipo de escala que abre, Dia D que vem do
banco). Vale decidir qual dos dois vem primeiro.

---

# Decisões pendentes

1. **O PIN.** O militar já desbloqueou o Sou PM. Pular o PIN?
2. **Militar não escalado.** Crachá válido, matrícula fora da operação: o que ele vê?
3. **A digital como prova** (Parte 5) — regra, não código. Decisão do GAPE.
4. **Multi-operação antes ou depois das telas** (Parte 8).
5. **Qual é o cliente de referência** depois do nativo: a PWA, o Sou PM, ou os dois.
6. **Quem assina** a rota nova e a chave no servidor — janela com a DTI e o "sim" do
   TEN CEL Brunno.
7. **TURN**, para a chamada entre redes diferentes.

# Onde está o material

- Fonte espelhada nesta sessão (temporário): `operar/extraido/` no scratchpad — 353 arquivos,
  20 MB, `operacoes/` + `frota/`, versão 12/10/2026
- No servidor: `/home/pmrronline/operar_app/pacotes/extraido/`
- Ler primeiro: `operacoes/INSTALAR.md` (479 linhas; §13 é a integração com o Sou PM, §14 a
  virada, §18 as decisões da DTI), `00_LEIA-ME_DTI.md`, `frota/INSTALAR.md`
- Cartilhas (9 `.docx`) em `operacoes/app_campo/cartilhas/` — descrição funcional por perfil
- Acesso ao servidor: FTPS em `server1.pmrr.online`, credenciais em
  `~/code/api-pmrr/.ftp-credentials`
