import 'package:flutter/material.dart';
import 'package:projetonovo/widgets/custom_appbar.dart';
import 'package:provider/provider.dart';

import '../models/auth_model.dart';
import '../utils/app_theme.dart';
import '../widgets/declaracao_widget.dart';

class DeclaracoesPage extends StatefulWidget {
  const DeclaracoesPage({Key? key}) : super(key: key);

  @override
  State<DeclaracoesPage> createState() => _DeclaracoesPageState();
}

class _DeclaracoesPageState extends State<DeclaracoesPage> {
  final int anoInicial = 2024;

  List<int> get listaAnos {
    final anoMaximo = DateTime.now().year - 1;
    List<int> anos = [];
    for (int ano = anoMaximo; ano >= anoInicial; ano--) {
      anos.add(ano);
    }
    if (anos.isEmpty) {
      anos.add(DateTime.now().year - 1);
    }
    return anos;
  }

  late String _anoSelecionado;

  @override
  void initState() {
    super.initState();
    _anoSelecionado = (DateTime.now().year - 1).toString();
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<Auth>(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bgTop = isDark ? const Color(0xFF0E1B2E) : const Color(0xFFE8F1FF);
    final bgBottom = isDark ? AppColors.darkBg : AppColors.lightBg;

    return Scaffold(
      appBar: CustomAppBar(title: 'Declarações'),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [bgTop, bgBottom],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeroCard(theme),
                const SizedBox(height: 14),
                _buildYearSelector(theme),
                const SizedBox(height: 14),
                DeclaracaoWidget(
                  key: ValueKey(_anoSelecionado),
                  cpf: auth.cpf ?? 'CPF Não Encontrado',
                  ano: _anoSelecionado,
                ),
                const SizedBox(height: 14),
                _buildComplianceCard(theme),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeroCard(ThemeData theme) {
    final base = int.tryParse(_anoSelecionado) ?? (DateTime.now().year - 1);
    final calendario = base + 1;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.navy, AppColors.blue],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.verified_user_rounded, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text(
                'Painel Anual de Declarações',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Acompanhe o status, envie pendências e mantenha tudo em dia em um só lugar.',
            style: TextStyle(
              color: Color(0xFFE3F2FD),
              fontSize: 13,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _heroTag('Ano base: $base'),
              _heroTag('Ano calendário: $calendario'),
              _heroTag('Atualização em tempo real'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroTag(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.30)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildYearSelector(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Selecione o ciclo de declaração',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: listaAnos.map((anoInt) {
              final anoStr = anoInt.toString();
              final selected = anoStr == _anoSelecionado;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                margin: const EdgeInsets.only(right: 10),
                child: Material(
                  color: selected
                      ? theme.colorScheme.primary
                      : theme.cardColor.withValues(alpha: 0.86),
                  borderRadius: BorderRadius.circular(18),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () => setState(() => _anoSelecionado = anoStr),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      child: Text(
                        '$anoStr/${anoInt + 1}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: selected
                              ? theme.colorScheme.onPrimary
                              : theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildComplianceCard(ThemeData theme) {
    final textColor = theme.colorScheme.onSurface.withValues(alpha: 0.80);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.gpp_good_rounded,
                  color: theme.colorScheme.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'Aviso de Responsabilidade',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Você é responsável pela veracidade, precisão e atualização dos dados informados. '
            'Informações incorretas ou falsas podem gerar suspensão ou exclusão de acesso, conforme os Termos de Uso.',
            style: theme.textTheme.bodyMedium?.copyWith(
              height: 1.45,
              color: textColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Após envio, os dados seguem para análise e recebimento interno.',
            style: theme.textTheme.bodyMedium?.copyWith(
              height: 1.45,
              color: textColor,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.withValues(alpha: 0.22)),
            ),
            child: Text(
              'LGPD - Lei n° 13.709/2018',
              textAlign: TextAlign.center,
              style: theme.textTheme.labelLarge?.copyWith(
                color: Colors.red.shade700,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
