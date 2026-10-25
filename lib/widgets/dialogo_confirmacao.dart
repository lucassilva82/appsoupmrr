import 'dart:ui';

import 'package:flutter/material.dart';

import '../core/design/fundo_circuito.dart';

import '../core/design/arte_cartao.dart';
import '../utils/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// dialogoConfirmacao e a caixa de diálogo do padrão 2.2 (DESIGN §11)
//
// Caixa de confirmação no padrão visual do SouPMRR, no lugar do AlertDialog
// padrão do Flutter: vidro, a arte discreta da área por baixo (brilho,
// trilhas e ícones quase apagados), ícone em destaque, botões lado a lado e
// entrada animada (parada com "Reduzir movimento").
//
// `CaixaDialogo` e `mostrarDialogoArte` são o mesmo desenho para quem precisa
// de um diálogo com conteúdo próprio (campo de senha, aviso com um botão,
// "Enviando…"): nenhuma tela monta AlertDialog cru.
//
// dialogoConfirmacao retorna true quando o usuário confirma.
// ─────────────────────────────────────────────────────────────────────────────

Future<bool> dialogoConfirmacao(
  BuildContext context, {
  required String titulo,
  required String mensagem,
  required String textoConfirmar,
  String textoCancelar = 'Cancelar',
  IconData icone = Icons.help_outline_rounded,
  Color cor = AppColors.blue,

  /// Arte discreta da área da tela que pergunta. Sem ela, a de `rh`.
  Arte? arte,
}) async {
  final resultado = await mostrarDialogoArte<bool>(
    context,
    arte: arte,
    icone: icone,
    cor: cor,
    titulo: titulo,
    mensagem: mensagem,
    acoes: (ctx) => [
      BotaoDialogo.secundario(
          rotulo: textoCancelar, onPressed: () => Navigator.of(ctx).pop(false)),
      BotaoDialogo.principal(
          rotulo: textoConfirmar,
          cor: cor,
          onPressed: () => Navigator.of(ctx).pop(true)),
    ],
  );
  return resultado ?? false;
}

/// Abre a caixa de diálogo do padrão 2.2. [corpo] vem abaixo da mensagem
/// (campo, lista); [acoes] são os botões (um ocupa a largura toda; dois ou
/// mais ficam lado a lado). Use [BotaoDialogo] para eles.
/// Sobre as telas de entrada (fundo de circuito escuro), o diálogo usa o
/// tema escuro, mesmo com o aparelho no claro.
Widget _naEntrada(Widget filho) => ValueListenableBuilder<int>(
      valueListenable: FundoCircuito.abertos,
      child: filho,
      builder: (_, n, f) => n > 0 ? Theme(data: FundoCircuito.temaEscuro, child: f!) : f!,
    );

Future<T?> mostrarDialogoArte<T>(
  BuildContext context, {
  Arte? arte,
  IconData? icone,
  Color? cor,
  String? titulo,
  String? mensagem,
  Widget Function(BuildContext ctx)? corpo,
  List<Widget> Function(BuildContext ctx)? acoes,
  bool fecharAoTocarFora = true,
  bool podeVoltar = true,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: fecharAoTocarFora,
    barrierLabel: titulo ?? 'Fechar',
    barrierColor: Colors.black.withValues(alpha: 0.55),
    transitionDuration: const Duration(milliseconds: 240),
    pageBuilder: (_, __, ___) => const SizedBox.shrink(),
    transitionBuilder: (ctx, anim, _, __) {
      final reduzir = MediaQuery.of(ctx).disableAnimations;
      final curva = CurvedAnimation(
          parent: anim, curve: reduzir ? Curves.linear : Curves.easeOutBack);
      return PopScope(
        canPop: podeVoltar,
        child: FadeTransition(
          opacity: anim,
          child: ScaleTransition(
            scale: Tween<double>(begin: reduzir ? 1.0 : 0.88, end: 1.0)
                .animate(curva),
            child: _naEntrada(CaixaDialogo(
              arte: arte,
              icone: icone,
              cor: cor,
              titulo: titulo,
              mensagem: mensagem,
              corpo: corpo == null ? null : Builder(builder: corpo),
              acoes: acoes == null ? const [] : acoes(ctx),
            )),
          ),
        ),
      );
    },
  );
}

/// "Enviando…", "Excluindo…": a caixa com o indicador, sem botão, que só
/// fecha pelo código (`Navigator.of(context).pop()`).
void mostrarCarregandoDialogo(BuildContext context, String texto,
    {Arte? arte}) {
  mostrarDialogoArte<void>(
    context,
    arte: arte,
    fecharAoTocarFora: false,
    podeVoltar: false,
    corpo: (ctx) => Semantics(
      liveRegion: true,
      label: texto,
      excludeSemantics: true,
      child: Row(children: [
        const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2.5)),
        const SizedBox(width: 16),
        Expanded(
            child: Text(texto, style: Theme.of(ctx).textTheme.bodyMedium)),
      ]),
    ),
  );
}

/// Botão das caixas de diálogo: principal cheio (cor do tema, ou a cor da
/// ação, como o vermelho de excluir) e secundário de contorno.
class BotaoDialogo extends StatelessWidget {
  const BotaoDialogo.principal(
      {super.key, required this.rotulo, required this.onPressed, this.cor})
      : principal = true;
  const BotaoDialogo.secundario(
      {super.key, required this.rotulo, required this.onPressed})
      : principal = false,
        cor = null;

  final String rotulo;
  final VoidCallback? onPressed;
  final Color? cor;
  final bool principal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final texto = FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(rotulo,
          maxLines: 1,
          style: TextStyle(
              fontWeight: principal ? FontWeight.bold : FontWeight.w600)),
    );
    final Widget botao;
    if (principal) {
      final c = cor;
      botao = ElevatedButton(
        onPressed: onPressed,
        // Cor própria (vermelho de excluir): o mesmo acabamento do tema.
        style: (c == null ? const ButtonStyle() : estiloBotaoCor(c))
            .copyWith(padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 12))),
        child: texto,
      );
    } else {
      botao = OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          side: BorderSide(
              color: isDark ? AppColors.darkBorder : const Color(0xFFD7E0EC)),
          foregroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.75),
          padding: const EdgeInsets.symmetric(horizontal: 12),
        ),
        child: texto,
      );
    }
    return SizedBox(height: 52, child: botao);
  }
}

/// O desenho da caixa: vidro com desfoque próprio (o diálogo flutua sobre o
/// véu, não há conteúdo atrás para desfocar), a arte discreta da área por
/// baixo, ícone num círculo, título, mensagem, corpo e botões.
class CaixaDialogo extends StatelessWidget {
  const CaixaDialogo({
    super.key,
    this.arte,
    this.icone,
    this.cor,
    this.topo,
    this.titulo,
    this.mensagem,
    this.corpo,
    this.rodape,
    this.acoes = const [],
    this.larguraMaxima = 360,
  });

  final Arte? arte;
  final IconData? icone;
  final Color? cor;

  /// No lugar do ícone (o símbolo animado dos alertas).
  final Widget? topo;
  final String? titulo;
  final String? mensagem;
  final Widget? corpo;

  /// Entre o corpo e os botões (o código do erro, por exemplo).
  final Widget? rodape;
  final List<Widget> acoes;
  final double larguraMaxima;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final corIcone = cor ?? theme.colorScheme.primary;
    final temCabeca = topo != null || icone != null || titulo != null;

    final conteudo = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (topo != null)
          Center(child: topo!)
        else if (icone != null)
          Center(
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: corIcone.withValues(alpha: 0.12),
                border: Border.all(color: corIcone.withValues(alpha: 0.22)),
              ),
              child: Icon(icone, size: AppIconSize.xl, color: corIcone),
            ),
          ),
        if ((topo != null || icone != null) && titulo != null)
          const SizedBox(height: 16),
        if (titulo != null)
          Semantics(
            header: true,
            child: Text(
              titulo!,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
        if (mensagem != null) ...[
          if (temCabeca) const SizedBox(height: 8),
          Text(
            mensagem!,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              height: 1.4,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
            ),
          ),
        ],
        if (corpo != null) ...[
          if (temCabeca || mensagem != null) const SizedBox(height: 16),
          corpo!,
        ],
        if (rodape != null) ...[const SizedBox(height: 12), rodape!],
        if (acoes.isNotEmpty) ...[
          const SizedBox(height: 24),
          if (acoes.length == 1)
            acoes.first
          else
            Row(children: [
              for (var i = 0; i < acoes.length; i++) ...[
                if (i > 0) const SizedBox(width: 12),
                Expanded(child: acoes[i]),
              ],
            ]),
        ],
      ],
    );

    return Center(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
            24, 32, 24, 32 + MediaQuery.of(context).viewInsets.bottom),
        child: Material(
          color: Colors.transparent,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
              child: Container(
                constraints: BoxConstraints(maxWidth: larguraMaxima),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: isDark
                        ? [
                            Color.alphaBlend(
                                Colors.white.withValues(alpha: 0.10),
                                AppColors.darkCard),
                            Color.alphaBlend(
                                Colors.white.withValues(alpha: 0.04),
                                AppColors.darkCard),
                          ]
                        : [
                            Colors.white.withValues(alpha: 0.96),
                            Colors.white.withValues(alpha: 0.90),
                          ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.16)
                        : Colors.white.withValues(alpha: 0.80),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color:
                          Colors.black.withValues(alpha: isDark ? 0.55 : 0.18),
                      blurRadius: 32,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Stack(children: [
                  ArteDiscreta(arte: arte ?? Arte.de('rh'), raio: 20),
                  // Rola com fonte grande do sistema em vez de estourar a tela.
                  SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
                    child: conteudo,
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
