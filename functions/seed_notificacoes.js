// Seed de notificações de teste.
//
// Cria várias notificações fictícias em:
//   militares/{matricula}/notificacoes/{autoId}
// com os campos usados pelo app: title, body, route, read, timestamp.
//
// USO:
//   cd functions
//   node seed_notificacoes.js <MATRICULA>
//
// Autenticação:
//   1) No Console do Firebase: Configurações do projeto > Contas de serviço >
//      "Gerar nova chave privada".
//   2) Salve o arquivo baixado como:  functions/serviceAccount.json
//   3) Rode o comando acima. O script detecta o arquivo automaticamente.
//
//   (Alternativa: export GOOGLE_APPLICATION_CREDENTIALS=/caminho/chave.json)

const fs = require("fs");
const path = require("path");
const admin = require("firebase-admin");

const keyPath = path.join(__dirname, "serviceAccount.json");
if (fs.existsSync(keyPath)) {
  admin.initializeApp({
    credential: admin.credential.cert(require(keyPath)),
    projectId: "minhapm-5ff71",
  });
} else {
  // Usa GOOGLE_APPLICATION_CREDENTIALS ou credenciais padrão do ambiente.
  admin.initializeApp({ projectId: "minhapm-5ff71" });
}

const db = admin.firestore();
const FieldValue = admin.firestore.FieldValue;

const matricula = process.argv[2];
if (!matricula) {
  console.error("❌ Informe a matrícula: node seed_notificacoes.js <MATRICULA>");
  process.exit(1);
}

// Amostras cobrindo as categorias que a tela reconhece pela rota.
const agora = Date.now();
const min = 60 * 1000;
const hora = 60 * min;
const dia = 24 * hora;

const amostras = [
  {
    title: "Nova vaga de SVI disponível",
    body: "Abriram vagas de Serviço Voluntário Indenizado para o próximo fim de semana. Confira e candidate-se.",
    route: "/svi/escalas",
    read: false,
    offset: 2 * min,
  },
  {
    title: "Escala publicada",
    body: "Sua escala de serviço para 08/07/2026 foi publicada. Verifique guarnição e horário.",
    route: "/escalas",
    read: false,
    offset: 40 * min,
  },
  {
    title: "Contracheque disponível",
    body: "O contracheque de referência 07/2026 já está disponível para consulta.",
    route: "/contracheque",
    read: false,
    offset: 5 * hora,
  },
  {
    title: "Voluntário confirmado",
    body: "Sua adesão ao SVI foi confirmada. Compareça no horário indicado.",
    route: "/svi/meus-voluntarios",
    read: true,
    offset: 1 * dia + 3 * hora,
  },
  {
    title: "Período de férias atualizado",
    body: "Seu período de férias foi ajustado. Toque para ver os detalhes.",
    route: "/ferias",
    read: true,
    offset: 2 * dia,
  },
  {
    title: "Aviso geral do comando",
    body: "Reunião de instrução obrigatória na próxima terça-feira às 09h.",
    route: "",
    read: false,
    offset: 6 * dia,
  },
];

(async () => {
  const col = db
    .collection("militares")
    .doc(String(matricula))
    .collection("notificacoes");

  const batch = db.batch();
  for (const a of amostras) {
    const ref = col.doc();
    batch.set(ref, {
      title: a.title,
      body: a.body,
      route: a.route,
      read: a.read,
      timestamp: admin.firestore.Timestamp.fromMillis(agora - a.offset),
      createdAt: FieldValue.serverTimestamp(),
    });
  }
  await batch.commit();

  console.log(
    `✅ ${amostras.length} notificações criadas em militares/${matricula}/notificacoes`
  );
  process.exit(0);
})().catch((err) => {
  console.error("❌ Erro ao criar notificações:", err);
  process.exit(1);
});
