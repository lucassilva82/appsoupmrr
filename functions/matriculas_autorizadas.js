// ============================================================================
//  Lista de matrículas AUTORIZADAS a receber notificações INDIVIDUAIS.
// ----------------------------------------------------------------------------
//  Como funciona:
//   - Enquanto `restrito` for true, SOMENTE as matrículas listadas em
//     `autorizados` recebem notificações individuais (função notificarEscala).
//   - As notificações para TODOS (notificarTodos) NÃO são afetadas — continuam
//     chegando para todos os militares normalmente.
//
//  Para LIBERAR geral no futuro (tirar a restrição):
//   - Troque `restrito` para false  (ou deixe a lista `autorizados` vazia)
//   - Rode novamente o deploy.
//
//  IMPORTANTE: após editar este arquivo, aplique com:
//     firebase deploy --only functions:notificarEscala
// ============================================================================

module.exports = {
  // true  = só as matrículas abaixo recebem notificação individual
  // false = todos recebem (sem restrição)
  restrito: true,

  // Coloque aqui as matrículas autorizadas (como texto, entre aspas).
  // Exemplo:
  //   autorizados: [
  //     "123456",
  //     "789012",
  //   ],
  autorizados: [
    "452955",
    "405558",
    "409995",
    "452912",
    "415928",
    "402575",
    "407836",
  ],
};
