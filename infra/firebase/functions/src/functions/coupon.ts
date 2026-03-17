/**
 * Coupon Functions (사용자 쿠폰 사용)
 */
import {FieldValue} from "firebase-admin/firestore";
import {HttpsError, onCall} from "firebase-functions/v2/https";
import {admin, REGION} from "../config";
import {hasActiveSubscription} from "../utils/briefingScheduler";
import type {
  RedeemCouponRequest, RedeemCouponResponse,
} from "../types/admin";

// Admin subcollection 헬퍼
const adminCol = (name: string) =>
  admin.firestore().collection("admin").doc("config")
    .collection(name);

export const redeemCoupon = onCall<RedeemCouponRequest>(
  {region: REGION},
  async (request): Promise<RedeemCouponResponse> => {
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated", "로그인이 필요합니다"
      );
    }

    const userId = request.auth.uid;
    const code = request.data.code?.trim().toUpperCase();

    if (!code) {
      throw new HttpsError(
        "invalid-argument", "쿠폰 코드는 필수입니다"
      );
    }

    const db = admin.firestore();
    const couponRef = adminCol("coupons").doc(code);
    const overrideRef =
      db.collection("entitlementOverrides").doc(userId);

    const subscriptionRef =
      db.collection("subscriptions").doc(userId);

    const result = await db.runTransaction(async (tx) => {
      const [couponDoc, overrideDoc, subscriptionDoc] = await Promise.all([
        tx.get(couponRef),
        tx.get(overrideRef),
        tx.get(subscriptionRef),
      ]);

      // 구독 활성 상태면 쿠폰 사용 차단
      const subData = subscriptionDoc.data();
      if (subData && hasActiveSubscription(subData.status)) {
        throw new HttpsError(
          "failed-precondition", "구독 중에는 쿠폰을 사용할 수 없습니다"
        );
      }

      // 1인 1쿠폰: 이미 쿠폰을 사용한 적이 있으면 거부
      const overrideData = overrideDoc.data();
      if (overrideDoc.exists && overrideData?.type === "coupon_redeem") {
        throw new HttpsError(
          "already-exists", "이미 쿠폰을 사용한 계정입니다"
        );
      }

      if (!couponDoc.exists) {
        throw new HttpsError("not-found", "유효하지 않은 쿠폰 코드입니다");
      }

      const data = couponDoc.data();
      if (!data) {
        throw new HttpsError("not-found", "쿠폰 데이터를 읽을 수 없습니다");
      }

      if (data.redeemedBy) {
        throw new HttpsError("already-exists", "이미 사용된 쿠폰입니다");
      }

      const expiresAt = data.expiresAt ?
        new Date(data.expiresAt) :
        null;
      if (expiresAt && expiresAt < new Date()) {
        throw new HttpsError("failed-precondition", "만료된 쿠폰입니다");
      }

      const durationDays: number = data.durationDays ?? 30;
      const proExpiresAt = new Date(
        Date.now() + durationDays * 24 * 60 * 60 * 1000
      );

      tx.update(couponRef, {
        redeemedBy: userId,
        redeemedAt: FieldValue.serverTimestamp(),
      });

      tx.set(overrideRef, {
        isActive: true,
        type: "coupon_redeem",
        reason: `쿠폰 사용: ${code}`,
        couponCode: code,
        expiresAt: proExpiresAt.toISOString(),
        createdBy: "system",
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
        revokedAt: null,
        revokedBy: null,
        revokedReason: null,
      }, {merge: true});

      return {durationDays, proExpiresAt};
    });

    await adminCol("auditLogs").add({
      actorId: userId,
      action: "redeem_coupon",
      targetType: "coupon",
      targetId: code,
      before: null,
      after: {
        durationDays: result.durationDays,
        expiresAt: result.proExpiresAt.toISOString(),
      },
      createdAt: FieldValue.serverTimestamp(),
    });

    return {
      success: true,
      durationDays: result.durationDays,
      expiresAt: result.proExpiresAt.toISOString(),
    };
  }
);
