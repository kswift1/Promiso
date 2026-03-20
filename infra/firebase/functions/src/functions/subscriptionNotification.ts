/**
 * 구독 Slack 알림 트리거
 *
 * subscriptions/{uid} 변경 시 구독 상태 전환에 따라
 * 적절한 Slack 알림을 전송한다.
 */
import {onDocumentWritten} from "firebase-functions/v2/firestore";
import {admin, REGION, SLACK_WEBHOOK_URL} from "../config";
import {
  sendSlackSubscriptionNotification,
  sendSlackSubscriptionCancelNotification,
  sendSlackSubscriptionExpiredNotification,
  sendSlackSubscriptionGracePeriodNotification,
  sendSlackSubscriptionPromoNotification,
  sendSlackSubscriptionRecoveredNotification,
} from "../utils/slack";

const ACTIVE_STATUSES = ["subscribed", "lifetime"];
const GRACE_PERIOD_STATUS = "gracePeriod";

const DEFAULT_PRICES: Record<string, number> = {
  monthly: 3900,
  yearly: 29000,
  lifetime: 39000,
};

/**
 * productId에서 플랜 종류를 추출하여 가격을 반환한다.
 *
 * @param {FirebaseFirestore.Firestore} db Firestore 인스턴스
 * @param {string} productId 상품 ID
 * @return {Promise<number>} 가격
 */
async function getPriceForProduct(
  db: FirebaseFirestore.Firestore,
  productId: string,
): Promise<number> {
  let prices = DEFAULT_PRICES;

  const priceDoc = await db
    .collection("admin").doc("proPlanPrices").get();
  if (priceDoc.exists) {
    const data = priceDoc.data()!;
    const m = data.monthly;
    const y = data.yearly;
    const l = data.lifetime;
    prices = {
      monthly: typeof m === "number" ? m : DEFAULT_PRICES.monthly,
      yearly: typeof y === "number" ? y : DEFAULT_PRICES.yearly,
      lifetime: typeof l === "number" ? l : DEFAULT_PRICES.lifetime,
    };
  }

  if (productId.includes("monthly")) return prices.monthly;
  if (productId.includes("yearly")) return prices.yearly;
  if (productId.includes("lifetime")) return prices.lifetime;
  return 0;
}

/**
 * Pro 사용자 수를 조회하는 내부 헬퍼
 *
 * @param {FirebaseFirestore.Firestore} db Firestore 인스턴스
 * @return {Promise<number>} 현재 Pro 사용자 수
 */
async function getTotalProUsers(
  db: FirebaseFirestore.Firestore,
): Promise<number> {
  const proSnap = await db
    .collection("entitlements")
    .where("hasPro", "==", true)
    .count()
    .get();
  return proSnap.data().count;
}

/**
 * subscriptions/{uid} 변경 시 구독 상태 전환을 감지하여
 * 적절한 Slack 알림을 전송한다.
 *
 * - 비활성 → 활성: 신규 구독 (가격 0원이면 프로모션 코드)
 * - 활성 → revoked: 구독 취소/환불
 * - 활성/gracePeriod → expired: 구독 만료
 * - subscribed → gracePeriod: 갱신 실패 (유예 기간 진입)
 */
export const onSubscriptionWriteNotifySlack = onDocumentWritten(
  {
    document: "subscriptions/{uid}",
    region: REGION,
    secrets: [SLACK_WEBHOOK_URL],
  },
  async (event) => {
    const uid = event.params.uid;
    if (!uid) return;

    const beforeData = event.data?.before?.data();
    const afterData = event.data?.after?.data();

    if (!afterData) return;

    const afterStatus: string =
      typeof afterData.status === "string" ?
        afterData.status : "";
    const beforeStatus: string =
      typeof beforeData?.status === "string" ?
        beforeData.status : "";

    const isAfterActive = ACTIVE_STATUSES.includes(afterStatus);
    const isBeforeActive = ACTIVE_STATUSES.includes(beforeStatus);
    const isBeforeGracePeriod = beforeStatus === GRACE_PERIOD_STATUS;

    // 상태 변화가 없으면 스킵
    if (afterStatus === beforeStatus) return;

    const productId: string =
      typeof afterData.productId === "string" ?
        afterData.productId :
        (typeof beforeData?.productId === "string" ? beforeData.productId : "");

    try {
      const db = admin.firestore();

      const userDoc = await db
        .collection("users").doc(uid).get();
      const userData = userDoc.data();
      const nickname: string =
        typeof userData?.nickname === "string" ?
          userData.nickname : uid;

      // 케이스 5: 갱신 복구 (gracePeriod → 활성)
      if (isAfterActive && isBeforeGracePeriod) {
        await sendSlackSubscriptionRecoveredNotification({
          uid,
          nickname,
          productId,
        });
        return;
      }

      // 케이스 1: 신규 구독 시작 (비활성 → 활성)
      if (isAfterActive && !isBeforeActive) {
        const totalProUsers = await getTotalProUsers(db);

        const price = await getPriceForProduct(db, productId);

        // lastNotificationType이 OFFER_REDEEMED이면 프로모션 코드 등록
        const lastNotification =
          typeof afterData.lastNotificationType === "string" ?
            afterData.lastNotificationType : "";
        const isPromo = lastNotification === "OFFER_REDEEMED";

        if (isPromo) {
          const expirationDate =
            typeof afterData.expirationDate === "string" ?
              afterData.expirationDate : null;

          await sendSlackSubscriptionPromoNotification({
            uid,
            nickname,
            productId,
            expirationDate,
            totalProUsers,
          });
        } else {
          await sendSlackSubscriptionNotification({
            uid,
            nickname,
            productId,
            status: afterStatus,
            price,
            totalProUsers,
          });
        }
        return;
      }

      // 케이스 2: 구독 취소/환불 (활성 → revoked)
      if (afterStatus === "revoked" && isBeforeActive) {
        const totalProUsers = await getTotalProUsers(db);

        await sendSlackSubscriptionCancelNotification({
          uid,
          nickname,
          productId,
          totalProUsers,
        });
        return;
      }

      // 케이스 3: 구독 만료 (활성/gracePeriod → expired)
      const isExpiredTransition =
        afterStatus === "expired" &&
        (isBeforeActive || isBeforeGracePeriod);
      if (isExpiredTransition) {
        const totalProUsers = await getTotalProUsers(db);

        await sendSlackSubscriptionExpiredNotification({
          uid,
          nickname,
          productId,
          totalProUsers,
        });
        return;
      }

      // 케이스 4: 갱신 실패 (subscribed → gracePeriod)
      const isGracePeriodTransition =
        afterStatus === GRACE_PERIOD_STATUS &&
        beforeStatus === "subscribed";
      if (isGracePeriodTransition) {
        const expirationDate =
          typeof afterData.expirationDate === "string" ?
            afterData.expirationDate : null;

        await sendSlackSubscriptionGracePeriodNotification({
          uid,
          nickname,
          productId,
          expirationDate,
        });
        return;
      }
    } catch (error) {
      console.error(
        `[SubscriptionNotification] uid=${uid}`,
        error,
      );
    }
  },
);
