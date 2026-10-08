import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../utils/api_services.dart';
import '../utils/app_theme.dart';
import '../widgets/custom_appbar.dart';
import '../widgets/requisitos_senha.dart';

// ─────────────────────────────────────────────────────────────────────────────
// RecuperarSenhaPage
//
// Recuperação de senha por e-mail, em quatro passos:
//   1. e-mail  → servidor envia um código de 6 dígitos
//   2. código  → servidor confere
//   3. senha   → grava a nova senha (regras do SIGRH)
//   4. pronto  → volta para o login
// ─────────────────────────────────────────────────────────────────────────────

enum _Passo { email, codigo, senha, concluido }

class RecuperarSenhaPage extends StatefulWidget {
  const RecuperarSenhaPage({Key? key}) : super(key: key);

  @override
  State<RecuperarSenhaPage> createState() => _RecuperarSenhaPageState();
}

class _RecuperarSenhaPageState extends State<RecuperarSenhaPage> {
  final _emailCtrl = TextEditingController();
  final _codigoCtrl = TextEditingController();
  final _senhaCtrl = TextEditingController();
  final _repetirCtrl = TextEditingController();

  _Passo _passo = _Passo.email;
  bool _carregando = false;
  bool _verSenha = false;
  String? _erro;
  String _emailMascarado = '';

  int _segundosReenvio = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _emailCtrl.dispose();
    _codigoCtrl.dispose();
    _senhaCtrl.dispose();
    _repetirCtrl.dispose();
    super.dispose();
  }

  String _md5(String valor) => md5.convert(utf8.encode(valor)).toString();

  void _contagemReenvio() {
    _timer?.cancel();
    setState(() => _segundosReenvio = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _segundosReenvio--);
      if (_segundosReenvio <= 0) t.cancel();
    });
  }

  Future<void> _executar(Future<Map<String, dynamic>> Function() acao,
      void Function(Map<String, dynamic>) aoDarCerto) async {
    FocusScope.of(context).unfocus();
    setState(() {
      _carregando = true;
      _erro = null;
    });

    final resultado = await acao();
    if (!mounted) return;

    if (resultado['code'] == 1) {
      HapticFeedback.lightImpact();
      aoDarCerto(resultado);
    } else {
      HapticFeedback.heavyImpact();
      setState(() => _erro =
          (resultado['message'] ?? 'Não foi possível concluir.').toString());
    }
    if (mounted) setState(() => _carregando = false);
  }

  // ── Ações ─────────────────────────────────────────────────────────────────

  void _solicitarCodigo() {
    final email = _emailCtrl.text.trim().toLowerCase();
    if (!RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$').hasMatch(email)) {
      setState(() => _erro = 'Informe um e-mail válido.');
      return;
    }
    _executar(
      () => ApiServices.recuperarSenha(acao: 'solicitar', email: email),
      (r) {
        setState(() {
          _emailMascarado = (r['email'] ?? email).toString();
          _passo = _Passo.codigo;
        });
        _contagemReenvio();
      },
    );
  }

  void _validarCodigo() {
    final codigo = _codigoCtrl.text.replaceAll(RegExp(r'\D'), '');
    if (codigo.length != 6) {
      setState(() => _erro = 'Digite os 6 dígitos do código.');
      return;
    }
    _executar(
      () => ApiServices.recuperarSenha(
        acao: 'validar',
        email: _emailCtrl.text.trim().toLowerCase(),
        codigo: codigo,
      ),
      (_) => setState(() => _passo = _Passo.senha),
    );
  }

  void _redefinir() {
    final senha = _senhaCtrl.text.trim();
    if (!senhaValida(senha)) {
      setState(() => _erro = 'A senha não atende aos requisitos.');
      return;
    }
    if (senha != _repetirCtrl.text.trim()) {
      setState(() => _erro = 'As senhas não conferem.');
      return;
    }
    _executar(
      () => ApiServices.recuperarSenha(
        acao: 'redefinir',
        email: _emailCtrl.text.trim().toLowerCase(),
        codigo: _codigoCtrl.text.replaceAll(RegExp(r'\D'), ''),
        senhaNovaMd5: _md5(senha),
      ),
      (_) => setState(() => _passo = _Passo.concluido),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(title: 'Recuperar senha'),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_passo != _Passo.concluido) _indicador(),
            const SizedBox(height: 20),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 320),
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.08, 0),
                    end: Offset.zero,
                  ).animate(anim),
                  child: child,
                ),
              ),
              child: switch (_passo) {
                _Passo.email => _telaEmail(),
                _Passo.codigo => _telaCodigo(),
                _Passo.senha => _telaSenha(),
                _Passo.concluido => _telaConcluido(),
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Trilha de progresso dos três passos.
  Widget _indicador() {
    final theme = Theme.of(context);
    final atual = _passo.index;
    return Row(
      children: List.generate(3, (i) {
        final ativo = i <= atual;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: i < 2 ? 6 : 0),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: 5,
              decoration: BoxDecoration(
                color: ativo
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface.withOpacity(0.12),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _cabecalho(IconData icone, String titulo, String descricao,
      {Color? cor}) {
    final theme = Theme.of(context);
    final destaque = cor ?? theme.colorScheme.primary;
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: destaque.withOpacity(0.12),
          ),
          child: Icon(icone, size: 36, color: destaque),
        ),
        const SizedBox(height: 16),
        Text(
          titulo,
          textAlign: TextAlign.center,
          style:
              theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          descricao,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.70),
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _erroBox() {
    if (_erro == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: AvisoCaixa(
        cor: Theme.of(context).colorScheme.error,
        icone: Icons.error_outline_rounded,
        texto: _erro!,
      ),
    );
  }

  Widget _botao(String texto, VoidCallback? aoTocar, {IconData? icone}) {
    final theme = Theme.of(context);
    return SizedBox(
      height: 50,
      child: ElevatedButton.icon(
        onPressed: _carregando ? null : aoTocar,
        icon: _carregando
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Icon(icone ?? Icons.arrow_forward_rounded, size: 18),
        label: Text(_carregando ? 'Aguarde...' : texto),
        style: ElevatedButton.styleFrom(
          backgroundColor: theme.colorScheme.primary,
          foregroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(
              fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 0.5),
        ),
      ),
    );
  }

  // ── Passo 1: e-mail ───────────────────────────────────────────────────────

  Widget _telaEmail() {
    return Column(
      key: const ValueKey('email'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _cabecalho(Icons.mark_email_unread_rounded, 'Qual é o seu e-mail?',
            'Enviaremos um código de 6 dígitos para o e-mail cadastrado no seu perfil.'),
        const SizedBox(height: 24),
        TextField(
          controller: _emailCtrl,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _solicitarCodigo(),
          decoration: decoracaoCampo(
            context: context,
            label: 'E-mail cadastrado',
            icon: Icons.alternate_email_rounded,
          ),
        ),
        _erroBox(),
        const SizedBox(height: 20),
        _botao('Enviar código', _solicitarCodigo, icone: Icons.send_rounded),
        const SizedBox(height: 16),
        const AvisoCaixa(
          cor: AppColors.lightBlue,
          icone: Icons.info_outline_rounded,
          texto: 'Não lembra qual e-mail cadastrou, ou nunca cadastrou? '
              'Volte e use a opção "Primeiro acesso".',
        ),
      ],
    );
  }

  // ── Passo 2: código ───────────────────────────────────────────────────────

  Widget _telaCodigo() {
    final theme = Theme.of(context);
    return Column(
      key: const ValueKey('codigo'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _cabecalho(Icons.sms_rounded, 'Digite o código',
            'Enviamos um código de 6 dígitos para:'),
        const SizedBox(height: 8),
        Text(
          _emailMascarado,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _codigoCtrl,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          maxLength: 6,
          style: const TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.bold,
            letterSpacing: 14,
          ),
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: (v) {
            if (v.length == 6) _validarCodigo();
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
        _erroBox(),
        const SizedBox(height: 16),
        _botao('Confirmar código', _validarCodigo,
            icone: Icons.check_rounded),
        const SizedBox(height: 10),
        TextButton(
          onPressed: _segundosReenvio > 0 || _carregando
              ? null
              : () {
                  _codigoCtrl.clear();
                  _solicitarCodigo();
                },
          child: Text(_segundosReenvio > 0
              ? 'Reenviar código em $_segundosReenvio s'
              : 'Não recebi o código, reenviar'),
        ),
        const AvisoCaixa(
          cor: AppColors.gold,
          icone: Icons.search_rounded,
          texto: 'O código chega em poucos minutos. Confira também a pasta '
              'de spam ou lixo eletrônico.',
        ),
      ],
    );
  }

  // ── Passo 3: nova senha ───────────────────────────────────────────────────

  Widget _telaSenha() {
    return Column(
      key: const ValueKey('senha'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _cabecalho(Icons.lock_reset_rounded, 'Crie uma nova senha',
            'Ela vale para o SouPMRR e para o SIGRH.'),
        const SizedBox(height: 24),
        TextField(
          controller: _senhaCtrl,
          obscureText: !_verSenha,
          onChanged: (_) => setState(() {}),
          decoration: decoracaoCampo(
            context: context,
            label: 'Nova senha',
            icon: Icons.lock_person_rounded,
            suffixIcon: IconButton(
              onPressed: () => setState(() => _verSenha = !_verSenha),
              icon: Icon(
                _verSenha
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                size: 20,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        RequisitosSenha(senha: _senhaCtrl.text),
        const SizedBox(height: 14),
        TextField(
          controller: _repetirCtrl,
          obscureText: !_verSenha,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _redefinir(),
          decoration: decoracaoCampo(
            context: context,
            label: 'Repita a nova senha',
            icon: Icons.check_circle_outline_rounded,
          ),
        ),
        _erroBox(),
        const SizedBox(height: 20),
        _botao('Salvar nova senha', _redefinir, icone: Icons.save_rounded),
      ],
    );
  }

  // ── Passo 4: concluído ────────────────────────────────────────────────────

  Widget _telaConcluido() {
    const verde = Color(0xFF2E7D32);
    return Column(
      key: const ValueKey('ok'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
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
              child: const Icon(Icons.verified_user_rounded,
                  size: 44, color: verde),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Senha redefinida!',
          textAlign: TextAlign.center,
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(fontWeight: FontWeight.bold, color: verde),
        ),
        const SizedBox(height: 10),
        Text(
          'Use a nova senha para entrar no SouPMRR e no SIGRH.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color:
                    Theme.of(context).colorScheme.onSurface.withOpacity(0.70),
                height: 1.4,
              ),
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
                  borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text('Ir para o login',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }
}
