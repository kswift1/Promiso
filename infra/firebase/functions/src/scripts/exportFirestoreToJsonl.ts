/**
 * Firestore → JSONL export script
 *
 * 사용법:
 *   npx ts-node src/scripts/exportFirestoreToJsonl.ts \
 *     --project <firebase-project-id> --output <directory>
 *
 * 예시:
 *   npx ts-node src/scripts/exportFirestoreToJsonl.ts \
 *     --project promiso-dev --output ./export/
 *
 * 출력:
 *   - <output>/<collection>.jsonl  (컬렉션별 JSONL 파일)
 *   - <output>/manifest.json        (문서 수 요약)
 *
 * 제외 컬렉션:
 *   - liveActivities          (ephemeral)
 *   - admin/config/coupons    (deprecated)
 *   - admin/config/pushJobs   (deprecated)
 *   - users/{uid}/cache       (deprecated)
 *   - entitlements/{uid}      (PG에서 재계산)
 */

import * as admin from "firebase-admin";
import * as fs from "fs";
import * as path from "path";

// ---------------------------------------------------------------------------
// CLI argument parsing
// ---------------------------------------------------------------------------

/**
 * Parses --project and --output from process.argv.
 * Exits with code 1 if either argument is missing.
 * @return {{project: string, output: string}}
 */
function parseArgs(): {project: string; output: string} {
  const args = process.argv.slice(2);
  let project = "";
  let output = "";

  for (let i = 0; i < args.length; i++) {
    if (args[i] === "--project" && args[i + 1]) {
      project = args[++i];
    } else if (args[i] === "--output" && args[i + 1]) {
      output = args[++i];
    }
  }

  if (!project) {
    console.error("Error: --project <firebase-project-id> is required");
    process.exit(1);
  }
  if (!output) {
    console.error("Error: --output <directory> is required");
    process.exit(1);
  }

  return {project, output};
}

// ---------------------------------------------------------------------------
// Firebase Admin initialization
// ---------------------------------------------------------------------------

/**
 * Initializes the Firebase Admin SDK with the given project ID.
 * No-ops if the app is already initialized.
 * @param {string} projectId Firebase project ID.
 */
function initFirebase(projectId: string): void {
  if (!admin.apps.length) {
    admin.initializeApp({projectId});
  }
}

// ---------------------------------------------------------------------------
// Timestamp conversion
// ---------------------------------------------------------------------------

/**
 * Recursively converts Firestore Timestamps to ISO 8601 strings.
 * @param {unknown} obj Any Firestore document field value.
 * @return {unknown} The same structure with Timestamps replaced by strings.
 */
function convertTimestamps(obj: unknown): unknown {
  if (obj === null || obj === undefined) return obj;
  if (obj instanceof admin.firestore.Timestamp) {
    return obj.toDate().toISOString();
  }
  if (Array.isArray(obj)) {
    return obj.map(convertTimestamps);
  }
  if (typeof obj === "object") {
    const result: Record<string, unknown> = {};
    const map = obj as Record<string, unknown>;
    for (const [key, value] of Object.entries(map)) {
      result[key] = convertTimestamps(value);
    }
    return result;
  }
  return obj;
}

// ---------------------------------------------------------------------------
// JSONL writer helper
// ---------------------------------------------------------------------------

/**
 * Appends a single JSON record as one line to a JSONL file.
 * @param {string} filePath Absolute path to the output file.
 * @param {Record<string, unknown>} record Document data to write.
 */
function appendJsonl(
  filePath: string,
  record: Record<string, unknown>
): void {
  fs.appendFileSync(filePath, JSON.stringify(record) + "\n", "utf8");
}

// ---------------------------------------------------------------------------
// Collection definitions
// ---------------------------------------------------------------------------

interface TopLevelCollection {
  kind: "top-level";
  name: string;
  path: string;
  output: string;
}

interface UserSubcollectionDocs {
  kind: "user-subcollection-docs";
  name: string;
  subcollection: string;
  doc: string;
  output: string;
}

interface UserSubcollection {
  kind: "user-subcollection";
  name: string;
  subcollection: string;
  output: string;
}

interface AdminSubcollection {
  kind: "admin-subcollection";
  name: string;
  path: string;
  output: string;
}

type CollectionDef =
  | TopLevelCollection
  | UserSubcollectionDocs
  | UserSubcollection
  | AdminSubcollection;

const COLLECTIONS: CollectionDef[] = [
  // Top-level collections
  {
    kind: "top-level",
    name: "users",
    path: "users",
    output: "users.jsonl",
  },
  {
    kind: "top-level",
    name: "groups",
    path: "groups",
    output: "groups.jsonl",
  },
  {
    kind: "top-level",
    name: "promises",
    path: "promises",
    output: "promises.jsonl",
  },
  {
    kind: "top-level",
    name: "notifications",
    path: "notifications",
    output: "notifications.jsonl",
  },
  {
    kind: "top-level",
    name: "subscriptions",
    path: "subscriptions",
    output: "subscriptions.jsonl",
  },
  {
    kind: "top-level",
    name: "subscriptionOwners",
    path: "subscriptionOwners",
    output: "subscription_owners.jsonl",
  },
  {
    kind: "top-level",
    name: "entitlementOverrides",
    path: "entitlementOverrides",
    output: "entitlement_overrides.jsonl",
  },
  {
    kind: "top-level",
    name: "briefingSubscriptions",
    path: "briefingSubscriptions",
    output: "briefing_subscriptions.jsonl",
  },

  // User subcollections — single fixed document (auth/main, settings/main)
  {
    kind: "user-subcollection-docs",
    name: "auth_accounts",
    subcollection: "auth",
    doc: "main",
    output: "auth_accounts.jsonl",
  },
  {
    kind: "user-subcollection-docs",
    name: "user_settings",
    subcollection: "settings",
    doc: "main",
    output: "user_settings.jsonl",
  },

  // User subcollections — all documents in subcollection
  {
    kind: "user-subcollection",
    name: "personalEvents",
    subcollection: "personalEvents",
    output: "personal_events.jsonl",
  },
  {
    kind: "user-subcollection",
    name: "recurringEvents",
    subcollection: "recurringEvents",
    output: "recurring_events.jsonl",
  },

  // Admin subcollections
  {
    kind: "admin-subcollection",
    name: "adminUsers",
    path: "admin/config/users",
    output: "admin_users.jsonl",
  },
  {
    kind: "admin-subcollection",
    name: "adminAuditLogs",
    path: "admin/config/auditLogs",
    output: "admin_audit_logs.jsonl",
  },
];

// ---------------------------------------------------------------------------
// Export functions
// ---------------------------------------------------------------------------

/**
 * Exports all documents from a top-level Firestore collection to JSONL.
 * Each line contains the document data plus an `_id` field.
 * @param {admin.firestore.Firestore} db Firestore instance.
 * @param {TopLevelCollection} def Collection definition.
 * @param {string} filePath Output JSONL file path.
 * @return {Promise<number>} Number of documents exported.
 */
async function exportTopLevel(
  db: admin.firestore.Firestore,
  def: TopLevelCollection,
  filePath: string
): Promise<number> {
  console.log(`Exporting ${def.name}...`);
  const snapshot = await db.collection(def.path).get();
  let count = 0;
  for (const doc of snapshot.docs) {
    const data = convertTimestamps(doc.data()) as Record<string, unknown>;
    appendJsonl(filePath, {_id: doc.id, ...data});
    count++;
  }
  console.log(`  -> ${count} docs`);
  return count;
}

/**
 * Exports a single fixed-ID document from each user's subcollection.
 * Each line contains `_id`, `_userId`, and the document fields.
 * Documents that don't exist are silently skipped.
 * @param {admin.firestore.Firestore} db Firestore instance.
 * @param {UserSubcollectionDocs} def Subcollection definition.
 * @param {string} filePath Output JSONL file path.
 * @param {string[]} userIds All user document IDs.
 * @return {Promise<number>} Number of documents exported.
 */
async function exportUserSubcollectionDocs(
  db: admin.firestore.Firestore,
  def: UserSubcollectionDocs,
  filePath: string,
  userIds: string[]
): Promise<number> {
  console.log(
    `Exporting ${def.name} ` +
    `(users/${def.subcollection}/${def.doc})...`
  );
  let count = 0;
  for (const userId of userIds) {
    const docRef = db
      .collection("users")
      .doc(userId)
      .collection(def.subcollection)
      .doc(def.doc);
    const snap = await docRef.get();
    if (!snap.exists) continue;
    const data = convertTimestamps(snap.data()) as Record<string, unknown>;
    appendJsonl(filePath, {_id: snap.id, _userId: userId, ...data});
    count++;
  }
  console.log(`  -> ${count} docs`);
  return count;
}

/**
 * Exports all documents from each user's named subcollection.
 * Each line contains `_id`, `_userId`, and the document fields.
 * @param {admin.firestore.Firestore} db Firestore instance.
 * @param {UserSubcollection} def Subcollection definition.
 * @param {string} filePath Output JSONL file path.
 * @param {string[]} userIds All user document IDs.
 * @return {Promise<number>} Number of documents exported.
 */
async function exportUserSubcollection(
  db: admin.firestore.Firestore,
  def: UserSubcollection,
  filePath: string,
  userIds: string[]
): Promise<number> {
  console.log(`Exporting ${def.name} (users/${def.subcollection}/*)...`);
  let count = 0;
  for (const userId of userIds) {
    const colRef = db
      .collection("users")
      .doc(userId)
      .collection(def.subcollection);
    const snapshot = await colRef.get();
    for (const doc of snapshot.docs) {
      const data = convertTimestamps(doc.data()) as Record<string, unknown>;
      appendJsonl(filePath, {_id: doc.id, _userId: userId, ...data});
      count++;
    }
  }
  console.log(`  -> ${count} docs`);
  return count;
}

/**
 * Builds a Firestore CollectionReference from a slash-separated path like
 * "admin/config/users" (collection/doc/collection).
 * @param {admin.firestore.Firestore} db Firestore instance.
 * @param {string} collectionPath Slash-separated path.
 * @return {admin.firestore.CollectionReference} The resolved reference.
 */
function collectionRefFromPath(
  db: admin.firestore.Firestore,
  collectionPath: string
): admin.firestore.CollectionReference {
  const segments = collectionPath.split("/");
  // segments[0] is always a collection name
  let colRef: admin.firestore.CollectionReference =
    db.collection(segments[0]);
  // Remaining segments alternate: doc, collection, doc, collection …
  for (let i = 1; i < segments.length - 1; i += 2) {
    colRef = colRef.doc(segments[i]).collection(segments[i + 1]);
  }
  return colRef;
}

/**
 * Exports all documents from a deeply-nested admin subcollection.
 * Each line contains `_id` and the document fields.
 * @param {admin.firestore.Firestore} db Firestore instance.
 * @param {AdminSubcollection} def Subcollection definition.
 * @param {string} filePath Output JSONL file path.
 * @return {Promise<number>} Number of documents exported.
 */
async function exportAdminSubcollection(
  db: admin.firestore.Firestore,
  def: AdminSubcollection,
  filePath: string
): Promise<number> {
  console.log(`Exporting ${def.name} (${def.path})...`);
  const ref = collectionRefFromPath(db, def.path);
  const snapshot = await ref.get();
  let count = 0;
  for (const doc of snapshot.docs) {
    const data = convertTimestamps(doc.data()) as Record<string, unknown>;
    appendJsonl(filePath, {_id: doc.id, ...data});
    count++;
  }
  console.log(`  -> ${count} docs`);
  return count;
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

/**
 * Entry point: reads CLI args, exports all collections, writes manifest.json.
 * @return {Promise<void>}
 */
async function main(): Promise<void> {
  const {project, output} = parseArgs();

  initFirebase(project);
  const db = admin.firestore();

  // Ensure output directory exists
  if (!fs.existsSync(output)) {
    fs.mkdirSync(output, {recursive: true});
    console.log(`Created output directory: ${output}`);
  }

  // Fetch all user IDs once — needed for subcollection exports
  console.log("Fetching all user IDs...");
  const usersSnapshot = await db.collection("users").get();
  const userIds = usersSnapshot.docs.map((d) => d.id);
  console.log(`  -> ${userIds.length} users found`);

  const manifest: Record<string, number> = {};

  for (const def of COLLECTIONS) {
    const filePath = path.join(output, def.output);

    // Remove existing file so we start fresh on re-runs
    if (fs.existsSync(filePath)) {
      fs.unlinkSync(filePath);
    }

    let count = 0;

    switch (def.kind) {
    case "top-level":
      count = await exportTopLevel(db, def, filePath);
      break;
    case "user-subcollection-docs":
      count = await exportUserSubcollectionDocs(db, def, filePath, userIds);
      break;
    case "user-subcollection":
      count = await exportUserSubcollection(db, def, filePath, userIds);
      break;
    case "admin-subcollection":
      count = await exportAdminSubcollection(db, def, filePath);
      break;
    }

    manifest[def.name] = count;
  }

  // Write manifest
  const manifestPath = path.join(output, "manifest.json");
  const manifestData = {
    exportedAt: new Date().toISOString(),
    project,
    collections: manifest,
  };
  fs.writeFileSync(
    manifestPath,
    JSON.stringify(manifestData, null, 2),
    "utf8"
  );

  const totalDocs = Object.values(manifest).reduce((a, b) => a + b, 0);
  console.log(
    "\nExport complete. " +
    `Total: ${totalDocs} docs across ${COLLECTIONS.length} collections.`
  );
  console.log(`Manifest written to ${manifestPath}`);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("[ExportFirestoreToJsonl] Failed", error);
    process.exit(1);
  });
