// tools/create_admin.js
// Usage: node create_admin.js admin@domain.com 'Password123'

const admin = require('firebase-admin');

async function main() {
  const [,, email, password] = process.argv;
  if (!email || !password) {
    console.error('Usage: node create_admin.js <email> <password>');
    process.exit(1);
  }

  try {
    admin.initializeApp({ credential: admin.credential.applicationDefault() });
    const auth = admin.auth();
    const db = admin.firestore();

    // Check if user exists
    let userRecord;
    try {
      userRecord = await auth.getUserByEmail(email);
      console.log('User already exists:', userRecord.uid);
    } catch (e) {
      console.log('Creating user', email);
      userRecord = await auth.createUser({ email, password });
      console.log('Created user:', userRecord.uid);
    }

    const uid = userRecord.uid;

    // Create users mapping doc
    await db.collection('users').doc(uid).set({
      email,
      role: 'admin',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });

    console.log('Wrote users doc for', uid);
    process.exit(0);
  } catch (err) {
    console.error('Error:', err);
    process.exit(1);
  }
}

main();
