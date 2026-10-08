// ignore_for_file: must_be_immutable
import 'dart:io';
import 'dart:typed_data';

import 'package:auto_size_text/auto_size_text.dart';
import 'package:currency_formatter/currency_formatter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:quickalert/quickalert.dart';
import 'package:share_plus/share_plus.dart';

import '../models/auth_model.dart';
import '../models/contracheque_model.dart';
import '../models/meses_contracheque_model.dart';
import '../services/dados_sql.dart';
import '../utils/app_theme.dart';
import '../view/second_screen.dart';
import '../widgets/vidro.dart';
import '../widgets/barra_vidro.dart';

class PageContracheque extends StatefulWidget {
  final MesesContracheque mesSelecionado;
  const PageContracheque({Key? key, required this.mesSelecionado})
      : super(key: key);

  @override
  State<PageContracheque> createState() => _PageContrachequeState();
}

class _PageContrachequeState extends State<PageContracheque> {
  final DadosSql dadosSql = DadosSql();
  late ContrachequeModel contracheque;
  late double proventos;
  late double descontos;
  late double totalLiquido;
  bool _sharingPdf = false;
  bool _sharingImage = false;

  final CurrencyFormatterSettings _realSettings = CurrencyFormatterSettings(
    symbol: '',
    symbolSide: SymbolSide.right,
    thousandSeparator: '.',
    decimalSeparator: ',',
    symbolSeparator: ' ',
  );

  Future<ContrachequeModel> _buscaDadosSql() async {
    final auth = Provider.of<Auth>(context, listen: false);
    contracheque = await dadosSql.buscaContracheque(
      widget.mesSelecionado.cpf,
      widget.mesSelecionado.ano,
      widget.mesSelecionado.mes,
      widget.mesSelecionado.mesExtenso,
      widget.mesSelecionado.matricula,
      widget.mesSelecionado.tipo,
      widget.mesSelecionado.codProvento,
      widget.mesSelecionado.relacaoTrabalho,
      widget.mesSelecionado.folha,
    );

    proventos = 0.0;
    descontos = 0.0;
    totalLiquido = 0.0;

    for (final e in contracheque.proventos) {
      if (e.tipoRubrica == 'P') {
        proventos += double.parse(e.provento);
      } else {
        descontos += double.parse(e.desconto);
      }
    }
    totalLiquido = proventos - descontos;

    final formatter =
        NumberFormat.currency(locale: 'pt_BR', symbol: '', decimalDigits: 2);
    for (final e in contracheque.proventos) {
      if (e.tipoRubrica == 'P') {
        final val = double.tryParse(e.provento) ?? 0.0;
        e.provento = formatter.format(val);
      } else {
        final val = double.tryParse(e.desconto) ?? 0.0;
        e.desconto = formatter.format(val);
      }
    }

    return contracheque;
  }

  // ── Gera o arquivo PDF v2.1 ───────────────────────────────────────────
  Future<File> _generatePdf(Auth auth) async {
    final pdf = pw.Document();

    final ByteData logoData = await rootBundle.load('assets/imagens/pmrrr.png');
    final Uint8List logoBytes = logoData.buffer.asUint8List();
    final ByteData dtiData = await rootBundle.load('assets/imagens/dti.jpeg');
    final Uint8List dtiBytes = dtiData.buffer.asUint8List();

    // ── Paleta sóbria e profissional ──────────────────────────────────
    final cHeader = PdfColor.fromHex('#1A3050'); // header navy (menos saturado)
    final cSlate =
        PdfColor.fromHex('#2C3A4A'); // cabeçalho da tabela (charcoal)
    final cGold = PdfColor.fromHex('#C9920A'); // dourado mais quente/sóbrio
    final cGreenDk = PdfColor.fromHex('#15803D'); // P no fundo claro
    final cRedDk = PdfColor.fromHex('#B91C1C'); // D no fundo claro
    final cGreenLt = PdfColor.fromHex('#4ADE80'); // P no fundo escuro
    final cRedLt = PdfColor.fromHex('#F87171'); // D no fundo escuro
    final cBg = PdfColor.fromHex('#F4F7FA'); // fundo geral
    final cCard = PdfColors.white; // card bg
    final cAlt = PdfColor.fromHex('#F0F4F8'); // linha alternada
    final cLabel = PdfColor.fromHex('#64748B'); // rótulo
    final cValue = PdfColor.fromHex('#1E293B'); // valor principal
    final cText = PdfColor.fromHex('#334155'); // texto das rubricas
    final cBorder = PdfColor.fromHex('#E2E8F0'); // bordas internas
    final cSep = PdfColor.fromHex('#3D5A7A'); // separador do resumo
    final cSubtle = PdfColor.fromHex('#94A3B8'); // texto sutil/footer
    final cBlueSub = PdfColor.fromHex('#93C5FD'); // subtítulo do header

    final mesAno =
        '${widget.mesSelecionado.mesExtenso.toUpperCase()} / ${widget.mesSelecionado.ano}';

    // ── Compactação dinâmica ─────────────────────────────────────────
    // Ajusta fontes/espaçamentos conforme a quantidade de rubricas para
    // garantir que TUDO (rubricas + resumo) caiba em UMA única página A4.
    final int _nRubricas = contracheque.proventos.length;
    final bool _t1 = _nRubricas > 14; // compacto
    final bool _t2 = _nRubricas > 22; // ultra
    final bool _t3 = _nRubricas > 30; // micro
    final bool _t4 = _nRubricas > 40; // nano

    final double rowVPad = _t4
        ? 0.8
        : _t3
            ? 1.0
            : _t2
                ? 1.5
                : _t1
                    ? 3.0
                    : 5.0;
    final double rowFont = _t4
        ? 5.5
        : _t3
            ? 6.0
            : _t2
                ? 7.0
                : _t1
                    ? 8.5
                    : 9.5;
    final double badgeSize = _t4
        ? 8
        : _t3
            ? 10
            : _t2
                ? 12
                : _t1
                    ? 15
                    : 18;
    final double badgeFont = _t4
        ? 5.0
        : _t3
            ? 5.5
            : _t2
                ? 6.5
                : _t1
                    ? 7.5
                    : 9.0;
    final double headRowVPad = _t1 ? 4 : 7;
    final double gapAntesResumo = _t1 ? 6 : 12;
    final double summaryVPad = _t3
        ? 9
        : _t2
            ? 11
            : 15;
    final double summaryValueFont = _t2
        ? 11
        : _t1
            ? 12
            : 13;
    final double summaryDivH = _t1 ? 28 : 36;

    // ── Helper: célula de informação ─────────────────────────────────
    pw.Widget infoCell(String label, String value) => pw.Padding(
          padding: const pw.EdgeInsets.fromLTRB(12, 9, 12, 9),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(label,
                  style: pw.TextStyle(
                      fontSize: 7.5,
                      color: cLabel,
                      fontWeight: pw.FontWeight.bold,
                      letterSpacing: 0.6)),
              pw.SizedBox(height: 3),
              pw.Text(value,
                  style: pw.TextStyle(
                      fontSize: 11,
                      color: cValue,
                      fontWeight: pw.FontWeight.bold)),
            ],
          ),
        );

    // ── Helper: coluna de resumo ──────────────────────────────────────
    pw.Widget summaryCol(String label, String value, PdfColor color) =>
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Text(label,
                  style: pw.TextStyle(
                      fontSize: 8, color: cSubtle, letterSpacing: 0.7)),
              pw.SizedBox(height: 5),
              pw.Text(value,
                  style: pw.TextStyle(
                      fontSize: summaryValueFont,
                      color: color,
                      fontWeight: pw.FontWeight.bold)),
            ],
          ),
        );

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.zero,

      // ── Cabeçalho (repetido em cada página) ──────────────────────────
      header: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          // Barra do topo
          pw.Container(
            color: cHeader,
            padding: const pw.EdgeInsets.fromLTRB(30, 14, 30, 14),
            child: pw.Row(children: [
              pw.SizedBox(
                width: 50,
                height: 50,
                child:
                    pw.Image(pw.MemoryImage(logoBytes), fit: pw.BoxFit.contain),
              ),
              pw.SizedBox(width: 20),
              pw.Expanded(
                child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('CONTRACHEQUE',
                          style: pw.TextStyle(
                              fontSize: 20,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.white,
                              letterSpacing: 2.5)),
                      pw.SizedBox(height: 4),
                      pw.Text(mesAno,
                          style: pw.TextStyle(
                              fontSize: 11,
                              color: cBlueSub,
                              letterSpacing: 0.5)),
                    ]),
              ),
              pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('POLÍCIA MILITAR DE RORAIMA',
                        style: pw.TextStyle(
                            fontSize: 8,
                            color: cGold,
                            fontWeight: pw.FontWeight.bold,
                            letterSpacing: 0.8)),
                    pw.SizedBox(height: 3),
                    pw.Text('Governo do Estado de Roraima',
                        style: pw.TextStyle(fontSize: 7, color: cSubtle)),
                  ]),
            ]),
          ),
          pw.Container(height: 3, color: cGold),

          // Dados do militar — só na primeira página
          if (ctx.pageNumber == 1) ...[
            pw.Container(
              color: cBg,
              padding: const pw.EdgeInsets.fromLTRB(30, 12, 30, 0),
              child: pw.Column(children: [
                // Card com grade interna
                pw.Container(
                  decoration: pw.BoxDecoration(
                    color: cCard,
                    border: pw.Border.all(color: cBorder, width: 0.6),
                    borderRadius:
                        const pw.BorderRadius.all(pw.Radius.circular(4)),
                  ),
                  child: pw.Column(children: [
                    // Linha 1: Nome (largura total)
                    pw.Container(
                      width: double.infinity,
                      decoration: pw.BoxDecoration(
                        border: pw.Border(
                            bottom: pw.BorderSide(color: cBorder, width: 0.6)),
                      ),
                      child: pw.Padding(
                        padding: const pw.EdgeInsets.fromLTRB(12, 10, 12, 10),
                        child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text('NOME COMPLETO',
                                  style: pw.TextStyle(
                                      fontSize: 7.5,
                                      color: cLabel,
                                      fontWeight: pw.FontWeight.bold,
                                      letterSpacing: 0.6)),
                              pw.SizedBox(height: 3),
                              pw.Text(auth.nomeCompleto ?? '-',
                                  style: pw.TextStyle(
                                      fontSize: 13,
                                      color: cValue,
                                      fontWeight: pw.FontWeight.bold)),
                            ]),
                      ),
                    ),
                    // Linha 2: Matrícula | Mês/Ano | Folha
                    pw.Table(
                      border: pw.TableBorder(
                        horizontalInside:
                            pw.BorderSide(color: cBorder, width: 0.6),
                        verticalInside:
                            pw.BorderSide(color: cBorder, width: 0.6),
                      ),
                      children: [
                        pw.TableRow(children: [
                          infoCell(
                              'MATRÍCULA', widget.mesSelecionado.matricula),
                          infoCell('MÊS / ANO',
                              '${widget.mesSelecionado.mes} / ${widget.mesSelecionado.ano}'),
                          infoCell(
                              'FOLHA',
                              contracheque.Folha.isNotEmpty
                                  ? contracheque.Folha
                                  : widget.mesSelecionado.folha),
                        ]),
                        pw.TableRow(children: [
                          infoCell(
                              'UN. ORGANIZACIONAL',
                              contracheque.UnidadeOrganizacional.isNotEmpty
                                  ? contracheque.UnidadeOrganizacional
                                  : '-'),
                          infoCell('RELAÇÃO DE TRABALHO',
                              widget.mesSelecionado.relacaoTrabalho),
                          pw.Container(),
                        ]),
                      ],
                    ),
                  ]),
                ),
                pw.SizedBox(height: 10),
              ]),
            ),
            // (cabeçalho de colunas movido para dentro do pw.Table)
          ],
        ],
      ),

      // ── Rodapé ──────────────────────────────────────────────────────
      footer: (ctx) => pw.Container(
        color: cBg,
        padding: const pw.EdgeInsets.fromLTRB(30, 7, 30, 7),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
                '* Dados apenas para visualização. Não válido como documento oficial.',
                style: pw.TextStyle(
                    fontSize: 7.5,
                    color: cSubtle,
                    fontStyle: pw.FontStyle.italic)),
            pw.SizedBox(
                height: 28,
                width: 72,
                child:
                    pw.Image(pw.MemoryImage(dtiBytes), fit: pw.BoxFit.contain)),
          ],
        ),
      ),

      // ── Conteúdo: rubricas + barra de resumo ─────────────────────────
      build: (ctx) => [
        // Tabela de rubricas usando pw.Table (alinhamento profissional)
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 30),
          child: pw.Table(
            border: pw.TableBorder.all(color: cBorder, width: 0.5),
            columnWidths: const {
              0: pw.FixedColumnWidth(48), // badge P/D
              1: pw.FlexColumnWidth(), // descrição
              2: pw.FixedColumnWidth(110), // valor
            },
            children: [
              // ── Linha de cabeçalho das colunas ────────────────────
              pw.TableRow(
                decoration: pw.BoxDecoration(color: cSlate),
                children: [
                  pw.Padding(
                    padding: pw.EdgeInsets.symmetric(
                        horizontal: 10, vertical: headRowVPad),
                    child: pw.Text('TIPO',
                        textAlign: pw.TextAlign.center,
                        style: pw.TextStyle(
                            fontSize: 8,
                            color: PdfColors.white,
                            fontWeight: pw.FontWeight.bold,
                            letterSpacing: 0.6)),
                  ),
                  pw.Padding(
                    padding:
                        pw.EdgeInsets.fromLTRB(8, headRowVPad, 8, headRowVPad),
                    child: pw.Text('DESCRIÇÃO DA RUBRICA',
                        style: pw.TextStyle(
                            fontSize: 8.5,
                            color: PdfColors.white,
                            fontWeight: pw.FontWeight.bold,
                            letterSpacing: 0.8)),
                  ),
                  pw.Padding(
                    padding:
                        pw.EdgeInsets.fromLTRB(8, headRowVPad, 8, headRowVPad),
                    child: pw.Text('VALOR',
                        textAlign: pw.TextAlign.right,
                        style: pw.TextStyle(
                            fontSize: 8.5,
                            color: PdfColors.white,
                            fontWeight: pw.FontWeight.bold,
                            letterSpacing: 0.8)),
                  ),
                ],
              ),
              // ── Linhas de dados ───────────────────────────────────
              ...contracheque.proventos.asMap().entries.map((entry) {
                final item = entry.value;
                final idx = entry.key;
                final isP = item.tipoRubrica == 'P';
                final valor = isP ? item.provento : item.desconto;
                final badgeBg = isP ? cGreenDk : cRedDk;
                final valColor = isP ? cGreenDk : cRedDk;

                return pw.TableRow(
                  decoration:
                      pw.BoxDecoration(color: idx.isEven ? cCard : cAlt),
                  children: [
                    // Coluna badge
                    pw.Padding(
                      padding: pw.EdgeInsets.symmetric(
                          horizontal: 10, vertical: rowVPad),
                      child: pw.Center(
                        child: pw.Container(
                          width: badgeSize,
                          height: badgeSize,
                          decoration: pw.BoxDecoration(
                            color: badgeBg,
                            borderRadius: pw.BorderRadius.all(
                                pw.Radius.circular(badgeSize / 2)),
                          ),
                          child: pw.Center(
                            child: pw.Text(item.tipoRubrica,
                                style: pw.TextStyle(
                                    color: PdfColors.white,
                                    fontSize: badgeFont,
                                    fontWeight: pw.FontWeight.bold)),
                          ),
                        ),
                      ),
                    ),
                    // Coluna descrição
                    pw.Padding(
                      padding: pw.EdgeInsets.symmetric(
                          horizontal: 8, vertical: rowVPad),
                      child: pw.Text(item.descricaoRubrica,
                          style: pw.TextStyle(fontSize: rowFont, color: cText)),
                    ),
                    // Coluna valor
                    pw.Padding(
                      padding: pw.EdgeInsets.symmetric(
                          horizontal: 8, vertical: rowVPad),
                      child: pw.Text('R\$\u2009$valor',
                          textAlign: pw.TextAlign.right,
                          style: pw.TextStyle(
                              fontSize: rowFont,
                              color: valColor,
                              fontWeight: pw.FontWeight.bold)),
                    ),
                  ],
                );
              }).toList(),
            ],
          ),
        ),

        pw.SizedBox(height: gapAntesResumo),

        // Barra de resumo
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 30),
          child: pw.Container(
            decoration: pw.BoxDecoration(
              color: cHeader,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
            ),
            padding:
                pw.EdgeInsets.symmetric(horizontal: 24, vertical: summaryVPad),
            child: pw.Row(children: [
              summaryCol(
                'PROVENTOS',
                'R\$\u2009${CurrencyFormatter.format(proventos, _realSettings)}',
                cGreenLt,
              ),
              pw.Container(width: 1, height: summaryDivH, color: cSep),
              summaryCol(
                'DESCONTOS',
                'R\$\u2009${CurrencyFormatter.format(descontos, _realSettings)}',
                cRedLt,
              ),
              pw.Container(width: 1, height: summaryDivH, color: cSep),
              summaryCol(
                'LÍQUIDO A RECEBER',
                'R\$\u2009${CurrencyFormatter.format(totalLiquido, _realSettings)}',
                PdfColors.white,
              ),
            ]),
          ),
        ),

        pw.SizedBox(height: gapAntesResumo),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 30),
          child: pw.Container(height: 2, color: cGold),
        ),
      ],
    ));

    final output = await getTemporaryDirectory();
    final file = File('${output.path}/contracheque.pdf');
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  // Origem do popover exigida pelo iOS/iPad (UIActivityViewController).
  // No Android o parâmetro é ignorado, então é seguro sempre enviar.
  Rect? _sharePositionOrigin() {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  // ── Compartilhar PDF ──────────────────────────────────────────────────
  Future<void> _sharePdf(Auth auth) async {
    if (_sharingPdf || _sharingImage) return;
    setState(() => _sharingPdf = true);
    try {
      final file = await _generatePdf(auth);
      await Share.shareXFiles(
        [XFile(file.path)],
        subject:
            'Contracheque ${widget.mesSelecionado.mesExtenso}/${widget.mesSelecionado.ano}',
        sharePositionOrigin: _sharePositionOrigin(),
      );
    } catch (e) {
      debugPrint('Erro ao compartilhar PDF: $e');
      if (!mounted) return;
      QuickAlert.show(
        context: context,
        type: QuickAlertType.error,
        title: 'Erro',
        text: 'Não foi possível gerar o PDF.\n$e',
        confirmBtnText: 'OK',
      );
    } finally {
      if (mounted) setState(() => _sharingPdf = false);
    }
  }

  // ── Compartilhar Imagem (rasteriza o PDF) ─────────────────────────────
  Future<void> _shareImage(Auth auth) async {
    if (_sharingImage || _sharingPdf) return;
    setState(() => _sharingImage = true);
    try {
      final file = await _generatePdf(auth);
      final pdfBytes = await file.readAsBytes();
      final pages =
          await Printing.raster(pdfBytes, pages: [0], dpi: 180).toList();
      if (pages.isEmpty) throw Exception('Sem páginas');
      final pngBytes = await pages.first.toPng();
      final tempDir = await getTemporaryDirectory();
      final imgFile = File('${tempDir.path}/contracheque.png');
      await imgFile.writeAsBytes(pngBytes);
      await Share.shareXFiles(
        [XFile(imgFile.path)],
        subject:
            'Contracheque ${widget.mesSelecionado.mesExtenso}/${widget.mesSelecionado.ano}',
        sharePositionOrigin: _sharePositionOrigin(),
      );
    } catch (e) {
      debugPrint('Erro ao compartilhar imagem: $e');
      if (!mounted) return;
      QuickAlert.show(
        context: context,
        type: QuickAlertType.error,
        title: 'Erro',
        text: 'Não foi possível gerar a imagem.\n$e',
        confirmBtnText: 'OK',
      );
    } finally {
      if (mounted) setState(() => _sharingImage = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<Auth>(context, listen: false);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return FutureBuilder<ContrachequeModel>(
      future: _buscaDadosSql(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body:
                Center(child: CircularProgressIndicator(color: AppColors.blue)),
          );
        }
        if (snapshot.hasError) return SecondScreen();
        if (!snapshot.hasData) return SecondScreen();

        return Scaffold(
          backgroundColor: Colors.transparent,
          // fundo global (FundoSuave) aparece por baixo
          // ── AppBar — mesma cor que CustomAppBar ──────────────────
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            centerTitle: true,
            iconTheme: const IconThemeData(color: Colors.white),
            flexibleSpace: const FundoBarraVidro(),
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
            ),
            title: Column(
              children: [
                const Text(
                  'Contracheque',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2),
                ),
                Text(
                  '${widget.mesSelecionado.mesExtenso} / ${widget.mesSelecionado.ano}',
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ],
            ),
          ),

          // ── Botões de compartilhar fixos no rodapé ──────────────────
          bottomNavigationBar: _buildShareBar(auth, isDark),

          body: Column(
            children: [
              // ── Card de informações do cabeçalho ──────────────────
              _buildHeaderCard(auth, isDark),

              // ── Tabela de rubricas ─────────────────────────────────
              _buildTableHeader(isDark),

              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                  itemCount: contracheque.proventos.length,
                  itemBuilder: (ctx, index) {
                    return _buildItemRow(
                        contracheque.proventos[index], isDark, index);
                  },
                ),
              ),

              // ── Resumo (proventos / descontos / líquido) ───────────
              _buildSummaryBar(isDark),
            ],
          ),
        );
      },
    );
  }

  // ── Header card com dados do militar ─────────────────────────────────
  Widget _buildHeaderCard(Auth auth, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: CartaoVidro(
        raio: 16,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
        children: [
          _headerRow(
            icon: Icons.person_outline_rounded,
            label: 'Nome',
            value: auth.nomeCompleto ?? '-',
            isDark: isDark,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _headerRow(
                  icon: Icons.badge_outlined,
                  label: 'Matrícula',
                  value: auth.matricula ?? '-',
                  isDark: isDark,
                ),
              ),
              Expanded(
                child: _headerRow(
                  icon: Icons.calendar_month_outlined,
                  label: 'Mês/Ano',
                  value:
                      '${widget.mesSelecionado.mes}/${widget.mesSelecionado.ano}',
                  isDark: isDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _headerRow(
            icon: Icons.location_city_outlined,
            label: 'Lotação',
            value: widget.mesSelecionado.relacaoTrabalho,
            isDark: isDark,
          ),
        ],
        ),
      ),
    );
  }

  Widget _headerRow({
    required IconData icon,
    required String label,
    required String value,
    required bool isDark,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: AppColors.blue),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: isDark ? Colors.white38 : Colors.black38,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Cabeçalho da tabela ───────────────────────────────────────────────
  Widget _buildTableHeader(bool isDark) {
    // Faixa de vidro tingida de azul no lugar da barra sólida: o rótulo das
    // colunas não precisa competir com os valores. O texto usa a cor primária
    // do tema (contraste alto nos dois modos), não branco sobre azul.
    return Builder(builder: (context) {
      final theme = Theme.of(context);
      final estilo = TextStyle(
        color: theme.colorScheme.primary,
        fontSize: 10,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.6,
      );

      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
        child: CartaoVidro(
          raio: 12,
          tingimento: theme.colorScheme.primary,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              // 30 + 8 acompanha o selo P/D das linhas, para o rótulo da
              // coluna cair exatamente sobre o conteúdo dela.
              SizedBox(width: 30, child: Text('TIPO', style: estilo)),
              const SizedBox(width: 8),
              Expanded(child: Text('DESCRIÇÃO', style: estilo)),
              Text('VALOR', style: estilo),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildItemRow(TipoProvento item, bool isDark, int index) {
    final isProvento = item.tipoRubrica == 'P';
    final valor = isProvento ? item.provento : item.desconto;
    final accentColor =
        isProvento ? const Color(0xFF1B8A3C) : const Color(0xFFD32F2F);

    // Linhas translúcidas, no padrão do resto do app: a cor fica como um
    // tingimento leve, e quem comunica provento ou desconto é o selo P/D
    // mais o sinal do valor — não só a cor de fundo.
    final rowColor = accentColor.withValues(
      alpha: isDark
          ? (index.isEven ? 0.10 : 0.07)
          : (index.isEven ? 0.07 : 0.04),
    );

    return Container(
      margin: const EdgeInsets.only(top: 3),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: rowColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: accentColor.withValues(alpha: isDark ? 0.22 : 0.18),
        ),
      ),
      child: Row(
        children: [
          // Badge P / D
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                item.tipoRubrica,
                style: TextStyle(
                  color: accentColor,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Descrição — ocupa todo espaço disponível
          Expanded(
            child: Text(
              item.descricaoRubrica,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.85)
                    : const Color(0xFF2D3748),
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 6),

          // Valor — largura fixa + AutoSizeText para shrink automático
          SizedBox(
            width: 82,
            child: AutoSizeText(
              'R\$\u2009$valor',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: accentColor,
              ),
              maxLines: 1,
              minFontSize: 8,
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  // ── Barra de resumo (proventos / descontos / líquido) ─────────────────
  Widget _buildSummaryBar(bool isDark) {
    // Era um bloco sólido azul→navy. Agora é vidro tingido: continua sendo o
    // elemento de mais peso da tela, mas deixa o fundo passar. As cores de
    // provento/desconto mudam por modo para manter contraste de 4.5:1.
    return Builder(builder: (context) {
      final theme = Theme.of(context);
      final verde = isDark ? const Color(0xFF6EE7A0) : const Color(0xFF14713B);
      final vermelho =
          isDark ? const Color(0xFFFF9E9E) : const Color(0xFFB3261E);

      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: CartaoVidro(
          raio: 16,
          tingimento: theme.colorScheme.primary,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              _summaryCol(
                label: 'Proventos',
                value:
                    'R\$\u2009${CurrencyFormatter.format(proventos, _realSettings)}',
                color: verde,
                isDark: isDark,
              ),
              Container(
                width: 1,
                height: 36,
                color: theme.colorScheme.onSurface.withOpacity(0.12),
              ),
              _summaryCol(
                label: 'Descontos',
                value:
                    'R\$\u2009${CurrencyFormatter.format(descontos, _realSettings)}',
                color: vermelho,
                isDark: isDark,
              ),
              Container(
                width: 1,
                height: 36,
                color: theme.colorScheme.onSurface.withOpacity(0.12),
              ),
              _summaryCol(
                label: 'Líquido',
                value:
                    'R\$\u2009${CurrencyFormatter.format(totalLiquido, _realSettings)}',
                color: theme.colorScheme.onSurface,
                isDark: isDark,
                destaque: true,
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _summaryCol({
    required String label,
    required String value,
    required Color color,
    required bool isDark,
    bool destaque = false,
  }) {
    return Expanded(
      child: Builder(builder: (context) {
        final theme = Theme.of(context);
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label.toUpperCase(),
              style: TextStyle(
                fontSize: 9,
                color: theme.colorScheme.onSurface.withOpacity(0.60),
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 3),
            // AutoSizeText: shrink automático se o valor não couber
            AutoSizeText(
              value,
              style: TextStyle(
                fontSize: destaque ? 13 : 11.5,
                color: color,
                fontWeight: FontWeight.w800,
              ),
              maxLines: 1,
              minFontSize: 7,
              textAlign: TextAlign.center,
            ),
          ],
        );
      }),
    );
  }

  // ── Barra inferior de compartilhamento ────────────────────────────────
  Widget _buildShareBar(Auth auth, bool isDark) {
    return SafeArea(
      child: CartaoVidro(
        raio: 0,
        desfoque: 22,
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Aviso
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                '* Dados apenas para visualização. Não válido como documento oficial.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10,
                  color: isDark ? Colors.white38 : Colors.black38,
                ),
              ),
            ),
            // Botões de compartilhar
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: (_sharingImage || _sharingPdf)
                        ? null
                        : () => _shareImage(auth),
                    icon: _sharingImage
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.blue,
                            ),
                          )
                        : const Icon(Icons.image_outlined, size: 18),
                    label: const Text('Compartilhar\nImagem',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.primary,
                      side: BorderSide(
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withOpacity(0.55)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: (_sharingPdf || _sharingImage)
                        ? null
                        : () => _sharePdf(auth),
                    icon: _sharingPdf
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.picture_as_pdf_outlined, size: 18),
                    label: const Text('Compartilhar\nPDF',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12)),
                    style: FilledButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      // No escuro a primária é clara: texto branco em cima
                      // dela fica em ~2:1. A cor do rótulo segue a luminância
                      // do fundo para manter a leitura.
                      foregroundColor: ThemeData.estimateBrightnessForColor(
                                  Theme.of(context).colorScheme.primary) ==
                              Brightness.dark
                          ? Colors.white
                          : Colors.black87,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
