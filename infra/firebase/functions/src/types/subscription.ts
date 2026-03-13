/**
 * Subscription Types
 *
 * 구독 관련 타입 정의
 *
 * @ios ProPlanFeature
 */

// ============================================================================
// Verify Purchase
// ============================================================================

/**
 * 구매 검증 요청
 *
 * @remarks
 * - 인증 필수 (Firebase Auth)
 * - 클라이언트가 StoreKit 2 Transaction JWS를 서버로 전송
 */
export interface VerifyPurchaseRequest {
  /** StoreKit 2 Transaction의 JWS 토큰 */
  transactionJWS: string;

  /** 상품 ID */
  productId: string;
}

/**
 * 구매 검증 응답
 */
export interface VerifyPurchaseResponse {
  /** 성공 여부 */
  success: boolean;

  /** 구독 상태 데이터 */
  subscriptionStatus: SubscriptionStatusData;
}

// ============================================================================
// Subscription Status
// ============================================================================

/**
 * 구독 상태 데이터 (Firestore subscriptions/{userId} 문서 스키마)
 */
export interface SubscriptionStatusData {
  /** 현재 구독 상태 */
  status: "none" | "subscribed" | "lifetime" |
    "expired" | "gracePeriod" | "revoked";

  /** 상품 ID (현재 구독 중인 상품) */
  productId: string | null;

  /** 원본 트랜잭션 ID (Apple 기준 고유 ID) */
  originalTransactionId: string | null;

  /** 만료일 (ISO 8601, lifetime은 null) */
  expirationDate: string | null;

  /** 구매일 (ISO 8601) */
  purchaseDate: string | null;

  /** 가장 최근에 반영한 App Store signedDate (replay 방지용) */
  latestAppStoreSignedDate?: number | null;

  /** 가장 최근에 반영한 transactionId */
  latestTransactionId?: string | null;

  /** 가장 최근에 반영한 서버 알림 타입 */
  lastNotificationType?: string | null;

  /** 마지막 업데이트 (Timestamp) */
  updatedAt: FirebaseFirestore.Timestamp;
}

// ============================================================================
// Apple Notification Payload
// ============================================================================

/**
 * App Store Server Notifications V2 페이로드
 *
 * @remarks
 * Apple이 웹훅으로 전송하는 형식
 */
export interface AppleNotificationPayload {
  /** JWS 형태로 서명된 페이로드 */
  signedPayload: string;
}

// ============================================================================
// Error Codes
// ============================================================================

/**
 * 구매 검증 에러
 */
export enum VerifyPurchaseError {
  /** 인증 필요 */
  UNAUTHENTICATED = "unauthenticated",

  /** 잘못된 요청 */
  INVALID_ARGUMENT = "invalid-argument",

  /** 검증 실패 */
  VERIFICATION_FAILED = "failed-precondition",

  /** 서버 오류 */
  INTERNAL = "internal",
}
