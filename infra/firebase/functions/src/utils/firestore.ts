import * as admin from "firebase-admin";

/**
 * Firebase Functions 실행 환경
 */
export enum FirestoreEnvironment {
  /** 개발 환경 (Emulator) */
  Dev = "dev",
  /** 스테이징 환경 */
  Stage = "stage",
  /** 프로덕션 환경 */
  Release = "release",
}

/**
 * 현재 Functions 실행 환경 감지
 *
 * @return {FirestoreEnvironment} 현재 환경 (Dev or Release)
 *
 * @remarks
 * - Emulator: FUNCTIONS_EMULATOR 환경 변수가 "true"
 * - Production: 그 외
 */
export function getCurrentEnvironment(): FirestoreEnvironment {
  const isEmulator = process.env.FUNCTIONS_EMULATOR === "true";
  return isEmulator ? FirestoreEnvironment.Dev : FirestoreEnvironment.Release;
}

/**
 * 환경에 맞는 Firestore 컬렉션 참조 반환
 *
 * @param {string} collectionName - 컬렉션 이름 (예: "groups", "users")
 * @param {FirebaseFirestore.Firestore} db - Firestore 인스턴스
 * @param {string | null | undefined} requestedEnv - 요청된 환경 (stage/prod)
 * @return {FirebaseFirestore.CollectionReference} 환경별 컬렉션 참조
 *
 * @remarks
 * **경로 구조**:
 * - Dev (Emulator): `dev/root/{collectionName}`
 * - Stage: `stage/root/{collectionName}`
 * - Release (Production): `prod/root/{collectionName}`
 *
 * **iOS와 동일한 경로 구조**를 사용하여 데이터 일관성 보장
 *
 * @example
 * ```typescript
 * // Dev: dev/root/groups
 * // Stage: stage/root/groups
 * // Release: prod/root/groups
 * const groupsRef = getEnvironmentCollection("groups");
 * ```
 */
export function getEnvironmentCollection(
  collectionName: string,
  db: FirebaseFirestore.Firestore = admin.firestore(),
  requestedEnv?: string | null,
): FirebaseFirestore.CollectionReference {
  const env = resolveEnvironment(requestedEnv);

  switch (env) {
  case FirestoreEnvironment.Dev:
    // Dev: dev/root/{collection}
    return db.collection("dev").doc("root").collection(collectionName);

  case FirestoreEnvironment.Stage:
    // Stage: stage/root/{collection}
    return db.collection("stage").doc("root").collection(collectionName);

  case FirestoreEnvironment.Release:
    // Release: prod/root/{collection}
    return db.collection("prod").doc("root").collection(collectionName);
  }
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
  console.log(`🌍 Firestore Environment: ${env}`);
  console.log(`📁 Path Pattern: ${getPathPattern(env)}`);
}

/**
 * 환경별 경로 패턴 반환
 *
 * @param {FirestoreEnvironment} env - 환경
 * @return {string} 경로 패턴
 */
function getPathPattern(env: FirestoreEnvironment): string {
  switch (env) {
  case FirestoreEnvironment.Dev:
    return "dev/root/{collection}";
  case FirestoreEnvironment.Stage:
    return "stage/root/{collection}";
  case FirestoreEnvironment.Release:
    return "prod/root/{collection}";
  }
}

/**
 * 요청 환경을 실제 실행 환경으로 매핑합니다.
 *
 * @param {string | null | undefined} requestedEnv - 요청된 환경
 * @return {FirestoreEnvironment} 해석된 환경
 */
function resolveEnvironment(
  requestedEnv?: string | null,
): FirestoreEnvironment {
  const isEmulator = process.env.FUNCTIONS_EMULATOR === "true";
  if (isEmulator) return FirestoreEnvironment.Dev;

  if (requestedEnv === "stage") return FirestoreEnvironment.Stage;
  return FirestoreEnvironment.Release;
}
