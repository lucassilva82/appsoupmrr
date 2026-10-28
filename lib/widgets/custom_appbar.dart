import 'dart:io';

import 'package:flutter/material.dart';
import 'package:projetonovo/core/navegacao/titulos_rota.dart';
import 'package:projetonovo/utils/app_theme.dart';
import 'package:projetonovo/widgets/barra_vidro.dart';

/// Barra das telas internas (protótipo `.cab-int`).
///
/// iOS: vidro com fio embaixo, "‹ Serviços" à esquerda (o nome da tela de
/// onde se veio) e o título centralizado em 17. Android: a barra pequena do
/// Material 3, seta de voltar e título de 22 à esquerda.
class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;

  /// Botões à direita (ex.: "Minhas mensagens").
  final List<Widget> actions;

  /// Para a tela abaixo dela, no lugar do título (ex.: título longo).
  final String? rotuloVoltar;

  /// Conteúdo abaixo da barra (abas, filtros), na mesma superfície.
  final PreferredSizeWidget? bottom;

  const CustomAppBar({
    super.key,
    required this.title,
    this.actions = const [],
    this.rotuloVoltar,
    this.bottom,
  });

  @override
  Widget build(BuildContext context) {
    TitulosRota.registrar(context, rotuloVoltar ?? title);
    final theme = Theme.of(context);
    final ios = Platform.isIOS;
    final podeVoltar = Navigator.of(context).canPop();
    final anterior = TitulosRota.anterior(context);
    final pri = theme.colorScheme.primary;

    // Como no iOS: o nome da tela anterior, ou "Voltar" quando ele não cabe
    // ao lado da seta (112 de largura: 6 + 28 da seta + 6 de cada lado).
    String rotulo = anterior ?? 'Voltar';
    if (anterior != null) {
      final medida = TextPainter(
        text: TextSpan(text: anterior, style: const TextStyle(fontSize: 17)),
        textDirection: TextDirection.ltr,
        textScaler: MediaQuery.textScalerOf(context),
        maxLines: 1,
      )..layout();
      if (medida.width > 112 - 6 - 28 - 6) rotulo = 'Voltar';
    }

    Widget? voltar;
    if (podeVoltar && ios) {
      voltar = Semantics(
        button: true,
        label: 'Voltar${anterior == null ? '' : ' para $anterior'}',
        excludeSemantics: true,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => Navigator.of(context).maybePop(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.chevron_left_rounded, size: 28, color: pri),
              Flexible(
                child: Text(
                  rotulo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 17, color: pri),
                ),
              ),
            ]),
          ),
        ),
      );
    }

    return AppBar(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: ios,
      automaticallyImplyLeading: !ios,
      leadingWidth: ios && podeVoltar ? 112 : null,
      leading: voltar,
      iconTheme: IconThemeData(color: theme.colorScheme.onSurface),
      flexibleSpace: ios ? const FundoBarraVidro() : null,
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: ios ? 17 : 22,
          fontWeight: ios ? FontWeight.w600 : FontWeight.w400,
          color: theme.colorScheme.onSurface,
        ),
      ),
      actions: [...actions, const SizedBox(width: 4)],
      bottom: bottom,
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(kToolbarHeight + (bottom?.preferredSize.height ?? 0));
}

/// Usado por telas que montam a própria AppBar: mesmas medidas da barra comum.
TextStyle estiloTituloBarra(BuildContext context) => TextStyle(
      fontSize: Platform.isIOS ? 17 : 22,
      fontWeight: Platform.isIOS ? FontWeight.w600 : FontWeight.w400,
      color: Theme.of(context).colorScheme.onSurface,
    );

/// Ícones das barras (cor do texto, tamanho do DESIGN.md).
const double tamanhoIconeBarra = AppIconSize.md;
