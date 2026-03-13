/**
 * 공통 헬퍼 함수
 */
import {HttpsError} from "firebase-functions/v2/https";
import {admin} from "../config";
import {CreateGroupRequest} from "../types/api";

/**
 * CreateGroupRequest 유효성 검사
 *
 * @param {CreateGroupRequest} data - CreateGroupRequest
 * @throws {HttpsError} invalid-argument
 * @return {void}
 */
export function validateCreateGroupRequest(data: CreateGroupRequest): void {
  const groupId = data.groupId.trim();
  if (groupId.length == 0) {
    throw new HttpsError(
      "invalid-argument",
      "groupId는 비어있을 수 없습니다",
    );
  }

  // Firestore 문서 ID에 '/'는 허용되지 않음
  if (groupId.includes("/")) {
    throw new HttpsError(
      "invalid-argument",
      "groupId에 '/' 문자는 허용되지 않습니다",
    );
  }

  // name 검증 (2~12자)
  const name = data.name.trim();
  if (name.length < 2) {
    throw new HttpsError(
      "invalid-argument",
      "그룹 이름은 최소 2글자 이상이어야 합니다",
    );
  }
  if (name.length > 12) {
    throw new HttpsError(
      "invalid-argument",
      "그룹 이름은 최대 12글자까지 가능합니다",
    );
  }

  // description 검증 (최대 50자)
  if (data.description && data.description.length > 50) {
    throw new HttpsError(
      "invalid-argument",
      "그룹 설명은 최대 50글자까지 가능합니다",
    );
  }

  // maxMembers 검증
  if (!Number.isInteger(data.maxMembers)) {
    throw new HttpsError(
      "invalid-argument",
      "최대 인원(maxMembers)은 정수여야 합니다",
    );
  }

  if (data.maxMembers < 2) {
    throw new HttpsError(
      "invalid-argument",
      "최대 인원(maxMembers)은 2 이상이어야 합니다",
    );
  }
}

/**
 * Firebase Storage URL 유효성 검증
 *
 * @param {string} url - 검증할 URL
 * @return {boolean} Firebase Storage URL 형식이면 true
 */
export function isValidFirebaseStorageUrl(url: string): boolean {
  const bucket = admin.storage().bucket();
  const bucketName = bucket.name;

  if (url.startsWith(`gs://${bucketName}/`)) {
    return true;
  }

  // iOS SDK downloadURL()은 :443 포트를 포함할 수 있음
  const httpsPrefix = "https://firebasestorage.googleapis.com";
  const pathPrefix = `/v0/b/${bucketName}/o/`;

  if (
    url.startsWith(`${httpsPrefix}${pathPrefix}`) ||
    url.startsWith(`${httpsPrefix}:443${pathPrefix}`)
  ) {
    return true;
  }

  return false;
}

/**
 * Storage 경로에서 downloadURL 생성
 *
 * @param {string} storagePath - Storage 파일 경로
 * @return {Promise<string>} Download URL
 */
export async function generateDownloadURL(
  storagePath: string
): Promise<string> {
  const bucket = admin.storage().bucket();
  const file = bucket.file(storagePath);

  // download token 생성 및 설정
  const downloadToken = crypto.randomUUID();

  await file.setMetadata({
    metadata: {
      firebaseStorageDownloadTokens: downloadToken,
    },
  });

  // Firebase Storage download URL 구성
  const bucketName = bucket.name;
  const encodedPath = encodeURIComponent(storagePath);
  const url = `https://firebasestorage.googleapis.com/v0/b/${bucketName}/o/${encodedPath}?alt=media&token=${downloadToken}`;

  return url;
}

/**
 * Generates a unique invite code that does not collide with existing groups.
 * @param {Object} params Params.
 * @param {FirebaseFirestore.Firestore} params.db Firestore instance.
 * @param {number} params.length Invite code length.
 * @param {number} params.maxAttempts Maximum retry attempts.
 * @return {Promise<string>} A unique invite code.
 */
export async function generateUniqueInviteCode(params: {
  db: FirebaseFirestore.Firestore;
  length: number;
  maxAttempts: number;
}): Promise<string> {
  const {db, length, maxAttempts} = params;
  const groups = db.collection("groups");

  for (let attempt = 0; attempt < maxAttempts; attempt++) {
    const code = randomInviteCode(length);
    const snapshot = await groups
      .where("inviteCode", "==", code)
      .limit(1)
      .get();
    if (snapshot.empty) return code;
  }

  throw new HttpsError(
    "internal",
    "초대 코드를 생성하지 못했어요. 잠시 후 다시 시도해주세요.",
  );
}

/**
 * Generates a random invite code.
 * @param {number} length Invite code length.
 * @return {string} Random invite code.
 */
export function randomInviteCode(length: number): string {
  const characters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
  let code = "";
  for (let i = 0; i < length; i++) {
    code += characters.charAt(Math.floor(Math.random() * characters.length));
  }
  return code;
}

/**
 * entitlement override가 현재 시각 기준으로 유효한지 판단한다.
 *
 * @param {Record<string, unknown> | null | undefined} overrideData override 문서.
 * @param {Date} now 비교 기준 시각.
 * @return {boolean} 현재 유효한 override면 true.
 */
export function isEntitlementOverrideActive(
  overrideData: Record<string, unknown> | null | undefined,
  now: Date = new Date(Date.now()),
): boolean {
  if (overrideData?.isActive !== true) {
    return false;
  }

  const expiresAt = typeof overrideData.expiresAt === "string" ?
    overrideData.expiresAt.trim() :
    "";
  if (!expiresAt) {
    return true;
  }

  const expiresAtDate = new Date(expiresAt);
  if (Number.isNaN(expiresAtDate.getTime())) {
    return true;
  }

  return expiresAtDate.getTime() > now.getTime();
}
