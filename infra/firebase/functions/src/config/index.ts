/**
 * Firebase Functions 공통 설정
 */
import * as admin from "firebase-admin";
import {setGlobalOptions} from "firebase-functions/v2";
import {defineSecret, defineString} from "firebase-functions/params";
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

// APNs 인증 시크릿 (Firebase Secret Manager)
export const APNS_KEY_ID = defineSecret("APNS_KEY_ID");
export const APNS_TEAM_ID = defineSecret("APNS_TEAM_ID");
export const APNS_AUTH_KEY = defineSecret("APNS_AUTH_KEY");

// Gemini API 시크릿
export const GEMINI_API_KEY = defineSecret("GEMINI_API_KEY");

// Rust/PostgreSQL authority 접근용 시크릿
export const RUST_DATABASE_URL = defineSecret("RUST_DATABASE_URL");

// Slack Webhook 시크릿 (가입 알림용)
export const SLACK_WEBHOOK_URL = defineSecret("SLACK_WEBHOOK_URL");

// 기상청 공공데이터 API 시크릿
export const KMA_API_KEY = defineSecret("KMA_API_KEY");

// ODsay Lab API 시크릿 (대중교통 경로)
export const ODSAY_API_KEY = defineSecret("ODSAY_API_KEY");

// Kakao REST API 시크릿 (장소 검색 + Mobility)
export const KAKAO_REST_API_KEY = defineSecret("KAKAO_REST_API_KEY");

// Analytics 조회 설정
export const GA4_PROPERTY_ID = defineString("GA4_PROPERTY_ID", {
  default: "",
});
export const ANALYTICS_BIGQUERY_PROJECT_ID = defineString(
  "ANALYTICS_BIGQUERY_PROJECT_ID",
  {default: ""}
);
export const ANALYTICS_BIGQUERY_DATASET_ID = defineString(
  "ANALYTICS_BIGQUERY_DATASET_ID",
  {default: ""}
);
export const ANALYTICS_BIGQUERY_LOCATION = defineString(
  "ANALYTICS_BIGQUERY_LOCATION",
  {default: ""}
);

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

export const APP_STORE_BUNDLE_ID = getAPNsBundleId();

/**
 * App Store Connect appAppleId (프로덕션 검증용)
 *
 * @remarks
 * Sandbox 환경에서는 SignedDataVerifier에 appAppleId가 필요하지 않다.
 */
export const APP_STORE_APPLE_ID = getCurrentEnvironment() ===
  FirestoreEnvironment.Release ?
  1625074042 :
  undefined;

export const APNS_BUNDLE_ID = APP_STORE_BUNDLE_ID;

// App Store Server Notification 시크릿 (향후 사용)
// export const APP_STORE_SHARED_SECRET =
//   defineSecret("APP_STORE_SHARED_SECRET");

// Firebase Admin 인스턴스 export
export {admin};
