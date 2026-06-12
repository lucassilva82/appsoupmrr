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

  // ── Gera o arquivo PDF v2.0 ───────────────────────────────────────────
  Future<File> _generatePdf(Auth auth) async {
    final pdf = pw.Document();

    final ByteData logoData = await rootBundle.load('assets/imagens/pmrrr.png');
    final Uint8List logoBytes = logoData.buffer.asUint8List();
    final ByteData dtiData = await rootBundle.load('assets/imagens/dti.jpeg');
    final Uint8List dtiBytes = dtiData.buffer.asUint8List();

    // ── Paleta de cores (espelha o app) ──────────────────────────────────
    final cNavy   = PdfColor.fromHex('#002154');
    final cBlue   = PdfColor.fromHex('#1565C0');
    final cGold   = PdfColor.fromHex('#FFB300');
    final cGreen  = PdfColor.fromHex('#2E7D32');
    final cRed    = PdfColor.fromHex('#C62828');
    final cGreenL = PdfColor.fromHex('#69F0AE');
    final cRedL   = PdfColor.fromHex('#FF8A80');
    final cBg     = PdfColor.fromHex('#F0F4F8');
    final cLabel  = PdfColor.fromHex('#78909C');
    final cValue  = PdfColor.fromHex('#1A237E');
    final cText   = PdfColor.fromHex('#37474F');
    final cAlt    = PdfColor.fromHex('#F5F7FA');
    final cBorder = PdfColor.fromHex('#CFD8DC');
    final cSep    = PdfColor.fromHex('#455A64');
    final cLightBlue = PdfColor.fromHex('#90CAF9');
    final cSubtle = PdfColor.fromHex('#B0BEC5');
    final cDiscl  = PdfColor.fromHex('#90A4AE');

    final mesAno = '${widget.mesSelecionado.mesExtenso.toUpperCase()} / ${widget.mesSelecionado.ano}';

    // ── Helper: campo info (label + valor) ────────────────────────────────
    pw.Widget infoField(String label, String value) => pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(label,
            style: pw.TextStyle(
                fontSize: 7,
                color: cLabel,
                fontWeight: pw.FontWeight.bold,
                letterSpacing: 0.6)),
        pw.SizedBox(height: 2),
        pw.Text(value,
            style: pw.TextStyle(
                fontSize: 10,
                color: cValue,
                fontWeight: pw.FontWeight.bold)),
      ],
    );

    // ── Helper: linha de rubrica ──────────────────────────────────────────
    pw.Widget rubraRow(TipoProvento item, int idx) {
      final isP   = item.tipoRubrica == 'P';
      final valor = isP ? item.provento : item.desconto;
      final badgeBg  = isP ? cGreen : cRed;
      final valColor = isP ? cGreen : cRed;
      return pw.Container(
        color: idx.isEven ? PdfColors.white : cAlt,
        padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        child: pw.Row(
          children: [
            pw.Container(
              width: 18,
              height: 18,
              decoration: pw.BoxDecoration(
                color: badgeBg,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(9)),
              ),
              child: pw.Center(
                child: pw.Text(item.tipoRubrica,
                    style: pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold)),
              ),
            ),
            pw.SizedBox(width: 8),
            pw.Expanded(
              child: pw.Text(item.descricaoRubrica,
                  style: pw.TextStyle(fontSize: 9, color: cText)),
            ),
            pw.Text('R\$\u2009$valor',
                style: pw.TextStyle(
                    fontSize: 9,
                    color: valColor,
                    fontWeight: pw.FontWeight.bold)),
          ],
        ),
      );
    }

    // ── Helper: coluna de resumo ──────────────────────────────────────────
    pw.Widget summaryCol(String label, String value, PdfColor color) =>
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Text(label,
                  style: pw.TextStyle(
                      fontSize: 7, color: cSubtle, letterSpacing: 0.8)),
              pw.SizedBox(height: 4),
              pw.Text(value,
                  style: pw.TextStyle(
                      fontSize: 11,
                      color: color,
                      fontWeight: pw.FontWeight.bold)),
            ],
          ),
        );

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.zero,

      // ── Cabeçalho (repetido em cada página) ────────────────────────────
      header: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Container(
            color: cNavy,
            padding: const pw.EdgeInsets.fromLTRB(20, 14, 20, 14),
            child: pw.Row(children: [
              pw.SizedBox(
                  width: 52,
                  height: 52,
                  child: pw.Image(pw.MemoryImage(logoBytes),
                      fit: pw.BoxFit.contain)),
              pw.SizedBox(width: 14),
              pw.Expanded(
                child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('CONTRACHEQUE',
                          style: pw.TextStyle(
                              fontSize: 17,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.white,
                              letterSpacing: 1.5)),
                      pw.SizedBox(height: 3),
                      pw.Text(mesAno,
                          style: pw.TextStyle(
                              fontSize: 10, color: cLightBlue)),
                    ]),
              ),
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                pw.Text('PMRR',
                    style: pw.TextStyle(
                        fontSize: 10,
                        color: cGold,
                        fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 2),
                pw.Text('Polícia Militar de Roraima',
                    style: pw.TextStyle(fontSize: 7, color: cSubtle)),
              ]),
            ]),
          ),
          // Faixa dourada
          pw.Container(height: 3, color: cGold),
          // Seção de dados do militar (apenas 1ª página)
          if (ctx.pageNumber == 1) ...[
            pw.Container(
              color: cBg,
              padding: const pw.EdgeInsets.fromLTRB(20, 10, 20, 10),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  infoField('NOME', auth.nomeCompleto ?? '-'),
                  pw.SizedBox(height: 8),
                  pw.Row(children: [
                    pw.Expanded(
                        child: infoField(
                            'MATRÍCULA', widget.mesSelecionado.matricula)),
                    pw.Expanded(
                        child: infoField('MÊS / ANO',
                            '${widget.mesSelecionado.mes} / ${widget.mesSelecionado.ano}')),
                    pw.Expanded(
                        child: infoField(
                            'FOLHA',
                            contracheque.Folha.isNotEmpty
                                ? contracheque.Folha
                                : widget.mesSelecionado.folha)),
                  ]),
                  pw.SizedBox(height: 8),
                  pw.Row(children: [
                    pw.Expanded(
                        child: infoField(
                            'UN. ORGANIZACIONAL',
                            contracheque.UnidadeOrganizacional.isNotEmpty
                                ? contracheque.UnidadeOrganizacional
                                : '-')),
                    pw.Expanded(
                        child: infoField('RELAÇÃO DE TRABALHO',
                            widget.mesSelecionado.relacaoTrabalho)),
                  ]),
                ],
              ),
            ),
            pw.Container(height: 1, color: cBorder),
            // Cabeçalho das colunas da tabela
            pw.Container(
              color: cBlue,
              padding:
                  const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: pw.Row(children: [
                pw.SizedBox(width: 26),
                pw.Expanded(
                    child: pw.Text('DESCRIÇÃO DA RUBRICA',
                        style: pw.TextStyle(
                            fontSize: 7.5,
                            color: PdfColors.white,
                            fontWeight: pw.FontWeight.bold,
                            letterSpacing: 0.8))),
                pw.Text('VALOR',
                    style: pw.TextStyle(
                        fontSize: 7.5,
                        color: PdfColors.white,
                        fontWeight: pw.FontWeight.bold,
                        letterSpacing: 0.8)),
              ]),
            ),
          ],
        ],
      ),

      // ── Rodapé com disclaimer e logo DTI ───────────────────────────────
      footer: (ctx) => pw.Container(
        color: cBg,
        padding: const pw.EdgeInsets.fromLTRB(20, 6, 20, 6),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
                '* Dados apenas para visualização. Não válido como documento oficial.',
                style: pw.TextStyle(
                    fontSize: 6.5,
                    color: cDiscl,
                    fontStyle: pw.FontStyle.italic)),
            pw.SizedBox(
                height: 26,
                width: 65,
                child: pw.Image(pw.MemoryImage(dtiBytes),
                    fit: pw.BoxFit.contain)),
          ],
        ),
      ),

      // ── Conteúdo: rubricas + resumo ────────────────────────────────────
      build: (ctx) => [
        ...contracheque.proventos
            .asMap()
            .entries
            .map((e) => rubraRow(e.value, e.key)),

        // Barra de resumo (proventos / descontos / líquido)
        pw.SizedBox(height: 10),
        pw.Container(
          color: cNavy,
          padding:
              const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: pw.Row(
            children: [
              summaryCol(
                'PROVENTOS',
                'R\$\u2009${CurrencyFormatter.format(proventos, _realSettings)}',
                cGreenL,
              ),
              pw.Container(width: 1, height: 36, color: cSep),
              summaryCol(
                'DESCONTOS',
                'R\$\u2009${CurrencyFormatter.format(descontos, _realSettings)}',
                cRedL,
              ),
              pw.Container(width: 1, height: 36, color: cSep),
              summaryCol(
                'LÍQUIDO',
                'R\$\u2009${CurrencyFormatter.format(totalLiquido, _realSettings)}',
                PdfColors.white,
              ),
            ],
          ),
        ),
        pw.Container(height: 3, color: cGold),
      ],
    ));

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
