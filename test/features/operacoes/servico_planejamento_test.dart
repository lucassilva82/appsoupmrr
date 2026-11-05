// Prova que o card só acusa "em planejamento" quando o Operar DIZ que a escala
// não foi fechada — e nunca por ausência do campo.
//
// A distinção importa: o `publicada` nasceu no Operar em 05/11/2026, e um
// Operar mais antigo não o manda. Tratar ausente como "em planejamento" seria
// afirmar sobre o mundo o que é falta do instrumento, e todo militar veria o
// aviso mesmo com a escala fechada.
import 'package:flutter_test/flutter_test.dart';
import 'package:projetonovo/features/operacoes/meu_servico.dart';

void main() {
  Map<String, Object?> servicoJson({Object? publicada = _ausente}) => {
        'data': '2026-11-06',
        'escala': 'Evento',
        'funcao': 'Patrulheiro',
        'posto': {'descricao': 'Evento · posto 15', 'hora_inicio': '20:00'},
        if (!identical(publicada, _ausente)) 'publicada': publicada,
      };

  group('ServicoOperacao.emPlanejamento', () {
    test('escala NÃO fechada: acusa planejamento', () {
      final s = ServicoOperacao.deJson(servicoJson(publicada: false))!;
      expect(s.publicada, isFalse);
      expect(s.emPlanejamento, isTrue);
    });

    test('escala fechada: não acusa', () {
      final s = ServicoOperacao.deJson(servicoJson(publicada: true))!;
      expect(s.publicada, isTrue);
      expect(s.emPlanejamento, isFalse);
    });

    test('Operar antigo, sem o campo: nulo é "não sei", NÃO é planejamento', () {
      final s = ServicoOperacao.deJson(servicoJson())!;
      expect(s.publicada, isNull);
      expect(s.emPlanejamento, isFalse);
    });

    test('campo de tipo inesperado não vira planejamento', () {
      final s = ServicoOperacao.deJson(servicoJson(publicada: 'nao'))!;
      expect(s.publicada, isNull);
      expect(s.emPlanejamento, isFalse);
    });

    test('escala fechada: o card diz "confirmada", nao fica calado', () {
      // A ausencia de aviso nao pode ser a mensagem: quem nao le nada nao sabe
      // se o card esta velho, se o app falhou ou se esta tudo certo.
      final s = ServicoOperacao.deJson(servicoJson(publicada: true))!;
      expect(s.publicada, isTrue, reason: 'o card mostra "Escala confirmada"');
      expect(s.emPlanejamento, isFalse);
    });

    test('o resto do serviço continua lido', () {
      final s = ServicoOperacao.deJson(servicoJson(publicada: false))!;
      expect(s.data, '2026-11-06');
      expect(s.escala, 'Evento');
      expect(s.posto, 'Evento · posto 15');
      expect(s.horaInicio, '20:00');
    });
  });
}

const Object _ausente = Object();
