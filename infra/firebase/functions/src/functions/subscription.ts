/**
 * Subscription Functions
 *
 * 구독/인앱 결제 서버 검증 Cloud Functions
 *
 * @ios ProPlanFeature
 */
import {FieldValue} from "firebase-admin/firestore";
import {HttpsError, onCall, onRequest} from "firebase-functions/v2/https";
import {admin, REGION} from "../config";
import {verifyAppleJWS} from "../utils/appstore";
import {
  VerifyPurchaseRequest,
  VerifyPurchaseResponse,
  SubscriptionStatusData,
  AppleNotificationPayload,
} from "../types/subscription";

/**
 * verifyPurchase — 클라이언트에서 구매 후 JWS 토큰을 전송하여 서버에서 검증
 *
 * 흐름:
 * 1. 인증 확인
 * 2. JWS 토큰 검증 (Apple 인증서 체인 검증)
 * 3. 트랜잭션 페이로드에서 구독 정보 추출
 * 4. Firestore subscriptions/{userId} 문서에 상태 저장
 * 5. 결과 반환
 *
 * @remarks
 * **인증 필수**
 */
export const verifyPurchase = onCall<VerifyPurchaseRequest>(
  {region: REGION},
  async (request): Promise<VerifyPurchaseResponse> => {
    // 1. 인증 확인
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "로그인이 필요합니다");
    }

    const userId = request.auth.uid;
    const data = request.data;

    // 2. 유효성 검사
    if (!data.transactionJWS || !data.productId) {
      throw new HttpsError(
        "invalid-argument",
        "transactionJWS와 productId는 필수입니다"
      );
    }

    console.log("📱 [Subscription] Verify purchase started", {
      userId,
      productId: data.productId,
    });

    try {
      // 3. JWS 토큰 검증
      const payload = await verifyAppleJWS(data.transactionJWS);

      console.log("✅ [Subscription] JWS verified", payload);

      // 4. 트랜잭션 페이로드에서 구독 정보 추출
      const productId = payload.productId as string;
      const originalTransactionId = payload.originalTransactionId as string;
      const purchaseDate = payload.purchaseDate ?
        new Date(payload.purchaseDate as number).toISOString() : null;
      const expiresDate = payload.expiresDate ?
        new Date(payload.expiresDate as number).toISOString() : null;
      const transactionType = payload.type as string;

      // 5. 상품 ID 검증
      if (productId !== data.productId) {
        throw new HttpsError(
          "invalid-argument",
          "상품 ID가 일치하지 않습니다"
        );
      }

      // 6. 구독 상태 결정
      let status: SubscriptionStatusData["status"] = "subscribed";
      let expirationDate: string | null = expiresDate;

      // lifetime 상품 확인 (Non-Consumable 또는 만료일 없음)
      if (transactionType === "Non-Consumable" || !expiresDate) {
        status = "lifetime";
        expirationDate = null;
      } else {
        // 구독 상품: 만료일 확인
        const now = new Date();
        const expiry = new Date(expiresDate);
        status = expiry > now ? "subscribed" : "expired";
      }

      const db = admin.firestore();
      const subscriptionRef = db.collection("subscriptions").doc(userId);

      // 7. Firestore 업데이트 (트랜잭션 사용)
      await db.runTransaction(async (transaction) => {
        const subscriptionData: SubscriptionStatusData = {
          status: status,
          productId: productId,
          originalTransactionId: originalTransactionId,
          expirationDate: expirationDate,
          purchaseDate: purchaseDate,
          updatedAt: FieldValue.serverTimestamp() as
            FirebaseFirestore.Timestamp,
        };

        // subscriptions/{userId} 문서 업데이트
        transaction.set(
          subscriptionRef, subscriptionData, {merge: true},
        );

        console.log(`✅ [Subscription] Updated status: ${status}`);
      });

      // 8. 응답 반환
      const subscriptionStatus: SubscriptionStatusData = {
        status: status,
        productId: productId,
        originalTransactionId: originalTransactionId,
        expirationDate: expirationDate,
        purchaseDate: purchaseDate,
        updatedAt: admin.firestore.Timestamp.now(),
      };

      return {
        success: true,
        subscriptionStatus: subscriptionStatus,
      };
    } catch (error) {
      console.error("❌ [Subscription] Verify purchase error:", error);

      // HttpsError는 그대로 throw
      if (error instanceof HttpsError) {
        throw error;
      }

      throw new HttpsError(
        "internal",
        "구매 검증 중 오류가 발생했습니다"
      );
    }
  }
);

/**
 * appleServerNotification — App Store Server Notifications V2 웹훅
 *
 * Apple이 구독 상태 변경 시 자동으로 호출하는 웹훅:
 * - SUBSCRIBED: 신규 구독
 * - DID_RENEW: 갱신 성공
 * - EXPIRED: 만료
 * - DID_FAIL_TO_RENEW: 갱신 실패
 * - GRACE_PERIOD_EXPIRED: 유예 기간 만료
 * - REVOKE: 환불
 * - REFUND: 환불
 *
 * @remarks
 * onRequest를 사용 (onCall이 아님 — Apple이 직접 HTTP POST)
 */
export const appleServerNotification = onRequest(
  {region: REGION},
  async (req, res) => {
    console.log("📱 [Subscription] Apple Server Notification received");

    try {
      // 1. signedPayload 추출
      const body = req.body as AppleNotificationPayload;
      if (!body.signedPayload) {
        console.error("❌ [Subscription] Missing signedPayload");
        res.status(200).json({success: false, error: "Missing signedPayload"});
        return;
      }

      // 2. signedPayload JWS 검증
      const payload = await verifyAppleJWS(body.signedPayload);
      console.log("✅ [Subscription] Notification payload verified", payload);

      const notificationType = payload.notificationType as string;
      const data = payload.data as Record<string, unknown>;

      // 3. signedTransactionInfo 추출 및 검증
      const signedTransactionInfo = data?.signedTransactionInfo as string;
      if (!signedTransactionInfo) {
        console.error("❌ [Subscription] Missing signedTransactionInfo");
        res.status(200).json({
          success: false, error: "Missing signedTransactionInfo",
        });
        return;
      }

      const transactionPayload = await verifyAppleJWS(signedTransactionInfo);
      console.log(
        "✅ [Subscription] Transaction payload verified",
        transactionPayload
      );

      // 4. 사용자 매핑 (originalTransactionId로 조회)
      const originalTransactionId =
        transactionPayload.originalTransactionId as string;
      const db = admin.firestore();
      const subscriptionsSnapshot = await db.collection("subscriptions")
        .where("originalTransactionId", "==", originalTransactionId)
        .limit(1)
        .get();

      if (subscriptionsSnapshot.empty) {
        console.warn(
          `⚠️ [Subscription] No user found for txId: ${originalTransactionId}`
        );
        res.status(200).json({success: false, error: "User not found"});
        return;
      }

      const userId = subscriptionsSnapshot.docs[0].id;
      console.log(`✅ [Subscription] User found: ${userId}`);

      // 5. notificationType에 따라 상태 업데이트
      let status = "subscribed";
      switch (notificationType) {
      case "SUBSCRIBED":
      case "DID_RENEW":
        status = "subscribed";
        break;
      case "EXPIRED":
      case "GRACE_PERIOD_EXPIRED":
        status = "expired";
        break;
      case "DID_FAIL_TO_RENEW":
        status = "gracePeriod";
        break;
      case "REVOKE":
      case "REFUND":
        status = "revoked";
        break;
      default:
        console.warn(
          `⚠️ [Subscription] Unknown type: ${notificationType}`
        );
        res.status(200).json({
          success: false, error: "Unknown notification type",
        });
        return;
      }

      // 6. Firestore 업데이트
      const productId = transactionPayload.productId as string;
      const purchaseDate = transactionPayload.purchaseDate ?
        new Date(transactionPayload.purchaseDate as number).toISOString() :
        null;
      const expiresDate = transactionPayload.expiresDate ?
        new Date(transactionPayload.expiresDate as number).toISOString() :
        null;

      const subscriptionRef = db.collection("subscriptions").doc(userId);

      await db.runTransaction(async (transaction) => {
        const subscriptionData = {
          status: status as SubscriptionStatusData["status"],
          productId: productId,
          expirationDate: expiresDate,
          purchaseDate: purchaseDate,
          updatedAt: FieldValue.serverTimestamp() as
            FirebaseFirestore.Timestamp,
        };

        transaction.set(
          subscriptionRef, subscriptionData, {merge: true},
        );

        // 구독 해지 시 proSettings 정리
        // (브리핑 알림 등 Pro 전용 설정 비활성화)
        const isInactive = [
          "expired", "revoked",
        ].includes(status);
        if (isInactive) {
          const settingsRef = db
            .collection("users").doc(userId)
            .collection("settings").doc("main");
          transaction.set(settingsRef, {
            proSettings: FieldValue.delete(),
          }, {merge: true});
          console.log(
            `🧹 [Subscription] Cleaned proSettings for ${userId}`
          );
        }

        console.log(`✅ [Subscription] Updated status: ${status}`);
      });

      // 7. 응답 (Apple은 non-200이면 재시도하므로 항상 200 반환)
      res.status(200).json({success: true});
    } catch (error) {
      console.error("❌ [Subscription] Apple notification error:", error);
      // 에러 시에도 200 반환 (Apple 재시도 방지)
      res.status(200).json({success: false, error: String(error)});
    }
  }
);
