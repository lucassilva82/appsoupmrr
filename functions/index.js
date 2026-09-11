const { onRequest } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");

admin.initializeApp();

// Lista de matrículas autorizadas a receber notificações INDIVIDUAIS.
// Edite o arquivo matriculas_autorizadas.js e faça deploy para atualizar.
const AUTORIZADOS = require("./matriculas_autorizadas");

/**
 * Lê a configuração de autorização de notificações a partir do arquivo
 * matriculas_autorizadas.js  { restrito: bool, autorizados: string[] }.
 *  - restrito = false (ou lista vazia): TODOS recebem (sem restrição).
 *  - restrito = true: SOMENTE as matrículas em 'autorizados' recebem.
 * Aplica-se APENAS às notificações individuais (notificarEscala).
 */
function carregarConfigNotificacoes() {
  const restrito = AUTORIZADOS?.restrito === true;
  const autorizados = new Set((AUTORIZADOS?.autorizados || []).map(String));
  return { restrito, autorizados };
}

/**
 * Envia notificação para uma lista de matrículas: busca os tokens FCM, grava
 * o histórico individual (coleção militares/{id}/notificacoes) e dispara o
 * push. Reutilizado por notificarEscala e por notificarTodos (modo restrito).
 */
async function enviarParaMatriculas(ids, { titulo, mensagem, rota }) {
  const db = admin.firestore();
  const idsStr = ids.map(String);

  // 1. Busca todos os tokens em paralelo
  const docs = await Promise.all(
    idsStr.map((id) => db.collection("militares").doc(id).get())
  );

  const tokens = [];
  const semToken = [];
  docs.forEach((doc, i) => {
    const token = doc.exists ? doc.data()?.fcmToken : null;
    if (token) {
      tokens.push(token);
    } else {
      semToken.push(idsStr[i]);
    }
  });

  // 2. Persiste o histórico individual de cada militar (fonte de verdade da
  //    lista interna do app — funciona mesmo com o app fechado).
  const agora = admin.firestore.FieldValue.serverTimestamp();
  await Promise.all(
    idsStr.map((id) =>
      db
        .collection("militares")
        .doc(id)
        .collection("notificacoes")
        .add({
          title: titulo,
          body: mensagem,
          route: rota ?? "",
          read: false,
          timestamp: agora,
        })
        .catch((e) => {
          console.error(`Falha ao gravar histórico para ${id}:`, e);
        })
    )
  );

  // 3. Envia em lotes de até 500 (limite do FCM por chamada)
  const payload = {
    notification: { title: titulo, body: mensagem },
    data: { route: rota ?? "", titulo, mensagem },
    android: { priority: "high" },
    apns: { payload: { aps: { sound: "default" } } },
  };

  const BATCH = 500;
  let enviados = 0;
  let falhas = 0;
  for (let i = 0; i < tokens.length; i += BATCH) {
    const lote = tokens.slice(i, i + BATCH);
    if (lote.length === 1) {
      try {
        await admin.messaging().send({ ...payload, token: lote[0] });
        enviados++;
      } catch (e) {
        falhas++;
      }
    } else {
      const result = await admin.messaging().sendEachForMulticast({
        ...payload,
        tokens: lote,
      });
      enviados += result.successCount;
      falhas += result.failureCount;
    }
  }

  return { enviados, falhas, semToken };
}

/**
 * notificarEscala
 *
 * Recebe do sistema web (PHP) um POST com:
 *   {
 *     "ids":      ["123456", "789012"],   // matrículas dos militares
 *     "titulo":   "Escala de Serviço",
 *     "mensagem": "Você foi escalado para 05/06/2026.",
 *     "rota":     "/plantao"              // opcional – navega no app
 *   }
 *
 * Busca o fcmToken de cada militar no Firestore e envia via FCM.
 * Suporta 1 ou N militares com o mesmo endpoint.
 */
exports.notificarEscala = onRequest({ invoker: "public", cors: true }, async (req, res) => {
  if (req.method !== "POST") {
    return res.status(405).json({ error: "Método não permitido" });
  }

  const { ids, titulo, mensagem, rota } = req.body;

  if (!ids || !Array.isArray(ids) || ids.length === 0) {
    return res.status(400).json({ error: "Campo 'ids' é obrigatório e deve ser um array." });
  }
  if (!titulo || !mensagem) {
    return res.status(400).json({ error: "Campos 'titulo' e 'mensagem' são obrigatórios." });
  }

  // 0. Aplica a lista de autorizados (whitelist) quando o modo restrito
  //    estiver ligado. Somente matrículas autorizadas recebem a notificação
  //    e têm o histórico gravado.
  const cfg = carregarConfigNotificacoes();
  let idsAlvo = ids.map(String);
  let bloqueados = [];
  if (cfg.restrito) {
    bloqueados = idsAlvo.filter((id) => !cfg.autorizados.has(id));
    idsAlvo = idsAlvo.filter((id) => cfg.autorizados.has(id));
  }

  if (idsAlvo.length === 0) {
    return res.status(200).json({
      enviados: 0,
      falhas: 0,
      semToken: [],
      bloqueados,
      restrito: cfg.restrito,
      mensagem: "Nenhuma matrícula autorizada a receber notificações.",
    });
  }

  const resultado = await enviarParaMatriculas(idsAlvo, {
    titulo,
    mensagem,
    rota,
  });

  return res.status(200).json({
    enviados: resultado.enviados,
    falhas: resultado.falhas,
    semToken: resultado.semToken,
    bloqueados,
    restrito: cfg.restrito,
  });
});

/**
 * notificarTodos
 *
 * Envia uma notificação para TODOS os militares.
 *
 * POST body:
 *   {
 *     "titulo":   "Aviso geral",
 *     "mensagem": "Mensagem para todos.",
 *     "rota":     "/escalas"   // opcional – deep-link ao tocar
 *   }
 *
 * Faz DUAS coisas (para ficar consistente com o app):
 *   1) Grava UM único documento na coleção global "avisos_gerais". O app lê
 *      essa coleção (além da individual) e controla lido/removido por usuário
 *      em militares/{matricula}/avisos_status/{avisoId}.
 *   2) Envia um push para o tópico "todos_militares" → banner do sistema quando
 *      o app está em background/fechado (1 chamada, sem depender de tokens).
 */
exports.notificarTodos = onRequest(
  { invoker: "public", cors: true, secrets: ["NOTIFICAR_TODOS_TOKEN"] },
  async (req, res) => {
  if (req.method !== "POST") {
    return res.status(405).json({ error: "Método não permitido" });
  }

  // Proteção: exige o token secreto no header x-admin-token.
  const tokenEsperado = process.env.NOTIFICAR_TODOS_TOKEN;
  const tokenRecebido = req.get("x-admin-token");
  if (!tokenEsperado || tokenRecebido !== tokenEsperado) {
    return res.status(403).json({ error: "Proibido: token inválido." });
  }

  const { titulo, mensagem, rota } = req.body;
  if (!titulo || !mensagem) {
    return res.status(400).json({ error: "Campos 'titulo' e 'mensagem' são obrigatórios." });
  }

  const db = admin.firestore();

  // 1. Grava um único aviso na coleção global.
  const avisoRef = await db.collection("avisos_gerais").add({
    title: titulo,
    body: mensagem,
    route: rota ?? "",
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
  });

  // 2. Envia UM push para o tópico (banner do sistema em background/fechado).
  let enviadoTopico = false;
  try {
    await admin.messaging().send({
      topic: "todos_militares",
      notification: { title: titulo, body: mensagem },
      data: {
        route: rota ?? "",
        titulo: titulo,
        mensagem: mensagem,
      },
      android: { priority: "high" },
      apns: { payload: { aps: { sound: "default" } } },
    });
    enviadoTopico = true;
  } catch (e) {
    console.error("Falha ao enviar para o tópico todos_militares:", e);
  }

  return res.status(200).json({
    avisoId: avisoRef.id,
    topico: enviadoTopico ? "todos_militares" : "falhou",
  });
});
