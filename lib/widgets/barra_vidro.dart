import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/auth_model.dart';
import '../utils/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// FundoBarraVidro
//
// Fundo translúcido das app bars: degradê institucional com transparência e
// desfoque do conteúdo que passa por baixo, como nas barras do iOS. Vai no
// `flexibleSpace` de qualquer AppBar; a barra em si fica transparente.
//
// É o mesmo acabamento da CustomAppBar e da barra inferior, para o app não
// ter três tratamentos diferentes de superfície.
// ─────────────────────────────────────────────────────────────────────────────

class FundoBarraVidro extends StatelessWidget {
  /// Cantos arredondados embaixo. O padrão é reto, igual à barra da tela
  /// inicial — era isso que deixava as telas internas com outro desenho.
  final bool arredondado;

  const FundoBarraVidro({Key? key, this.arredondado = false}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // O modo GESTOR muda o degradê. Nem toda tela está sob o Provider, então
    // a leitura é tolerante: sem Auth, cai no degradê padrão.
    var isSuperUser = false;
    try {
      isSuperUser = Provider.of<Auth>(context, listen: false).isSuperUser;
    } catch (_) {}

    final cores = AppTheme.appBarGradient(
      isDark: isDark,
      isSuperUser: isSuperUser,
    );

    final raio = arredondado
        ? const BorderRadius.vertical(bottom: Radius.circular(20))
        : BorderRadius.zero;

    return ClipRRect(
      borderRadius: raio,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: cores
                  .map((c) => c.withOpacity(isDark ? 0.82 : 0.90))
                  .toList(),
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border(
              bottom: BorderSide(color: Colors.white.withOpacity(0.12)),
            ),
          ),
        ),
      ),
    );
  }
}
