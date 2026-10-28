import 'package:flutter/material.dart';
import 'package:projetonovo/widgets/custom_appbar.dart';
import 'package:provider/provider.dart';

import '../core/design/arte_cartao.dart';
import '../models/auth_model.dart';
import '../utils/app_theme.dart';
import '../models/militar.dart';
import '../services/dados_sql.dart';
import '../widgets/dados_militar.dart';
import '../widgets/vidro.dart';

// ── PageMilitarBody ───────────────────────────────────────────────────────────
// Conteúdo da aba "Perfil" dentro do MainShell.
class PageMilitarBody extends StatefulWidget {
  const PageMilitarBody({Key? key}) : super(key: key);

  @override
  State<PageMilitarBody> createState() => _PageMilitarBodyState();
}

class _PageMilitarBodyState extends State<PageMilitarBody>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  Future<Militar?>? _future;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<Auth>(context, listen: false);
      setState(() {
        _future = DadosSql().buscarMilitarBancoByMatricula(auth.matricula!);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_future == null) {
      return const Center(child: CircularProgressIndicator.adaptive());
    }

    return FutureBuilder<Militar?>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator.adaptive());
        }
        if (snapshot.hasData && snapshot.data != null) {
          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 24),
            child: DadosMilitar(militar: snapshot.data!),
          );
        }
        if (snapshot.hasError) {
          return _ErrorState(error: snapshot.error.toString());
        }
        return const _ErrorState(
            error: 'Dados não encontrados. Verifique sua conexão.');
      },
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String error;
  const _ErrorState({Key? key, required this.error}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Estado de erro numa caixa de vidro com a arte da área (padrão 2.2).
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: CartaoVidro(
          arte: Arte.de('rh'),
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ExcludeSemantics(
                child: Icon(Icons.cloud_off_rounded,
                    size: AppIconSize.xl, color: theme.colorScheme.error),
              ),
              const SizedBox(height: 12),
              Text(
                'Não foi possível carregar os dados',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                error,
                style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.70)),
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── PageMilitar ───────────────────────────────────────────────────────────────
// Mantida para compatibilidade com rota existente.
class PageMilitar extends StatelessWidget {
  const PageMilitar({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FundoSuave(child: Scaffold(
      appBar: CustomAppBar(title: 'Ficha Individual'),
      body: const PageMilitarBody(),
    ));
  }
}
