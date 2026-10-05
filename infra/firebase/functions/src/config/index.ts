/**
 * Firebase Functions 공통 설정
 */
import * as admin from "firebase-admin";
import {setGlobalOptions} from "firebase-functions/v2";
import {
  logEnvironmentInfo,
  getCurrentEnvironment,
  FirestoreEnvironment,
} from "../utils/firestore";

// Firebase Admin 초기화 (이미 초기화되어 있으면 skip)
if (!admin.apps.length) {
  admin.initializeApp();
}

// 환경 정보 로깅
logEnvironmentInfo();

// 공통 옵션(비용/스케일 제어)
setGlobalOptions({maxInstances: 10});

// 리전 설정
export const REGION = "asia-northeast3";

/**
 * APNs Bundle ID (환경별)
 *
 * @return {string} 환경에 맞는 Bundle ID
 *
 * @remarks
 * - Dev: com.promiso.dev
 * - Stage: com.promiso.stage
 * - Release: com.promiso
 */
function getAPNsBundleId(): string {
  const env = getCurrentEnvironment();
  switch (env) {
  case FirestoreEnvironment.Dev:
    return "com.promiso.dev";
  case FirestoreEnvironment.Stage:
    return "com.promiso.stage";
  case FirestoreEnvironment.Release:
  default:
    return "com.promiso";
  }
}

export const APP_STORE_BUNDLE_ID = getAPNsBundleId();

/**
 * App Store Connect appAppleId (프로덕션 검증용)
 *
 * @remarks
 * Sandbox 환경에서는 SignedDataVerifier에 appAppleId가 필요하지 않다.
 */
export const APP_STORE_APPLE_ID = getCurrentEnvironment() ===
  FirestoreEnvironment.Release ?
  6757733720 :
  undefined;

export const APNS_BUNDLE_ID = APP_STORE_BUNDLE_ID;

// App Store Server Notification 시크릿 (향후 사용)
// export const APP_STORE_SHARED_SECRET =
//   defineSecret("APP_STORE_SHARED_SECRET");

// Firebase Admin 인스턴스 export
export {admin};
