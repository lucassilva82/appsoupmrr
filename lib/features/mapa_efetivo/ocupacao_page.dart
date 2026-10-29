import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';

import '../../core/design/arte_cartao.dart';
import '../../core/design/esqueleto.dart';
import '../../core/erros/estado_erro.dart';
import '../../core/erros/falha_app.dart';
import '../../core/log/registro_log.dart';
import '../../core/rede/api_client.dart';
import '../../models/auth_model.dart';
import '../../utils/app_theme.dart';
import '../../widgets/custom_appbar.dart';
import '../../widgets/vidro.dart';
import 'mapa_efetivo.dart';

MapaEfetivoRepositorio repositorioMapaEfetivo(BuildContext context) {
  final auth = context.read<Auth>();
  return MapaEfetivoRepositorio(
    api: ApiClient(),
    matricula: auth.matricula ?? '',
    senhaMd5: md5.convert(utf8.encode(auth.password ?? '')).toString(),
  );
}

/// Ocupação do efetivo: previsto × existente, descendo da PMRR até a
/// subunidade e abrindo por posto (docs/SOUPM_2_2.md, Mapa da Força).
class OcupacaoView extends StatefulWidget {
  const OcupacaoView({
    super.key,
    this.repositorio,
    this.comando,
    this.unidade,
    this.subunidade,
    this.tituloFallback,
  });

  final MapaEfetivoRepositorio? repositorio;
  final String? comando;
  final String? unidade;
  final String? subunidade;
  final String? tituloFallback;

  @override
  State<OcupacaoView> createState() => _OcupacaoViewState();
}

class _OcupacaoViewState extends State<OcupacaoView> {
  EfetivoEscopo? _dados;
  FalhaApp? _falha;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() => _falha = null);
    final repo = widget.repositorio ?? repositorioMapaEfetivo(context);
    try {
      final d = await repo.carregar(
        comando: widget.comando,
        unidade: widget.unidade,
        subunidade: widget.subunidade,
      );
      if (!mounted) return;
      // O banner do topo do Mapa da Força lê daqui, para a tela e o banner
      // nunca mostrarem números diferentes da mesma coisa (APRENDIZADOS §52).
      if (widget.comando == null && widget.unidade == null && widget.subunidade == null) {
        MapaEfetivoRepositorio.pmrr.value = d;
      }
      setState(() => _dados = d);
      registrar('mapa.ocupacao_ver',
          chave: 'gestao.mapa_forca',
          dados: {'escopo': d.nivel, 'filhos': d.filhos.length});
    } on FalhaApp catch (f) {
      registrarErro(f, tela: 'Ocupação do efetivo');
      if (!mounted) return;
      setState(() => _falha = f);
    }
  }

  void _descer(ItemEfetivo item) {
    final nivel = _dados?.filhoNivel;
    if (nivel == null || nivel == 'posto') return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => OcupacaoPage(
        titulo: item.nome,
        comando: nivel == 'comando' ? item.chave : widget.comando,
        unidade: nivel == 'unidade' ? item.chave : widget.unidade,
        subunidade: nivel == 'subunidade' ? item.chave : widget.subunidade,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    if (_falha != null && _dados == null) {
      return EstadoErro(
        falha: _falha!,
        aoTentar: _carregar,
        tela: 'Ocupação do efetivo',
        chave: 'gestao.mapa_forca',
      );
    }
    final d = _dados;
    if (d == null) return const EsqueletoLista(itens: 5);

    return RefreshIndicator(
      onRefresh: _carregar,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          _Hero(escopo: d),
          if (d.fonteSuspeita) ...[
            const SizedBox(height: 10),
            const _AvisoFonte(),
          ],
          if (d.falhas.isNotEmpty) ...[
            const SizedBox(height: 10),
            _AvisoFalhas(falhas: d.falhas),
          ],
          if (d.filhos.isNotEmpty) ...[
            const SizedBox(height: 14),
            _Secao(titulo: _rotuloNivel(d.filhoNivel), contagem: d.filhos.length),
            const SizedBox(height: 8),
            for (final f in d.filhos)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _LinhaItem(
                  item: f,
                  mostrarPct: !d.fonteSuspeita,
                  aoTocar: d.filhoNivel == 'posto' ? null : () => _descer(f),
                ),
              ),
          ],
          if (d.postos.isNotEmpty) ...[
            const SizedBox(height: 14),
            _Secao(titulo: 'Por posto e graduação', contagem: d.postos.length),
            const SizedBox(height: 8),
            for (final p in d.postos)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _LinhaItem(item: p, mostrarPct: !d.fonteSuspeita),
              ),
          ],
          if (d.filhos.isEmpty && d.postos.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 24),
              child: Text(
                'Sem detalhamento para este escopo.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.62)),
              ),
            ),
        ],
      ),
    );
  }

  static String _rotuloNivel(String? n) => switch (n) {
        'comando' => 'Por grande comando',
        'unidade' => 'Por unidade',
        'subunidade' => 'Por subunidade',
        _ => 'Detalhamento',
      };
}

/// A subtela: o mesmo corpo, com barra e título do escopo aberto.
class OcupacaoPage extends StatelessWidget {
  const OcupacaoPage({
    super.key,
    required this.titulo,
    this.comando,
    this.unidade,
    this.subunidade,
  });

  final String titulo;
  final String? comando;
  final String? unidade;
  final String? subunidade;

  @override
  Widget build(BuildContext context) {
    return FundoSuave(
      child: Scaffold(
        appBar: CustomAppBar(title: titulo),
        body: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: OcupacaoView(
            comando: comando,
            unidade: unidade,
            subunidade: subunidade,
            tituloFallback: titulo,
          ),
        ),
      ),
    );
  }
}

// ── Peças ────────────────────────────────────────────────────────────────────

/// O cartão de abertura: um número grande (o percentual), e em volta o que ele
/// significa. A gramática é a do DESIGN §2b — o peso fica no número, o resto é
/// apoio.
class _Hero extends StatelessWidget {
  const _Hero({required this.escopo});

  final EfetivoEscopo escopo;

  @override
  Widget build(BuildContext context) {
    final o = escopo.total;
    final mostrarPct = !escopo.fonteSuspeita && o.pct != null;
    return CartaoArte(
      arte: Arte.de('gestao'),
      padding: const EdgeInsets.all(16),
      child: Builder(builder: (context) {
        final theme = Theme.of(context);
        final mudo = theme.colorScheme.onSurface.withValues(alpha: 0.74);
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            escopo.titulo.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              letterSpacing: 0.6,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 6),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  mostrarPct ? '${o.pct!.toStringAsFixed(1)}%' : '${o.existente}',
                  style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w700, height: 1),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(mostrarPct ? 'ocupado' : 'militares',
                  style: TextStyle(fontSize: 11, color: mudo)),
              if (o.faltam > 0)
                Text('faltam ${o.faltam}',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.error)),
              if (o.temExcedente)
                Text('excedente de ${o.excedente}',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.douradoTexto(theme.brightness))),
            ]),
          ]),
          const SizedBox(height: 10),
          BarraOcupacao(ocupacao: o, altura: 10),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: _Par(rotulo: 'Existente', valor: '${o.existente}')),
            Expanded(child: _Par(rotulo: 'Previsto', valor: o.semPrevisao ? '—' : '${o.previsto}')),
            Expanded(
                child: _Par(
                    rotulo: o.temExcedente ? 'Excedente' : 'Faltam',
                    valor: o.semPrevisao ? '—' : '${o.temExcedente ? o.excedente : o.faltam}')),
          ]),
        ]);
      }),
    );
  }
}

class _Par extends StatelessWidget {
  const _Par({required this.rotulo, required this.valor});
  final String rotulo;
  final String valor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(rotulo,
          style: TextStyle(
              fontSize: 10.5,
              letterSpacing: 0.4,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.68))),
      Text(valor, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
    ]);
  }
}

class _Secao extends StatelessWidget {
  const _Secao({required this.titulo, required this.contagem});
  final String titulo;
  final int contagem;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(children: [
      Expanded(
        child: Text(titulo.toUpperCase(),
            style: TextStyle(
                fontSize: 11,
                letterSpacing: 0.6,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.primary)),
      ),
      Text('$contagem',
          style: TextStyle(
              fontSize: 11, color: theme.colorScheme.onSurface.withValues(alpha: 0.62))),
    ]);
  }
}

class _LinhaItem extends StatelessWidget {
  const _LinhaItem({required this.item, required this.mostrarPct, this.aoTocar});

  final ItemEfetivo item;
  final bool mostrarPct;
  final VoidCallback? aoTocar;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return CartaoVidro(
      raio: 14,
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      onTap: aoTocar,
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(item.nome,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            if (item.descricao != null && item.descricao!.isNotEmpty)
              Text(item.descricao!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 11.5,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.62))),
            const SizedBox(height: 7),
            BarraOcupacao(ocupacao: item.ocupacao),
            const SizedBox(height: 5),
            LinhaOcupacao(ocupacao: item.ocupacao, mostrarPct: mostrarPct),
          ]),
        ),
        if (aoTocar != null)
          Icon(Icons.chevron_right_rounded,
              size: AppIconSize.sm,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.45)),
      ]),
    );
  }
}

/// Quando a previsão do banco parece ser a própria contagem de gente, a tela
/// diz isso em vez de mostrar 100% em tudo (APRENDIZADOS §27 e §52).
class _AvisoFonte extends StatelessWidget {
  const _AvisoFonte();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return CartaoVidro(
      raio: 14,
      tingimento: AppColors.douradoTexto(theme.brightness),
      child: Row(children: [
        Icon(Icons.info_outline_rounded,
            size: AppIconSize.sm, color: AppColors.douradoTexto(theme.brightness)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'A previsão de vagas cadastrada está igual à contagem de militares, '
            'então o percentual de ocupação não é mostrado. A conferência do '
            'quadro no SIGRH foi pedida à DRH.',
            style: TextStyle(
                fontSize: 12.5,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.86)),
          ),
        ),
      ]),
    );
  }
}

class _AvisoFalhas extends StatelessWidget {
  const _AvisoFalhas({required this.falhas});
  final List<String> falhas;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return CartaoVidro(
      raio: 14,
      tingimento: theme.colorScheme.error,
      child: Row(children: [
        Icon(Icons.warning_amber_rounded, size: AppIconSize.sm, color: theme.colorScheme.error),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'Parte do detalhamento não pôde ser conferida no SIGRH '
            '(${falhas.join(', ')}). O que aparece acima está completo; o que '
            'faltou não foi contado como zero.',
            style: TextStyle(
                fontSize: 12.5,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.86)),
          ),
        ),
      ]),
    );
  }
}
