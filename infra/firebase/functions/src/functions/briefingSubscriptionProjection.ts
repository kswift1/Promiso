/**
 * Briefing subscription projection functions
 *
 * 브리핑 발송 대상과 다음 dispatch 시각을 별도 projection 컬렉션에 유지한다.
 */
import {FieldValue} from "firebase-admin/firestore";
import {onDocumentWritten} from "firebase-functions/v2/firestore";
import {admin, REGION} from "../config";
import {
  BRIEFING_SUBSCRIPTIONS_COLLECTION,
  buildBriefingSubscriptionProjection,
} from "../utils/briefingScheduler";

/**
 * 사용자의 현재 settings/subscription/override 상태를 projection으로 동기화한다.
 * @param {string} uid 사용자 ID.
 * @return {Promise<void>}
 */
export async function reconcileBriefingSubscription(
  uid: string,
): Promise<void> {
  const db = admin.firestore();
  const projectionRef = db
    .collection(BRIEFING_SUBSCRIPTIONS_COLLECTION)
    .doc(uid);

  const [settingsDoc, subscriptionDoc, overrideDoc] = await Promise.all([
    db.collection("users").doc(uid)
      .collection("settings").doc("main")
      .get(),
    db.collection("subscriptions").doc(uid).get(),
    db.collection("entitlementOverrides").doc(uid).get(),
  ]);

  const projection = buildBriefingSubscriptionProjection({
    settingsData: settingsDoc.data() ?? null,
    subscriptionStatus: subscriptionDoc.data()?.status,
    overrideActive: overrideDoc.exists &&
      overrideDoc.data()?.isActive === true,
    now: new Date(),
  });

  if (!projection) {
    await projectionRef.delete();
    console.log(`🧹 [BriefingProjection] Deleted projection for ${uid}`);
    return;
  }

  await projectionRef.set({
    notificationHour: projection.notificationHour,
    timezone: projection.timezone,
    language: projection.language,
    style: projection.style,
    nextDispatchAt: admin.firestore.Timestamp
      .fromDate(projection.nextDispatchAt),
    updatedAt: FieldValue.serverTimestamp(),
  });

  console.log(
    `✅ [BriefingProjection] Synced projection for ${uid} ` +
    `at ${projection.nextDispatchAt.toISOString()}`
  );
}

/**
 * settings/main 변경 시 브리핑 projection을 재계산한다.
 */
export const onUserSettingsSyncBriefingSubscription = onDocumentWritten(
  {document: "users/{uid}/settings/main", region: REGION},
  async (event) => {
    const uid = event.params.uid;
    if (!uid) return;

    await reconcileBriefingSubscription(uid);
  },
);

/**
 * subscriptions/{uid} 변경 시 브리핑 projection을 재계산한다.
 */
export const onSubscriptionSyncBriefingSubscription = onDocumentWritten(
  {document: "subscriptions/{uid}", region: REGION},
  async (event) => {
    const uid = event.params.uid;
    if (!uid) return;

    await reconcileBriefingSubscription(uid);
  },
);

/**
 * entitlementOverrides/{uid} 변경 시 브리핑 projection을 재계산한다.
 */
export const onEntitlementOverrideSyncBriefingSubscription = onDocumentWritten(
  {document: "entitlementOverrides/{uid}", region: REGION},
  async (event) => {
    const uid = event.params.uid;
    if (!uid) return;

    await reconcileBriefingSubscription(uid);
  },
);
