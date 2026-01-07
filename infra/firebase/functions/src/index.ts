import * as admin from "firebase-admin";
import {FieldValue} from "firebase-admin/firestore";
import {setGlobalOptions} from "firebase-functions/v2";
import {HttpsError, onCall} from "firebase-functions/v2/https";
import {
  CreateGroupRequest,
  CreateGroupResponse,
  CreatePromiseRequest,
  CreatePromiseResponse,
  CreateUserRequest,
  CreateUserResponse,
  DeleteGroupRequest,
  DeleteGroupResponse,
  GetUserRequest,
  GetUserSettingsResponse,
  GroupMemberPreview,
  JoinGroupRequest,
  JoinGroupResponse,
  LeaveGroupRequest,
  LeaveGroupResponse,
  RespondPromiseRequest,
  RespondPromiseResponse,
  PreviewGroupRequest,
  PreviewGroupResponse,
  UpdateUserRequest,
  UpdateUserResponse,
  UpdateUserSettingsRequest,
  UpdateUserSettingsResponse,
  UploadProfileImageRequest,
  UploadProfileImageResponse,
  UserPrivateResponse,
  UserPublicResponse,
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
// User Functions
// ============================================================================

/**
 * 사용자 생성 (회원가입)
 *
 * @remarks
 * **인증 필수**
 *
 * Firebase Auth 가입 후 Firestore에 사용자 정보를 생성합니다.
 * - 메인 문서 (users/{userId}): name, nickname, metaData
 * - auth 서브컬렉션: provider 정보 (email 포함)
 * - settings 서브컬렉션: 기본 설정
 *
 * @param request.data - CreateUserRequest
 * @returns CreateUserResponse
 *
 * @throws HttpsError
 * - unauthenticated: 로그인이 필요합니다
 * - invalid-argument: 잘못된 파라미터
 * - already-exists: 이미 존재하는 사용자
 * - internal: 서버 오류
 */
export const createUser = onCall<CreateUserRequest>(
  {region: REGION},
  async (request): Promise<CreateUserResponse> => {
    // 1. 인증 확인
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "로그인이 필요합니다");
    }

    const userId = request.auth.uid;
    const data = request.data;

    // 2. 유효성 검사
    const nickname = data.nickname.trim();
    if (nickname.length < 2 || nickname.length > 12) {
      throw new HttpsError(
        "invalid-argument",
        "닉네임은 2~12자여야 합니다",
      );
    }

    // name이 없으면 nickname으로 대체
    const name = data.name?.trim() || nickname;

    if (
      !data.provider ||
      !data.provider.type ||
      !data.provider.uid ||
      !data.provider.email
    ) {
      throw new HttpsError(
        "invalid-argument",
        "인증 제공자 정보는 필수입니다",
      );
    }

    const db = admin.firestore();
    const usersCollection = getEnvironmentCollection("users", db, data.env);
    const userRef = usersCollection.doc(userId);

    // 3. 이미 존재하는 사용자인지 확인
    const existingUser = await userRef.get();
    if (existingUser.exists) {
      throw new HttpsError(
        "already-exists",
        "이미 존재하는 사용자입니다",
      );
    }

    const now = FieldValue.serverTimestamp();

    try {
      // 4. Firestore에 저장
      await db.runTransaction(async (transaction) => {
        // 4-1. 메인 문서 생성 (email 제외, profile 필드는 null로 초기화)
        transaction.set(userRef, {
          name: name,
          nickname: nickname,
          profile: null,
          metaData: {
            createdAt: now,
            updatedAt: now,
          },
        });

        // 4-2. auth 서브컬렉션 생성 (provider 정보 및 email 포함)
        transaction.set(userRef.collection("auth").doc("main"), {
          provider: {
            type: data.provider.type,
            uid: data.provider.uid,
            email: data.provider.email,
          },
        });

        // 4-3. settings 서브컬렉션 생성 (기본값)
        transaction.set(userRef.collection("settings").doc("main"), {
          notificationEnabled: true,
        });
      });

      // 5. 응답 반환
      return {
        userId: userId,
        createdAt: admin.firestore.Timestamp.now(),
      };
    } catch (error) {
      console.error("❌ createUser error:", error);
      throw new HttpsError(
        "internal",
        "사용자 생성 중 오류가 발생했습니다",
      );
    }
  },
);

/**
 * 사용자 정보 조회
 *
 * @remarks
 * **인증 필수**
 *
 * 특정 사용자의 정보를 조회합니다.
 * - isPublic=false: UserPrivateResponse (email, provider 포함, auth 서브컬렉션 읽기)
 * - isPublic=true: UserPublicResponse (email, provider 제외, auth 서브컬렉션 읽기 생략)
 *
 * @param request.data - GetUserRequest
 * @returns UserPrivateResponse | UserPublicResponse
 *
 * @throws HttpsError
 * - unauthenticated: 로그인이 필요합니다
 * - not-found: 사용자를 찾을 수 없습니다
 */
export const getUser = onCall<GetUserRequest>(
  {region: REGION},
  async (request): Promise<UserPrivateResponse | UserPublicResponse> => {
    // 1. 인증 확인
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "로그인이 필요합니다");
    }

    const requesterId = request.auth.uid;
    const data = request.data || {};
    const targetUserId = data.userId || requesterId;
    const isPublic = data.isPublic ?? false;

    const db = admin.firestore();
    const usersCollection = getEnvironmentCollection("users", db, data.env);
    const userRef = usersCollection.doc(targetUserId);

    // 2. 메인 문서 조회
    const userDoc = await userRef.get();
    if (!userDoc.exists) {
      throw new HttpsError(
        "not-found",
        "사용자를 찾을 수 없습니다",
      );
    }

    const userData = userDoc.data();
    if (!userData) {
      throw new HttpsError(
        "internal",
        "사용자 데이터를 읽을 수 없습니다",
      );
    }

    // 3. 공통 응답 구성
    const baseResponse: UserPublicResponse = {
      userId: targetUserId,
      name: userData.name as string,
      nickname: userData.nickname as string,
      profile: userData.profile ? {
        url: userData.profile.url,
        thumbUrl: userData.profile.thumbUrl ?? null,
        updatedAt: userData.profile.updatedAt,
      } : null,
      metaData: {
        createdAt: userData.metaData.createdAt,
        updatedAt: userData.metaData.updatedAt,
      },
      groups: userData.groups ?? null,
    };

    // 4. Private 정보 조회 시 auth 서브컬렉션에서 email, provider 추가
    if (!isPublic) {
      const authDoc = await userRef.collection("auth").doc("main").get();
      const authData = authDoc.data();

      if (!authData || !authData.provider) {
        throw new HttpsError(
          "internal",
          "인증 정보를 찾을 수 없습니다",
        );
      }

      const privateResponse: UserPrivateResponse = {
        ...baseResponse,
        email: authData.provider.email as string,
        provider: authData.provider.type as string,
      };

      return privateResponse;
    }

    // 5. Public 정보만 반환
    return baseResponse;
  },
);

/**
 * 사용자 정보 수정
 *
 * @remarks
 * **인증 필수**
 *
 * 사용자의 기본 정보를 수정합니다.
 * - name, email은 수정 불가 (provider 정보이므로)
 *
 * @param request.data - UpdateUserRequest
 * @returns UpdateUserResponse
 *
 * @throws HttpsError
 * - unauthenticated: 로그인이 필요합니다
 * - invalid-argument: 잘못된 파라미터
 */
export const updateUser = onCall<UpdateUserRequest>(
  {region: REGION},
  async (request): Promise<UpdateUserResponse> => {
    // 1. 인증 확인
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "로그인이 필요합니다");
    }

    const userId = request.auth.uid;
    const data = request.data;

    // 2. 유효성 검사
    if (data.nickname) {
      const nickname = data.nickname.trim();
      if (nickname.length < 2 || nickname.length > 12) {
        throw new HttpsError(
          "invalid-argument",
          "닉네임은 2~12자여야 합니다",
        );
      }
    }

    const db = admin.firestore();
    const usersCollection = getEnvironmentCollection("users", db, data.env);
    const userRef = usersCollection.doc(userId);

    const now = FieldValue.serverTimestamp();
    const updateData: Record<string, unknown> = {
      "metaData.updatedAt": now,
    };

    // 3. 업데이트할 필드 추가
    if (data.nickname) {
      updateData.nickname = data.nickname.trim();
    }

    // 4. Firestore 업데이트
    await userRef.update(updateData);

    // 5. 응답 반환
    return {
      success: true,
      updatedAt: admin.firestore.Timestamp.now(),
    };
  },
);

/**
 * 프로필 이미지 업로드
 *
 * @remarks
 * **인증 필수**
 *
 * 프로필 이미지를 업로드하고 Firestore에 정보를 저장합니다.
 * - iOS에서 먼저 Storage에 업로드 후 경로를 전달
 * - 썸네일은 Cloud Function에서 비동기로 자동 생성
 *
 * @param request.data - UploadProfileImageRequest
 * @returns UploadProfileImageResponse
 *
 * @throws HttpsError
 * - unauthenticated: 로그인이 필요합니다
 * - invalid-argument: 잘못된 파라미터
 * - internal: 서버 오류
 */
export const uploadProfileImage = onCall<UploadProfileImageRequest>(
  {region: REGION},
  async (request): Promise<UploadProfileImageResponse> => {
    // 1. 인증 확인
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "로그인이 필요합니다");
    }

    const userId = request.auth.uid;
    const data = request.data;

    // 2. 유효성 검사
    if (!data.imagePath || data.imagePath.trim().length === 0) {
      throw new HttpsError(
        "invalid-argument",
        "이미지 경로는 필수입니다",
      );
    }

    try {
      console.log("📸 uploadProfileImage started", {
        userId,
        imagePath: data.imagePath,
        env: data.env,
      });

      // 3. Storage에서 downloadURL 생성
      const url = await generateDownloadURL(data.imagePath);

      console.log("✅ Download URL generated:", url);

      const now = FieldValue.serverTimestamp();
      const profileData = {
        url: url,
        updatedAt: now,
      };

      // 4. Firestore 업데이트
      const db = admin.firestore();
      const usersCollection = getEnvironmentCollection("users", db, data.env);
      const userRef = usersCollection.doc(userId);

      console.log("📝 Updating Firestore profile field...");

      await userRef.update({
        "profile": profileData,
        "metaData.updatedAt": now,
      });

      console.log("✅ Firestore profile updated successfully");

      // 5. 응답 반환 (thumbUrl은 Cloud Function이 비동기로 생성)
      return {
        profile: {
          url: url,
          thumbUrl: null,
          updatedAt: admin.firestore.Timestamp.now(),
        },
      };
    } catch (error) {
      console.error("❌ uploadProfileImage error:", error);
      throw new HttpsError(
        "internal",
        "프로필 이미지 업로드 중 오류가 발생했습니다",
      );
    }
  },
);

/**
 * 사용자 설정 조회
 *
 * @remarks
 * **인증 필수**
 *
 * 사용자의 설정 정보를 조회합니다.
 *
 * @param request.data - { env?: "stage" | "prod" }
 * @returns GetUserSettingsResponse
 *
 * @throws HttpsError
 * - unauthenticated: 로그인이 필요합니다
 * - not-found: 설정을 찾을 수 없습니다
 */
export const getUserSettings = onCall(
  {region: REGION},
  async (request): Promise<GetUserSettingsResponse> => {
    // 1. 인증 확인
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "로그인이 필요합니다");
    }

    const userId = request.auth.uid;
    const data = request.data || {};

    const db = admin.firestore();
    const usersCollection = getEnvironmentCollection("users", db, data.env);
    const settingsRef = usersCollection
      .doc(userId)
      .collection("settings")
      .doc("main");

    // 2. 설정 조회
    const settingsDoc = await settingsRef.get();
    if (!settingsDoc.exists) {
      throw new HttpsError(
        "not-found",
        "설정을 찾을 수 없습니다",
      );
    }

    const settingsData = settingsDoc.data();
    if (!settingsData) {
      throw new HttpsError(
        "internal",
        "설정 데이터를 읽을 수 없습니다",
      );
    }

    // 3. 응답 반환
    return {
      notificationEnabled: settingsData.notificationEnabled ?? true,
    };
  },
);

/**
 * 사용자 설정 수정
 *
 * @remarks
 * **인증 필수**
 *
 * 사용자의 설정을 수정합니다.
 *
 * @param request.data - UpdateUserSettingsRequest
 * @returns UpdateUserSettingsResponse
 *
 * @throws HttpsError
 * - unauthenticated: 로그인이 필요합니다
 */
export const updateUserSettings = onCall<UpdateUserSettingsRequest>(
  {region: REGION},
  async (request): Promise<UpdateUserSettingsResponse> => {
    // 1. 인증 확인
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "로그인이 필요합니다");
    }

    const userId = request.auth.uid;
    const data = request.data;

    const db = admin.firestore();
    const usersCollection = getEnvironmentCollection("users", db, data.env);
    const settingsRef = usersCollection
      .doc(userId)
      .collection("settings")
      .doc("main");

    const updateData: Record<string, unknown> = {};

    // 2. 업데이트할 필드 추가
    if (
      data.notificationEnabled !== undefined &&
      data.notificationEnabled !== null
    ) {
      updateData.notificationEnabled = data.notificationEnabled;
    }

    // 3. Firestore 업데이트
    if (Object.keys(updateData).length > 0) {
      await settingsRef.update(updateData);
    }

    // 4. 응답 반환
    return {
      success: true,
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
 *   "imageUrl": "https://firebasestorage.googleapis.com/..."
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
    const usersCollection = getEnvironmentCollection("users", db, data.env);

    // 4-1. 초대 코드 생성
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

    // 5-1. 그룹 기본 정보 생성 (memberIds 포함)
    await groupRef.set({
      name: data.name,
      description: data.description ?? null,
      imageUrl: data.imageUrl ?? null,
      memberIds: [creatorId],
      activePromiseCount: 0,
      maxMembers: data.maxMembers,
      inviteCode,
      createdBy: creatorId,
      createdAt: now,
      updatedAt: now,
      isDeleted: false,
    });

    // 5-2. 사용자의 그룹 목록에 추가 (Map 방식)
    await usersCollection
      .doc(creatorId)
      .set({
        groups: {
          [groupRef.id]: {
            groupName: data.name,
            role: "admin",
            joinedAt: now,
            notifications: true,
          },
        },
      }, {merge: true});

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
    const groupData = groupDoc.data();
    const memberIds = (groupData.memberIds as string[]) ?? [];

    // 3. 멤버 프로필 정보 조회 (memberIds에서 최대 10명)
    const usersCollection = getEnvironmentCollection(
      "users",
      db,
      data.env,
    );

    const members: GroupMemberPreview[] = [];
    const memberIdsToFetch = memberIds.slice(0, 10);

    for (const userId of memberIdsToFetch) {
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

    // 4. 그룹 ID와 멤버 리스트 반환
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
    const maxMembers = groupData.maxMembers as number | undefined;
    const memberIds = (groupData.memberIds as string[]) ?? [];

    // 3-2. 이미 참여한 멤버인지 확인
    if (memberIds.includes(userId)) {
      throw new HttpsError(
        "already-exists",
        "이미 참여한 그룹입니다",
      );
    }

    // 3-3. 정원 확인
    if (maxMembers && memberIds.length >= maxMembers) {
      throw new HttpsError(
        "resource-exhausted",
        "그룹 정원이 초과되었습니다",
      );
    }

    const now = FieldValue.serverTimestamp();
    const usersCollection = getEnvironmentCollection("users", db, data.env);

    // 4. Firestore에 저장 (트랜잭션 사용)
    await db.runTransaction(async (transaction) => {
      // 4-1. 그룹의 memberIds에 추가
      transaction.update(groupDoc.ref, {
        memberIds: FieldValue.arrayUnion(userId),
        updatedAt: now,
      });

      // 4-2. 사용자의 그룹 목록에 추가 (Map 방식)
      const userRef = usersCollection.doc(userId);
      transaction.set(userRef, {
        groups: {
          [groupId]: {
            groupName: groupName,
            role: "member",
            joinedAt: now,
            notifications: true,
          },
        },
      }, {merge: true});
    });

    // 5. 응답 반환
    return {
      groupId: groupId,
      groupName: groupName,
    };
  },
);

/**
 * 그룹 나가기
 *
 * @remarks
 * **인증 필수**
 *
 * 사용자가 그룹에서 나갑니다:
 * 1. groups/{groupId}의 memberIds에서 사용자 제거
 * 2. users/{userId}의 groups Map에서 해당 그룹 삭제
 * 3. 호스트(admin)는 나갈 수 없음
 *
 * @param request.data - LeaveGroupRequest
 * @returns LeaveGroupResponse
 *
 * @throws HttpsError
 * - unauthenticated: 로그인이 필요합니다
 * - invalid-argument: 잘못된 파라미터
 * - permission-denied: 호스트는 나갈 수 없습니다
 * - not-found: 그룹을 찾을 수 없습니다
 * - internal: 서버 오류
 */
export const leaveGroup = onCall<LeaveGroupRequest>(
  {region: REGION},
  async (request): Promise<LeaveGroupResponse> => {
    // 1. 인증 확인
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "로그인이 필요합니다");
    }

    // 2. 데이터 추출 및 검증
    const data = request.data;
    const groupId = data.groupId?.trim();
    const userId = request.auth.uid;

    if (!groupId) {
      throw new HttpsError(
        "invalid-argument",
        "그룹 ID는 필수입니다",
      );
    }

    if (data.env && data.env !== "stage" && data.env !== "prod") {
      throw new HttpsError(
        "invalid-argument",
        "env는 stage 또는 prod만 허용됩니다",
      );
    }

    // 3. 비즈니스 로직
    const db = admin.firestore();
    const groupsCollection = getEnvironmentCollection("groups", db, data.env);
    const usersCollection = getEnvironmentCollection("users", db, data.env);

    // 3-1. 그룹 존재 확인
    const groupRef = groupsCollection.doc(groupId);
    const groupDoc = await groupRef.get();

    if (!groupDoc.exists) {
      throw new HttpsError(
        "not-found",
        "그룹을 찾을 수 없습니다",
      );
    }

    const groupData = groupDoc.data();
    if (!groupData) {
      throw new HttpsError(
        "not-found",
        "그룹 데이터를 찾을 수 없습니다",
      );
    }

    const createdBy = groupData.createdBy as string;
    const memberIds = (groupData.memberIds as string[]) ?? [];

    // 3-2. 멤버인지 확인
    if (!memberIds.includes(userId)) {
      throw new HttpsError(
        "permission-denied",
        "그룹 멤버가 아닙니다",
      );
    }

    // 3-3. 호스트인지 확인 (호스트는 나갈 수 없음)
    if (createdBy === userId) {
      throw new HttpsError(
        "permission-denied",
        "그룹 호스트는 나갈 수 없습니다. 그룹을 삭제하거나 다른 멤버에게 호스트를 이전하세요.",
      );
    }

    const now = FieldValue.serverTimestamp();

    // 4. Firestore에서 제거 (트랜잭션 사용)
    await db.runTransaction(async (transaction) => {
      // 4-1. 그룹의 memberIds에서 제거
      transaction.update(groupRef, {
        memberIds: FieldValue.arrayRemove(userId),
        updatedAt: now,
      });

      // 4-2. 사용자의 그룹 목록에서 삭제
      const userRef = usersCollection.doc(userId);
      transaction.update(userRef, {
        [`groups.${groupId}`]: FieldValue.delete(),
        updatedAt: now,
      });
    });

    // 5. 응답 반환
    return {
      success: true,
    };
  },
);

/**
 * 그룹 삭제
 *
 * @remarks
 * **인증 필수**
 *
 * 호스트(admin)가 그룹을 삭제합니다:
 * 1. 호스트 권한 확인
 * 2. groups/{groupId}를 soft delete (isDeleted: true)
 * 3. 모든 멤버의 users/{userId}/groups Map에서 해당 그룹 삭제
 *
 * @param request.data - DeleteGroupRequest
 * @returns DeleteGroupResponse
 *
 * @throws HttpsError
 * - unauthenticated: 로그인이 필요합니다
 * - invalid-argument: 잘못된 파라미터
 * - permission-denied: 호스트만 삭제할 수 있습니다
 * - not-found: 그룹을 찾을 수 없습니다
 * - internal: 서버 오류
 */
export const deleteGroup = onCall<DeleteGroupRequest>(
  {region: REGION},
  async (request): Promise<DeleteGroupResponse> => {
    // 1. 인증 확인
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "로그인이 필요합니다");
    }

    // 2. 데이터 추출 및 검증
    const data = request.data;
    const groupId = data.groupId?.trim();
    const userId = request.auth.uid;

    if (!groupId) {
      throw new HttpsError(
        "invalid-argument",
        "그룹 ID는 필수입니다",
      );
    }

    if (data.env && data.env !== "stage" && data.env !== "prod") {
      throw new HttpsError(
        "invalid-argument",
        "env는 stage 또는 prod만 허용됩니다",
      );
    }

    // 3. 비즈니스 로직
    const db = admin.firestore();
    const groupsCollection = getEnvironmentCollection("groups", db, data.env);
    const usersCollection = getEnvironmentCollection("users", db, data.env);

    // 3-1. 그룹 존재 및 권한 확인
    const groupRef = groupsCollection.doc(groupId);
    const groupDoc = await groupRef.get();

    if (!groupDoc.exists) {
      throw new HttpsError(
        "not-found",
        "그룹을 찾을 수 없습니다",
      );
    }

    const groupData = groupDoc.data();
    if (!groupData) {
      throw new HttpsError(
        "not-found",
        "그룹 데이터를 찾을 수 없습니다",
      );
    }

    const createdBy = groupData.createdBy as string;
    const memberIds = (groupData.memberIds as string[]) ?? [];

    // 3-2. 호스트인지 확인
    if (createdBy !== userId) {
      throw new HttpsError(
        "permission-denied",
        "그룹 호스트만 삭제할 수 있습니다",
      );
    }

    const now = FieldValue.serverTimestamp();

    // 4. Firestore에서 삭제 (트랜잭션 사용)
    await db.runTransaction(async (transaction) => {
      // 4-1. 그룹 soft delete
      transaction.update(groupRef, {
        isDeleted: true,
        deletedAt: now,
        updatedAt: now,
      });

      // 4-2. 모든 멤버의 그룹 목록에서 삭제
      for (const memberId of memberIds) {
        const userRef = usersCollection.doc(memberId);
        transaction.update(userRef, {
          [`groups.${groupId}`]: FieldValue.delete(),
          updatedAt: now,
        });
      }
    });

    // 5. 응답 반환
    return {
      success: true,
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
 * Storage 경로에서 downloadURL 생성
 *
 * @param {string} storagePath - Storage 파일 경로
 * @return {Promise<string>} Download URL
 */
async function generateDownloadURL(storagePath: string): Promise<string> {
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
 * **votes Map 방식**:
 * - votes.accepted: 참여 확정 userId 배열
 * - votes.declined: 참여 불가 userId 배열
 * - votes.until: 투표 마감 시각 (기본값: startAt)
 * - pending: memberIds - accepted - declined (계산)
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

    // 2. 데이터 검증
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

    // 3. 그룹 존재 확인
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

    // 4. 멤버십 확인 (memberIds 배열 사용)
    const memberIds = (groupData.memberIds as string[]) ?? [];
    if (!memberIds.includes(userId)) {
      throw new HttpsError(
        "permission-denied",
        "그룹 멤버만 약속을 생성할 수 있습니다",
      );
    }

    // 5. 시작/종료 시간 파싱
    const startAtDate = new Date(data.startAt);
    const startAtTimestamp = admin.firestore.Timestamp.fromDate(startAtDate);
    const endAtDate = data.endAt ? new Date(data.endAt) : null;

    // 6. 약속 문서 생성
    const promiseRef = promisesCollection.doc();
    const promiseId = promiseRef.id;

    const promiseData = {
      title: data.title,
      emoji: data.emoji || null,
      description: data.description || null,
      hostId: userId,
      groupId: data.groupId,
      minimumParticipants: data.minimumParticipants,
      votes: {
        accepted: [userId], // 호스트는 자동 accepted
        declined: [],
        until: startAtTimestamp, // 기본값: startAt
      },
      startAt: startAtTimestamp,
      endAt: endAtDate ? admin.firestore.Timestamp.fromDate(endAtDate) : null,
      location: data.place ? {name: data.place} : null,
      status: "pending",
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
      isDeleted: false,
    };

    const batch = db.batch();
    batch.set(promiseRef, promiseData);

    // 7. 그룹의 activePromiseCount 증가
    batch.update(groupsCollection.doc(data.groupId), {
      activePromiseCount: FieldValue.increment(1),
      updatedAt: FieldValue.serverTimestamp(),
    });

    await batch.commit();

    // 8. 응답 반환
    return {
      promiseId: promiseId,
      title: data.title,
      groupId: data.groupId,
      startAt: startAtTimestamp,
    };
  },
);

/**
 * 약속 응답
 *
 * @remarks
 * **인증 필수**
 *
 * 약속 참석자 응답을 수락/거절로 업데이트합니다.
 * iOS GroupMain Feature와 연동됩니다.
 *
 * **votes Map 방식**:
 * - votes.accepted / votes.declined 배열을 arrayUnion/arrayRemove로 업데이트
 * - Set-like 동작: 중복 자동 방지
 *
 * @param request.data - RespondPromiseRequest
 * @returns RespondPromiseResponse
 *
 * @throws HttpsError
 * - unauthenticated: 로그인이 필요합니다
 * - invalid-argument: 잘못된 요청 데이터
 * - not-found: 약속을 찾을 수 없습니다
 * - permission-denied: 그룹 멤버가 아닙니다
 * - internal: 서버 오류
 */
export const respondPromise = onCall<RespondPromiseRequest>(
  {region: REGION},
  async (request): Promise<RespondPromiseResponse> => {
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "로그인이 필요합니다",
      );
    }

    const userId = request.auth.uid;
    const data = request.data;
    const status = data.status?.trim();

    if (!data.promiseId || !status) {
      throw new HttpsError(
        "invalid-argument",
        "약속 ID와 응답 상태는 필수입니다",
      );
    }

    if (!["accepted", "declined", "pending"].includes(status)) {
      throw new HttpsError(
        "invalid-argument",
        "status는 accepted/declined/pending 중 하나여야 합니다",
      );
    }

    if (data.env && data.env !== "stage" && data.env !== "prod") {
      throw new HttpsError(
        "invalid-argument",
        "env는 stage 또는 prod만 허용됩니다",
      );
    }

    const db = admin.firestore();
    const promisesCollection = getEnvironmentCollection(
      "promises",
      db,
      data.env,
    );
    const groupsCollection = getEnvironmentCollection(
      "groups",
      db,
      data.env,
    );

    const promiseRef = promisesCollection.doc(data.promiseId);

    await db.runTransaction(async (transaction) => {
      // 1. 약속 조회
      const promiseSnapshot = await transaction.get(promiseRef);
      if (!promiseSnapshot.exists) {
        throw new HttpsError(
          "not-found",
          "약속을 찾을 수 없습니다",
        );
      }

      const promiseData = promiseSnapshot.data();
      if (!promiseData) {
        throw new HttpsError(
          "internal",
          "약속 데이터를 가져올 수 없습니다",
        );
      }

      // 2. 그룹 조회 및 멤버십 확인
      const groupId = promiseData.groupId as string;
      const groupDoc = await transaction.get(groupsCollection.doc(groupId));

      if (!groupDoc.exists) {
        throw new HttpsError(
          "not-found",
          "그룹을 찾을 수 없습니다",
        );
      }

      const groupData = groupDoc.data();
      const memberIds = (groupData?.memberIds as string[]) ?? [];

      if (!memberIds.includes(userId)) {
        throw new HttpsError(
          "permission-denied",
          "그룹 멤버만 응답할 수 있습니다",
        );
      }

      // 3. 현재 투표 상태 확인
      const votes = promiseData.votes || {accepted: [], declined: []};
      const acceptedList = (votes.accepted as string[]) ?? [];
      const declinedList = (votes.declined as string[]) ?? [];

      const isInAccepted = acceptedList.includes(userId);
      const isInDeclined = declinedList.includes(userId);

      // 이미 같은 상태면 스킵
      if (
        (status === "accepted" && isInAccepted) ||
        (status === "declined" && isInDeclined) ||
        (status === "pending" && !isInAccepted && !isInDeclined)
      ) {
        return;
      }

      // 4. votes 배열 업데이트 (Set-like 동작)
      // 먼저 기존 상태에서 제거
      const updateData: Record<string, unknown> = {
        updatedAt: FieldValue.serverTimestamp(),
      };

      if (isInAccepted) {
        updateData["votes.accepted"] = FieldValue.arrayRemove(userId);
      }
      if (isInDeclined) {
        updateData["votes.declined"] = FieldValue.arrayRemove(userId);
      }

      // 새 상태로 추가 (pending이면 제거만 하고 추가 안함)
      if (status === "accepted") {
        updateData["votes.accepted"] = FieldValue.arrayUnion(userId);
      } else if (status === "declined") {
        updateData["votes.declined"] = FieldValue.arrayUnion(userId);
      }
      // status === "pending"이면 제거만 하고 아무 배열에도 추가하지 않음

      // 5. 확정 여부 계산 (새 상태 기준)
      let newAcceptedCount = acceptedList.length;
      if (isInAccepted && (status === "declined" || status === "pending")) {
        newAcceptedCount -= 1;
      } else if (!isInAccepted && status === "accepted") {
        newAcceptedCount += 1;
      }

      const minimumParticipants =
        (promiseData.minimumParticipants as number) ?? 2;
      const isConfirmed = newAcceptedCount >= minimumParticipants;
      updateData["status"] = isConfirmed ? "active" : "pending";

      transaction.update(promiseRef, updateData);
    });

    return {
      promiseId: data.promiseId,
      status: status as "accepted" | "declined" | "pending",
    };
  },
);
