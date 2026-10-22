import '../core/sessao/sessao.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/auth_model.dart';
import '../utils/api_services.dart';
import '../utils/app_theme.dart';
import '../widgets/custom_appbar.dart';
import '../widgets/vidro.dart';
import 'confirm_email.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AlterarSenhaPage
//
// Troca da senha de acesso, aberta em Configurações → Conta.
// A senha é a mesma do SIGRH e do SouPMRR, por isso o aviso em tela.
//
// Fluxo: senha atual + nova (duas vezes) → alterar_senha.php → e-mail de
// confirmação enviado pelo servidor.
//
// "Não lembro minha senha atual": código de 6 dígitos no e-mail confirmado
// (recuperar_senha.php pela matrícula) → nova senha. Quem não tem e-mail
// confirmado é levado a confirmá-lo primeiro.
// ─────────────────────────────────────────────────────────────────────────────

/// Em qual parte do fluxo a tela está.
enum _Etapa { senhaAtual, codigo, novaSenha }

class AlterarSenhaPage extends StatefulWidget {
  const AlterarSenhaPage({Key? key}) : super(key: key);

  @override
  State<AlterarSenhaPage> createState() => _AlterarSenhaPageState();
}

class _AlterarSenhaPageState extends State<AlterarSenhaPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _atualCtrl = TextEditingController();
  final _novaCtrl = TextEditingController();
  final _repetirCtrl = TextEditingController();
  final _codigoCtrl = TextEditingController();

  bool _verAtual = false;
  bool _verNova = false;
  bool _carregando = false;
  bool _concluido = false;
  String? _erro;

  _Etapa _etapa = _Etapa.senhaAtual;
  String _emailMascarado = '';
  bool _emailNaoConfirmado = false;
  int _segundosReenvio = 0;
  Timer? _timerReenvio;

  bool get _porCodigo => _etapa != _Etapa.senhaAtual;

  /// Sacode o formulário quando o servidor recusa a troca.
  late final AnimationController _shakeCtrl;
  late final Animation<double> _shake;

  @override
  void initState() {
    super.initState();
    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _shake = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 12.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 12.0, end: -10.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -10.0, end: 7.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 7.0, end: -4.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -4.0, end: 0.0), weight: 1),
    ]).animate(CurvedAnimation(parent: _shakeCtrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _shakeCtrl.dispose();
    _timerReenvio?.cancel();
    _atualCtrl.dispose();
    _novaCtrl.dispose();
    _repetirCtrl.dispose();
    _codigoCtrl.dispose();
    super.dispose();
  }

  // ── Regras de senha ───────────────────────────────────────────────────────
  // As mesmas exigidas pelo SIGRH, já que a senha é a mesma nos dois sistemas.

  static const _regras = <({String texto, String chave})>[
    (texto: 'Mínimo 8 caracteres', chave: 'tamanho'),
    (texto: 'Uma letra maiúscula', chave: 'maiuscula'),
    (texto: 'Uma letra minúscula', chave: 'minuscula'),
    (texto: 'Um número', chave: 'numero'),
    (texto: 'Um caractere especial', chave: 'especial'),
  ];

  Map<String, bool> _avaliar(String senha) => {
        'tamanho': senha.length >= 8,
        'maiuscula': RegExp(r'[A-Z]').hasMatch(senha),
        'minuscula': RegExp(r'[a-z]').hasMatch(senha),
        'numero': RegExp(r'[0-9]').hasMatch(senha),
        'especial': RegExp(r'[^A-Za-z0-9]').hasMatch(senha),
      };

  bool _senhaValida(String senha) =>
      _avaliar(senha).values.every((cumprida) => cumprida);

  // ── Envio ─────────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() => _erro = null);

    if (!(_formKey.currentState?.validate() ?? false)) {
      _shakeCtrl.forward(from: 0);
      return;
    }

    final auth = Provider.of<Auth>(context, listen: false);
    final matricula = auth.matricula ?? '';
    if (matricula.isEmpty) {
      setState(() => _erro = 'Não identificamos sua matrícula. '
          'Saia do app e entre novamente.');
      return;
    }

    setState(() => _carregando = true);

    final senhaAtual = _atualCtrl.text.trim();
    final senhaNova = _novaCtrl.text.trim();

    final resultado = _porCodigo
        ? await ApiServices.recuperarSenha(
            acao: 'redefinir',
            matricula: matricula,
            codigo: _codigoCtrl.text.replaceAll(RegExp(r'\D'), ''),
            senhaNovaMd5: auth.generateMd5(senhaNova),
          )
        : await ApiServices.alterarSenha(
            matricula: matricula,
            senhaAtualMd5: auth.generateMd5(senhaAtual),
            senhaNovaMd5: auth.generateMd5(senhaNova),
          );

    if (!mounted) return;

    if (resultado['code'] == 1) {
      // A senha guardada no app precisa acompanhar a troca, senão o
      // login automático e a biometria passam a falhar.
      auth.password = senhaNova;
      await auth.saveUserData();

      if (await Sessao.instancia.senhaLembrada() != null) {
        await Sessao.instancia.gravarSenhaLembrada(senhaNova);
      }

      _timerReenvio?.cancel();
      HapticFeedback.mediumImpact();
      if (mounted) setState(() => _concluido = true);
    } else {
      HapticFeedback.heavyImpact();
      setState(() {
        _erro = (resultado['message'] ?? 'Não foi possível alterar a senha.')
            .toString();
        _carregando = false;
      });
      _shakeCtrl.forward(from: 0);
      return;
    }

    if (mounted) setState(() => _carregando = false);
  }

  // ── Não lembro minha senha atual ──────────────────────────────────────────

  String get _matricula =>
      Provider.of<Auth>(context, listen: false).matricula ?? '';

  void _contagemReenvio() {
    _timerReenvio?.cancel();
    setState(() => _segundosReenvio = 60);
    _timerReenvio = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _segundosReenvio--);
      if (_segundosReenvio <= 0) t.cancel();
    });
  }

  /// Pede o código de 6 dígitos para o e-mail confirmado do cadastro.
  Future<void> _solicitarCodigo() async {
    FocusScope.of(context).unfocus();
    if (_matricula.isEmpty) {
      setState(() => _erro = 'Não identificamos sua matrícula. '
          'Saia do app e entre novamente.');
      return;
    }

    setState(() {
      _carregando = true;
      _erro = null;
      _emailNaoConfirmado = false;
    });

    final r = await ApiServices.recuperarSenha(
        acao: 'solicitar', matricula: _matricula);
    if (!mounted) return;

    if (r['code'] == 1) {
      HapticFeedback.lightImpact();
      _codigoCtrl.clear();
      setState(() {
        _emailMascarado = (r['email'] ?? '').toString();
        _etapa = _Etapa.codigo;
      });
      _contagemReenvio();
    } else {
      HapticFeedback.heavyImpact();
      final mensagem =
          (r['message'] ?? 'Não foi possível enviar o código.').toString();
      setState(() {
        _erro = mensagem;
        _emailNaoConfirmado = mensagem.contains('não foi confirmado');
      });
    }
    if (mounted) setState(() => _carregando = false);
  }

  /// Confere o código antes de liberar a nova senha.
  Future<void> _validarCodigo() async {
    final codigo = _codigoCtrl.text.replaceAll(RegExp(r'\D'), '');
    if (codigo.length != 6) {
      setState(() => _erro = 'Digite os 6 dígitos do código.');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _carregando = true;
      _erro = null;
    });

    final r = await ApiServices.recuperarSenha(
        acao: 'validar', matricula: _matricula, codigo: codigo);
    if (!mounted) return;

    if (r['code'] == 1) {
      HapticFeedback.lightImpact();
      setState(() => _etapa = _Etapa.novaSenha);
    } else {
      HapticFeedback.heavyImpact();
      // Limpa o campo para a próxima tentativa já começar do zero.
      _codigoCtrl.clear();
      setState(() => _erro =
          (r['message'] ?? 'Não foi possível conferir o código.').toString());
    }
    if (mounted) setState(() => _carregando = false);
  }

  /// Volta para a troca com a senha atual.
  void _cancelarCodigo() {
    _timerReenvio?.cancel();
    _codigoCtrl.clear();
    setState(() {
      _etapa = _Etapa.senhaAtual;
      _erro = null;
      _segundosReenvio = 0;
    });
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return FundoSuave(child: Scaffold(
      appBar: const CustomAppBar(title: 'Alterar senha'),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          switchInCurve: Curves.easeOutCubic,
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: anim,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.06),
                end: Offset.zero,
              ).animate(anim),
              child: child,
            ),
          ),
          child: _concluido
              ? _sucesso()
              : (_etapa == _Etapa.codigo ? _telaCodigo() : _formulario()),
        ),
      ),
    ));
  }

  // ── Formulário ────────────────────────────────────────────────────────────

  Widget _formulario() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final situacao = _avaliar(_novaCtrl.text);

    return AnimatedBuilder(
      key: const ValueKey('form'),
      animation: _shake,
      builder: (context, child) => Transform.translate(
        offset: Offset(_shake.value, 0),
        child: child,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.colorScheme.primary.withOpacity(0.12),
                ),
                child: Icon(Icons.lock_reset_rounded,
                    size: 36, color: theme.colorScheme.primary),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _porCodigo ? 'Crie sua nova senha' : 'Alterar senha de acesso',
              textAlign: TextAlign.center,
              style:
                  theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'A mesma senha vale para o SIGRH e para o SouPMRR. '
              'Ao alterar aqui, ela muda nos dois.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.70),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),

            if (_erro != null) ...[
              _Caixa(
                cor: theme.colorScheme.error,
                icone: Icons.error_outline_rounded,
                texto: _erro!,
              ),
              if (_emailNaoConfirmado) ...[
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => const ConfirmEmailScreen()),
                  ),
                  icon: const Icon(Icons.mark_email_unread_outlined, size: 18),
                  label: const Text('Confirmar meu e-mail'),
                ),
              ],
              const SizedBox(height: 16),
            ],

            if (_porCodigo) ...[
              _Caixa(
                cor: isDark ? AppColors.sucessoEscuro : AppColors.sucesso,
                icone: Icons.verified_rounded,
                texto: 'Código confirmado. Agora escolha a nova senha.',
              ),
              const SizedBox(height: 16),
            ] else ...[
              TextFormField(
                controller: _atualCtrl,
                obscureText: !_verAtual,
                decoration: _deco(
                  label: 'Senha atual',
                  icon: Icons.lock_outline_rounded,
                  isDark: isDark,
                  onToggle: () => setState(() => _verAtual = !_verAtual),
                  visivel: _verAtual,
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Informe sua senha atual'
                    : null,
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _carregando ? null : _solicitarCodigo,
                  child: const Text('Não lembro minha senha atual'),
                ),
              ),
              const SizedBox(height: 4),
            ],

            TextFormField(
              controller: _novaCtrl,
              obscureText: !_verNova,
              onChanged: (_) => setState(() {}),
              decoration: _deco(
                label: 'Nova senha',
                icon: Icons.lock_person_rounded,
                isDark: isDark,
                onToggle: () => setState(() => _verNova = !_verNova),
                visivel: _verNova,
              ),
              validator: (v) {
                final valor = (v ?? '').trim();
                if (valor.isEmpty) return 'Informe a nova senha';
                if (!_senhaValida(valor)) {
                  return 'A senha não atende aos requisitos abaixo';
                }
                if (!_porCodigo && valor == _atualCtrl.text.trim()) {
                  return 'A nova senha deve ser diferente da atual';
                }
                return null;
              },
            ),

            // Requisitos do SIGRH, marcados em tempo real.
            const SizedBox(height: 12),
            _ListaRequisitos(regras: _regras, situacao: situacao),
            const SizedBox(height: 14),

            TextFormField(
              controller: _repetirCtrl,
              obscureText: !_verNova,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
              decoration: _deco(
                label: 'Repita a nova senha',
                icon: Icons.check_circle_outline_rounded,
                isDark: isDark,
              ),
              validator: (v) {
                final valor = (v ?? '').trim();
                if (valor.isEmpty) return 'Repita a nova senha';
                if (valor != _novaCtrl.text.trim()) {
                  return 'As senhas não conferem';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),

            SizedBox(
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _carregando ? null : _submit,
                icon: _carregando
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.save_rounded, size: 18),
                label: Text(_carregando ? 'Alterando...' : 'Alterar senha'),
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.white,
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
            if (_porCodigo) ...[
              const SizedBox(height: 6),
              TextButton(
                onPressed: _carregando ? null : _cancelarCodigo,
                child: const Text('Voltar e usar a senha atual'),
              ),
            ],
            const SizedBox(height: 16),

            _Caixa(
              cor: AppColors.lightBlue,
              icone: Icons.mark_email_read_outlined,
              texto: 'Ao concluir, enviamos um e-mail confirmando a alteração '
                  'para o endereço cadastrado.',
            ),
          ],
        ),
      ),
    );
  }

  // ── Código de verificação ─────────────────────────────────────────────────

  Widget _telaCodigo() {
    final theme = Theme.of(context);

    return Column(
      key: const ValueKey('codigo'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: theme.colorScheme.primary.withOpacity(0.12),
            ),
            child: Icon(Icons.mark_email_read_rounded,
                size: 36, color: theme.colorScheme.primary),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Digite o código',
          textAlign: TextAlign.center,
          style:
              theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'Enviamos um código de 6 dígitos para o seu e-mail confirmado:',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.70),
            height: 1.4,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _emailMascarado,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 24),

        if (_erro != null) ...[
          _Caixa(
            cor: theme.colorScheme.error,
            icone: Icons.error_outline_rounded,
            texto: _erro!,
          ),
          const SizedBox(height: 16),
        ],

        TextField(
          controller: _codigoCtrl,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          maxLength: 6,
          autofocus: true,
          style: const TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.bold,
            letterSpacing: 14,
          ),
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: (v) {
            if (v.length == 6 && !_carregando) _validarCodigo();
          },
          decoration: InputDecoration(
            counterText: '',
            hintText: '000000',
            hintStyle: TextStyle(
              letterSpacing: 14,
              color: theme.colorScheme.onSurface.withOpacity(0.18),
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 18),
          ),
        ),
        const SizedBox(height: 20),

        SizedBox(
          height: 50,
          child: ElevatedButton.icon(
            onPressed: _carregando ? null : _validarCodigo,
            icon: _carregando
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.check_rounded, size: 18),
            label: Text(_carregando ? 'Conferindo...' : 'Confirmar código'),
            style: ElevatedButton.styleFrom(
              foregroundColor: Colors.white,
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
        TextButton(
          onPressed: _segundosReenvio > 0 || _carregando
              ? null
              : _solicitarCodigo,
          child: Text(_segundosReenvio > 0
              ? 'Reenviar código em $_segundosReenvio s'
              : 'Não recebi o código, reenviar'),
        ),
        TextButton(
          onPressed: _carregando ? null : _cancelarCodigo,
          child: const Text('Voltar e usar a senha atual'),
        ),
        const SizedBox(height: 8),
        _Caixa(
          cor: AppColors.gold,
          icone: Icons.search_rounded,
          texto: 'O código chega em poucos minutos e vale por 15 minutos. '
              'Confira também a pasta de spam ou lixo eletrônico.',
        ),
      ],
    );
  }

  // ── Sucesso ───────────────────────────────────────────────────────────────

  Widget _sucesso() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final verde = isDark ? AppColors.sucessoEscuro : AppColors.sucesso;

    return Column(
      key: const ValueKey('sucesso'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 24),

        // Selo que cresce ao aparecer.
        Center(
          child: TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 520),
            curve: Curves.elasticOut,
            tween: Tween(begin: 0.4, end: 1.0),
            builder: (_, escala, child) =>
                Transform.scale(scale: escala, child: child),
            child: Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: verde.withOpacity(0.12),
              ),
              child: Icon(Icons.verified_user_rounded, size: 44, color: verde),
            ),
          ),
        ),
        const SizedBox(height: 20),

        Text(
          'Senha alterada!',
          textAlign: TextAlign.center,
          style: theme.textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.bold, color: verde),
        ),
        const SizedBox(height: 10),
        Text(
          'Sua nova senha já está valendo no SouPMRR e no SIGRH.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.70),
            height: 1.4,
          ),
        ),
        const SizedBox(height: 24),

        _Caixa(
          cor: AppColors.lightBlue,
          icone: Icons.mail_outline_rounded,
          texto: 'Enviamos um e-mail confirmando a alteração. Se não foi você, '
              'procure o DTI/PMRR imediatamente.',
        ),
        const SizedBox(height: 28),

        SizedBox(
          height: 50,
          child: ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: verde,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text(
              'Voltar ao app',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  // ── Decoração dos campos ──────────────────────────────────────────────────

  InputDecoration _deco({
    required String label,
    required IconData icon,
    required bool isDark,
    VoidCallback? onToggle,
    bool visivel = false,
  }) {
    final theme = Theme.of(context);
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 20, color: theme.colorScheme.primary),
      suffixIcon: onToggle == null
          ? null
          : IconButton(
              onPressed: onToggle,
              icon: Icon(
                visivel
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                size: 20,
              ),
            ),
      // borda, preenchimento, foco e erro vêm do inputDecorationTheme
    );
  }
}

// ── Lista de requisitos da senha ────────────────────────────────────────────
// Cada item fica cinza enquanto não foi digitado nada, vermelho quando não
// cumpre e verde quando cumpre — como no SIGRH.

class _ListaRequisitos extends StatelessWidget {
  final List<({String texto, String chave})> regras;
  final Map<String, bool> situacao;

  const _ListaRequisitos({required this.regras, required this.situacao});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final vazio = situacao.values.every((cumprida) => !cumprida);

    final verde = isDark ? AppColors.sucessoEscuro : AppColors.sucesso;
    final vermelho = isDark ? AppColors.falhaEscuro : AppColors.falha;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.055) : Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.10) : Colors.white.withOpacity(0.80),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'A senha deve conter:',
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface.withOpacity(0.70),
            ),
          ),
          const SizedBox(height: 8),
          for (final regra in regras) ...[
            Builder(builder: (_) {
              final ok = situacao[regra.chave] ?? false;
              final cor = vazio
                  ? theme.colorScheme.onSurface.withOpacity(0.70)
                  : (ok ? verde : vermelho);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      transitionBuilder: (child, anim) =>
                          ScaleTransition(scale: anim, child: child),
                      child: Icon(
                        ok
                            ? Icons.check_circle_rounded
                            : Icons.radio_button_unchecked_rounded,
                        key: ValueKey(ok),
                        size: 16,
                        color: cor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 250),
                        style: theme.textTheme.bodySmall!.copyWith(
                          color: cor,
                          fontWeight:
                              ok ? FontWeight.w600 : FontWeight.normal,
                        ),
                        child: Text(regra.texto),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}

// ── Caixa de aviso ──────────────────────────────────────────────────────────

class _Caixa extends StatelessWidget {
  final Color cor;
  final IconData icone;
  final String texto;

  const _Caixa({required this.cor, required this.icone, required this.texto});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cor.withOpacity(0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cor.withOpacity(0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icone, color: cor, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              texto,
              style: theme.textTheme.bodySmall?.copyWith(
                height: 1.4,
                color: theme.colorScheme.onSurface.withOpacity(0.85),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
