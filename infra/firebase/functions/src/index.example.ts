import * as admin from "firebase-admin";
import {setGlobalOptions} from "firebase-functions/v2";
import {HttpsError, onCall, onRequest} from "firebase-functions/v2/https";
import {
  CreateGroupRequest,
  CreateGroupResponse,
  TestCallableRequest,
  TestCallableResponse,
} from "./types/api";

// Firebase Admin 초기화
admin.initializeApp();

// 공통 옵션(비용/스케일 제어)
setGlobalOptions({maxInstances: 10});

const REGION = "asia-northeast3";

// ============================================================================
// Test Functions
// ============================================================================

/**
 * 테스트용 HTTP 함수
 */
export const helloWorld = onRequest(
  {region: REGION},
  (request, response) => {
    response.json({
      message: "Hello from Firebase!",
      timestamp: new Date().toISOString(),
    });
  },
);

/**
 * 테스트용 Callable 함수
 *
 * @param request.data - TestCallableRequest
 * @returns TestCallableResponse
 */
export const testCallable = onCall<TestCallableRequest>(
  {region: REGION},
  (request): TestCallableResponse => {
    const name = request.data.name ?? "Guest";
    return {
      message: `Hello ${name}!`,
      authenticated: request.auth != null,
      uid: request.auth?.uid ?? null,
    };
  },
);

// ============================================================================
// Group Functions
// ============================================================================

/**
 * 그룹 생성
 *
 * **인증 필수**
 *
 * @param request.data - CreateGroupRequest
 * @returns CreateGroupResponse
 * @throws HttpsError
 * - unauthenticated: 로그인 필요
 * - invalid-argument: 잘못된 파라미터
 * - internal: 초대 코드 생성 실패
 *
 * @example
 * ```typescript
 * const result = await functions.httpsCallable('createGroup')({
 *   name: "주말 등산 모임",
 *   maxMembers: 5,
 *   photoPath: "groups/abc/photo.jpg"
 * });
 * console.log(result.data); // {id: "...", inviteCode: "AB12CD"}
 * ```
 */
export const createGroup = onCall<CreateGroupRequest>(
  {region: REGION},
  async (request): Promise<CreateGroupResponse> => {
    // 1. 인증 확인
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "로그인이 필요합니다");
    }

    // 2. 타입 안전한 데이터 추출
    const data = request.data;

    // 3. 유효성 검사
    validateCreateGroupRequest(data);

    // 4. 비즈니스 로직
    const creatorId = request.auth.uid;
    const db = admin.firestore();

    const inviteCode = await generateUniqueInviteCode({
      db,
      length: 6,
      maxAttempts: 5,
    });

    // 5. Firestore에 저장
    const groupRef = db.collection("groups").doc();
    const now = admin.firestore.FieldValue.serverTimestamp();

    await groupRef.set({
      name: data.name,
      description: null,
      emoji: null,
      themeColor: null,
      photoPath: data.photoPath ?? null,
      memberCount: 1,
      activePromiseCount: 0,
      maxMembers: data.maxMembers,
      requireApproval: false,
      defaultMinimumParticipants: 2,
      inviteCode,
      createdBy: creatorId,
      createdAt: now,
      updatedAt: now,
      isDeleted: false,
    });

    // 6. 응답 반환 (타입 안전)
    return {
      id: groupRef.id,
      inviteCode,
    };
  },
);

// ============================================================================
// Helper Functions
// ============================================================================

/**
 * CreateGroupRequest 유효성 검사
 *
 * @param data - CreateGroupRequest
 * @throws HttpsError (invalid-argument)
 */
function validateCreateGroupRequest(data: CreateGroupRequest): void {
  // name 검증
  const name = data.name.trim();
  if (name.length < 2) {
    throw new HttpsError(
      "invalid-argument",
      "그룹 이름은 최소 2글자 이상이어야 합니다",
    );
  }

  // maxMembers 검증
  if (!Number.isInteger(data.maxMembers)) {
    throw new HttpsError(
      "invalid-argument",
      "최대 인원(maxMembers)은 정수여야 합니다",
    );
  }

  if (data.maxMembers < 2 || data.maxMembers > 10) {
    throw new HttpsError(
      "invalid-argument",
      "최대 인원(maxMembers)은 2~10 사이여야 합니다",
    );
  }
}

/**
 * 유니크한 초대 코드 생성
 *
 * @param params.db - Firestore 인스턴스
 * @param params.length - 코드 길이
 * @param params.maxAttempts - 최대 재시도 횟수
 * @returns 유니크한 초대 코드
 * @throws HttpsError (internal) - 생성 실패 시
 */
async function generateUniqueInviteCode(params: {
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

    if (snapshot.empty) {
      return code;
    }
  }

  throw new HttpsError(
    "internal",
    "초대 코드를 생성하지 못했어요. 잠시 후 다시 시도해주세요.",
  );
}

/**
 * 랜덤 초대 코드 생성 (영숫자 대문자)
 *
 * @param length - 코드 길이
 * @returns 랜덤 코드
 */
function randomInviteCode(length: number): string {
  const characters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
  let code = "";

  for (let i = 0; i < length; i++) {
    const randomIndex = Math.floor(Math.random() * characters.length);
    code += characters.charAt(randomIndex);
  }

  return code;
}
