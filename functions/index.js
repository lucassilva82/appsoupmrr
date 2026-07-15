const { onRequest } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");

admin.initializeApp();

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

  // 1. Busca todos os tokens em paralelo no Firestore
  const docs = await Promise.all(
    ids.map((id) =>
      admin.firestore().collection("militares").doc(String(id)).get()
    )
  );

  const tokens = [];
  const semToken = [];

  docs.forEach((doc, i) => {
    const token = doc.exists ? doc.data()?.fcmToken : null;
    if (token) {
      tokens.push(token);
    } else {
      semToken.push(ids[i]);
    }
  });

  // 1.1 Persiste a notificação no histórico de CADA militar (fonte de verdade
  //     para a lista interna do app — funciona mesmo com o app fechado).
  const agora = admin.firestore.FieldValue.serverTimestamp();
  await Promise.all(
    ids.map((id) =>
      admin
        .firestore()
        .collection("militares")
        .doc(String(id))
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

  if (tokens.length === 0) {
    return res.status(200).json({
      enviados: 0,
      semToken: semToken,
      mensagem: "Nenhum token encontrado para os IDs informados.",
    });
  }

  // 2. Monta o payload base
  const notificationPayload = {
    notification: {
      title: titulo,
      body: mensagem,
    },
    data: {
      route: rota ?? "",
      titulo: titulo,
      mensagem: mensagem,
    },
    android: {
      priority: "high",
    },
    apns: {
      payload: {
        aps: { sound: "default" },
      },
    },
  };

  // 3. Envia em lotes de até 500 (limite do FCM por chamada)
  const BATCH = 500;
  let totalEnviados = 0;
  let totalFalhas = 0;

  for (let i = 0; i < tokens.length; i += BATCH) {
    const lote = tokens.slice(i, i + BATCH);

    if (lote.length === 1) {
      // Envio individual
      try {
        await admin.messaging().send({ ...notificationPayload, token: lote[0] });
        totalEnviados++;
      } catch (e) {
        totalFalhas++;
      }
    } else {
      // Envio em multicast
      const result = await admin.messaging().sendEachForMulticast({
        ...notificationPayload,
        tokens: lote,
      });
      totalEnviados += result.successCount;
      totalFalhas += result.failureCount;
    }
  }

  return res.status(200).json({
    enviados: totalEnviados,
    falhas: totalFalhas,
    semToken: semToken,
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
