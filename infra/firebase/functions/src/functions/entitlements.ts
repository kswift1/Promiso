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

    const subscriptionData = subscriptionDoc.data();
    const rawStatus = subscriptionData?.status;
    const subscriptionStatus =
      typeof rawStatus === "string" ? rawStatus : null;
    const rawProductId = subscriptionData?.productId;
    const productId =
      typeof rawProductId === "string" ? rawProductId : null;
    const rawExpiration = subscriptionData?.expirationDate;
    const expirationDate =
      typeof rawExpiration === "string" ? rawExpiration : null;
    const overrideData = overrideDoc.data() ?? null;

    const subscriptionActive = hasActiveSubscription(subscriptionStatus);
    const overrideActive = isEntitlementOverrideActive(overrideData);
    const hasPro = subscriptionActive || overrideActive;

    let source: "subscription" | "override" | "none" = "none";
    if (subscriptionActive) source = "subscription";
    else if (overrideActive) source = "override";

    const rawOverrideExp = overrideData?.expiresAt;
    const overrideExpiresAt =
      typeof rawOverrideExp === "string" ? rawOverrideExp : null;

    const rawOverrideType = overrideData?.type;
    const overrideType =
      overrideActive && typeof rawOverrideType === "string" ?
        rawOverrideType : null;

    await db.collection("entitlements").doc(uid).set(
      {
        hasPro,
        source,
        subscriptionStatus,
        productId,
        expirationDate,
        overrideActive,
        overrideExpiresAt,
        overrideType,
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
