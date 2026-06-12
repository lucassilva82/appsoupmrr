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
