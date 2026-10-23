// ignore_for_file: must_be_immutable
import 'dart:convert';
import 'dart:io';
import 'dart:ui' show ImageFilter;
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
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

import '../core/erros/falha_app.dart';
import '../core/log/registro_log.dart';
import '../core/rede/api_client.dart';
import '../features/contracheque/contracheque_pdf_repositorio.dart';
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

  // Valores à mostra ou escondidos. Começa visível: quem abriu o
  // contracheque veio justamente para ver os números.
  bool _valoresVisiveis = true;

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
              sobrescrito(etiqueta, tam: 6.5),
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
    // Bloco claro, não uma tarja azul. A primeira versão repetia aqui o
    // degradê escuro do cabeçalho e ficava pesada: num documento oficial o
    // azul forte marca a identidade no topo, não grita no meio da página. A
    // hierarquia vem do corpo do número e do contraste, não da saturação.
    //
    // O líquido segue sendo o único herói: cartão interno, dobro do corpo.
    pw.Widget totais() => pw.Container(
          decoration: pw.BoxDecoration(
            color: mistura(papel, navy, 0.04),
            border: pw.Border.all(color: fio, width: 0.6),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(12)),
          ),
          padding: const pw.EdgeInsets.all(6),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.SizedBox(width: 16),
              totalSecundario(
                  'Proventos', dinheiro(proventos, _realSettings), verde),
              pw.Container(width: 0.8, height: 34, color: fio),
              pw.SizedBox(width: 16),
              totalSecundario(
                  'Descontos', dinheiro(descontos, _realSettings), vermelho),
              pw.Container(
                decoration: pw.BoxDecoration(
                  color: papel,
                  border: pw.Border.all(
                      color: mistura(papel, navy, 0.18), width: 0.7),
                  borderRadius:
                      const pw.BorderRadius.all(pw.Radius.circular(8)),
                ),
                padding:
                    const pw.EdgeInsets.fromLTRB(20, 12, 20, 13),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    sobrescrito('Líquido a receber',
                        cor: mistura(papel, navy, 0.62), tam: 6.5),
                    pw.SizedBox(height: 5),
                    pw.Text(
                        'R\$ ${dinheiro(totalLiquido, _realSettings)}',
                        style: pw.TextStyle(
                            fontSize: 19,
                            color: navy,
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

  /// O PDF do mês: pronto da API (2.2, §12.3) ou, enquanto ela não emite
  /// (`contracheque.pdf_api` desligado no painel), o montado no aparelho.
  Future<File> _arquivoPdf(Auth auth) async {
    final pronto = _pdfPronto;
    if (pronto != null && await pronto.exists()) return pronto;
    final daApi = await ContrachequePdfRepositorio(
      api: ApiClient(),
      matricula: auth.matricula ?? '',
      senhaMd5: md5.convert(utf8.encode(auth.password ?? '')).toString(),
    ).pedir(widget.mesSelecionado, pasta: await getTemporaryDirectory());
    final file = daApi ?? await _generatePdf(auth);
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

  /// Mostra o que será enviado e deixa escolher o formato ali mesmo.
  ///
  /// O PDF é uma renderização própria, diferente da tela: cabeçalho, brasão e
  /// layout de documento que o militar nunca viu. Como ele costuma mandar
  /// isso para banco, locador ou RH, e mensagem enviada não volta, vale
  /// conferir antes.
  ///
  /// Escolher PDF ou imagem aqui, e não antes, é o que permite um botão só na
  /// tela: decidir o formato sem ver o documento era pedir uma escolha no
  /// escuro. Como os dois arquivos já estão prontos neste ponto, qualquer um
  /// dos dois envia na hora.
  Future<_FormatoEnvio?> _escolherEnvio({
    required Uint8List pagina,
    required int bytesPdf,
    required int bytesImagem,
  }) {
    final theme = Theme.of(context);
    final apagado = theme.colorScheme.onSurface.withValues(alpha: 0.6);

    // As duas opções têm o mesmo peso visual: o ícone é que identifica o
    // formato, e nenhuma das duas deve ser empurrada para o militar.
    Widget opcao({
      required Widget icone,
      required String titulo,
      required String detalhe,
      required VoidCallback aoTocar,
    }) =>
        Expanded(
          child: Material(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: aoTocar,
              borderRadius: BorderRadius.circular(12),
              child: Ink(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color:
                          theme.colorScheme.onSurface.withValues(alpha: 0.10)),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 13, 12, 12),
                  child: Row(
                    children: [
                      icone,
                      const SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(titulo,
                                style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w600,
                                    color: theme.colorScheme.onSurface)),
                            const SizedBox(height: 1),
                            Text(detalhe,
                                style:
                                    TextStyle(fontSize: 11, color: apagado)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );

    return showModalBottomSheet<_FormatoEnvio>(
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
                Text('Confira antes de enviar',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(
                  'Contracheque de ${widget.mesSelecionado.mesExtenso}/${widget.mesSelecionado.ano}',
                  style: theme.textTheme.bodySmall?.copyWith(color: apagado),
                ),
                const SizedBox(height: 14),

                // A página inteira, com zoom. Rubrica pequena num celular
                // pequeno fica ilegível sem isso, e conferir é o objetivo.
                Flexible(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: altura * 0.52),
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
                    opcao(
                      icone: const _IconePdf(altura: 30),
                      titulo: 'PDF',
                      detalhe: _tamanhoLegivel(bytesPdf),
                      aoTocar: () => Navigator.of(ctx).pop(_FormatoEnvio.pdf),
                    ),
                    const SizedBox(width: 10),
                    opcao(
                      icone: const _IconeImagem(altura: 30),
                      titulo: 'Imagem',
                      detalhe: _tamanhoLegivel(bytesImagem),
                      aoTocar: () =>
                          Navigator.of(ctx).pop(_FormatoEnvio.imagem),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancelar'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _compartilhar(Auth auth) async {
    if (_sharingPdf || _sharingImage) return;
    setState(() => _sharingPdf = true);

    try {
      // Os dois arquivos saem da mesma geração: o PDF e, dele, a
      // rasterização que serve à prévia e ao PNG. Fazer os dois agora é o
      // que deixa a escolha na prévia ser instantânea.
      final arquivoPdf = await _arquivoPdf(auth);
      final pagina = await _rasterizar(auth);
      final arquivoImagem = await _arquivoImagem(auth);

      // A tela pode ter sido fechada enquanto o arquivo era gerado.
      if (!mounted) return;
      setState(() {
        _sharingPdf = false;
        _sharingImage = false;
      });

      final escolha = await _escolherEnvio(
        pagina: pagina,
        bytesPdf: await arquivoPdf.length(),
        bytesImagem: await arquivoImagem.length(),
      );
      if (escolha == null || !mounted) return;

      final arquivo =
          escolha == _FormatoEnvio.pdf ? arquivoPdf : arquivoImagem;
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
      debugPrint('[CONTRACHEQUE] erro ao compartilhar: $e');
      final falha = e is FalhaApp ? e : FalhaApp.inesperada('CC', e);
      registrarErro(falha, tela: 'rh.contracheques');
      if (!mounted) return;
      alertaErro(
        context,
        titulo: falha.titulo,
        texto: '${falha.texto}\n\n${falha.deQuem} · Código ${falha.codigo}',
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

        final proventosLista = contracheque.proventos
            .where((r) => r.tipoRubrica == 'P')
            .toList();
        final descontosLista = contracheque.proventos
            .where((r) => r.tipoRubrica != 'P')
            .toList();

        return FundoSuave(
          child: Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              centerTitle: true,
              iconTheme: const IconThemeData(color: Colors.white),
              flexibleSpace: const FundoBarraVidro(),
              title: const Text(
                'Contracheque',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.4),
              ),
              actions: [
                // Esconder os valores aqui serve para o militar abrir o
                // contracheque ao lado de outra pessoa. O mesmo gesto já
                // existe no cartão da tela inicial.
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: _BotaoOlho(
                    visivel: _valoresVisiveis,
                    aoTocar: () =>
                        setState(() => _valoresVisiveis = !_valoresVisiveis),
                  ),
                ),
              ],
            ),
            floatingActionButton: _botaoCompartilhar(auth),
            body: ListView(
              // A folga embaixo precisa cobrir o botão flutuante inteiro —
              // área segura, afastamento e altura dele — senão a última linha
              // fica encoberta no fim da rolagem.
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 132),
              children: [
                _tituloCompetencia(theme),
                const SizedBox(height: 18),
                _cartaoServidor(auth, theme),
                const SizedBox(height: 14),
                _cartaoLiquido(theme),
                const SizedBox(height: 22),
                if (proventosLista.isNotEmpty) ...[
                  _tituloSecao(theme,
                      rotulo: 'Proventos',
                      cor: _verde,
                      quantidade: proventosLista.length),
                  const SizedBox(height: 10),
                  _blocoRubricas(theme, proventosLista, _verde),
                  const SizedBox(height: 22),
                ],
                if (descontosLista.isNotEmpty) ...[
                  _tituloSecao(theme,
                      rotulo: 'Descontos',
                      cor: _vermelho,
                      quantidade: descontosLista.length),
                  const SizedBox(height: 10),
                  _blocoRubricas(theme, descontosLista, _vermelho),
                ],
                const SizedBox(height: 18),
                _rodapeAviso(theme),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Paleta da tela ────────────────────────────────────────────────────
  // Tons contidos, não os primários saturados: é a leitura de um documento
  // oficial, não um painel. O verde e o vermelho marcam a natureza da
  // rubrica, mas quem informa de fato são o rótulo da seção e o sinal do
  // valor — cor sozinha não carrega significado.
  static const _verde = Color(0xFF34D399);
  static const _vermelho = Color(0xFFF87171);

  Color _superficie(ThemeData theme) => theme.brightness == Brightness.dark
      ? Colors.white.withValues(alpha: 0.04)
      : AppColors.navy.withValues(alpha: 0.04);

  Color _contorno(ThemeData theme) => theme.brightness == Brightness.dark
      ? Colors.white.withValues(alpha: 0.08)
      : AppColors.navy.withValues(alpha: 0.10);

  Color _apagado(ThemeData theme) =>
      theme.colorScheme.onSurface.withValues(alpha: 0.55);

  String get _oculto => '••••••';

  // ── Competência ───────────────────────────────────────────────────────
  Widget _tituloCompetencia(ThemeData theme) {
    final mes = widget.mesSelecionado.mesExtenso;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            style: theme.textTheme.headlineSmall?.copyWith(
              fontSize: 23,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
              letterSpacing: -0.3,
            ),
            children: [
              TextSpan(text: '$mes '),
              TextSpan(
                text: widget.mesSelecionado.ano,
                style: TextStyle(
                    fontWeight: FontWeight.w400, color: _apagado(theme)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 3),
        Text('Demonstrativo de pagamento',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: _apagado(theme), fontSize: 11.5)),
      ],
    );
  }

  // ── Cartão do servidor ────────────────────────────────────────────────
  Widget _cartaoServidor(Auth auth, ThemeData theme) {
    Widget par(String etiqueta, String valor) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(etiqueta,
                style: TextStyle(
                    fontSize: 10.5,
                    color: _apagado(theme),
                    fontWeight: FontWeight.w400)),
            const SizedBox(height: 2),
            Text(valor.isEmpty ? 'Não informado' : valor,
                style: TextStyle(
                  fontSize: 12.5,
                  color: valor.isEmpty
                      ? _apagado(theme)
                      : theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w500,
                )),
          ],
        );

    return Container(
      decoration: BoxDecoration(
        color: _superficie(theme),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _contorno(theme)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.blue.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(Icons.person_outline_rounded,
                    size: 21, color: AppColors.lightBlue),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('SERVIDOR',
                        style: TextStyle(
                            fontSize: 9,
                            letterSpacing: 1.2,
                            fontWeight: FontWeight.w600,
                            color: _apagado(theme))),
                    const SizedBox(height: 3),
                    Text(auth.nomeCompleto ?? '—',
                        style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Divider(height: 1, thickness: 1, color: _contorno(theme)),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                  child: par('Matrícula', widget.mesSelecionado.matricula)),
              Expanded(
                  child: par('Lotação',
                      contracheque.UnidadeOrganizacional.isNotEmpty
                          ? contracheque.UnidadeOrganizacional
                          : widget.mesSelecionado.relacaoTrabalho)),
            ],
          ),
          const SizedBox(height: 13),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                  child: par('Competência',
                      '${widget.mesSelecionado.mesExtenso} / ${widget.mesSelecionado.ano}')),
              Expanded(
                  child: par(
                      'Tipo de folha',
                      contracheque.Folha.isNotEmpty
                          ? contracheque.Folha
                          : widget.mesSelecionado.folha)),
            ],
          ),
        ],
      ),
    );
  }

  // ── Cartão do valor líquido ───────────────────────────────────────────
  Widget _cartaoLiquido(ThemeData theme) {
    final escuro = theme.brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: escuro
              ? [
                  AppColors.blue.withValues(alpha: 0.26),
                  AppColors.navy.withValues(alpha: 0.22),
                ]
              : [
                  AppColors.blue.withValues(alpha: 0.12),
                  AppColors.navy.withValues(alpha: 0.07),
                ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.blue.withValues(alpha: 0.22)),
      ),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Valor líquido',
              style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.75))),
          const SizedBox(height: 8),
          _valorGrande(theme),
          const SizedBox(height: 14),
          Divider(
              height: 1,
              thickness: 1,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.10)),
          const SizedBox(height: 13),
          Row(
            children: [
              Expanded(
                  child: _resumoColuna(
                      theme, 'Proventos', proventos, _verde)),
              Container(
                  width: 1,
                  height: 32,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.10)),
              const SizedBox(width: 16),
              Expanded(
                  child: _resumoColuna(
                      theme, 'Descontos', descontos, _vermelho)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _valorGrande(ThemeData theme) {
    if (!_valoresVisiveis) {
      return Text(_oculto,
          style: TextStyle(
              fontSize: 29,
              height: 1.0,
              letterSpacing: 2,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.45)));
    }
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: 'R\$ ',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.72)),
          ),
          TextSpan(
            text: CurrencyFormatter.format(totalLiquido, _realSettings),
            style: TextStyle(
                fontSize: 29,
                height: 1.0,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.6,
                color: theme.colorScheme.onSurface),
          ),
        ],
      ),
    );
  }

  Widget _resumoColuna(
      ThemeData theme, String etiqueta, double valor, Color cor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(etiqueta,
            style: TextStyle(fontSize: 11.5, color: _apagado(theme))),
        const SizedBox(height: 3),
        Text(
          _valoresVisiveis
              ? 'R\$ ${CurrencyFormatter.format(valor, _realSettings)}'
              : _oculto,
          style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: _valoresVisiveis
                  ? cor
                  : theme.colorScheme.onSurface.withValues(alpha: 0.45)),
        ),
      ],
    );
  }

  // ── Cabeçalho de seção ────────────────────────────────────────────────
  Widget _tituloSecao(ThemeData theme,
      {required String rotulo, required Color cor, required int quantidade}) {
    return Row(
      children: [
        Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: cor, shape: BoxShape.circle)),
        const SizedBox(width: 9),
        Text(rotulo,
            style: TextStyle(
                fontSize: 13.5, fontWeight: FontWeight.w600, color: cor)),
        const Spacer(),
        Text(
            '$quantidade ${quantidade == 1 ? "lançamento" : "lançamentos"}',
            style: TextStyle(fontSize: 11.5, color: _apagado(theme))),
      ],
    );
  }

  // ── Bloco de rubricas ─────────────────────────────────────────────────
  Widget _blocoRubricas(
      ThemeData theme, List<TipoProvento> itens, Color cor) {
    return Container(
      decoration: BoxDecoration(
        color: cor.withValues(alpha: theme.brightness == Brightness.dark
            ? 0.055
            : 0.045),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cor.withValues(alpha: 0.18)),
      ),
      child: Column(
        children: [
          for (var i = 0; i < itens.length; i++) ...[
            if (i > 0)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Divider(
                    height: 1,
                    thickness: 1,
                    color: cor.withValues(alpha: 0.14)),
              ),
            _linhaRubrica(theme, itens[i], cor),
          ],
        ],
      ),
    );
  }

  Widget _linhaRubrica(ThemeData theme, TipoProvento item, Color cor) {
    final partes = _partesRubrica(item.descricaoRubrica);
    final bruto = item.tipoRubrica == 'P' ? item.provento : item.desconto;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(partes.$1,
                    style: TextStyle(
                        fontSize: 13,
                        height: 1.3,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.15,
                        color: theme.colorScheme.onSurface)),
                if (partes.$2 != null) ...[
                  const SizedBox(height: 2),
                  Text(partes.$2!,
                      style:
                          TextStyle(fontSize: 10.5, color: _apagado(theme))),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            _valoresVisiveis ? 'R\$ $bruto' : _oculto,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _valoresVisiveis
                    ? cor
                    : theme.colorScheme.onSurface.withValues(alpha: 0.45)),
          ),
        ],
      ),
    );
  }

  /// Separa o código entre parênteses do nome da rubrica.
  ///
  /// "SUBSIDIO EFETIVO (MIG: 0002)" vira ("SUBSIDIO EFETIVO", "MIG · 0002").
  /// O nome continua exatamente como vem do SIGRH: traduzi-lo para algo mais
  /// amigável exigiria um dicionário de rubricas validado pela corporação, e
  /// inventar nome em contracheque é pior que mostrar a sigla.
  (String, String?) _partesRubrica(String bruto) {
    final texto = bruto.trim();
    final m = RegExp(r'^(.*?)\s*\(([^)]*)\)\s*$').firstMatch(texto);
    if (m == null) return (texto, null);
    final detalhe = m
        .group(2)!
        .replaceAll(':', ' ·')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final nome = m.group(1)!.trim();
    if (nome.isEmpty) return (texto, null);
    return (nome, detalhe.isEmpty ? null : detalhe);
  }

  // ── Compartilhar ──────────────────────────────────────────────────────
  // Botão flutuante no canto inferior direito: fica ao alcance do polegar e
  // não rouba uma faixa fixa da tela, que numa lista longa de rubricas faz
  // falta. O formato — PDF ou imagem — é escolhido na prévia, depois de o
  // militar ver o documento.
  Widget _botaoCompartilhar(Auth auth) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaria = theme.colorScheme.primary;
    final ocupado = _sharingPdf || _sharingImage;

    // Mesma receita da pílula do item ativo no menu inferior
    // (barra_navegacao.dart): primária a 22% com borda a 35%, raio 18 e o
    // mesmo desfoque de fundo. Assim o botão pertence ao app em vez de
    // parecer um elemento colado por cima.
    final conteudo = Container(
      decoration: BoxDecoration(
        color: primaria.withValues(alpha: isDark ? 0.22 : 0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: primaria.withValues(alpha: isDark ? 0.35 : 0.22),
          width: 0.8,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: ocupado ? null : () => _compartilhar(auth),
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 13, 20, 13),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ocupado
                    ? SizedBox(
                        width: 17,
                        height: 17,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: primaria),
                      )
                    : Icon(Icons.ios_share_rounded, size: 18, color: primaria),
                const SizedBox(width: 9),
                Text(
                  ocupado ? 'Gerando…' : 'Compartilhar',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.1,
                    color: primaria,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    return Semantics(
      button: true,
      label: 'Compartilhar contracheque',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        // Vidro só no iOS, como na barra de navegação: no Android o desfoque
        // de fundo custa caro e a superfície do Material já resolve.
        child: Platform.isAndroid
            ? conteudo
            : BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
                child: conteudo,
              ),
      ),
    );
  }

  Widget _rodapeAviso(ThemeData theme) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Text(
          'Demonstrativo para visualização. Não substitui o documento oficial.',
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: 10.5, height: 1.45, color: _apagado(theme)),
        ),
      );
}

/// Botão de olho da barra superior, com o contorno discreto do mockup.
class _BotaoOlho extends StatelessWidget {
  const _BotaoOlho({required this.visivel, required this.aoTocar});

  final bool visivel;
  final VoidCallback aoTocar;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: visivel ? 'Ocultar valores' : 'Mostrar valores',
      child: InkWell(
        onTap: aoTocar,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.blue.withValues(alpha: 0.16),
            border:
                Border.all(color: AppColors.lightBlue.withValues(alpha: 0.45)),
          ),
          child: Icon(
            visivel
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
            size: 19,
            color: AppColors.lightBlue,
          ),
        ),
      ),
    );
  }
}

/// Formato escolhido na prévia de compartilhamento.
enum _FormatoEnvio { pdf, imagem }

/// Ícone de arquivo PDF: folha branca com o canto dobrado e a tarja vermelha,
/// como o sistema desenha num gerenciador de arquivos.
///
/// Um glifo monocromático de biblioteca não diz ao militar o que ele vai
/// receber; esta forma sim, porque é a mesma que ele já viu no celular.
class _IconePdf extends StatelessWidget {
  const _IconePdf({this.altura = 30});

  final double altura;

  @override
  Widget build(BuildContext context) {
    final largura = altura * 0.78;
    return SizedBox(
      width: largura,
      height: altura,
      child: Stack(
        children: [
          CustomPaint(
              size: Size(largura, altura), painter: const _PintorFolha()),
          Positioned(
            left: largura * 0.10,
            right: largura * 0.10,
            bottom: altura * 0.15,
            child: Container(
              height: altura * 0.29,
              decoration: BoxDecoration(
                color: const Color(0xFFD93F32),
                borderRadius: BorderRadius.circular(2),
              ),
              alignment: Alignment.center,
              child: FittedBox(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 1.5),
                  child: Text('PDF',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: altura * 0.26,
                        height: 1.0,
                        letterSpacing: 0.1,
                      )),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PintorFolha extends CustomPainter {
  const _PintorFolha();

  static const _papel = Color(0xFFFBFCFD);
  static const _borda = Color(0xFFB6C0CE);
  static const _dobra = Color(0xFFDCE3EC);

  @override
  void paint(Canvas canvas, Size size) {
    final d = size.width * 0.34; // tamanho do canto dobrado
    const r = 2.5;

    final folha = Path()
      ..moveTo(r, 0)
      ..lineTo(size.width - d, 0)
      ..lineTo(size.width, d)
      ..lineTo(size.width, size.height - r)
      ..quadraticBezierTo(
          size.width, size.height, size.width - r, size.height)
      ..lineTo(r, size.height)
      ..quadraticBezierTo(0, size.height, 0, size.height - r)
      ..lineTo(0, r)
      ..quadraticBezierTo(0, 0, r, 0)
      ..close();

    canvas.drawPath(folha, Paint()..color = _papel);
    canvas.drawPath(
        folha,
        Paint()
          ..color = _borda
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.9);

    final canto = Path()
      ..moveTo(size.width - d, 0)
      ..lineTo(size.width, d)
      ..lineTo(size.width - d, d)
      ..close();
    canvas.drawPath(canto, Paint()..color = _dobra);
    canvas.drawPath(
        canto,
        Paint()
          ..color = _borda
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.9);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Ícone de imagem: uma miniatura de foto — céu, sol e serra —, que é como
/// o sistema representa um arquivo de imagem.
class _IconeImagem extends StatelessWidget {
  const _IconeImagem({this.altura = 30});

  final double altura;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: altura * 0.94,
        height: altura,
        child: CustomPaint(
            size: Size(altura * 0.94, altura), painter: const _PintorFoto()),
      );
}

class _PintorFoto extends CustomPainter {
  const _PintorFoto();

  static const _borda = Color(0xFFB6C0CE);
  static const _ceuAlto = Color(0xFFBFE2F7);
  static const _ceuBaixo = Color(0xFFE9F4FB);
  static const _sol = Color(0xFFF5C451);
  static const _serraLonge = Color(0xFF7FB2A6);
  static const _serraPerto = Color(0xFF4E8C7E);

  @override
  void paint(Canvas canvas, Size size) {
    final moldura = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(3.5),
    );

    canvas.save();
    canvas.clipRRect(moldura);

    // Céu
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_ceuAlto, _ceuBaixo],
        ).createShader(Offset.zero & size),
    );

    // Sol
    canvas.drawCircle(
      Offset(size.width * 0.74, size.height * 0.27),
      size.width * 0.11,
      Paint()..color = _sol,
    );

    // Serra ao fundo
    final longe = Path()
      ..moveTo(0, size.height)
      ..lineTo(size.width * 0.30, size.height * 0.46)
      ..lineTo(size.width * 0.62, size.height)
      ..close();
    canvas.drawPath(longe, Paint()..color = _serraLonge);

    // Serra à frente
    final perto = Path()
      ..moveTo(size.width * 0.34, size.height)
      ..lineTo(size.width * 0.66, size.height * 0.56)
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(perto, Paint()..color = _serraPerto);

    canvas.restore();

    canvas.drawRRect(
        moldura,
        Paint()
          ..color = _borda
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.9);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
