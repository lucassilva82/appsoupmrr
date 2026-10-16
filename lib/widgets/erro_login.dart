import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../utils/app_theme.dart';
import '../utils/auth_exception.dart';
import 'aviso_rapido.dart';

// ─────────────────────────────────────────────────────────────────────────────
// mostrarErroLogin
//
// Cartão de erro do login, no mesmo desenho do dialogoConfirmacao (vidro,
// ícone num círculo, botões lado a lado). Um aviso rápido (DESIGN §10) some
// em 4 s e cabe uma linha; aqui o militar precisa ler o que houve, o que
// fazer e, se ligar para o suporte, o código.
//
// Cores: as do aviso de erro e de atenção (corDoAviso), para o login falar a
// mesma língua dos avisos do resto do app.
//
// Devolve a ação escolhida no botão principal, ou null se só fechou.
// ─────────────────────────────────────────────────────────────────────────────

Future<AcaoErroLogin?> mostrarErroLogin(
  BuildContext context,
  AuthException erro,
) {
  HapticFeedback.mediumImpact();
  return showGeneralDialog<AcaoErroLogin>(
    context: context,
    barrierDismissible: true,
    barrierLabel: erro.titulo,
    barrierColor: Colors.black.withOpacity(0.55),
    transitionDuration: const Duration(milliseconds: 240),
    pageBuilder: (_, __, ___) => const SizedBox.shrink(),
    transitionBuilder: (context, anim, _, __) {
      final reduzir = MediaQuery.of(context).disableAnimations;
      final curva = CurvedAnimation(
          parent: anim, curve: reduzir ? Curves.linear : Curves.easeOutBack);
      return FadeTransition(
        opacity: anim,
        child: ScaleTransition(
          scale: Tween<double>(begin: reduzir ? 1.0 : 0.88, end: 1.0)
              .animate(curva),
          child: _CartaoErro(erro: erro),
        ),
      );
    },
  );
}

String _rotuloAcao(AcaoErroLogin acao) {
  switch (acao) {
    case AcaoErroLogin.tentarDeNovo:
      return 'Tentar de novo';
    case AcaoErroLogin.recuperarSenha:
      return 'Recuperar senha';
    case AcaoErroLogin.primeiroAcesso:
      return 'Primeiro acesso';
    case AcaoErroLogin.fechar:
      return 'Entendi';
  }
}

class _CartaoErro extends StatelessWidget {
  final AuthException erro;
  const _CartaoErro({required this.erro});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cor = corDoAviso(
      theme,
      erro.gravidade == GravidadeErroLogin.erro
          ? TipoAviso.erro
          : TipoAviso.atencao,
    );
    final suave = theme.colorScheme.onSurface.withOpacity(0.70);
    final acao = erro.acao;
    // Senha e matrícula: o "outro" botão é corrigir o que foi digitado.
    final rotuloSecundario = (acao == AcaoErroLogin.recuperarSenha ||
            acao == AcaoErroLogin.primeiroAcesso)
        ? 'Tentar de novo'
        : 'Fechar';

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Material(
          color: Colors.transparent,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 380),
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
                // Rola com fonte grande do sistema em vez de estourar a tela.
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
                  child: Semantics(
                    liveRegion: true,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: cor.withOpacity(0.12),
                          ),
                          child: Icon(erro.icone, size: 32, color: cor),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          erro.titulo,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          erro.explicacao,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(height: 1.4, color: suave),
                        ),
                        const SizedBox(height: 16),
                        _OQueFazer(texto: erro.oQueFazer, cor: cor),
                        const SizedBox(height: 12),
                        SelectableText(
                          'Código ${erro.codigo}',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface
                                .withOpacity(0.55),
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 20),
                        if (acao == AcaoErroLogin.fechar)
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: _BotaoPrincipal(
                              rotulo: _rotuloAcao(acao),
                              cor: AppColors.acao,
                              onPressed: () => Navigator.of(context).pop(),
                            ),
                          )
                        else
                          Row(
                            children: [
                              Expanded(
                                child: SizedBox(
                                  height: 52,
                                  child: OutlinedButton(
                                    onPressed: () =>
                                        Navigator.of(context).pop(),
                                    style: OutlinedButton.styleFrom(
                                      side: BorderSide(
                                        color: isDark
                                            ? AppColors.darkBorder
                                            : const Color(0xFFD7E0EC),
                                      ),
                                      foregroundColor: theme
                                          .colorScheme.onSurface
                                          .withOpacity(0.75),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12),
                                    ),
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        rotuloSecundario,
                                        maxLines: 1,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: SizedBox(
                                  height: 52,
                                  child: _BotaoPrincipal(
                                    rotulo: _rotuloAcao(acao),
                                    cor: AppColors.acao,
                                    onPressed: () =>
                                        Navigator.of(context).pop(acao),
                                  ),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Caixa "O que fazer": fundo levemente tingido na cor do erro, como os
/// avisos rápidos (DESIGN §10).
class _OQueFazer extends StatelessWidget {
  final String texto;
  final Color cor;
  const _OQueFazer({required this.texto, required this.cor});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
      decoration: BoxDecoration(
        color: cor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cor.withOpacity(0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: cor.withOpacity(0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.lightbulb_outline_rounded,
                color: cor, size: AppIconSize.sm),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'O que fazer',
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  texto,
                  style: theme.textTheme.bodySmall?.copyWith(
                    height: 1.35,
                    color: theme.colorScheme.onSurface.withOpacity(0.78),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BotaoPrincipal extends StatelessWidget {
  final String rotulo;
  final Color cor;
  final VoidCallback onPressed;
  const _BotaoPrincipal(
      {required this.rotulo, required this.cor, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: cor,
        foregroundColor:
            ThemeData.estimateBrightnessForColor(cor) == Brightness.dark
                ? Colors.white
                : Colors.black87,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 12),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(rotulo,
            maxLines: 1, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }
}
