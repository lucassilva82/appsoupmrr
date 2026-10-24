import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/design/arte_cartao.dart';
import '../../core/enderecos.dart';
import '../../core/log/registro_log.dart';
import '../../utils/app_theme.dart';
import '../../widgets/custom_appbar.dart';
import '../../widgets/vidro.dart';

const _chave = 'rh.validar';

/// O que o militar digitou ou colou, já entendido: a página pública que
/// confere o documento (as mesmas que o QR Code abre e que nunca mudam de
/// endereço, APRENDIZADOS §22 e §44).
class Conferencia {
  const Conferencia(this.tipo, this.url);
  final String tipo; // certidao | contracheque
  final Uri url;
}

/// Aceita o link do QR Code ou o código impresso (com espaços ou traços).
/// Certidão tem 32 dígitos hexadecimais; contracheque, 16. Nulo = não é um
/// código que a PMRR emite.
Conferencia? entenderCodigo(String entrada) {
  var texto = entrada.trim();
  final link = Uri.tryParse(texto);
  if (link != null && link.hasScheme) {
    if (!link.path.endsWith('/verificar.php') && !link.path.endsWith('/conferir.php')) return null;
    texto = link.queryParameters['codigo'] ?? link.queryParameters['c'] ?? '';
  }
  final codigo = texto.toLowerCase().replaceAll(RegExp(r'[^0-9a-f]'), '');
  if (texto.replaceAll(RegExp(r'[\s.\-]'), '').length != codigo.length) return null;
  return switch (codigo.length) {
    32 => Conferencia('certidao', Uri.parse('$urlSigrh/certidoes/verificar.php').replace(queryParameters: {'codigo': codigo})),
    16 => Conferencia('contracheque', Uri.parse('$urlSigrh/doc/conferir.php').replace(queryParameters: {'c': codigo})),
    _ => null,
  };
}

/// Validar documento (P6): confere uma certidão ou um contracheque pelo
/// código. O QR Code impresso já abre a mesma página pela câmera do celular.
class ValidarDocumentoPage extends StatefulWidget {
  const ValidarDocumentoPage({super.key, this.abrir});

  /// Trocável nos testes.
  final Future<bool> Function(Uri url)? abrir;

  @override
  State<ValidarDocumentoPage> createState() => _ValidarDocumentoPageState();
}

class _ValidarDocumentoPageState extends State<ValidarDocumentoPage> {
  final _campo = TextEditingController();
  String? _erro;

  @override
  void dispose() {
    _campo.dispose();
    super.dispose();
  }

  Future<void> _colar() async {
    final d = await Clipboard.getData(Clipboard.kTextPlain);
    if (d?.text != null) setState(() => _campo.text = d!.text!.trim());
  }

  Future<void> _conferir() async {
    final c = entenderCodigo(_campo.text);
    if (c == null) {
      registrar('documento.validar', chave: _chave, resultado: 'falhou', codigo: 'VD-CODIGO');
      setState(() => _erro = 'Este não é um código de documento da PMRR. Confira os dígitos impressos '
          'junto do QR Code (certidão: 32; contracheque: 16). Código VD-CODIGO.');
      return;
    }
    setState(() => _erro = null);
    final abriu = await (widget.abrir ?? (u) => launchUrl(u, mode: LaunchMode.inAppBrowserView))(c.url);
    registrar('documento.validar', chave: _chave, resultado: abriu ? 'ok' : 'falhou', codigo: abriu ? null : 'VD-ABRIR',
        dados: {'tipo': c.tipo});
    if (!abriu && mounted) {
      setState(() => _erro = 'O aparelho não conseguiu abrir a página de conferência. Confira a internet e tente de novo. '
          'Código VD-ABRIR.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FundoSuave(
      child: Scaffold(
        appBar: const CustomAppBar(title: 'Validar documento'),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            // Topo com a arte da área (padrão 2.2), com a explicação do QR.
            TopoArte(
              arte: Arte.de('rh'),
              icone: Icons.qr_code_2_rounded,
              titulo: 'Validar documento',
              subtitulo: 'Para conferir pelo QR Code, aponte a câmera do celular para ele: a página de conferência '
                  'abre sozinha. Sem o QR, digite ou cole aqui o código impresso no documento.',
              margem: const EdgeInsets.only(bottom: 16),
            ),
            // O formulário numa seção com a arte discreta.
            CartaoVidro(
              arte: Arte.de('rh'),
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                TextField(
                  controller: _campo,
                  autocorrect: false,
                  textInputAction: TextInputAction.go,
                  onSubmitted: (_) => _conferir(),
                  decoration: InputDecoration(
                    labelText: 'Código ou link do documento',
                    errorText: _erro,
                    errorMaxLines: 4,
                    suffixIcon: IconButton(
                      tooltip: 'Colar',
                      icon: const Icon(Icons.content_paste_rounded, size: AppIconSize.sm),
                      onPressed: _colar,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _conferir,
                  style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                  child: const Text('Conferir'),
                ),
              ]),
            ),
            const SizedBox(height: 12),
            Text('A conferência mostra se o documento é válido, vencido ou revogado. Nada é guardado no seu aparelho.',
                style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
