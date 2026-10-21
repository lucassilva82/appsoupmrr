/**
 * Campos do aviso que o SIGE manda junto com { ids, titulo, mensagem, rota }:
 *   tipo_evento     "permuta_solicitada", "cancelada", ...
 *   referencia_id   id do assunto (escala, permuta, escala SVI...)
 *   notificacao_id  id em intranet.notificacoes_push
 *
 * Todos opcionais. Vão para o `data` do FCM (o app abre a tela do aviso pelo
 * notificacao_id) e para o histórico no Firestore (a lista do app abre o mesmo
 * aviso). Valor fora do formato é descartado, nunca recusado: o SIGE e as
 * versões antigas do app continuam funcionando como antes.
 */
const FORMATOS = {
  tipo_evento: /^[A-Za-z0-9_.-]{1,60}$/,
  referencia_id: /^\d{1,12}$/,
  notificacao_id: /^\d{1,12}$/,
};

function camposAviso(body) {
  const campos = {};
  const descartados = [];
  for (const [chave, formato] of Object.entries(FORMATOS)) {
    const bruto = body?.[chave];
    if (bruto === undefined || bruto === null || bruto === "") continue;
    const valor = String(bruto).trim();
    if (formato.test(valor)) {
      campos[chave] = valor;
    } else {
      descartados.push(chave);
    }
  }
  return { campos, descartados };
}

module.exports = { camposAviso };
