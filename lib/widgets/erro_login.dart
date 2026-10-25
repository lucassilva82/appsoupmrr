import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/design/arte_cartao.dart';
import '../utils/app_theme.dart';
import '../utils/auth_exception.dart';
import 'aviso_rapido.dart';
import 'dialogo_confirmacao.dart';
import 'vidro.dart';

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
    barrierColor: Colors.black.withValues(alpha: 0.55),
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
    final cor = corDoAviso(
      theme,
      erro.gravidade == GravidadeErroLogin.erro
          ? TipoAviso.erro
          : TipoAviso.atencao,
    );
    final acao = erro.acao;
    // Senha e matrícula: o "outro" botão é corrigir o que foi digitado.
    final rotuloSecundario = (acao == AcaoErroLogin.recuperarSenha ||
            acao == AcaoErroLogin.primeiroAcesso)
        ? 'Tentar de novo'
        : 'Fechar';

    return Semantics(
      liveRegion: true,
      child: CaixaDialogo(
        // Conta e acesso: a arte de `rh` (DESIGN §11).
        arte: Arte.de('rh'),
        icone: erro.icone,
        cor: cor,
        titulo: erro.titulo,
        mensagem: erro.explicacao,
        larguraMaxima: 380,
        corpo: _OQueFazer(texto: erro.oQueFazer, cor: cor),
        rodape: SelectableText(
          'Código ${erro.codigo}',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
            letterSpacing: 0.3,
          ),
        ),
        acoes: [
          if (acao != AcaoErroLogin.fechar)
            BotaoDialogo.secundario(
              rotulo: rotuloSecundario,
              onPressed: () => Navigator.of(context).pop(),
            ),
          BotaoDialogo.principal(
            rotulo: _rotuloAcao(acao),
            cor: AppColors.acao,
            onPressed: () => Navigator.of(context)
                .pop(acao == AcaoErroLogin.fechar ? null : acao),
          ),
        ],
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
    return CartaoVidro(
      raio: 14,
      tingimento: cor,
      padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: cor.withValues(alpha: 0.14),
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
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.78),
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
