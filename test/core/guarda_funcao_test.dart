import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:projetonovo/core/config/app_config.dart';
import 'package:projetonovo/core/navegacao/guarda_funcao.dart';
import 'package:projetonovo/utils/app_routes.dart';

/// Bug de 25/10/2026: o Plano de férias em manutenção ficou apagado só em
/// Serviços; o card da Início abria a tela mesmo assim, porque ia direto pela
/// rota. O estado da função tem de valer em todo caminho (SOUPM_2_2 §5.2).
AppConfig _config({required bool bloqueado, bool visivel = true}) => AppConfig(
      origem: OrigemConfig.rede,
      menu: [
        ItemMenu(chave: 'rh', tipo: 'area', rotulo: 'Minha vida funcional', filhos: [
          ItemMenu(
            chave: 'rh.ferias',
            tipo: 'funcao',
            rotulo: 'Plano de férias',
            rota: AppRoutes.PLANO_DE_FERIAS_PAGE,
            visivel: visivel,
            bloqueado: bloqueado,
            selo: bloqueado ? 'Manutenção' : null,
            mensagem: bloqueado
                ? const MensagemBloqueio(
                    motivo: 'manutencao',
                    titulo: 'Plano de férias em manutenção',
                    texto: 'Volta em breve.',
                    codigo: 'MD-RH.FERIAS-MANUTENCAO')
                : null,
          ),
        ]),
      ],
    );

Widget _app() => MaterialApp(
      home: Builder(
        builder: (c) => TextButton(
          onPressed: () => Navigator.of(c).pushNamed(AppRoutes.PLANO_DE_FERIAS_PAGE),
          child: const Text('abrir'),
        ),
      ),
      routes: protegerRotas({AppRoutes.PLANO_DE_FERIAS_PAGE: (_) => const Text('TELA DO PLANO DE FÉRIAS')}),
    );

void main() {
  tearDown(() => RepositorioConfig.atual = AppConfig.padrao);

  testWidgets('rota direta (card, push, link) de função em manutenção mostra o bloqueio, não a tela',
      (t) async {
    RepositorioConfig.atual = _config(bloqueado: true);
    await t.pumpWidget(_app());
    await t.tap(find.text('abrir'));
    await t.pumpAndSettle();
    expect(find.text('TELA DO PLANO DE FÉRIAS'), findsNothing);
    expect(find.text('Plano de férias em manutenção'), findsOneWidget);
    expect(find.textContaining('MD-RH.FERIAS-MANUTENCAO'), findsOneWidget);
  });

  testWidgets('fora do menu mas em manutenção também bloqueia', (t) async {
    RepositorioConfig.atual = _config(bloqueado: true, visivel: false);
    await t.pumpWidget(_app());
    await t.tap(find.text('abrir'));
    await t.pumpAndSettle();
    expect(find.text('TELA DO PLANO DE FÉRIAS'), findsNothing);
  });

  testWidgets('função ativa abre normalmente', (t) async {
    RepositorioConfig.atual = _config(bloqueado: false);
    await t.pumpWidget(_app());
    await t.tap(find.text('abrir'));
    await t.pumpAndSettle();
    expect(find.text('TELA DO PLANO DE FÉRIAS'), findsOneWidget);
  });
}
