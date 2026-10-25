import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:projetonovo/core/design/arte_cartao.dart';
import 'package:projetonovo/core/design/folha_arte.dart';
import 'package:flutter/services.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/auth_model.dart';
import '../services/certidao_service.dart';
import '../utils/app_theme.dart';
import '../widgets/alerta.dart';
import '../widgets/aviso_rapido.dart';
import '../widgets/cartao_painel.dart';
import '../widgets/custom_appbar.dart';
import '../widgets/dialogo_confirmacao.dart';
import '../widgets/vidro.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CertidoesPage
//
// Um botão "Emitir nova certidão" leva à escolha do tipo; o militar confirma
// a Declaração de Conferência de Dados e acompanha as etapas no botão. Ao
// terminar volta para cá, onde a certidão nova entra na lista com destaque e
// o aviso diz para qual e-mail (oculto) foi a cópia em PDF.
// O documento sai da API com QR Code de autenticidade e vale 30 dias; fica
// guardado no aparelho enquanto vale (CertidaoService).
//
// Os 3 tipos da intranet e a Certidão de Comportamento. Sem internet, a tela
// ainda mostra e compartilha as certidões já guardadas.
// ─────────────────────────────────────────────────────────────────────────────

/// O que cada certidão comprova, para o militar escolher sem abrir o PDF.
const _descricoes = <String, ({IconData icone, String texto})>{
  'tempo_servico': (
    icone: Icons.timelapse_rounded,
    texto: 'Tempo de efetivo serviço na PMRR, ano a ano, e tempo averbado.',
  ),
  'vinculo_funcional': (
    icone: Icons.verified_user_rounded,
    texto: 'Comprova que você é policial militar, com posto, quadro e data '
        'de inclusão.',
  ),
  'comportamento': (
    icone: Icons.military_tech_rounded,
    texto: 'Seu comportamento atual, o histórico de classificação e as '
        'punições registradas.',
  ),
  'ficha_funcional': (
    icone: Icons.badge_rounded,
    texto: 'Seus dados pessoais e funcionais, documentos, conta, endereço, '
        'promoções e dependentes.',
  ),
};

/// Ícones que a API pode pedir (campo "icone" de soupm_certidao_tipo).
/// Chave desconhecida cai no ícone do tipo e, por fim, num documento.
const _icones = <String, IconData>{
  'tempo': Icons.timelapse_rounded,
  'escudo': Icons.verified_user_rounded,
  'medalha': Icons.military_tech_rounded,
  'ficha': Icons.badge_rounded,
  'documento': Icons.description_rounded,
  'relogio': Icons.schedule_rounded,
  'calendario': Icons.event_rounded,
  'diploma': Icons.workspace_premium_rounded,
  'balanca': Icons.balance_rounded,
  'casa': Icons.home_rounded,
  'saude': Icons.medical_services_rounded,
  'arma': Icons.gpp_good_rounded,
};

IconData _iconeDe(TipoCertidao t) =>
    _icones[t.icone] ?? _descricoes[t.tipo]?.icone ?? Icons.description_rounded;

String _descricaoDe(TipoCertidao t) =>
    t.descricao ?? _descricoes[t.tipo]?.texto ?? '';

/// Texto da tela vindo da API, ou o padrão local (sem internet / API antiga).
String _texto(PainelCertidoes? p, String chave, String padrao) =>
    p?.textos[chave] ?? padrao;

/// A Ficha traz dados que pedem cuidado antes de sair do aparelho.
const _tipoSensivel = 'ficha_funcional';

String _doisDigitos(int n) => n.toString().padLeft(2, '0');
String _data(DateTime d) =>
    '${_doisDigitos(d.day)}/${_doisDigitos(d.month)}/${d.year}';
String _dataHora(DateTime d) =>
    '${_data(d)} às ${_doisDigitos(d.hour)}:${_doisDigitos(d.minute)}';

class CertidoesPage extends StatefulWidget {
  const CertidoesPage({Key? key}) : super(key: key);

  @override
  State<CertidoesPage> createState() => _CertidoesPageState();
}

class _CertidoesPageState extends State<CertidoesPage> {
  PainelCertidoes? _painel;
  List<CertidaoGuardada> _guardadas = const [];
  bool _carregando = true;
  String? _erro;

  /// Última emissão desta visita: destaca o cartão e mostra o aviso do e-mail.
  EmissaoCertidao? _recente;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _carregar());
  }

  Auth get _auth => Provider.of<Auth>(context, listen: false);
  String get _matricula => _auth.matricula ?? '';
  String get _senhaMd5 => _auth.generateMd5(_auth.password ?? '');

  /// Guardadas primeiro (funcionam sem internet), depois o painel da API.
  Future<void> _carregar() async {
    setState(() {
      _carregando = true;
      _erro = null;
    });

    final guardadas = await CertidaoService.guardadas(_matricula);
    if (!mounted) return;
    setState(() => _guardadas = guardadas);

    try {
      final painel = await CertidaoService.painel(
          matricula: _matricula, senhaMd5: _senhaMd5);
      // Certidão revogada no servidor (pela DRH, ou substituída em outro
      // aparelho) não pode continuar aqui como se valesse.
      final revogadas = await CertidaoService.sincronizar(_matricula, painel);
      final atuais = revogadas.isEmpty
          ? null
          : await CertidaoService.guardadas(_matricula);
      if (!mounted) return;
      setState(() {
        _painel = painel;
        if (atuais != null) _guardadas = atuais;
      });
      if (revogadas.isNotEmpty) {
        final r = revogadas.first;
        avisoRapido(
          context,
          titulo: revogadas.length == 1
              ? '${r.certidao.titulo} cancelada'
              : '${revogadas.length} certidões foram canceladas',
          texto: r.motivo ?? 'Ela não vale mais e saiu do aparelho.',
          icone: Icons.block_rounded,
          cor: Theme.of(context).colorScheme.error,
          duracao: const Duration(seconds: 6),
        );
      }
    } on CertidaoErro catch (e) {
      if (mounted) setState(() => _erro = e.mensagem);
    } catch (e) {
      debugPrint('[CERTIDAO] painel: $e');
      if (mounted) {
        setState(() => _erro =
            'Sem conexão com o servidor. Suas certidões guardadas continuam '
                'disponíveis abaixo.');
      }
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  // ── Emitir ────────────────────────────────────────────────────────────────

  Future<void> _novaCertidao() async {
    final painel = _painel;
    if (painel == null) {
      await _carregar();
      return;
    }

    final emitida = await Navigator.of(context).push<EmissaoCertidao>(
      MaterialPageRoute(
        builder: (_) => _EscolherCertidaoPage(
          painel: painel,
          emitir: (tipo) => CertidaoService.emitir(
            matricula: _matricula,
            senhaMd5: _senhaMd5,
            tipo: tipo.tipo,
            declaracaoVersao: painel.declaracaoVersao,
          ),
        ),
      ),
    );

    if (emitida == null || !mounted) return;
    final guardadas = await CertidaoService.guardadas(_matricula);
    if (!mounted) return;
    // A troca de página termina antes de o cartão novo entrar na lista.
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (!mounted) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _guardadas = guardadas;
      _recente = emitida;
    });
  }

  Future<void> _abrir(CertidaoGuardada c) async {
    final removida = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => CertidaoVisualizarPage(
        certidao: c,
        // Guardada antes de a API mandar o nome curto: usa o do painel.
        tituloBarra: c.tituloCurto ??
            _painel?.tipos
                .where((t) => t.tipo == c.tipo)
                .map((t) => t.tituloCurto)
                .firstOrNull,
      ),
    ));
    if (removida != true || !mounted) return;
    final guardadas = await CertidaoService.guardadas(_matricula);
    if (!mounted) return;
    setState(() {
      _guardadas = guardadas;
      if (_recente?.certidao.codigo == c.codigo) _recente = null;
    });
    avisoSucesso(
      context,
      'Certidão removida do aparelho',
      texto: c.emailMascarado != null
          ? 'Ela continua válida e disponível no seu e-mail.'
          : 'Ela continua válida para quem já a recebeu.',
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return FundoSuave(
      child: Scaffold(
        appBar: const CustomAppBar(title: 'Certidões'),
        body: RefreshIndicator(
          onRefresh: _carregar,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics()),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              TopoArte(
                arte: Arte.de('rh'),
                icone: Icons.verified_outlined,
                titulo: 'Certidões',
                subtitulo: _texto(
                    _painel,
                    'topo',
                    'Emita suas certidões na hora. Elas ficam salvas aqui '
                        'por 30 dias e também chegam no seu e-mail.'),
                margem: const EdgeInsets.only(bottom: 16),
              ),
              ..._botaoNova(),
              const SizedBox(height: 24),
              _Rotulo('Minhas certidões'),
              const SizedBox(height: 10),
              if (_recente != null) ...[
                _EntradaAnimada(
                  key: ValueKey('aviso-${_recente!.certidao.codigo}'),
                  child: _AvisoEmail(envio: _recente!.email),
                ),
                const SizedBox(height: 10),
              ],
              ..._listaGuardadas(),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _botaoNova() {
    final theme = Theme.of(context);

    if (_painel == null && !_carregando) {
      return [
        _Aviso(
          cor: theme.colorScheme.error,
          icone: Icons.cloud_off_rounded,
          texto: _erro ?? 'Não foi possível carregar as certidões.',
        ),
        const SizedBox(height: 10),
        Align(
          child: OutlinedButton.icon(
            onPressed: _carregar,
            icon: const Icon(Icons.refresh_rounded, size: AppIconSize.sm),
            label: const Text('Tentar de novo'),
          ),
        ),
      ];
    }

    // Serviço tirado do ar pelo administrador: aviso no lugar do botão. As
    // certidões já emitidas continuam abrindo e compartilhando.
    final painel = _painel;
    if (painel != null && !painel.servicoAtivo) {
      return [
        _Aviso(
          cor: kCorAtencao,
          icone: Icons.pause_circle_outline_rounded,
          titulo: painel.servicoTitulo ?? 'Emissão de certidões indisponível',
          texto: painel.servicoMensagem ??
              'A emissão de certidões está temporariamente suspensa.',
        ),
      ];
    }

    // A ação principal da tela: botão cheio com a cor, a altura e o raio do
    // tema (DESIGN §5). A tela não redefine estilo.
    return [
      ElevatedButton.icon(
        onPressed: _painel == null ? null : _novaCertidao,
        icon: _painel == null
            ? const SizedBox(
                width: AppIconSize.xs,
                height: AppIconSize.xs,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white70),
              )
            : const Icon(Icons.add_rounded, size: AppIconSize.md),
        label: Text(_texto(_painel, 'botao', 'Emitir nova certidão')),
      ),
    ];
  }

  List<Widget> _listaGuardadas() {
    final theme = Theme.of(context);

    if (_guardadas.isEmpty) {
      return [
        CartaoVidro(
          padding: kPaddingCartao,
          arte: Arte.de('rh'),
          child: Row(
            children: [
              Icon(Icons.folder_open_rounded,
                  size: AppIconSize.md,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.55)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _texto(_painel, 'lista_vazia',
                      'As certidões que você emitir ficam aqui por 30 dias.'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ];
    }

    final codigoNovo = _recente?.certidao.codigo;
    return [
      for (final c in _guardadas) ...[
        c.codigo == codigoNovo
            ? _EntradaAnimada(
                key: ValueKey('nova-${c.codigo}'),
                atraso: const Duration(milliseconds: 120),
                destacar: true,
                child: _CartaoGuardada(certidao: c, aoTocar: () => _abrir(c)),
              )
            : _CartaoGuardada(
                key: ValueKey(c.codigo), certidao: c, aoTocar: () => _abrir(c)),
        const SizedBox(height: 10),
      ],
    ];
  }
}

// ── Escolha do tipo ─────────────────────────────────────────────────────────

class _EscolherCertidaoPage extends StatelessWidget {
  final PainelCertidoes painel;
  final Future<EmissaoCertidao> Function(TipoCertidao tipo) emitir;

  const _EscolherCertidaoPage({required this.painel, required this.emitir});

  Future<void> _escolher(BuildContext context, TipoCertidao tipo) async {
    if (!tipo.disponivel) {
      await alertaAviso(context,
          titulo: tipo.situacao == SituacaoCertidao.desativado
              ? 'Temporariamente indisponível'
              : tipo.titulo,
          texto: tipo.motivo ?? 'Esta certidão não está disponível.',
          arte: Arte.de('rh'));
      return;
    }

    final emitida = await showModalBottomSheet<EmissaoCertidao>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      // Durante a emissão a folha não fecha por toque fora nem por arrasto.
      isDismissible: false,
      enableDrag: false,
      // O desenho é o da FolhaArte (padrão 2.2), montado dentro da folha.
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: .55),
      builder: (_) => _FolhaEmissao(
        tipo: tipo,
        painel: painel,
        emitir: () => emitir(tipo),
      ),
    );

    if (emitida != null && context.mounted) Navigator.of(context).pop(emitida);
  }

  @override
  Widget build(BuildContext context) {
    return FundoSuave(
      child: Scaffold(
        appBar: const CustomAppBar(title: 'Emitir certidão'),
        body: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            TopoArte(
              arte: Arte.de('rh'),
              icone: Icons.post_add_rounded,
              titulo: 'Emitir certidão',
              subtitulo: _texto(
                  painel, 'escolha', 'Escolha a certidão que você precisa.'),
              margem: const EdgeInsets.only(bottom: 16),
            ),
            for (final tipo in painel.tipos) ...[
              _CartaoTipo(tipo: tipo, aoTocar: () => _escolher(context, tipo)),
              const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Entrada animada ─────────────────────────────────────────────────────────
// Sobe e aparece; com destacar, a borda acende e apaga devagar, para o olho
// achar a certidão que acabou de chegar.

class _EntradaAnimada extends StatefulWidget {
  final Widget child;
  final Duration atraso;
  final bool destacar;

  const _EntradaAnimada({
    super.key,
    required this.child,
    this.atraso = Duration.zero,
    this.destacar = false,
  });

  @override
  State<_EntradaAnimada> createState() => _EntradaAnimadaState();
}

class _EntradaAnimadaState extends State<_EntradaAnimada>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: widget.destacar ? 2400 : 450),
  );

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(widget.atraso, () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primaria = Theme.of(context).colorScheme.primary;
    final total = _c.duration!.inMilliseconds;
    // A entrada ocupa os primeiros 450 ms; o resto é o brilho apagando.
    final fimEntrada = (450 / total).clamp(0.0, 1.0);
    final entrada = CurvedAnimation(
        parent: _c, curve: Interval(0, fimEntrada, curve: Curves.easeOutCubic));
    final brilho = CurvedAnimation(
        parent: _c, curve: Interval(fimEntrada, 1, curve: Curves.easeIn));

    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (context, child) {
        final t = entrada.value;
        Widget w = child!;
        if (widget.destacar) {
          final a = (1 - brilho.value) * (t);
          w = DecoratedBox(
            position: DecorationPosition.foreground,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: primaria.withValues(alpha: 0.85 * a), width: 1.4),
            ),
            child: w,
          );
        }
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, 28 * (1 - t)),
            child: Transform.scale(scale: 0.97 + 0.03 * t, child: w),
          ),
        );
      },
    );
  }
}

// ── Aviso do e-mail depois da emissão ───────────────────────────────────────

class _AvisoEmail extends StatelessWidget {
  final EnvioEmailCertidao envio;
  const _AvisoEmail({required this.envio});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final verde = isDark ? AppColors.sucessoEscuro : AppColors.sucesso;

    if (envio.enviado) {
      return _Aviso(
        cor: verde,
        icone: Icons.mark_email_read_rounded,
        texto: 'Certidão emitida. Enviamos uma cópia em PDF para '
            '${envio.emailMascarado ?? 'o seu e-mail'}.',
      );
    }
    return _Aviso(
      cor: theme.colorScheme.primary,
      icone: Icons.info_outline_rounded,
      texto: 'Certidão emitida e salva no app. '
          '${envio.aviso ?? 'Não foi possível enviar a cópia por e-mail.'}',
    );
  }
}

// ── Rótulo de seção ─────────────────────────────────────────────────────────

class _Rotulo extends StatelessWidget {
  final String texto;
  const _Rotulo(this.texto);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      header: true,
      child: Text(
        texto.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}

// ── Cartão de um tipo de certidão ───────────────────────────────────────────

class _CartaoTipo extends StatelessWidget {
  final TipoCertidao tipo;
  final VoidCallback aoTocar;
  const _CartaoTipo({required this.tipo, required this.aoTocar});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final apagado = !tipo.disponivel;
    final foraDoAr = tipo.situacao == SituacaoCertidao.desativado;
    final corTexto = theme.colorScheme.onSurface;

    return Semantics(
      button: true,
      label: apagado
          ? '${tipo.titulo}, ${foraDoAr ? 'temporariamente indisponível' : 'indisponível'}'
          : 'Emitir ${tipo.titulo}',
      excludeSemantics: true,
      child: Opacity(
        opacity: apagado ? 0.6 : 1,
        child: CartaoVidro(
          onTap: aoTocar,
          padding: kPaddingCartao,
          arte: Arte.de('rh'),
          child: Row(
            children: [
              Icon(_iconeDe(tipo),
                  size: AppIconSize.lg, color: theme.colorScheme.primary),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tipo.titulo,
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    if (foraDoAr) ...[
                      const SizedBox(height: 6),
                      _SeloForaDoAr(),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      apagado
                          ? (tipo.motivo ?? 'Indisponível.')
                          : _descricaoDe(tipo),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: corTexto.withValues(alpha: 0.72),
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                foraDoAr
                    ? Icons.pause_circle_outline_rounded
                    : (apagado
                        ? Icons.lock_outline_rounded
                        : Icons.chevron_right_rounded),
                size: AppIconSize.md,
                color: corTexto.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Selo âmbar do tipo tirado do ar pelo administrador (soupm_certidao_tipo).
class _SeloForaDoAr extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: kCorAtencao.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: kCorAtencao.withValues(alpha: 0.35)),
      ),
      child: const Text(
        'Temporariamente indisponível',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: kCorAtencao,
        ),
      ),
    );
  }
}

// ── Cartão de uma certidão guardada ─────────────────────────────────────────

class _CartaoGuardada extends StatelessWidget {
  final CertidaoGuardada certidao;
  final VoidCallback aoTocar;
  const _CartaoGuardada(
      {super.key, required this.certidao, required this.aoTocar});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final verde = isDark ? AppColors.sucessoEscuro : AppColors.sucesso;
    final dias = certidao.diasRestantes;
    final prazo = dias <= 0
        ? 'Vence hoje'
        : (dias == 1 ? 'Falta 1 dia' : 'Faltam $dias dias');

    return Semantics(
      button: true,
      label:
          'Abrir ${certidao.titulo}, válida até ${_data(certidao.validoAte)}',
      excludeSemantics: true,
      child: CartaoVidro(
        onTap: aoTocar,
        padding: kPaddingCartao,
        arte: Arte.de('rh'),
        child: Row(
          children: [
            Icon(Icons.picture_as_pdf_rounded,
                size: AppIconSize.lg, color: theme.colorScheme.primary),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(certidao.titulo,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 3),
                  Text(
                    'Emitida em ${_dataHora(certidao.geradoEm)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color:
                          theme.colorScheme.onSurface.withValues(alpha: 0.72),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.verified_rounded,
                          size: AppIconSize.xs, color: verde),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          'Válida até ${_data(certidao.validoAte)} · $prazo',
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontSize: 12,
                            color: verde,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                size: AppIconSize.md,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
          ],
        ),
      ),
    );
  }
}

// ── Folha de emissão: declaração + botão ────────────────────────────────────

class _FolhaEmissao extends StatefulWidget {
  final TipoCertidao tipo;
  final PainelCertidoes painel;
  final Future<EmissaoCertidao> Function() emitir;

  const _FolhaEmissao({
    required this.tipo,
    required this.painel,
    required this.emitir,
  });

  @override
  State<_FolhaEmissao> createState() => _FolhaEmissaoState();
}

/// O que o servidor faz, na ordem e na linguagem da caserna, para o militar
/// acompanhar no botão. As duas últimas etapas são comuns a todas.
const _etapasPorTipo = <String, List<String>>{
  'tempo_servico': [
    'Consultando o SIGRH',
    'Levantando seus assentamentos funcionais',
    'Conferindo a data de inclusão',
    'Calculando seu tempo de serviço',
    'Apurando licenças e afastamentos',
    'Computando o tempo averbado',
  ],
  'vinculo_funcional': [
    'Consultando o SIGRH',
    'Levantando seus assentamentos funcionais',
    'Verificando postos e graduações',
    'Conferindo quadro e lotação',
    'Confirmando a situação funcional',
  ],
  'comportamento': [
    'Consultando o SIGRH',
    'Levantando seus assentamentos disciplinares',
    'Verificando publicações em BGI',
    'Apurando punições disciplinares',
    'Calculando seu comportamento',
  ],
  'ficha_funcional': [
    'Consultando sua ficha funcional',
    'Verificando postos e graduações',
    'Conferindo documentos pessoais',
    'Conferindo endereço e contatos',
    'Conferindo dependentes e conta bancária',
  ],
};

const _etapasFinais = [
  'Validando os dados da certidão',
  'Lavrando o documento',
  'Registrando a autenticação',
  'Enviando cópia por e-mail',
];

List<String> _etapasDe(String tipo) => [
      ...(_etapasPorTipo[tipo] ?? const ['Consultando o SIGRH']),
      ..._etapasFinais
    ];

class _FolhaEmissaoState extends State<_FolhaEmissao> {
  bool _confirmado = false;
  bool _emitindo = false;
  bool _pronto = false;
  int _etapa = 0;
  Timer? _relogio;
  String? _erro;

  @override
  void dispose() {
    _relogio?.cancel();
    super.dispose();
  }

  Future<void> _emitir() async {
    setState(() {
      _emitindo = true;
      _pronto = false;
      _etapa = 0;
      _erro = null;
    });
    // Avança uma etapa por vez e para na última até a resposta chegar.
    final total = (widget.tipo.etapas ?? _etapasDe(widget.tipo.tipo)).length;
    _relogio = Timer.periodic(const Duration(milliseconds: 650), (_) {
      if (mounted && _etapa < total - 1) setState(() => _etapa++);
    });

    try {
      // Tempo mínimo para as etapas não passarem num piscar.
      final resultado = await Future.wait([
        widget.emitir(),
        Future<void>.delayed(const Duration(milliseconds: 3600)),
      ]);
      _relogio?.cancel();
      if (!mounted) return;
      setState(() => _pronto = true);
      HapticFeedback.lightImpact();
      await Future<void>.delayed(const Duration(milliseconds: 700));
      if (mounted) {
        Navigator.of(context).pop(resultado.first as EmissaoCertidao);
      }
    } on CertidaoErro catch (e) {
      HapticFeedback.heavyImpact();
      if (mounted) setState(() => _erro = e.mensagem);
    } catch (e) {
      debugPrint('[CERTIDAO] emitir: $e');
      HapticFeedback.heavyImpact();
      if (mounted) {
        setState(() => _erro =
            'Sem conexão com o servidor. Verifique sua internet e tente de novo.');
      }
    } finally {
      _relogio?.cancel();
      if (mounted && !_pronto) setState(() => _emitindo = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopScope(
      canPop: !_emitindo,
      child: FolhaArte(
        arte: Arte.de('rh'),
        icone: _iconeDe(widget.tipo),
        titulo: widget.tipo.titulo,
        subtitulo: _descricaoDe(widget.tipo).isEmpty
            ? null
            : _descricaoDe(widget.tipo),
        paddingCorpo: const EdgeInsets.fromLTRB(16, 16, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Declaração em caixa de nível 1 (DESIGN §3b).
            CartaoVidro(
              raio: 14,
              arte: Arte.de('rh'),
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'DECLARAÇÃO DE CONFERÊNCIA DE DADOS',
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.painel.declaracaoTexto,
                    style: theme.textTheme.bodySmall?.copyWith(height: 1.45),
                  ),
                ],
              ),
            ),
            if (widget.tipo.vigenteDesde != null) ...[
              const SizedBox(height: 10),
              _Aviso(
                cor: theme.colorScheme.primary,
                icone: Icons.autorenew_rounded,
                texto: 'A certidão emitida em '
                    '${_dataHora(widget.tipo.vigenteDesde!)} deixará de valer. '
                    'Quem conferir a anterior pelo QR Code verá que ela foi '
                    'substituída por esta.',
              ),
            ],
            const SizedBox(height: 6),
            CheckboxListTile(
              value: _confirmado,
              onChanged: _emitindo
                  ? null
                  : (v) => setState(() => _confirmado = v ?? false),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: Text('Li e confirmo a declaração',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600)),
            ),

            if (_erro != null) ...[
              _Aviso(
                cor: theme.colorScheme.error,
                icone: Icons.error_outline_rounded,
                texto: _erro!,
              ),
              const SizedBox(height: 12),
            ],

            _BotaoEmitir(
              habilitado: _confirmado,
              emitindo: _emitindo,
              pronto: _pronto,
              etapa: _etapa,
              etapas: widget.tipo.etapas ?? _etapasDe(widget.tipo.tipo),
              aoTocar: _emitir,
            ),
            const SizedBox(height: 10),
            Text(
              'A certidão vale por ${widget.painel.validadeDias} dias.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            // A folha não fecha por toque fora nem por arrasto: o
            // "Cancelar" some só durante a emissão.
            if (!_emitindo) ...[
              const SizedBox(height: 4),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancelar'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Botão de emitir com as etapas ───────────────────────────────────────────
// Parado: "Emitir certidão". Emitindo: a etapa atual troca de baixo para
// cima, com uma barra fina avançando no pé do botão. Pronto: "Certidão
// emitida" com o visto.

class _BotaoEmitir extends StatelessWidget {
  final bool habilitado;
  final bool emitindo;
  final bool pronto;
  final int etapa;
  final List<String> etapas;
  final VoidCallback aoTocar;

  const _BotaoEmitir({
    required this.habilitado,
    required this.emitindo,
    required this.pronto,
    required this.etapa,
    required this.etapas,
    required this.aoTocar,
  });

  @override
  Widget build(BuildContext context) {
    const noBotao = Colors.white;

    final String texto;
    final Widget icone;
    if (pronto) {
      texto = 'Certidão emitida';
      icone = Icon(Icons.check_circle_rounded,
          key: const ValueKey('pronto'), size: AppIconSize.sm, color: noBotao);
    } else if (emitindo) {
      texto = '${etapas[etapa]}…';
      icone = SizedBox(
        key: const ValueKey('girando'),
        width: 16,
        height: 16,
        child: CircularProgressIndicator(strokeWidth: 2, color: noBotao),
      );
    } else {
      texto = 'Emitir certidão';
      icone = const Icon(Icons.picture_as_pdf_rounded,
          key: ValueKey('pdf'), size: AppIconSize.sm);
    }

    // Progresso aparente: cada etapa empurra a barra; termina ao ficar pronto.
    final progresso = pronto ? 1.0 : (etapa + 1) / (etapas.length + 1);
    final ocupado = emitindo || pronto;

    return Semantics(
      liveRegion: ocupado,
      label: ocupado ? texto : null,
      child: SizedBox(
        height: 52,
        child: ElevatedButton(
          onPressed: habilitado && !ocupado ? aoTocar : null,
          clipBehavior: Clip.antiAlias,
          // Emitindo, o botão fica com a cor cheia mesmo desabilitado.
          style: estiloBotaoCor(AppColors.acao, clara: AppColors.acaoClara, cheioDesligado: ocupado)
              .copyWith(padding: const WidgetStatePropertyAll(EdgeInsets.zero)),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        child: icone,
                      ),
                      const SizedBox(width: 10),
                      Flexible(
                        child: ClipRect(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 320),
                            switchInCurve: Curves.easeOutCubic,
                            switchOutCurve: Curves.easeInCubic,
                            transitionBuilder: (child, anim) {
                              final entrando =
                                  child.key == ValueKey<String>(texto);
                              final inicio = Offset(0, entrando ? 0.6 : -0.6);
                              return FadeTransition(
                                opacity: anim,
                                child: SlideTransition(
                                  position:
                                      Tween(begin: inicio, end: Offset.zero)
                                          .animate(anim),
                                  child: child,
                                ),
                              );
                            },
                            // As etapas são longas: um pouco menores e numa linha só.
                            child: Text(
                              texto,
                              key: ValueKey<String>(texto),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: ocupado && !pronto
                                  ? const TextStyle(fontSize: 14.5)
                                  : null,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (ocupado)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(end: progresso),
                    duration: const Duration(milliseconds: 900),
                    curve: Curves.easeOutCubic,
                    builder: (_, v, __) => LinearProgressIndicator(
                      value: v,
                      minHeight: 3,
                      backgroundColor: noBotao.withValues(alpha: 0.18),
                      valueColor: AlwaysStoppedAnimation(
                          noBotao.withValues(alpha: 0.85)),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Caixa de aviso ──────────────────────────────────────────────────────────

class _Aviso extends StatelessWidget {
  final Color cor;
  final IconData icone;
  final String texto;
  final String? titulo;
  const _Aviso(
      {required this.cor,
      required this.icone,
      required this.texto,
      this.titulo});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return CartaoVidro(
      raio: 14,
      tingimento: cor,
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icone, color: cor, size: AppIconSize.sm),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (titulo != null) ...[
                  Text(titulo!,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 3),
                ],
                Text(texto,
                    style: theme.textTheme.bodySmall?.copyWith(height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CertidaoVisualizarPage — o PDF, os dados de validade e o compartilhar.
// ─────────────────────────────────────────────────────────────────────────────

class CertidaoVisualizarPage extends StatefulWidget {
  final CertidaoGuardada certidao;

  /// Nome curto vindo da API (titulo_curto) para a barra do topo: o nome
  /// oficial é longo demais para ela. Sem ele, o nome oficial.
  final String? tituloBarra;
  const CertidaoVisualizarPage(
      {Key? key, required this.certidao, this.tituloBarra})
      : super(key: key);

  @override
  State<CertidaoVisualizarPage> createState() => _CertidaoVisualizarPageState();
}

class _CertidaoVisualizarPageState extends State<CertidaoVisualizarPage> {
  bool _compartilhando = false;

  /// Tira só do aparelho, depois de confirmar. Volta true para a lista.
  Future<void> _remover() async {
    final c = widget.certidao;
    final email = c.emailMascarado;
    final ok = await dialogoConfirmacao(
      context,
      titulo: 'Remover do aparelho?',
      mensagem: 'A certidão será removida apenas deste aparelho e continua '
          'válida para quem já a recebeu. '
          '${email != null ? 'Se precisar dela de novo, o PDF está no e-mail enviado para $email.' : 'Se precisar dela de novo, emita uma nova certidão.'}',
      textoConfirmar: 'Remover',
      icone: Icons.delete_outline_rounded,
      cor: Theme.of(context).colorScheme.error,
      arte: Arte.de('rh'),
    );
    if (!ok || !mounted) return;
    final matricula = Provider.of<Auth>(context, listen: false).matricula ?? '';
    await CertidaoService.remover(matricula, c.codigo);
    HapticFeedback.mediumImpact();
    if (mounted) Navigator.of(context).pop(true);
  }

  // Origem do popover exigida pelo iPad (UIActivityViewController).
  Rect? _origemCompartilhar() {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  Future<void> _compartilhar() async {
    final c = widget.certidao;

    if (c.tipo == _tipoSensivel) {
      final seguir = await dialogoConfirmacao(
        context,
        titulo: 'Dados sensíveis',
        mensagem: 'A Ficha Funcional contém sua conta bancária, endereço e '
            'dependentes. Envie apenas para quem realmente precisa.',
        textoConfirmar: 'Compartilhar',
        icone: Icons.shield_outlined,
        arte: Arte.de('rh'),
      );
      if (!seguir || !mounted) return;
    }

    setState(() => _compartilhando = true);
    try {
      // Cópia com nome legível: o arquivo guardado se chama pelo código.
      final copia = File('${Directory.systemTemp.path}/${c.nomeArquivo}');
      await File(c.caminho).copy(copia.path);
      await Share.shareXFiles(
        [XFile(copia.path, mimeType: 'application/pdf', name: c.nomeArquivo)],
        subject: c.titulo,
        sharePositionOrigin: _origemCompartilhar(),
      );
    } catch (e) {
      debugPrint('[CERTIDAO] compartilhar: $e');
      if (mounted) {
        await alertaErro(context,
            titulo: 'Não foi possível compartilhar',
            texto: 'Tente de novo em instantes.',
            arte: Arte.de('rh'));
      }
    } finally {
      if (mounted) setState(() => _compartilhando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.certidao;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final verde = isDark ? AppColors.sucessoEscuro : AppColors.sucesso;

    return FundoSuave(
      child: Scaffold(
        appBar: CustomAppBar(title: widget.tituloBarra ?? c.titulo),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
              child: CartaoVidro(
                arte: Arte.de('rh'),
                padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
                child: Row(
                  children: [
                    Icon(Icons.verified_rounded,
                        size: AppIconSize.md, color: verde),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Válida até ${_data(c.validoAte)}',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w700, color: verde)),
                          Text('Emitida em ${_dataHora(c.geradoEm)}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurface
                                      .withValues(alpha: 0.72))),
                        ],
                      ),
                    ),
                    Semantics(
                      button: true,
                      label: 'Remover certidão do aparelho',
                      excludeSemantics: true,
                      child: IconButton(
                        onPressed: _remover,
                        tooltip: 'Remover do aparelho',
                        icon: Icon(Icons.delete_outline_rounded,
                            size: AppIconSize.md,
                            color: theme.colorScheme.error),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: PDFView(
                    filePath: c.caminho,
                    enableSwipe: true,
                    autoSpacing: true,
                    pageFling: true,
                    fitEachPage: true,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 96),
          ],
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        floatingActionButton: _BotaoCompartilhar(
          ocupado: _compartilhando,
          aoTocar: _compartilhar,
        ),
      ),
    );
  }
}

// ── Botão de compartilhar de vidro ──────────────────────────────────────────
// Mesma receita do botão do contracheque e da pílula do menu inferior.

class _BotaoCompartilhar extends StatelessWidget {
  final bool ocupado;
  final VoidCallback aoTocar;
  const _BotaoCompartilhar({required this.ocupado, required this.aoTocar});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaria = theme.colorScheme.primary;

    final conteudo = Container(
      decoration: BoxDecoration(
        color: primaria.withValues(alpha: isDark ? 0.22 : 0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: primaria.withValues(alpha: isDark ? 0.35 : 0.22),
          width: 0.8,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: ocupado ? null : aoTocar,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 13, 20, 13),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ocupado
                    ? SizedBox(
                        width: AppIconSize.xs,
                        height: AppIconSize.xs,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: primaria),
                      )
                    : Icon(Icons.ios_share_rounded,
                        size: AppIconSize.xs, color: primaria),
                const SizedBox(width: 9),
                Text(
                  ocupado ? 'Preparando…' : 'Compartilhar',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.1,
                    color: primaria,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    return Semantics(
      button: true,
      label: 'Compartilhar certidão',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Platform.isAndroid
            ? conteudo
            : BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
                child: conteudo,
              ),
      ),
    );
  }
}
