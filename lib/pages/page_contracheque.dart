// ignore_for_file: must_be_immutable
import 'dart:io';
import 'dart:typed_data';

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
  bool _sharing = false;

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
      final val = double.tryParse(e.provento) ?? 0.0;
      e.provento = formatter.format(val);
    }

    return contracheque;
  }

  // ── Gera o arquivo PDF ────────────────────────────────────────────────
  Future<File> _generatePdf(Auth auth) async {
    final pdf = pw.Document();

    final ByteData bytes = await rootBundle.load('assets/imagens/pmrrr.png');
    final Uint8List byteList = bytes.buffer.asUint8List();
    final ByteData bytesDti = await rootBundle.load('assets/imagens/dti.jpeg');
    final Uint8List byteListDti = bytesDti.buffer.asUint8List();

    pdf.addPage(
      pw.Page(
        margin: const pw.EdgeInsets.all(10),
        build: (pw.Context ctx) {
          return pw.Container(
            color: PdfColor.fromHex('#f5f5f5'),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Container(
                  color: PdfColor.fromHex('#003366'),
                  padding: const pw.EdgeInsets.all(10),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Container(
                        height: 100,
                        width: 100,
                        child: pw.Image(pw.MemoryImage(byteList),
                            fit: pw.BoxFit.cover),
                      ),
                      pw.Text(
                        'Contracheque - ${widget.mesSelecionado.mes}/${widget.mesSelecionado.ano}',
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
                        pw.Text(widget.mesSelecionado.relacaoTrabalho,
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
                              '${widget.mesSelecionado.mes}/${widget.mesSelecionado.ano}',
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
                    style: pw.TextStyle(fontSize: 14, color: PdfColors.black)),
                pw.SizedBox(height: 20),
                pw.Container(
                  color: PdfColor.fromHex('#003366'),
                  padding: const pw.EdgeInsets.all(5),
                  child: pw.Text('Proventos e Descontos',
                      style: pw.TextStyle(
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.white)),
                ),
                pw.Table.fromTextArray(
                  headerStyle: pw.TextStyle(color: PdfColors.white),
                  headerDecoration:
                      pw.BoxDecoration(color: PdfColor.fromHex('#003366')),
                  cellPadding: const pw.EdgeInsets.all(5),
                  data: [
                    ['Tipo', 'Descrição', 'Valor'],
                    ...contracheque.proventos.map((p) => [
                          p.tipoRubrica,
                          p.descricaoRubrica,
                          'R\$ ${p.tipoRubrica == 'P' ? p.provento : p.desconto}'
                        ]),
                  ],
                ),
                pw.SizedBox(height: 20),
                pw.Container(
                  color: PdfColor.fromHex('#003366'),
                  padding: const pw.EdgeInsets.all(5),
                  child: pw.Text('Resumo',
                      style: pw.TextStyle(
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.white)),
                ),
                pw.SizedBox(height: 10),
                pw.Text(
                    'Proventos: R\$ ${CurrencyFormatter.format(proventos, _realSettings)}',
                    style: pw.TextStyle(
                        color: PdfColors.blue,
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 10),
                pw.Text(
                    'Descontos: R\$ ${CurrencyFormatter.format(descontos, _realSettings)}',
                    style: pw.TextStyle(
                        color: PdfColors.red,
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 10),
                pw.Text(
                    'Total Líquido: R\$ ${CurrencyFormatter.format(totalLiquido, _realSettings)}',
                    style: pw.TextStyle(
                        color: PdfColors.green,
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 80),
                pw.Container(
                  height: 55,
                  width: 900,
                  child: pw.Image(pw.MemoryImage(byteListDti),
                      fit: pw.BoxFit.cover),
                ),
              ],
            ),
          );
        },
      ),
    );

    final output = await getTemporaryDirectory();
    final file = File('${output.path}/contracheque.pdf');
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  // ── Compartilhar PDF ──────────────────────────────────────────────────
  Future<void> _sharePdf(Auth auth) async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      final file = await _generatePdf(auth);
      await Share.shareXFiles(
        [XFile(file.path)],
        subject:
            'Contracheque ${widget.mesSelecionado.mesExtenso}/${widget.mesSelecionado.ano}',
      );
    } catch (e) {
      if (!mounted) return;
      QuickAlert.show(
        context: context,
        type: QuickAlertType.error,
        title: 'Erro',
        text: 'Não foi possível gerar o PDF.',
        confirmBtnText: 'OK',
      );
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  // ── Compartilhar Imagem (rasteriza o PDF) ─────────────────────────────
  Future<void> _shareImage(Auth auth) async {
    if (_sharing) return;
    setState(() => _sharing = true);
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
      );
    } catch (e) {
      if (!mounted) return;
      QuickAlert.show(
        context: context,
        type: QuickAlertType.error,
        title: 'Erro',
        text: 'Não foi possível gerar a imagem.',
        confirmBtnText: 'OK',
      );
    } finally {
      if (mounted) setState(() => _sharing = false);
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
    final rowColor = isProvento
        ? (isDark ? const Color(0xFF1A2A1A) : const Color(0xFFF0FDF4))
        : (isDark ? const Color(0xFF2A1A1A) : const Color(0xFFFFF5F5));
    final accentColor =
        isProvento ? const Color(0xFF1B8A3C) : const Color(0xFFD32F2F);
    final badgeBg = isProvento
        ? const Color(0xFF1B8A3C).withValues(alpha: 0.12)
        : const Color(0xFFD32F2F).withValues(alpha: 0.1);

    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: rowColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : accentColor.withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        children: [
          // Badge P / D
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: badgeBg,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                item.tipoRubrica,
                style: TextStyle(
                  color: accentColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Descrição
          Expanded(
            child: Text(
              item.descricaoRubrica,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.87)
                    : const Color(0xFF2D3748),
              ),
            ),
          ),

          // Valor
          Text(
            'R\$ $valor',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: accentColor,
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
            value: 'R\$ ${CurrencyFormatter.format(proventos, _realSettings)}',
            color: const Color(0xFF69F0AE),
          ),
          Container(width: 1, height: 36, color: Colors.white24),
          _summaryCol(
            label: 'Descontos',
            value: 'R\$ ${CurrencyFormatter.format(descontos, _realSettings)}',
            color: const Color(0xFFFF8A80),
          ),
          Container(width: 1, height: 36, color: Colors.white24),
          _summaryCol(
            label: 'Líquido',
            value:
                'R\$ ${CurrencyFormatter.format(totalLiquido, _realSettings)}',
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
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: Colors.white70,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w800,
            ),
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
                    onPressed: _sharing ? null : () => _shareImage(auth),
                    icon: const Icon(Icons.image_outlined, size: 18),
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
                    onPressed: _sharing ? null : () => _sharePdf(auth),
                    icon: _sharing
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
