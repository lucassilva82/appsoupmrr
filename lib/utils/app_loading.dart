import 'package:flutter/material.dart';

const _kBlue = Color(0xFF42A5F5);

/// Spinner fino com cor da marca — substitui o CircularProgressIndicator genérico.
///
/// Uso simples:
///   Center(child: AppLoading())
///   AppLoading(size: 24, strokeWidth: 1.8)
class AppLoading extends StatelessWidget {
  final double size;
  final double strokeWidth;
  final Color color;

  const AppLoading({
    super.key,
    this.size = 32,
    this.strokeWidth = 2.0,
    this.color = _kBlue,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(
        strokeWidth: strokeWidth,
        color: color,
        backgroundColor: color.withOpacity(0.12),
      ),
    );
  }
}

/// Versão centralizada com mensagem opcional — para FutureBuilders e páginas.
///
/// Uso:
///   return const AppLoadingCenter();
///   return const AppLoadingCenter(message: 'Carregando dados...');
class AppLoadingCenter extends StatelessWidget {
  final String? message;

  const AppLoadingCenter({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).brightness == Brightness.dark
        ? Colors.white54
        : Colors.black45;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const AppLoading(size: 36),
          if (message != null) ...[
            const SizedBox(height: 14),
            Text(
              message!,
              style: TextStyle(fontSize: 13, color: textColor, height: 1.4),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}
