import 'package:projetonovo/widgets/dialogo_confirmacao.dart';
// DeclaracaoBensPage
// Versão com melhorias visuais – mantém toda a lógica original.
//
// • Layout responsivo usando MediaQuery para dimensionar fontes.
// • Containers com cores suaves para destacar seções importantes.
// • Botões com estilo moderno (Material 3).
// • Pequenas animações de fade para a lista.
// • Nenhuma dependência extra além das já usadas.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:extenso/extenso.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;

import '../models/auth_model.dart';
import '../utils/app_theme.dart';
import '../widgets/barra_vidro.dart';
import '../widgets/alerta.dart';
import '../widgets/vidro.dart';
import '../core/erros/falha_de.dart';
import '../core/design/arte_cartao.dart';

class DeclaracaoBensPage extends StatefulWidget {
  final String ano;
  const DeclaracaoBensPage({Key? key, required this.ano}) : super(key: key);

  @override
  State<DeclaracaoBensPage> createState() => _DeclaracaoBensPageState();
}

class _DeclaracaoBensPageState extends State<DeclaracaoBensPage>
    with SingleTickerProviderStateMixin {
  //--------------------------------------------------------------------
  // ESTADO
  //--------------------------------------------------------------------
  String tipoBem = 'Imóvel'; // Imóvel | Móvel | Nenhum
  String formaAquisicao = 'À vista';

  final valorController = TextEditingController();
  final descricaoController = TextEditingController();
  final enderecoController = TextEditingController();
  final areaController = TextEditingController();
  final dataAquisicaoController = TextEditingController();
  final instituicaoController = TextEditingController();
  final parcelasController = TextEditingController();
  final gastosController = TextEditingController();
  final marcaModeloController = TextEditingController();
  final placaController = TextEditingController();

  String valorExtenso = '';
  List<Map<String, dynamic>> bensEnviados = [];

  bool jaDeclarouNaoPossui = false;
  Map<String, dynamic>? naoPossuiRegistro;

  late final AnimationController _fadeCtrl;

  //--------------------------------------------------------------------
  // CICLO DE VIDA
  //--------------------------------------------------------------------
  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _fetchBens();
    valorController.addListener(_updateValorExtenso);
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    valorController.removeListener(_updateValorExtenso);
    valorController.dispose();
    descricaoController.dispose();
    enderecoController.dispose();
    areaController.dispose();
    dataAquisicaoController.dispose();
    instituicaoController.dispose();
    parcelasController.dispose();
    gastosController.dispose();
    marcaModeloController.dispose();
    placaController.dispose();
    super.dispose();
  }

  //--------------------------------------------------------------------
  // AJUSTE RESPONSIVO
  //--------------------------------------------------------------------
  double _fs(BuildContext ctx, double base) {
    // base = tamanho pensado para 390 px de largura (iPhone 13)
    final w = MediaQuery.of(ctx).size.width;
    return base * (w / 390).clamp(0.85, 1.15);
  }

  TextStyle _titleStyle(BuildContext ctx) => TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: _fs(ctx, 17),
        color: Theme.of(ctx).colorScheme.primary,
      );

  TextStyle _labelStyle(BuildContext ctx) => TextStyle(
        fontSize: _fs(ctx, 13),
        color: Theme.of(ctx).colorScheme.onSurface,
      );

  ButtonStyle _compactActionStyle() => const ButtonStyle(
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        minimumSize: WidgetStatePropertyAll(Size(0, 34)),
        padding: WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        ),
        textStyle: WidgetStatePropertyAll(
          TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
        ),
      );

  //--------------------------------------------------------------------
  // FETCH BENS
  //--------------------------------------------------------------------
  Future<void> _fetchBens() async {
    final auth = Provider.of<Auth>(context, listen: false);
    final url =
        'https://pmrr.online/flutter/sigrh/buscabem.php?cpf=${auth.cpf}&ano=${widget.ano}';
    try {
      final resp = await http.get(Uri.parse(url));
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body);
        if (data['code'] == 1) {
          final lista = List<Map<String, dynamic>>.from(data['result']);
          final idx = lista.indexWhere((b) => b['tipo_bem'] == 3);
          if (idx != -1) {
            setState(() {
              jaDeclarouNaoPossui = true;
              naoPossuiRegistro = lista[idx];
              tipoBem = 'Nenhum';
              bensEnviados = [];
            });
          } else {
            setState(() {
              jaDeclarouNaoPossui = false;
              naoPossuiRegistro = null;
              bensEnviados = lista;
            });
          }
          _fadeCtrl.forward(from: 0);
        }
      } else {
        _alerta('Erro ao buscar bens', erro: true);
      }
    } catch (e) {
      _alerta(textoFalha('DC', e, tela: 'rh.declaracoes.bens'), erro: true);
    }
  }

  //--------------------------------------------------------------------
  // ENVIO
  //--------------------------------------------------------------------
  Future<void> _enviarBem() async {
    if (!_validateForm()) return;
    final auth = Provider.of<Auth>(context, listen: false);

    if (tipoBem == 'Nenhum') {
      await _enviarDeclaracaoNaoPossui(auth);
      return;
    }

    final descricao = tipoBem == 'Imóvel'
        ? _formatarDescricaoImovel()
        : _formatarDescricaoMovel();
    final valor = valorController.text.replaceAll(RegExp(r'[^0-9]'), '');
    final tipo = tipoBem == 'Imóvel' ? 1 : 2;

    final url =
        'https://pmrr.online/flutter/sigrh/inserebem.php?cpf=${auth.cpf}&ano=${widget.ano}&descricao=${Uri.encodeComponent(descricao)}&valor=$valor&tipo=$tipo';

    _showLoading();
    try {
      final resp = await http.get(Uri.parse(url));
      Navigator.of(context).pop();
      final data = json.decode(resp.body);
      if (resp.statusCode == 200 && data['code'] == 1) {
        await _fetchBens();
        _alerta('Bem cadastrado com sucesso');
        _resetForm();
      } else {
        _alerta(data['message'] ?? 'Erro ao enviar o bem', erro: true);
      }
    } catch (e) {
      Navigator.of(context).pop();
      _alerta(textoFalha('DC', e, tela: 'rh.declaracoes.bens'), erro: true);
    }
  }

  Future<void> _enviarDeclaracaoNaoPossui(Auth auth) async {
    final url =
        'https://pmrr.online/flutter/sigrh/inserebem.php?cpf=${auth.cpf}&ano=${widget.ano}&tipo=3';

    _showLoading();
    try {
      final resp = await http.get(Uri.parse(url));
      Navigator.of(context).pop();
      final data = json.decode(resp.body);
      if (resp.statusCode == 200 && data['code'] == 1) {
        await _fetchBens();
        _alerta('Declaração enviada com sucesso');
      } else {
        _alerta(data['message'] ?? 'Erro ao enviar declaração', erro: true);
      }
    } catch (e) {
      Navigator.of(context).pop();
      _alerta(textoFalha('DC', e, tela: 'rh.declaracoes.bens'), erro: true);
    }
  }

  Future<void> _excluirNaoPossui() async {
    final confirm = await _showConfirmDialog(
      title: 'Excluir declaração',
      message: 'Deseja realmente excluir a declaração de não possuir bens?',
    );
    if (!confirm) return;

    if (naoPossuiRegistro == null) return;
    final id = naoPossuiRegistro!['id'];
    final url = 'https://pmrr.online/flutter/sigrh/excluibem.php?id_bem=$id';
    _showLoading();
    try {
      final resp = await http.get(Uri.parse(url));
      Navigator.of(context).pop();
      final data = json.decode(resp.body);
      if (resp.statusCode == 200 && data['code'] == 1) {
        setState(() {
          jaDeclarouNaoPossui = false;
          naoPossuiRegistro = null;
          tipoBem = 'Imóvel';
        });
        _resetForm();
        _alerta('Declaração excluída com sucesso');
      } else {
        _alerta(data['message'] ?? 'Erro ao excluir declaração', erro: true);
      }
    } catch (e) {
      Navigator.of(context).pop();
      _alerta(textoFalha('DC', e, tela: 'rh.declaracoes.bens'), erro: true);
    }
  }

  Future<void> _excluirBem(int index) async {
    final confirm = await _showConfirmDialog(
      title: 'Excluir bem',
      message: 'Deseja realmente excluir este item declarado?',
    );
    if (!confirm) return;

    final id = bensEnviados[index]['id'];
    final url = 'https://pmrr.online/flutter/sigrh/excluibem.php?id_bem=$id';
    _showLoading();
    try {
      final resp = await http.get(Uri.parse(url));
      Navigator.of(context).pop();
      final data = json.decode(resp.body);
      if (resp.statusCode == 200 && data['code'] == 1) {
        setState(() => bensEnviados.removeAt(index));
        _alerta('Bem excluído com sucesso');
      } else {
        _alerta(data['message'] ?? 'Erro ao excluir o bem', erro: true);
      }
    } catch (e) {
      Navigator.of(context).pop();
      _alerta(textoFalha('DC', e, tela: 'rh.declaracoes.bens'), erro: true);
    }
  }

  //--------------------------------------------------------------------
  // FORM VALIDATION
  //--------------------------------------------------------------------
  bool _validateForm() {
    if (tipoBem == 'Nenhum') return true;

    if (descricaoController.text.isEmpty ||
        valorController.text.isEmpty ||
        (tipoBem == 'Imóvel' && enderecoController.text.isEmpty) ||
        (tipoBem == 'Imóvel' && areaController.text.isEmpty) ||
        dataAquisicaoController.text.isEmpty ||
        (formaAquisicao == 'Financiado' &&
            instituicaoController.text.isEmpty) ||
        (formaAquisicao == 'Financiado' && parcelasController.text.isEmpty) ||
        (formaAquisicao == 'Financiado' && gastosController.text.isEmpty)) {
      _alerta('Preencha todos os campos obrigatórios', erro: true);
      return false;
    }
    return true;
  }

  //--------------------------------------------------------------------
  // HELPERS
  //--------------------------------------------------------------------
  void _updateValorExtenso() {
    final digits = valorController.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) {
      setState(() => valorExtenso = '');
      return;
    }
    final cents = int.parse(digits);
    final reais = cents ~/ 100;
    final centavos = cents % 100;

    String strip(String s) => s
        .replaceAll(RegExp(r'\b(reais?|centavos?)\b', caseSensitive: false), '')
        .trim();

    final extReais = reais > 0 ? strip(extenso(reais)) : '';
    final extCentavos = centavos > 0 ? strip(extenso(centavos)) : '';

    var frase = '';
    if (reais > 0) frase += '$extReais ${reais == 1 ? "real" : "reais"}';
    if (centavos > 0) {
      if (reais > 0) frase += ' e ';
      frase += '$extCentavos ${centavos == 1 ? "centavo" : "centavos"}';
    }
    setState(() => valorExtenso = frase);
  }

  void _resetForm() {
    descricaoController.clear();
    enderecoController.clear();
    areaController.clear();
    dataAquisicaoController.clear();
    instituicaoController.clear();
    parcelasController.clear();
    gastosController.clear();
    marcaModeloController.clear();
    placaController.clear();
    valorController.clear();
    setState(() => valorExtenso = '');
  }

  Future<void> _selectDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => dataAquisicaoController.text =
          DateFormat('dd/MM/yyyy').format(picked));
    }
  }

  String _formatarDescricaoImovel() {
    var d = 'Imóvel:\n- Tipo: ${descricaoController.text.trim()}\n';
    d += '- Endereço: ${enderecoController.text.trim()}\n';
    d += '- Área: ${areaController.text.trim()}\n';
    d += '- Data: ${dataAquisicaoController.text.trim()}\n';
    d += '- Aquisição: $formaAquisicao\n';
    if (formaAquisicao == 'Financiado') {
      d += '- Instituição: ${instituicaoController.text.trim()}\n';
      d += '- Parcelas: ${parcelasController.text.trim()}\n';
      d += '- Gastos: ${gastosController.text.trim()}\n';
    }
    return d;
  }

  String _formatarDescricaoMovel() {
    var d = 'Móvel:\n- Tipo: ${descricaoController.text.trim()}\n';
    d += '- Marca: ${marcaModeloController.text.trim()}\n';
    d += '- Placa: ${placaController.text.trim()}\n';
    d += '- Data: ${dataAquisicaoController.text.trim()}\n';
    d += '- Aquisição: $formaAquisicao\n';
    if (formaAquisicao == 'Financiado') {
      d += '- Instituição: ${instituicaoController.text.trim()}\n';
      d += '- Parcelas: ${parcelasController.text.trim()}\n';
      d += '- Gastos: ${gastosController.text.trim()}\n';
    }
    return d;
  }

  String _calcularValorTotal() {
    var total = 0.0;
    for (var b in bensEnviados) {
      total +=
          double.tryParse((b['valor'] as String).replaceAll(',', '.')) ?? 0;
    }
    return NumberFormat.currency(locale: 'pt_BR', symbol: '').format(total);
  }

  /// Atalho local: sucesso ou erro, com o visual dos alertas do app.
  void _alerta(String message, {bool erro = false}) {
    if (erro) {
      alertaErro(context, titulo: 'Atenção', texto: message, arte: Arte.de('rh'));
    } else {
      alertaSucesso(context, titulo: 'Sucesso', texto: message, arte: Arte.de('rh'));
    }
  }

  void _showLoading() =>
      mostrarCarregandoDialogo(context, 'Processando...', arte: Arte.de('rh'));

  Future<bool> _showConfirmDialog({
    required String title,
    required String message,
  }) =>
      dialogoConfirmacao(
        context,
        titulo: title,
        mensagem: message,
        // Todas as confirmações desta tela são de exclusão.
        textoConfirmar: 'Excluir',
        icone: Icons.delete_outline_rounded,
        cor: Theme.of(context).colorScheme.error,
        arte: Arte.de('rh'),
      );

  //--------------------------------------------------------------------
  // BUILD
  //--------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final radius = BorderRadius.circular(12);

    return FundoSuave(
        child: Scaffold(
      appBar: AppBar(
        elevation: 0,
        flexibleSpace: const FundoBarraVidro(),
        title: const Text('Declarações de Bens',
            style: TextStyle(color: Colors.white)),
        leading: const BackButton(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // ---------- Topo com a arte da área (padrão 2.2) ----------
          TopoArte(
            arte: Arte.de('rh'),
            icone: Icons.home_work_outlined,
            titulo: 'Declaração de bens',
            subtitulo: 'Informe seus bens móveis e imóveis do ciclo '
                '${widget.ano}, ou declare que não possui.',
            margem: const EdgeInsets.only(bottom: 16),
          ),
          // ---------- Título ----------
          Center(child: Text('Tipo de Bem', style: _titleStyle(context))),
          const SizedBox(height: 8),

          // ---------- Radio Buttons ----------
          Row(children: [
            _radio('Imóvel'),
            _radio('Móvel'),
            _radio('Nenhum', label: 'Não possui'),
          ]),
          const SizedBox(height: 14),

          // ---------- Conteúdo dinâmico ----------
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: tipoBem == 'Nenhum'
                ? _buildNaoPossui(radius, width)
                : _buildForm(radius, width),
          ),
        ]),
      ),
    ));
  }

  //--------------------------------------------------------------------
  // RADIO
  //--------------------------------------------------------------------
  Widget _radio(String value, {String? label}) {
    final theme = Theme.of(context);
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: ChoiceChip(
          selected: tipoBem == value,
          label: SizedBox(
            width: double.infinity,
            child: Text(
              label ?? value,
              textAlign: TextAlign.center,
              style: _labelStyle(context).copyWith(
                fontSize: _fs(context, 12.5),
                fontWeight: FontWeight.w600,
                color: tipoBem == value
                    ? theme.colorScheme.onPrimary
                    : theme.colorScheme.onSurface,
              ),
            ),
          ),
          showCheckmark: false,
          selectedColor: theme.colorScheme.primary,
          backgroundColor: theme.cardColor.withValues(alpha: 0.88),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
          side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.35)),
          onSelected: (_) => setState(() {
            tipoBem = value;
            _resetForm();
          }),
        ),
      ),
    );
  }

  //--------------------------------------------------------------------
  // NÃO POSSUI UI
  //--------------------------------------------------------------------
  Widget _buildNaoPossui(BorderRadius radius, double width) {
    final theme = Theme.of(context);
    return Column(children: [
      CartaoVidro(
        arte: Arte.de('rh'),
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          width: double.infinity,
          child: Text(
            jaDeclarouNaoPossui
                ? 'Declarou Não possuir Bens'
                : 'Não possuo bem móvel ou imóvel',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
                fontSize: _fs(context, 16)),
          ),
        ),
      ),
      const SizedBox(height: 16),
      Row(children: [
        Expanded(
          child: FilledButton.tonal(
            style: _compactActionStyle(),
            onPressed: jaDeclarouNaoPossui ? null : _enviarBem,
            child: const Text('Enviar Declaração'),
          ),
        ),
        if (jaDeclarouNaoPossui) ...[
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton(
              style: const ButtonStyle(
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                minimumSize: WidgetStatePropertyAll(Size(0, 34)),
                padding: WidgetStatePropertyAll(
                  EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                ),
                backgroundColor: WidgetStatePropertyAll(Colors.red),
              ),
              onPressed: _excluirNaoPossui,
              child: const Text('Excluir Declaração'),
            ),
          ),
        ],
      ]),
    ]);
  }

  //--------------------------------------------------------------------
  // FORMULARIO DE BENS
  //--------------------------------------------------------------------
  Widget _buildForm(BorderRadius radius, double width) {
    final theme = Theme.of(context);
    return Column(children: [
      CartaoVidro(
        arte: Arte.de('rh'),
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (tipoBem == 'Imóvel') ...[
            _buildTextField(
                'Tipo do Imóvel - Casa, Apartamento...', descricaoController),
            _buildTextField('Endereço', enderecoController),
            _buildTextField('Área (m²)', areaController),
          ] else ...[
            _buildTextField(
                'Tipo do Bem - Carro, Jet‑Ski...', descricaoController),
            _buildTextField('Marca e Modelo', marcaModeloController),
            _buildTextField('Placa', placaController),
          ],
          GestureDetector(
            onTap: () => _selectDate(context),
            child: AbsorbPointer(
                child: _buildTextField(
                    'Data de Aquisição', dataAquisicaoController)),
          ),
          _buildFormaAquisicaoDropdown(),
          if (formaAquisicao == 'Financiado') ...[
            _buildTextField('Instituição Financeira', instituicaoController),
            Row(children: [
              Expanded(
                  child: _buildTextField('Parcelas Pagas', parcelasController)),
              const SizedBox(width: 10),
              Expanded(
                  child:
                      _buildTextField('Gastos Relacionados', gastosController)),
            ]),
          ],
          const SizedBox(height: 6),
          TextField(
            controller: valorController,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              CurrencyInputFormatter()
            ],
            decoration: const InputDecoration(labelText: 'Valor'),
            style: _labelStyle(context),
          ),
          const SizedBox(height: 6),
          if (valorExtenso.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: theme.colorScheme.primary.withValues(alpha: 0.20)),
              ),
              child: Text(valorExtenso,
                  style: TextStyle(
                      fontSize: _fs(context, 13),
                      color: theme.colorScheme.onSurface,
                      fontStyle: FontStyle.italic)),
            ),
          const SizedBox(height: 10),
          Center(
            child: FilledButton.tonal(
                style: _compactActionStyle(),
                onPressed: _enviarBem,
                child: const Text('Enviar Bem')),
          ),
        ]),
      ),
      const SizedBox(height: 20),
      _buildResumo(radius),
    ]);
  }

  //--------------------------------------------------------------------
  // RESUMO / LISTA
  //--------------------------------------------------------------------
  Widget _buildResumo(BorderRadius radius) {
    final theme = Theme.of(context);
    return FadeTransition(
      opacity: _fadeCtrl.drive(CurveTween(curve: Curves.easeIn)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Declarações de Bens - Total do Ano R\$ ${_calcularValorTotal()}',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
                fontSize: _fs(context, 15))),
        const SizedBox(height: 8),
        if (bensEnviados.isEmpty)
          Text('Nenhum bem cadastrado', style: _labelStyle(context))
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: bensEnviados.length,
            itemBuilder: (ctx, i) {
              final bem = bensEnviados[i];
              final tipoTexto = bem['tipo_bem'] == 1 ? 'Imóvel' : 'Móvel';
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: CartaoVidro(
                  raio: 12,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: Duration(milliseconds: 240 + (i * 45)),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, child) => Opacity(
                      opacity: value,
                      child: Transform.translate(
                        offset: Offset(0, (1 - value) * 8),
                        child: child,
                      ),
                    ),
                    child: ListTile(
                      dense: true,
                      visualDensity: const VisualDensity(vertical: -2),
                      title: Text('$tipoTexto: ${bem['descricao'] ?? ''}',
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: _fs(context, 12.5))),
                      subtitle: bem['valor'] != null
                          ? Text(
                              'R\$ ${NumberFormat.currency(locale: 'pt_BR', symbol: '').format(double.tryParse((bem['valor'] as String).replaceAll(',', '.')) ?? 0)}',
                              style: _labelStyle(context)
                                  .copyWith(color: Colors.green.shade700))
                          : null,
                      trailing: IconButton(
                        visualDensity: VisualDensity.compact,
                        iconSize: AppIconSize.sm,
                        icon: Icon(Icons.delete_outline_rounded,
                            color: theme.colorScheme.error),
                        onPressed: () => _excluirBem(i),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
      ]),
    );
  }

  //--------------------------------------------------------------------
  // INPUT WIDGETS
  //--------------------------------------------------------------------
  Widget _buildTextField(String label, TextEditingController ctrl) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextField(
        controller: ctrl,
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        ),
        style: _labelStyle(context),
      ),
    );
  }

  Widget _buildFormaAquisicaoDropdown() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: DropdownButtonFormField<String>(
        value: formaAquisicao,
        items: [
          DropdownMenuItem(
              value: 'À vista',
              child: Text(
                'À vista',
                style: TextStyle(color: theme.colorScheme.onSurface),
              )),
          DropdownMenuItem(
            value: 'Financiado',
            child: Text(
              'Financiado',
              style: TextStyle(color: theme.colorScheme.onSurface),
            ),
          ),
        ],
        onChanged: (v) => setState(() {
          formaAquisicao = v!;
          if (formaAquisicao == 'À vista') {
            instituicaoController.clear();
            parcelasController.clear();
            gastosController.clear();
          }
        }),
        decoration: const InputDecoration(
          labelText: 'Forma de Aquisição',
          isDense: true,
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        ),
        style: _labelStyle(context),
        dropdownColor:
            isDark ? theme.colorScheme.surface : theme.colorScheme.background,
      ),
    );
  }
}

//--------------------------------------------------------------------
// FORMATADOR DE MOEDA
//--------------------------------------------------------------------
class CurrencyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) return newValue.copyWith(text: '');
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    final number = int.tryParse(digits) ?? 0;
    final formatted =
        NumberFormat.currency(locale: 'pt_BR', symbol: '', decimalDigits: 2)
            .format(number / 100);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
