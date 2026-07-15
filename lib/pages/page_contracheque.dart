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
                      fontSize: 13,
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
            padding: const pw.EdgeInsets.fromLTRB(30, 20, 30, 20),
            child: pw.Row(children: [
              pw.SizedBox(
                width: 64,
                height: 64,
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
                              fontSize: 22,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.white,
                              letterSpacing: 2.5)),
                      pw.SizedBox(height: 5),
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
              padding: const pw.EdgeInsets.fromLTRB(30, 16, 30, 0),
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
                pw.SizedBox(height: 16),
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
                    padding: const pw.EdgeInsets.symmetric(
                        horizontal: 10, vertical: 8),
                    child: pw.Text('TIPO',
                        textAlign: pw.TextAlign.center,
                        style: pw.TextStyle(
                            fontSize: 8,
                            color: PdfColors.white,
                            fontWeight: pw.FontWeight.bold,
                            letterSpacing: 0.6)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.fromLTRB(8, 8, 8, 8),
                    child: pw.Text('DESCRIÇÃO DA RUBRICA',
                        style: pw.TextStyle(
                            fontSize: 8.5,
                            color: PdfColors.white,
                            fontWeight: pw.FontWeight.bold,
                            letterSpacing: 0.8)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.fromLTRB(8, 8, 8, 8),
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
                      padding: const pw.EdgeInsets.symmetric(
                          horizontal: 10, vertical: 9),
                      child: pw.Center(
                        child: pw.Container(
                          width: 22,
                          height: 22,
                          decoration: pw.BoxDecoration(
                            color: badgeBg,
                            borderRadius: const pw.BorderRadius.all(
                                pw.Radius.circular(11)),
                          ),
                          child: pw.Center(
                            child: pw.Text(item.tipoRubrica,
                                style: pw.TextStyle(
                                    color: PdfColors.white,
                                    fontSize: 9,
                                    fontWeight: pw.FontWeight.bold)),
                          ),
                        ),
                      ),
                    ),
                    // Coluna descrição
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(
                          horizontal: 8, vertical: 9),
                      child: pw.Text(item.descricaoRubrica,
                          style: pw.TextStyle(fontSize: 10, color: cText)),
                    ),
                    // Coluna valor
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(
                          horizontal: 8, vertical: 9),
                      child: pw.Text('R\$\u2009$valor',
                          textAlign: pw.TextAlign.right,
                          style: pw.TextStyle(
                              fontSize: 10,
                              color: valColor,
                              fontWeight: pw.FontWeight.bold)),
                    ),
                  ],
                );
              }).toList(),
            ],
          ),
        ),

        pw.SizedBox(height: 16),

        // Barra de resumo
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 30),
          child: pw.Container(
            decoration: pw.BoxDecoration(
              color: cHeader,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
            ),
            padding:
                const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 18),
            child: pw.Row(children: [
              summaryCol(
                'PROVENTOS',
                'R\$\u2009${CurrencyFormatter.format(proventos, _realSettings)}',
                cGreenLt,
              ),
              pw.Container(width: 1, height: 38, color: cSep),
              summaryCol(
                'DESCONTOS',
                'R\$\u2009${CurrencyFormatter.format(descontos, _realSettings)}',
                cRedLt,
              ),
              pw.Container(width: 1, height: 38, color: cSep),
              summaryCol(
                'LÍQUIDO A RECEBER',
                'R\$\u2009${CurrencyFormatter.format(totalLiquido, _realSettings)}',
                PdfColors.white,
              ),
            ]),
          ),
        ),

        pw.SizedBox(height: 12),
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
          backgroundColor:
              isDark ? const Color(0xFF0D1117) : const Color(0xFFF4F6FA),
          // ── AppBar — mesma cor que CustomAppBar ──────────────────
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            centerTitle: true,
            iconTheme: const IconThemeData(color: Colors.white),
            flexibleSpace: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: AppTheme.appBarGradient(
                    isDark: isDark,
                    isSuperUser: auth.isSuperUser,
                  ),
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
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
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C2128) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF30363D) : const Color(0xFFE0E7F0),
        ),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
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
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.blue, AppColors.navy],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Row(
        children: [
          SizedBox(
            width: 32,
            child: Text('Tipo',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700)),
          ),
          Expanded(
            child: Text('Descrição',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700)),
          ),
          SizedBox(
            width: 90,
            child: Text('Valor',
                textAlign: TextAlign.right,
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  // ── Linha de rubrica ──────────────────────────────────────────────────
  Widget _buildItemRow(TipoProvento item, bool isDark, int index) {
    final isProvento = item.tipoRubrica == 'P';
    final valor = isProvento ? item.provento : item.desconto;
    final accentColor =
        isProvento ? const Color(0xFF1B8A3C) : const Color(0xFFD32F2F);

    // Zebra suave: alterna levemente o fundo par/ímpar
    final baseBg = isProvento
        ? (isDark ? const Color(0xFF182818) : const Color(0xFFF0FDF4))
        : (isDark ? const Color(0xFF281818) : const Color(0xFFFFF5F5));
    final altBg = isProvento
        ? (isDark ? const Color(0xFF1C2E1C) : const Color(0xFFE8FAF0))
        : (isDark ? const Color(0xFF2E1C1C) : const Color(0xFFFEECEC));
    final rowColor = index.isEven ? baseBg : altBg;

    return Container(
      margin: const EdgeInsets.only(top: 3),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: rowColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.04)
              : accentColor.withValues(alpha: 0.12),
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
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.blue, AppColors.navy],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          _summaryCol(
            label: 'Proventos',
            value:
                'R\$\u2009${CurrencyFormatter.format(proventos, _realSettings)}',
            color: const Color(0xFF69F0AE),
          ),
          Container(width: 1, height: 36, color: Colors.white24),
          _summaryCol(
            label: 'Descontos',
            value:
                'R\$\u2009${CurrencyFormatter.format(descontos, _realSettings)}',
            color: const Color(0xFFFF8A80),
          ),
          Container(width: 1, height: 36, color: Colors.white24),
          _summaryCol(
            label: 'Líquido',
            value:
                'R\$\u2009${CurrencyFormatter.format(totalLiquido, _realSettings)}',
            color: Colors.white,
          ),
        ],
      ),
    );
  }

  Widget _summaryCol(
      {required String label, required String value, required Color color}) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 9,
              color: Colors.white60,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 3),
          // AutoSizeText: shrink automático se o valor não couber
          AutoSizeText(
            value,
            style: TextStyle(
              fontSize: 11.5,
              color: color,
              fontWeight: FontWeight.w800,
            ),
            maxLines: 1,
            minFontSize: 7,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ── Barra inferior de compartilhamento ────────────────────────────────
  Widget _buildShareBar(Auth auth, bool isDark) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1C2128) : Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.08),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
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
                      foregroundColor: AppColors.blue,
                      side: const BorderSide(color: AppColors.blue),
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
                      backgroundColor: AppColors.blue,
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
