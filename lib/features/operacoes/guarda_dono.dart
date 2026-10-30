// ─────────────────────────────────────────────────────────────────────────────
// A guarda de dono: o armazém do Operar só sobrevive se for de quem está
// logado no Sou PM agora.
//
// POR QUE ELA EXISTE. Não há logout dentro do módulo — decisão do Lucas em
// 30/10/2026: quem entra no Sou PM com uma matrícula só pode usar a conta
// daquela matrícula, e o único "sair" é o do Sou PM. Mas o token, o PIN, a
// escala, os avisos e as conversas do Operar moram no `localStorage` da
// WebView, que não morre com a sessão do app. Sem esta guarda, o militar A
// saía, o militar B entrava, e se o nosso `operar_token.php` falhasse para o B
// — nada injetado — a página subia com a sessão do A ainda viva: o B entrava
// como o A no sistema do GAPE.
//
// POR QUE EM JAVASCRIPT, E NÃO NO LOGOUT. No logout não existe WebView, e
// aquele armazém é dela. A limpeza nativa que o logout tenta
// (`armazem_operar.dart`) é melhor esforço: no Android não há como apagar
// `localStorage` por origem. Isto roda `AT_DOCUMENT_START`, antes do `app.js`
// do Operar, e é o único caminho pelo qual a página carrega — não tem como ser
// contornado.
//
// COMO ELE SABE DE QUEM É. Por uma chave NOSSA, `e26.soupm_dono`, e não pela
// `e26.matricula` do Operar: aquela pode vir na matrícula longa que o
// `/acesso` devolve, e comparar formatos diferentes faria a guarda apagar tudo
// a cada abertura.
//
// O QUE ELA NÃO APAGA: `e26.filaOrfa`. São registros feitos no campo e ainda
// não enviados — isso é fato, não cache. A fila do dono anterior é guardada em
// nome dele, na mesma chave e no mesmo formato do `entrar()` do Operar. Quem a
// devolve é o Operar, no próximo acesso daquele militar; o caminho do Sou PM
// não passa pelo `entrar()`, então hoje ela espera lá. Está anotado para o
// Cap Stenio (`docs/PENDENTE_USUARIO.md`).
// ─────────────────────────────────────────────────────────────────────────────
import 'dart:convert';

/// O script da guarda, em ES5 — roda no mesmo motor do app do Operar.
///
/// [matricula] é quem está logado no Sou PM; nula ou vazia significa que não
/// há como atribuir o armazém a ninguém, e então ele é esvaziado.
/// [token] é o token que a tela vai plantar logo depois, usado para reconhecer
/// como nosso um armazém que ainda não tem etiqueta (é o caso de quem já usava
/// o módulo antes desta versão).
/// [forcar] vem da marca que o logout deixa: esvazia mesmo que o militar que
/// volta seja o mesmo, porque sair do Sou PM é sair do Operar.
String guardaDeDonoJs({String? matricula, String? token, bool forcar = false}) {
  final eu = (matricula == null || matricula.isEmpty)
      ? 'null'
      : jsonEncode(matricula);
  final meu = token == null || token.isEmpty ? 'null' : jsonEncode(token);
  return '''
(function(){
  try{
    var ls = window.localStorage;
    var eu = $eu, meuToken = $meu, forcar = ${forcar ? 'true' : 'false'};
    if (!forcar && eu !== null) {
      var dono = null;
      try { dono = JSON.parse(ls.getItem('e26.soupm_dono')); } catch(e) { dono = null; }
      if (dono !== null && String(dono) === String(eu)) { return; }
      if (dono === null) {
        // Armazém sem etiqueta: ou é novo, ou é de antes desta versão. Se o
        // token guardado é o nosso, é deste militar — etiqueta e segue, para
        // um upgrade não pedir `/acesso` novo e derrubar o navegador dele.
        var tk = null;
        try { tk = JSON.parse(ls.getItem('e26.token')); } catch(e) { tk = null; }
        if (tk === null || (meuToken !== null && String(tk) === String(meuToken))) {
          ls.setItem('e26.soupm_dono', JSON.stringify(eu)); return;
        }
      }
    }
    var orfas = {};
    try { orfas = JSON.parse(ls.getItem('e26.filaOrfa')) || {}; } catch(e) { orfas = {}; }
    var fila = [];
    try { fila = JSON.parse(ls.getItem('e26.fila')) || []; } catch(e) { fila = []; }
    var anterior = null;
    try { anterior = JSON.parse(ls.getItem('e26.matricula')); } catch(e) { anterior = null; }
    if (anterior && fila.length) { orfas[anterior] = (orfas[anterior] || []).concat(fila); }
    var fora = [];
    for (var i = 0; i < ls.length; i++) {
      var k = ls.key(i);
      if (k && k.indexOf('e26.') === 0) { fora.push(k); }
    }
    for (var j = 0; j < fora.length; j++) { ls.removeItem(fora[j]); }
    var sobrou = false;
    for (var q in orfas) { if (orfas.hasOwnProperty(q)) { sobrou = true; break; } }
    if (sobrou) { ls.setItem('e26.filaOrfa', JSON.stringify(orfas)); }
    if (eu !== null) { ls.setItem('e26.soupm_dono', JSON.stringify(eu)); }
  }catch(e){}
})();
''';
}
