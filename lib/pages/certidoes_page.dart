import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/auth_model.dart';
import '../services/certidao_service.dart';
import '../utils/app_theme.dart';
import '../widgets/alerta.dart';
import '../widgets/cartao_painel.dart';
import '../widgets/custom_appbar.dart';
import '../widgets/dialogo_confirmacao.dart';
import '../widgets/vidro.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CertidoesPage
//
// O militar escolhe a certidão, confirma a Declaração de Conferência de
// Dados e recebe o PDF na hora.
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
      if (mounted) setState(() => _painel = painel);
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

  Future<void> _escolher(TipoCertidao tipo) async {
    final painel = _painel;
    if (painel == null) return;

    if (!tipo.disponivel) {
      await alertaAviso(context,
          titulo: tipo.titulo,
          texto: tipo.motivo ?? 'Esta certidão não está disponível.');
      return;
    }

    final emitida = await showModalBottomSheet<CertidaoGuardada>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => _FolhaEmissao(
        tipo: tipo,
        painel: painel,
        emitir: () => CertidaoService.emitir(
          matricula: _matricula,
          senhaMd5: _senhaMd5,
          tipo: tipo.tipo,
          declaracaoVersao: painel.declaracaoVersao,
        ),
      ),
    );

    if (emitida == null || !mounted) return;
    HapticFeedback.mediumImpact();
    final guardadas = await CertidaoService.guardadas(_matricula);
    if (!mounted) return;
    setState(() => _guardadas = guardadas);
    _abrir(emitida);
  }

  void _abrir(CertidaoGuardada c) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => CertidaoVisualizarPage(certidao: c),
    ));
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
              Text(
                'Escolha a certidão que você precisa.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 18),
              _Rotulo('Emitir certidão'),
              const SizedBox(height: 10),
              ..._tipos(),
              const SizedBox(height: 22),
              _Rotulo('Minhas certidões'),
              const SizedBox(height: 10),
              ..._listaGuardadas(),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _tipos() {
    final theme = Theme.of(context);

    if (_carregando && _painel == null) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 28),
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }

    if (_painel == null) {
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

    return [
      for (final tipo in _painel!.tipos) ...[
        _CartaoTipo(tipo: tipo, aoTocar: () => _escolher(tipo)),
        const SizedBox(height: 10),
      ],
    ];
  }

  List<Widget> _listaGuardadas() {
    final theme = Theme.of(context);

    if (_guardadas.isEmpty) {
      return [
        CartaoVidro(
          padding: kPaddingCartao,
          child: Row(
            children: [
              Icon(Icons.folder_open_rounded,
                  size: AppIconSize.md,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.55)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'As certidões que você emitir ficam aqui por 30 dias.',
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

    return [
      for (final c in _guardadas) ...[
        _CartaoGuardada(certidao: c, aoTocar: () => _abrir(c)),
        const SizedBox(height: 10),
      ],
    ];
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
    final info = _descricoes[tipo.tipo];
    final apagado = !tipo.disponivel;
    final corTexto = theme.colorScheme.onSurface;

    return Semantics(
      button: true,
      label: apagado ? '${tipo.titulo}, indisponível' : 'Emitir ${tipo.titulo}',
      excludeSemantics: true,
      child: Opacity(
        opacity: apagado ? 0.6 : 1,
        child: CartaoVidro(
          onTap: aoTocar,
          padding: kPaddingCartao,
          child: Row(
            children: [
              Icon(info?.icone ?? Icons.description_rounded,
                  size: AppIconSize.lg, color: theme.colorScheme.primary),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tipo.titulo,
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(
                      apagado
                          ? (tipo.motivo ?? 'Indisponível.')
                          : (info?.texto ?? ''),
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
                apagado ? Icons.lock_outline_rounded : Icons.chevron_right_rounded,
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

// ── Cartão de uma certidão guardada ─────────────────────────────────────────

class _CartaoGuardada extends StatelessWidget {
  final CertidaoGuardada certidao;
  final VoidCallback aoTocar;
  const _CartaoGuardada({required this.certidao, required this.aoTocar});

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
      label: 'Abrir ${certidao.titulo}, válida até ${_data(certidao.validoAte)}',
      excludeSemantics: true,
      child: CartaoVidro(
        onTap: aoTocar,
        padding: kPaddingCartao,
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
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
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
  final Future<CertidaoGuardada> Function() emitir;

  const _FolhaEmissao({
    required this.tipo,
    required this.painel,
    required this.emitir,
  });

  @override
  State<_FolhaEmissao> createState() => _FolhaEmissaoState();
}

class _FolhaEmissaoState extends State<_FolhaEmissao> {
  bool _confirmado = false;
  bool _emitindo = false;
  String? _erro;

  Future<void> _emitir() async {
    setState(() {
      _emitindo = true;
      _erro = null;
    });
    try {
      final c = await widget.emitir();
      if (mounted) Navigator.of(context).pop(c);
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
      if (mounted) setState(() => _emitindo = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final info = _descricoes[widget.tipo.tipo];

    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 10, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Icon(info?.icone ?? Icons.description_rounded,
                    size: AppIconSize.xl, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(widget.tipo.titulo,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              info?.texto ?? '',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),

            // Declaração em caixa de nível 1 (DESIGN §3b).
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary
                    .withValues(alpha: isDark ? 0.10 : 0.06),
                borderRadius: BorderRadius.circular(14),
              ),
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

            SizedBox(
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _confirmado && !_emitindo ? _emitir : null,
                icon: _emitindo
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.picture_as_pdf_rounded,
                        size: AppIconSize.sm),
                label: Text(_emitindo ? 'Emitindo…' : 'Emitir certidão'),
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'A certidão vale por ${widget.painel.validadeDias} dias.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
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
  const _Aviso({required this.cor, required this.icone, required this.texto});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cor.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icone, color: cor, size: AppIconSize.sm),
          const SizedBox(width: 10),
          Expanded(
            child: Text(texto,
                style: theme.textTheme.bodySmall?.copyWith(height: 1.4)),
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
  const CertidaoVisualizarPage({Key? key, required this.certidao})
      : super(key: key);

  @override
  State<CertidaoVisualizarPage> createState() => _CertidaoVisualizarPageState();
}

class _CertidaoVisualizarPageState extends State<CertidaoVisualizarPage> {
  bool _compartilhando = false;

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
            texto: 'Tente de novo em instantes.');
      }
    } finally {
      if (mounted) setState(() => _compartilhando = false);
    }
  }

  Future<void> _copiarLink() async {
    await Clipboard.setData(ClipboardData(text: widget.certidao.urlVerificacao));
    if (!mounted) return;
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Link de verificação copiado'),
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.certidao;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final verde = isDark ? AppColors.sucessoEscuro : AppColors.sucesso;

    return FundoSuave(
      child: Scaffold(
        appBar: CustomAppBar(title: c.titulo),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
              child: CartaoVidro(
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
                      label: 'Copiar link de verificação',
                      child: IconButton(
                        onPressed: _copiarLink,
                        tooltip: 'Copiar link de verificação',
                        icon: Icon(Icons.link_rounded,
                            size: AppIconSize.md,
                            color: theme.colorScheme.primary),
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
