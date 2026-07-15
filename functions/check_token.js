const admin = require('firebase-admin');
admin.initializeApp({ projectId: 'soupmrr' });

admin.firestore().collection('militares').doc('452955').get().then(doc => {
  if (!doc.exists) { console.log('Documento nao encontrado'); process.exit(0); }
  const data = doc.data();
  const token = data.fcmToken;
  if (token) {
    console.log('TOKEN ENCONTRADO');
    console.log('Inicio do token:', token.substring(0, 40) + '...');
  } else {
    console.log('SEM TOKEN - campo fcmToken ausente ou vazio');
  }
  console.log('Campos do doc:', Object.keys(data).join(', '));
  process.exit(0);
}).catch(e => { console.error('Erro:', e.message); process.exit(1); });
