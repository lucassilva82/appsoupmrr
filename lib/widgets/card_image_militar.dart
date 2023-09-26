import 'package:flutter/material.dart';

class CardImageMilitar extends StatelessWidget {
  final String urlImage;
  const CardImageMilitar({Key? key, required this.urlImage}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    double width = MediaQuery.of(context).size.width;
    double height = MediaQuery.of(context).size.height;

    return Container(
      width: width * 0.35,
      height: height * 0.28,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.all(Radius.circular(5)),
        boxShadow: [
          BoxShadow(
            color: Colors.grey,
            blurRadius: 4,
            offset: Offset(2, 2), // Shadow position
          ),
        ],
      ),
      child: urlImage == 'null'
          ? const Image(
              width: 50,
              height: 25,
              image: AssetImage('assets/imagens/avatar2.jpg'))
          : Image.network(urlImage, width: 100, height: 120,
              frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
              return child;
            }, loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) {
                return child;
              }
              // ignore: unnecessary_null_comparison
              if (loadingProgress != null) {
                return Image(
                    width: width * 0.25,
                    height: height * 0.31,
                    image: AssetImage('assets/imagens/avatar2.jpg'));
              } else {
                return const SizedBox(
                    width: 40,
                    height: 30,
                    child: Center(
                        child: CircularProgressIndicator(
                      strokeWidth: 2,
                    )));
              }
            }, errorBuilder:
                  (BuildContext context, Object exception, stackTrace) {
              return Image(
                  width: width * 0.25,
                  height: height * 0.31,
                  image: AssetImage('assets/imagens/avatar2.jpg'));
            }),
    );
  }
}
