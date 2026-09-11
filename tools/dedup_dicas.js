/**
 * Remove dicas duplicadas da coleção `dicas_app`.
 *
 * A duplicação veio de um seed automático que rodava no cliente: a checagem
 * "coleção está vazia?" seguida da escrita não é atômica, então vários
 * aparelhos abrindo ao mesmo tempo semeavam em paralelo. E como o batch
 * usava `_col.doc()` sem ID, cada rodada criava documentos novos em vez de
 * sobrescrever. O seed já foi removido do app; este script limpa o passivo.
 *
 * Uso:
 *   node tools/dedup_dicas.js            → apenas relata (não apaga nada)
 *   node tools/dedup_dicas.js --apply    → apaga as duplicatas
 */
const admin = require('firebase-admin');

const CRED = process.env.GOOGLE_APPLICATION_CREDENTIALS
  || `${process.env.HOME}/Documents/minhapm-5ff71-firebase-adminsdk-4b3xx-c0135fc157.json`;
const APLICAR = process.argv.includes('--apply');

admin.initializeApp({ credential: admin.credential.cert(require(CRED)) });
const db = admin.firestore();

(async () => {
  const snap = await db.collection('dicas_app').get();
  console.log(`Documentos na coleção: ${snap.size}`);

  // A identidade de uma dica é o texto: mesmo texto = mesma dica.
  const grupos = new Map();
  snap.forEach((d) => {
    const chave = (d.data().texto || '').trim();
    if (!grupos.has(chave)) grupos.set(chave, []);
    grupos.get(chave).push(d);
  });

  const apagar = [];
  for (const [texto, docs] of grupos) {
    if (docs.length <= 1) continue;
    // Mantém o primeiro por ID (estável entre execuções) e marca o resto.
    docs.sort((a, b) => a.id.localeCompare(b.id));
    apagar.push(...docs.slice(1));
    console.log(`  ${docs.length}× "${texto.slice(0, 58)}…"  → remover ${docs.length - 1}`);
  }

  console.log(`\nDicas distintas: ${grupos.size}`);
  console.log(`Documentos a remover: ${apagar.length}`);

  if (!apagar.length) return console.log('Nada a fazer.');
  if (!APLICAR) return console.log('\nSimulação. Rode com --apply para apagar.');

  // Batches de 500 é o teto do Firestore.
  for (let i = 0; i < apagar.length; i += 500) {
    const b = db.batch();
    apagar.slice(i, i + 500).forEach((d) => b.delete(d.ref));
    await b.commit();
    console.log(`  removidos ${Math.min(i + 500, apagar.length)}/${apagar.length}`);
  }
  console.log('Concluído.');
})().catch((e) => { console.error('ERRO:', e.message); process.exit(1); });
