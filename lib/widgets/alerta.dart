import 'package:flutter/material.dart';

import '../core/design/arte_cartao.dart';
import '../utils/app_theme.dart';
import 'dialogo_confirmacao.dart';

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
  Arte? arte,
}) =>
    _mostrar(context, _Tipo.sucesso, titulo, texto, confirmar, aoConfirmar,
        arte);

Future<void> alertaErro(
  BuildContext context, {
  required String titulo,
  required String texto,
  String confirmar = 'Ok',
  VoidCallback? aoConfirmar,
  Arte? arte,
}) =>
    _mostrar(
        context, _Tipo.erro, titulo, texto, confirmar, aoConfirmar, arte);

Future<void> alertaAviso(
  BuildContext context, {
  required String titulo,
  required String texto,
  String confirmar = 'Ok',
  VoidCallback? aoConfirmar,
  Arte? arte,
}) =>
    _mostrar(
        context, _Tipo.aviso, titulo, texto, confirmar, aoConfirmar, arte);

/// Arte padrão de cada tipo (DESIGN §11): `fe` para o sucesso, `pe` para o
/// erro e `ts` (dourado) para o aviso. A tela pode passar a da área dela.
String _artePadrao(_Tipo tipo) => switch (tipo) {
      _Tipo.sucesso => 'fe',
      _Tipo.erro => 'pe',
      _Tipo.aviso => 'ts',
    };

Future<void> _mostrar(
  BuildContext context,
  _Tipo tipo,
  String titulo,
  String texto,
  String confirmar,
  VoidCallback? aoConfirmar,
  Arte? arte,
) async {
  await showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierLabel: titulo,
    barrierColor: Colors.black.withValues(alpha: 0.62),
    transitionDuration: const Duration(milliseconds: 260),
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
          child: _Cartao(
            tipo: tipo,
            titulo: titulo,
            texto: texto,
            confirmar: confirmar,
            entrada: anim,
            arte: arte ?? Arte.de(_artePadrao(tipo)),
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
  final Arte arte;

  const _Cartao({
    required this.tipo,
    required this.titulo,
    required this.texto,
    required this.confirmar,
    required this.entrada,
    required this.arte,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final estilo = _estilo(isDark);

    return CaixaDialogo(
      arte: arte,
      topo: _Simbolo(cor: estilo.cor, icone: estilo.icone, entrada: entrada),
      titulo: titulo,
      mensagem: texto,
      acoes: [
        // O botão acompanha a cor do tipo; a luminância decide o texto
        // (sobre o verde/vermelho claros do modo escuro, branco ficaria em
        // ~2:1).
        BotaoDialogo.principal(
          rotulo: confirmar,
          cor: estilo.cor,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
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
                color: cor.withValues(alpha: 0.10),
              ),
            ),
          ),
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: cor.withValues(alpha: 0.18),
              border: Border.all(color: cor.withValues(alpha: 0.45), width: 1.5),
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
