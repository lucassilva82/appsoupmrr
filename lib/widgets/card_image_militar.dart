import 'package:flutter/material.dart';

import '../utils/app_theme.dart';

class CardImageMilitar extends StatelessWidget {
  final String urlImage;
  const CardImageMilitar({Key? key, required this.urlImage}) : super(key: key);

  void _showImageModal(BuildContext context) {
    showGeneralDialog(
      context: context,
      barrierLabel: "Exibir Imagem",
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      transitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (context, animation, secondaryAnimation) {
        final size = MediaQuery.of(context).size;
        return Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: size.width * 0.7,
              height: size.height * 0.7,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
              ),
              child: Stack(
                children: [
                  // Imagem com animação
                  FadeTransition(
                    opacity: animation,
                    child: ScaleTransition(
                      scale: animation,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: InteractiveViewer(
                          child: urlImage == 'null'
                              ? Image.asset('assets/imagens/avatar2.jpg',
                                  fit: BoxFit.contain)
                              : Image.network(urlImage, fit: BoxFit.contain),
                        ),
                      ),
                    ),
                  ),
                  // Botão de fechar
                  Positioned(
                    top: 10,
                    right: 10,
                    child: IconButton(
                      tooltip: 'Fechar',
                      // Botão sobre a foto: fundo escuro translúcido para o
                      // X branco ter contraste em qualquer imagem; alvo 44.
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black.withValues(alpha: 0.45),
                        minimumSize: const Size(44, 44),
                      ),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                        size: AppIconSize.md,
                      ),
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                    ),
                  )
                ],
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: animation,
            child: child,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    double width = MediaQuery.of(context).size.width;
    double height = MediaQuery.of(context).size.height;

    return GestureDetector(
      onTap: () {
        _showImageModal(context);
      },
      // Moldura fina no tom do tema, no lugar da caixa branca com sombra
      // cinza fixa (padrão 2.2: nada de superfície opaca).
      child: Container(
        width: width * 0.35,
        height: height * 0.28,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Theme.of(context)
                .colorScheme
                .onSurface
                .withValues(alpha: 0.14),
          ),
        ),
        child: urlImage == 'null'
            ? const Image(
                width: 50,
                height: 25,
                image: AssetImage('assets/imagens/avatar2.jpg'),
              )
            : Image.network(urlImage, width: 100, height: 120,
                frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                return child;
              }, loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) {
                  return child;
                }
                return Image(
                    width: width * 0.25,
                    height: height * 0.31,
                    image: const AssetImage('assets/imagens/avatar2.jpg'));
              }, errorBuilder:
                    (BuildContext context, Object exception, stackTrace) {
                return Image(
                    width: width * 0.25,
                    height: height * 0.31,
                    image: const AssetImage('assets/imagens/avatar2.jpg'));
              }),
      ),
    );
  }
}
