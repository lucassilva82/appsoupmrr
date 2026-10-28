# O que só o usuário pode fazer — SouPM 2.2

Lista do que depende do login, da senha ou da decisão do usuário. O resto do
plano (`docs/SOUPM_2_2.md` §16) segue sem esperar por isto: cada função nova
entra na API **desligada**, e nada muda para quem usa o app da loja até um
item desta lista ser feito.

Os SQL ficam na cópia local da API (`~/code/api-soupmrr/sql/`, fora do git
por conter estrutura do banco de produção). Rodar no phpPgAdmin, com o login
do usuário, **desmarcando "Paginar resultados"**, na ordem da tabela. Todos
podem rodar mais de uma vez sem estragar nada.

Última atualização: 28/10/2026 (a 2.2.1 fica para amanhã: seção logo abaixo).

## Para amanhã (29/10/2026): a 2.2.1

Decisão do usuário em 28/10: a versão sai amanhã. **O motivo dela é o crash ao
fechar o app no iPhone** (APRENDIZADOS §51), que está corrigido no `main` e não
existe em build nenhum: o `pubspec` ainda diz 2.2.0+58, que é o que está nas
lojas.

**O que a 2.2.1 leva** — seis commits que mexem no app depois do envio da 2.2.0:

| Commit | O quê |
|---|---|
| `146557c` (28/10) | O crash: piso do `cloud_firestore` em 5.6.12. **É o motivo da versão** |
| `68b9a72` (28/10) | Início: bloco que pode não existir não reserva espaço antes de saber |
| `2b27450` (28/10) | Contracheque: a tela de erro antiga vira `EstadoErro`, e o valor ganha um leitor só |
| `ee098b3` (27/10) | `flutter analyze` sem nenhum aviso (eram 14) |
| `64a2e93` (26/10) | Entrada suave na Início depois do login e do Face ID |
| `1520a19` (26/10) | Perfil no iPad: Face ID e notificações dizem iPad, não iPhone |

**Os dois de 26/10 podem já estar no binário publicado**, porque o envio foi no
mesmo dia. O archive local não decide (é de 15/10, da 2.1.x); quem diz é o
horário do build na TestFlight. Não muda o que fazer: os seis entram na 2.2.1
de qualquer forma.

**A ordem, amanhã:**

1. Versão nos **três** arquivos: `pubspec.yaml` (`2.2.1+59`),
   `android/app/build.gradle.kts` (`versionCode = 59`, `versionName = "2.2.1"`)
   e `ios/Runner/Info.plist` (os dois campos). Editar o XML do Info.plist à
   mão, nunca pelo PlistBuddy (§15).
2. `flutter analyze` e `flutter test` limpos antes de compilar.
3. `flutter build appbundle --release --dart-define-from-file=env.json` e
   `flutter build ipa --release --dart-define-from-file=env.json`. **Conferir
   que o `env.json` existe antes**, senão Legislações e POPs saem quebradas de
   novo (§41).
4. **TestFlight em iPhone físico, e fechar o app arrastando para cima** — é
   exatamente o defeito que esta versão corrige, e o simulador não o reproduz
   (§1 e §51).
5. **Abrir o Organizer antes de enviar** e olhar os fechamentos (§51: eram 156
   aparelhos esperando alguém abrir aquela tela).
6. "O que há de novo" escrito **separado para cada loja** (§31).
7. Ao publicar, **avisar a sessão do painel** (seção própria neste arquivo).

Não há SQL nem interruptor ligado a esta versão: ela é só o app.

---

## 1. SQL de produção (phpPgAdmin)

| # | Arquivo | Para quê | Situação |
|---|---|---|---|
| 1 | `2026-10-22_soupm_log.sql`, `2026-10-22_soupm_servico_saude.sql`, `2026-10-23_soupm_cron_log.sql` | Fase 0 (log, sonda) | Feito |
| 2 | `2026-10-23_soupm_app_config.sql` | Fase 1 (menu e app_config) | Feito |
| 3 | `2026-10-23_soupm_inicio.sql` | Fase 2 (blocos da Início, atalhos, Mais usados) | Feito |
| 4 | `2026-10-23_soupm_feedback.sql`, `2026-10-23_soupm_atendimento.sql` | Fase 3 (Sugestões e elogios, Preciso de ajuda, área Atendimento) | Feito |
| 5 | `2026-10-23_soupm_documentos.sql` | Fase 3b (contracheque pela API, QR e conferência) | Feito (23/10/2026) |
| 6 | `2026-10-23_soupm_notificacoes.sql` | Fase 4 (aparelhos e Avisos pelo Postgres) | Feito (23/10/2026) |
| 7 | `2026-10-23_soupm_conta_resumo.sql` | Tela Militares do painel (bloco Conta) | Feito (23/10/2026) — e depois `ALTER FUNCTION public.soupm_conta_resumo(TEXT) OWNER TO` um usuário que leia o esquema `qra` (o do cPanel não lê) |

| 8 | `2026-10-23_soupm_artes.sql` | Artes dos cards editáveis pelo painel, mídia aprovada e paleta fechada | Feito (23/10/2026) |
| 9 | `2026-10-23_soupm_comunicados.sql` | Central de comunicados (categorias, comunicados, leitura e ciência) | Feito (23/10/2026) — o `comunicados.php` já está no ar e responde erro até este SQL rodar; o app 2.2 só usa com o interruptor abaixo |
| 10 | `2026-10-23_soupm_painel_filas.sql` | Reset de senha pelo painel (fila), lembretes automáticos, modelos de mensagem e módulos da intranet que pedem push | Feito (23/10/2026) |
| 11 | `2026-10-23_soupm_cards.sql` | Cards criados no painel, Comando aprovado no painel e dicas (depois do 8, que cria as artes) | Feito (23/10/2026) — sem ele, o Comando e as dicas continuam vindo do Firestore |
| 12 | `2026-10-23_soupm_pendencias.sql` | Suas pendências: catálogo dos 37 tipos, **todos desligados**, dispensas e fontes de dados | Feito (23/10/2026) — depois dele, cada tipo só liga pelo painel, depois de homologado |
| 13 | `2026-10-23_soupm_declaracao_campanha.sql` | Declarações por campanha. Nasce **desligado** (`declaracoes.campanhas_ligadas = false`) | Feito (23/10/2026) — antes de ligar, cadastrar pelo painel a campanha do ano em curso, senão ninguém consegue declarar |
| 14 | `2026-10-23_soupm_inicio_preferencia.sql` | A tela inicial de cada militar guardada no servidor (vale em outro aparelho) | Feito (23/10/2026) — sem ele, a escolha fica só no aparelho |
| 15 | `2026-10-23_soupm_niveis.sql` | Níveis de acesso e papéis (fase 5). Nasce **desligado** (`niveis.ligado = false`): o app e o menu seguem com a regra de hoje | Feito (23/10/2026) — ligar só depois da comparação no painel |
| 16 | `2026-10-23_soupm_chamados_config.sql` | Textos e limites da tela "Meus chamados" pelo painel | Feito (23/10/2026) |
| 17 | `2026-10-23_soupm_funcoes_novas.sql` | Funções novas no menu com o selo "Novo" (só para o app 2.2): O que mudou no contracheque, Central de documentos, Linha do tempo da carreira e Validar documento | Feito (23/10/2026) — sem ele, só o menu de reserva do app mostra essas funções |
| 18 | `2026-10-23_soupm_lembretes.sql` | Lembretes automáticos (P3): controle para não repetir o mesmo lembrete | Feito (23/10/2026) — os lembretes continuam desligados até alguém ligar no painel |
| 19 | `2026-10-23_soupm_uso_hora.sql` | Aberturas por hora para o mapa de calor "Quando usam" do painel (refaz a rotina noturna do log com esse passo a mais) | Feito (23/10/2026) |
| 20 | `2026-10-23_soupm_niveis_rapido.sql` | Níveis de acesso mais rápidos: a prévia do painel caiu de cerca de 2 minutos para menos de 1 segundo, com o mesmo resultado; o `app_config` lê a visão do SIGRH uma vez só | Feito (23/10/2026) — rodar depois do SQL 15 |
| 21 | `2026-10-23_soupm_feedback_retencao.sql` | Deixa o cron noturno apagar os anexos de sugestões 180 dias depois de concluídas ou arquivadas (decisão de 21/10/2026) | Feito (23/10/2026) — sem ele, os anexos ficam guardados e o cron só avisa no log |

| 22 | `2026-10-23_soupm_niveis_rapido.sql` (de novo, só a função `soupm_e_gestor`) | **Pendente.** O `EXCEPTION WHEN OTHERS` da `soupm_e_gestor` chamava **a mesma função que acabara de falhar** (`soupm_e_gestor_legado`). Quando o problema era a legada — como em 23/10, quando ela estava sem `EXECUTE` —, o erro subia duplicado e **derrubava o menu inteiro**, em vez de devolver `false` como a política do §46 manda. Corrigido no arquivo em 27/10/2026, com um bloco próprio para o cálculo dos níveis. **Não rodar agora:** é durante a revisão da Apple, e o privilégio hoje está lá (conferido em 27/10: 24 das 25 funções com `EXECUTE`), então o defeito não dispara. Entra no próximo lote de SQL, **depois de compilar num Postgres local** (§19 e §47) — esta máquina não tem Postgres, então o arquivo não foi compilado |

| 23 | As funções e a lotação de comando no SIGRH: **medido em 27/10/2026** | **Serve, e nada a fazer agora:** o usuário pediu para estudar antes de montar regra. O comando sai de duas fontes, as duas pela lotação ativa: a **função** (`escalaservico.funcoes_servico`, cadastro mantido, Comandante Geral = 1) e a **subunidade de comando** (efetivo 1, `Cmt`, `Cmt Geral`, `Com da …`), que cobre 22 das 50 unidades — as 28 que faltam são diretorias, que têm chefe e não comandante. Quatro achados mudam a regra antes de ela existir: função com **dois códigos**, o nível 3 **partido em dois públicos** (quem comanda e quem dirige), **nenhuma** classificação marcando comando (está no nome, em texto livre, sem chave estrangeira) e **cinco grafias** de "Cmt" com dois falsos positivos. Detalhe e o que continua não confirmado: logo abaixo desta tabela |

O item 11 (`2026-10-23_soupm_cards.sql`) ganhou o que o Comando precisa: a matrícula de cada cargo (o painel grava) e o "Conferir no SIGRH agora". Se já tiver rodado, rode de novo: ele não estraga nada.

Os itens novos que forem entrando vão para o fim desta tabela, com o mesmo
formato.

### O item 23: medido em 27/10/2026, e o que ele decide

**O conteúdo foi medido pelo painel** (a tela de Níveis; a conta do cPanel
não lê `recursoshumanos`, §46). A resposta é **serve, com ressalvas** — e
não era o catálogo que eu tinha chutado.

| Coluna de `recursoshumanos.policial_lotacao` | Catálogo | O que tem |
|---|---|---|
| `fk_tipo_func_cod` | `escalaservico.tipo_funcao` (sem chave declarada; o nome casa) | só *Administrativo* (1.794) e *Operacional* (1.404) — **grosso demais, não serve** |
| `fk_func_serv_cod` | `escalaservico.funcoes_servico` | 53 entradas, e **é onde está o comando** |
| `fk_subu_cod` | `subunidades` | a lotação (ver a terceira fonte, abaixo) |

**O comando está em `funcoes_servico`, e o cadastro é mantido:**

| Função | Código | Militares |
|---|---|---|
| Comandante Geral | 33 | **1** |
| Subcomandante Geral | 34 | **1** |
| Subcomandante de Grande Comando | 16 | 1 |
| Comandante de Companhia | **54 e 42** | 10 + 6 |
| Subcomandante de Companhia | **43 e 55** | 3 + 3 |
| Comandante de Pelotão | **41 e 52** | 9 + 7 |
| Comandante de Grupamento | 53 | 2 |
| Chefe / Diretor | 17 | 140 |

Comandante Geral com exatamente **1** é o que prova o cadastro: é um número
que só fecha se alguém mantém. Compare com o grupo "Comandantes BPM / CIPM"
dos níveis de acesso, que tem 3 e claramente não é usado.

A ressalva do esquema **era procedente e não fatal**: `escalaservico` é da
escala de serviço, e há funções de escala ali (Sentinela, Motorista, Rádio
Operador), mas as de comando convivem com elas.

**Três armadilhas medidas, e a primeira muda a regra que vamos escrever:**

1. **Função duplicada, com dois códigos.** *Comandante de Companhia* é 54
   (10 militares) **e** 42 (6). O mesmo em Pelotão (41 e 52), Subcomandante
   de Companhia (43 e 55) e Comandante de Guarnição (2 e 56). Uma regra
   cadastrada por id pega metade e **não dá erro nenhum**: seis comandantes
   perdem Gestão no menu e ninguém liga os pontos — o §46 e o §37 outra vez.
2. **Não existe "Comandante de Batalhão" nem "de OPM".** O degrau **Gestor
   de unidade** (nível 3) fica **sem fonte direta**. O mais próximo é
   *Chefe / Diretor*, com 140 militares, grosso demais para virar nível 3.
3. **Lixo no catálogo:** *Selecione*, *Incapaz* (129), *Agregado* (415),
   *Falecido*, *Licenciado*, *Reserva*. Não são funções; são situações.

**Consequência para a nossa tabela de regras** (`soupm_nivel_regra`, SQL 15).
A estrutura aguenta: cada nível aceita várias linhas, e o
`soupm_nivel_para` vale pela primeira que casa, então duas linhas cobrem os
dois códigos. Mas isso depende de **quem cadastra saber da duplicata**, e é
justamente o que ninguém sabe. Como o `valor` é `VARCHAR(80)`, a regra
`funcao_sigrh` pode casar por **nome** em vez de id, e aí:
- uma linha cobre os dois códigos;
- o porquê que o painel mostra vira legível (`funcao_sigrh:Comandante de
  Companhia`, não `funcao_sigrh:54`);
- código novo com o mesmo nome entra sozinho.

O risco do nome é a renomeação no SIGRH, que derrubaria a regra em silêncio
— por isso a prévia do painel (quantos militares cada regra pega **agora**)
deixa de ser conferência e passa a ser parte da regra.

**A terceira fonte foi medida, e funciona: a lotação.** Cada unidade
operacional tem uma **subunidade de comando com efetivo 1**, onde o
comandante é lotado — `Cmt` nos BPM, nas CIPM, BOPE, CIPA, CIPCOM, CIPG,
CIPTUR, GIRO e E.M. CPI; `Cmt Geral` no Gab Cmdo Geral; `Cmt CPC` no E.M.
CPC; `Com da 1ª…6ª CIPMFron` nas de fronteira. Não era amostra de um: o
padrão se repete.

**Cobertura de 22 das 50 unidades ativas — e as 28 que faltam não são falha
de cadastro.** São `CORREGE`, `DP`, `DTI`, `DCS`, `DF`, `DII`, `CEP`, Casa
Militar, Colégio Militar, BANDA e as assessorias: **diretorias e seções, que
têm chefe ou diretor, não comandante**. É coerente que não tenham subunidade
"Cmt".

**Isso fecha o nível 3, e sem os dirigentes.** Os diretores aparecem na
lotação do mesmo jeito que os comandantes (`Diretor` no Gab DEP, `Dir DRH`
no GAB DRH, `Ch Gab`, `Dir Polic`, `Dir do SS`, sempre efetivo 1 com o
cargo no nome), e por isso escrevemos aqui que o degrau 3 teria dois
públicos. **Estava errado, e a resposta já estava no plano:** o
`SOUPM_2_2` §6.2 põe **diretores no Alto Comando** (nível 5), por decisão
sua de 21/10/2026. Com isso o degrau 3 fecha certinho — as 22 unidades
operacionais, que são justamente as que têm subunidade de comando; as
outras 28 são diretorias e assessorias, e sobem para o 5. O degrau nunca
esteve sem fonte: estava com a gente errada dentro.

**O nível 2 (*Gestor de subunidade*) é o que continua sem fonte boa**, e
fica vazio na primeira carga. A lotação não serve: o comandante de
Companhia é lotado na própria Cia, junto com os 80 militares dela. A função
54+42 falha por falta, que é o modo que acabamos de recusar. Sobram a
função com o vigia ligado ou a concessão por matrícula — que também
envelhece, mas **à vista**, com data de fim e na tela.

**O valor da regra não é um nome nem um par: é um trio**, porque **a regra precisa de uma interseção, e `soupm_nivel_regra` não a
expressa.** As premissas caíram na terceira medição: "subunidade de cargo tem
efetivo 1" só vale para `Cmt` **dentro de uma unidade**. Em chefia e gabinete
a subunidade é a equipe toda — `S Cmt Geral` tem **10 militares, um deles
soldado**, `Chefia DTI` tem 5, `Coord. Ens. Pol.` tem 10. Lotação sozinha
daria Alto Comando a um soldado do gabinete do Subcomandante: o erro
espelhado do que a função fazia, e do mesmo tamanho.

Quem identifica o titular é **(subunidade, unidade) ∩ função**:
`S Cmt Geral` ∩ 34 = 1, `Chefia DTI` ∩ 17 = 1. E as duas fontes se corrigem
**em direções opostas**, o que impede hierarquizar uma sobre a outra: a
função separa o diretor dentro de `Chefia DTI`, e a **subunidade desmente a
função** em `Sbc da 2ª CIPMFron`, onde o subcomandante está cadastrado com a
função 54 (*Comandante de Companhia*) — quem confiasse na função daria
comando a ele. A regra que sobrou: **a subunidade manda quando o nome dela
diz o cargo; a função manda quando a subunidade é coletiva.**

Consequência direta para o SQL 15: as linhas de `soupm_nivel_regra` somam
com **OU** (o nível é o maior degrau em que *alguma* regra vale), então
cadastrar "subunidade = Chefia DTI" e "função = 17" como duas linhas daria o
nível aos 5 da chefia **e** aos 140 da função. **Duas regras somadas sai da
lista de opções.** O trio tem de caber **numa linha**, num tipo novo
(`lotacao_funcao`, com valor composto), e isso se decide antes de escrever a
`soupm_regra_vale`, não depois. Mais três medições para a comparação: **não
existe CPE** (só CPC e CPI; o EMG é grande comando, com 297 militares),
`ch DF` é minúsculo ao lado de `Ch DCS` — **comparar ignorando caixa** — e a
abreviação da subunidade **não segue** a da unidade (`Com da 3ª CIPMFron Ror`
dentro de `3ª CIPMFron Rorai`).

**O vigia tem três perguntas, e a que vale é a terceira:** *unidade ativa
sem nenhum militar no nível 3 ou acima*. As outras duas vigiam a grafia
(subunidade com cara de cargo fora da lista; regra cuja subunidade está com
efetivo 0) e por isso **envelhecem junto com ela**: só acham o que o padrão
delas souber parecer. A terceira pergunta de cima para baixo — se o 5º BPM
não tem gestor, ela acusa sem precisar adivinhar se a subunidade virou
`Cmt Btl`, `Cmte` ou outra coisa.

**E a função de serviço saiu de vez como fonte de nível.** Medidos os 140 de
*Chefe / Diretor* (código 17), um por um: eles se espalham por 43 unidades e
o mesmo código cobre chefia de seção (`P2/P3`, `SPA`, `Ch DP`), **situações
que não são chefia nenhuma** (`Agregado Proc. Reserva/Reforma`, `Reserva`)
e — o que fecha o assunto — **7 militares lotados na subunidade `Cmt`**, ou
seja, **comandantes cadastrados como "Chefe / Diretor"**.

O problema não é o código 17 ser um saco de gatos. É o que esses 7 provam:
**o campo de função não identifica o comandante de forma confiável.** Uma
regra sobre a função 54 não erraria — ela simplesmente **não acharia** esses
7, sem dar erro, e sete comandantes ficariam sem Gestão no menu. É o §37 na
escolha da fonte: o campo responde, o número é plausível, e o que falta não
aparece em lugar nenhum. Por isso `funcao_sigrh` **não entra como fonte de
nível**, nem no degrau 3 nem nos outros, apesar de *Comandante Geral* e
*Subcomandante Geral* terem exatamente 1 cada.

**Nenhuma classificação marca comando.** `subunidades_tipo` é só
*Administrativa* (416) e *Operacional* (126), e a função de lotação é o
mesmo par. A informação de que aquele lugar é um posto de comando está **só
no nome**, em texto livre. As duas fontes (`funcao_sigrh` e `lotacao`)
dependem de texto que alguém digita, e **não há chave estrangeira para
proteger**: se o nome mudar, a regra para de casar sem dar erro. Então a
prévia do painel não é só conferência — é o **único** sinal de que uma
renomeação quebrou a regra.

**E o nome não tem uma grafia só.** Medidas cinco para a mesma coisa:
`Cmt`, `Cmte`, `CMT`, `Cmt Geral`, `Cmt CPC` e `Com da …`. Pior: existem
`Cmte Guarn` (guarnição, 4 militares) e `Cmte do Gp de Cons. e Seg.` (10),
que **não** são comando de unidade. Uma regra `ILIKE 'cmt%'` pegaria os dois
junto — plausível e errado, como o join do `cad.funcao`. Consequência: a
regra de lotação tem de ser uma **lista explícita de nomes**, não um padrão.

E aí volta o problema por outro lado: lista explícita **envelhece em
silêncio** quando uma unidade nova aparece com uma grafia nova. Nem padrão
nem lista se protegem sozinhos. O que fecha isso é a lista no painel **mais
um vigia**: mostrar as subunidades de efetivo 1 cujo nome parece comando e
**não estão na lista**. Sem esse vigia, a regra nasce certa e apodrece.

**O que ainda NÃO está confirmado:** que o militar da função 33 é o 400831.
É o provável, mas a tela de Níveis mostra só a contagem e a de Militares não
mostra função. Cruzar exige listar quem tem cada função, com auditoria, como
as outras listas nominais.

**Decisão do usuário (27/10/2026):** estudar melhor antes de montar
qualquer regra. Nada de implementar `funcao_sigrh` agora — e mudar a
`soupm_regra_vale` muda quem é gestor no menu, com a 2.2.0 em revisão na
Apple. (Escrito quando `niveis.ligado` era `false`; ele foi ligado em 28/10, depois da comparação no painel.)


### Rodados em 23/10/2026

Os 17 SQL acima foram para o banco de produção pelo phpPgAdmin, um a um, com
"Paginar resultados" desmarcado. O banco foi de 24 para 53 tabelas `soupm_`.

Na mesma passada apareceu e foi consertado um estrago antigo: 73 textos com
acento gravados como Mac Roman (`Certidões`), 71 em colunas de texto e 2
dentro do JSON de `soupm_config`. A causa e a regra para não repetir estão em
`APRENDIZADOS.md` §45 — em resumo, **`LC_CTYPE=UTF-8 pbcopy`** e conferir o
texto já colado antes de executar.

**Os interruptores continuam todos desligados**, de propósito. Cada um muda o
que o militar vê e tem uma condição antes:

| Interruptor | Antes de ligar |
|---|---|
| `comunicados.fonte_app` (`firestore` → `api`) | cadastrar as categorias e ao menos um comunicado pelo painel |
| `notificacoes.envio_fcm` | `~/private/soupm_fcm.json` no servidor e o cron `envio_push.php` de pé |
| `notificacoes.fonte_app` (`firestore` → `api`) | só depois do corte, com a 2.2 na loja |
| `declaracoes.campanhas_ligadas` | cadastrar a campanha do ano em curso, senão ninguém consegue declarar |
| `niveis.ligado` | comparar no painel a regra nova com a de hoje |
| contracheque pela API | homologar o PDF gerado pela API contra o de hoje |

Falta ainda, do item 7: `ALTER FUNCTION public.soupm_conta_resumo(TEXT) OWNER
TO` um usuário que leia o esquema `qra` — o do cPanel não lê.

## 2. Arquivos em `~/private` no servidor (cPanel › Gerenciador de arquivos)

| Arquivo | Para quê | Como |
|---|---|---|
| `~/private/config_painel.php` | Segredo do link assinado dos anexos e da prévia do PDF (painel ↔ API) | `<?php return ['segredo' => '<64+ caracteres aleatórios>'];` — o **mesmo valor** vai no `conex/painelsoupmrr_local.php` do painel |
| `~/private/soupm_fcm.json` | Conta de serviço do Firebase, para a API mandar push sem as Cloud Functions (fase 4) | Console do Firebase › Configurações do projeto › Contas de serviço › Gerar nova chave privada. Permissão 600. Nunca no git |

## 2b. Chave do app no SISCHAMADOS (Meus chamados, fase 3c) — fase futura, quando o painel for para a intranet

1. Na intranet, SISCHAMADOS › Configurações › API Mobile: criar a chave do
   aplicativo "SouPM" (aparece uma vez só) e ligar a API Mobile.
2. Pôr no `env.json` da máquina, na linha `SISCHAMADOS_APP_CHAVE` (modelo em
   `env.example.json`), e guardar uma cópia no Drive, em "Arquivos SouPMRR".
   **Nunca no git.**
3. Só então liberar `atend.chamados` no painel (hoje fica "Em breve"). Sem a
   chave no build, a tela explica e mostra o código `CH-CHAVE`.

## 3. Cron do cPanel

| Comando | Quando | Para quê |
|---|---|---|
| `php ~/public_html/flutter/sigrh/cron/envio_push.php >> ~/logs/envio_push.log 2>&1` | A cada minuto | Fila de push (fase 4). Sem a conta de serviço e com `envio_fcm` desligado, sai sem fazer nada |
| `php ~/public_html/flutter/sigrh/cron/reset_senha.php >> ~/logs/reset_senha.log 2>&1` | A cada minuto | Reset de senha pedido pelo painel (SQL 10). Sem pedido na fila, não faz nada |
| `php ~/public_html/flutter/sigrh/cron/comando_sigrh.php >> ~/logs/comando_sigrh.log 2>&1` | A cada minuto | Comando pelo SIGRH (SQL 11): confere uma vez por dia e na hora em que o painel pede |
| `php ~/public_html/flutter/sigrh/cron/lembretes.php >> ~/logs/lembretes.log 2>&1` | Todo dia às 08:00 | Lembretes automáticos (SQL 18): férias que começam, certidão que vence, prazo de declaração (com as campanhas ligadas) e ciência de comunicado. Só manda os que o painel ligou; para conferir antes, rode com `--simular`. O de contracheque disponível fica no cron do contracheque que já existe: com o lembrete e o `envio_fcm` ligados, ele passa da Cloud Function para a fila de push |
| `php ~/public_html/flutter/sigrh/cron/versao_legada.php >> ~/logs/versao_legada.log 2>&1` | A cada 10 minutos | Leva para o Firestore das 2.1.x o mínimo legado que o painel definir, nunca acima do que as lojas têm publicado. Sem valor no painel, não mexe em nada; para conferir antes, rode com `--simular`. Precisa da conta de serviço em `~/private/soupm_fcm.json` |

## 4. Interruptores (depois dos itens acima)

Ligar pelo painel, ou por SQL (`UPDATE public.soupm_config SET valor = valor || '{...}' WHERE chave = '...'`):

| Chave | Campo | Quando ligar |
|---|---|---|
| `contracheque` | `pdf_api_matriculas: ["<sua matrícula>"]` | Para comparar o PDF novo com a sua conta (piloto) |
| `contracheque` | `pdf_api: true` | Depois de aprovar a comparação: o app passa a pedir o PDF à API |
| `comunicados` | `fonte_app: "api"` | Depois do SQL 9 e de publicar o primeiro comunicado pelo painel: a Início troca o anúncio do Firestore pela central |
| `declaracoes` | `campanhas_ligadas: true` | Depois do SQL 13 e de abrir pelo painel a campanha de cada tipo do ano em curso |
| `niveis` | `ligado: true` | **LIGADO em 28/10/2026.** A escada foi replanejada por você e ficou com **quatro degraus** (Adm 16, Comando 48, Gestor 378, Militar 2.653), toda montada sobre o `sigrh_nivel`, que já funciona. Medido antes de ligar: **219 gestores passavam a 442, com zero perdendo acesso** — foi o que resolveu o risco de 185 perderem o Mapa da Força. Conferido depois no "Ver o app como": a área Gestão aparece com o Mapa da Força. O app passa a usar "nível acima do primeiro" no lugar da regra antiga, na próxima leitura do `app_config` |
| `notificacoes` | `envio_fcm: true` | Depois da conta de serviço e do cron. A partir daí, o push da certidão emitida também passa pela fila (antes ia pela Cloud Function) |
| `notificacoes` | `fonte_app: "api"` | Depois de copiar o histórico do Firestore: no terminal do cPanel, `php ~/public_html/flutter/sigrh/cron/exportar_firestore.php` (só conta) e depois com `--gravar`; ele mostra a conferência por contagem no fim (§13, passo 4) |

## 5. Decisões e conferências

- **Notícias e agenda (P7), fase futura:** decidir o que da agenda da intranet pode aparecer
  para toda a tropa (hoje a API só tem a agenda dos comandantes, com permissão
  própria) e pedir à intranet uma rota de notícias publicadas. Sem isso a P7
  não entra.
- **Comparar o contracheque** novo com o de hoje com uma conta real (§12.3). O
  modelo já está sem a Diretoria de Recursos Humanos e com o QR (APRENDIZADOS
  §44).
- ~~**Ver a barra lateral no iPad**~~ **visto em 27/10/2026**, num iPad
  físico, no teste do build 4. Antes só havia passado por teste automático.
- **"Avisar quando voltar" na folha de bloqueio:** o app já mostra o botão
  quando o painel escolhe essa ação e grava o pedido no log
  (`modulo.avisar_quando_voltar`, com o código `MD-` da função). Falta a API
  mandar o push quando a função voltar a `ativo`. Até lá, o painel não deve
  escolher essa ação.
- **Pasta `sigrh/documentos/` no servidor:** três arquivos de uma tentativa que
  ficaram inacessíveis (o servidor bloqueia esse nome de pasta). Pode apagar a
  pasta pelo cPanel; o que vale está em `sigrh/doc/`.

## 6. Bloqueios do modo automático

- **25/10/2026:** publicar mudança no painel de **produção** (Funções e menu,
  "Salvar e publicar") foi barrado pelo verificador. Nada foi salvo; o painel
  ficou como estava (Linha do tempo da carreira: Ativo, selo "Novo"). A
  autorização tem de vir do usuário **direto na sessão do teste** (mensagem de
  outra sessão não vale), ou o usuário mexe no painel e a sessão confere no app.

---

## "SouPMRR falhou" ao fechar o app no iPhone (28/10)

O usuário fecha o app arrastando para cima e o iOS mostra "SouPMRR falhou",
depois de qualquer tela. Ele acha que e falso positivo, e **provavelmente
é** — mas a 2.2.0 está em revisão na Apple, e este projeto já perdeu duas
semanas de fila por tratar aviso de crash como ruído (§16). Então fica
medido, não suposto.

**O que já foi conferido no código (28/10):** nada nosso roda ao encerrar. O
observador de ciclo de vida trata só `paused` e `resumed`; o `detached` cai
no `default`. O `AppDelegate.swift` não tem `applicationWillTerminate`. Ou
seja, não há um candidato óbvio do nosso lado.

**Teste feito em 28/10, no simulador: não reproduz.** Três caminhos de
encerramento, nenhum relatório de falha:

| Caminho | Resultado |
|---|---|
| Fechar arrastando o cartão no seletor de apps | nenhum relatório |
| Mandar para segundo plano e depois encerrar | nenhum relatório |
| `simctl terminate` com o app em segundo plano | nenhum relatório |

Procurado em `~/Library/Logs/DiagnosticReports`, no `CrashReporter` do
simulador e no `system.log` dele. Nada, em nenhum dos três.

**E o suspeito que este projeto já tinha foi descartado.** O
`screenshot_recording_detector`, que no Android fechava o app a cada captura
(§48) e no iOS continua ligado, **remove o observador** que registra
(`removeObserver(self)` no `stopMonitoring`) e não tem risco de `dealloc`.
De passagem, ele mantém um `Timer` de 1 segundo com `target: self`, que
segura o plugin vivo e acorda o app todo segundo — gasto de bateria, não
causa de falha.

Com isso são **quatro negativas**: nada nosso roda ao encerrar, o plugin
está correto, e os três encerramentos não geram relatório. A balança pende
forte para **falso positivo** — o iOS registrando o fechamento do próprio
usuário como término anormal, que tecnicamente é.

**Não vou mexer em código por palpite.** Mudar algo sem reproduzir seria
trocar um incômodo conhecido por um risco desconhecido, logo depois de a
versão ser aprovada. O que falta é uma das duas conferências abaixo, e a
primeira leva dez segundos no seu iPhone:

**Duas conferências baratas, e a primeira decide:**

1. **O arquivo do próprio iOS.** No iPhone: Ajustes → Privacidade e
   Segurança → Análises e Melhorias → **Dados de Análise**, arquivos
   começando com `SouPMRR`. Abrir o mais recente e procurar o bloco
   `termination`. Se disser `namespace FRONTBOARD` com
   `explicit-terminate` (ou `SIGKILL` sem `EXC_BAD_ACCESS`), **é o próprio
   fechamento do usuário sendo registrado**: falso positivo, assunto
   encerrado. Se aparecer `EXC_BAD_ACCESS`, `EXC_BREAKPOINT` ou uma pilha com
   nome de plugin, é crash de verdade e a pilha diz onde.

2. **A nossa própria captura.** O app grava `AP-FATAL` em `soupm_erro` e a
   fila sobrevive ao fechamento (fica no `SharedPreferences` e sai no
   próximo envio), então um crash do lado Dart apareceria. No phpPgAdmin,
   com "Paginar resultados" desmarcada:

```sql
SELECT codigo, app_versao, count(*) AS vezes, max(recebido_em) AS ultimo
  FROM soupm.soupm_erro
 WHERE plataforma = 'ios' AND recebido_em > now() - interval '7 days'
 GROUP BY codigo, app_versao
 ORDER BY vezes DESC;
```

   **Limite desta segunda conferência, para não ler demais no resultado:**
   vazio prova que **não houve crash do lado Dart**, não que não houve crash.
   Um crash nativo (plugin, Firebase, o detector de captura do §48, que no
   iOS continua ligado) morre antes de o Dart registrar qualquer coisa. Por
   isso é o arquivo do item 1 que decide.

## O contracheque de outubro (27 e 28/10): feito

**Os três itens saíram em 28/10.** O que falta é só o senhor abrir o
contracheque de outubro e dizer se abre (ver o fim desta seção).

**O que aconteceu.** A folha de outubro entrou no banco. O militar abriu o
app, o mês aparecia na lista e **deu erro ao abrir**, numa tela de erro
antiga. O aviso de contracheque novo não havia saído ainda.

**O aviso não era problema, e já saiu.** O cron
`sigrh/notificacoes/notifica_contracheque.php` roda a cada 15 minutos e
estava certo: até as 11:45 a view só tinha setembro; às 12:00 outubro
apareceu com **99,9% de cobertura** (3.273 de 3.277; o limite era 2.622) e
ele disparou para 3.273 militares, pelo tópico `todos_militares` (Cloud
Function, porque `envio_fcm` segue desligado). Log em
`/logs/notifica_contracheque.log`. **O atraso era a carga da folha, não o
aviso** — é para isso que a cobertura existe.

**Três coisas para fazer, em ordem de valor:**

1. **A lista e a abertura leem views diferentes.** `listamesescontracheque_new.php`
   lê `vw_cc_novo_1`; `exibecontracheque_new.php` lê `vw_cc_novo2` e compara
   **cinco campos exatos** (`cpf`, `mes_extenso`, `matricula`,
   `relacaotrabalho`, `folha`) com valores que o app recebeu da **outra**
   view. Durante a carga, uma view pode ter o mês e a outra não, e aí **o app
   lista um mês que não consegue abrir**. Conferir se o erro voltou a
   acontecer agora que a carga fechou: se não, era a janela de carga e a
   correção é a mensagem (item 2); se sim, é divergência de chave, e aí medir
   qual dos cinco campos difere entre as duas views para outubro.
2. **Ponto cego:** a abertura responde `code: 0` quando não acha a folha e
   **não registra nada** no `error_log` (só registra quando o `execute()`
   falha). Foi por isso que o log da API não tinha nada de hoje. Um endpoint
   que falha sem deixar rastro é o §22 outra vez: acrescentar o registro, com
   o código `CC-SEM-FOLHA`, que a fase 3b já criou.
3. **FEITO (28/10).** Tela de erro antiga: era o `SecondScreen()` em
   `lib/pages/page_contracheque.dart:1001`. A tela do contracheque não entrou
   na lista da fase 6 (declarações, Mapa da Força, plantão, e-mail). Trocar
   pelo `EstadoErro`, com código e "Detalhes técnicos", e **separar "mês sem
   folha" de falha de verdade** — hoje as duas caem na mesma tela muda. Isto
   é do app, então só chega ao militar na versão seguinte; entra na branch
   esperando o próximo build.

**Nota de leitura do código:** `buscaContracheque` (em
`lib/services/dados_sql.dart`) **nunca lança** — todo caminho devolve o
modelo, e os `catch` engolem. Então o `SecondScreen` do `FutureBuilder` só
aparece se algo em `_buscaDadosSql` lançar, e lá o único candidato é o
`double.parse` (sem `tryParse`) dos proventos, no caminho da API antiga
(`tipo == "A"`), onde o valor vem como "8.791,85". Vale conferir isso junto
com o item 3.

### O que foi feito em 28/10

| Item | Onde | Situação |
|---|---|---|
| Mensagem de "mês sem folha" | app, `CC-SEM-FOLHA` | feito (commit `2b27450`) |
| Registro no log da API | `exibecontracheque_new.php` | **no ar** (commit `a276c0a`), conferido com um mês impossível |
| Tela de erro antiga | `SecondScreen` → `EstadoErro`, nas duas telas | feito |

Dois defeitos a mais apareceram no caminho:

- **o valor da rubrica era lido com `double.parse` sem limpar o formato.** Na
  API antiga ("1.234,56") isso lançava, e era a **única** coisa capaz de levar
  ao `SecondScreen`, porque o `buscaContracheque` nunca lança;
- **havia dois leitores do mesmo valor, e só um estava certo.** O do "O que
  mudou" (P1) já olhava a vírgula antes de limpar os pontos; o da tela, não — e
  limpar os pontos de `1234.56` daria `123456`. Agora é um só
  (`features/contracheque/valor_rubrica.dart`), com teste dos dois formatos.
  Valor ilegível no total vira `CC-VALOR`, nunca zero (§37).

**Falta o senhor conferir:** abrir o contracheque de outubro. Se abrir, era a
janela de carga das duas views e o assunto fecha. Se não abrir, a mensagem
agora diz qual é o caso, e o `error_log` da API passa a ter a linha
`CC-SEM-FOLHA` com a chave da consulta — foi para isso que o registro entrou.

**Um achado de segurança saiu deste trabalho** e está na lista privada
(`~/code/api-soupmrr-private/PENDENTE_SEGURANCA.md`), fora deste repositório,
que é público. Resumo sem detalhe: um endpoint do contracheque não confere
quem pede. A correção tem ordem obrigatória e começa por uma versão nova do
app, então não dava para fazer hoje.


## Ao publicar qualquer versão: avisar a sessão do painel

Combinado em 28/10. **O painel não lê as lojas** — ele só sabe o que foi
publicado se alguém disser. Três coisas dependem disso, e a terceira é uma
armadilha:

1. **Histórico** (`soupm_versao_app`): a versão entra com a ficha técnica do
   build (Flutter, Dart, SDKs, pacotes).
2. **Recomendada** de cada loja. A **mínima não precisa subir**: 2.2.0 e
   2.2.1 convivem, e subir a mínima obriga todo mundo a atualizar sem
   necessidade.
3. **Mínimo legado do Firestore** (o que as versões 2.1.x leem): ele **não
   pode ficar acima da última versão publicada em cada loja**. Se ficar, o
   iPhone na 2.1.x passa a pedir uma versão que a App Store não tem — o app
   fica inutilizável e o militar não tem o que fazer. A tela do painel
   **bloqueia** salvar isso, **mas a trava só funciona se o número publicado
   estiver registrado**. Ou seja: a proteção depende do passo 1.

Por isso o aviso não é cortesia, é parte da publicação: **publicou, avisa**.

## A Apple aprovou a 2.2.0 (28/10/2026)

A espera acabou. Os quatro passos que estavam anotados na seção de 27/10
valem a partir de agora, **nesta ordem**:

1. **Juntar a `feature/soupm-2-2` no `main`.**
2. **Mínima e recomendada no painel**, com o cuidado do mínimo legado: ele
   nunca pode passar do que cada loja tem publicado.
3. **SQL do item 22** (a `soupm_e_gestor`), compilando antes num Postgres
   local (§19 e §47). Esta máquina não tem Postgres, então é o primeiro
   obstáculo prático.
4. **Os interruptores, do mais barato ao mais arriscado:** comunicados →
   piloto do contracheque → um tipo de pendência homologado → níveis. O de
   níveis continua esperando a decisão do trio (§1, item 23).

### Teste no simulador, 28/10

Rodado em modo vitrine (iPhone 17 Pro, `VITRINE=true`), conferindo o que
mudou hoje:

- **O contracheque fecha as contas.** 5.486,42 + 500,00 + 1.500,00 =
  7.486,42 de proventos; 742,18 + 767,20 = 1.509,38 de descontos; líquido
  5.977,04. É o teste direto do leitor de valores novo, que é a mudança mais
  arriscada do dia — se ele estivesse errado, o líquido estaria errado.
- **"O que mudou" abre** e usa o mesmo leitor, sem falha.
- **A Início desenha certo** com Comando, comunicados, pendências, atalhos e
  cards.
- **O convite de biometria diz "Face ID"**, não "Touch ID" — a pendência do
  §33 está resolvida.

**O que o simulador NÃO testou, e por quê:** no modo vitrine sempre há dado,
então os dois caminhos que mudei hoje não acontecem lá. O das pendências sem
tipo ligado está coberto por teste de widget; o da faixa do Comando vazia
**foi conferido só por leitura** — testá-lo exigiria simular o Firestore, o
que custa mais do que vale para uma remoção de cinco linhas. Quem confirma é
a próxima abertura real: a faixa não deve reservar espaço antes de ter o que
mostrar.

## Onde paramos em 27/10/2026 (esperando a Apple)

O usuário decidiu **aguardar a resposta da Apple** antes de mexer em produção.
Esta seção existe para a próxima sessão não ter de refazer a medição.

### Não há fila de mudanças esperando versão nova

Medido, não suposto: desde o build que está em revisão (o commit `64a2e93`),
**um único commit mexeu em código** — `ee098b3`, a limpeza dos 14 avisos do
`flutter analyze`. Todo o resto do dia foi documentação.

Dentro dele, nove eram código morto (import e variável sem uso) e três eram
defeito:

- `dados_sql.dart`: `folha` nulo chegava ao contracheque antigo como a string
  `"null"`; agora chega vazio. **É o único visível ao militar.**
- `calendar_widget.dart`: `return null` explícito no `todayBuilder` (o
  comportamento já era esse).
- `configura_plantao.dart`: os campos saíram do `StatefulWidget` para o
  `State`; reconstruir a tela deixava de esquecer a data escolhida.

Conclusão: **o primeiro build depois da 2.2.0 sai quando houver motivo** — a
chave do SISCHAMADOS, ou algo que apareça no uso real —, não para despejar
atraso.

### O que muda sem build, e o que exige build

É a arquitetura da 2.2 funcionando: quase tudo é configuração.

| Muda sem build novo | Exige build novo |
|---|---|
| Menu, textos, ícones, artes, cards da Início | `SISCHAMADOS_APP_CHAVE` no `env.json` (é `--dart-define`): **Meus chamados só sai com build** |
| Comunicados, pendências, campanhas de declaração | Migração das telas antigas para `features/` (invisível ao militar) |
| Versão mínima e recomendada | Notícias e agenda (P7), travada na intranet |
| Contracheque pela API (`pdf_api`), push pelo FCM | Os itens da 2.3: login pela intranet, Escalas, SVI |
| Bloquear e liberar função, manutenção | |

### Quando a Apple responder, nesta ordem

1. **Aprovada:** juntar a `feature/soupm-2-2` no `main`.
2. Subir a mínima e a recomendada no painel — atenção ao **mínimo legado**, que
   o painel não deixa passar do que cada loja tem publicado (§5.6 do
   PAINEL_ADMIN).
3. Rodar o SQL do **item 22** (§1), **compilando antes num Postgres local**
   (§19 e §47 do APRENDIZADOS).
4. Só então os interruptores (§4), do mais barato ao mais arriscado:
   comunicados → piloto do contracheque → um tipo de pendência homologado →
   níveis (este exige a comparação de quem ganha e quem perde o Mapa da Força).

Nenhum dos quatro pede versão nova do app.

**Se vier rejeitada**, a hipótese mais provável não é o binário: são as **notas
para a revisão**, que estão velhas e citam "escalas", hoje "Em breve". Isso se
corrige no texto, sem build (§31 do APRENDIZADOS).

### Fechado em 27/10/2026

- **Testado em aparelho:** iPhone e iPad físicos, build 4, tudo certo. Caiu
  junto a conferência da barra lateral do iPad.
- **Conferências do banco (pela sessão do painel, somente leitura):** 64
  tabelas, todas no esquema `soupm`; 25 funções, **24 com `EXECUTE`** para o
  usuário da API — inclusive a `soupm_e_gestor_legado`, que roda em toda
  leitura do `app_config` enquanto `niveis.ligado` for `false`. A única sem é a
  `soupm_conceder_painel`, e é assim que deve ser. `SECURITY DEFINER` só nas
  duas em que a elevação é o objetivo: o §46 não se repetiu na virada.
- **Interruptores hoje:** `comunicados.fonte_app = api`; `pdf_api`,
  `envio_fcm`, `niveis.ligado` e `campanhas_ligadas` em `false`;
  `notificacoes.fonte_app = firestore`; `versao_config = 19`; **0** tipos de
  pendência ligados.
- **O cartaz de abertura é deliberado.** Comunicado da eleição, id 1, público
  TODOS, `abertura_ate_ciencia = FALSE` — aparece **uma vez por aparelho**, não
  volta. O revisor o vê uma vez, como qualquer militar. Configurado pelo
  usuário de propósito; não é pendência.
- **Lições novas no git:** §44 (arquivo de inclusão se mede; 500 não é
  proteção), §18 (espelhar o servidor traz a credencial junto) e, no
  PAINEL_ADMIN, as três listas brancas da mídia e o painel fora da intranet.
- **Único SQL pendente:** o item 22, e de propósito não é para rodar agora.

---

## Onde paramos em 26/10/2026 (2.2.0 enviada às lojas)

- **Android:** 2.2.0 (`versionCode` 58) enviada pelo usuário à Play Store.
- **iOS:** 2.2.0, **build 4**, enviada para revisão da Apple às 20:13. Foi do
  mesmo arquivo do iOS de 26/10 à tarde, já com a entrada suave na Início. O
  "O que há de novo" é o resumido e não cita Android. As capturas novas (modo
  vitrine, 6 no iPhone e 5 no iPad) estão em todos os tamanhos. Os arquivos
  ficam em `appstore-capturas/jpg22/`, fora do git, com cópia no Drive em
  "Arquivos SouPMRR/capturas-2.2.0".
- Os dois builds saíram da branch `feature/soupm-2-2`, que **ainda não foi
  juntada no `main`**. Juntar depois de aprovada nas duas lojas.

**Falta (depende do usuário)**
1. ~~Instalar o build 4 pela TestFlight num iPhone e num iPad e abrir o
   app~~ **feito em 27/10/2026**: o usuário testou nos dois aparelhos
   físicos e estava tudo certo. O teste saiu **depois** do envio, não
   antes, como manda o APRENDIZADOS §1 — deu certo, mas a ordem foi a de
   risco: se tivesse quebrado, a correção pegaria a fila da Apple de novo.
2. Acompanhar a revisão da Apple, que leva até 48 h. As notas para a revisão
   são antigas: citam "escalas", que estão "Em breve", e as rejeições da
   2.1.x. Se a Apple questionar as funções "Em breve", responder que Escalas,
   SVI e Meus chamados estão assim de propósito, até a versão 2.3.
3. Depois de aprovada nas duas lojas: juntar a `feature/soupm-2-2` no `main`
   e subir a versão mínima e a recomendada no painel, quando for a hora.
4. Continuam valendo os itens abaixo: homologar um tipo de pendência, a conta
   de serviço do FCM em `~/private` e o cron `versao_legada.php`.

---

## Onde paramos em 25/10/2026 (para continuar no iMac)

Tudo no git: app na `feature/soupm-2-2` (não juntar no `main`: o usuário testa
no aparelho primeiro), API na `main` do repositório privado. Os 36 arquivos da
API mexidos no dia estão iguais no servidor (conferido com `cmp`). No iMac:
`git pull` nos dois repositórios e seguir o SETUP.md.

**Feito em 25/10/2026**
- Função em manutenção ou bloqueada vale em todo caminho: card da Início,
  push, link, dica, comunicado e rota direta (guarda na rota,
  `lib/core/navegacao/guarda_funcao.dart`); a API recusa com o código `MD-`
  (`sigrh/funcao_estado.php`, em férias, contracheque, tempo de serviço,
  carreira, declarações, Mapa da Força e emissão de certidão).
- Comunicado também como card fixo na Início (painel: "Card na Início" no
  editor do comunicado; SQL `2026-10-25_soupm_comunicado_card.sql` rodado).
- Tema mais usado guardado por 2 anos (`soupm_tema_dia`, SQL rodado; o app
  passou a mandar o tema da tela e a escolha em Aparência).
- Tema claro: selo "Admin" e textos com contraste (regra no DESIGN.md §6).
- Teste de ponta a ponta na vitrine (Android): 61 itens, falhas corrigidas;
  dois AP-FATAL do painel corrigidos (teclado no login do Android e contagem
  da tela de entrada). Entrada por Face ID/digital e login do Android no
  padrão 2.2.

**Falta (depende do usuário)**
1. Testar no aparelho (TestFlight e APK) a branch `feature/soupm-2-2`.
2. ~~Teste dos interruptores do painel~~ **feito em 26/10/2026**: manutenção,
   "Em breve", fora do menu, card do painel, comunicado como card e bloco da
   Início conferidos no app e desfeitos; um defeito da API corrigido
   (e6c62d4). Falta: **homologar um tipo de pendência** (só tipo com fonte
   confirmada pode ser ligado). O "Simular para uma matrícula" voltou a
   funcionar em 26/10 (faltava o `config_painel.php` em `~/private`).
3. ~~Rodar o SQL do catálogo~~ rodado em 25/10/2026.
5. ~~Revisão no iPad~~ **feita em 26/10/2026** (iPad Air 11", vitrine): Início,
   Serviços em 3 colunas, Contracheque, compartilhar (balão do sistema, sem
   travar), Perfil e horizontal, sem erro de layout no log. Corrigido: o Perfil
   dizia "iPhone" no iPad (1520a19). Fica para depois: lista e detalhe lado a
   lado no iPad (§15.4) e o teste em Split View, que o simulador não faz por
   comando.
4. Antes da loja: TestFlight em iPhone e iPad físicos, capturas novas em
   todos os tamanhos (vitrine), "O que há de novo" separado por loja
   (APRENDIZADOS §31–32).

Relatório completo do teste: pasta de notas das sessões
(`e2e-roteiro-2-2.md` e `e2e-android-vitrine.md`), fora do git.

---

## Onde paramos em 23/10/2026 (fim da tarde)

Tudo o que foi feito está no git (app na `feature/soupm-2-2`, API na `main`) e
no banco de produção. As decisões 1 e 2 foram tomadas (a 1 mudou em 24/10/2026);
a ordem da 3 está combinada com o painel e espera o seu "pode".

### 1. Roteiro único de SQL de produção (fase sem intranet, 24/10/2026)

Decisão do usuário: "Esqueça intranet por enquanto." Painel e app ficam no
mesmo banco, com o usuário de banco da API, e **tudo roda com a conta do
cPanel** no phpPgAdmin. Nada depende dos esquemas `intranet` nem `sccti`, e
não há nada para pedir ao administrador do banco. Cada arquivo pode rodar
mais de uma vez. Ordem:

| # | Arquivo | Onde está | Para quê |
|---|---|---|---|
| 1 | Os SQL da tabela do §1 acima que ainda não rodaram, **com o `_niveis.sql` e o `_niveis_rapido.sql`** | `sql/` da API | Tudo do app 2.2. O passo 3 usa `soupm_papel`, `soupm_papel_regra` e `soupm_papeis_para`, que nascem nos SQL de níveis |
| 2 | `A_tabelas_painel_producao.sql` | `painelsoupmrr/database/producao/` da intranet | As 7 tabelas do painel. Termina com uma conferência: as 7 têm de aparecer como "existe" |
| 3 | `C_acesso_proprio_producao.sql` | mesma pasta (commit b3f37d83) | Quem entra no painel e o que pode: 58 recursos, 33 permissões, a auditoria própria (`soupm_painel_auditoria`) e os Administradores (o nível 1 do SIGRH e a matrícula que o usuário indicou). No fim, lista os Administradores. Se a conta do cPanel não ler a visão do SIGRH, ele avisa e segue só com a matrícula indicada |
| 4 | `D_telas_prototipo_producao.sql` | mesma pasta (commit c497f463) | A imagem aprovada nas áreas do menu (`arte_imagem`) e os textos do rodapé e do botão das telas de erro |
| 5 | `2026-10-24_soupm_painel_permissoes.sql`, de novo | `sql/` da API | Dá ao usuário da API a escrita nas tabelas novas dos passos 2 a 4 (auditoria, papéis) e a leitura de `recursoshumanos.vw_buscar_policial`. O que ele já tinha aparece como `ok (já tinha)`; tabela que ainda não existe aparece como "pulado" |

Depois:
- Entrar no painel com a **matrícula e a senha do app** e conferir a tela
  Papéis. Se aparecer `PSP-DB-03`, a mensagem diz qual tabela falta.
- Publicar em pmrr.online os dois arquivos que o painel corrigiu (as telas
  abriam sem estilo e o tema escuro não pegava): `nucleo/casca.php` e
  `assets/nexus/nexus2-componentes.css`.
- Criar `~/public_html/painelsoupmrr/midia/`, com gravação pelo PHP, e
  publicar o `midia/.htaccess` do painel. As imagens aprovadas ficam lá e o
  app as busca em `https://pmrr.online/painelsoupmrr/midia/`.

**Não rodar:** os P0 a P8 antigos do painel (estão em `substituidos/`) e o
`intranet_depois/B_intranet_acl_producao.sql`, que fica para quando o painel
for para a intranet.

Fica a dívida "leitura e escrita no mesmo usuário" (PAINEL_ADMIN §7, item 6).

### Publicado em 24/10/2026

- `sigrh/app_config.php` e `sigrh/sessao_app.php` (backup em
  `/backups_api/sigrh/*.bak-20261024-v1`, conferidos com `cmp` depois do
  envio, parte pública respondendo 200). Trazem: a lotação para a linha da
  saudação, os textos de tela do painel (`soupm_config` 'textos'), a imagem
  aprovada nas áreas do menu (quando o SQL D do painel tiver rodado) e a mídia
  servida de `https://pmrr.online/`. A parte de quem entrou não foi testada
  com conta real: conferir no app ou no `error_log` de `sigrh/`.
- No `error_log` de `sigrh/` há um erro das 11:21 de 23/10:
  `permission denied for function soupm_e_gestor_legado`. O passo 5 do
  roteiro acima (permissões) dá EXECUTE em todas as funções `soupm_*`; se
  voltar a aparecer depois dele, a função precisa de dono que leia o SIGRH
  (APRENDIZADOS §46).

### O que o painel ainda não mostra por falta da API ou do app

- **Blocos do contracheque** (`soupm_documento_padrao`, campo `blocos`): o
  painel grava, o `contracheque_doc.php` ainda não lê. Até ler, o PDF não muda.
  Só importa quando o contracheque pela API for ligado.
- **Chamados no app** (`soupm_config` 'chamados': `acesso_movel`,
  `sessao_dias`, `tipos`): só valem quando o SISCHAMADOS voltar (2.3).
- **Rede no `app.abrir`**: o app manda tempo de abertura, tema, tamanho da
  fonte e modelo; a rede (Wi-Fi ou dados) pediria um pacote nativo novo.
- **Sem fonte, mostrados como "—" no painel:** tempo e falhas do PDF do
  contracheque, recusas `DC-FECHADA`, os números de chamados e as sessões
  abertas do painel.

### Fase futura: quando o painel for para a intranet

Nada disto entra agora. No app, as funções ficam "Em breve", com a folha de
bloqueio e o código `MD-`:

- **Login único pela intranet** (2.3, SOUPM_2_2 §6.6).
- **Minhas escalas e SVI** (`op.escalas`, `op.svi`) e os avisos do SIGE: usam a
  API da intranet. Desde o commit 0a7e485 o app não entra mais na intranet em
  segundo plano enquanto as duas estiverem bloqueadas.
- **Meus chamados** (SISCHAMADOS, `atend.chamados`) e o "Abrir chamado
  técnico" das telas de erro e do "Preciso de ajuda": a chave do app (§2b
  abaixo) e as rotas da API móvel.
- **Notícias e agenda** (P7, `inst.noticias`): rotas da intranet (§5).
- **No banco:** o `B_intranet_acl_producao.sql` (cadastro do módulo na ACL da
  intranet) e a leitura de `sccti` (medido em 24/10: o usuário da API não tem;
  as de `intranet` ele já tem). A regra de nível "perfil da intranet"
  (`soupm_nivel_para`) só vale quando a intranet existir no banco.

### 2. Arquivos de inclusão da API — feito em 24/10/2026

Um `.htaccess` na raiz da API bloqueia pela web os arquivos que só são
incluídos (conexão, `sessao_app.php`, bibliotecas das certidões e do
contracheque, `push_lib.php`, PHPMailer) e os `error_log`. Medido antes e
depois: os 14 arquivos passaram de 200 (ou 500) a 403, e os endpoints públicos
respondem igual, inclusive `certidoes/verificar.php` e `doc/conferir.php`.
Endpoint novo que seja só de inclusão entra na lista do `.htaccess`.

### 3. A virada para o esquema `soupm` — feita em 24/10/2026

Pedido do usuário: "tudo deve ficar no nosso esquema do soupm e nao no
public". Feita sem tirar nada do ar:

- `conexao.php` da API com `SET search_path TO soupm, public`; os 31 PHP da
  API sem o `public.` (commit 91284f9 da API); o painel publicado com o mesmo
  ajuste (commit 2a2daa44 da intranet).
- No banco, numa transação só: `2026-10-23_soupm_esquema_proprio.sql` +
  `2026-10-24_soupm_funcoes_para_esquema.sql`. Ficaram em `soupm` as 63
  tabelas, as 32 sequências e 21 funções (com as mesmas permissões); em
  `public` só as duas `soupm_conceder_*`. O gatilho do protocolo do feedback
  aponta para a função nova. A concessão ao usuário da API rodou de novo, sem
  falha.
- Conferido: `app_config` e `log.php` respondem, o `log.php` gravou um evento
  de teste (`teste.virada_esquema`), `/painelsoupmrr/entrar` responde 200 e o
  `error_log` de `sigrh/` não tem erro novo.
- Backup dos PHP de antes: `/backups_api/virada-soupm-20261024/`.

**Daqui em diante:** SQL novo cria em `soupm.` (os `.sql` versionados já
foram reescritos, commit 0ab86b9 da API). Os SQL A, C e D do painel criam em
`public.` e não rodam de novo como estão.

**Falta:** entrar no painel com a matrícula do Administrador e abrir algumas
telas (leitura e gravação).

### O que já está no ar

- Os 17 SQL da 2.2 (banco de 24 para 53 tabelas `soupm_`).
- O conserto dos 73 textos gravados como Mac Roman (APRENDIZADOS §45).
- A árvore de menus do protótipo, com a área Institucional nova.
- As 9 funções que liam o SIGRH passaram a `SECURITY INVOKER` — era o que
  fazia a área Gestão sumir do menu para todo mundo (APRENDIZADOS §46).
- O painel no ar em `/painelsoupmrr`, com a matrícula normalizada nos dois
  lados.

### Falta conferir no app (um toque)

A área **Gestão** deve ter voltado ao menu depois do conserto das funções,
mas o simulador caiu para a tela de login antes de eu confirmar. Entrar e
abrir Serviços: devem aparecer **6 áreas**, não 5.
