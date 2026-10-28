import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/config/app_config.dart';
import '../core/rede/api_client.dart';
import '../models/auth_model.dart';
import '../utils/app_theme.dart';

/// Faixa no topo da Início quando o servidor não respondeu e a tela mostra o
/// que estava guardado (§5.3). Diz desde quando e deixa tentar de novo.
class FaixaSemConexao extends StatefulWidget {
  const FaixaSemConexao({super.key});

  @override
  State<FaixaSemConexao> createState() => _FaixaSemConexaoState();
}

class _FaixaSemConexaoState extends State<FaixaSemConexao> {
  bool _tentando = false;

  Future<void> _tentar() async {
    setState(() => _tentando = true);
    final auth = context.read<Auth>();
    await carregarAppConfig(api: ApiClient(), matricula: auth.matricula, senha: auth.password);
    if (mounted) setState(() => _tentando = false);
  }

  static String _quando(DateTime? d) {
    if (d == null) return 'Mostrando o padrão do app.';
    final agora = DateTime.now();
    final hm = '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    final mesmoDia = d.year == agora.year && d.month == agora.month && d.day == agora.day;
    return mesmoDia
        ? 'Mostrando o que foi atualizado hoje às $hm.'
        : 'Mostrando o que foi atualizado em ${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')} às $hm.';
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: RepositorioConfig.semConexao,
      builder: (context, sem, _) {
        if (!sem) return const SizedBox.shrink();
        final theme = Theme.of(context);
        final escuro = theme.brightness == Brightness.dark;
        final cor = escuro ? const Color(0xFFFFC233) : const Color(0xFF8A5A00);
        return Semantics(
          liveRegion: true,
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
            decoration: BoxDecoration(
              color: cor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: cor.withValues(alpha: 0.45)),
            ),
            child: Row(children: [
              Icon(Icons.cloud_off_rounded, size: AppIconSize.sm, color: cor),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Sem conexão com o servidor. ${_quando(RepositorioConfig.atual.recebidoEm)}',
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface),
                ),
              ),
              SizedBox(
                height: 44,
                child: TextButton(
                  onPressed: _tentando ? null : _tentar,
                  child: Text(_tentando ? 'Tentando…' : 'Tentar de novo'),
                ),
              ),
            ]),
          ),
        );
      },
    );
  }
}
