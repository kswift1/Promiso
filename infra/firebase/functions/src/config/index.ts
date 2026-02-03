/**
 * Firebase Functions 공통 설정
 */
import * as admin from "firebase-admin";
import {setGlobalOptions} from "firebase-functions/v2";
import {defineSecret} from "firebase-functions/params";
import {
  logEnvironmentInfo,
  getCurrentEnvironment,
  FirestoreEnvironment,
} from "../utils/firestore";

// Firebase Admin 초기화
admin.initializeApp();

// 환경 정보 로깅
logEnvironmentInfo();

// 공통 옵션(비용/스케일 제어)
setGlobalOptions({maxInstances: 10});

// 리전 설정
export const REGION = "asia-northeast3";

// APNs 인증 시크릿 (Firebase Secret Manager)
export const APNS_KEY_ID = defineSecret("APNS_KEY_ID");
export const APNS_TEAM_ID = defineSecret("APNS_TEAM_ID");
export const APNS_AUTH_KEY = defineSecret("APNS_AUTH_KEY");

// Gemini API 시크릿
export const GEMINI_API_KEY = defineSecret("GEMINI_API_KEY");

// APNs 호스트 설정
export const APNS_HOST_PRODUCTION = "api.push.apple.com";
export const APNS_HOST_DEVELOPMENT = "api.sandbox.push.apple.com";

// APNs Channel Management 호스트 (채널 생성/삭제용)
export const CHANNEL_MGMT_HOST_PRODUCTION =
  "api-manage-broadcast.push.apple.com";
export const CHANNEL_MGMT_HOST_DEVELOPMENT =
  "api-manage-broadcast.sandbox.push.apple.com";
export const CHANNEL_MGMT_PORT_PRODUCTION = 2196;
export const CHANNEL_MGMT_PORT_DEVELOPMENT = 2195;

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

export const APNS_BUNDLE_ID = getAPNsBundleId();

// Firebase Admin 인스턴스 export
export {admin};
