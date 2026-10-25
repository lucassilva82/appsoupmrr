import 'package:flutter/material.dart';

import '../../app/registro_modulos.dart';
import '../../widgets/custom_appbar.dart';
import '../config/app_config.dart';
import '../log/registro_log.dart';
import 'abrir_funcao.dart';

/// O estado que o painel deu a cada função vale em **todo** caminho até a
/// tela (SOUPM_2_2 §5.2 e §5.4), não só em Serviços.
///
/// Bug de 25/10/2026: o Plano de férias em manutenção ficou apagado no menu,
/// mas o card da Início abria a tela pela rota, sem passar pelo
/// `abrirFuncao`. Por isso a guarda fica na própria rota: card, push, link,
/// "mais usados" ou qualquer `pushNamed` que vier depois cai aqui.
Map<String, WidgetBuilder> protegerRotas(Map<String, WidgetBuilder> rotas) => {
      for (final e in rotas.entries)
        e.key: switch (registroModulos.porRota(e.key)) {
          final m? => (c) => GuardaFuncao(chave: m.chave, child: e.value(c)),
          null => e.value,
        },
    };

/// A tela da função, ou, se o painel a bloqueou, a mesma mensagem da folha
/// de bloqueio no lugar dela, com o código `MD-…`. Acompanha o `app_config`:
/// se o painel tirar a manutenção com a tela aberta, ela volta sozinha.
class GuardaFuncao extends StatelessWidget {
  const GuardaFuncao({super.key, required this.chave, required this.child});

  final String chave;
  final Widget child;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<AppConfig>(
        valueListenable: RepositorioConfig.emUso,
        builder: (context, config, _) {
          // A árvore inteira, inclusive o que está fora do menu: "fora do
          // menu" não libera uma função em manutenção (§5.4).
          final item = config.item(chave);
          if (item == null || !item.bloqueado) return child;
          return TelaBloqueio(item: item);
        },
      );
}

/// A folha de bloqueio como tela, para quem chegou à função sem passar pelo
/// menu (§5.2: "a tela mostra o mesmo conteúdo no lugar dela").
class TelaBloqueio extends StatefulWidget {
  const TelaBloqueio({super.key, required this.item});
  final ItemMenu item;

  @override
  State<TelaBloqueio> createState() => _TelaBloqueioState();
}

class _TelaBloqueioState extends State<TelaBloqueio> {
  late final MensagemBloqueio _m = mensagemDoBloqueio(widget.item);

  @override
  void initState() {
    super.initState();
    registrar('modulo.bloqueio_visto',
        chave: widget.item.chave, codigo: _m.codigo, dados: {'motivo': _m.motivo, 'origem': 'rota'});
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: CustomAppBar(title: widget.item.rotulo),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: FolhaBloqueio(mensagem: _m, arte: arteDaChave(widget.item.chave)),
                ),
              ),
            ),
          ),
        ),
      );
}
