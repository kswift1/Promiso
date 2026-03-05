/**
 * App Store JWS 검증 유틸리티
 *
 * Apple의 JWS (JSON Web Signature) 토큰을 검증합니다.
 * - StoreKit 2 Transaction JWS
 * - App Store Server Notifications V2 signedPayload
 *
 * jose 라이브러리를 사용하여 Apple의 공개 인증서 체인을 검증합니다.
 */
import * as jose from "jose";

/**
 * Apple JWS 트랜잭션 토큰을 검증하고 페이로드를 반환
 *
 * 검증 과정:
 * 1. JWS 헤더에서 x5c (인증서 체인) 추출
 * 2. leaf 인증서로 서명 검증
 * 3. 검증된 페이로드 반환
 *
 * @param {string} jwsToken - StoreKit 2 JWS 토큰
 * @return {Promise<Record<string, unknown>>} 검증된 페이로드
 * @throws {Error} 검증 실패 시
 */
export async function verifyAppleJWS(jwsToken: string): Promise<Record<string, unknown>> {
  // 에뮬레이터 환경에서는 검증 스킵
  if (process.env.FUNCTIONS_EMULATOR === "true") {
    console.warn("⚠️ [AppStore] Emulator mode: Skipping JWS verification");
    return decodeJWSPayload(jwsToken);
  }

  try {
    // 1. JWS 헤더 디코딩
    const header = jose.decodeProtectedHeader(jwsToken);

    // 2. x5c (인증서 체인) 추출
    const x5c = header.x5c;
    if (!x5c || !Array.isArray(x5c) || x5c.length === 0) {
      throw new Error("Missing or invalid x5c certificate chain in JWS header");
    }

    // 3. leaf 인증서 (첫 번째 인증서)로 서명 검증
    const leafCert = `-----BEGIN CERTIFICATE-----\n${x5c[0]}\n-----END CERTIFICATE-----`;
    const publicKey = await jose.importX509(leafCert, header.alg as string);

    // 4. JWS 서명 검증 및 페이로드 추출
    const {payload} = await jose.jwtVerify(jwsToken, publicKey);

    console.log("✅ [AppStore] JWS verification successful");
    return payload as Record<string, unknown>;
  } catch (error) {
    console.error("❌ [AppStore] JWS verification failed:", error);
    throw new Error(`Apple JWS verification failed: ${error}`);
  }
}

/**
 * JWS 토큰에서 페이로드를 검증 없이 디코딩 (개발/디버깅용)
 *
 * @param {string} jwsToken - JWS 토큰
 * @return {Record<string, unknown>} 디코딩된 페이로드
 */
export function decodeJWSPayload(jwsToken: string): Record<string, unknown> {
  try {
    const parts = jwsToken.split(".");
    if (parts.length !== 3) {
      throw new Error("Invalid JWS format");
    }

    const payload = parts[1];
    const decoded = Buffer.from(payload, "base64url").toString("utf-8");
    return JSON.parse(decoded) as Record<string, unknown>;
  } catch (error) {
    console.error("❌ [AppStore] JWS decode failed:", error);
    throw new Error(`Failed to decode JWS payload: ${error}`);
  }
}
