import 'package:pdfx/pdfx.dart';
import 'package:flutter/material.dart';

class PdfViewerPage extends StatefulWidget {
  final String pdfPath; // Caminho do arquivo PDF

  PdfViewerPage({required this.pdfPath});

  @override
  State<PdfViewerPage> createState() => _PdfViewerPageState();
}

class _PdfViewerPageState extends State<PdfViewerPage> {
  late PdfController pdfController;
  bool pdfReady = false;
  late int numPaginas;
  var url = "https://www.africau.edu/images/default/sample.pdf";

  @override
  void initState() {
    super.initState();
    loadController();
  }

  loadController() {
    // from asset
    pdfController = PdfController(
      document: PdfDocument.openAsset('${widget.pdfPath}'),
    );

    // from web
    // pdfController =
    //     PdfController(document: PdfDocument.openData(InternetFile.get(url)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Contracheque'),
      ),
      body: Stack(
        children: [
          // PdfView(
          //   controller: pdfController,
          // )
          PdfView(
            controller: pdfController,
            onDocumentLoaded: (document) {
              numPaginas = document.pagesCount;
              pdfReady = true;
              setState(() {});
            },
          ),

          !pdfReady
              ? Center(
                  child: CircularProgressIndicator(),
                )
              : Offstage()
        ],
      ),
    );
  }
}
