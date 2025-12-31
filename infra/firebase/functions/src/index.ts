import * as admin from "firebase-admin";
import {FieldValue} from "firebase-admin/firestore";
import {setGlobalOptions} from "firebase-functions/v2";
import {HttpsError, onCall, onRequest} from "firebase-functions/v2/https";
import {
  CreateGroupRequest,
  CreateGroupResponse,
  TestCallableRequest,
  TestCallableResponse,
} from "./types/api";
import {getEnvironmentCollection, logEnvironmentInfo} from "./utils/firestore";

// Firebase Admin 초기화
admin.initializeApp();

// 환경 정보 로깅
logEnvironmentInfo();

// 공통 옵션(비용/스케일 제어)
setGlobalOptions({maxInstances: 10});

const REGION = "asia-northeast3";

// ============================================================================
// Test Functions
// ============================================================================

/**
 * 테스트용 HTTP 함수
 *
 * @remarks
 * 배포 테스트 및 기본 연결 확인용
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
 * @remarks
 * Callable Function 연결 테스트용
 * 인증은 선택적이며, 인증 여부를 응답에 포함
 *
 * @param request.data - TestCallableRequest
 * @returns TestCallableResponse
 */
export const testCallable = onCall<TestCallableRequest>(
  {region: REGION},
  (request): TestCallableResponse => {
    const name = request.data?.name ?? "Guest";
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
 * @remarks
 * **인증 필수**
 *
 * 새로운 그룹을 생성하고 유니크한 초대 코드를 발급합니다.
 * iOS CreateGroup Feature와 연동됩니다.
 *
 * @param request.data - CreateGroupRequest
 * @returns CreateGroupResponse
 *
 * @throws HttpsError
 * - unauthenticated: 로그인이 필요합니다
 * - invalid-argument: 잘못된 파라미터 (name, maxMembers)
 * - internal: 초대 코드 생성 실패
 *
 * @example
 * ```typescript
 * // iOS에서 호출
 * let data: [String: Any] = [
 *   "name": "주말 등산 모임",
 *   "maxMembers": 5,
 *   "photo": { "type": "storagePath", "url": "groups/abc/photo.jpg" }
 * ]
 * let result = try await functions.httpsCallable("createGroup").call(data)
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

    // 4-1. 생성자 정보 조회
    const usersCollection = getEnvironmentCollection("users", db, data.env);
    const userDoc = await usersCollection.doc(creatorId).get();

    if (!userDoc.exists) {
      throw new HttpsError(
        "not-found",
        "사용자 정보를 찾을 수 없습니다. 다시 로그인해주세요.",
      );
    }

    const userData = userDoc.data();
    if (!userData) {
      throw new HttpsError(
        "internal",
        "사용자 데이터를 읽을 수 없습니다.",
      );
    }

    const creatorName = userData.name as string;
    const creatorNickname = userData.nickname as string;
    const creatorProfileImageUrl = (userData.profile?.url as string) ?? null;

    // 4-2. 초대 코드 생성
    const inviteCode = await generateUniqueInviteCode({
      db,
      length: 6,
      maxAttempts: 5,
    });

    // 5. Firestore에 저장 (환경별 경로)
    const groupsCollection = getEnvironmentCollection("groups", db, data.env);
    const groupRef = groupsCollection.doc();
    const now = FieldValue.serverTimestamp();

    // 5-1. 그룹 기본 정보 생성
    await groupRef.set({
      name: data.name,
      description: data.description ?? null,
      emoji: null,
      themeColor: null,
      photo: data.photo ?? null,
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

    // 5-2. 그룹 멤버에 생성자 추가
    await groupRef.collection("members").doc(creatorId).set({
      userId: creatorId,
      userName: creatorName,
      userNickname: creatorNickname,
      profileImageUrl: creatorProfileImageUrl,
      role: "admin",
      joinedAt: now,
      invitedBy: creatorId,
      isActive: true,
      leftAt: null,
    });

    // 5-3. 사용자의 그룹 목록에 추가
    await usersCollection
      .doc(creatorId)
      .collection("groups")
      .doc(groupRef.id)
      .set({
        groupId: groupRef.id,
        groupName: data.name,
        role: "admin",
        joinedAt: now,
        notifications: true,
      });

    // 6. 응답 반환 (타입 안전)
    return {
      id: groupRef.id,
      name: data.name,
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
 * @param {CreateGroupRequest} data - CreateGroupRequest
 * @throws {HttpsError} invalid-argument
 * @return {void}
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

  if (data.maxMembers < 2) {
    throw new HttpsError(
      "invalid-argument",
      "최대 인원(maxMembers)은 2 이상이어야 합니다",
    );
  }

  if (data.env && data.env !== "stage" && data.env !== "prod") {
    throw new HttpsError(
      "invalid-argument",
      "env는 stage 또는 prod만 허용됩니다",
    );
  }
}

/**
 * Generates a unique invite code that does not collide with existing groups.
 * @param {Object} params Params.
 * @param {FirebaseFirestore.Firestore} params.db Firestore instance.
 * @param {number} params.length Invite code length.
 * @param {number} params.maxAttempts Maximum retry attempts.
 * @return {Promise<string>} A unique invite code.
 */
async function generateUniqueInviteCode(params: {
  db: FirebaseFirestore.Firestore;
  length: number;
  maxAttempts: number;
}): Promise<string> {
  const {db, length, maxAttempts} = params;
  const groups = getEnvironmentCollection("groups", db);

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
function randomInviteCode(length: number): string {
  const characters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
  let code = "";
  for (let i = 0; i < length; i++) {
    code += characters.charAt(Math.floor(Math.random() * characters.length));
  }
  return code;
}
