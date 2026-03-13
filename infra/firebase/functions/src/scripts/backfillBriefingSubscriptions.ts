/**
 * Briefing subscription projection backfill script
 *
 * 사용법:
 *   npm run backfill:briefing-subscriptions
 *   npm run backfill:briefing-subscriptions -- --dry-run
 */
import * as admin from "firebase-admin";
import {FieldValue} from "firebase-admin/firestore";
import {
  BRIEFING_SUBSCRIPTIONS_COLLECTION,
  buildBriefingSubscriptionProjection,
} from "../utils/briefingScheduler";

if (!admin.apps.length) {
  admin.initializeApp();
}

/**
 * 기존 유저 설정을 briefingSubscriptions projection으로 backfill한다.
 * @return {Promise<void>}
 */
async function main(): Promise<void> {
  const dryRun = process.argv.includes("--dry-run");
  const db = admin.firestore();
  const settingsSnap = await db
    .collectionGroup("settings")
    .where("proSettings.briefing.notificationHour", ">=", 0)
    .get();

  let upserts = 0;
  let deletes = 0;
  let skipped = 0;

  for (const doc of settingsSnap.docs) {
    const uid = doc.ref.path.split("/")[1];
    if (!uid) {
      skipped++;
      continue;
    }

    const [subscriptionDoc, overrideDoc] = await Promise.all([
      db.collection("subscriptions").doc(uid).get(),
      db.collection("entitlementOverrides").doc(uid).get(),
    ]);

    try {
      const projection = buildBriefingSubscriptionProjection({
        settingsData: doc.data(),
        subscriptionStatus: subscriptionDoc.data()?.status,
        overrideActive: overrideDoc.exists &&
          overrideDoc.data()?.isActive === true,
        now: new Date(),
      });

      const projectionRef = db
        .collection(BRIEFING_SUBSCRIPTIONS_COLLECTION)
        .doc(uid);
      if (!projection) {
        if (!dryRun) {
          await projectionRef.delete();
        }
        deletes++;
        continue;
      }

      if (!dryRun) {
        await projectionRef.set({
          notificationHour: projection.notificationHour,
          timezone: projection.timezone,
          language: projection.language,
          style: projection.style,
          nextDispatchAt: admin.firestore.Timestamp
            .fromDate(projection.nextDispatchAt),
          updatedAt: FieldValue.serverTimestamp(),
        });
      }

      upserts++;
    } catch (error) {
      skipped++;
      console.error(
        `[BackfillBriefingSubscriptions] Failed to backfill ${uid}`,
        error,
      );
    }
  }

  console.log("[BackfillBriefingSubscriptions] Completed", {
    scanned: settingsSnap.size,
    upserts,
    deletes,
    skipped,
    dryRun,
  });
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("[BackfillBriefingSubscriptions] Failed", error);
    process.exit(1);
  });
