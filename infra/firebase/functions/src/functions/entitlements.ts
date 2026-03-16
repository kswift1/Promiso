/**
 * Entitlement read model sync functions
 *
 * subscriptions/{uid}와 entitlementOverrides/{uid} 변경 시
 * entitlements/{uid} read model을 최신 상태로 동기화한다.
 */
import {FieldValue} from "firebase-admin/firestore";
import {onDocumentWritten} from "firebase-functions/v2/firestore";
import {admin, REGION} from "../config";
import {hasActiveSubscription} from "../utils/briefingScheduler";
import {isEntitlementOverrideActive} from "../utils/helpers";

/**
 * 사용자의 subscription과 override 상태를 entitlements read model로 동기화한다.
 * @param {string} uid 사용자 ID.
 * @return {Promise<void>}
 */
export async function reconcileEntitlement(uid: string): Promise<void> {
  try {
    const db = admin.firestore();

    const [subscriptionDoc, overrideDoc] = await Promise.all([
      db.collection("subscriptions").doc(uid).get(),
      db.collection("entitlementOverrides").doc(uid).get(),
    ]);

    const subscriptionStatus =
      typeof subscriptionDoc.data()?.status === "string"
        ? (subscriptionDoc.data()?.status as string)
        : null;
    const overrideData = overrideDoc.data() ?? null;

    const subscriptionActive = hasActiveSubscription(subscriptionStatus);
    const overrideActive = isEntitlementOverrideActive(overrideData);
    const hasPro = subscriptionActive || overrideActive;

    const source: "subscription" | "override" | "none" = subscriptionActive
      ? "subscription"
      : overrideActive
        ? "override"
        : "none";

    const overrideExpiresAt =
      typeof overrideData?.expiresAt === "string" ? overrideData.expiresAt : null;

    await db.collection("entitlements").doc(uid).set(
      {
        hasPro,
        source,
        subscriptionStatus,
        overrideActive,
        overrideExpiresAt,
        updatedAt: FieldValue.serverTimestamp(),
      },
      {merge: true},
    );

    console.log(
      `[Entitlements] Synced entitlement for ${uid}: ` +
      `hasPro=${hasPro}, source=${source}`,
    );
  } catch (error) {
    console.error(
      `[Entitlements] Failed to reconcile entitlement for ${uid}`,
      error,
    );
  }
}

/**
 * subscriptions/{uid} 변경 시 entitlements read model을 재계산한다.
 */
export const onSubscriptionWriteSyncEntitlement = onDocumentWritten(
  {document: "subscriptions/{uid}", region: REGION},
  async (event) => {
    const uid = event.params.uid;
    if (!uid) return;

    await reconcileEntitlement(uid);
  },
);

/**
 * entitlementOverrides/{uid} 변경 시 entitlements read model을 재계산한다.
 */
export const onEntitlementOverrideWriteSyncEntitlement = onDocumentWritten(
  {document: "entitlementOverrides/{uid}", region: REGION},
  async (event) => {
    const uid = event.params.uid;
    if (!uid) return;

    await reconcileEntitlement(uid);
  },
);
