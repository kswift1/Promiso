/**
 * Firebase Functions 실행 환경
 *
 * @remarks
 * 프로젝트 분리 후에는 각 Firebase 프로젝트가 환경을 나타냄:
 * - promiso-dev: 개발 환경
 * - promiso-stage: 스테이징 환경
 * - promiso-prod: 프로덕션 환경
 */
export enum FirestoreEnvironment {
  /** 개발 환경 (Emulator 또는 promiso-dev) */
  Dev = "dev",
  /** 스테이징 환경 (promiso-stage) */
  Stage = "stage",
  /** 프로덕션 환경 (promiso-prod) */
  Release = "release",
}

/**
 * 현재 Functions 실행 환경 감지
 *
 * @return {FirestoreEnvironment} 현재 환경
 *
 * @remarks
 * - Emulator: FUNCTIONS_EMULATOR 환경 변수가 "true"
 * - Production: 그 외 (실제 환경은 배포된 프로젝트에 따라 결정)
 */
export function getCurrentEnvironment(): FirestoreEnvironment {
  const isEmulator = process.env.FUNCTIONS_EMULATOR === "true";
  return isEmulator ? FirestoreEnvironment.Dev : FirestoreEnvironment.Release;
}

/**
 * 환경 정보 로깅
 *
 * @return {void}
 *
 * @remarks
 * Functions 시작 시 호출하여 현재 환경 확인
 */
export function logEnvironmentInfo(): void {
  const env = getCurrentEnvironment();
  const projectId = process.env.GCLOUD_PROJECT || "unknown";
  console.log(`🌍 Environment: ${env}`);
  console.log(`📁 Project: ${projectId}`);
  console.log("📁 Path Pattern: /{collection} (root level)");
}
