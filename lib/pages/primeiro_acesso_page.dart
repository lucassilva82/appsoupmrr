import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../utils/api_services.dart';
import '../utils/app_theme.dart';
import '../widgets/custom_appbar.dart';
import '../widgets/requisitos_senha.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PrimeiroAcessoPage
//
// Para quem nunca acessou ou não tem e-mail cadastrado. O militar informa o
// CPF e confirma a identidade respondendo perguntas sobre os próprios dados,
// no estilo dos aplicativos de banco. Acertando todas, cadastra a senha.
// ─────────────────────────────────────────────────────────────────────────────

enum _Passo { cpf, perguntas, email, codigo, senha, concluido }

class PrimeiroAcessoPage extends StatefulWidget {
  const PrimeiroAcessoPage({Key? key}) : super(key: key);

  @override
  State<PrimeiroAcessoPage> createState() => _PrimeiroAcessoPageState();
}

class _PrimeiroAcessoPageState extends State<PrimeiroAcessoPage> {
  final _cpfCtrl = TextEditingController();
  final _senhaCtrl = TextEditingController();
  final _repetirCtrl = TextEditingController();

  _Passo _passo = _Passo.cpf;
  bool _carregando = false;
  bool _verSenha = false;
  String? _erro;

  String _sessao = '';
  String _matricula = '';
  String _segadNova = '';
  String _segadAntiga = '';
  String _senhaCadastrada = '';
  bool _emailEnviado = false;
  final List<String> _usadas = [];
  final _emailCtrl = TextEditingController();
  final _codigoCtrl = TextEditingController();
  String _emailMascarado = '';
  List<Map<String, dynamic>> _perguntas = [];
  final Map<String, String> _respostas = {};
  int _indice = 0;

  @override
  void dispose() {
    _cpfCtrl.dispose();
    _emailCtrl.dispose();
    _codigoCtrl.dispose();
    _senhaCtrl.dispose();
    _repetirCtrl.dispose();
    super.dispose();
  }

  String _md5(String valor) => md5.convert(utf8.encode(valor)).toString();

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

  void _iniciar() {
    final cpf = _cpfCtrl.text.replaceAll(RegExp(r'\D'), '');
    if (cpf.length != 11) {
      setState(() => _erro = 'Digite os 11 números do CPF.');
      return;
    }
    _executar(
      () => ApiServices.primeiroAcesso(acao: 'iniciar', cpf: cpf),
      (r) => setState(() {
        _sessao = r['sessao'].toString();
        _perguntas = List<Map<String, dynamic>>.from(r['perguntas'] as List);
        _usadas
          ..clear()
          ..addAll(_perguntas.map((p) => p['id'].toString()));
        _respostas.clear();
        _indice = 0;
        _passo = _Passo.perguntas;
      }),
    );
  }

  void _responder(String opcao) {
    final pergunta = _perguntas[_indice];
    _respostas[pergunta['id'].toString()] = opcao;

    if (_indice < _perguntas.length - 1) {
      setState(() => _indice++);
      return;
    }

    _executar(
      () => ApiServices.primeiroAcesso(
        acao: 'responder',
        sessao: _sessao,
        respostas: _respostas,
      ),
      (r) => setState(() {
        // Sem e-mail no cadastro, o militar informa um agora e confirma por
        // código — assim ninguém fica preso com um endereço digitado errado.
        _passo = r['tem_email'] == true ? _Passo.senha : _Passo.email;
      }),
    );
  }

  void _enviarCodigoEmail() {
    final email = _emailCtrl.text.trim().toLowerCase();
    if (!RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$').hasMatch(email)) {
      setState(() => _erro = 'Informe um e-mail válido.');
      return;
    }
    _executar(
      () => ApiServices.primeiroAcesso(
        acao: 'enviar_codigo_email',
        sessao: _sessao,
        email: email,
      ),
      (r) => setState(() {
        _emailMascarado = (r['email'] ?? email).toString();
        _passo = _Passo.codigo;
      }),
    );
  }

  void _validarCodigoEmail() {
    final codigo = _codigoCtrl.text.replaceAll(RegExp(r'\D'), '');
    if (codigo.length != 6) {
      setState(() => _erro = 'Digite os 6 dígitos do código.');
      return;
    }
    _executar(
      () => ApiServices.primeiroAcesso(
        acao: 'validar_codigo_email',
        sessao: _sessao,
        codigo: codigo,
      ),
      (_) => setState(() => _passo = _Passo.senha),
    );
  }

  /// "Não sei": troca a pergunta atual por outra, sem perder a sessão.
  void _naoSei() {
    _executar(
      () => ApiServices.primeiroAcesso(
        acao: 'trocar_pergunta',
        sessao: _sessao,
        usadas: _usadas,
        atual: _perguntas[_indice]['id'].toString(),
      ),
      (r) {
        final nova = Map<String, dynamic>.from(r['pergunta'] as Map);
        setState(() {
          _respostas.remove(_perguntas[_indice]['id'].toString());
          _perguntas[_indice] = nova;
          _usadas.add(nova['id'].toString());
        });
      },
    );
  }

  void _definirSenha() {
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
      () => ApiServices.primeiroAcesso(
        acao: 'definir_senha',
        sessao: _sessao,
        senhaNovaMd5: _md5(senha),
      ),
      (r) => setState(() {
        _matricula = (r['matricula'] ?? '').toString();
        final m = (r['matriculas'] as Map?) ?? {};
        _segadNova = (m['segad_nova'] ?? '').toString();
        _segadAntiga = (m['segad_antiga'] ?? '').toString();
        _senhaCadastrada = senha;
        _emailEnviado = r['email_enviado'] == true;
        _passo = _Passo.concluido;
      }),
    );
  }

  /// Recomeça do zero: a sessão morre no servidor a cada erro.
  void _recomecar() {
    setState(() {
      _passo = _Passo.cpf;
      _sessao = '';
      _perguntas = [];
      _respostas.clear();
      _indice = 0;
      _erro = null;
    });
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(title: 'Primeiro acesso'),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        child: AnimatedSwitcher(
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
            _Passo.cpf => _telaCpf(),
            _Passo.perguntas => _telaPerguntas(),
            _Passo.email => _telaEmail(),
            _Passo.codigo => _telaCodigo(),
            _Passo.senha => _telaSenha(),
            _Passo.concluido => _telaConcluido(),
          },
        ),
      ),
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

  Widget _erroBox({bool comRecomecar = false}) {
    if (_erro == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        children: [
          AvisoCaixa(
            cor: Theme.of(context).colorScheme.error,
            icone: Icons.error_outline_rounded,
            texto: _erro!,
          ),
          if (comRecomecar)
            TextButton.icon(
              onPressed: _recomecar,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Recomeçar'),
            ),
        ],
      ),
    );
  }

  // ── Passo 1: CPF ──────────────────────────────────────────────────────────

  Widget _telaCpf() {
    return Column(
      key: const ValueKey('cpf'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _cabecalho(Icons.badge_rounded, 'Informe seu CPF',
            'Vamos confirmar sua identidade com algumas perguntas sobre seu cadastro na PMRR.'),
        const SizedBox(height: 24),
        TextField(
          controller: _cpfCtrl,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          maxLength: 14,
          inputFormatters: [_CpfFormatter()],
          onSubmitted: (_) => _iniciar(),
          decoration: decoracaoCampo(
            context: context,
            label: 'CPF',
            icon: Icons.pin_rounded,
          ).copyWith(counterText: ''),
        ),
        _erroBox(),
        const SizedBox(height: 20),
        SizedBox(
          height: 50,
          child: ElevatedButton.icon(
            onPressed: _carregando ? null : _iniciar,
            icon: _carregando
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.arrow_forward_rounded, size: 18),
            label: Text(_carregando ? 'Verificando...' : 'Continuar'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              textStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5),
            ),
          ),
        ),
        const SizedBox(height: 16),
        const AvisoCaixa(
          cor: AppColors.lightBlue,
          icone: Icons.shield_outlined,
          texto: 'Responda apenas se os dados forem seus. Errar qualquer '
              'pergunta encerra a verificação, e várias tentativas erradas '
              'bloqueiam o CPF temporariamente.',
        ),
      ],
    );
  }

  // ── Passo 2: perguntas ────────────────────────────────────────────────────

  Widget _telaPerguntas() {
    final theme = Theme.of(context);
    final pergunta = _perguntas[_indice];
    final opcoes = List<String>.from(pergunta['opcoes'] as List);

    return Column(
      key: ValueKey('pergunta_$_indice'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Progresso das perguntas
        Row(
          children: List.generate(_perguntas.length, (i) {
            final feito = i <= _indice;
            return Expanded(
              child: Padding(
                padding:
                    EdgeInsets.only(right: i < _perguntas.length - 1 ? 6 : 0),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  height: 5,
                  decoration: BoxDecoration(
                    color: feito
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 18),
        Text(
          'Pergunta ${_indice + 1} de ${_perguntas.length}',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.70),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          pergunta['pergunta'].toString(),
          style:
              theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        if (pergunta['ajuda'] != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.lightBlue.withOpacity(0.10),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.lightBlue.withOpacity(0.30)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.help_outline_rounded,
                    size: 16, color: AppColors.lightBlue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    pergunta['ajuda'].toString(),
                    style: theme.textTheme.bodySmall?.copyWith(height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 20),

        for (final opcao in opcoes) ...[
          _OpcaoCard(
            texto: opcao,
            habilitado: !_carregando,
            onTap: () => _responder(opcao),
          ),
          const SizedBox(height: 10),
        ],

        if (_carregando)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Center(child: CircularProgressIndicator.adaptive()),
          ),

        const SizedBox(height: 4),
        TextButton.icon(
          onPressed: _carregando ? null : _naoSei,
          icon: const Icon(Icons.swap_horiz_rounded, size: 18),
          label: const Text('Não sei responder, trocar pergunta'),
          style: TextButton.styleFrom(
            foregroundColor: theme.colorScheme.onSurface.withOpacity(0.65),
            textStyle: const TextStyle(fontSize: 13),
          ),
        ),

        _erroBox(comRecomecar: true),
      ],
    );
  }


  // ── Passo 3a: cadastrar e-mail (quem não tem) ─────────────────────────────

  Widget _telaEmail() {
    return Column(
      key: const ValueKey('email'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _cabecalho(Icons.alternate_email_rounded, 'Cadastre seu e-mail',
            'Você ainda não tem e-mail no cadastro. Ele é necessário para '
            'recuperar a senha caso você esqueça.',
            cor: const Color(0xFF2E7D32)),
        const SizedBox(height: 24),
        TextField(
          controller: _emailCtrl,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _enviarCodigoEmail(),
          decoration: decoracaoCampo(
            context: context,
            label: 'Seu e-mail',
            icon: Icons.alternate_email_rounded,
          ),
        ),
        _erroBox(),
        const SizedBox(height: 20),
        _botaoPrincipal(
          texto: 'Enviar código',
          carregandoTexto: 'Enviando...',
          icone: Icons.send_rounded,
          aoTocar: _enviarCodigoEmail,
        ),
        const SizedBox(height: 16),
        const AvisoCaixa(
          cor: AppColors.gold,
          icone: Icons.priority_high_rounded,
          texto: 'Confira bem o endereço: enviaremos um código para confirmar '
              'que ele é seu antes de salvar no cadastro.',
        ),
      ],
    );
  }

  // ── Passo 3b: confirmar o código do e-mail ────────────────────────────────

  Widget _telaCodigo() {
    final theme = Theme.of(context);
    return Column(
      key: const ValueKey('codigo'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _cabecalho(Icons.sms_rounded, 'Confirme o código',
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
            if (v.length == 6) _validarCodigoEmail();
          },
          decoration: InputDecoration(
            counterText: '',
            hintText: '000000',
            hintStyle: TextStyle(
              letterSpacing: 14,
              color: theme.colorScheme.onSurface.withOpacity(0.18),
            ),
            filled: true,
            fillColor: theme.brightness == Brightness.dark
                ? AppColors.darkCard
                : Colors.white,
            contentPadding: const EdgeInsets.symmetric(vertical: 18),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: theme.brightness == Brightness.dark
                    ? AppColors.darkBorder
                    : const Color(0xFFE8EEF6),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide:
                  BorderSide(color: theme.colorScheme.primary, width: 1.6),
            ),
          ),
        ),
        _erroBox(),
        const SizedBox(height: 16),
        _botaoPrincipal(
          texto: 'Confirmar código',
          carregandoTexto: 'Conferindo...',
          icone: Icons.check_rounded,
          aoTocar: _validarCodigoEmail,
        ),
        const SizedBox(height: 10),
        TextButton(
          onPressed: _carregando
              ? null
              : () {
                  _codigoCtrl.clear();
                  setState(() {
                    _erro = null;
                    _passo = _Passo.email;
                  });
                },
          child: const Text('Corrigir o e-mail'),
        ),
        const AvisoCaixa(
          cor: AppColors.gold,
          icone: Icons.search_rounded,
          texto: 'Não chegou? Procure na pasta de spam ou lixo eletrônico.',
        ),
      ],
    );
  }

  /// Botão principal padrão das etapas.
  Widget _botaoPrincipal({
    required String texto,
    required String carregandoTexto,
    required IconData icone,
    required VoidCallback aoTocar,
  }) {
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
            : Icon(icone, size: 18),
        label: Text(_carregando ? carregandoTexto : texto),
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(
              fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 0.5),
        ),
      ),
    );
  }

  // ── Passo 3: senha ────────────────────────────────────────────────────────


  Widget _telaSenha() {
    return Column(
      key: const ValueKey('senha'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _cabecalho(Icons.lock_person_rounded, 'Identidade confirmada',
            'Agora crie a senha que você vai usar no SouPMRR e no SIGRH.',
            cor: const Color(0xFF2E7D32)),
        const SizedBox(height: 24),
        TextField(
          controller: _senhaCtrl,
          obscureText: !_verSenha,
          onChanged: (_) => setState(() {}),
          decoration: decoracaoCampo(
            context: context,
            label: 'Nova senha',
            icon: Icons.lock_outline_rounded,
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
          onSubmitted: (_) => _definirSenha(),
          decoration: decoracaoCampo(
            context: context,
            label: 'Repita a senha',
            icon: Icons.check_circle_outline_rounded,
          ),
        ),
        _erroBox(),
        const SizedBox(height: 20),
        SizedBox(
          height: 50,
          child: ElevatedButton.icon(
            onPressed: _carregando ? null : _definirSenha,
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
            label: Text(_carregando ? 'Salvando...' : 'Cadastrar senha'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              textStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5),
            ),
          ),
        ),
      ],
    );
  }

  // ── Passo 4: concluído ────────────────────────────────────────────────────

  Widget _telaConcluido() {
    final theme = Theme.of(context);
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
              child:
                  const Icon(Icons.verified_rounded, size: 44, color: verde),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Tudo pronto!',
          textAlign: TextAlign.center,
          style: theme.textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.bold, color: verde),
        ),
        const SizedBox(height: 10),
        Text(
          'Sua senha foi cadastrada. Entre com a matrícula abaixo e a senha '
          'que você acabou de criar.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.70),
            height: 1.4,
          ),
        ),
        const SizedBox(height: 20),

        // Dados de acesso, para o militar anotar antes de sair da tela.
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: verde.withOpacity(0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: verde.withOpacity(0.35)),
          ),
          child: Column(
            children: [
              Text(
                'SEUS DADOS DE ACESSO',
                style: theme.textTheme.bodySmall?.copyWith(
                  letterSpacing: 1,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
              const SizedBox(height: 14),
              _LinhaDado(
                rotulo: 'Matrícula PMRR',
                valor: _matricula,
                legenda: 'use esta para entrar no app',
                destaque: true,
              ),
              if (_segadNova.isNotEmpty) ...[
                const SizedBox(height: 12),
                Divider(color: verde.withOpacity(0.25), height: 1),
                const SizedBox(height: 12),
                _LinhaDado(
                    rotulo: 'Matrícula SEGAD (nova)', valor: _segadNova),
              ],
              if (_segadAntiga.isNotEmpty) ...[
                const SizedBox(height: 12),
                Divider(color: verde.withOpacity(0.25), height: 1),
                const SizedBox(height: 12),
                _LinhaDado(
                    rotulo: 'Matrícula SEGAD (antiga)', valor: _segadAntiga),
              ],
              const SizedBox(height: 12),
              Divider(color: verde.withOpacity(0.25), height: 1),
              const SizedBox(height: 12),
              _LinhaDado(rotulo: 'Senha', valor: _senhaCadastrada),
            ],
          ),
        ),
        const SizedBox(height: 14),

        AvisoCaixa(
          cor: _emailEnviado ? AppColors.lightBlue : AppColors.gold,
          icone: _emailEnviado
              ? Icons.mark_email_read_outlined
              : Icons.info_outline_rounded,
          texto: _emailEnviado
              ? 'Enviamos sua matrícula para o e-mail cadastrado. Por '
                  'segurança, a senha não vai por e-mail: anote-a agora.'
              : 'Anote esses dados: não há e-mail cadastrado para enviá-los.',
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

// ── Cartão de alternativa ───────────────────────────────────────────────────

class _OpcaoCard extends StatelessWidget {
  final String texto;
  final bool habilitado;
  final VoidCallback onTap;

  const _OpcaoCard({
    required this.texto,
    required this.habilitado,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      color: isDark ? AppColors.darkCard.withOpacity(0.72) : Colors.white.withOpacity(0.78),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: habilitado ? onTap : null,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? Colors.white.withOpacity(0.10) : Colors.white.withOpacity(0.80),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  texto,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: theme.colorScheme.onSurface.withOpacity(0.3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Máscara de CPF ──────────────────────────────────────────────────────────

class _CpfFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue antigo,
    TextEditingValue novo,
  ) {
    final digitos = novo.text.replaceAll(RegExp(r'\D'), '');
    final limitado = digitos.length > 11 ? digitos.substring(0, 11) : digitos;

    final buffer = StringBuffer();
    for (var i = 0; i < limitado.length; i++) {
      if (i == 3 || i == 6) buffer.write('.');
      if (i == 9) buffer.write('-');
      buffer.write(limitado[i]);
    }

    final texto = buffer.toString();
    return TextEditingValue(
      text: texto,
      selection: TextSelection.collapsed(offset: texto.length),
    );
  }
}

// ── Linha de dado na tela final ─────────────────────────────────────────────

class _LinhaDado extends StatelessWidget {
  final String rotulo;
  final String valor;
  final String? legenda;
  final bool destaque;

  const _LinhaDado({
    required this.rotulo,
    required this.valor,
    this.legenda,
    this.destaque = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(
          rotulo.toUpperCase(),
          style: theme.textTheme.bodySmall?.copyWith(
            fontSize: 10.5,
            letterSpacing: 0.8,
            color: theme.colorScheme.onSurface.withOpacity(0.70),
          ),
        ),
        const SizedBox(height: 4),
        SelectableText(
          valor,
          textAlign: TextAlign.center,
          style: (destaque
                  ? theme.textTheme.headlineSmall
                  : theme.textTheme.titleMedium)
              ?.copyWith(
            fontWeight: FontWeight.bold,
            color: const Color(0xFF2E7D32),
          ),
        ),
        if (legenda != null)
          Text(
            legenda!,
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 10.5,
              color: theme.colorScheme.onSurface.withOpacity(0.70),
            ),
          ),
      ],
    );
  }
}
