import 'package:currency_formatter/currency_formatter.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:money_formatter/money_formatter.dart';
import 'package:pdf/pdf.dart';
import 'package:projetonovo/pages/pdf_view_page.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:typed_data';

import '../models/auth_model.dart';
import '../models/contracheque_model.dart';
import '../models/meses_contracheque_model.dart';
import '../services/dados_sql.dart';
import '../view/second_screen.dart';

import 'dart:io';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';

class PageContracheque extends StatelessWidget {
  MesesContracheque mesSelecionado;
  PageContracheque({Key? key, required this.mesSelecionado}) : super(key: key);
  late ContrachequeModel contracheque;
  late ScrollController _controllerOne = ScrollController();
  late double proventos;
  late double descontos;
  late double totalLiquido;

  @override
  Widget build(BuildContext context) {
    Auth auth = Provider.of(context);
    double width = MediaQuery.of(context).size.width;
    double height = MediaQuery.of(context).size.height;
    double textScaleFactor = MediaQuery.of(context).textScaleFactor;
    DadosSql dadosSql = DadosSql();
    TextStyle estiloCabecalho = TextStyle(
      fontWeight: FontWeight.bold,
      fontSize: 16,
      color: Colors.blue,
    );
    TextStyle estiloCabecalho2 = TextStyle(
      fontWeight: FontWeight.bold,
      fontSize: 13,
      color: Colors.white,
    );
    TextStyle estiloSubtitulo = TextStyle(
      fontSize: 14,
      color: Colors.black54,
    );
    TextStyle contrachequeTexto = TextStyle(
      fontSize: 14,
      color: Colors.black54,
    );

    Future<ContrachequeModel> _buscaDadosSql() async {
      contracheque = await dadosSql.buscaContracheque(mesSelecionado.cpf,
          mesSelecionado.ano, mesSelecionado.mes, mesSelecionado.codProvento);

      proventos = 0.0;
      descontos = 0.0;
      totalLiquido = 0.0;

      contracheque.proventos.forEach((element) {
        if (element.dp == 'P') {
          proventos += double.parse(element.valor);
        } else {
          descontos += double.parse(element.valor);
        }
      });

      totalLiquido = proventos - descontos;

      contracheque.proventos.forEach((element) {
        print(element.valor);
        double valorDouble = double.tryParse(element.valor) ?? 0.0;
        // Formata o valor para o padrão de moeda brasileira
        final formatter = NumberFormat.currency(
            locale: 'pt_BR', symbol: '', decimalDigits: 2);
        String valorFormatado = formatter.format(valorDouble);
        print(valorFormatado);
        element.valor = valorFormatado;
      });

      return contracheque;
    }

    Future<File> generatePdf(
        ContrachequeModel contracheque,
        MesesContracheque mesSelecionado,
        double proventos,
        double descontos,
        double totalLiquido) async {
      final pdf = pw.Document();
      // Carregar a imagem dos assets
      final ByteData bytes = await rootBundle.load('assets/imagens/pmrrr.png');
      final Uint8List byteList = bytes.buffer.asUint8List();

      final ByteData bytesDti =
          await rootBundle.load('assets/imagens/dti.jpeg');
      final Uint8List byteListDti = bytesDti.buffer.asUint8List();

      CurrencyFormatterSettings realSettings = CurrencyFormatterSettings(
        symbol: '',
        symbolSide: SymbolSide.right,
        thousandSeparator: '.',
        decimalSeparator: ',',
        symbolSeparator: ' ',
      );

      pdf.addPage(
        pw.Page(
          margin: pw.EdgeInsets.all(10),
          build: (pw.Context context) {
            return pw.Container(
              color: PdfColor.fromHex('#f5f5f5'),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Container(
                    color: PdfColor.fromHex('#003366'),
                    padding: pw.EdgeInsets.all(10),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Container(
                          height: 100, // ajuste o tamanho conforme necessário
                          width: 100,
                          child: pw.Image(
                            pw.MemoryImage(byteList),
                            fit: pw.BoxFit.cover,
                          ),
                        ),
                        pw.Text(
                          'Contracheque - ${mesSelecionado.mes}/${mesSelecionado.ano}',
                          style: pw.TextStyle(
                            fontSize: 24,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 20),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('LOTAÇÃO',
                              style: pw.TextStyle(
                                  fontSize: 16, color: PdfColors.blue)),
                          pw.Text(mesSelecionado.lotacao,
                              style: pw.TextStyle(
                                  fontSize: 14, color: PdfColors.black)),
                        ],
                      ),
                      pw.Container(
                        width: 92,
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text('MÊS/ANO',
                                style: pw.TextStyle(
                                    fontSize: 16, color: PdfColors.blue)),
                            pw.Text(
                                '${mesSelecionado.mes}/${mesSelecionado.ano}',
                                style: pw.TextStyle(
                                    fontSize: 14, color: PdfColors.black)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 10),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('CARGO / TIPO',
                              style: pw.TextStyle(
                                  fontSize: 16, color: PdfColors.blue)),
                          pw.Text(mesSelecionado.lotacao,
                              style: pw.TextStyle(
                                  fontSize: 14, color: PdfColors.black)),
                        ],
                      ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('MATRÍCULA',
                              style: pw.TextStyle(
                                  fontSize: 16, color: PdfColors.blue)),
                          pw.Text(auth.matricula!,
                              style: pw.TextStyle(
                                  fontSize: 14, color: PdfColors.black)),
                        ],
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 10),
                  pw.Text('NOME',
                      style: pw.TextStyle(fontSize: 16, color: PdfColors.blue)),
                  pw.Text(auth.nomeCompleto!,
                      style:
                          pw.TextStyle(fontSize: 14, color: PdfColors.black)),
                  pw.SizedBox(height: 20),
                  pw.Container(
                    color: PdfColor.fromHex('#003366'),
                    padding: pw.EdgeInsets.all(5),
                    child: pw.Text(
                      'Proventos',
                      style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                      ),
                    ),
                  ),
                  pw.Table.fromTextArray(
                    headerStyle: pw.TextStyle(color: PdfColors.white),
                    headerDecoration:
                        pw.BoxDecoration(color: PdfColor.fromHex('#003366')),
                    cellPadding: pw.EdgeInsets.all(5),
                    data: [
                      ['Tipo', 'Descrição', 'Valor'],
                      ...contracheque.proventos
                          .map((p) => [p.dp, p.descricao, 'R\$ ${p.valor}'])
                          .toList(),
                    ],
                  ),
                  pw.SizedBox(height: 20),
                  pw.Container(
                    color: PdfColor.fromHex('#003366'),
                    padding: pw.EdgeInsets.all(5),
                    child: pw.Text(
                      'Resumo',
                      style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                      ),
                    ),
                  ),
                  pw.SizedBox(height: 10),
                  pw.Text(
                    'Proventos: R\$ ${CurrencyFormatter.format(proventos, realSettings)}',
                    style: pw.TextStyle(
                        color: PdfColors.blue,
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold),
                  ),
                  pw.SizedBox(height: 10),
                  pw.Text(
                    'Descontos: R\$ ${CurrencyFormatter.format(descontos, realSettings)}',
                    style: pw.TextStyle(
                        color: PdfColors.red,
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold),
                  ),
                  pw.SizedBox(height: 10),
                  pw.Text(
                    'Total Líquido: R\$ ${CurrencyFormatter.format(totalLiquido, realSettings)}',
                    style: pw.TextStyle(
                        color: PdfColors.green,
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold),
                  ),
                  pw.SizedBox(height: 100),
                  pw.Container(
                    height: 55, // ajuste o tamanho conforme necessário
                    width: 900,
                    child: pw.Image(
                      pw.MemoryImage(byteListDti),
                      fit: pw.BoxFit.cover,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      );

      final output = await getTemporaryDirectory();
      final file = File("${output.path}/contracheque.pdf");
      await file.writeAsBytes(await pdf.save());
      return file;
    }

    CurrencyFormatterSettings realSettings = CurrencyFormatterSettings(
      symbol: '',
      symbolSide: SymbolSide.right,
      thousandSeparator: '.',
      decimalSeparator: ',',
      symbolSeparator: ' ',
    );

    return FutureBuilder<ContrachequeModel>(
      future: _buscaDadosSql(),
      builder: ((context, snapshot) {
        if (snapshot.hasData) {
          return Scaffold(
            appBar: AppBar(
              flexibleSpace: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.lightBlue,
                      Colors.blue.shade900,
                    ],
                    begin: Alignment.centerLeft,
                    end: Alignment.topRight,
                  ),
                ),
              ),
              title: Text(
                'Contracheque - ${mesSelecionado.mes}/${mesSelecionado.ano}',
                style: TextStyle(color: Colors.white),
              ),
              actions: [
                IconButton(
                  icon: Icon(
                    Icons.picture_as_pdf,
                    color: Colors.red,
                  ),
                  onPressed: () async {
                    final pdfFile = await generatePdf(contracheque,
                        mesSelecionado, proventos, descontos, totalLiquido);
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => PdfViewPage(path: pdfFile.path),
                      ),
                    );
                  },
                ),
              ],
            ),
            body: SafeArea(
              child: Container(
                decoration: BoxDecoration(),
                child: Column(
                  children: [
                    //Cabecalho contracheque
                    Container(
                      // decoration: const BoxDecoration(
                      //     image: DecorationImage(
                      //   opacity: 220,
                      //   // image: AssetImage("assets/imagens/previa.png"),
                      // )),
                      width: width,
                      height: height * 0.25,
                      child: Column(
                        children: [
                          Container(
                            height: height * 0.08,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Padding(
                                      padding:
                                          EdgeInsets.only(left: width * 0.03),
                                      child: Text(
                                        'LOTAÇÃO',
                                        style: estiloCabecalho,
                                      ),
                                    ),
                                    Padding(
                                      padding:
                                          EdgeInsets.only(right: width * 0.10),
                                      child: Text(
                                        'MÊS/ANO',
                                        style: estiloCabecalho,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: height * 0.01),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Padding(
                                      padding:
                                          EdgeInsets.only(left: width * 0.03),
                                      child: Text(
                                        mesSelecionado.lotacao,
                                        style: estiloSubtitulo,
                                      ),
                                    ),
                                    Padding(
                                      padding:
                                          EdgeInsets.only(right: width * 0.10),
                                      child: Text(
                                        '${mesSelecionado.mes}/${mesSelecionado.ano}',
                                        style: estiloSubtitulo,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Container(
                            height: height * 0.08,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Padding(
                                      padding:
                                          EdgeInsets.only(left: width * 0.03),
                                      child: Text(
                                        'CARGO / TIPO',
                                        style: estiloCabecalho,
                                      ),
                                    ),
                                    Padding(
                                      padding:
                                          EdgeInsets.only(right: width * 0.10),
                                      child: Text(
                                        'MATRÍCULA',
                                        style: estiloCabecalho,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: height * 0.01),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Padding(
                                      padding:
                                          EdgeInsets.only(left: width * 0.03),
                                      child: Text(
                                        mesSelecionado.lotacao!,
                                        style: estiloSubtitulo,
                                      ),
                                    ),
                                    Padding(
                                      padding:
                                          EdgeInsets.only(right: width * 0.15),
                                      child: Text(
                                        auth.matricula!,
                                        style: estiloSubtitulo,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Container(
                            height: height * 0.08,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Padding(
                                      padding:
                                          EdgeInsets.only(left: width * 0.03),
                                      child: Text(
                                        'NOME',
                                        style: estiloCabecalho,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: height * 0.01),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Padding(
                                      padding:
                                          EdgeInsets.only(left: width * 0.03),
                                      child: Text(
                                        auth.nomeCompleto!,
                                        style: estiloSubtitulo,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    //dados de provento
                    // Dados de provento
                    Container(
                      width: width,
                      height: height * 0.40,
                      child: Column(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.lightBlue,
                                  Colors.blue.shade900,
                                ],
                                begin: Alignment.centerLeft,
                                end: Alignment.topRight,
                              ),
                            ),
                            width: width,
                            height: height * 0.045,
                            child: Row(
                              children: [
                                Container(
                                  width: width * 0.25,
                                  child: Padding(
                                    padding: const EdgeInsets.only(left: 20.0),
                                    child: Text(
                                      'TIPO',
                                      style: estiloCabecalho2.copyWith(
                                          fontSize: 13 * textScaleFactor),
                                    ),
                                  ),
                                ),
                                Container(
                                  width: width * 0.50,
                                  child: Text(
                                    'DESCRIÇÃO',
                                    style: estiloCabecalho2.copyWith(
                                        fontSize: 13 * textScaleFactor),
                                  ),
                                ),
                                Container(
                                  width: width * 0.20,
                                  child: Text(
                                    'VALOR',
                                    style: estiloCabecalho2.copyWith(
                                        fontSize: 13 * textScaleFactor),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SingleChildScrollView(
                            scrollDirection: Axis.vertical,
                            child: Container(
                              width: double.maxFinite,
                              height: height * 0.35,
                              child: Scrollbar(
                                controller: _controllerOne,
                                child: ListView.builder(
                                  controller: _controllerOne,
                                  itemCount: contracheque.proventos.length,
                                  itemBuilder: (context, index) {
                                    return Container(
                                      padding: const EdgeInsets.only(left: 8.0),
                                      decoration: BoxDecoration(
                                        gradient:
                                            contracheque.proventos[index].dp ==
                                                    'P'
                                                ? LinearGradient(
                                                    colors: [
                                                      Colors.lightBlue.shade100,
                                                      const Color.fromARGB(
                                                          255, 89, 173, 241),
                                                    ],
                                                    begin: Alignment.centerLeft,
                                                    end: Alignment.topRight,
                                                  )
                                                : LinearGradient(
                                                    colors: [
                                                      Color.fromARGB(
                                                          255, 231, 209, 209),
                                                      Color.fromARGB(
                                                          255, 252, 156, 159),
                                                    ],
                                                    begin: Alignment.centerLeft,
                                                    end: Alignment.topRight,
                                                  ),
                                      ),
                                      width: width,
                                      height: height * 0.05,
                                      child: Row(
                                        children: [
                                          Container(
                                            width: width * 0.12,
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.all(8.0),
                                              child: Text(
                                                contracheque
                                                    .proventos[index].dp,
                                                style:
                                                    contrachequeTexto.copyWith(
                                                        fontSize: 14 *
                                                            textScaleFactor),
                                              ),
                                            ),
                                          ),
                                          Container(
                                            width: width * 0.55,
                                            child: Padding(
                                              padding: const EdgeInsets.only(
                                                  right: 5),
                                              child: Text(
                                                contracheque
                                                    .proventos[index].descricao,
                                                style:
                                                    contrachequeTexto.copyWith(
                                                        fontSize: 14 *
                                                            textScaleFactor),
                                              ),
                                            ),
                                          ),
                                          Container(
                                            width: width * 0.30,
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 1),
                                              child: Text(
                                                // 'R\$ ${CurrencyFormatter.format(contracheque.proventos[index].valor, realSettings)}',
                                                'R\$ ${contracheque.proventos[index].valor}',
                                                style:
                                                    contrachequeTexto.copyWith(
                                                        fontSize: 14 *
                                                            textScaleFactor),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
// Soma dos valores
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.yellow,
                      ),
                      width: width,
                      height: height * 0.04,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.lightBlue,
                              Colors.blue.shade900,
                            ],
                            begin: Alignment.centerLeft,
                            end: Alignment.topRight,
                          ),
                        ),
                        width: width,
                        height: height * 0.04,
                        child: Row(
                          children: [
                            Container(
                              width: width * 0.35,
                              child: Padding(
                                padding: const EdgeInsets.only(left: 20.0),
                                child: Text(
                                  'PROVENTOS',
                                  style: estiloCabecalho2.copyWith(
                                      fontSize: 13 * textScaleFactor),
                                ),
                              ),
                            ),
                            Container(
                              width: width * 0.30,
                              child: Text(
                                'DESCONTOS',
                                style: estiloCabecalho2.copyWith(
                                    fontSize: 13 * textScaleFactor),
                              ),
                            ),
                            Container(
                              width: width * 0.30,
                              child: Text(
                                'TOTAL LíQUIDO',
                                style: estiloCabecalho2.copyWith(
                                    fontSize: 13 * textScaleFactor),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: height * 0.01),
                    Row(
                      children: [
                        Container(
                          width: width * 0.35,
                          child: Padding(
                            padding: const EdgeInsets.only(left: 20.0),
                            child: Text(
                              'R\$ ${CurrencyFormatter.format(proventos, realSettings)}',
                              style: TextStyle(
                                color: Colors.blue,
                                fontSize: 14 * textScaleFactor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        Container(
                          width: width * 0.30,
                          child: Text(
                            'R\$ ${CurrencyFormatter.format(descontos, realSettings)}',
                            style: TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                              fontSize: 14 * textScaleFactor,
                            ),
                          ),
                        ),
                        Container(
                          width: width * 0.33,
                          child: Text(
                            'R\$ ${CurrencyFormatter.format(totalLiquido, realSettings)}',
                            style: TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                              fontSize: 14 * textScaleFactor,
                            ),
                          ),
                        ),
                      ],
                    ),

                    //ate aqui
                    SizedBox(height: height * 0.01),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(6.0),
                          child: Container(
                            width: width * 0.95,
                            height: height * 0.05,
                            child: Text(
                              '* Dados somente para visualização, nao valido para fins de comprovação, acesse o site do servidor para imprimir seu contracheque oficial',
                              style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        } else if (snapshot.hasError) {
          print(snapshot.error);
          return SecondScreen();
        }
        return const Center(
          child: CircularProgressIndicator(),
        );
      }),
    );
  }
}
