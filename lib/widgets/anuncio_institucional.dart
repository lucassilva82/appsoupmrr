import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/config/app_config.dart';
import '../core/log/registro_log.dart';
import '../core/navegacao/abrir_funcao.dart';
import '../features/servicos/servicos_page.dart' show menuEmUso;
import '../models/auth_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AnuncioInstitucional
//
// Cartaz em imagem por cima da página inicial. O usuário fecha no X; tocar na
// imagem abre o destino.
//
// Fonte (2.2): a chave `anuncio` do app_config, editada no painel (tela
// "Anúncio de abertura", tabela soupm_anuncio):
//   id, titulo (texto alternativo), imagem (https), tipo (nenhum | link |
//   funcao), destino (o https do link ou a chave do menu), frequencia
//   (abertura = toda abertura; dia = uma vez por dia; uma_vez = só até ser
//   visto) e versao (muda quando o anúncio muda; a frequência recomeça).
// Sem a chave no app_config (API ou tabela ainda sem o anúncio), vale o
// documento antigo do Firestore `appConfig/anuncio` (ativo, imagem, tipo
// link|whatsapp, destino), como na 2.1.x.
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
      final cfg = RepositorioConfig.atual;
      final _Anuncio? anuncio;
      if (cfg.anuncioDoPainel) {
        anuncio = cfg.anuncio == null ? null : _Anuncio.doPainel(cfg.anuncio!);
      } else {
        final doc = await FirebaseFirestore.instance.collection('appConfig').doc('anuncio').get();
        anuncio = _Anuncio.doFirestore(doc.data());
      }
      if (anuncio == null) return;
      if (!await anuncio.podeMostrar()) return;

      // Baixa a imagem antes de abrir o diálogo, para não mostrar um quadro
      // vazio carregando. Se o download falhar, o anúncio não aparece.
      if (!context.mounted) return;
      var falhou = false;
      await precacheImage(
        CachedNetworkImageProvider(anuncio.imagem),
        context,
        onError: (e, _) {
          falhou = true;
          debugPrint('AnuncioInstitucional: erro ao baixar imagem: $e');
        },
      );
      if (falhou || !context.mounted) return;

      await anuncio.marcarVisto();
      if (!context.mounted) return;
      registrar('anuncio.ver', dados: {'id': anuncio.id, 'versao': anuncio.versao});
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _AnuncioDialog(anuncio: anuncio!),
      );
    } catch (e) {
      debugPrint('AnuncioInstitucional: $e');
    }
  }
}

/// O anúncio já conferido: imagem válida, o que o toque faz e a frequência.
class _Anuncio {
  _Anuncio({
    required this.imagem,
    this.titulo = '',
    this.link,
    this.funcao,
    this.id = 0,
    this.versao = 0,
    this.frequencia = 'abertura',
  });

  final String imagem;
  final String titulo;
  final Uri? link;

  /// Chave do menu (ex.: rh.contracheques) que o toque abre.
  final String? funcao;
  final int id;
  final int versao;
  final String frequencia;

  String get _chaveVisto => 'anuncio_visto_${id}_$versao';

  static _Anuncio? doPainel(Map<String, dynamic> j) {
    final imagem = '${j['imagem'] ?? ''}'.trim();
    if (!imagem.startsWith('https://')) return null;
    final tipo = '${j['tipo'] ?? ''}';
    final destino = '${j['destino'] ?? ''}'.trim();
    return _Anuncio(
      imagem: imagem,
      titulo: '${j['titulo'] ?? ''}'.trim(),
      link: tipo == 'link' && destino.startsWith('https://') ? Uri.tryParse(destino) : null,
      funcao: tipo == 'funcao' && destino.isNotEmpty ? destino : null,
      id: (j['id'] as num?)?.toInt() ?? 0,
      versao: (j['versao'] as num?)?.toInt() ?? 0,
      frequencia: '${j['frequencia'] ?? 'abertura'}',
    );
  }

  static _Anuncio? doFirestore(Map<String, dynamic>? data) {
    if (data == null || data['ativo'] != true) return null;
    final imagem = (data['imagem'] ?? '').toString().trim();
    if (!imagem.startsWith('http://') && !imagem.startsWith('https://')) return null;
    return _Anuncio(imagem: imagem, link: _destinoFirestore(data));
  }

  /// Frequência do painel, guardada no aparelho por id + versão.
  Future<bool> podeMostrar() async {
    if (frequencia == 'abertura') return true;
    try {
      final visto = (await SharedPreferences.getInstance()).getString(_chaveVisto);
      if (visto == null) return true;
      if (frequencia == 'uma_vez') return false;
      return visto != _hoje(); // dia
    } catch (_) {
      return true;
    }
  }

  Future<void> marcarVisto() async {
    if (frequencia == 'abertura') return;
    try {
      await (await SharedPreferences.getInstance()).setString(_chaveVisto, _hoje());
    } catch (_) {}
  }

  static String _hoje() {
    final d = DateTime.now();
    return '${d.year}-${d.month}-${d.day}';
  }

  /// O destino do documento antigo do Firestore: link ou WhatsApp.
  static Uri? _destinoFirestore(Map<String, dynamic> data) {
    final tipo = (data['tipo'] ?? '').toString().trim().toLowerCase();
    final valor = (data['destino'] ?? '').toString().trim();
    switch (tipo) {
      case 'link':
        if (!valor.startsWith('http://') && !valor.startsWith('https://')) return null;
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
  final _Anuncio anuncio;

  const _AnuncioDialog({required this.anuncio});

  bool get _temDestino => anuncio.link != null || anuncio.funcao != null;

  // Sem canLaunchUrl: no Android 11+ ele responde false para links http(s)
  // porque o manifesto não declara <queries> de navegador.
  Future<void> _abrirDestino(BuildContext context) async {
    registrar('anuncio.tocar', dados: {'id': anuncio.id, 'destino': anuncio.funcao ?? 'link'});
    final link = anuncio.link;
    if (link != null) {
      try {
        await launchUrl(link, mode: LaunchMode.externalApplication);
      } catch (e) {
        debugPrint('AnuncioInstitucional: não abriu $link: $e');
      }
      return;
    }
    // Função do app: fecha o cartaz e abre a função pela chave do menu.
    final gestor = context.read<Auth>().isSuperUser;
    final item = itemPorChave(anuncio.funcao!, menu: menuEmUso(RepositorioConfig.atual, gestor: gestor));
    final nav = Navigator.of(context);
    nav.pop();
    if (item != null && nav.context.mounted) await abrirFuncao(nav.context, item, origem: 'anuncio');
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
              child: Semantics(
                image: true,
                button: _temDestino,
                label: anuncio.titulo.isEmpty ? 'Anúncio' : anuncio.titulo,
                child: GestureDetector(
                  onTap: _temDestino ? () => _abrirDestino(context) : null,
                  child: CachedNetworkImage(
                    imageUrl: anuncio.imagem,
                    fit: BoxFit.contain,
                  ),
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
