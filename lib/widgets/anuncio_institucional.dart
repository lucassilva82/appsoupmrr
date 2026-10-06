import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AnuncioInstitucional
//
// Anúncio em imagem exibido por cima da página inicial, uma vez a cada
// abertura do app. O usuário fecha no X; tocar na imagem abre o destino.
//
// Fonte: documento Firestore `appConfig/anuncio`
// Campos:
//   ativo   : bool    — liga/desliga o anúncio
//   imagem  : String  — URL http(s) da imagem
//   tipo    : String  — (opcional) o que o toque na imagem abre:
//                       'link' | 'whatsapp'. Vazio ou outro valor = nada.
//   destino : String  — valor usado pelo `tipo`:
//                       link     → URL http(s), ex.: "https://www.pm.rr.gov.br"
//                       whatsapp → telefone com ou sem formatação e com ou
//                                  sem o 55, ex.: "95 99129-8238"
//
// Para trocar o anúncio basta editar o documento no console do Firebase.
// ─────────────────────────────────────────────────────────────────────────────

class AnuncioInstitucional {
  AnuncioInstitucional._();

  /// Garante uma exibição por abertura do app: a home pode ser remontada
  /// (ex.: logout e login de novo) sem o anúncio reaparecer.
  static bool _jaExibido = false;

  static Future<void> mostrarSeAtivo(BuildContext context) async {
    if (_jaExibido) return;
    _jaExibido = true;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('appConfig')
          .doc('anuncio')
          .get();
      final data = doc.data();
      if (data == null || data['ativo'] != true) return;

      final imagem = (data['imagem'] ?? '').toString().trim();
      if (!imagem.startsWith('http://') && !imagem.startsWith('https://')) {
        return;
      }
      final destino = _destino(data);

      // Baixa a imagem antes de abrir o diálogo, para não mostrar um quadro
      // vazio carregando. Se o download falhar, o anúncio não aparece.
      if (!context.mounted) return;
      var falhou = false;
      await precacheImage(
        CachedNetworkImageProvider(imagem),
        context,
        onError: (e, _) {
          falhou = true;
          debugPrint('AnuncioInstitucional: erro ao baixar imagem: $e');
        },
      );
      if (falhou || !context.mounted) return;

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _AnuncioDialog(imagem: imagem, destino: destino),
      );
    } catch (e) {
      debugPrint('AnuncioInstitucional: $e');
    }
  }

  /// O que abrir ao tocar na imagem, conforme `tipo` + `destino`.
  /// Retorna null (toque sem ação) quando o par não formar um destino válido.
  static Uri? _destino(Map<String, dynamic> data) {
    final tipo = (data['tipo'] ?? '').toString().trim().toLowerCase();
    final valor = (data['destino'] ?? '').toString().trim();

    switch (tipo) {
      case 'link':
        if (!valor.startsWith('http://') && !valor.startsWith('https://')) {
          return null;
        }
        return Uri.tryParse(valor);
      case 'whatsapp':
        // Mantém só os dígitos e completa o DDI 55 quando vier só DDD + número.
        final digitos = valor.replaceAll(RegExp(r'\D'), '');
        if (digitos.isEmpty) return null;
        final telefone = digitos.length <= 11 ? '55$digitos' : digitos;
        return Uri.parse('https://wa.me/$telefone');
      default:
        return null;
    }
  }
}

class _AnuncioDialog extends StatelessWidget {
  final String imagem;
  final Uri? destino;

  const _AnuncioDialog({required this.imagem, this.destino});

  // Sem canLaunchUrl: no Android 11+ ele responde false para links http(s)
  // porque o manifesto não declara <queries> de navegador.
  Future<void> _abrirDestino() async {
    try {
      await launchUrl(destino!, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('AnuncioInstitucional: não abriu $destino: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final tela = MediaQuery.of(context).size;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: tela.height * 0.8),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // ── Imagem ───────────────────────────────────────────────────
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: GestureDetector(
                onTap: destino == null ? null : _abrirDestino,
                child: CachedNetworkImage(
                  imageUrl: imagem,
                  fit: BoxFit.contain,
                ),
              ),
            ),

            // ── Botão fechar ─────────────────────────────────────────────
            Positioned(
              top: 8,
              right: 8,
              child: Material(
                color: Colors.black.withOpacity(0.55),
                shape: const CircleBorder(),
                child: IconButton(
                  tooltip: 'Fechar',
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
