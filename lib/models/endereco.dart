class Municipio {
  String id;
  String nome;

  Municipio({required this.id, required this.nome});

  static Municipio fromJson(Map<String, dynamic> json) =>
      Municipio(id: json['muni_cod'].toString(), nome: json['muni_nome']);
}

class Bairro {
  String id;
  String nome;

  Bairro({required this.id, required this.nome});

  static Bairro fromJson(Map<String, dynamic> json) =>
      Bairro(id: json['bair_cod'].toString(), nome: json['bair_nome']);
}

class Rua {
  String id;
  String nome;

  Rua({required this.id, required this.nome});

  static Rua fromJson(Map<String, dynamic> json) =>
      Rua(id: json['rua_cod'].toString(), nome: json['logradouro']);
}

class Endereco {
  Municipio? municipio;
  Bairro? bairro;
  Rua? rua;
  String? numero;
  String? cep;
  String? logradouro;

  static Endereco fromJson(Map<String, dynamic> json) => Endereco.log(
        logradouro: json['logradouro'],
        municipio:
            Municipio(id: json['muni_cod'].toString(), nome: json['muni_nome']),
        bairro:
            Bairro(id: json['bair_cod'].toString(), nome: json['bair_nome']),
        rua: Rua(id: json['rua_cod'].toString(), nome: json['rua']),
        numero: '',
        cep: '',
      );

  Endereco(this.municipio, this.bairro, this.rua, this.numero, this.cep);
  Endereco.log(
      {required this.logradouro,
      this.municipio,
      this.bairro,
      this.rua,
      this.numero,
      this.cep});
}
