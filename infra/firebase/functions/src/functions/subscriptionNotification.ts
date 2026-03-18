/**
 * 구독 Slack 알림 트리거
 *
 * subscriptions/{uid} 변경 시 신규 유료 구독이 시작된 경우에만
 * Slack 알림을 전송한다.
 */
import {onDocumentWritten} from "firebase-functions/v2/firestore";
import {admin, REGION, SLACK_WEBHOOK_URL} from "../config";
import {sendSlackSubscriptionNotification} from "../utils/slack";

const ACTIVE_STATUSES = ["subscribed", "lifetime"];

const DEFAULT_PRICES: Record<string, number> = {
  monthly: 3900,
  yearly: 29000,
  lifetime: 39000,
};

/**
 * productId에서 플랜 종류를 추출하여 가격을 반환한다.
 * Firestore admin/proPlanPrices 문서가 있으면 해당 가격을, 없으면 기본값을 사용한다.
 */
async function getPriceForProduct(
  db: FirebaseFirestore.Firestore,
  productId: string,
): Promise<number> {
  let prices = DEFAULT_PRICES;

  const priceDoc = await db.collection("admin").doc("proPlanPrices").get();
  if (priceDoc.exists) {
    const data = priceDoc.data()!;
    prices = {
      monthly: typeof data.monthly === "number" ? data.monthly : DEFAULT_PRICES.monthly,
      yearly: typeof data.yearly === "number" ? data.yearly : DEFAULT_PRICES.yearly,
      lifetime: typeof data.lifetime === "number" ? data.lifetime : DEFAULT_PRICES.lifetime,
    };
  }

  if (productId.includes("monthly")) return prices.monthly;
  if (productId.includes("yearly")) return prices.yearly;
  if (productId.includes("lifetime")) return prices.lifetime;
  return 0;
}

/**
 * subscriptions/{uid} 변경 시 신규 Pro 구독 시작 여부를 감지하여 Slack 알림을 전송한다.
 */
export const onSubscriptionWriteNotifySlack = onDocumentWritten(
  {document: "subscriptions/{uid}", region: REGION, secrets: [SLACK_WEBHOOK_URL]},
  async (event) => {
    const uid = event.params.uid;
    if (!uid) return;

    const beforeData = event.data?.before?.data();
    const afterData = event.data?.after?.data();

    // after가 없거나 status가 활성 상태가 아니면 스킵
    if (!afterData) return;

    const afterStatus: string = typeof afterData.status === "string" ? afterData.status : "";
    const beforeStatus: string =
      typeof beforeData?.status === "string" ? beforeData.status : "";

    const isAfterActive = ACTIVE_STATUSES.includes(afterStatus);
    const isBeforeActive = ACTIVE_STATUSES.includes(beforeStatus);

    // 신규 구독 시작이 아니면 스킵 (이미 활성 상태였거나 비활성으로 변경된 경우)
    if (!isAfterActive || isBeforeActive) return;

    try {
      const db = admin.firestore();

      // 사용자 닉네임 조회
      const userDoc = await db.collection("users").doc(uid).get();
      const nickname: string =
        typeof userDoc.data()?.nickname === "string" ?
          userDoc.data()!.nickname :
          uid;

      // 총 Pro 사용자 수 카운트
      const proCountSnapshot = await db
        .collection("entitlements")
        .where("hasPro", "==", true)
        .count()
        .get();
      const totalProUsers = proCountSnapshot.data().count;

      const productId: string =
        typeof afterData.productId === "string" ? afterData.productId : "";

      const price = await getPriceForProduct(db, productId);

      await sendSlackSubscriptionNotification({
        uid,
        nickname,
        productId,
        status: afterStatus,
        price,
        totalProUsers,
      });
    } catch (error) {
      console.error(`[SubscriptionNotification] uid=${uid} 처리 중 오류:`, error);
    }
  },
);
