import 'package:flutter_test/flutter_test.dart';
import 'package:projetonovo/core/config/app_config.dart';

void main() {
  test('textos do painel e imagem aprovada da área', () {
    final c = AppConfig.deJson({
      'textos': {'rodape_inicio': 'Desenvolvido pelo DTI', 'botao_erro': '  ', 'outro': 3},
      'menu': [
        {'chave': 'rh', 'tipo': 'area', 'rotulo': 'Minha vida funcional',
         'arte_imagem': 'https://pmrr.online/painelsoupmrr/midia/abc.jpg', 'filhos': []},
        {'chave': 'normas', 'tipo': 'area', 'rotulo': 'Normas', 'arte_imagem': 'http://inseguro/x.jpg', 'filhos': []},
      ],
    }, origem: OrigemConfig.rede);
    expect(c.texto('rodape_inicio'), 'Desenvolvido pelo DTI');
    expect(c.texto('botao_erro'), isNull);
    expect(c.texto('outro'), isNull);
    expect(c.menu![0].arteImagem, 'https://pmrr.online/painelsoupmrr/midia/abc.jpg');
    expect(c.menu![1].arteImagem, isNull);
  });
}
