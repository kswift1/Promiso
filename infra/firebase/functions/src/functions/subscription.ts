/**
 * Subscription Functions
 *
 * 구독/인앱 결제 서버 검증 Cloud Functions
 *
 * @ios ProPlanFeature
 */
import {
  JWSRenewalInfoDecodedPayload,
  JWSTransactionDecodedPayload,
  NotificationTypeV2,
} from "@apple/app-store-server-library";
import {FieldValue} from "firebase-admin/firestore";
import {HttpsError, onCall, onRequest} from "firebase-functions/v2/https";
import {admin, REGION} from "../config";
import {
  VerifyPurchaseRequest,
  VerifyPurchaseResponse,
  SubscriptionStatusData,
  AppleNotificationPayload,
} from "../types/subscription";
import {
  verifyAppleNotificationPayload,
  verifyAppleRenewalInfoJWS,
  verifyAppleTransactionJWS,
} from "../utils/appstore";

type SubscriptionStatus = SubscriptionStatusData["status"];

type StoredSubscriptionData = Partial<SubscriptionStatusData> & {
  updatedAt?: FirebaseFirestore.Timestamp;
};

const NO_OP_NOTIFICATION_TYPES = new Set<string>([
  NotificationTypeV2.TEST,
  NotificationTypeV2.CONSUMPTION_REQUEST,
  NotificationTypeV2.EXTERNAL_PURCHASE_TOKEN,
  NotificationTypeV2.ONE_TIME_CHARGE,
  NotificationTypeV2.RESCIND_CONSENT,
  NotificationTypeV2.REFUND_DECLINED,
]);

/**
 * Apple 재시도가 필요한 웹훅 실패를 나타낸다.
 */
class RetryableNotificationError extends Error {}

/**
 * Apple millisecond timestamp를 ISO 8601 문자열로 변환한다.
 *
 * @param {number | null | undefined} timestamp Apple timestamp
 * @return {string | null} ISO 8601 문자열 또는 null
 */
function toISOStringOrNull(timestamp?: number | null): string | null {
  if (typeof timestamp !== "number") {
    return null;
  }

  return new Date(timestamp).toISOString();
}

/**
 * 여러 signedDate 중 가장 최신 값을 반환한다.
 *
 * @param {...Array<number | undefined>} dates signedDate 후보 목록
 * @return {number | null} 가장 최신 signedDate
 */
function latestSignedDate(
  ...dates: Array<number | undefined>
): number | null {
  const validDates = dates.filter(
    (value): value is number => typeof value === "number",
  );

  return validDates.length > 0 ? Math.max(...validDates) : null;
}

/**
 * 저장된 구독 문서에서 replay 방지 기준 signedDate를 읽는다.
 *
 * @param {StoredSubscriptionData | undefined} data 저장된 구독 데이터
 * @return {number | null} 저장된 최신 signedDate
 */
function existingLatestSignedDate(
  data?: StoredSubscriptionData,
): number | null {
  return typeof data?.latestAppStoreSignedDate === "number" ?
    data.latestAppStoreSignedDate :
    null;
}

/**
 * Firestore 문서를 클라이언트 응답 형태로 정규화한다.
 *
 * @param {StoredSubscriptionData} data Firestore 문서 데이터
 * @return {SubscriptionStatusData} 응답용 상태 데이터
 */
function buildResponseStatus(
  data: StoredSubscriptionData,
): SubscriptionStatusData {
  return {
    status: (data.status as SubscriptionStatus) ?? "none",
    productId: data.productId ?? null,
    originalTransactionId: data.originalTransactionId ?? null,
    expirationDate: data.expirationDate ?? null,
    purchaseDate: data.purchaseDate ?? null,
    latestAppStoreSignedDate: data.latestAppStoreSignedDate ?? null,
    latestTransactionId: data.latestTransactionId ?? null,
    lastNotificationType: data.lastNotificationType ?? null,
    updatedAt: data.updatedAt ?? admin.firestore.Timestamp.now(),
  };
}

/**
 * signed transaction 하나만 기준으로 현재 상태를 계산한다.
 *
 * @param {JWSTransactionDecodedPayload} transactionPayload 검증된 transaction
 * @return {Pick<SubscriptionStatusData,
 *   "status" | "expirationDate" | "purchaseDate">} 계산된 상태
 */
function deriveStatusFromTransaction(
  transactionPayload: JWSTransactionDecodedPayload,
): Pick<
  SubscriptionStatusData,
  "status" | "expirationDate" | "purchaseDate"
> {
  const purchaseDate = toISOStringOrNull(transactionPayload.purchaseDate);
  const expirationDate = toISOStringOrNull(transactionPayload.expiresDate);
  const transactionType = transactionPayload.type as string | undefined;

  if (
    typeof transactionPayload.revocationDate === "number" ||
    typeof transactionPayload.revocationReason !== "undefined" ||
    typeof transactionPayload.revocationType !== "undefined"
  ) {
    return {
      status: "revoked",
      expirationDate,
      purchaseDate,
    };
  }

  if (transactionType === "Non-Consumable" || !transactionPayload.expiresDate) {
    return {
      status: "lifetime",
      expirationDate: null,
      purchaseDate,
    };
  }

  return {
    status: transactionPayload.expiresDate > Date.now() ?
      "subscribed" :
      "expired",
    expirationDate,
    purchaseDate,
  };
}

/**
 * notificationType + renewalInfo를 반영해 웹훅 상태를 계산한다.
 *
 * @param {string} notificationType App Store notification type
 * @param {JWSTransactionDecodedPayload} transactionPayload 검증된 transaction
 * @param {JWSRenewalInfoDecodedPayload | null} renewalInfo 검증된 renewal info
 * @return {Pick<SubscriptionStatusData,
 *   "status" | "expirationDate" | "purchaseDate"> | null} 계산된 상태
 */
function deriveStatusFromNotification(
  notificationType: string,
  transactionPayload: JWSTransactionDecodedPayload,
  renewalInfo: JWSRenewalInfoDecodedPayload | null,
): Pick<
  SubscriptionStatusData,
  "status" | "expirationDate" | "purchaseDate"
> | null {
  const transactionState = deriveStatusFromTransaction(transactionPayload);
  const graceExpirationDate = toISOStringOrNull(
    renewalInfo?.gracePeriodExpiresDate ?? renewalInfo?.renewalDate,
  );

  switch (notificationType) {
  case NotificationTypeV2.SUBSCRIBED:
  case NotificationTypeV2.DID_RENEW:
  case NotificationTypeV2.DID_CHANGE_RENEWAL_PREF:
  case NotificationTypeV2.DID_CHANGE_RENEWAL_STATUS:
  case NotificationTypeV2.OFFER_REDEEMED:
  case NotificationTypeV2.PRICE_INCREASE:
  case NotificationTypeV2.RENEWAL_EXTENDED:
  case NotificationTypeV2.RENEWAL_EXTENSION:
  case NotificationTypeV2.REFUND_REVERSED:
    return transactionState;

  case NotificationTypeV2.DID_FAIL_TO_RENEW:
    return {
      ...transactionState,
      status: renewalInfo?.isInBillingRetryPeriod ||
          renewalInfo?.gracePeriodExpiresDate ?
        "gracePeriod" :
        "expired",
      expirationDate: graceExpirationDate ?? transactionState.expirationDate,
    };

  case NotificationTypeV2.EXPIRED:
    return {
      ...transactionState,
      status: "expired",
    };

  case NotificationTypeV2.GRACE_PERIOD_EXPIRED:
    return {
      ...transactionState,
      status: "expired",
      expirationDate: graceExpirationDate ?? transactionState.expirationDate,
    };

  case NotificationTypeV2.REVOKE:
  case NotificationTypeV2.REFUND:
    return {
      ...transactionState,
      status: "revoked",
    };

  default:
    return null;
  }
}

/**
 * verifyPurchase — 클라이언트에서 구매 후 JWS 토큰을 전송하여 서버에서 검증
 *
 * 흐름:
 * 1. 인증 확인
 * 2. App Store signed transaction 검증
 * 3. subscriptionOwners/{originalTransactionId}로 소유권 확인 (1:1 바인딩)
 * 4. replay/stale 이벤트를 차단하며 subscriptions/{userId} 갱신
 * 5. 결과 반환
 *
 * @remarks
 * **인증 필수**
 */
export const verifyPurchase = onCall<VerifyPurchaseRequest>(
  {region: REGION},
  async (request): Promise<VerifyPurchaseResponse> => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "로그인이 필요합니다");
    }

    const userId = request.auth.uid;
    const data = request.data;

    if (!data.transactionJWS || !data.productId) {
      throw new HttpsError(
        "invalid-argument",
        "transactionJWS와 productId는 필수입니다",
      );
    }

    console.log("📱 [Subscription] Verify purchase started", {
      userId,
      productId: data.productId,
    });

    try {
      const payload = await verifyAppleTransactionJWS(data.transactionJWS);

      const productId = payload.productId;
      const originalTransactionId = payload.originalTransactionId;
      const transactionId = payload.transactionId ?? null;

      if (!productId || !originalTransactionId) {
        throw new HttpsError(
          "failed-precondition",
          "유효한 App Store 트랜잭션 정보가 없습니다",
        );
      }

      console.log("✅ [Subscription] Transaction verified", {
        originalTransactionId,
        transactionId,
        productId,
      });

      if (productId !== data.productId) {
        throw new HttpsError(
          "invalid-argument",
          "상품 ID가 일치하지 않습니다",
        );
      }

      const derivedStatus = deriveStatusFromTransaction(payload);
      const signedDate = latestSignedDate(payload.signedDate);

      const db = admin.firestore();
      const subscriptionRef = db.collection("subscriptions").doc(userId);
      const ownerRef = db.collection("subscriptionOwners")
        .doc(originalTransactionId);

      const transactionResult = await db.runTransaction(async (transaction) => {
        const [ownerDoc, subscriptionDoc] = await Promise.all([
          transaction.get(ownerRef),
          transaction.get(subscriptionRef),
        ]);

        if (ownerDoc.exists) {
          const existingOwner = ownerDoc.data()?.userId;
          if (existingOwner && existingOwner !== userId) {
            throw new HttpsError(
              "already-exists",
              "이 구독은 다른 계정에 연결되어 있습니다",
            );
          }
        }

        transaction.set(ownerRef, {
          userId,
          productId,
          createdAt: ownerDoc.exists ?
            ownerDoc.data()?.createdAt :
            FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        }, {merge: true});

        const existingSubscription =
          subscriptionDoc.data() as StoredSubscriptionData | undefined;
        const currentLatestSignedDate =
          existingLatestSignedDate(existingSubscription);

        if (
          signedDate !== null &&
          currentLatestSignedDate !== null &&
          signedDate < currentLatestSignedDate
        ) {
          console.warn(
            "⚠️ [Subscription] Stale purchase verification ignored",
            {
              userId,
              originalTransactionId,
              signedDate,
              currentLatestSignedDate,
            },
          );

          return buildResponseStatus(existingSubscription ?? {});
        }

        const subscriptionData: SubscriptionStatusData = {
          status: derivedStatus.status,
          productId,
          originalTransactionId,
          expirationDate: derivedStatus.expirationDate,
          purchaseDate: derivedStatus.purchaseDate,
          latestAppStoreSignedDate: signedDate,
          latestTransactionId: transactionId,
          lastNotificationType: null,
          updatedAt: FieldValue.serverTimestamp() as
            FirebaseFirestore.Timestamp,
        };

        transaction.set(subscriptionRef, subscriptionData, {merge: true});

        console.log("✅ [Subscription] Updated purchase state", {
          userId,
          originalTransactionId,
          status: derivedStatus.status,
          signedDate,
        });

        return buildResponseStatus(subscriptionData);
      });

      return {
        success: true,
        subscriptionStatus: transactionResult,
      };
    } catch (error) {
      console.error("❌ [Subscription] Verify purchase error:", error);

      if (error instanceof HttpsError) {
        throw error;
      }

      throw new HttpsError(
        "internal",
        "구매 검증 중 오류가 발생했습니다",
      );
    }
  },
);

/**
 * appleServerNotification — App Store Server Notifications V2 웹훅
 *
 * Apple이 구독 상태 변경 시 자동으로 호출하는 웹훅
 *
 * @remarks
 * onRequest를 사용 (onCall이 아님 — Apple이 직접 HTTP POST)
 */
export const appleServerNotification = onRequest(
  {region: REGION},
  async (req, res) => {
    console.log("📱 [Subscription] Apple Server Notification received");

    try {
      const body = req.body as AppleNotificationPayload;
      if (!body.signedPayload) {
        res.status(400).json({success: false, error: "Missing signedPayload"});
        return;
      }

      const payload = await verifyAppleNotificationPayload(body.signedPayload);
      const notificationType = payload.notificationType as string | undefined;

      if (!notificationType) {
        res.status(400).json({
          success: false,
          error: "Missing notificationType",
        });
        return;
      }

      if (NO_OP_NOTIFICATION_TYPES.has(notificationType)) {
        console.log(
          "ℹ️ [Subscription] Notification acknowledged without mutation",
          {notificationType},
        );
        res.status(200).json({success: true});
        return;
      }

      const notificationData = payload.data;
      const signedTransactionInfo = notificationData?.signedTransactionInfo;
      if (!signedTransactionInfo) {
        res.status(400).json({
          success: false,
          error: "Missing signedTransactionInfo",
        });
        return;
      }

      const transactionPayload =
        await verifyAppleTransactionJWS(signedTransactionInfo);
      const renewalInfo = notificationData?.signedRenewalInfo ?
        await verifyAppleRenewalInfoJWS(notificationData.signedRenewalInfo) :
        null;

      const originalTransactionId = transactionPayload.originalTransactionId;
      const productId = transactionPayload.productId ?? null;

      if (!originalTransactionId) {
        throw new RetryableNotificationError(
          "Missing originalTransactionId",
        );
      }

      console.log("✅ [Subscription] Notification verified", {
        notificationType,
        originalTransactionId,
        transactionId: transactionPayload.transactionId ?? null,
        productId,
      });

      const derivedStatus = deriveStatusFromNotification(
        notificationType,
        transactionPayload,
        renewalInfo,
      );

      if (!derivedStatus) {
        console.log("ℹ️ [Subscription] Notification type skipped", {
          notificationType,
          originalTransactionId,
        });
        res.status(200).json({success: true});
        return;
      }

      const db = admin.firestore();
      const ownerRef = db.collection("subscriptionOwners")
        .doc(originalTransactionId);
      const ownerDoc = await ownerRef.get();

      if (!ownerDoc.exists) {
        throw new RetryableNotificationError(
          `Owner not found for txId: ${originalTransactionId}`,
        );
      }

      const ownerData = ownerDoc.data();
      const userId = ownerData?.userId as string | undefined;
      if (!userId) {
        throw new RetryableNotificationError(
          `Owner userId missing for txId: ${originalTransactionId}`,
        );
      }
      const subscriptionRef = db.collection("subscriptions").doc(userId);
      const signedDate = latestSignedDate(
        payload.signedDate,
        transactionPayload.signedDate,
        renewalInfo?.signedDate,
      );

      await db.runTransaction(async (transaction) => {
        const subscriptionDoc = await transaction.get(subscriptionRef);
        const existingSubscription =
          subscriptionDoc.data() as StoredSubscriptionData | undefined;
        const currentLatestSignedDate =
          existingLatestSignedDate(existingSubscription);

        if (
          signedDate !== null &&
          currentLatestSignedDate !== null &&
          signedDate < currentLatestSignedDate
        ) {
          console.warn("⚠️ [Subscription] Stale notification ignored", {
            userId,
            originalTransactionId,
            notificationType,
            signedDate,
            currentLatestSignedDate,
          });
          return;
        }

        const subscriptionData: SubscriptionStatusData = {
          status: derivedStatus.status,
          productId,
          originalTransactionId,
          expirationDate: derivedStatus.expirationDate,
          purchaseDate: derivedStatus.purchaseDate,
          latestAppStoreSignedDate: signedDate,
          latestTransactionId: transactionPayload.transactionId ?? null,
          lastNotificationType: notificationType,
          updatedAt: FieldValue.serverTimestamp() as
            FirebaseFirestore.Timestamp,
        };

        transaction.set(subscriptionRef, subscriptionData, {merge: true});

        const isInactive = ["expired", "revoked"].includes(
          derivedStatus.status,
        );
        if (isInactive) {
          const settingsRef = db
            .collection("users").doc(userId)
            .collection("settings").doc("main");
          const briefingSubscriptionRef = db
            .collection("briefingSubscriptions").doc(userId);
          transaction.set(settingsRef, {
            proSettings: FieldValue.delete(),
          }, {merge: true});
          transaction.delete(briefingSubscriptionRef);
          console.log(`🧹 [Subscription] Cleaned proSettings for ${userId}`);
        }

        console.log("✅ [Subscription] Notification applied", {
          userId,
          originalTransactionId,
          notificationType,
          status: derivedStatus.status,
          signedDate,
        });
      });

      res.status(200).json({success: true});
    } catch (error) {
      console.error("❌ [Subscription] Apple notification error:", error);

      if (error instanceof RetryableNotificationError) {
        res.status(500).json({success: false, error: error.message});
        return;
      }

      const message = error instanceof Error ? error.message : String(error);
      res.status(200).json({success: false, error: message});
    }
  },
);
