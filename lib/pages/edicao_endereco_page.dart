import 'package:flutter/material.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:projetonovo/utils/app_theme.dart';

import '../models/endereco.dart';
import '../models/militar.dart';
import '../services/dados_sql.dart';
import '../core/design/arte_cartao.dart';
import '../widgets/custom_appbar.dart';
import '../widgets/alerta.dart';
import '../widgets/vidro.dart';
import '../widgets/aviso_rapido.dart';

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
    final primaria = theme.colorScheme.primary;
    final apagado = theme.colorScheme.onSurface.withValues(alpha: 0.6);

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

    // Campo de Número e CEP: com o endereço novo escolhido, vira campo do
    // tema (rótulo visível, contorno); antes disso, é só leitura.
    Widget campoEditavel(String rotulo, String exemplo,
        TextEditingController controller, IconData icone) {
      if (!widget.alterouDados) {
        return _endRow(theme, rotulo,
            controller.text.isEmpty ? '—' : controller.text, icone);
      }
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: rotulo,
            hintText: exemplo,
            prefixIcon: Icon(icone, size: AppIconSize.sm),
          ),
        ),
      );
    }

    return FundoSuave(child: Scaffold(
      appBar: const CustomAppBar(title: 'Atualizar endereço'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Topo com a arte da ficha (padrão 2.2) ─────────────────────
            TopoArte(
              arte: Arte.de('rh'),
              icone: Icons.home_outlined,
              titulo: 'Atualizar endereço',
              subtitulo: 'Busque a rua ou o bairro, escolha o endereço '
                  'e informe o número e o CEP.',
              margem: const EdgeInsets.only(bottom: 16),
            ),

            // ── Campo de busca ────────────────────────────────────────────
            // O campo do tema (contorno, raio e rótulo), sem caixa própria.
            TypeAheadField<Endereco?>(
              controller: widget.controllerEnderecoNovo,
              errorBuilder: (context, error) => ListTile(
                leading: Icon(Icons.search_rounded,
                    size: AppIconSize.sm, color: primaria),
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
                  size: AppIconSize.sm,
                  color: apagado,
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
                  decoration: InputDecoration(
                    labelText: 'Buscar novo endereço',
                    hintText: 'Digite a rua ou bairro...',
                    prefixIcon:
                        const Icon(Icons.search_rounded, size: AppIconSize.sm),
                    suffixIcon: IconButton(
                      tooltip: 'Limpar',
                      onPressed: limpaDados,
                      icon: const Icon(Icons.close_rounded,
                          size: AppIconSize.sm),
                    ),
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
                  leading: Icon(Icons.location_on_outlined,
                      size: AppIconSize.sm, color: primaria),
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

            const SizedBox(height: 16),

            // ── Endereço atual / novo ─────────────────────────────────────
            CartaoVidro(
              arte: Arte.de('rh'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Cabeçalho (sem quadradinho tingido atrás do ícone, §2b)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                    child: Row(
                      children: [
                        ExcludeSemantics(
                          child: Icon(Icons.home_outlined,
                              size: AppIconSize.xs, color: primaria),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            widget.alterouDados
                                ? 'Novo endereço'
                                : 'Endereço atual',
                            style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                        if (widget.alterouDados)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: primaria.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              'Alterado',
                              style: TextStyle(
                                  color: primaria,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, indent: 14, endIndent: 14),

                  // Campos
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _endRow(
                            theme,
                            'Município',
                            widget.enderecoCompleto.municipio?.nome ?? '—',
                            Icons.location_city_outlined),
                        _endRow(
                            theme,
                            'Rua',
                            widget.enderecoCompleto.rua?.nome ?? '—',
                            Icons.map_outlined),
                        _endRow(
                            theme,
                            'Bairro',
                            widget.enderecoCompleto.bairro?.nome ?? '—',
                            Icons.holiday_village_outlined),
                        campoEditavel('Número', 'Ex: 123',
                            widget.controllerNumero, Icons.pin_outlined),
                        campoEditavel('CEP', 'Ex: 69314623',
                            widget.controllerCep,
                            Icons.local_post_office_outlined),
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
                  icon: const Icon(Icons.save_rounded, size: AppIconSize.sm),
                  label: const Text('Salvar alterações'),
                  // Cor e forma do filledButtonTheme (DESIGN §5).
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                  ),
                  onPressed: _saving
                      ? null
                      : () async {
                          if (widget.controllerNumero.text.isEmpty ||
                              widget.controllerCep.text.isEmpty) {
                            avisoAtencao(context, 'Preencha o número e o CEP');
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

                            alertaSucesso(context,
                                titulo: 'Sucesso',
                                texto: 'Endereço atualizado com sucesso!',
                                confirmar: 'OK', aoConfirmar: () {
                              Navigator.of(context).pop(); // fecha o alerta
                              Navigator.of(context).pop(); // volta para perfil
                            });
                          } catch (error) {
                            if (!mounted) return;
                            Navigator.of(context, rootNavigator: true).pop();

                            alertaErro(context,
                                titulo: 'Erro',
                                texto: 'Erro ao salvar. Tente novamente.',
                                confirmar: 'OK',
                                aoConfirmar: () => Navigator.of(context).pop());
                          } finally {
                            if (mounted) setState(() => _saving = false);
                          }
                        },
                ),
              ),
          ],
        ),
      ),
    ));
  }

  Widget _endRow(ThemeData theme, String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(
            child: Icon(icon,
                size: AppIconSize.xs,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
          ),
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

// ── Aviso de "salvando" ───────────────────────────────────────────────────────
// Caixa de vidro do app (CartaoVidro), com o indicador da plataforma.
class _EnderecoLoadingDialog extends StatelessWidget {
  const _EnderecoLoadingDialog();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Center(
        child: Semantics(
          liveRegion: true,
          label: 'Salvando. Aguarde um momento.',
          excludeSemantics: true,
          child: CartaoVidro(
            raio: 22,
            arte: Arte.de('rh'),
            padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 40,
                  height: 40,
                  child: CircularProgressIndicator.adaptive(),
                ),
                const SizedBox(height: 18),
                Text(
                  'Salvando…',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Aguarde um momento',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.62),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
