import 'dart:ui';

import 'package:flutter/material.dart';

import '../utils/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Alertas de sucesso, erro e aviso
//
// Mesma anatomia do QuickAlert — símbolo animado no topo, título, texto e um
// botão — mas na paleta do app. A biblioteca desenha o cabeçalho com um GIF
// que já traz o fundo vermelho/verde embutido, então `headerBackgroundColor`
// não tinha efeito: abria um bloco saturado no meio de um app escuro.
//
// Aqui o símbolo é desenhado, entra com escala e traço, e a cor vem dos
// tokens semânticos por modo (ver AppColors.sucesso / falha).
// ─────────────────────────────────────────────────────────────────────────────

enum _Tipo { sucesso, erro, aviso }

Future<void> alertaSucesso(
  BuildContext context, {
  required String titulo,
  required String texto,
  String confirmar = 'Ok',
  VoidCallback? aoConfirmar,
}) =>
    _mostrar(context, _Tipo.sucesso, titulo, texto, confirmar, aoConfirmar);

Future<void> alertaErro(
  BuildContext context, {
  required String titulo,
  required String texto,
  String confirmar = 'Ok',
  VoidCallback? aoConfirmar,
}) =>
    _mostrar(context, _Tipo.erro, titulo, texto, confirmar, aoConfirmar);

Future<void> alertaAviso(
  BuildContext context, {
  required String titulo,
  required String texto,
  String confirmar = 'Ok',
  VoidCallback? aoConfirmar,
}) =>
    _mostrar(context, _Tipo.aviso, titulo, texto, confirmar, aoConfirmar);

Future<void> _mostrar(
  BuildContext context,
  _Tipo tipo,
  String titulo,
  String texto,
  String confirmar,
  VoidCallback? aoConfirmar,
) async {
  await showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierLabel: titulo,
    barrierColor: Colors.black.withOpacity(0.62),
    transitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (_, __, ___) => const SizedBox.shrink(),
    transitionBuilder: (context, anim, _, __) {
      final curva = CurvedAnimation(parent: anim, curve: Curves.easeOutBack);
      return FadeTransition(
        opacity: anim,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.88, end: 1.0).animate(curva),
          child: _Cartao(
            tipo: tipo,
            titulo: titulo,
            texto: texto,
            confirmar: confirmar,
            entrada: anim,
          ),
        ),
      );
    },
  );
  aoConfirmar?.call();
}

class _Cartao extends StatelessWidget {
  final _Tipo tipo;
  final String titulo;
  final String texto;
  final String confirmar;
  final Animation<double> entrada;

  const _Cartao({
    required this.tipo,
    required this.titulo,
    required this.texto,
    required this.confirmar,
    required this.entrada,
  });

  ({Color cor, IconData icone}) _estilo(bool isDark) {
    switch (tipo) {
      case _Tipo.sucesso:
        return (
          cor: isDark ? AppColors.sucessoEscuro : AppColors.sucesso,
          icone: Icons.check_rounded,
        );
      case _Tipo.erro:
        return (
          cor: isDark ? AppColors.falhaEscuro : AppColors.falha,
          icone: Icons.close_rounded,
        );
      case _Tipo.aviso:
        return (cor: AppColors.gold, icone: Icons.priority_high_rounded);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final estilo = _estilo(isDark);
    // O botão acompanha a luminância da cor: sobre o verde/vermelho claros do
    // modo escuro, texto branco ficaria em ~2:1.
    final sobreCor =
        ThemeData.estimateBrightnessForColor(estilo.cor) == Brightness.dark
            ? Colors.white
            : Colors.black87;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Material(
          color: Colors.transparent,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 360),
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: isDark
                        ? [
                            Color.alphaBlend(Colors.white.withOpacity(0.10),
                                AppColors.darkCard),
                            Color.alphaBlend(Colors.white.withOpacity(0.04),
                                AppColors.darkCard),
                          ]
                        : [
                            Colors.white.withOpacity(0.96),
                            Colors.white.withOpacity(0.90),
                          ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withOpacity(0.16)
                        : Colors.white.withOpacity(0.80),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.55 : 0.18),
                      blurRadius: 32,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _Simbolo(
                      cor: estilo.cor,
                      icone: estilo.icone,
                      entrada: entrada,
                    ),
                    const SizedBox(height: 18),
                    Text(
                      titulo,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      texto,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        height: 1.4,
                        color: theme.colorScheme.onSurface.withOpacity(0.72),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: estilo.cor,
                          foregroundColor: sobreCor,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          confirmar,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Símbolo do topo: anel que pulsa e ícone que entra com escala.
class _Simbolo extends StatelessWidget {
  final Color cor;
  final IconData icone;
  final Animation<double> entrada;

  const _Simbolo({
    required this.cor,
    required this.icone,
    required this.entrada,
  });

  @override
  Widget build(BuildContext context) {
    final escala = CurvedAnimation(parent: entrada, curve: Curves.elasticOut);

    return SizedBox(
      width: 96,
      height: 96,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Halo externo, que abre junto com o diálogo.
          ScaleTransition(
            scale: Tween<double>(begin: 0.6, end: 1.0).animate(
              CurvedAnimation(parent: entrada, curve: Curves.easeOutCubic),
            ),
            child: Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: cor.withOpacity(0.10),
              ),
            ),
          ),
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: cor.withOpacity(0.18),
              border: Border.all(color: cor.withOpacity(0.45), width: 1.5),
            ),
          ),
          ScaleTransition(
            scale: Tween<double>(begin: 0.3, end: 1.0).animate(escala),
            child: Icon(icone, size: 40, color: cor),
          ),
        ],
      ),
    );
  }
}
