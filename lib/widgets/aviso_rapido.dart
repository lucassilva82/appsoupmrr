import 'package:flutter/material.dart';

import '../core/design/fundo_circuito.dart';
import 'package:flutter/services.dart';

import '../utils/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// avisoRapido
//
// O aviso curto do app: aparece embaixo, some sozinho e tem sempre o mesmo
// desenho (o do "Em desenvolvimento" do menu): cartão flutuante com fundo
// levemente tingido, borda fina, ícone num círculo, título e, se precisar,
// uma linha de explicação. Use sempre ele, nunca o SnackBar padrão do Flutter,
// para todos os avisos terem a mesma cara (DESIGN §10).
//
// Os quatro tipos já trazem cor e ícone:
//   avisoSucesso(context, 'Certidão removida do aparelho');
//   avisoErro(context, 'Não foi possível abrir o PDF', texto: 'Tente de novo.');
//   avisoAtencao(context, 'Preencha o número e o CEP');
//   avisoInfo(context, 'Dados restaurados do sistema');
// Cor ou ícone diferentes: avisoRapido(context, ..., icone:, cor:).
// Sem BuildContext (callback de push): avisoRapidoGlobal(...).
// ─────────────────────────────────────────────────────────────────────────────

enum TipoAviso { sucesso, erro, atencao, info }

/// Âmbar do "Em desenvolvimento" e dos avisos de atenção.
const Color kCorAtencao = Color(0xFFC77800);

/// Cor de cada tipo, lida do tema para servir aos modos claro e escuro.
Color corDoAviso(ThemeData theme, TipoAviso tipo) {
  final isDark = theme.brightness == Brightness.dark;
  switch (tipo) {
    case TipoAviso.sucesso:
      return isDark ? AppColors.sucessoEscuro : AppColors.sucesso;
    case TipoAviso.erro:
      return theme.colorScheme.error;
    case TipoAviso.atencao:
      return kCorAtencao;
    case TipoAviso.info:
      return theme.colorScheme.primary;
  }
}

IconData _iconeDoAviso(TipoAviso tipo) {
  switch (tipo) {
    case TipoAviso.sucesso:
      return Icons.check_rounded;
    case TipoAviso.erro:
      return Icons.error_outline_rounded;
    case TipoAviso.atencao:
      return Icons.warning_amber_rounded;
    case TipoAviso.info:
      return Icons.info_outline_rounded;
  }
}

void avisoSucesso(BuildContext context, String titulo, {String? texto}) =>
    _porTipo(context, TipoAviso.sucesso, titulo, texto);

void avisoErro(BuildContext context, String titulo, {String? texto}) =>
    _porTipo(context, TipoAviso.erro, titulo, texto);

void avisoAtencao(BuildContext context, String titulo, {String? texto}) =>
    _porTipo(context, TipoAviso.atencao, titulo, texto);

void avisoInfo(BuildContext context, String titulo, {String? texto}) =>
    _porTipo(context, TipoAviso.info, titulo, texto);

void _porTipo(
    BuildContext context, TipoAviso tipo, String titulo, String? texto) {
  // Háptico (§15.2): leve no sucesso, médio no erro e na atenção.
  switch (tipo) {
    case TipoAviso.sucesso:
      HapticFeedback.lightImpact();
    case TipoAviso.erro || TipoAviso.atencao:
      HapticFeedback.mediumImpact();
    case TipoAviso.info:
      break;
  }
  avisoRapido(
    context,
    titulo: titulo,
    texto: texto,
    icone: _iconeDoAviso(tipo),
    cor: corDoAviso(FundoCircuito.ativo ? FundoCircuito.temaEscuro : Theme.of(context), tipo),
    // Erro fica um pouco mais na tela: costuma ter algo para ler.
    duracao: Duration(seconds: tipo == TipoAviso.erro ? 4 : 3),
  );
}

void avisoRapido(
  BuildContext context, {
  required String titulo,
  String? texto,
  required IconData icone,
  required Color cor,
  Duration duracao = const Duration(seconds: 3),
}) {
  _mostrar(
    ScaffoldMessenger.of(context),
    // Sobre as telas de entrada, o aviso segue o fundo escuro delas.
    FundoCircuito.ativo ? FundoCircuito.temaEscuro : Theme.of(context),
    titulo: titulo,
    texto: texto,
    icone: icone,
    cor: cor,
    duracao: duracao,
  );
}

/// Para quando não há BuildContext à mão (ex.: push com o app aberto): usa o
/// ScaffoldMessenger e o tema do app.
void avisoRapidoGlobal(
  ScaffoldMessengerState messenger,
  ThemeData theme, {
  required String titulo,
  String? texto,
  required TipoAviso tipo,
  IconData? icone,
  Color? cor,
}) {
  _mostrar(
    messenger,
    theme,
    titulo: titulo,
    texto: texto,
    icone: icone ?? _iconeDoAviso(tipo),
    cor: cor ?? corDoAviso(theme, tipo),
    duracao: const Duration(seconds: 3),
  );
}

void _mostrar(
  ScaffoldMessengerState messenger,
  ThemeData theme, {
  required String titulo,
  String? texto,
  required IconData icone,
  required Color cor,
  required Duration duracao,
}) {
  final isDark = theme.brightness == Brightness.dark;
  final textoCor = theme.colorScheme.onSurface;

  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        elevation: 2,
        duration: duracao,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        backgroundColor: isDark
            ? Color.alphaBlend(cor.withValues(alpha: 0.10), AppColors.darkCard)
            : Color.alphaBlend(cor.withValues(alpha: 0.08), Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: cor.withValues(alpha: 0.25)),
        ),
        content: Semantics(
          liveRegion: true,
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: cor.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(icone, color: cor, size: AppIconSize.sm),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                        color: textoCor,
                      ),
                    ),
                    if (texto != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        texto,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.25,
                          color: textoCor.withValues(alpha: 0.72),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
}
