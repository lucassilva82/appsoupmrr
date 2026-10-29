import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../core/rede/api_client.dart';
import '../../models/auth_model.dart';
import 'mapa_efetivo.dart';

MapaEfetivoRepositorio repositorioMapaEfetivo(BuildContext context) {
  final auth = context.read<Auth>();
  return MapaEfetivoRepositorio(
    api: ApiClient(),
    matricula: auth.matricula ?? '',
    senhaMd5: md5.convert(utf8.encode(auth.password ?? '')).toString(),
  );
}
