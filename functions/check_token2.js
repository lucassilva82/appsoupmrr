const admin = require('firebase-admin');
admin.initializeApp({ projectId: 'minhapm-5ff71' });
admin.firestore().collection('militares').doc('452955').get().then(doc => {
  if (!doc.exists) { console.log('NAO EXISTE'); process.exit(0); return; }
  const d = doc.data();
  const tok = d.fcmToken;
  console.log('fcmToken:', tok ? tok.substring(0,40)+'...' : 'AUSENTE');
  console.log('campos:', Object.keys(d).join(', '));
  process.exit(0);
}).catch(e => { console.error(e.message); process.exit(1); });
