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
import 'package:quickalert/quickalert.dart';
import 'package:http/http.dart' as http;

import '../models/auth_model.dart';

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
        fontSize: _fs(ctx, 18),
        color: Colors.blue.shade900,
      );

  TextStyle _labelStyle(BuildContext ctx) => TextStyle(fontSize: _fs(ctx, 14));

  //--------------------------------------------------------------------
  // FETCH BENS
  //--------------------------------------------------------------------
  Future<void> _fetchBens() async {
    final auth = Provider.of<Auth>(context, listen: false);
    final url =
        'https://pmrr.net/flutter/sigrh/buscabem.php?cpf=${auth.cpf}&ano=${widget.ano}';
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
        _showQuickAlert('Erro ao buscar bens', QuickAlertType.error);
      }
    } catch (e) {
      _showQuickAlert('Erro inesperado: $e', QuickAlertType.error);
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
        'https://pmrr.net/flutter/sigrh/inserebem.php?cpf=${auth.cpf}&ano=${widget.ano}&descricao=${Uri.encodeComponent(descricao)}&valor=$valor&tipo=$tipo';

    _showLoading();
    try {
      final resp = await http.get(Uri.parse(url));
      Navigator.of(context).pop();
      final data = json.decode(resp.body);
      if (resp.statusCode == 200 && data['code'] == 1) {
        await _fetchBens();
        _showQuickAlert('Bem cadastrado com sucesso', QuickAlertType.success);
        _resetForm();
      } else {
        _showQuickAlert(
            data['message'] ?? 'Erro ao enviar o bem', QuickAlertType.error);
      }
    } catch (e) {
      Navigator.of(context).pop();
      _showQuickAlert('Erro inesperado: $e', QuickAlertType.error);
    }
  }

  Future<void> _enviarDeclaracaoNaoPossui(Auth auth) async {
    final url =
        'https://pmrr.net/flutter/sigrh/inserebem.php?cpf=${auth.cpf}&ano=${widget.ano}&tipo=3';

    _showLoading();
    try {
      final resp = await http.get(Uri.parse(url));
      Navigator.of(context).pop();
      final data = json.decode(resp.body);
      if (resp.statusCode == 200 && data['code'] == 1) {
        await _fetchBens();
        _showQuickAlert(
            'Declaração enviada com sucesso', QuickAlertType.success);
      } else {
        _showQuickAlert(data['message'] ?? 'Erro ao enviar declaração',
            QuickAlertType.error);
      }
    } catch (e) {
      Navigator.of(context).pop();
      _showQuickAlert('Erro inesperado: $e', QuickAlertType.error);
    }
  }

  Future<void> _excluirNaoPossui() async {
    if (naoPossuiRegistro == null) return;
    final id = naoPossuiRegistro!['id'];
    final url = 'https://pmrr.net/flutter/sigrh/excluibem.php?id_bem=$id';
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
        _showQuickAlert(
            'Declaração excluída com sucesso', QuickAlertType.success);
      } else {
        _showQuickAlert(data['message'] ?? 'Erro ao excluir declaração',
            QuickAlertType.error);
      }
    } catch (e) {
      Navigator.of(context).pop();
      _showQuickAlert('Erro inesperado: $e', QuickAlertType.error);
    }
  }

  Future<void> _excluirBem(int index) async {
    final id = bensEnviados[index]['id'];
    final url = 'https://pmrr.net/flutter/sigrh/excluibem.php?id_bem=$id';
    _showLoading();
    try {
      final resp = await http.get(Uri.parse(url));
      Navigator.of(context).pop();
      final data = json.decode(resp.body);
      if (resp.statusCode == 200 && data['code'] == 1) {
        setState(() => bensEnviados.removeAt(index));
        _showQuickAlert('Bem excluído com sucesso', QuickAlertType.success);
      } else {
        _showQuickAlert(
            data['message'] ?? 'Erro ao excluir o bem', QuickAlertType.error);
      }
    } catch (e) {
      Navigator.of(context).pop();
      _showQuickAlert('Erro inesperado: $e', QuickAlertType.error);
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
      _showQuickAlert(
          'Preencha todos os campos obrigatórios', QuickAlertType.warning);
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

  void _showQuickAlert(String message, QuickAlertType type) {
    QuickAlert.show(context: context, type: type, text: message);
  }

  void _showLoading() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator.adaptive()),
    );
  }

  //--------------------------------------------------------------------
  // BUILD
  //--------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final radius = BorderRadius.circular(12);

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF3AA0FF), Color(0xFF006DFF)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
        ),
        title: const Text('Declarações de Bens',
            style: TextStyle(color: Colors.white)),
        leading: const BackButton(color: Colors.white),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF6F7FB), Color(0xFFFBFBFD)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // ---------- Título ----------
            Center(child: Text('Tipo de Bem', style: _titleStyle(context))),
            const SizedBox(height: 8),

            // ---------- Radio Buttons ----------
            Row(children: [
              _radio('Imóvel'),
              _radio('Móvel'),
              _radio('Nenhum', label: 'Não\nPossui'),
            ]),
            const SizedBox(height: 16),

            // ---------- Conteúdo dinâmico ----------
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: tipoBem == 'Nenhum'
                  ? _buildNaoPossui(radius, width)
                  : _buildForm(radius, width),
            ),
          ]),
        ),
      ),
    );
  }

  //--------------------------------------------------------------------
  // RADIO
  //--------------------------------------------------------------------
  Widget _radio(String value, {String? label}) {
    return Expanded(
      child: RadioListTile(
        contentPadding: EdgeInsets.zero,
        dense: true,
        title: Text(label ?? value,
            textAlign: TextAlign.center, style: _labelStyle(context)),
        value: value,
        groupValue: tipoBem,
        onChanged: (v) => setState(() {
          tipoBem = v as String;
          _resetForm();
        }),
      ),
    );
  }

  //--------------------------------------------------------------------
  // NÃO POSSUI UI
  //--------------------------------------------------------------------
  Widget _buildNaoPossui(BorderRadius radius, double width) {
    return Column(children: [
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: radius,
          border: Border.all(color: Colors.blue.shade100),
        ),
        child: Text(
          jaDeclarouNaoPossui
              ? 'Declarou Não possuir Bens'
              : 'Não possuo bem móvel ou imóvel',
          textAlign: TextAlign.center,
          style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.blue.shade900,
              fontSize: _fs(context, 16)),
        ),
      ),
      const SizedBox(height: 16),
      Row(children: [
        Expanded(
          child: FilledButton.tonal(
            onPressed: jaDeclarouNaoPossui ? null : _enviarBem,
            child: const Text('Enviar Declaração'),
          ),
        ),
        if (jaDeclarouNaoPossui) ...[
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
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
    return Column(children: [
      Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: radius,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 4),
            )
          ],
        ),
        padding: const EdgeInsets.all(16),
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
              const SizedBox(width: 12),
              Expanded(
                  child:
                      _buildTextField('Gastos Relacionados', gastosController)),
            ]),
          ],
          const SizedBox(height: 8),
          TextField(
            controller: valorController,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              CurrencyInputFormatter()
            ],
            decoration: const InputDecoration(
                labelText: 'Valor', border: OutlineInputBorder()),
            style: _labelStyle(context),
          ),
          const SizedBox(height: 8),
          if (valorExtenso.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(valorExtenso,
                  style: TextStyle(
                      fontSize: _fs(context, 13), fontStyle: FontStyle.italic)),
            ),
          const SizedBox(height: 12),
          Center(
            child: FilledButton.tonal(
                onPressed: _enviarBem, child: const Text('Enviar Bem')),
          ),
        ]),
      ),
      const SizedBox(height: 24),
      _buildResumo(radius),
    ]);
  }

  //--------------------------------------------------------------------
  // RESUMO / LISTA
  //--------------------------------------------------------------------
  Widget _buildResumo(BorderRadius radius) {
    return FadeTransition(
      opacity: _fadeCtrl.drive(CurveTween(curve: Curves.easeIn)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Declarações de Bens - Total do Ano R\$ ${_calcularValorTotal()}',
            style: TextStyle(
                fontWeight: FontWeight.bold, fontSize: _fs(context, 15))),
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
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                elevation: 1,
                child: ListTile(
                  title: Text('$tipoTexto: ${bem['descricao'] ?? ''}',
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: _fs(context, 14))),
                  subtitle: bem['valor'] != null
                      ? Text(
                          'R\$ ${NumberFormat.currency(locale: 'pt_BR', symbol: '').format(double.tryParse((bem['valor'] as String).replaceAll(',', '.')) ?? 0)}',
                          style: _labelStyle(context)
                              .copyWith(color: Colors.green.shade700))
                      : null,
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _excluirBem(i),
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
            labelText: label, border: const OutlineInputBorder()),
        style: _labelStyle(context),
      ),
    );
  }

  Widget _buildFormaAquisicaoDropdown() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: DropdownButtonFormField<String>(
        value: formaAquisicao,
        items: const [
          DropdownMenuItem(
              value: 'À vista',
              child: Text(
                'À vista',
                style: TextStyle(color: Colors.black),
              )),
          DropdownMenuItem(
              value: 'Financiado',
              child: Text('Financiado', style: TextStyle(color: Colors.black))),
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
            labelText: 'Forma de Aquisição', border: OutlineInputBorder()),
        style: _labelStyle(context),
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
