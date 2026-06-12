import 'package:flutter/material.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:projetonovo/utils/app_theme.dart';
import 'package:quickalert/quickalert.dart';

import '../models/endereco.dart';
import '../models/militar.dart';
import '../services/dados_sql.dart';
import '../utils/app_routes.dart';

// ignore: must_be_immutable
class EdicaoEnderecoPage extends StatefulWidget {
  Militar militar;
  EdicaoEnderecoPage({
    Key? key,
    required this.militar,
  }) : super(key: key);
  late Endereco enderecoCompleto;
  bool inicio = true;
  bool alterouDados = false;
  DadosSql dadosSql = DadosSql();
  TextEditingController controllerMunicipio = TextEditingController();
  TextEditingController controllerEnderecoNovo = TextEditingController();
  TextEditingController controllerRua = TextEditingController();
  TextEditingController controllerNumero = TextEditingController();
  TextEditingController controllerCep = TextEditingController();
  TextEditingController controllerBairro = TextEditingController();

  @override
  _EdicaoEnderecoPageState createState() => _EdicaoEnderecoPageState();
}

class _EdicaoEnderecoPageState extends State<EdicaoEnderecoPage> {
  final DadosSql dadosSql = DadosSql();
  String _query = '';
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    const primaryBlue = AppColors.blue;

    if (widget.inicio) {
      widget.enderecoCompleto = widget.militar.endereco;
      widget.controllerCep.text = widget.enderecoCompleto.cep ?? '';
      widget.controllerMunicipio.text =
          widget.enderecoCompleto.municipio?.nome ?? '';
      widget.controllerRua.text = widget.enderecoCompleto.rua?.nome ?? '';
      widget.controllerNumero.text = widget.enderecoCompleto.numero ?? '';
      widget.controllerBairro.text = widget.enderecoCompleto.bairro?.nome ?? '';
      widget.inicio = false;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Atualizar Endereço',
          style: TextStyle(
              fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1976D2), Color(0xFF002154)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Campo de busca ────────────────────────────────────────────
            Text(
              'Buscar novo endereço',
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: isDark
                    ? theme.colorScheme.surface
                    : const Color(0xFFF2F6FF),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF30363D)
                      : const Color(0xFFDDE6F5),
                ),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 14),
                  Icon(Icons.search_rounded,
                      color: primaryBlue.withValues(alpha: 0.7), size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TypeAheadField<Endereco?>(
                      controller: widget.controllerEnderecoNovo,
                      errorBuilder: (context, error) => ListTile(
                        leading: const Icon(Icons.search_rounded,
                            size: 18, color: AppColors.blue),
                        title: Text(
                          _query.length < 3
                              ? 'Mín. 3 caracteres para buscar'
                              : 'Erro ao buscar. Tente novamente.',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                      loadingBuilder: (context) => const Padding(
                        padding: EdgeInsets.all(12),
                        child: LinearProgressIndicator(),
                      ),
                      emptyBuilder: (context) => ListTile(
                        leading: Icon(
                          _query.length < 3
                              ? Icons.keyboard_outlined
                              : Icons.search_off_rounded,
                          size: 18,
                          color: AppColors.blue.withValues(alpha: 0.6),
                        ),
                        title: Text(
                          _query.length < 3
                              ? 'Mín. 3 caracteres para buscar'
                              : 'Nenhum resultado encontrado',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                      builder: (context, controller, focusNode) {
                        return TextField(
                          controller: widget.controllerEnderecoNovo,
                          focusNode: focusNode,
                          obscureText: false,
                          style: const TextStyle(fontSize: 14),
                          decoration: InputDecoration(
                            hintText: 'Digite a rua ou bairro...',
                            hintStyle: TextStyle(
                              fontSize: 13,
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.4),
                            ),
                            border: InputBorder.none,
                            contentPadding:
                                const EdgeInsets.symmetric(vertical: 14),
                          ),
                        );
                      },
                      suggestionsCallback: (query) async {
                        setState(() => _query = query);
                        if (query.trim().length < 3) return [];
                        return widget.dadosSql.listaEnderecoCompleto(query);
                      },
                      itemBuilder: (context, Endereco? suggestion) {
                        if (suggestion == null) return const SizedBox.shrink();
                        return ListTile(
                          leading: const Icon(Icons.location_on_outlined,
                              size: 18, color: AppColors.blue),
                          title: Text(
                            suggestion.logradouro ?? '',
                            style: const TextStyle(fontSize: 13),
                          ),
                        );
                      },
                      onSelected: (end) {
                        atualizaDados();
                        if (end != null) alteraEndereco(end);
                      },
                    ),
                  ),
                  IconButton(
                    onPressed: limpaDados,
                    icon: Icon(Icons.close_rounded,
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.4),
                        size: 20),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── Card de endereço atual ────────────────────────────────────
            Container(
              decoration: BoxDecoration(
                color: isDark ? theme.colorScheme.surface : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: widget.alterouDados
                      ? primaryBlue.withValues(alpha: 0.4)
                      : (isDark
                          ? const Color(0xFF30363D)
                          : const Color(0xFFE8EFFA)),
                  width: widget.alterouDados ? 1.5 : 1,
                ),
                boxShadow: isDark
                    ? []
                    : [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
              ),
              child: Column(
                children: [
                  // Cabeçalho
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    decoration: BoxDecoration(
                      color:
                          primaryBlue.withValues(alpha: isDark ? 0.18 : 0.08),
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(16)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: primaryBlue.withValues(
                                alpha: isDark ? 0.25 : 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.home_outlined,
                              size: 16, color: primaryBlue),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          widget.alterouDados
                              ? 'Novo Endereço'
                              : 'Endereço Atual',
                          style: theme.textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        if (widget.alterouDados) ...[
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: primaryBlue.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              'Alterado',
                              style: TextStyle(
                                  color: primaryBlue,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Campos de exibição
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                    child: Column(
                      children: [
                        _endRow(
                            theme,
                            isDark,
                            'Município',
                            widget.enderecoCompleto.municipio?.nome ?? '—',
                            Icons.location_city_outlined),
                        _endRow(
                            theme,
                            isDark,
                            'Rua',
                            widget.enderecoCompleto.rua?.nome ?? '—',
                            Icons.map_outlined),
                        _endRow(
                            theme,
                            isDark,
                            'Bairro',
                            widget.enderecoCompleto.bairro?.nome ?? '—',
                            Icons.holiday_village_outlined),

                        // Número — editável
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Icon(Icons.pin_outlined,
                                  size: 16,
                                  color: theme.colorScheme.onSurface
                                      .withValues(alpha: 0.4)),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Número',
                                        style: theme.textTheme.labelSmall
                                            ?.copyWith(
                                          color: theme.colorScheme.onSurface
                                              .withValues(alpha: 0.5),
                                        )),
                                    const SizedBox(height: 2),
                                    SizedBox(
                                      height: 28,
                                      child: TextField(
                                        controller: widget.controllerNumero,
                                        readOnly: !widget.alterouDados,
                                        keyboardType: TextInputType.number,
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 13),
                                        decoration: InputDecoration(
                                          isDense: true,
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                  vertical: 4),
                                          border: widget.alterouDados
                                              ? const UnderlineInputBorder()
                                              : InputBorder.none,
                                          hintText: 'Ex: 123',
                                          hintStyle: TextStyle(
                                              fontSize: 13,
                                              color: Colors.grey.shade400),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        // CEP — editável
                        Padding(
                          padding: const EdgeInsets.only(bottom: 0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Icon(Icons.local_post_office_outlined,
                                  size: 16,
                                  color: theme.colorScheme.onSurface
                                      .withValues(alpha: 0.4)),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('CEP',
                                        style: theme.textTheme.labelSmall
                                            ?.copyWith(
                                          color: theme.colorScheme.onSurface
                                              .withValues(alpha: 0.5),
                                        )),
                                    const SizedBox(height: 2),
                                    SizedBox(
                                      height: 28,
                                      child: TextField(
                                        controller: widget.controllerCep,
                                        readOnly: !widget.alterouDados,
                                        keyboardType: TextInputType.number,
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 13),
                                        decoration: InputDecoration(
                                          isDense: true,
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                  vertical: 4),
                                          border: widget.alterouDados
                                              ? const UnderlineInputBorder()
                                              : InputBorder.none,
                                          hintText: 'Ex: 69314623',
                                          hintStyle: TextStyle(
                                              fontSize: 13,
                                              color: Colors.grey.shade400),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── Botão Salvar ──────────────────────────────────────────────
            if (widget.alterouDados)
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  icon: const Icon(Icons.save_rounded, size: 18),
                  label: const Text('Salvar Alterações',
                      style: TextStyle(fontSize: 15)),
                  style: FilledButton.styleFrom(
                    backgroundColor: primaryBlue,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: _saving
                      ? null
                      : () async {
                          if (widget.controllerNumero.text.isEmpty ||
                              widget.controllerCep.text.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content:
                                    Text('Por favor preencha número e CEP'),
                                backgroundColor: Colors.orange,
                              ),
                            );
                            return;
                          }

                          widget.enderecoCompleto.cep =
                              widget.controllerCep.text;
                          widget.enderecoCompleto.numero =
                              widget.controllerNumero.text;

                          // Dialog ANTES do setState para renderizar imediatamente
                          showDialog(
                            context: context,
                            barrierDismissible: false,
                            barrierColor: Colors.black.withValues(alpha: 0.45),
                            builder: (_) => const _EnderecoLoadingDialog(),
                          );

                          setState(() => _saving = true);

                          try {
                            // Future.wait garante mín. 700ms de loading visível
                            await Future.wait([
                              dadosSql.atualizaEndereco(
                                widget.enderecoCompleto.municipio?.id ?? '',
                                widget.enderecoCompleto.bairro?.id ?? '',
                                widget.enderecoCompleto.rua?.id ?? '',
                                widget.enderecoCompleto.numero ?? '',
                                widget.enderecoCompleto.cep ?? '',
                                widget.militar.matricula,
                              ),
                              Future<void>.delayed(
                                  const Duration(milliseconds: 700)),
                            ]);

                            if (!mounted) return;
                            Navigator.of(context, rootNavigator: true).pop();

                            QuickAlert.show(
                              onConfirmBtnTap: () =>
                                  Navigator.of(context).popUntil(
                                ModalRoute.withName(AppRoutes.PAGE_MILITAR),
                              ),
                              context: context,
                              title: 'Sucesso',
                              confirmBtnText: 'OK',
                              type: QuickAlertType.success,
                              text: 'Endereço atualizado com sucesso!',
                              confirmBtnColor: AppColors.blue,
                            );
                          } catch (error) {
                            if (!mounted) return;
                            Navigator.of(context, rootNavigator: true).pop();

                            QuickAlert.show(
                              onConfirmBtnTap: () =>
                                  Navigator.of(context).pop(),
                              context: context,
                              title: 'Erro',
                              confirmBtnText: 'OK',
                              type: QuickAlertType.error,
                              text: 'Erro ao salvar. Tente novamente.',
                            );
                          } finally {
                            if (mounted) setState(() => _saving = false);
                          }
                        },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _endRow(
      ThemeData theme, bool isDark, String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon,
              size: 16,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.5))),
                const SizedBox(height: 2),
                Text(
                  value.isNotEmpty ? value : '—',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void alteraEndereco(Endereco end) {
    setState(() {
      widget.alterouDados = true;
      widget.enderecoCompleto = end;
      widget.controllerEnderecoNovo.text = end.logradouro ?? '';
      widget.controllerCep.text = '';
      widget.controllerNumero.text = '';
    });
  }

  void limpaDados() {
    setState(() {
      widget.controllerEnderecoNovo.text = '';
      widget.alterouDados = false;
      widget.enderecoCompleto = widget.militar.endereco;
    });
  }

  void atualizaDados() {
    setState(() {
      widget.alterouDados = true;
    });
  }
}

// ── Loading dialog (reutilizável) ─────────────────────────────────────────────
class _EnderecoLoadingDialog extends StatelessWidget {
  const _EnderecoLoadingDialog();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 32),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1C2128) : Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.12),
                blurRadius: 32,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 48,
                height: 48,
                child: CircularProgressIndicator(
                  color: AppColors.blue,
                  strokeWidth: 3.5,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Salvando...',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Aguarde um momento',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
