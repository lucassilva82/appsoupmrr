import 'package:flutter/material.dart';
import 'package:projetonovo/utils/app_theme.dart';
import 'package:projetonovo/widgets/dados_situacao_funcional.dart';
import 'package:quickalert/quickalert.dart';

import '../models/militar.dart';
import '../services/dados_sql.dart';
import '../utils/app_routes.dart';
import 'card_image_militar.dart';
import 'dados_contato.dart';
import 'dados_endereco.dart';
import 'dados_principal.dart';

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
    const primaryBlue = AppColors.blue;
    final DadosSql dadosSql = DadosSql();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Hero banner + avatar ─────────────────────────────────────────
        Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            // Banner gradiente
            Container(
              width: double.infinity,
              height: 90,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF1976D2), Color(0xFF002154)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            // Avatar centralizado sobrepondo o banner
            Positioned(
              bottom: -40,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color:
                        isDark ? theme.scaffoldBackgroundColor : Colors.white,
                    width: 4,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: SizedBox(
                    width: 90,
                    height: 90,
                    child: CardImageMilitar(urlImage: widget.militar.imageUrl),
                  ),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 48), // espaço para o avatar que sobressai

        // ── Nome + Posto + Unidade ────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              Center(
                child: Text(
                  widget.militar.nomeCompleto,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 4),
              Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  decoration: BoxDecoration(
                    color: primaryBlue.withValues(alpha: isDark ? 0.18 : 0.10),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${widget.militar.postoGraduacao} ${widget.militar.quadro}',
                    style: const TextStyle(
                      color: primaryBlue,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.location_on_outlined,
                        size: 14,
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        widget.militar.subUnidade,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.6),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // ── Chips de stats rápidos ────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              _statChip(
                  context: context,
                  icon: Icons.badge_outlined,
                  label: 'Matrícula',
                  value: widget.militar.matricula,
                  isDark: isDark),
              const SizedBox(width: 8),
              _statChip(
                  context: context,
                  icon: Icons.calendar_today_outlined,
                  label: 'Incorporação',
                  value: widget.militar.dataIncorporacao,
                  isDark: isDark),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // ── Seções de dados ───────────────────────────────────────────────
        _sectionCard(
          context: context,
          icon: Icons.person_outline_rounded,
          title: 'Dados Principais',
          isDark: isDark,
          child: DadosPrincipal(militar: widget.militar),
        ),

        _sectionCard(
          context: context,
          icon: Icons.phone_outlined,
          title: 'Contato',
          isDark: isDark,
          child: DadosContato(
            militar: widget.militar,
          ),
        ),

        _sectionCard(
          context: context,
          icon: Icons.home_outlined,
          title: 'Endereço',
          isDark: isDark,
          trailingAction: IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: const Icon(Icons.edit_outlined, size: 18, color: primaryBlue),
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
          child: DadosSituacaoFuncional(militar: widget.militar),
        ),

        const SizedBox(height: 24),
      ],
    );
  }

  Widget _statChip({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String value,
    required bool isDark,
  }) {
    final theme = Theme.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? theme.colorScheme.surface : const Color(0xFFF5F8FF),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? const Color(0xFF30363D) : const Color(0xFFE0E7F0),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon,
                    size: 14,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.45)),
                const SizedBox(width: 4),
                Text(label,
                    style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.5))),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required Widget child,
    required bool isDark,
    Widget? trailingAction,
  }) {
    final theme = Theme.of(context);
    const primaryBlue = AppColors.blue;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? theme.colorScheme.surface : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? const Color(0xFF30363D) : const Color(0xFFE8EFFA),
            width: 1,
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabeçalho da seção
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 12, 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color:
                          primaryBlue.withValues(alpha: isDark ? 0.18 : 0.10),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, size: 15, color: primaryBlue),
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
