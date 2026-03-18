/**
 * App Store JWS 검증 유틸리티
 *
 * Apple 공식 App Store Server Library 기반으로
 * transaction / renewal / notification JWS를 검증한다.
 */
import {
  Environment,
  JWSRenewalInfoDecodedPayload,
  JWSTransactionDecodedPayload,
  ResponseBodyV2DecodedPayload,
  SignedDataVerifier,
} from "@apple/app-store-server-library";
import {readFileSync} from "fs";
import path from "path";
import {
  APP_STORE_APPLE_ID,
  APP_STORE_BUNDLE_ID,
} from "../config";
import {
  FirestoreEnvironment,
  getCurrentEnvironment,
} from "./firestore";

const APPLE_ROOT_CERTIFICATE_PATHS = [
  path.resolve(__dirname, "../../certs/AppleRootCA-G2.der"),
  path.resolve(__dirname, "../../certs/AppleRootCA-G3.der"),
];

let signedDataVerifier: SignedDataVerifier | null = null;

/**
 * Firebase 환경을 App Store verifier 환경으로 변환한다.
 *
 * @return {Environment} App Store verifier 환경
 */
function getVerifierEnvironment(): Environment {
  return getCurrentEnvironment() === FirestoreEnvironment.Release ?
    Environment.PRODUCTION :
    Environment.SANDBOX;
}

/**
 * App Store signed data verifier singleton을 생성한다.
 *
 * @return {SignedDataVerifier} 서명 검증기 인스턴스
 */
function getSignedDataVerifier(): SignedDataVerifier {
  if (signedDataVerifier) {
    return signedDataVerifier;
  }

  const appleRootCertificates = APPLE_ROOT_CERTIFICATE_PATHS.map((certPath) =>
    readFileSync(certPath)
  );

  signedDataVerifier = new SignedDataVerifier(
    appleRootCertificates,
    false,
    getVerifierEnvironment(),
    APP_STORE_BUNDLE_ID,
    APP_STORE_APPLE_ID,
  );

  return signedDataVerifier;
}

/**
 * emulator 전용으로 JWS payload를 서명 검증 없이 디코딩한다.
 *
 * @param {string} jwsToken JWS 문자열
 * @return {T} 디코딩된 payload
 */
function decodeJWSPayload<T>(jwsToken: string): T {
  const parts = jwsToken.split(".");
  if (parts.length !== 3) {
    throw new Error("Invalid JWS format");
  }

  const decoded = Buffer.from(parts[1], "base64url").toString("utf-8");
  return JSON.parse(decoded) as T;
}

/**
 * StoreKit signed transaction을 검증하고 디코딩한다.
 *
 * @param {string} jwsToken signed transaction JWS
 * @return {Promise<JWSTransactionDecodedPayload>} 검증된 transaction payload
 */
export async function verifyAppleTransactionJWS(
  jwsToken: string,
): Promise<JWSTransactionDecodedPayload> {
  if (process.env.FUNCTIONS_EMULATOR === "true") {
    console.warn("⚠️ [AppStore] Emulator: Skipping transaction JWS verify");
    return decodeJWSPayload<JWSTransactionDecodedPayload>(jwsToken);
  }

  const verify = () =>
    getSignedDataVerifier().verifyAndDecodeTransaction(jwsToken);

  if (getCurrentEnvironment() === FirestoreEnvironment.Dev) {
    try {
      return await verify();
    } catch (error) {
      console.warn(
        "⚠️ [AppStore] Dev: Apple verify failed," +
        " falling back to decode-only",
        error,
      );
      return decodeJWSPayload<JWSTransactionDecodedPayload>(
        jwsToken,
      );
    }
  }

  return verify();
}

/**
 * App Store signed renewal info를 검증하고 디코딩한다.
 *
 * @param {string} jwsToken signed renewal info JWS
 * @return {Promise<JWSRenewalInfoDecodedPayload>} 검증된 renewal payload
 */
export async function verifyAppleRenewalInfoJWS(
  jwsToken: string,
): Promise<JWSRenewalInfoDecodedPayload> {
  if (process.env.FUNCTIONS_EMULATOR === "true") {
    console.warn(
      "⚠️ [AppStore] Emulator: Skipping renewal JWS verify",
    );
    return decodeJWSPayload<JWSRenewalInfoDecodedPayload>(
      jwsToken,
    );
  }

  const verify = () =>
    getSignedDataVerifier().verifyAndDecodeRenewalInfo(jwsToken);

  if (getCurrentEnvironment() === FirestoreEnvironment.Dev) {
    try {
      return await verify();
    } catch (error) {
      console.warn(
        "⚠️ [AppStore] Dev: Apple verify failed," +
        " falling back to decode-only",
        error,
      );
      return decodeJWSPayload<JWSRenewalInfoDecodedPayload>(
        jwsToken,
      );
    }
  }

  return verify();
}

/**
 * App Store Server Notification payload를 검증하고 디코딩한다.
 *
 * @param {string} signedPayload signedPayload JWS
 * @return {Promise<ResponseBodyV2DecodedPayload>} 검증된 notification payload
 */
export async function verifyAppleNotificationPayload(
  signedPayload: string,
): Promise<ResponseBodyV2DecodedPayload> {
  if (process.env.FUNCTIONS_EMULATOR === "true") {
    console.warn(
      "⚠️ [AppStore] Emulator: Skipping notification verify",
    );
    return decodeJWSPayload<ResponseBodyV2DecodedPayload>(
      signedPayload,
    );
  }

  const verify = () =>
    getSignedDataVerifier().verifyAndDecodeNotification(signedPayload);

  if (getCurrentEnvironment() === FirestoreEnvironment.Dev) {
    try {
      return await verify();
    } catch (error) {
      console.warn(
        "⚠️ [AppStore] Dev: Apple verify failed," +
        " falling back to decode-only",
        error,
      );
      return decodeJWSPayload<ResponseBodyV2DecodedPayload>(
        signedPayload,
      );
    }
  }

  return verify();
}
