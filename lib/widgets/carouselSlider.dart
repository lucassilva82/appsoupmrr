import 'dart:convert';
import 'dart:typed_data';

import 'package:carousel_slider/carousel_slider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class WidgetCarouselSlider extends StatefulWidget {
  int currentIndex = 0;
  WidgetCarouselSlider({Key? key}) : super(key: key);

  @override
  _WidgetCarouselSliderState createState() => _WidgetCarouselSliderState();
}

class _WidgetCarouselSliderState extends State<WidgetCarouselSlider> {
  late Stream<List<Map<String, dynamic>>> slides;

  @override
  void initState() {
    super.initState();
    _queryDb();
  }

  // Consulta o Firestore e converte os documentos em uma lista de Map<String, dynamic>
  void _queryDb() {
    slides = FirebaseFirestore.instance.collection('stores').snapshots().map(
        (snapshot) => snapshot.docs
            .map((doc) => doc.data() as Map<String, dynamic>)
            .toList());
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      width: screenWidth * 0.95,
      height: screenHeight * 0.40,
      child: StreamBuilder<List<Map<String, dynamic>>>(
        stream: slides,
        builder: (context, AsyncSnapshot<List<Map<String, dynamic>>> snap) {
          if (snap.hasError) {
            return Center(child: Text('Erro: ${snap.error.toString()}'));
          }
          if (snap.connectionState == ConnectionState.waiting) {
            return const LinearProgressIndicator();
          }
          List<Map<String, dynamic>> slideList = snap.data!;
          if (slideList.isEmpty) {
            return const Center(child: Text("Nenhum slide encontrado"));
          }
          return _carouselSlider(slideList);
        },
      ),
    );
  }

  Widget _carouselSlider(List<Map<String, dynamic>> slideList) {
    final List<Widget> imageSliders = slideList.map((item) {
      final imageUrl = item['img'] ?? '';
      final title = item['title'] ?? '';
      final subtitle = item['subtitle'] ?? '';

      if (imageUrl.isEmpty ||
          (!imageUrl.startsWith("http://") &&
              !imageUrl.startsWith("https://"))) {
        return Container(
          margin: const EdgeInsets.all(8.0),
          decoration: BoxDecoration(
            color: Colors.grey.shade300,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Center(
            child: Text(
              "URL inválida",
              style: TextStyle(color: Colors.red),
            ),
          ),
        );
      }

      return InkWell(
        onTap: () {
          // Trate o clique no slide se necessário.
        },
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 2.0, vertical: 2.0),
          child: ClipRRect(
            borderRadius: const BorderRadius.all(Radius.circular(8.0)),
            child: Stack(
              children: <Widget>[
                // Widget que carrega a imagem do cache (ou baixa e armazena)
                CachedImageFromPrefs(imageUrl: imageUrl),
                // Gradiente opcional para sobrepor na parte inferior (caso deseje inserir um título)
                Positioned(
                  bottom: 0.0,
                  left: 0.0,
                  right: 0.0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        vertical: 10.0, horizontal: 20.0),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Color.fromARGB(180, 0, 0, 0),
                          Color.fromARGB(0, 0, 0, 0)
                        ],
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18.0,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14.0,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }).toList();

    return Column(
      children: [
        CarouselSlider(
          items: imageSliders,
          options: CarouselOptions(
            height: MediaQuery.of(context).size.height * 0.31,
            autoPlay: true,
            enlargeCenterPage: true,
            aspectRatio: 2.0,
            viewportFraction: 0.95,
            onPageChanged: (index, reason) {
              widget.currentIndex = index;
              setState(() {});
            },
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            imageSliders.length,
            (index) => Container(
              width: 6,
              height: 6,
              margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.currentIndex == index
                    ? Colors.blue
                    : Colors.grey.shade300,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Widget stateful que utiliza SharedPreferences para armazenar a imagem em cache (em base64)
/// e exibi-la. A imagem é exibida com BoxFit.cover para preencher todo o widget, com
/// alignment: Alignment.topCenter para que a parte superior (por exemplo, um rosto) fique visível.
class CachedImageFromPrefs extends StatefulWidget {
  final String imageUrl;
  const CachedImageFromPrefs({Key? key, required this.imageUrl})
      : super(key: key);

  @override
  _CachedImageFromPrefsState createState() => _CachedImageFromPrefsState();
}

class _CachedImageFromPrefsState extends State<CachedImageFromPrefs> {
  Widget? _cachedImageWidget;

  @override
  void initState() {
    super.initState();
    _loadImage().then((widget) {
      setState(() {
        _cachedImageWidget = widget;
      });
    });
  }

  Future<Widget> _loadImage() async {
    final prefs = await SharedPreferences.getInstance();
    final String key = "cached_image_${widget.imageUrl.hashCode}";
    if (prefs.containsKey(key)) {
      String base64Str = prefs.getString(key)!;
      Uint8List bytes = base64Decode(base64Str);
      return Image.memory(
        bytes,
        fit: BoxFit.cover, // Preenche todo o widget
        alignment: Alignment.topCenter, // Alinha a parte superior
        width: double.infinity,
        height: double.infinity,
      );
    } else {
      try {
        final response = await http.get(Uri.parse(widget.imageUrl));
        if (response.statusCode == 200) {
          Uint8List bytes = response.bodyBytes;
          String base64Str = base64Encode(bytes);
          await prefs.setString(key, base64Str);
          return Image.memory(
            bytes,
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
            width: double.infinity,
            height: double.infinity,
          );
        } else {
          return const Icon(Icons.error, color: Colors.red);
        }
      } catch (e) {
        print("Erro ao baixar imagem: $e");
        return const Icon(Icons.error, color: Colors.red);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return _cachedImageWidget ??
        Container(
          color: Colors.grey.shade200,
          child: const Center(
            child: CircularProgressIndicator.adaptive(strokeWidth: 2),
          ),
        );
  }
}
