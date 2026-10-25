import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../core/log/registro_log.dart';
import '../features/servicos/servicos_page.dart' show menuEmUso;
import '../core/navegacao/abrir_funcao.dart';
import 'package:provider/provider.dart';

import '../core/config/app_config.dart';
import '../core/design/arte_cartao.dart';
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
      'texto': 'Confira seu Plano de Férias e acompanhe suas próximas folgas programadas.',
      'icone': '🏖️',
      'tipo': 'dica',
      'ordem': 1,
      'ativo': true,
    },
    {
      'texto': 'Use o Mapa da Força para visualizar a distribuição de militares em cada unidade da PMRR.',
      'icone': '📍',
      'tipo': 'dica',
      'ordem': 2,
      'ativo': true,
      'perfil': 'admin',
    },
    {
      'texto': 'Ative a biometria em Perfil para um acesso mais rápido e seguro ao SouPMRR.',
      'icone': '🔐',
      'tipo': 'dica',
      'ordem': 3,
      'ativo': true,
    },
    {
      'texto': 'O módulo de Escalas exibe sua escala de serviço atualizada direto do sistema da PMRR.',
      'icone': '📅',
      'tipo': 'dica',
      'ordem': 4,
      'ativo': true,
    },
    {
      'texto': 'Consulte certidões e documentos oficiais diretamente pelo app, sem precisar ir ao quartel.',
      'icone': '📄',
      'tipo': 'dica',
      'ordem': 5,
      'ativo': true,
    },
    {
      'texto': 'Mantenha as notificações ativadas para receber avisos importantes da PMRR em tempo real.',
      'icone': '🔔',
      'tipo': 'aviso',
      'ordem': 6,
      'ativo': true,
    },
    {
      'texto': 'SouPMRR Módulo 2.0: nova interface, mais recursos e desempenho melhorado para você.',
      'icone': '🚀',
      'tipo': 'novidade',
      'ordem': 7,
      'ativo': true,
    },
    {
      'texto': 'Acesse seu extrato de proventos e vantagens no módulo Contracheque a qualquer momento.',
      'icone': '💰',
      'tipo': 'dica',
      'ordem': 8,
      'ativo': true,
    },
    {
      'texto': 'O módulo SVI permite adesão ao Serviço Voluntário Interno diretamente pelo app.',
      'icone': '🤝',
      'tipo': 'dica',
      'ordem': 9,
      'ativo': true,
    },
    {
      'texto': 'Dúvidas ou problemas? Acesse Configurações → Suporte Técnico para falar com o DTI.',
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
    // Dicas do painel (app_config, `home.dicas`): quando vêm, valem elas e o
    // Firestore nem é lido. Ícone é chave do catálogo, nunca emoji.
    final doPainel = RepositorioConfig.atual.bloco('home.dicas')?.itens ?? const [];
    if (doPainel.isNotEmpty) {
      setState(() => _dicas = doPainel);
      _startTimer();
      return;
    }
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
      final lista =
          s.docs.isEmpty ? _defaults : s.docs.where((d) => d.data()['ativo'] == true).map((d) => d.data()).toList();
      setState(() => _dicas = lista);
      _startTimer();
    });
  }

  /// Quantas dicas estão na tela agora (as do painel, quando vêm, valem).
  int _total = 0;

  void _startTimer() {
    _timer?.cancel();
    // Passam sozinhas a cada 7 s; paradas com "Reduzir movimento" (o militar
    // desliza ou toca nos pontos para trocar).
    _timer = Timer.periodic(const Duration(seconds: 7), (_) {
      if (!mounted || _total <= 1 || MediaQuery.disableAnimationsOf(context)) return;
      setState(() => _current = (_current + 1) % _total);
    });
  }

  void _ir(int delta) {
    if (_total <= 1) return;
    setState(() => _current = (_current + delta) % _total);
    _startTimer(); // o tempo recomeça depois de trocar à mão
  }

  Future<void> _abrirDestino(String chave) async {
    registrar('inicio.card_tocar', chave: 'home.dicas', dados: {'destino': chave});
    final gestor = context.read<Auth>().isSuperUser;
    final item = itemPorChave(chave, menu: menuEmUso(RepositorioConfig.atual, gestor: gestor));
    if (item != null && mounted) await abrirFuncao(context, item, origem: 'dica');
  }

  @override
  void dispose() {
    _sub?.cancel();
    _timer?.cancel();
    super.dispose();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isSuperUser = Provider.of<Auth>(context, listen: false).isSuperUser;

    // As do painel valem mesmo quando o app_config chega depois de a tela
    // abrir (na abertura ele ainda pode estar a caminho).
    final doPainel = RepositorioConfig.atual.bloco('home.dicas')?.itens ?? const [];
    final dicasFiltradas = (doPainel.isNotEmpty ? doPainel : _dicas).where((d) {
      final perfil = (d['perfil'] ?? 'todos') as String;
      if (perfil == 'admin' && !isSuperUser) return false;
      return true;
    }).toList();

    if (dicasFiltradas.isEmpty) return const SizedBox.shrink();
    _total = dicasFiltradas.length;
    if (_timer == null) _startTimer();

    // Uma linha discreta com a arte da dica (protótipo `.dica`): ícone na
    // cor de destaque e o texto em cinza claro. Com mais de uma dica, elas
    // se revezam no mesmo lugar, sem pontos (um só cartão, sem disputar com
    // o carrossel dos comunicados).
    final d = dicasFiltradas[_current % dicasFiltradas.length];
    final icone = iconePorNome('${d['icone']}') ?? Icons.tips_and_updates_outlined;
    final semMovimento = MediaQuery.of(context).disableAnimations;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Semantics(
        container: true,
        label: 'Dica ${_current % _total + 1} de $_total: ${d['texto'] ?? ''}',
        hint: _total > 1 ? 'Deslize para ver a próxima' : null,
        onIncrease: _total > 1 ? () => _ir(1) : null,
        onDecrease: _total > 1 ? () => _ir(_total - 1) : null,
        excludeSemantics: true,
        child: GestureDetector(
          // Deslizar troca de dica, como nos comunicados.
          onHorizontalDragEnd: (e) {
            final v = e.primaryVelocity ?? 0;
            if (v.abs() < 120) return;
            _ir(v < 0 ? 1 : _total - 1);
          },
          child: CartaoArte(
            // Dica com função (painel: `destino`) abre a função ao tocar.
            onTap: '${d['destino'] ?? ''}'.isEmpty ? null : () => _abrirDestino('${d['destino']}'),
            arte: Arte.de('dc'),
            raio: 16,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: AnimatedSwitcher(
              duration: semMovimento ? Duration.zero : const Duration(milliseconds: 320),
              child: Row(
                key: ValueKey(_current),
                children: [
                  Icon(icone, size: AppIconSize.sm, color: const Color(0xFF42A5F5)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${d['texto'] ?? ''}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.35,
                        color: Colors.white.withValues(alpha: 0.78),
                      ),
                    ),
                  ),
                  // Quantas dicas há e qual está na tela: antes elas se
                  // revezavam sem sinal nenhum e pareciam uma só.
                  if (_total > 1) ...[
                    const SizedBox(width: 10),
                    Column(mainAxisSize: MainAxisSize.min, children: [
                      for (var i = 0; i < _total && i < 8; i++)
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          margin: const EdgeInsets.symmetric(vertical: 1.5),
                          width: 4,
                          height: i == _current % _total ? 10 : 4,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: i == _current % _total ? .85 : .30),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                    ]),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
