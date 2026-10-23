import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/config/app_config.dart';
import '../core/design/arte_cartao.dart';
import '../core/log/registro_log.dart';
import '../core/navegacao/abrir_funcao.dart';
import '../features/inicio/personalizar_inicio_page.dart';
import '../features/servicos/servicos_page.dart';
import '../models/auth_model.dart';
import '../utils/api_services.dart';
import '../utils/app_routes.dart';
import '../utils/app_theme.dart';
import '../utils/theme_provider.dart';
import '../widgets/custom_appbar.dart';
import '../widgets/aviso_rapido.dart';
import '../widgets/dialogo_confirmacao.dart';
import '../widgets/vidro.dart';
import '../widgets/versao_app.dart';
import 'alterar_senha_page.dart';
import 'confirm_email.dart';

// ── Perfil (protótipo `telaPerfil`) ──────────────────────────────────────────
// Cartão do militar com a capa da arte, "Configurações" e os grupos Conta,
// Segurança e aparência, Nível de acesso e Ajuda, "Sair da conta" e o
// rodapé. Aparência, Notificações e a biometria abrem telas próprias.

/// Nome da biometria como o aparelho chama.
String get nomeBiometria => Platform.isIOS ? 'Face ID' : 'Biometria';

class SettingsBody extends StatelessWidget {
  const SettingsBody({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<Auth>(context);
    final config = RepositorioConfig.atual;
    final nivel = config.nivel;

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        _CartaoMilitar(auth: auth, config: config),
        const SizedBox(height: 7),
        const _Titulo('Configurações'),

        // ── Conta ───────────────────────────────────────────────────────
        const _Rotulo('Conta'),
        _Grupo(arte: 'rh', linhas: [
          _EmailLinha(auth: auth),
          _Linha(
            icone: Icons.lock_reset_rounded,
            titulo: 'Alterar senha',
            texto: 'Vale para o SouPMRR e o SIGRH',
            aoTocar: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const AlterarSenhaPage())),
          ),
        ]),

        // ── Segurança e aparência ───────────────────────────────────────
        const _Rotulo('Segurança e aparência'),
        _Grupo(arte: 'cc', linhas: [
          _Linha(
            icone: Platform.isIOS ? Icons.face_rounded : Icons.fingerprint_rounded,
            titulo: nomeBiometria,
            texto: Platform.isIOS
                ? 'Entrar no app olhando para o iPhone · ${auth.useBiometrics ? 'ligado' : 'desligado'}'
                : 'Entrar com a digital ou o rosto · ${auth.useBiometrics ? 'ligada' : 'desligada'}',
            aoTocar: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const BiometriaPage())),
          ),
          _Linha(
            icone: Icons.palette_outlined,
            titulo: 'Aparência',
            texto: 'Tema e tela inicial',
            aoTocar: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const AparenciaPage())),
          ),
          _Linha(
            icone: Icons.notifications_outlined,
            titulo: 'Notificações',
            texto: 'O que avisar e quando',
            aoTocar: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const NotificacoesPreferenciasPage())),
          ),
        ]),

        // ── Nível de acesso (§6.2) ──────────────────────────────────────
        const _Rotulo('Nível de acesso'),
        _CartaoNivel(nome: nivel?.nome ?? 'Militar', escopo: nivel?.escopo ?? 'Seus próprios dados'),

        // ── Ajuda (§8: todo suporte é chamado técnico) ──────────────────
        const _Rotulo('Ajuda'),
        _Grupo(arte: 'atendimento', linhas: [
          for (final (chave, icone, titulo, texto) in const [
            ('atend.ajuda', Icons.help_outline_rounded, 'Preciso de ajuda', 'Respostas rápidas para as dúvidas mais comuns'),
            (
              'atend.chamados',
              Icons.confirmation_number_outlined,
              'Meus chamados',
              'Suporte técnico: erro no app, acesso, senha, rede, equipamento'
            ),
            ('atend.feedback', Icons.lightbulb_outline_rounded, 'Sugestões e elogios', 'Ideias de melhoria e funções novas para o DTI'),
          ])
            _Linha(
              icone: icone,
              titulo: titulo,
              texto: texto,
              selo: _seloDe(chave, auth),
              aoTocar: () => _abrirAjuda(context, auth, chave),
            ),
        ]),
        const SizedBox(height: 12),

        // ── Sair ────────────────────────────────────────────────────────
        CartaoVidro(
          padding: EdgeInsets.zero,
          child: _Linha(
            icone: Icons.logout_rounded,
            titulo: 'Sair da conta',
            cor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFFFF9E9E) : const Color(0xFFB3261E),
            seta: false,
            aoTocar: () => _confirmLogout(context, auth),
          ),
        ),

        // ── Rodapé ──────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.only(top: 18, bottom: 12),
          child: DefaultTextStyle(
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 12, height: 1.35, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: .62)),
            child: Column(children: [
              TextoVersao(
                formato: (v) => v.isEmpty
                    ? 'SouPMRR · Diretoria de Recursos Humanos - PMRR'
                    : 'SouPMRR $v · Diretoria de Recursos Humanos - PMRR',
              ),
              const Text('Desenvolvido pelo DTI/PMRR'),
            ]),
          ),
        ),
      ],
    );
  }

  /// Selo de estado da função no menu (o "Novo" das sugestões).
  static String? _seloDe(String chave, Auth auth) =>
      itemPorChave(chave, menu: menuEmUso(RepositorioConfig.atual, gestor: auth.isSuperUser))?.selo;

  /// Abre pelo menu, para valer o estado do painel (Meus chamados "Em
  /// breve", por exemplo, mostra a folha de bloqueio).
  void _abrirAjuda(BuildContext context, Auth auth, String chave) {
    final item = itemPorChave(chave, menu: menuEmUso(RepositorioConfig.atual, gestor: auth.isSuperUser));
    if (item != null) {
      abrirFuncao(context, item, origem: 'perfil');
    } else if (chave == 'atend.ajuda') {
      Navigator.of(context).pushNamed(AppRoutes.AJUDA_PAGE);
    } else {
      avisoAtencao(context, 'Função indisponível',
          texto: 'Esta função não está disponível para você agora. '
              'Código MD-${chave.toUpperCase()}-RESTRITO.');
    }
  }

  Future<void> _confirmLogout(BuildContext context, Auth auth) async {
    final confirm = await dialogoConfirmacao(
      context,
      titulo: 'Sair da conta',
      mensagem: 'Você precisará informar matrícula e senha para entrar '
          'novamente.',
      textoConfirmar: 'Sair',
      icone: Icons.logout_rounded,
      cor: const Color(0xFFC62828),
    );
    if (confirm) {
      // Limpa a pilha de rotas até a raiz para que o modal biométrico
      // apareça sobre o fundo da tela de login, não sobre esta página.
      if (context.mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
      auth.logout();
    }
  }
}

// ── Peças ────────────────────────────────────────────────────────────────────

class _Titulo extends StatelessWidget {
  const _Titulo(this.texto);
  final String texto;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 0, 2, 0),
        child: Semantics(
          header: true,
          child: Text(texto,
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                  height: 1.35,
                  color: Theme.of(context).colorScheme.onSurface)),
        ),
      );
}

/// Rótulo de grupo (protótipo `.rot`): 11, caixa alta, na cor de ação.
class _Rotulo extends StatelessWidget {
  const _Rotulo(this.texto);
  final String texto;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 12, 4, 6),
        child: Semantics(
          header: true,
          child: Text(texto.toUpperCase(),
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: .88,
                  color: Theme.of(context).colorScheme.primary)),
        ),
      );
}

/// Grupo de vidro com a arte discreta e as linhas separadas por um fio.
class _Grupo extends StatelessWidget {
  const _Grupo({required this.arte, required this.linhas});
  final String arte;
  final List<Widget> linhas;

  @override
  Widget build(BuildContext context) {
    final fio = Theme.of(context).colorScheme.onSurface.withValues(alpha: .10);
    return CartaoVidro(
      padding: EdgeInsets.zero,
      child: Stack(children: [
        ArteDiscreta(arte: Arte.de(arte)),
        Column(children: [
          for (final (i, l) in linhas.indexed) ...[
            if (i > 0) Divider(height: 1, thickness: 1, color: fio),
            l,
          ],
        ]),
      ]),
    );
  }
}

/// Linha de 56 (protótipo `.grupo .linha`): ícone na cor de ação, título,
/// apoio em cinza e a seta.
class _Linha extends StatelessWidget {
  const _Linha({
    required this.icone,
    required this.titulo,
    required this.aoTocar,
    this.texto,
    this.textoCor,
    this.cor,
    this.selo,
    this.seta = true,
    this.direita,
  });

  final IconData icone;
  final String titulo;
  final String? texto;
  final Color? textoCor;
  final Color? cor;
  final String? selo;
  final bool seta;
  final Widget? direita;
  final VoidCallback? aoTocar;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = cor ?? theme.colorScheme.primary;
    final mudo = theme.colorScheme.onSurface.withValues(alpha: .62);
    return InkWell(
      onTap: aoTocar,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 54),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Row(children: [
            SizedBox(width: 36, height: 36, child: Icon(icone, size: AppIconSize.sm, color: c)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Row(children: [
                  Flexible(
                    child: Text(titulo,
                        style: TextStyle(
                            fontSize: 15.5,
                            height: 1.35,
                            fontWeight: FontWeight.w500,
                            color: cor ?? theme.colorScheme.onSurface)),
                  ),
                  if (selo != null) ...[const SizedBox(width: 6), SeloEstado(texto: selo!)],
                ]),
                if (texto != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Text(texto!, style: TextStyle(fontSize: 12.5, height: 1.35, color: textoCor ?? mudo)),
                  ),
              ]),
            ),
            if (direita != null) direita!,
            if (seta) Icon(Icons.chevron_right_rounded, size: 20, color: theme.colorScheme.onSurface.withValues(alpha: .45)),
          ]),
        ),
      ),
    );
  }
}

/// O cartão do militar: capa com a arte da área, a foto sobreposta na borda,
/// nome, matrícula, lotação por extenso e o nível. Toque abre a Ficha.
class _CartaoMilitar extends StatelessWidget {
  const _CartaoMilitar({required this.auth, required this.config});
  final Auth auth;
  final AppConfig config;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mudo = theme.colorScheme.onSurface.withValues(alpha: .62);

    ImageProvider? foto;
    final local = auth.localImagePath;
    if (local != null && local.isNotEmpty && File(local).existsSync()) {
      foto = FileImage(File(local));
    } else if ((auth.image ?? '').startsWith('https://') && !auth.image!.endsWith('/')) {
      // Endereço que termina em "/" é a pasta das fotos sem o arquivo: o
      // militar não tem foto, e valem as iniciais.
      foto = NetworkImage(auth.image!);
    }

    final posto = (auth.nomeMilitar ?? '').trim().split(RegExp(r'\s+')).first;
    final completo = (auth.nomeCompleto ?? '').trim();
    final nome = completo.isEmpty ? (auth.nomeMilitar ?? 'Militar') : '$posto $completo'.trim();
    final partes = completo.isEmpty ? nome.split(' ') : completo.split(RegExp(r'\s+'));
    final iniciais = partes.length >= 2
        ? '${partes.first[0]}${partes.last[0]}'.toUpperCase()
        : (partes.first.isNotEmpty ? partes.first[0].toUpperCase() : '?');
    final lotacao = config.lotacaoPorExtenso;
    final nivel = config.nivel?.nome ?? 'Militar';
    final escuro = theme.brightness == Brightness.dark;
    final fundoPagina = escuro ? const Color(0xFF03050A) : theme.colorScheme.surface;

    return Semantics(
      button: true,
      label: '$nome, matrícula ${auth.matricula ?? ''}. Abrir a ficha individual',
      child: CartaoVidro(
        raio: 18,
        padding: EdgeInsets.zero,
        onTap: () {
          registrar('funcao.tocar', chave: 'perfil.ficha', dados: {'origem': 'perfil'});
          Navigator.of(context).pushNamed(AppRoutes.PAGE_MILITAR);
        },
        // A foto (64) desce 32 da capa (78) e o texto começa 8 abaixo dela.
        child: Stack(children: [
          Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SizedBox(
              height: 78,
              child: FundoArte(
                arte: Arte.de('rh'),
                raio: 0,
                tamanhoIcone: 90,
                child: const Align(
                  alignment: Alignment(0.95, 0.4),
                  child: Icon(Icons.chevron_right_rounded, color: Colors.white, size: 20),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 41, 16, 14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(nome,
                    style: TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w700, height: 1.35, color: theme.colorScheme.onSurface)),
                Text('Matrícula ${auth.matricula ?? '-'}', style: TextStyle(fontSize: 13, height: 1.35, color: mudo)),
                if (lotacao.isNotEmpty) Text(lotacao, style: TextStyle(fontSize: 12.5, height: 1.35, color: mudo)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurface.withValues(alpha: .06),
                    border: Border.all(color: theme.colorScheme.onSurface.withValues(alpha: .10)),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.person_outline_rounded, size: 16, color: theme.colorScheme.onSurface),
                    const SizedBox(width: 4),
                    Text('Nível: $nivel',
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface)),
                  ]),
                ),
              ]),
            ),
          ]),
          Positioned(
            left: 16,
            top: 46,
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: fundoPagina, width: 3),
                gradient: const LinearGradient(
                  begin: Alignment(-0.6, -1),
                  end: Alignment(0.6, 1),
                  colors: [Color(0xFF1B3A66), Color(0xFF0A1726)],
                ),
                image: foto == null
                    ? null
                    : DecorationImage(image: foto, fit: BoxFit.cover, alignment: Alignment.topCenter),
              ),
              alignment: Alignment.center,
              child: foto == null
                  ? Text(iniciais,
                      style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w700, color: Color(0xFFBFD6F2)))
                  : null,
            ),
          ),
        ]),
      ),
    );
  }
}

/// Cartão do nível de acesso (§6.2), com a arte discreta da Gestão.
class _CartaoNivel extends StatelessWidget {
  const _CartaoNivel({required this.nome, required this.escopo});
  final String nome;
  final String escopo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mudo = theme.colorScheme.onSurface.withValues(alpha: .62);
    return CartaoVidro(
      padding: EdgeInsets.zero,
      child: Stack(children: [
        ArteDiscreta(arte: Arte.de('gestao')),
        Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(nome, style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, color: theme.colorScheme.onSurface)),
            Text('Escopo: $escopo', style: TextStyle(fontSize: 12.5, height: 1.35, color: mudo)),
            const SizedBox(height: 8),
            Text(
              'Definido pela sua função no SIGRH e pelo painel do SouPMRR. Se estiver errado, '
              'fale com a seção de pessoal da sua OPM.',
              style: TextStyle(fontSize: 12.5, height: 1.35, color: mudo),
            ),
          ]),
        ),
      ]),
    );
  }
}

// ── E-mail ───────────────────────────────────────────────────────────────────
// Confirmado → mostra o endereço; pendente → em laranja, leva à confirmação.
class _EmailLinha extends StatefulWidget {
  const _EmailLinha({required this.auth});
  final Auth auth;

  @override
  State<_EmailLinha> createState() => _EmailLinhaState();
}

class _EmailLinhaState extends State<_EmailLinha> {
  /// O banco grava este valor em `activation_code` quando o militar confirma
  /// o e-mail pelo link.
  static const _codigoVerificado = 'pmrr190!@';

  @override
  void initState() {
    super.initState();
    _sincronizarStatus();
  }

  /// Confere no servidor a situação real do e-mail: o militar pode ter
  /// confirmado o link em outro aparelho desde o último login.
  Future<void> _sincronizarStatus() async {
    final matricula = widget.auth.matricula ?? '';
    if (matricula.isEmpty) return;
    final status = await ApiServices.checkEmailStatus(matricula);
    if (!mounted || status['code'] != 1) return;
    final verificadoServidor = status['verificado'] == true;
    final verificadoLocal = widget.auth.activationCode == _codigoVerificado;
    if (verificadoServidor != verificadoLocal) {
      await widget.auth.atualizarStatusEmail(verificado: verificadoServidor);
    }
  }

  @override
  Widget build(BuildContext context) {
    final verificado = widget.auth.activationCode == _codigoVerificado;
    final email = (widget.auth.emailUser ?? '').trim();
    const laranja = Color(0xFFE65100);
    return _Linha(
      icone: Icons.mail_outline_rounded,
      titulo: 'E-mail',
      texto: verificado
          ? (email.isEmpty ? 'Toque para cadastrar' : '$email · confirmado')
          : 'Não confirmado · necessário para recuperar a senha',
      textoCor: verificado ? null : laranja,
      aoTocar: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ConfirmEmailScreen())),
    );
  }
}

// ── Telas abertas pelo Perfil ────────────────────────────────────────────────

/// Corpo comum das telas do Perfil: barra própria e a lista com 16 de margem.
class _TelaPerfil extends StatelessWidget {
  const _TelaPerfil({required this.titulo, required this.filhos});
  final String titulo;
  final List<Widget> filhos;

  @override
  Widget build(BuildContext context) => FundoSuave(
        child: Scaffold(
          appBar: CustomAppBar(title: titulo),
          body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 32), children: filhos),
        ),
      );
}

/// Aparência (§4.5): tema, tela inicial e texto.
class AparenciaPage extends StatelessWidget {
  const AparenciaPage({super.key});

  @override
  Widget build(BuildContext context) {
    final temas = Provider.of<ThemeProvider>(context);
    final theme = Theme.of(context);
    Widget opcao(AppThemeMode m, IconData icone, String titulo, String texto) {
      final escolhido = temas.mode == m;
      return _Linha(
        icone: icone,
        titulo: titulo,
        texto: texto,
        seta: false,
        direita: escolhido
            ? Icon(Icons.check_circle_rounded, size: 22, color: theme.colorScheme.primary)
            : const SizedBox(width: 22),
        aoTocar: () {
          temas.setMode(m);
          registrar('aparencia.tema', chave: 'apar.tema', dados: {'tema': m.name});
        },
      );
    }

    return _TelaPerfil(titulo: 'Aparência', filhos: [
      const _Rotulo('Tema'),
      _Grupo(arte: 'dc', linhas: [
        opcao(AppThemeMode.auto, Icons.brightness_auto_outlined, 'Automático', 'Segue o tema do aparelho'),
        opcao(AppThemeMode.light, Icons.light_mode_outlined, 'Claro', 'Fundo claro, bom sob o sol'),
        opcao(AppThemeMode.dark, Icons.dark_mode_outlined, 'Escuro', 'Fundo escuro, descansa a vista à noite'),
      ]),
      const _Rotulo('Tela inicial'),
      _Grupo(arte: 'cc', linhas: [
        _Linha(
          icone: Icons.dashboard_customize_outlined,
          titulo: 'Reorganizar a tela inicial',
          texto: 'Mudar a ordem dos blocos, esconder o que não usa e escolher os atalhos',
          aoTocar: () =>
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PersonalizarInicioPage())),
        ),
        _Linha(
          icone: Icons.restart_alt_rounded,
          titulo: 'Restaurar o padrão da PMRR',
          texto: 'Volta a ordem e os atalhos de fábrica',
          seta: false,
          aoTocar: () async {
            final ok = await dialogoConfirmacao(
              context,
              titulo: 'Restaurar o padrão da PMRR?',
              mensagem: 'A ordem dos blocos e os atalhos voltam a ser os da PMRR.',
              textoConfirmar: 'Restaurar',
              icone: Icons.restart_alt_rounded,
            );
            if (!ok || !context.mounted) return;
            await repositorioPreferencias(context).restaurar();
            if (context.mounted) avisoSucesso(context, 'Tela inicial restaurada');
          },
        ),
      ]),
      const _Rotulo('Texto'),
      _Grupo(arte: 'rh', linhas: [
        _Linha(
          icone: Icons.format_size_rounded,
          titulo: 'Tamanho do texto',
          texto: 'Segue o tamanho escolhido nos ajustes do aparelho',
          seta: false,
          aoTocar: null,
        ),
      ]),
    ]);
  }
}

/// Notificações (P3): o aparelho e os lembretes que a PMRR define no painel.
class NotificacoesPreferenciasPage extends StatelessWidget {
  const NotificacoesPreferenciasPage({super.key});

  /// Padrão de reserva; o painel define os lembretes (soupm_lembrete).
  static const _lembretes = [
    ('Férias vão começar', '7 dias antes'),
    ('Certidão vai vencer', '3 dias antes'),
    ('Prazo de declaração anual', '15 e 3 dias antes'),
    ('Contracheque do mês saiu', 'no dia'),
    ('Comunicado com ciência obrigatória', 'na publicação e no prazo'),
  ];

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<Auth>(context);
    final theme = Theme.of(context);
    final mudo = theme.colorScheme.onSurface.withValues(alpha: .62);
    return _TelaPerfil(titulo: 'Notificações', filhos: [
      const SizedBox(height: 8),
      _Grupo(arte: 'cc', linhas: [
        _Linha(
          icone: Icons.notifications_active_outlined,
          titulo: 'Notificações neste aparelho',
          texto: Platform.isIOS
              ? 'O sistema também pode desligar, no Ajustes do iPhone'
              : 'O sistema também pode desligar, nas configurações do aparelho',
          seta: false,
          direita: Switch.adaptive(
            value: auth.notificationsEnabled,
            onChanged: (v) async {
              if (!v) {
                final ok = await dialogoConfirmacao(
                  context,
                  titulo: 'Desligar as notificações?',
                  mensagem: 'Você deixa de receber o contracheque disponível, os comunicados oficiais '
                      'e os lembretes de prazo neste aparelho.',
                  textoConfirmar: 'Desligar',
                  icone: Icons.notifications_off_rounded,
                  cor: const Color(0xFFC62828),
                );
                if (!ok) return;
              }
              auth.setNotificationsEnabled(v);
            },
          ),
          aoTocar: null,
        ),
      ]),
      const _Rotulo('Lembretes da PMRR'),
      _Grupo(arte: 'pe', linhas: [
        for (final (titulo, quando) in _lembretes)
          _Linha(
            icone: Icons.alarm_rounded,
            titulo: titulo,
            texto: quando,
            seta: false,
            direita: Icon(Icons.lock_outline_rounded, size: 18, color: mudo),
            aoTocar: null,
          ),
      ]),
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 12, 4, 0),
        child: Text(
          'Os lembretes são definidos pela PMRR no painel e valem para todos. Não dá para desligar um por um.',
          style: TextStyle(fontSize: 12.5, height: 1.35, color: mudo),
        ),
      ),
    ]);
  }
}

/// Face ID ou biometria: liga e desliga neste aparelho.
class BiometriaPage extends StatelessWidget {
  const BiometriaPage({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<Auth>(context);
    final mudo = Theme.of(context).colorScheme.onSurface.withValues(alpha: .62);
    return _TelaPerfil(titulo: nomeBiometria, filhos: [
      const SizedBox(height: 8),
      _Grupo(arte: 'cc', linhas: [
        _Linha(
          icone: Platform.isIOS ? Icons.face_rounded : Icons.fingerprint_rounded,
          titulo: 'Entrar com $nomeBiometria',
          texto: auth.useBiometrics ? 'Ligado neste aparelho' : 'Desligado neste aparelho',
          seta: false,
          direita: Switch.adaptive(value: auth.useBiometrics, onChanged: auth.setBiometrics),
          aoTocar: () => auth.setBiometrics(!auth.useBiometrics),
        ),
      ]),
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 12, 4, 0),
        child: Text(
          Platform.isIOS
              ? 'Com Face ID ligado, o app abre sem pedir a senha, olhando para o iPhone. '
                  'Vale só para este aparelho.'
              : 'Com a biometria ligada, o app abre sem pedir a senha, com a digital ou o rosto. '
                  'Vale só para este aparelho.',
          style: TextStyle(fontSize: 12.5, height: 1.35, color: mudo),
        ),
      ),
    ]);
  }
}

// ── Configuracoes ─────────────────────────────────────────────────────────────
// Mantida para compatibilidade com rota existente.
class Configuracoes extends StatelessWidget {
  const Configuracoes({super.key});

  @override
  Widget build(BuildContext context) {
    return FundoSuave(
        child: Scaffold(
      appBar: CustomAppBar(title: 'Perfil'),
      body: const SettingsBody(),
    ));
  }
}
