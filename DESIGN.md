# Padrão de design — SouPMRR

Como construir qualquer tela nova do app para que ela pareça parte do mesmo
produto. Se a tela que você está escrevendo precisar de uma superfície, uma
cor ou um tamanho de ícone, a resposta está aqui — não invente um valor novo.

A base é a skill `ui-ux-pro-max` (acessibilidade, alvos de toque, hierarquia,
consistência de ícones). Este documento é a tradução dela para este app.

---

## 1. A ideia central

O app é **translúcido**. Nada de blocos de cor sólida: as superfícies deixam o
fundo passar, desfocado, e é a borda fininha que dá o contorno.

Isso só funciona se houver **alguma coisa atrás para desfocar**. Por isso:

- o fundo é pintado **uma vez só**, em `main.dart`, pelo `FundoSuave`;
- o `scaffoldBackgroundColor` do tema é `Colors.transparent`;
- **nenhuma tela pinta o próprio fundo.**

> Se você escrever `Scaffold(backgroundColor: ...)` ou um `Container` de tela
> cheia com `color`/`gradient`, está tapando o fundo global e a tela vai voltar
> a parecer preta. Já aconteceu em nove telas; foi tudo removido.

### Adaptação por plataforma

O `CartaoVidro` resolve isso sozinho:

- **iOS** — vidro de verdade: `BackdropFilter` + degradê translúcido + borda.
- **Android** — superfície tonal do Material 3. Blur pesado destoa do padrão
  da plataforma e custa caro em aparelho simples.

Você não precisa fazer `if (Platform.isAndroid)` na sua tela. Use o componente.

---

## 2. Componentes — use estes, não refaça

| Componente | Arquivo | Para quê |
|---|---|---|
| `CartaoVidro` | `lib/widgets/vidro.dart` | **Toda** superfície de conteúdo: cards, caixas, linhas de lista agrupadas |
| `CartaoDestaque` | `lib/widgets/vidro.dart` | O cartão de abertura da tela (um por tela, no máximo) |
| `FundoSuave` | `lib/widgets/vidro.dart` | Fundo global. Já está em `main.dart` — não use de novo |
| `FundoBarraVidro` | `lib/widgets/barra_vidro.dart` | Fundo de app bar (vai no `flexibleSpace`) |
| `CustomAppBar` | `lib/widgets/custom_appbar.dart` | App bar pronta, com título e selo de gestor |
| `BarraNavegacao` | `lib/widgets/barra_navegacao.dart` | Barra inferior (só o `MainShell` usa) |
| `dialogoConfirmacao` | `lib/widgets/dialogo_confirmacao.dart` | Confirmar ação destrutiva |
| `RequisitosSenha`, `AvisoCaixa`, `decoracaoCampo` | `lib/widgets/requisitos_senha.dart` | Telas de senha e acesso |
| `VersaoApp`, `TextoVersao` | `lib/widgets/versao_app.dart` | Versão do app (lê do `PackageInfo`, nunca hardcode) |
| `CabecalhoCartao`, `DestaqueCartao`, `BarraProgressoCartao`, `PilulaCartao`, `ParCartao`, `MarcadorCartao`, `DivisorCartao`, `RodapeCartao` | `lib/widgets/cartao_painel.dart` | As peças dos cards do painel — ver §2b |
| `MarcaDaguaCartao` | `lib/widgets/marca_dagua_cartao.dart` | O desenho apagado no canto do card — ver §2c |

### `CartaoVidro`

```dart
CartaoVidro(
  raio: 16,                         // 16 é o padrão; 14 em caixas menores
  padding: const EdgeInsets.all(14),
  onTap: () { ... },                // opcional — já traz o ripple
  tingimento: AppColors.gold,       // opcional — só para destacar um item
  child: ...,
)
```

`tingimento` é exceção, não regra. Hoje só o "Mapa da Força" (dourado) e o
"Sair" (vermelho) no menu usam.

### `CartaoDestaque`

Vidro tingido com a primária do tema. **O conteúdo usa as cores do tema**
(`onSurface`, `primary`), nunca `Colors.white` fixo — no modo claro o fundo
dele é claro.

---

## 2b. Gramática dos cards do painel

Os cards de dado da Início — tempo de serviço, contracheque, plano de férias —
seguem todos a mesma ordem:

```
cabeçalho discreto  →  UM número grande  →  apoio  →  rodapé
```

O peso fica todo no número. Tudo em volta é cinza de apoio, e só a ação
(pílula, link) usa azul. Antes era o contrário: selo, chip, badge e barra
disputavam atenção e o dado em si saía em 11pt espremido dentro da barra de
progresso.

Regras que caem desse desenho:

- **Nada de quadradinho tingido atrás do ícone do cabeçalho.** É uma segunda
  superfície dentro de uma superfície — o empilhamento de tons do §3b.
- **Um rótulo por bloco**, em caixa alta, 11pt, na primária (`estiloRotulo`).
- **Barra de progresso sem texto dentro.** Rótulo sobre barra colorida não
  fecha 4.5:1 em toda a extensão, porque o fundo muda no meio dela.
- **Legenda de quadradinhos coloridos, não.** Quando há duas origens de dado,
  a barra sai em dois tons e o rodapé nomeia a segunda em uma frase.
- **Selo não pisca.** O `NOVO` do contracheque tinha um `AnimationController`
  em `repeat(reverse: true)` eterno; movimento aqui responde a estado, não
  decora (§7).
- Cada card usa `kPaddingCartao` e raio 16, para que empilhados pareçam a
  mesma família.
- **Pílula cheia só para o que é curto e pontual.** O countdown das férias
  era uma faixa azul de 40pt dizendo "Começam em 69 dias"; virou uma linha de
  texto com o azul só na parte que importa, e sobrou espaço para dizer também
  quanto dura o período. Frase explica mais que selo e ocupa menos.
- **Rótulo diz a posição, não só o nome.** "2ª parcela" não responde de
  quantas; "2ª de 2 parcelas" responde.
- Os tamanhos saem de `AppDisplaySize`, nunca de um número solto no card —
  foi assim que os três voltaram a divergir depois da primeira padronização.

---

## 2c. A marca d'água dos cards

Cada card do painel tem, no canto, um desenho grande, inclinado e quase
apagado. Não é enfeite solto: ele repete em forma o que o card diz em texto.

| Card | Desenho | O que o acento marca |
|---|---|---|
| Plano de férias | calendário | o intervalo selecionado |
| Contracheque | cédula | o valor da nota |
| Tempo de serviço | medalha | o arco do tempo cumprido (o percentual de verdade) |

Três coisas aprendidas fazendo isto:

- **Desenhar, não usar `Icon(...)` em corpo 90.** Ícone do Material nesse
  tamanho não vira ilustração, vira um ícone grande: traço de espessura fixa,
  sem hierarquia interna e com canto duro batendo na borda do card.
- **Máscara radial, nunca linear.** Um degradê de um canto ao outro deixa o
  canto oposto opaco, e lá o desenho encosta no texto com aresta de régua.
- **Os tons ficam juntos**, em `_Tons`, para os três terem o mesmo peso.
  Ajustar um sem os outros é o caminho para um aparecer mais que o resto.

A posição é por card (`Positioned`), porque cada um tem um controle diferente
no canto para desviar — o olho do contracheque, o percentual do tempo de
serviço.

---

## 3. Tokens

### Cores

Vêm de `lib/utils/app_theme.dart`. Na tela, leia sempre do tema:

```dart
final theme = Theme.of(context);
theme.colorScheme.primary      // navy no claro, azul claro no escuro
theme.colorScheme.onSurface    // texto
theme.colorScheme.error
```

`AppColors` só para o que é identidade visual fixa: `gold` (gestor), `navy`,
`blue`. **Não use `AppColors.blue` como cor de texto ou de botão** — no modo
escuro ele não tem contraste. Use `colorScheme.primary`.

Semântica de valores (contracheque, proventos/descontos):

| Significado | Escuro | Claro |
|---|---|---|
| Positivo / provento | `#6EE7A0` | `#14713B` |
| Negativo / desconto | `#FF9E9E` | `#B3261E` |

### Ícones — `AppIconSize`

| Token | Valor | Onde |
|---|---|---|
| `xxs` | 12 | selos e chips, ao lado de texto de 9–11 |
| `xs` | 16 | listas densas, dentro de texto |
| `sm` | 20 | campos, linhas de lista |
| `md` | 24 | **padrão** — barra inferior, app bar, ações |
| `lg` | 28 | botões do menu principal |
| `xl` | 32 | ilustrações e destaques |

Número solto em `size:` é erro de revisão. Família única: `_outlined` para o
estado inativo, `_rounded` preenchido para o ativo — nunca misture `_rounded`
com a variante normal no mesmo grupo.

### Raios

| Valor | Onde |
|---|---|
| 8–10 | chips, selos, badges |
| 12 | linhas de lista, botões |
| 14 | caixas internas, campos |
| 16 | cards (o mais usado) |
| 20–22 | diálogos e cartão de destaque |
| 28 | topo de bottom sheet |

### Espaçamento

Múltiplos de 2, na prática 6 / 8 / 10 / 12 / 14 / 16 / 20 / 24.
Margem lateral de tela: **16**. Entre cards: **10**.

---

## 3b. Profundidade — um tom só

Quando uma tela tem listas dentro de listas, a tentação é dar uma superfície
a cada nível. Não faça: cada nível com um cinza um pouco diferente deixa a
tela com meia dúzia de pretos encavalados, e o usuário não consegue dizer o
que está dentro do quê.

A regra aqui:

| Profundidade | Tratamento |
|---|---|
| Nível 1 (a entidade da tela) | Superfície tingida, raio 14 |
| Seção dentro dela | Superfície neutra (`onSurface` a 0.055), raio 12 |
| Nível 2 em diante | **Sem superfície** — indentação de 12 + guia de 2px à esquerda |

A guia é desenhada **uma vez para o bloco inteiro de filhos**, nunca uma por
filho — senão ela sai tracejada, com um corte na margem de cada item.

### Duas armadilhas do Flutter nisso

`withValues(alpha:)` **substitui** o alfa, não multiplica. Em tiles aninhados,
`cor.withValues(alpha: 0.7)` sobre uma cor que já vinha a 0.20 devolve 0.70 e
o bloco volta a ficar opaco.

`ExpansionTile` aberto pinta o fundo do tile inteiro, filhos incluídos — com
três níveis a translucidez se empilha até virar cor chapada. Por isso:
fechado é tingido, aberto é transparente. E `shape: const Border()` /
`collapsedShape: const Border()` tiram os divisores que aparecem assim que o
fundo some.

### Escala de texto

Nada de multiplicar tudo por um fator. Havia um `scale = 0.82` nessa tela que
transformava 13 em 10,66 e 11,5 em 9,43 — valores arbitrários, exatamente o
que a regra de consistência proíbe. Use os números da escala: 10, 11, 12, 13,
14, 16, 18.

Acima disso há a escala de display, só para o número herói de um card
(`AppDisplaySize`, em `cartao_painel.dart`):

| Token | Valor | Onde |
|---|---|---|
| `heroi` | 28 | o número principal do card |
| `heroiMenor` | 24 | quando o texto é longo — datas, moeda |
| `apoio` | 17 | a segunda linha do herói |
| `valor` | 18 | valor de um par rótulo/valor |

Herói sempre dentro de `FittedBox(fit: BoxFit.scaleDown)`: é texto vindo de
dado, e um nome de mês comprido não pode estourar o card.

---

## 4. App bar

Todas iguais: **reta embaixo** (sem canto arredondado), degradê institucional
translúcido com blur, borda inferior branca a 12%.

```dart
Scaffold(
  appBar: const CustomAppBar(title: 'Nome da tela'),
  body: ...,   // sem backgroundColor, sem Container de fundo
)
```

Se precisar de uma `AppBar` própria (ações, `TabBar`, `SliverAppBar`):

```dart
AppBar(
  backgroundColor: Colors.transparent,
  elevation: 0,
  flexibleSpace: const FundoBarraVidro(),
  title: ...,
)
```

Nunca `shape: RoundedRectangleBorder(...)` na app bar — foi removido de cinco
telas justamente para padronizar.

Uma faixa logo abaixo da barra (seletor de ano, abas) é **continuação dela**:
use o mesmo `FundoBarraVidro` como fundo, não uma superfície com tom próprio.

### Altura com `PreferredSize`

Se você criar a barra com `PreferredSize`, a altura precisa somar o recorte do
topo, senão o conteúdo encosta na borda de baixo:

```dart
preferredSize: Size.fromHeight(
  kToolbarHeight + MediaQuery.of(context).padding.top,
),
```

---

## 5. Hierarquia — o que pode ser chamativo

O app é discreto **para que a ação se destaque**. Essa é a regra que decide:

| Elemento | Tratamento |
|---|---|
| Fundo, cards, cabeçalhos, faixas, selos | Translúcido, discreto |
| Cartão de destaque da tela | Vidro tingido, discreto |
| **Botão da ação principal** | **Cheio — a cor vem do tema, nunca de `colorScheme.primary`** |
| Botão secundário | `OutlinedButton` com a primária |
| Ação destrutiva | Vermelho, e sempre com `dialogoConfirmacao` |

Deixar tudo discreto, inclusive o botão, tira do usuário a única pista do que
fazer na tela.

**Botões cheios não usam a primária como fundo.** A primária é o acento de
texto e ícone e por isso é clara no modo escuro: branco em cima dela fica em
2,65:1. O fundo dos botões é `AppColors.acao`, definido no
`elevatedButtonTheme` e no `filledButtonTheme` — a tela não redefine. Foi o
erro mais repetido aqui: 21 botões fixavam a própria cor e nenhuma
padronização chegava neles.

**Por que não um navy.** Navy sobre o fundo escuro fica em 1,24:1, abaixo dos
3:1 que o contorno de um controle precisa — o botão deixa de se delimitar do
fundo. Nenhuma variação de navy chega lá. `AppColors.acao` é o tom mais escuro
da família que passa: 3,25:1 de contorno e 5,94:1 de branco por cima.

---

## 6. Acessibilidade — não negociável

- **Contraste 4.5:1** em texto normal, 3:1 em ícone que carrega significado.
  Texto branco só sobre superfície escura de verdade.
- **Alvo de toque** ≥ 44pt (iOS) / 48dp (Android). O ícone pode ser 20; o alvo
  não. Use `SizedBox`/`padding` para ampliar a área sem crescer o desenho.
- **Rótulo visível** em campo de formulário. `placeholder` não é rótulo.
- **Erro junto do campo**, não só no topo da tela.
- **Cor não é o único indicador**: provento e desconto têm selo P/D e sinal,
  além do verde e do vermelho.
- Ícone decorativo ao lado de texto visível → esconder da árvore semântica.
  Ícone sozinho que faz algo → precisa de `Semantics(label:)`.

### Tema claro: cor clara não vira texto

Medido em 25/10/2026, quando o selo "Admin" sumia no tema claro:

| Cor como texto ou ícone | Sobre o fundo claro (`#F0F4F8`) | No tema claro use |
|---|---|---|
| Dourado `AppColors.gold` (`#FFB300`) | 1,5:1 | `AppColors.douradoTexto(brilho)` → `#7A4F00` (6:1) |
| Âmbar `kCorAtencao` (`#C77800`) | 2,9:1 | `corAtencao(theme)` → `#8A5A00` (5:1) |
| Cinza `onSurface` a 50% | 3,2:1 | no mínimo **62%** (4,6:1); no escuro, 50% já basta |
| Azul claro `AppColors.lightBlue` em ícone | 2,6:1 | o mesmo tom escurecido no claro, ou `colorScheme.primary` |

- As cores claras (dourado, âmbar, ciano, verde claro) continuam valendo como
  **tinta de fundo** (alfa 0,10–0,14) e em tudo que fica sobre a arte escura
  (cards com arte, telas de entrada), que é escura nos dois temas.
- Texto e ícone com cor de destaque leem a cor pelo tema (`douradoTexto`,
  `corAtencao`, `colorScheme`), nunca uma constante fixa.
- Placeholder (`hintStyle`) pode ficar mais claro, porque o campo sempre tem
  rótulo visível.

---

## 7. Movimento

| Caso | Duração | Curva |
|---|---|---|
| Troca de estado (cor, opacidade) | 180–240ms | `easeOut` |
| Abrir / expandir | 240–320ms | `easeOutCubic` |
| Pílula da navegação | 320ms | `easeOutCubic` |
| Entrada de diálogo | 240ms | `easeOutBack` |

Regra da skill que já nos custou retrabalho: **estado não muda layout**. O
ícone ativo da barra inferior tinha um `AnimatedScale(1.08)` e por isso a linha
de ícones ficava desalinhada. Mude cor, peso e opacidade — não tamanho.

---

## 8. Nada de emoji como ícone

Emoji depende da fonte, muda de desenho por plataforma e não aceita token de
cor. Use `Icons.*`.

*(Pendência conhecida: as dicas da home vêm do Firestore com emoji no texto.)*

---

## 9. Checklist antes de abrir PR de uma tela nova

- [ ] `Scaffold` sem `backgroundColor` e sem `Container` de fundo
- [ ] Superfícies via `CartaoVidro` — nenhum `BoxDecoration` com cor opaca
- [ ] `CustomAppBar` ou `AppBar` + `FundoBarraVidro`, sem `shape` arredondado
- [ ] Ícones só com `AppIconSize`
- [ ] Cores lidas do `Theme.of(context)`; `Colors.white` só sobre fundo escuro
- [ ] Um botão principal cheio; o resto discreto
- [ ] Avisos curtos com `avisoSucesso/Erro/Atencao/Info`, nunca `SnackBar` (§10)
- [ ] Alvos de toque ≥ 44/48
- [ ] Testado nos dois modos (claro e escuro)
- [ ] Testado no Android (lá o `CartaoVidro` vira Material, não vidro)
- [ ] `flutter analyze` sem erro

---

## 10. Onde já foi aplicado

Início, Perfil (ficha individual), Avisos, Configurações, Contracheques,
Contracheque, Declarações, Certidões, Legislações, POPs, Plano de Férias,
Cálculo de Inatividade, Mapa da Força, Recuperar senha, Primeiro acesso,
Confirmar e-mail, Alterar senha, modal de biometria.

Detalhe de comando (`detalhes_mapa_forca_comando_page.dart`) também: era a
última tela feita de superfícies azuis sólidas com texto branco.

Os três cards de dado da Início foram refeitos na gramática do §2b. Os três
fixavam `const primaryBlue = Color(0xFF1565C0)` no próprio arquivo — o azul
não vinha do tema em nenhum deles.

---

## 10b. Avisos curtos — um desenho só

Todo aviso que aparece embaixo e some sozinho usa `lib/widgets/aviso_rapido.dart`
(o desenho do "Em desenvolvimento" do menu): cartão flutuante com fundo levemente
tingido, borda fina, ícone num círculo, título curto e, se precisar, uma linha
de explicação. **Nunca `ScaffoldMessenger.showSnackBar(SnackBar(...))` direto**
— eram 22 avisos, cada tela com cor, raio e ícone próprios.

| Função | Quando | Cor / ícone |
|---|---|---|
| `avisoSucesso` | a ação deu certo | verde / visto |
| `avisoErro` | falhou (fica 4 s) | `colorScheme.error` / alerta |
| `avisoAtencao` | falta algo do usuário | âmbar / triângulo |
| `avisoInfo` | informação neutra | primária / "i" |

Título curto e sem ponto final ("Ciência registrada", não "Ciência registrada
com sucesso!"). Explicação no `texto:`. Erro técnico (`$e`) vai para o
`debugPrint`, nunca para a tela. Cor ou ícone fora dos quatro tipos:
`avisoRapido(context, icone:, cor:)`; sem `BuildContext` (push com o app
aberto): `avisoRapidoGlobal`.

---

## 11. Padrão 2.2: arte, efeitos e imagens de fundo

Decisão do usuário (24/10/2026): da versão 2.2 em diante, **toda tela** segue
este padrão, as novas e as antigas quando forem mexidas. Discreto, mas com a
cara do app: a arte da área aparece em todas as telas, sem virar enfeite.

| Onde | Use | Não use |
|---|---|---|
| Topo da tela de função (o que antes era um parágrafo de introdução) | `TopoArte(arte: Arte.de('<área>'), icone:, titulo:, subtitulo:)` | Texto solto no topo, círculo com ícone |
| Card de resumo (Início, cards do painel) | `CartaoArte` / `FundoArte` com o texto em `temaSobreArte` | Superfície sólida com cor fixa |
| Caixa, lista agrupada, estado vazio | `CartaoVidro(arte: Arte.de('<área>'))` (arte discreta: brilho, trilhas e ícones quase apagados) | `Container` com `BoxDecoration` de cor própria |
| Aviso dentro da tela | `CartaoVidro(tingimento: cor)` ou `avisoRapido` | Caixa com borda colorida feita à mão |
| Campos | O `InputDecoration` do tema (contorno, raio 14 no iOS e 12 no Android) | `filled`, borda ou cor fixas no campo |
| Botões cheios | O tema (`AppColors.acao`) | Cor própria (o verde de "Voltar ao app" saiu por isso) |
| Telas antes do login (login, Face ID, primeiro acesso, recuperar senha) | `TelaEntrada` (fundo de circuito escuro, sempre no tema escuro) com o conteúdo num `CartaoVidro` de raio 24 e a marca `MarcaSouPMRR` | Imagem fixa de fundo (`entradacapa.png`), fundo claro |

**A arte segue a área da função** (as mesmas chaves das áreas de Serviços):
`rh` vida funcional, perfil e conta; `fe` sucesso e férias; `pe` pendências;
`atendimento` ajuda, sugestões e chamados; `institucional` comunicados e
avisos; `normas` legislações e POPs; `gestao` Mapa da Força; `operacional`
escalas e SVI. Uma arte por tela: todas as caixas dela usam a mesma.

**Efeitos.** Movimento só com as durações do §7 e parado com "Reduzir
movimento". Nada pisca nem passa sozinho sem motivo.

**Dado sensível na tela de entrada.** O Face ID mostra a matrícula e o CPF
mascarado (`***.456.789-**`), nunca o número inteiro.

**Conferir antes de entregar:** simulador do iPhone e emulador Android, temas
claro e escuro, e a tela com o teclado aberto, quando tiver campo.
