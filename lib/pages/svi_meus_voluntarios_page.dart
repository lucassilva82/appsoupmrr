import 'package:flutter/material.dart';

import '../models/svi_model.dart';
import '../services/escala_service.dart';
import '../utils/app_theme.dart';

// ── Meus Voluntários ──────────────────────────────────────────────────────────
/// Histórico dos serviços SVI em que o militar se candidatou.
/// Alimentada por GET /svi/meus-voluntarios (mais recente primeiro).
class SviMeusVoluntariosPage extends StatefulWidget {
  const SviMeusVoluntariosPage({Key? key}) : super(key: key);

  @override
  State<SviMeusVoluntariosPage> createState() => _SviMeusVoluntariosPageState();
}

class _SviMeusVoluntariosPageState extends State<SviMeusVoluntariosPage> {
  final EscalaService _service = EscalaService();

  bool _loading = true;
  String? _error;
  List<SviVoluntarioModel> _itens = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final itens = await _service.getSviMeusVoluntarios();
      if (!mounted) return;
      setState(() {
        _itens = itens;
        _loading = false;
      });
    } on EscalaServiceException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Não foi possível carregar seu histórico SVI.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.navy, AppColors.blue],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
        ),
        title: const Text(
          'Meus Voluntários',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 1.2,
          ),
        ),
      ),
      body: _buildBody(theme, isDark),
    );
  }

  Widget _buildBody(ThemeData theme, bool isDark) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.blue),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded,
                  size: 56, color: Colors.redAccent),
              const SizedBox(height: 16),
              Text(_error!,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _load,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.blue,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      );
    }

    if (_itens.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        color: AppColors.blue,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics()),
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 120, left: 32, right: 32),
              child: Column(
                children: [
                  Icon(Icons.volunteer_activism_rounded,
                      size: 64,
                      color: theme.colorScheme.onSurface.withOpacity(0.25)),
                  const SizedBox(height: 16),
                  Text(
                    'Nenhuma candidatura ainda',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Quando você se candidatar a uma vaga SVI, o serviço '
                    'aparecerá aqui.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.55)),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final grupos = _agruparPorMes(_itens);

    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.blue,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        itemCount: grupos.length,
        itemBuilder: (ctx, gi) {
          final grupo = grupos[gi];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.only(top: gi == 0 ? 0 : 12, bottom: 8),
                child: Text(
                  grupo.titulo,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface.withOpacity(0.55),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              for (var i = 0; i < grupo.itens.length; i++)
                _SviVoluntarioCard(
                  item: grupo.itens[i],
                  isDark: isDark,
                  theme: theme,
                  index: i,
                ),
            ],
          );
        },
      ),
    );
  }
}

// ── Agrupamento por mês ───────────────────────────────────────────────────────
class _GrupoMes {
  final String titulo;
  final List<SviVoluntarioModel> itens;
  _GrupoMes(this.titulo, this.itens);
}

List<_GrupoMes> _agruparPorMes(List<SviVoluntarioModel> itens) {
  const meses = [
    'Janeiro',
    'Fevereiro',
    'Março',
    'Abril',
    'Maio',
    'Junho',
    'Julho',
    'Agosto',
    'Setembro',
    'Outubro',
    'Novembro',
    'Dezembro',
  ];
  final grupos = <String, List<SviVoluntarioModel>>{};
  final ordem = <String>[];
  for (final item in itens) {
    DateTime? dt = DateTime.tryParse(item.dataInicio);
    if (dt == null && item.dataEscala.contains('/')) {
      final p = item.dataEscala.split('/');
      if (p.length == 3) dt = DateTime.tryParse('${p[2]}-${p[1]}-${p[0]}');
    }
    final chave = dt != null ? '${meses[dt.month - 1]} ${dt.year}' : 'Outros';
    if (!grupos.containsKey(chave)) {
      grupos[chave] = [];
      ordem.add(chave);
    }
    grupos[chave]!.add(item);
  }
  return ordem.map((k) => _GrupoMes(k, grupos[k]!)).toList();
}

// ── Card de histórico ─────────────────────────────────────────────────────────
class _SviVoluntarioCard extends StatelessWidget {
  final SviVoluntarioModel item;
  final bool isDark;
  final ThemeData theme;
  final int index;

  const _SviVoluntarioCard({
    required this.item,
    required this.isDark,
    required this.theme,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final (dia, mes) = _diaMesHist(item.dataInicio, item.dataEscala);
    final statusV = _statusEscalaVisual(item.statusEscala);
    final situacaoV = _situacaoVisual(item.situacao);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 240 + (index * 40).clamp(0, 300)),
      curve: Curves.easeOut,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child:
            Transform.translate(offset: Offset(0, (1 - t) * 12), child: child),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : const Color(0xFFE8EFFA),
          ),
          boxShadow: isDark
              ? []
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.blue.withOpacity(isDark ? 0.2 : 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(dia,
                      style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.blue)),
                  Text(mes,
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.blue.withOpacity(0.7),
                          letterSpacing: 0.5)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.funcao.isNotEmpty
                              ? item.funcao
                              : (item.titulo.isNotEmpty
                                  ? item.titulo
                                  : item.tipoServico),
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      _badge(statusV.$1, statusV.$2),
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (item.guarnicaoNome.isNotEmpty)
                    Text(
                      item.guarnicaoNome,
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.6)),
                      overflow: TextOverflow.ellipsis,
                    ),
                  const SizedBox(height: 2),
                  Text(
                    '${_hm(item.horarioInicio)} – ${_hm(item.horarioFim)}'
                    '${item.horas > 0 ? '  ·  ${item.horas}h' : ''}'
                    '${item.localAssuncao.isNotEmpty ? '  ·  ${item.localAssuncao}' : ''}',
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.45)),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _situacaoBadge(situacaoV.$1, situacaoV.$2),
                      if (item.voluntarioEm != null)
                        Text(
                          'Candidatou em ${_fmtData(item.voluntarioEm!)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                              fontSize: 11,
                              color:
                                  theme.colorScheme.onSurface.withOpacity(0.4)),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _badge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style:
            TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }

  Widget _situacaoBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 7, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }
}

String _hm(String h) => h.length >= 5 ? h.substring(0, 5) : h;

(String, String) _diaMesHist(String iso, String br) {
  const meses = [
    'JAN',
    'FEV',
    'MAR',
    'ABR',
    'MAI',
    'JUN',
    'JUL',
    'AGO',
    'SET',
    'OUT',
    'NOV',
    'DEZ',
  ];
  DateTime? dt = DateTime.tryParse(iso);
  if (dt == null && br.contains('/')) {
    final p = br.split('/');
    if (p.length == 3) dt = DateTime.tryParse('${p[2]}-${p[1]}-${p[0]}');
  }
  if (dt == null) return ('--', '');
  return (dt.day.toString().padLeft(2, '0'), meses[dt.month - 1]);
}

String _fmtData(DateTime dt) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(dt.day)}/${two(dt.month)} ${two(dt.hour)}:${two(dt.minute)}';
}

/// (label, cor) por status da escala.
(String, Color) _statusEscalaVisual(String status) {
  switch (status.toUpperCase()) {
    case 'PUBLICADA':
      return ('Publicada', const Color(0xFF059669));
    case 'CONCLUIDA':
    case 'CONCLUÍDA':
      return ('Concluída', AppColors.blue);
    case 'CANCELADA':
      return ('Cancelada', Colors.redAccent);
    case 'RASCUNHO':
      return ('Rascunho', Colors.blueGrey);
    default:
      return (status.isEmpty ? '—' : status, Colors.grey);
  }
}

/// (label, cor) pela situação do militar.
(String, Color) _situacaoVisual(String situacao) {
  switch (situacao.toUpperCase()) {
    case 'ATIVO':
      return ('Ativo', const Color(0xFF059669));
    case 'CANCELADO':
      return ('Cancelado', Colors.redAccent);
    default:
      return (situacao.isEmpty ? '—' : situacao, Colors.grey);
  }
}
