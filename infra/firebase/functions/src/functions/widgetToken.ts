/**
 * Widget Token Functions
 *
 * Widget 전용 Long-lived Token 발급 및 검증
 *
 * @why Firebase ID Token은 1시간 만료 → Widget에서 앱 종료 후 갱신 불가
 * @solution 30일 유효 Widget Token 발급, 앱 실행 시 자동 갱신
 */
import {onCall, HttpsError} from "firebase-functions/v2/https";
import {defineSecret} from "firebase-functions/params";
import * as jwt from "jsonwebtoken";
import {admin, REGION} from "../config";

// Widget JWT 시크릿 (Firebase Secret Manager)
export const WIDGET_JWT_SECRET = defineSecret("WIDGET_JWT_SECRET");

// MARK: - Types

interface WidgetTokenPayload {
  sub: string; // userId
  scope: string; // "widget:read"
  deviceId: string; // 기기 바인딩
  version: number; // revocation용 버전
  iat: number; // issued at
  exp: number; // expiry
}

interface GenerateWidgetTokenRequest {
  deviceId: string;
}

interface GenerateWidgetTokenResponse {
  widgetToken: string;
  expiresAt: number; // Unix timestamp (seconds)
}

// MARK: - Constants

/** Widget Token 유효 기간 (30일) */
const TOKEN_VALIDITY_DAYS = 30;

/** Widget Token 갱신 권장 기간 (7일 이내면 갱신 권장) */
export const TOKEN_REFRESH_THRESHOLD_DAYS = 7;

// MARK: - Generate Widget Token

/**
 * Widget 전용 Long-lived Token 발급
 *
 * @requires Firebase ID Token 인증
 * @param deviceId - 기기 고유 ID (탈취 방지용 바인딩)
 * @returns widgetToken (JWT, 30일 유효)
 *
 * @security
 * - JWT 서명: 서버만 발급 가능
 * - scope 제한: widget:read만 허용
 * - deviceId 바인딩: 다른 기기에서 사용 불가
 * - version 필드: 비밀번호 변경 시 무효화 가능
 */
export const generateWidgetToken = onCall<GenerateWidgetTokenRequest>(
  {
    region: REGION,
    secrets: [WIDGET_JWT_SECRET],
  },
  async (request): Promise<GenerateWidgetTokenResponse> => {
    // 1. 인증 확인 (Firebase ID Token)
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "로그인이 필요합니다");
    }

    const userId = request.auth.uid;
    const {deviceId} = request.data;

    // 2. deviceId 유효성 검사
    if (!deviceId || deviceId.trim().length === 0) {
      throw new HttpsError("invalid-argument", "deviceId는 필수입니다");
    }

    // 3. 사용자의 토큰 버전 조회 (revocation용)
    const db = admin.firestore();
    const usersCollection = db.collection("users");
    const userDoc = await usersCollection.doc(userId).get();

    let tokenVersion = 1;
    if (userDoc.exists) {
      const userData = userDoc.data();
      tokenVersion = (userData?.widgetTokenVersion as number) || 1;
    }

    // 4. Widget Token 생성
    const now = Math.floor(Date.now() / 1000);
    const expiresAt = now + TOKEN_VALIDITY_DAYS * 24 * 60 * 60;

    const payload: Omit<WidgetTokenPayload, "iat" | "exp"> = {
      sub: userId,
      scope: "widget:read",
      deviceId: deviceId.trim(),
      version: tokenVersion,
    };

    const secret = WIDGET_JWT_SECRET.value();
    const widgetToken = jwt.sign(payload, secret, {
      expiresIn: `${TOKEN_VALIDITY_DAYS}d`,
    });

    console.log(
      `🔐 Widget Token 발급: user=${userId}, ` +
      `expires=${new Date(expiresAt * 1000).toISOString()}`
    );

    return {
      widgetToken,
      expiresAt,
    };
  }
);

// MARK: - Verify Widget Token (Helper)

/**
 * Widget Token 검증 헬퍼 함수
 *
 * @param {string} token - Widget Token (JWT)
 * @param {string} secret - JWT 시크릿
 * @return {WidgetTokenPayload} 검증된 payload
 * @throws {HttpsError} 검증 실패 시
 */
export function verifyWidgetToken(
  token: string,
  secret: string
): WidgetTokenPayload {
  try {
    const decoded = jwt.verify(token, secret) as WidgetTokenPayload;

    // scope 확인
    if (decoded.scope !== "widget:read") {
      throw new HttpsError("permission-denied", "Invalid token scope");
    }

    return decoded;
  } catch (error) {
    if (error instanceof jwt.TokenExpiredError) {
      throw new HttpsError("unauthenticated", "Widget token expired");
    }
    if (error instanceof jwt.JsonWebTokenError) {
      throw new HttpsError("unauthenticated", "Invalid widget token");
    }
    throw error;
  }
}

// MARK: - Revoke Widget Token

/**
 * 사용자의 모든 Widget Token 무효화
 *
 * 비밀번호 변경, 보안 이슈 발생 시 호출
 * widgetTokenVersion을 증가시켜 기존 토큰을 무효화
 *
 * @param {string} userId - 사용자 ID
 * @param {FirebaseFirestore.Firestore} db - Firestore 인스턴스
 * @return {Promise<void>}
 */
export async function revokeWidgetTokens(
  userId: string,
  db: FirebaseFirestore.Firestore
): Promise<void> {
  const usersCollection = db.collection("users");
  const userRef = usersCollection.doc(userId);

  await userRef.update({
    widgetTokenVersion: admin.firestore.FieldValue.increment(1),
  });

  console.log(`🔒 Widget Token 무효화: user=${userId}`);
}
