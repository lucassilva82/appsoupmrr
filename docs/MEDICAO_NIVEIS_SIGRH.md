# Níveis de acesso: a medição das fontes do SIGRH (27/10/2026)

Movido do `docs/PENDENTE_USUARIO.md` (antigo §1, item 23) em 31/10/2026, na limpeza daquele arquivo. É referência para quando a regra `funcao_sigrh`/lotação for implementada; nada aqui está pendente agora.


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


