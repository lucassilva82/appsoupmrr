import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/auth_model.dart';
import '../utils/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// WidgetDicasApp
//
// Balão de dicas / avisos / novidades que fica logo abaixo dos cards de
// Comandante e Sub-Comandante na página inicial.
//
// Fonte: coleção Firestore `dicas_app`
// Campos de cada documento:
//   texto  : String   — texto exibido
//   icone  : String   — emoji ou caractere visual
//   tipo   : String   — 'dica' | 'aviso' | 'novidade' | 'suporte'
//   ativo  : bool     — se deve aparecer (filtra no cliente)
//   ordem  : int      — ordem de exibição
//   perfil : String   — 'todos' (padrão) | 'admin'  (só para isSuperUser)
//
// Para adicionar novas dicas: basta inserir documentos na coleção
// `dicas_app` no console do Firebase com os campos acima.
// ─────────────────────────────────────────────────────────────────────────────

class WidgetDicasApp extends StatefulWidget {
  const WidgetDicasApp({Key? key}) : super(key: key);

  @override
  State<WidgetDicasApp> createState() => _WidgetDicasAppState();
}

class _WidgetDicasAppState extends State<WidgetDicasApp> {
  final PageController _pageCtrl = PageController();
  int _current = 0;
  Timer? _timer;
  List<Map<String, dynamic>> _dicas = [];

  static final _col = FirebaseFirestore.instance.collection('dicas_app');

  /// Guardada para ser cancelada no dispose: sem isso, cada vez que a home
  /// era remontada sobrava um listener ativo no Firestore.
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;

  // Dicas padrão — usadas apenas como fallback de exibição local quando a
  // coleção do Firestore está vazia (nunca gravadas de volta no banco).
  static const _defaults = [
    {
      'texto':
          'Confira seu Plano de Férias e acompanhe suas próximas folgas programadas.',
      'icone': '🏖️',
      'tipo': 'dica',
      'ordem': 1,
      'ativo': true,
    },
    {
      'texto':
          'Use o Mapa da Força para visualizar a distribuição de militares em cada unidade da PMRR.',
      'icone': '📍',
      'tipo': 'dica',
      'ordem': 2,
      'ativo': true,
      'perfil': 'admin',
    },
    {
      'texto':
          'Ative a biometria em Configurações para um acesso mais rápido e seguro ao SouPMRR.',
      'icone': '🔐',
      'tipo': 'dica',
      'ordem': 3,
      'ativo': true,
    },
    {
      'texto':
          'O módulo de Escalas exibe sua escala de serviço atualizada direto do sistema da PMRR.',
      'icone': '📅',
      'tipo': 'dica',
      'ordem': 4,
      'ativo': true,
    },
    {
      'texto':
          'Consulte certidões e documentos oficiais diretamente pelo app, sem precisar ir ao quartel.',
      'icone': '📄',
      'tipo': 'dica',
      'ordem': 5,
      'ativo': true,
    },
    {
      'texto':
          'Mantenha as notificações ativadas para receber avisos importantes da PMRR em tempo real.',
      'icone': '🔔',
      'tipo': 'aviso',
      'ordem': 6,
      'ativo': true,
    },
    {
      'texto':
          'SouPMRR Módulo 2.0: nova interface, mais recursos e desempenho melhorado para você.',
      'icone': '🚀',
      'tipo': 'novidade',
      'ordem': 7,
      'ativo': true,
    },
    {
      'texto':
          'Acesse seu extrato de proventos e vantagens no módulo Contracheque a qualquer momento.',
      'icone': '💰',
      'tipo': 'dica',
      'ordem': 8,
      'ativo': true,
    },
    {
      'texto':
          'O módulo SVI permite adesão ao Serviço Voluntário Interno diretamente pelo app.',
      'icone': '🤝',
      'tipo': 'dica',
      'ordem': 9,
      'ativo': true,
    },
    {
      'texto':
          'Dúvidas ou problemas? Acesse Configurações → Suporte Técnico para falar com o DTI.',
      'icone': '💬',
      'tipo': 'suporte',
      'ordem': 10,
      'ativo': true,
    },
  ];

  @override
  void initState() {
    super.initState();
    _initDicas();
  }

  Future<void> _initDicas() async {
    // Escuta em tempo real — filtra e ordena no cliente.
    // OBS: o seed automático de documentos foi removido daqui — cada
    // cliente que abrisse o app com a coleção vazia tentava semeá-la,
    // e como a checagem "está vazia?" + escrita não é atômica, várias
    // instâncias do app rodando ao mesmo tempo duplicavam as dicas
    // padrão (ex.: 6 execuções concorrentes geraram 6 cópias de cada
    // dica). Se a coleção estiver vazia, usamos `_defaults` apenas para
    // exibição local, sem gravar nada no Firestore.
    _sub = _col.orderBy('ordem').snapshots().listen((s) {
      if (!mounted) return;
      final lista = s.docs.isEmpty
          ? _defaults
          : s.docs
              .where((d) => d.data()['ativo'] == true)
              .map((d) => d.data())
              .toList();
      setState(() => _dicas = lista);
      _startTimer();
    });
  }

  void _startTimer() {
    _timer?.cancel();
    if (_dicas.length <= 1) return;
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || _dicas.isEmpty) return;
      final next = (_current + 1) % _dicas.length;
      _pageCtrl.animateToPage(
        next,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _timer?.cancel();
    _pageCtrl.dispose();
    super.dispose();
  }

  // ── Helpers de estilo ─────────────────────────────────────────────────────

  Color _tipoColor(String tipo) {
    switch (tipo) {
      case 'aviso':
        return Colors.orange;
      case 'novidade':
        return const Color(0xFF2E7D32);
      case 'suporte':
        return AppColors.lightBlue;
      default:
        return AppColors.blue;
    }
  }

  String _tipoLabel(String tipo) {
    switch (tipo) {
      case 'aviso':
        return 'AVISO';
      case 'novidade':
        return 'NOVIDADE';
      case 'suporte':
        return 'SUPORTE';
      default:
        return 'DICA';
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isSuperUser = Provider.of<Auth>(context, listen: false).isSuperUser;

    final dicasFiltradas = _dicas.where((d) {
      final perfil = (d['perfil'] ?? 'todos') as String;
      if (perfil == 'admin' && !isSuperUser) return false;
      return true;
    }).toList();

    if (dicasFiltradas.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        children: [
          // ── Card balão ───────────────────────────────────────────────────
          Container(
            height: 76,
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : const Color(0xFFE8EEF6),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: PageView.builder(
              controller: _pageCtrl,
              onPageChanged: (i) => setState(() => _current = i),
              itemCount: dicasFiltradas.length,
              itemBuilder: (_, i) {
                final d = dicasFiltradas[i];
                final tipo = (d['tipo'] ?? 'dica') as String;
                final cor = _tipoColor(tipo);
                return Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(
                    children: [
                      // Ícone (largura fixa — protege o layout caso o campo
                      // 'icone' venha do Firestore com um valor malformado
                      // e mais longo que um emoji único).
                      SizedBox(
                        width: 30,
                        child: Text(
                          d['icone'] ?? '💡',
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.clip,
                          style: const TextStyle(fontSize: 26),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Texto + label
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: cor.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    _tipoLabel(tipo),
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: cor,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              d['texto'] ?? '',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.35,
                                color: theme.colorScheme.onSurface
                                    .withOpacity(0.85),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Chevron sutil
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 16,
                        color: theme.colorScheme.onSurface.withOpacity(0.2),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 6),

          // ── Dots indicadores ─────────────────────────────────────────────
          // Envolvido em scroll horizontal: com muitas dicas cadastradas no
          // Firestore, a linha de pontos pode ficar mais larga que a tela.
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(dicasFiltradas.length, (i) {
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 280),
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  width: i == _current ? 18.0 : 5.0,
                  height: 5,
                  decoration: BoxDecoration(
                    color: i == _current
                        ? AppColors.blue
                        : AppColors.blue.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(3),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}
