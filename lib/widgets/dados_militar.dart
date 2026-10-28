import 'package:flutter/material.dart';
import 'package:projetonovo/utils/app_theme.dart';
import '../core/design/arte_cartao.dart';
import 'package:projetonovo/widgets/dados_situacao_funcional.dart';

import '../models/militar.dart';
import '../utils/app_routes.dart';
import 'card_image_militar.dart';
import 'dados_contato.dart';
import 'dados_endereco.dart';
import 'dados_principal.dart';
import 'vidro.dart';

/// Formata datas do banco (YYYY-MM-DD) para o padrão BR DD/MM/AAAA.
String _fmtDataBr(String? s) {
  if (s == null || s.trim().isEmpty) return '';
  final v = s.trim();
  try {
    final d = DateTime.parse(v);
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  } catch (_) {
    final m = RegExp(r'^(\d{4})[-/](\d{2})[-/](\d{2})').firstMatch(v);
    if (m != null) return '${m.group(3)}/${m.group(2)}/${m.group(1)}';
    return v;
  }
}

class DadosMilitar extends StatefulWidget {
  final Militar militar;

  const DadosMilitar({Key? key, required this.militar}) : super(key: key);

  @override
  State<DadosMilitar> createState() => _DadosMilitarState();
}

class _DadosMilitarState extends State<DadosMilitar> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaria = theme.colorScheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Topo com a arte da área (padrão 2.2) ─────────────────────────
        // Nome, posto e lotação no cartão com a arte cheia de "Minha vida
        // funcional", com a foto e os dois dados rápidos logo abaixo.
        TopoArte(
          arte: Arte.de('rh'),
          icone: Icons.badge_outlined,
          titulo: widget.militar.nomeCompleto,
          subtitulo: _linhaPosto(),
          child: Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.85), width: 2),
                ),
                child: ClipOval(
                  child: SizedBox(
                    width: 64,
                    height: 64,
                    child: CardImageMilitar(urlImage: widget.militar.imageUrl),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _parTopo('Matrícula', widget.militar.matricula),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _parTopo('Incorporação',
                    _fmtDataBr(widget.militar.dataIncorporacao)),
              ),
            ],
          ),
        ),

        // ── Seções de dados ───────────────────────────────────────────────
        _sectionCard(
          context: context,
          icon: Icons.person_outline_rounded,
          title: 'Dados Principais',
          isDark: isDark,
          arte: Arte.de('rh'),
          child: DadosPrincipal(militar: widget.militar),
        ),

        _sectionCard(
          context: context,
          icon: Icons.phone_outlined,
          title: 'Contato',
          isDark: isDark,
          arte: Arte.de('rh'),
          child: DadosContato(
            militar: widget.militar,
          ),
        ),

        _sectionCard(
          context: context,
          icon: Icons.home_outlined,
          title: 'Endereço',
          isDark: isDark,
          arte: Arte.de('rh'),
          trailingAction: IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            tooltip: 'Editar endereço',
            icon: Icon(Icons.edit_outlined,
                size: AppIconSize.sm, color: primaria),
            onPressed: () => Navigator.of(context).pushNamed(
              AppRoutes.ENDERECO_PAGE,
              arguments: widget.militar,
            ),
          ),
          child: DadosEndereco(militar: widget.militar),
        ),

        _sectionCard(
          context: context,
          icon: Icons.work_history_outlined,
          title: 'Situação Funcional',
          isDark: isDark,
          arte: Arte.de('rh'),
          child: DadosSituacaoFuncional(militar: widget.militar),
        ),

        const SizedBox(height: 24),
      ],
    );
  }

  /// Posto, quadro e lotação numa linha só, para o subtítulo do topo.
  String? _linhaPosto() {
    final posto = '${widget.militar.postoGraduacao} ${widget.militar.quadro}'
        .trim();
    final partes = [posto, widget.militar.subUnidade.trim()]
        .where((p) => p.isNotEmpty)
        .toList();
    return partes.isEmpty ? null : partes.join(' · ');
  }

  /// Rótulo e valor sobre a arte (o fundo é sempre escuro: texto branco).
  Widget _parTopo(String rotulo, String valor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          rotulo.toUpperCase(),
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
            color: Colors.white.withValues(alpha: 0.72),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          valor.isEmpty ? '—' : valor,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _sectionCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required Widget child,
    required bool isDark,
    Widget? trailingAction,
    Arte? arte,
  }) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: CartaoVidro(
        raio: 16,
        arte: arte,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabeçalho da seção
            Padding(
              padding: EdgeInsets.fromLTRB(
                  14, trailingAction != null ? 4 : 12, 4, trailingAction != null ? 0 : 8),
              child: Row(
                children: [
                  // Sem quadradinho tingido atrás do ícone (DESIGN §2b).
                  ExcludeSemantics(
                    child: Icon(icon,
                        size: AppIconSize.xs,
                        color: theme.colorScheme.primary),
                  ),
                  const SizedBox(width: 10),
                  Text(title,
                      style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold, fontSize: 13)),
                  const Spacer(),
                  if (trailingAction != null) trailingAction,
                ],
              ),
            ),
            const Divider(height: 1, indent: 14, endIndent: 14),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: child,
            ),
          ],
        ),
      ),
    );
  }
}
