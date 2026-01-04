import * as admin from "firebase-admin";
import {FieldValue} from "firebase-admin/firestore";
import {setGlobalOptions} from "firebase-functions/v2";
import {HttpsError, onCall, onRequest} from "firebase-functions/v2/https";
import {
  CreateGroupRequest,
  CreateGroupResponse,
  CreatePromiseRequest,
  CreatePromiseResponse,
  GroupMemberPreview,
  JoinGroupRequest,
  JoinGroupResponse,
  PreviewGroupRequest,
  PreviewGroupResponse,
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
    const requestedGroupId = data.groupId.trim();
    const groupRef = groupsCollection.doc(requestedGroupId);

    const existingGroup = await groupRef.get();
    if (existingGroup.exists) {
      throw new HttpsError(
        "already-exists",
        "이미 존재하는 그룹 ID입니다.",
      );
    }
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

/**
 * 그룹 미리보기
 *
 * @remarks
 * **인증 불필요**
 *
 * 초대 코드를 사용하여 그룹 정보를 미리 볼 수 있습니다.
 * 실제로 참여하지 않고 그룹 ID만 반환합니다.
 * iOS JoinGroup Feature에서 참여 전 확인용으로 사용됩니다.
 *
 * @param request.data - PreviewGroupRequest
 * @returns PreviewGroupResponse
 *
 * @throws HttpsError
 * - invalid-argument: 잘못된 초대 코드
 * - not-found: 그룹을 찾을 수 없습니다
 * - internal: 서버 오류
 *
 * @example
 * ```typescript
 * // iOS에서 호출
 * let data: [String: Any] = [
 *   "inviteCode": "ABC123"
 * ]
 * let result = try await functions.httpsCallable("previewGroup").call(data)
 * ```
 */
export const previewGroup = onCall<PreviewGroupRequest>(
  {region: REGION},
  async (request): Promise<PreviewGroupResponse> => {
    // 1. 데이터 추출 및 검증
    const data = request.data;
    const inviteCode = data.inviteCode?.trim().toUpperCase();

    if (!inviteCode || inviteCode.length !== 6) {
      throw new HttpsError(
        "invalid-argument",
        "초대 코드는 6자리여야 합니다",
      );
    }

    if (data.env && data.env !== "stage" && data.env !== "prod") {
      throw new HttpsError(
        "invalid-argument",
        "env는 stage 또는 prod만 허용됩니다",
      );
    }

    // 2. 초대 코드로 그룹 찾기
    const db = admin.firestore();
    const groupsCollection = getEnvironmentCollection("groups", db, data.env);
    const groupSnapshot = await groupsCollection
      .where("inviteCode", "==", inviteCode)
      .where("isDeleted", "==", false)
      .limit(1)
      .get();

    if (groupSnapshot.empty) {
      throw new HttpsError(
        "not-found",
        "초대 코드에 해당하는 그룹을 찾을 수 없습니다",
      );
    }

    const groupDoc = groupSnapshot.docs[0];
    const groupId = groupDoc.id;

    // 3. 멤버 리스트 조회 (최대 10명)
    const membersSnapshot = await groupDoc.ref
      .collection("members")
      .where("isActive", "==", true)
      .limit(10)
      .get();

    // 4. 각 멤버의 프로필 정보 조회
    const usersCollection = getEnvironmentCollection(
      "users",
      db,
      data.env,
    );

    const members: GroupMemberPreview[] = [];
    for (const memberDoc of membersSnapshot.docs) {
      const memberData = memberDoc.data();
      const userId = memberData.userId;
      if (!userId) {
        continue;
      }

      const userDoc = await usersCollection.doc(userId).get();
      if (userDoc.exists) {
        const userProfile = userDoc.data();
        const nickname = (userProfile?.nickname as string | undefined)?.trim();
        members.push({
          userId: userId,
          name: nickname && nickname.length > 0 ? nickname : "Unknown",
          profileImage: userProfile?.profile || null,
        });
      }
    }

    // 5. 그룹 ID와 멤버 리스트 반환
    return {
      groupId: groupId,
      members: members,
    };
  },
);

/**
 * 그룹 참여
 *
 * @remarks
 * **인증 필수**
 *
 * 초대 코드를 사용하여 기존 그룹에 참여합니다.
 * iOS JoinGroup Feature와 연동됩니다.
 *
 * @param request.data - JoinGroupRequest
 * @returns JoinGroupResponse
 *
 * @throws HttpsError
 * - unauthenticated: 로그인이 필요합니다
 * - invalid-argument: 잘못된 초대 코드
 * - not-found: 그룹을 찾을 수 없습니다
 * - already-exists: 이미 참여한 그룹입니다
 * - resource-exhausted: 그룹 정원이 초과되었습니다
 * - internal: 서버 오류
 *
 * @example
 * ```typescript
 * // iOS에서 호출
 * let data: [String: Any] = [
 *   "inviteCode": "ABC123"
 * ]
 * let result = try await functions.httpsCallable("joinGroup").call(data)
 * ```
 */
export const joinGroup = onCall<JoinGroupRequest>(
  {region: REGION},
  async (request): Promise<JoinGroupResponse> => {
    // 1. 인증 확인
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "로그인이 필요합니다");
    }

    // 2. 데이터 추출 및 검증
    const data = request.data;
    const inviteCode = data.inviteCode?.trim().toUpperCase();

    if (!inviteCode || inviteCode.length !== 6) {
      throw new HttpsError(
        "invalid-argument",
        "초대 코드는 6자리여야 합니다",
      );
    }

    if (data.env && data.env !== "stage" && data.env !== "prod") {
      throw new HttpsError(
        "invalid-argument",
        "env는 stage 또는 prod만 허용됩니다",
      );
    }

    // 3. 비즈니스 로직
    const userId = request.auth.uid;
    const db = admin.firestore();

    // 3-1. 초대 코드로 그룹 찾기
    const groupsCollection = getEnvironmentCollection("groups", db, data.env);
    const groupSnapshot = await groupsCollection
      .where("inviteCode", "==", inviteCode)
      .where("isDeleted", "==", false)
      .limit(1)
      .get();

    if (groupSnapshot.empty) {
      throw new HttpsError(
        "not-found",
        "초대 코드에 해당하는 그룹을 찾을 수 없습니다",
      );
    }

    const groupDoc = groupSnapshot.docs[0];
    const groupId = groupDoc.id;
    const groupData = groupDoc.data();
    const groupName = groupData.name as string;
    const memberCount = groupData.memberCount as number;
    const maxMembers = groupData.maxMembers as number | undefined;

    // 3-2. 이미 참여한 멤버인지 확인
    const memberDoc = await groupDoc.ref
      .collection("members")
      .doc(userId)
      .get();

    if (memberDoc.exists) {
      const memberData = memberDoc.data();
      if (memberData?.isActive) {
        throw new HttpsError(
          "already-exists",
          "이미 참여한 그룹입니다",
        );
      }
    }

    // 3-3. 정원 확인
    if (maxMembers && memberCount >= maxMembers) {
      throw new HttpsError(
        "resource-exhausted",
        "그룹 정원이 초과되었습니다",
      );
    }

    // 3-4. 사용자 정보 조회
    const usersCollection = getEnvironmentCollection("users", db, data.env);
    const userDoc = await usersCollection.doc(userId).get();

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

    const userName = userData.name as string;
    const userNickname = userData.nickname as string;
    const userProfileImageUrl = (userData.profile?.url as string) ?? null;

    const now = FieldValue.serverTimestamp();

    // 4. Firestore에 저장 (트랜잭션 사용)
    await db.runTransaction(async (transaction) => {
      // 4-1. 그룹 멤버에 추가
      const memberRef = groupDoc.ref.collection("members").doc(userId);
      transaction.set(memberRef, {
        userId: userId,
        userName: userName,
        userNickname: userNickname,
        profileImageUrl: userProfileImageUrl,
        role: "member",
        joinedAt: now,
        invitedBy: null,
        isActive: true,
        leftAt: null,
      });

      // 4-2. 사용자의 그룹 목록에 추가
      const userGroupRef = usersCollection
        .doc(userId)
        .collection("groups")
        .doc(groupId);
      transaction.set(userGroupRef, {
        groupId: groupId,
        groupName: groupName,
        role: "member",
        joinedAt: now,
        notifications: true,
      });

      // 4-3. memberCount 증가
      transaction.update(groupDoc.ref, {
        memberCount: FieldValue.increment(1),
        updatedAt: now,
      });
    });

    // 5. 응답 반환
    return {
      groupId: groupId,
      groupName: groupName,
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
  const groupId = data.groupId.trim();
  if (groupId.length == 0) {
    throw new HttpsError(
      "invalid-argument",
      "groupId는 비어있을 수 없습니다",
    );
  }

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

/**
 * 약속 생성
 *
 * @remarks
 * **인증 필수**
 *
 * 그룹에 새로운 약속을 생성합니다.
 * iOS CreatePromise Feature와 연동됩니다.
 *
 * @param request.data - CreatePromiseRequest
 * @returns CreatePromiseResponse
 *
 * @throws HttpsError
 * - unauthenticated: 로그인이 필요합니다
 * - invalid-argument: 잘못된 요청 데이터
 * - not-found: 그룹을 찾을 수 없습니다
 * - permission-denied: 그룹 멤버가 아닙니다
 * - internal: 서버 오류
 */
export const createPromise = onCall<CreatePromiseRequest>(
  {region: REGION},
  async (request): Promise<CreatePromiseResponse> => {
    // 1. 인증 확인
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "로그인이 필요합니다",
      );
    }

    const userId = request.auth.uid;
    const data = request.data;

    // 3. 데이터 검증
    if (
      !data.groupId ||
      !data.title ||
      !data.startAt ||
      !data.minimumParticipants
    ) {
      throw new HttpsError(
        "invalid-argument",
        "그룹 ID, 제목, 시작 시간, 최소 참가 인원은 필수입니다",
      );
    }

    if (data.minimumParticipants < 2) {
      throw new HttpsError(
        "invalid-argument",
        "최소 참가 인원은 2명 이상이어야 합니다",
      );
    }

    const db = admin.firestore();
    const groupsCollection = getEnvironmentCollection(
      "groups",
      db,
      data.env,
    );
    const promisesCollection = getEnvironmentCollection(
      "promises",
      db,
      data.env,
    );
    const usersCollection = getEnvironmentCollection("users", db, data.env);

    // 4. 그룹 존재 확인
    const groupDoc = await groupsCollection.doc(data.groupId).get();
    if (!groupDoc.exists) {
      throw new HttpsError(
        "not-found",
        "그룹을 찾을 수 없습니다",
      );
    }

    const groupData = groupDoc.data();
    if (!groupData) {
      throw new HttpsError(
        "internal",
        "그룹 데이터를 가져올 수 없습니다",
      );
    }

    // 5. 멤버십 확인
    const membershipQuery = await groupDoc.ref
      .collection("members")
      .where("userId", "==", userId)
      .where("isActive", "==", true)
      .limit(1)
      .get();

    if (membershipQuery.empty) {
      throw new HttpsError(
        "permission-denied",
        "그룹 멤버만 약속을 생성할 수 있습니다",
      );
    }

    // 6. 사용자 정보 조회 (호스트 이름 캐싱용)
    const userDoc = await usersCollection.doc(userId).get();
    const userData = userDoc.data();
    const hostName = userData?.nickname || "Unknown";

    // 7. 시작/종료 시간 파싱
    const startAtDate = new Date(data.startAt);
    const endAtDate = data.endAt ? new Date(data.endAt) : null;

    // 8. 날짜 인덱스 생성 (로컬 시간 기준)
    const year = startAtDate.getFullYear();
    const month = String(startAtDate.getMonth() + 1).padStart(2, "0");
    const day = String(startAtDate.getDate()).padStart(2, "0");
    const localYyyymm = `${year}${month}`;
    const localYyyymmdd = `${year}${month}${day}`;

    // 9. 약속 문서 생성
    const promiseRef = promisesCollection.doc();
    const promiseId = promiseRef.id;

    const promiseData = {
      emoji: data.emoji || null,
      title: data.title,
      description: data.description || null,
      minimumParticipants: data.minimumParticipants,
      requiredCount: data.minimumParticipants,
      isConfirmed: false,
      confirmedAt: null,
      hostId: userId,
      hostName: hostName,
      groupId: data.groupId,
      groupName: groupData.name,
      counts: {
        total: 0,
        accepted: 0,
        declined: 0,
        tentative: 0,
      },
      startAt: admin.firestore.Timestamp.fromDate(startAtDate),
      endAt: endAtDate ? admin.firestore.Timestamp.fromDate(endAtDate) : null,
      localYyyymm: localYyyymm,
      localYyyymmdd: localYyyymmdd,
      localTz: "Asia/Seoul",
      status: "draft",
      location: data.place ? {name: data.place} : null,
      titleLower: data.title.toLowerCase(),
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
      isDeleted: false,
    };

    await promiseRef.set(promiseData);

    // 10. 그룹의 activePromiseCount 증가
    await groupsCollection.doc(data.groupId).update({
      activePromiseCount: FieldValue.increment(1),
      updatedAt: FieldValue.serverTimestamp(),
    });

    // 11. 응답 반환
    return {
      promiseId: promiseId,
      title: data.title,
      groupId: data.groupId,
      startAt: admin.firestore.Timestamp.fromDate(startAtDate),
    };
  },
);
