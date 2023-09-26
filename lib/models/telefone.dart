enum Tipos { whats, comum }

class Telefone {
  String numeroTel;
  Tipos tipo;
  bool value;

  Telefone({required this.numeroTel, required this.tipo, required this.value});
}
