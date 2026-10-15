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
import 'package:share_plus/share_plus.dart';

import '../models/auth_model.dart';
import '../models/contracheque_model.dart';
import '../models/meses_contracheque_model.dart';
import '../services/dados_sql.dart';
import '../utils/app_theme.dart';
import '../view/second_screen.dart';
import '../widgets/vidro.dart';
import '../widgets/barra_vidro.dart';
import '../widgets/alerta.dart';

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

  // Arquivos guardados depois de gerados. Compartilhar o mesmo mês de novo
  // não refaz o PDF nem a rasterização, que é a parte cara da operação.
  File? _pdfPronto;
  File? _imagemPronta;

  // A página rasterizada. Serve para a prévia dos dois formatos e para o
  // arquivo PNG, então é gerada uma vez só.
  Uint8List? _paginaRasterizada;

  // A consulta roda uma vez só, na primeira leitura.
  //
  // Antes o `future:` era montado dentro do build(): cada setState criava uma
  // consulta nova, o FutureBuilder voltava para ConnectionState.waiting e a
  // tela inteira era substituída pelo indicador de carregamento. Era essa a
  // piscada ao tocar em compartilhar — e a segunda piscada ao cancelar a
  // folha do sistema, quando o setState de encerramento rodava.
  late final Future<ContrachequeModel> _dados = _buscaDadosSql();

  final CurrencyFormatterSettings _realSettings = CurrencyFormatterSettings(
    symbol: '',
    symbolSide: SymbolSide.right,
    thousandSeparator: '.',
    decimalSeparator: ',',
    symbolSeparator: ' ',
  );

  Future<ContrachequeModel> _buscaDadosSql() async {
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

  // ── Documento PDF ─────────────────────────────────────────────────────
  //
  // O contracheque sai daqui para o banco, o locador e o RH. Ele precisa
  // parecer o que é: um documento institucional da corporação, não um
  // relatório genérico. As escolhas abaixo seguem essa intenção.
  //
  //  • Tipografia Lato, a mesma do app, empacotada no bundle. Antes o PDF
  //    usava a Helvetica embutida do gerador — a fonte que todo PDF sem
  //    projeto gráfico usa, e que ainda avisava no log não ter suporte a
  //    Unicode completo.
  //  • Hierarquia em três níveis: rótulo miúdo em caixa alta espaçada,
  //    valor em peso forte, e um único herói por bloco. Nada compete.
  //  • Fios de 0,4pt em azul a 8% no lugar de bordas cinzas fechando cada
  //    célula. A grade pesada era o que mais datava o documento.
  //  • Degradê e transparência onde dão profundidade: a faixa do topo, o
  //    brasão em marca d'água a 4%, as etiquetas P/D em cor sólida a 12% e
  //    o bloco de totais com um cartão interno em branco a 10%.
  //
  // Sobre paginação: a versão anterior encolhia a fonte até 5,5pt para
  // forçar tudo numa página. Contracheque de 40 rubricas virava algo
  // ilegível. Agora o piso é 8pt e o documento pagina, com o cabeçalho da
  // tabela se repetindo e a contagem "Página X de Y" no rodapé.
  Future<File> _generatePdf(Auth auth) async {
    final pdf = pw.Document(
      title:
          'Contracheque ${widget.mesSelecionado.mesExtenso}/${widget.mesSelecionado.ano}',
      author: 'Polícia Militar do Estado de Roraima',
      creator: 'SouPMRR',
      subject: 'Demonstrativo de pagamento',
    );

    // Fontes do próprio app, já no bundle: nada de rede na hora de gerar.
    final fonteBase =
        pw.Font.ttf(await rootBundle.load('assets/fonts/Lato-Regular.ttf'));
    final fonteForte =
        pw.Font.ttf(await rootBundle.load('assets/fonts/Lato-Bold.ttf'));

    final ByteData logoData = await rootBundle.load('assets/imagens/pmrrr.png');
    final brasao = pw.MemoryImage(logoData.buffer.asUint8List());
    final ByteData dtiData = await rootBundle.load('assets/imagens/dti.jpeg');
    final dti = pw.MemoryImage(dtiData.buffer.asUint8List());

    // ── Paleta ────────────────────────────────────────────────────────
    // Os mesmos valores do app (AppColors), para o documento e a tela
    // falarem a mesma língua.
    final navy = PdfColor.fromHex('#002154');
    final navyFundo = PdfColor.fromHex('#00112E');
    final navyClaro = PdfColor.fromHex('#0B3A6F');
    final ouro = PdfColor.fromHex('#FFB300');
    final tinta = PdfColor.fromHex('#0F172A');
    final tintaFraca = PdfColor.fromHex('#475569');
    final rotulo = PdfColor.fromHex('#8A98AC');
    final papel = PdfColors.white;
    final papelFundo = PdfColor.fromHex('#F7F9FC');
    final verde = PdfColor.fromHex('#0F7B3F');
    final vermelho = PdfColor.fromHex('#B42318');
    final verdeClaro = PdfColor.fromHex('#6EE7A8');
    final vermelhoClaro = PdfColor.fromHex('#FCA5A5');

    /// Mistura duas cores. É daqui que vêm os fios, as faixas alternadas e
    /// as etiquetas: tinta diluída no fundo, em vez de cinzas chapados.
    ///
    /// Por que misturar em vez de usar cor com alfa: o dart_pdf descarta o
    /// canal alfa no preenchimento — `setFillColor` emite só `r g b rg`. Uma
    /// cor a 12% sai pintada a 100%, e foi o que aconteceu na primeira
    /// versão: as linhas pares viraram azul sólido e as etiquetas, blocos
    /// chapados. Transparência real no PDF só com `pw.Opacity`, que é o que
    /// a marca d'água usa. Pré-misturar ainda imprime melhor, porque não
    /// depende de grupo de transparência do leitor.
    PdfColor mistura(PdfColor fundo, PdfColor frente, double t) => PdfColor(
          fundo.red + (frente.red - fundo.red) * t,
          fundo.green + (frente.green - fundo.green) * t,
          fundo.blue + (frente.blue - fundo.blue) * t,
        );

    final fio = mistura(papel, navy, 0.16);
    final faixaPar = mistura(papel, navy, 0.035);

    final mesAno =
        '${widget.mesSelecionado.mesExtenso.toUpperCase()} · ${widget.mesSelecionado.ano}';
    final emitidoEm = DateFormat("dd/MM/yyyy 'às' HH:mm").format(DateTime.now());

    // ── Densidade ─────────────────────────────────────────────────────
    // Dois níveis apenas, com piso de 8pt. Acima disso o documento pagina
    // em vez de espremer: um contracheque ilegível não serve para nada.
    final int nRubricas = contracheque.proventos.length;
    final bool denso = nRubricas > 16;
    final double linhaVPad = denso ? 4.5 : 7.0;
    final double linhaFonte = denso ? 8.5 : 9.5;

    final dinheiro = CurrencyFormatter.format;

    // ── Peças de texto ────────────────────────────────────────────────
    pw.Widget sobrescrito(String texto, {PdfColor? cor, double tam = 6.5}) =>
        pw.Text(
          texto.toUpperCase(),
          style: pw.TextStyle(
            fontSize: tam,
            color: cor ?? rotulo,
            fontWeight: pw.FontWeight.bold,
            letterSpacing: 1.1,
          ),
        );

    pw.Widget campo(String etiqueta, String valor, {double tam = 10.5}) =>
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            sobrescrito(etiqueta),
            pw.SizedBox(height: 3),
            pw.Text(
              valor.isEmpty ? '—' : valor,
              style: pw.TextStyle(
                  fontSize: tam, color: tinta, fontWeight: pw.FontWeight.bold),
            ),
          ],
        );

    // Coluna secundária do bloco de totais.
    pw.Widget totalSecundario(String etiqueta, String valor, PdfColor cor) =>
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              sobrescrito(etiqueta, cor: mistura(navy, PdfColors.white, 0.62), tam: 6.5),
              pw.SizedBox(height: 5),
              pw.Text('R\$ $valor',
                  style: pw.TextStyle(
                      fontSize: 12.5,
                      color: cor,
                      fontWeight: pw.FontWeight.bold)),
            ],
          ),
        );

    // ── Cabeçalho ─────────────────────────────────────────────────────
    pw.Widget cabecalho(pw.Context ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Container(
              height: 86,
              decoration: pw.BoxDecoration(
                gradient: pw.LinearGradient(
                  begin: pw.Alignment.topLeft,
                  end: pw.Alignment.bottomRight,
                  colors: [navyClaro, navy, navyFundo],
                  stops: const [0.0, 0.45, 1.0],
                ),
                borderRadius: const pw.BorderRadius.only(
                  topLeft: pw.Radius.circular(12),
                  topRight: pw.Radius.circular(12),
                ),
              ),
              child: pw.Stack(
                children: [
                  // Brasão gigante sangrando pela direita, quase imperceptível.
                  // É o que tira a faixa da aparência de retângulo chapado.
                  pw.Positioned(
                    right: -34,
                    top: -40,
                    child: pw.Opacity(
                      opacity: 0.07,
                      child: pw.SizedBox(
                          width: 190,
                          height: 190,
                          child: pw.Image(brasao, fit: pw.BoxFit.contain)),
                    ),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.fromLTRB(22, 0, 22, 0),
                    child: pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.SizedBox(
                            width: 46,
                            height: 46,
                            child: pw.Image(brasao, fit: pw.BoxFit.contain)),
                        pw.SizedBox(width: 18),
                        pw.Expanded(
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            mainAxisAlignment: pw.MainAxisAlignment.center,
                            children: [
                              pw.Text('CONTRACHEQUE',
                                  style: pw.TextStyle(
                                      fontSize: 21,
                                      fontWeight: pw.FontWeight.bold,
                                      color: PdfColors.white,
                                      letterSpacing: 3.4)),
                              pw.SizedBox(height: 5),
                              pw.Row(children: [
                                pw.Container(
                                    width: 16, height: 1.6, color: ouro),
                                pw.SizedBox(width: 7),
                                pw.Text(mesAno,
                                    style: pw.TextStyle(
                                        fontSize: 9.5,
                                        color: mistura(navy, PdfColors.white, 0.80),
                                        letterSpacing: 1.4)),
                              ]),
                            ],
                          ),
                        ),
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.end,
                          mainAxisAlignment: pw.MainAxisAlignment.center,
                          children: [
                            pw.Text('POLÍCIA MILITAR',
                                style: pw.TextStyle(
                                    fontSize: 9,
                                    color: PdfColors.white,
                                    fontWeight: pw.FontWeight.bold,
                                    letterSpacing: 1.6)),
                            pw.SizedBox(height: 2),
                            pw.Text('DO ESTADO DE RORAIMA',
                                style: pw.TextStyle(
                                    fontSize: 7,
                                    color: ouro,
                                    fontWeight: pw.FontWeight.bold,
                                    letterSpacing: 1.1)),
                            pw.SizedBox(height: 4),
                            pw.Text('Governo do Estado de Roraima',
                                style: pw.TextStyle(
                                    fontSize: 6.5,
                                    color: mistura(navy, PdfColors.white, 0.58))),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Fio dourado que se dissolve: dá o acento institucional sem
            // virar uma tarja atravessando a página.
            pw.Container(
              height: 2.5,
              decoration: pw.BoxDecoration(
                gradient: pw.LinearGradient(
                  begin: pw.Alignment.centerLeft,
                  end: pw.Alignment.centerRight,
                  colors: [ouro, mistura(papelFundo, ouro, 0.85), papelFundo],
                  stops: const [0.0, 0.28, 1.0],
                ),
              ),
            ),
          ],
        );

    // ── Identificação do militar ──────────────────────────────────────
    // Casca externa levemente tingida com o cartão branco por dentro: o
    // bloco ganha relevo sem precisar de sombra pesada.
    pw.Widget identificacao() => pw.Container(
          decoration: pw.BoxDecoration(
            color: mistura(papelFundo, navy, 0.06),
            border: pw.Border.all(color: fio, width: 0.6),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
          ),
          padding: const pw.EdgeInsets.all(5),
          child: pw.Container(
            decoration: pw.BoxDecoration(
              color: papel,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
            ),
            padding: const pw.EdgeInsets.fromLTRB(16, 13, 16, 14),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                campo('Nome completo', auth.nomeCompleto ?? '', tam: 13.5),
                pw.SizedBox(height: 12),
                pw.Container(height: 0.6, color: fio),
                pw.SizedBox(height: 12),
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(
                        flex: 3,
                        child: campo(
                            'Matrícula', widget.mesSelecionado.matricula)),
                    pw.Expanded(
                        flex: 2,
                        child: campo('Mês / Ano',
                            '${widget.mesSelecionado.mes}/${widget.mesSelecionado.ano}')),
                    pw.Expanded(
                        flex: 4,
                        child: campo(
                            'Folha',
                            contracheque.Folha.isNotEmpty
                                ? contracheque.Folha
                                : widget.mesSelecionado.folha)),
                  ],
                ),
                pw.SizedBox(height: 12),
                pw.Container(height: 0.6, color: fio),
                pw.SizedBox(height: 12),
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(
                        flex: 5,
                        child: campo('Unidade organizacional',
                            contracheque.UnidadeOrganizacional)),
                    pw.Expanded(
                        flex: 4,
                        child: campo('Relação de trabalho',
                            widget.mesSelecionado.relacaoTrabalho)),
                  ],
                ),
              ],
            ),
          ),
        );

    // ── Tabela de rubricas ────────────────────────────────────────────
    pw.Widget celulaCabecalho(String texto, pw.TextAlign alinha) => pw.Padding(
          padding: const pw.EdgeInsets.fromLTRB(12, 9, 12, 9),
          child: pw.Text(texto.toUpperCase(),
              textAlign: alinha,
              style: pw.TextStyle(
                fontSize: 7,
                color: PdfColors.white,
                fontWeight: pw.FontWeight.bold,
                letterSpacing: 1.3,
              )),
        );

    pw.Widget tabela() => pw.Table(
          columnWidths: const {
            0: pw.FixedColumnWidth(54),
            1: pw.FlexColumnWidth(),
            2: pw.FixedColumnWidth(112),
          },
          children: [
            pw.TableRow(
              repeat: true,
              decoration: pw.BoxDecoration(
                gradient: pw.LinearGradient(
                  begin: pw.Alignment.centerLeft,
                  end: pw.Alignment.centerRight,
                  colors: [navy, navyClaro],
                ),
                borderRadius: const pw.BorderRadius.only(
                  topLeft: pw.Radius.circular(8),
                  topRight: pw.Radius.circular(8),
                ),
              ),
              children: [
                celulaCabecalho('Tipo', pw.TextAlign.center),
                celulaCabecalho('Descrição da rubrica', pw.TextAlign.left),
                celulaCabecalho('Valor', pw.TextAlign.right),
              ],
            ),
            ...contracheque.proventos.asMap().entries.map((e) {
              final item = e.value;
              final ehProvento = item.tipoRubrica == 'P';
              final cor = ehProvento ? verde : vermelho;
              final valor = ehProvento ? item.provento : item.desconto;

              return pw.TableRow(
                decoration: pw.BoxDecoration(
                  color: e.key.isEven ? papel : faixaPar,
                  border: pw.Border(bottom: pw.BorderSide(color: fio, width: 0.4)),
                ),
                children: [
                  // Etiqueta em cor sólida a 12%: identifica sem gritar, e
                  // continua legível impressa em preto e branco.
                  pw.Padding(
                    padding:
                        pw.EdgeInsets.symmetric(horizontal: 12, vertical: linhaVPad),
                    child: pw.Center(
                      child: pw.Container(
                        decoration: pw.BoxDecoration(
                          color: mistura(papel, cor, 0.15),
                          borderRadius:
                              const pw.BorderRadius.all(pw.Radius.circular(3)),
                        ),
                        padding: const pw.EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2.5),
                        child: pw.Text(item.tipoRubrica,
                            style: pw.TextStyle(
                                fontSize: 7,
                                color: cor,
                                fontWeight: pw.FontWeight.bold,
                                letterSpacing: 0.5)),
                      ),
                    ),
                  ),
                  pw.Padding(
                    padding:
                        pw.EdgeInsets.symmetric(horizontal: 12, vertical: linhaVPad),
                    child: pw.Text(item.descricaoRubrica,
                        style: pw.TextStyle(
                            fontSize: linhaFonte, color: tintaFraca)),
                  ),
                  pw.Padding(
                    padding:
                        pw.EdgeInsets.symmetric(horizontal: 12, vertical: linhaVPad),
                    child: pw.Text('R\$ $valor',
                        textAlign: pw.TextAlign.right,
                        style: pw.TextStyle(
                            fontSize: linhaFonte,
                            color: cor,
                            fontWeight: pw.FontWeight.bold)),
                  ),
                ],
              );
            }),
          ],
        );

    // ── Totais ────────────────────────────────────────────────────────
    // O líquido é o único herói da página: fica num cartão interno, sobre
    // o degradê, com o dobro do corpo dos outros dois.
    pw.Widget totais() => pw.Container(
          decoration: pw.BoxDecoration(
            gradient: pw.LinearGradient(
              begin: pw.Alignment.centerLeft,
              end: pw.Alignment.centerRight,
              colors: [navyFundo, navy, navyClaro],
              stops: const [0.0, 0.5, 1.0],
            ),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(12)),
          ),
          padding: const pw.EdgeInsets.all(6),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.SizedBox(width: 16),
              totalSecundario('Proventos', dinheiro(proventos, _realSettings),
                  verdeClaro),
              pw.Container(
                  width: 0.8,
                  height: 36,
                  color: mistura(navy, PdfColors.white, 0.22)),
              pw.SizedBox(width: 16),
              totalSecundario('Descontos', dinheiro(descontos, _realSettings),
                  vermelhoClaro),
              pw.Container(
                decoration: pw.BoxDecoration(
                  color: mistura(navy, PdfColors.white, 0.13),
                  borderRadius:
                      const pw.BorderRadius.all(pw.Radius.circular(8)),
                ),
                padding:
                    const pw.EdgeInsets.fromLTRB(20, 12, 20, 13),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    sobrescrito('Líquido a receber', cor: ouro, tam: 6.5),
                    pw.SizedBox(height: 5),
                    pw.Text(
                        'R\$ ${dinheiro(totalLiquido, _realSettings)}',
                        style: pw.TextStyle(
                            fontSize: 19,
                            color: PdfColors.white,
                            fontWeight: pw.FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
        );

    // ── Rodapé ────────────────────────────────────────────────────────
    pw.Widget rodape(pw.Context ctx) => pw.Padding(
          padding: const pw.EdgeInsets.fromLTRB(0, 8, 0, 0),
          child: pw.Column(
            children: [
              pw.Container(height: 0.6, color: fio),
              pw.SizedBox(height: 8),
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                            'Documento gerado pelo aplicativo SouPMRR em $emitidoEm.',
                            style:
                                pw.TextStyle(fontSize: 6.8, color: tintaFraca)),
                        pw.SizedBox(height: 2),
                        pw.Text(
                            'Demonstrativo para visualização. Não substitui o documento oficial emitido pela administração.',
                            style: pw.TextStyle(
                                fontSize: 6.8,
                                color: rotulo,
                                fontStyle: pw.FontStyle.italic)),
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 16),
                  pw.Text('Página ${ctx.pageNumber} de ${ctx.pagesCount}',
                      style: pw.TextStyle(
                          fontSize: 7,
                          color: tintaFraca,
                          fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(width: 14),
                  pw.SizedBox(
                      height: 24,
                      width: 62,
                      child: pw.Image(dti, fit: pw.BoxFit.contain)),
                ],
              ),
            ],
          ),
        );

    pdf.addPage(pw.MultiPage(
      pageTheme: pw.PageTheme(
        pageFormat: PdfPageFormat.a4,
        // A calha lateral vem da margem da página, não de um Padding em volta
        // da tabela. No dart_pdf só widgets SpanningWidget (Table, Column) se
        // dividem entre páginas; qualquer embrulho trava a quebra e o
        // MultiPage estoura em TooManyPagesException.
        margin: const pw.EdgeInsets.fromLTRB(28, 22, 28, 16),
        theme: pw.ThemeData.withFont(base: fonteBase, bold: fonteForte),
        // Fundo da página: papel levemente frio e o brasão em marca d'água.
        buildBackground: (ctx) => pw.FullPage(
          ignoreMargins: true,
          child: pw.Stack(
            children: [
              pw.Positioned.fill(child: pw.Container(color: papelFundo)),
              pw.Positioned(
                right: -70,
                bottom: 110,
                child: pw.Opacity(
                  opacity: 0.04,
                  child: pw.SizedBox(
                      width: 330,
                      height: 330,
                      child: pw.Image(brasao, fit: pw.BoxFit.contain)),
                ),
              ),
            ],
          ),
        ),
      ),
      header: cabecalho,
      footer: rodape,
      // Filhos diretos, sem embrulho: é o que permite a tabela quebrar.
      build: (ctx) => [
        identificacao(),
        pw.SizedBox(height: 18),
        sobrescrito('Composição do pagamento', tam: 7),
        pw.SizedBox(height: 7),
        tabela(),
        pw.SizedBox(height: 16),
        totais(),
      ],
    ));

    final output = await getTemporaryDirectory();
    final file = File('${output.path}/$_nomeArquivo.pdf');
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  /// Nome do arquivo que chega a quem recebe. "contracheque.pdf" não diz de
  /// qual mês é, e quem guarda vários acaba com um sobrescrevendo o outro.
  String get _nomeArquivo {
    final mes = widget.mesSelecionado.mes.padLeft(2, '0');
    return 'contracheque_${widget.mesSelecionado.ano}-$mes';
  }

  // Origem do popover exigida pelo iOS/iPad (UIActivityViewController).
  // No Android o parâmetro é ignorado, então é seguro sempre enviar.
  Rect? _sharePositionOrigin() {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  // ── Compartilhar ──────────────────────────────────────────────────────
  //
  // A sequência é sempre: gerar o arquivo primeiro, com o botão mostrando que
  // está gerando, e só então abrir a folha de compartilhamento do sistema.
  //
  // Cancelar a folha não desfaz nem recarrega nada: o arquivo continua
  // guardado e a próxima tentativa abre na hora. O usuário também não fica
  // olhando para uma folha vazia enquanto o PDF ainda está sendo montado.

  /// Gera o PDF, ou devolve o que já foi gerado para este mês.
  Future<File> _arquivoPdf(Auth auth) async {
    final pronto = _pdfPronto;
    if (pronto != null && await pronto.exists()) return pronto;
    final file = await _generatePdf(auth);
    _pdfPronto = file;
    return file;
  }

  /// Rasteriza o PDF inteiro. É a operação mais cara do fluxo, e os dois
  /// formatos dependem dela — o PNG é o próprio raster e a prévia mostra
  /// esse mesmo desenho. Por isso roda uma vez e fica guardada.
  ///
  /// Quando o contracheque passa de uma página, as páginas são empilhadas
  /// numa imagem só. Antes a rasterização pedia `pages: [0]`, o que estava
  /// certo enquanto o PDF cabia sempre numa página — depois que ele passou a
  /// paginar, isso faria a imagem perder rubricas sem avisar ninguém.
  Future<Uint8List> _rasterizar(Auth auth) async {
    final pronta = _paginaRasterizada;
    if (pronta != null) return pronta;

    final pdfBytes = await (await _arquivoPdf(auth)).readAsBytes();
    final paginas = await Printing.raster(pdfBytes, dpi: 180).toList();
    if (paginas.isEmpty) {
      throw Exception('O PDF não produziu nenhuma página para rasterizar.');
    }

    final bytes = paginas.length == 1
        ? await paginas.first.toPng()
        : await _empilhar(paginas).toPng();
    _paginaRasterizada = bytes;
    return bytes;
  }

  /// Junta as páginas numa única imagem, uma embaixo da outra.
  ///
  /// Todas saem do mesmo formato A4 e do mesmo dpi, então têm a mesma
  /// largura e basta concatenar os buffers RGBA na ordem. Uma faixa clara
  /// separa uma página da outra, para quem recebe perceber a divisão.
  PdfRasterBase _empilhar(List<PdfRaster> paginas) {
    const vao = 24; // linhas de separação entre páginas
    final largura = paginas.first.width;
    final altura = paginas.fold<int>(0, (soma, p) => soma + p.height) +
        vao * (paginas.length - 1);

    final combinado = Uint8List(largura * altura * 4);
    // Fundo da separação: o mesmo tom de papel usado no PDF (#F7F9FC).
    for (var i = 0; i < combinado.length; i += 4) {
      combinado[i] = 0xF7;
      combinado[i + 1] = 0xF9;
      combinado[i + 2] = 0xFC;
      combinado[i + 3] = 0xFF;
    }

    var linha = 0;
    for (final pagina in paginas) {
      combinado.setRange(
        linha * largura * 4,
        (linha + pagina.height) * largura * 4,
        pagina.pixels,
      );
      linha += pagina.height + vao;
    }

    return PdfRasterBase(largura, altura, true, combinado);
  }

  Future<File> _arquivoImagem(Auth auth) async {
    final pronta = _imagemPronta;
    if (pronta != null && await pronta.exists()) return pronta;

    final dir = await getTemporaryDirectory();
    final imgFile = File('${dir.path}/$_nomeArquivo.png');
    await imgFile.writeAsBytes(await _rasterizar(auth));
    _imagemPronta = imgFile;
    return imgFile;
  }

  /// Tamanho em KB decimal (1 KB = 1000 B), que é como o iOS e o Android
  /// mostram na folha de compartilhamento. Usar KB binário aqui faria a
  /// prévia dizer 194 KB e a folha do sistema dizer 199 KB para o mesmo
  /// arquivo, logo em seguida.
  static String _tamanhoLegivel(int bytes) {
    if (bytes < 1000) return '$bytes B';
    if (bytes < 1000000) return '${(bytes / 1000).round()} KB';
    return '${(bytes / 1000000).toStringAsFixed(1)} MB';
  }

  /// Mostra o que será enviado antes de abrir a folha do sistema.
  ///
  /// O PDF é uma renderização própria, diferente da tela: cabeçalho, logos e
  /// layout que o militar nunca viu. Como ele costuma mandar isso para banco,
  /// locador ou RH, e mensagem enviada não volta, vale conferir antes. A
  /// prévia mostra exatamente a página que vai no arquivo.
  Future<bool> _confirmarEnvio({
    required bool comoPdf,
    required Uint8List pagina,
    required int tamanhoBytes,
  }) async {
    final theme = Theme.of(context);
    final confirmado = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final altura = MediaQuery.of(ctx).size.height;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Confira antes de enviar',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  '${comoPdf ? "PDF" : "Imagem PNG"} · '
                  '${_tamanhoLegivel(tamanhoBytes)} · '
                  '${widget.mesSelecionado.mesExtenso}/${widget.mesSelecionado.ano}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                  ),
                ),
                const SizedBox(height: 14),

                // A página inteira, com zoom. Rubrica pequena num celular
                // pequeno fica ilegível sem isso, e conferir é o objetivo.
                Flexible(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: altura * 0.56),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        color: Colors.white,
                        child: InteractiveViewer(
                          maxScale: 4,
                          child: Image.memory(pagina, fit: BoxFit.contain),
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(ctx).pop(false),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Cancelar'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => Navigator.of(ctx).pop(true),
                        icon: const Icon(Icons.ios_share_rounded, size: 18),
                        label: const Text('Compartilhar'),
                        style: FilledButton.styleFrom(
                          foregroundColor:
                              ThemeData.estimateBrightnessForColor(
                                          theme.colorScheme.primary) ==
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
      },
    );
    return confirmado ?? false;
  }

  Future<void> _compartilhar(Auth auth, {required bool comoPdf}) async {
    if (_sharingPdf || _sharingImage) return;
    setState(() {
      if (comoPdf) {
        _sharingPdf = true;
      } else {
        _sharingImage = true;
      }
    });

    try {
      // Gera o arquivo e a prévia. A rasterização é compartilhada, então o
      // segundo formato não paga esse custo de novo.
      final arquivo =
          comoPdf ? await _arquivoPdf(auth) : await _arquivoImagem(auth);
      final pagina = await _rasterizar(auth);
      final tamanho = await arquivo.length();

      // A tela pode ter sido fechada enquanto o arquivo era gerado.
      if (!mounted) return;

      // O estado de "gerando" acaba aqui: o que vem a seguir já é visível.
      setState(() {
        _sharingPdf = false;
        _sharingImage = false;
      });

      final enviar = await _confirmarEnvio(
        comoPdf: comoPdf,
        pagina: pagina,
        tamanhoBytes: tamanho,
      );
      if (!enviar || !mounted) return;

      await Share.shareXFiles(
        [XFile(arquivo.path)],
        subject:
            'Contracheque ${widget.mesSelecionado.mesExtenso}/${widget.mesSelecionado.ano}',
        sharePositionOrigin: _sharePositionOrigin(),
      );
      // O resultado é deliberadamente ignorado: o Android não informa de forma
      // confiável se o envio aconteceu, e exibir "enviado!" com base nisso
      // mentiria para metade dos usuários.
    } catch (e) {
      debugPrint('[CONTRACHEQUE] erro ao compartilhar '
          '${comoPdf ? "PDF" : "imagem"}: $e');
      if (!mounted) return;
      alertaErro(
        context,
        titulo: 'Erro',
        texto: comoPdf
            ? 'Não foi possível gerar o PDF do contracheque.'
            : 'Não foi possível gerar a imagem do contracheque.',
        confirmar: 'OK',
      );
    } finally {
      if (mounted && (_sharingPdf || _sharingImage)) {
        setState(() {
          _sharingPdf = false;
          _sharingImage = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<Auth>(context, listen: false);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return FutureBuilder<ContrachequeModel>(
      future: _dados,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body:
                Center(child: CircularProgressIndicator(color: AppColors.blue)),
          );
        }
        if (snapshot.hasError) return SecondScreen();
        if (!snapshot.hasData) return SecondScreen();

        return FundoSuave(child: Scaffold(
          backgroundColor: Colors.transparent,
          // fundo global (FundoSuave) aparece por baixo
          // ── AppBar — mesma cor que CustomAppBar ──────────────────
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            centerTitle: true,
            iconTheme: const IconThemeData(color: Colors.white),
            flexibleSpace: const FundoBarraVidro(),
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
        ));
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
      alpha:
          isDark ? (index.isEven ? 0.10 : 0.07) : (index.isEven ? 0.07 : 0.04),
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
    // Sem superfície própria: os botões ficam direto sobre o fundo da tela.
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: (_sharingImage || _sharingPdf)
                        ? null
                        : () => _compartilhar(auth, comoPdf: false),
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
                        : () => _compartilhar(auth, comoPdf: true),
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
