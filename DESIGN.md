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
| **Botão da ação principal** | **Cheio, `colorScheme.primary`** |
| Botão secundário | `OutlinedButton` com a primária |
| Ação destrutiva | Vermelho, e sempre com `dialogoConfirmacao` |

Deixar tudo discreto, inclusive o botão, tira do usuário a única pista do que
fazer na tela.

**Texto sobre a primária**: no escuro ela é clara e texto branco fica em ~2:1.
Decida pela luminância:

```dart
foregroundColor: ThemeData.estimateBrightnessForColor(primaria) ==
        Brightness.dark
    ? Colors.white
    : Colors.black87,
```

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

### Uma armadilha que apareceu ali

`withValues(alpha:)` **substitui** o alfa, não multiplica. Em tiles aninhados,
`cor.withValues(alpha: 0.7)` sobre uma cor que já vinha a 0.20 devolveu 0.70 e
o bloco voltou a ficar opaco. E `ExpansionTile` aberto pinta o fundo do tile
inteiro, filhos incluídos — com três níveis aninhados a translucidez se
empilha até virar cor chapada. A saída: fechado é tingido, aberto é
transparente (`shape: const Border()` também tira os divisores que aparecem
quando o fundo some).
