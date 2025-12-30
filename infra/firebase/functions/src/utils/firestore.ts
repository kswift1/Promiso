import * as admin from "firebase-admin";

/**
 * Firebase Functions 실행 환경
 */
export enum FirestoreEnvironment {
  /** 개발 환경 (Emulator) */
  Dev = "dev",
  /** 프로덕션 환경 */
  Release = "release",
}

/**
 * 현재 Functions 실행 환경 감지
 *
 * @returns 현재 환경 (Dev or Release)
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
 * @param collectionName - 컬렉션 이름 (예: "groups", "users")
 * @param db - Firestore 인스턴스 (기본값: admin.firestore())
 * @returns 환경별 컬렉션 참조
 *
 * @remarks
 * **경로 구조**:
 * - Dev (Emulator): `dev/root/{collectionName}`
 * - Release (Production): `{collectionName}`
 *
 * **iOS와 동일한 경로 구조**를 사용하여 데이터 일관성 보장
 *
 * @example
 * ```typescript
 * // Dev: dev/root/groups
 * // Release: groups
 * const groupsRef = getEnvironmentCollection("groups");
 * ```
 */
export function getEnvironmentCollection(
  collectionName: string,
  db: FirebaseFirestore.Firestore = admin.firestore(),
): FirebaseFirestore.CollectionReference {
  const env = getCurrentEnvironment();

  switch (env) {
  case FirestoreEnvironment.Dev:
    // Dev: dev/root/{collection}
    return db.collection("dev").doc("root").collection(collectionName);

  case FirestoreEnvironment.Release:
    // Release: {collection}
    return db.collection(collectionName);
  }
}

/**
 * 환경 정보 로깅
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
 */
function getPathPattern(env: FirestoreEnvironment): string {
  return env === FirestoreEnvironment.Dev
    ? "dev/root/{collection}"
    : "{collection}";
}
