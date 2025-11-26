// tools/migrate_status.js
// One-off migration: normalize 'status' fields in 'drivers' and 'staff' collections
// Usage: node migrate_status.js

const admin = require('firebase-admin');

function canonicalize(src) {
  if (!src) return null;
  const s = String(src).trim().toLowerCase();
  if (s === 'active' || s === 'available') return 'online';
  if (s === 'online') return 'online';
  if (s === 'on the way' || s === 'on_the_way' || s === 'ontheway' || s === 'on_delivery' || s === 'on_delivery') return 'on_delivery';
  if (s.includes('deliver') && s.includes('on')) return 'on_delivery';
  if (s === 'on break' || s === 'break') return 'break';
  if (s === 'end of shift' || s === 'endofshift' || s === 'offline' || s === 'off') return 'offline';
  // fallback: return original lowercased value
  return s;
}

async function migrateCollection(db, colName) {
  console.log(`Scanning collection: ${colName}`);
  const snapshot = await db.collection(colName).get();
  if (snapshot.empty) {
    console.log(`No documents in ${colName}`);
    return {updated:0, total:0};
  }

  let batch = db.batch();
  let ops = 0;
  let updated = 0;
  for (const doc of snapshot.docs) {
    ops++;
    const data = doc.data();
    const old = data.status;
    const canon = canonicalize(old);
    if (canon && canon !== String(old).toLowerCase()) {
      batch.set(db.collection(colName).doc(doc.id), {status: canon}, {merge: true});
      updated++;
    }

    if (ops >= 450) {
      await batch.commit();
      batch = db.batch();
      ops = 0;
    }
  }

  if (ops > 0) await batch.commit();
  return {updated, total: snapshot.size};
}

async function main() {
  try {
    admin.initializeApp({ credential: admin.credential.applicationDefault() });
    const db = admin.firestore();

    const collections = ['drivers', 'staff'];
    for (const c of collections) {
      const res = await migrateCollection(db, c);
      console.log(`Collection ${c}: scanned ${res.total}, updated ${res.updated}`);
    }

    console.log('Migration finished. Review and verify in Firebase Console.');
    process.exit(0);
  } catch (err) {
    console.error('Migration failed:', err);
    process.exit(1);
  }
}

main();
