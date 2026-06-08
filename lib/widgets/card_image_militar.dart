import 'package:flutter/material.dart';

class CardImageMilitar extends StatelessWidget {
  final String urlImage;
  const CardImageMilitar({Key? key, required this.urlImage}) : super(key: key);

  void _showImageModal(BuildContext context) {
    showGeneralDialog(
      context: context,
      barrierLabel: "Exibir Imagem",
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.7),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        final size = MediaQuery.of(context).size;
        return Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: size.width * 0.7,
              height: size.height * 0.7,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: Colors.black,
              ),
              child: Stack(
                children: [
                  // Imagem com animação
                  FadeTransition(
                    opacity: animation,
                    child: ScaleTransition(
                      scale: animation,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
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
                      icon: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 28,
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
      child: Container(
        width: width * 0.35,
        height: height * 0.28,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.all(Radius.circular(5)),
          boxShadow: [
            BoxShadow(
              color: Colors.grey,
              blurRadius: 4,
              offset: Offset(2, 2), // Sombra
            ),
          ],
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
