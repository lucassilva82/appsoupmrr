import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:share_plus/share_plus.dart';

class PdfViewPage extends StatelessWidget {
  final String path;

  PdfViewPage({required this.path});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Visualização do Contracheque'),
        actions: [
          IconButton(
            icon: Icon(Icons.share),
            onPressed: () {
              Share.shareXFiles([XFile(path)],
                  text: 'Confira meu contracheque!');
            },
          ),
        ],
      ),
      body: PDFView(
        filePath: path,
      ),
    );
  }
}
