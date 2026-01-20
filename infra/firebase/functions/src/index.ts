import * as admin from "firebase-admin";
import {FieldValue} from "firebase-admin/firestore";
import {getFunctions} from "firebase-admin/functions";
import {setGlobalOptions} from "firebase-functions/v2";
import {HttpsError, onCall} from "firebase-functions/v2/https";
import {onTaskDispatched} from "firebase-functions/v2/tasks";
import {defineSecret} from "firebase-functions/params";
import * as http2 from "http2";
import * as jwt from "jsonwebtoken";

// APNs 인증 시크릿 (Firebase Secret Manager)
const APNS_KEY_ID = defineSecret("APNS_KEY_ID");
const APNS_TEAM_ID = defineSecret("APNS_TEAM_ID");
const APNS_AUTH_KEY = defineSecret("APNS_AUTH_KEY");
import {
  onDocumentCreated,
  onDocumentUpdated,
} from "firebase-functions/v2/firestore";
import {
  CheckNicknameAvailableRequest,
  CheckNicknameAvailableResponse,
  CreateGroupRequest,
  CreateGroupResponse,
  CreatePromiseRequest,
  CreatePromiseResponse,
  CreateUserRequest,
  CreateUserResponse,
  DeleteGroupRequest,
  DeleteGroupResponse,
  DeviceInfo,
  EndLiveActivityRequest,
  EndLiveActivityResponse,
  GetUserRequest,
  GetUserSettingsResponse,
  GroupMemberPreview,
  JoinGroupRequest,
  JoinGroupResponse,
  LeaveGroupRequest,
  LeaveGroupResponse,
  LiveActivityParticipant,
  NotificationDocument,
  NotificationType,
  RegisterPushToStartTokenRequest,
  RegisterPushToStartTokenResponse,
  RespondPromiseRequest,
  ScheduledLiveActivityTaskPayload,
  RespondPromiseResponse,
  PreviewGroupRequest,
  PreviewGroupResponse,
  SendPushNotificationRequest,
  SendPushNotificationResponse,
  StartLiveActivityRequest,
  StartLiveActivityResponse,
  UpdateETARequest,
  UpdateETAResponse,
  UpdatePromiseRequest,
  UpdatePromiseResponse,
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
    if (nickname.length < 2 || nickname.length > 20) {
      throw new HttpsError(
        "invalid-argument",
        "닉네임은 2~20자여야 합니다",
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
      if (nickname.length < 2 || nickname.length > 20) {
        throw new HttpsError(
          "invalid-argument",
          "닉네임은 2~20자여야 합니다",
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

/**
 * 닉네임 중복 검사
 *
 * @remarks
 * **인증 필수**
 *
 * 닉네임이 이미 사용 중인지 확인합니다.
 * Firestore 보안 규칙에서 다른 사용자 문서에 직접 접근할 수 없으므로,
 * 이 Cloud Function을 통해 안전하게 닉네임 중복을 검사합니다.
 *
 * @param request.data - CheckNicknameAvailableRequest
 * @returns CheckNicknameAvailableResponse
 *
 * @throws HttpsError
 * - unauthenticated: 로그인이 필요합니다
 * - invalid-argument: 잘못된 닉네임 형식
 * - internal: 서버 오류
 */
export const checkNicknameAvailable = onCall<CheckNicknameAvailableRequest>(
  {region: REGION},
  async (request): Promise<CheckNicknameAvailableResponse> => {
    // 1. 인증 확인
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "로그인이 필요합니다");
    }

    const userId = request.auth.uid;
    const data = request.data;

    // 2. 유효성 검사
    const nickname = data.nickname?.trim();
    if (!nickname || nickname.length < 2 || nickname.length > 20) {
      throw new HttpsError(
        "invalid-argument",
        "닉네임은 2~20자여야 합니다",
      );
    }

    try {
      const db = admin.firestore();
      const usersCollection = getEnvironmentCollection("users", db, data.env);

      // 3. 닉네임으로 사용자 검색 (본인 제외)
      const snapshot = await usersCollection
        .where("nickname", "==", nickname)
        .limit(1)
        .get();

      // 4. 결과 확인
      let available = true;
      if (!snapshot.empty) {
        // 검색된 사용자가 본인인 경우는 사용 가능
        const foundUserId = snapshot.docs[0].id;
        available = foundUserId === userId;
      }

      return {
        available: available,
        nickname: nickname,
      };
    } catch (error) {
      console.error("❌ checkNicknameAvailable error:", error);
      throw new HttpsError(
        "internal",
        "닉네임 중복 검사 중 오류가 발생했습니다",
      );
    }
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

    const memberIdsToFetch = memberIds.slice(0, 10);

    // 병렬 조회로 응답 시간 개선
    const userDocs = await Promise.all(
      memberIdsToFetch.map((userId) => usersCollection.doc(userId).get())
    );

    const members: GroupMemberPreview[] = userDocs
      .filter((doc) => doc.exists)
      .map((doc) => {
        const userProfile = doc.data();
        const nickname = (userProfile?.nickname as string | undefined)?.trim();
        return {
          userId: doc.id,
          name: nickname && nickname.length > 0 ? nickname : "Unknown",
          profileImage: userProfile?.profile || null,
        };
      });

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
      trackingStartMinutesBefore: data.arrivalSharingTime || null,
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
      isDeleted: false,
    };

    await promiseRef.set(promiseData);

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

      transaction.update(promiseRef, updateData);
    });

    return {
      promiseId: data.promiseId,
      status: status as "accepted" | "declined" | "pending",
    };
  },
);

/**
 * 약속 수정
 *
 * @remarks
 * **인증 필수**
 *
 * 약속 정보를 수정합니다.
 * - 호스트만 수정 가능
 * - 시작 전 약속만 수정 가능
 *
 * @param request.data - UpdatePromiseRequest
 * @returns UpdatePromiseResponse
 *
 * @throws HttpsError
 * - unauthenticated: 로그인이 필요합니다
 * - invalid-argument: 잘못된 요청 데이터
 * - not-found: 약속을 찾을 수 없습니다
 * - permission-denied: 호스트만 수정할 수 있습니다
 * - failed-precondition: 이미 시작된 약속은 수정할 수 없습니다
 * - internal: 서버 오류
 */
export const updatePromise = onCall<UpdatePromiseRequest>(
  {region: REGION},
  async (request): Promise<UpdatePromiseResponse> => {
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
    if (!data.promiseId) {
      throw new HttpsError(
        "invalid-argument",
        "약속 ID는 필수입니다",
      );
    }

    if (data.env && data.env !== "stage" && data.env !== "prod") {
      throw new HttpsError(
        "invalid-argument",
        "env는 stage 또는 prod만 허용됩니다",
      );
    }

    // minimumParticipants 검증
    if (
      data.minimumParticipants !== undefined &&
      data.minimumParticipants !== null &&
      data.minimumParticipants < 2
    ) {
      throw new HttpsError(
        "invalid-argument",
        "최소 참가 인원은 2명 이상이어야 합니다",
      );
    }

    const db = admin.firestore();
    const promisesCollection = getEnvironmentCollection(
      "promises",
      db,
      data.env,
    );

    const promiseRef = promisesCollection.doc(data.promiseId);

    // 3. 약속 조회
    const promiseDoc = await promiseRef.get();
    if (!promiseDoc.exists) {
      throw new HttpsError(
        "not-found",
        "약속을 찾을 수 없습니다",
      );
    }

    const promiseData = promiseDoc.data();
    if (!promiseData) {
      throw new HttpsError(
        "internal",
        "약속 데이터를 가져올 수 없습니다",
      );
    }

    // 4. 호스트 권한 확인
    const hostId = promiseData.hostId as string;
    if (hostId !== userId) {
      throw new HttpsError(
        "permission-denied",
        "호스트만 약속을 수정할 수 있습니다",
      );
    }

    // 5. 시작 시간 확인 (시작 전 약속만 수정 가능)
    const startAt = promiseData.startAt as admin.firestore.Timestamp;
    const now = admin.firestore.Timestamp.now();
    if (startAt.toMillis() <= now.toMillis()) {
      throw new HttpsError(
        "failed-precondition",
        "이미 시작된 약속은 수정할 수 없습니다",
      );
    }

    // 6. 업데이트할 필드 구성
    const updateData: Record<string, unknown> = {
      updatedAt: FieldValue.serverTimestamp(),
    };

    if (data.title !== undefined && data.title !== null) {
      const title = data.title.trim();
      if (title.length === 0) {
        throw new HttpsError(
          "invalid-argument",
          "제목은 비어있을 수 없습니다",
        );
      }
      updateData.title = title;
    }

    if (data.emoji !== undefined) {
      updateData.emoji = data.emoji || null;
    }

    if (data.description !== undefined) {
      updateData.description = data.description || null;
    }

    if (data.startAt !== undefined && data.startAt !== null) {
      const newStartAt = new Date(data.startAt);
      const newStartAtTimestamp =
        admin.firestore.Timestamp.fromDate(newStartAt);

      // 새 시작 시간도 현재보다 미래여야 함
      if (newStartAtTimestamp.toMillis() <= now.toMillis()) {
        throw new HttpsError(
          "invalid-argument",
          "시작 시간은 현재보다 미래여야 합니다",
        );
      }

      updateData.startAt = newStartAtTimestamp;
      // votes.until도 함께 업데이트
      updateData["votes.until"] = newStartAtTimestamp;
    }

    if (data.endAt !== undefined) {
      if (data.endAt === null) {
        updateData.endAt = null;
      } else {
        const endAtDate = new Date(data.endAt);
        updateData.endAt = admin.firestore.Timestamp.fromDate(endAtDate);
      }
    }

    const hasMinParticipants =
      data.minimumParticipants !== undefined &&
      data.minimumParticipants !== null;
    if (hasMinParticipants) {
      updateData.minimumParticipants = data.minimumParticipants;
    }

    // trackingStartMinutesBefore (실시간 공유 시작 시간)
    if (data.trackingStartMinutesBefore !== undefined) {
      updateData.trackingStartMinutesBefore =
        data.trackingStartMinutesBefore || null;
    }

    // 7. Firestore 업데이트
    await promiseRef.update(updateData);

    // 8. 응답 반환
    return {
      success: true,
    };
  },
);

// ============================================================================
// Push Notification Functions
// ============================================================================

/**
 * 푸시 알림 전송 (Callable Function)
 *
 * @remarks
 * **인증 필수**
 *
 * 지정된 사용자들에게 푸시 알림을 전송합니다.
 * - 각 사용자의 devices Map에서 FCM 토큰을 조회
 * - FCM을 통해 멀티캐스트 전송
 * - notifications 컬렉션에 알림 기록 저장
 *
 * @param request.data - SendPushNotificationRequest
 * @returns SendPushNotificationResponse
 *
 * @throws HttpsError
 * - unauthenticated: 로그인이 필요합니다
 * - invalid-argument: 잘못된 요청 데이터
 * - internal: 서버 오류
 */
export const sendPushNotification = onCall<SendPushNotificationRequest>(
  {region: REGION},
  async (request): Promise<SendPushNotificationResponse> => {
    // 1. 인증 확인
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "로그인이 필요합니다");
    }

    const data = request.data;

    // 2. 유효성 검사
    if (!data.userIds || data.userIds.length === 0) {
      throw new HttpsError(
        "invalid-argument",
        "수신자 ID 배열은 필수입니다",
      );
    }

    if (!data.type || !data.title || !data.body) {
      throw new HttpsError(
        "invalid-argument",
        "알림 타입, 제목, 본문은 필수입니다",
      );
    }

    try {
      const result = await sendPushNotificationInternal({
        userIds: data.userIds,
        type: data.type,
        title: data.title,
        body: data.body,
        promiseId: data.promiseId ?? null,
        groupId: data.groupId ?? null,
        relatedUserId: data.relatedUserId ?? null,
        data: data.data ?? null,
        env: data.env ?? null,
      });

      return result;
    } catch (error) {
      console.error("❌ sendPushNotification error:", error);
      throw new HttpsError(
        "internal",
        "푸시 알림 전송 중 오류가 발생했습니다",
      );
    }
  },
);

/**
 * 푸시 알림 전송 내부 헬퍼 함수
 *
 * Firestore 트리거나 Callable Function에서 공통으로 사용됩니다.
 *
 * @param {Object} params - 알림 전송 파라미터
 * @param {string[]} params.userIds - 수신자 ID 배열
 * @param {NotificationType} params.type - 알림 타입
 * @param {string} params.title - 알림 제목
 * @param {string} params.body - 알림 본문
 * @param {string|null} params.promiseId - 관련 약속 ID
 * @param {string|null} params.groupId - 관련 그룹 ID
 * @param {string|null} params.relatedUserId - 관련 사용자 ID
 * @param {Object|null} params.data - 추가 데이터
 * @param {string|null} params.env - 환경 (stage/prod)
 * @return {Promise<SendPushNotificationResponse>} 전송 결과
 */
async function sendPushNotificationInternal(params: {
  userIds: string[];
  type: NotificationType;
  title: string;
  body: string;
  promiseId: string | null;
  groupId: string | null;
  relatedUserId: string | null;
  data: { [key: string]: string } | null;
  env: "stage" | "prod" | null;
}): Promise<SendPushNotificationResponse> {
  const {userIds, type, title, body, promiseId, groupId,
    relatedUserId, data, env} = params;

  const db = admin.firestore();
  const usersCollection = getEnvironmentCollection("users", db, env);
  const notificationsCollection = getEnvironmentCollection(
    "notifications",
    db,
    env,
  );

  // 1. 각 사용자의 FCM 토큰 수집
  const allTokens: string[] = [];
  const userTokenMap: Map<string, string[]> = new Map();

  for (const userId of userIds) {
    try {
      const userDoc = await usersCollection.doc(userId).get();
      if (!userDoc.exists) continue;

      const userData = userDoc.data();
      const devices = userData?.devices as { [key: string]: DeviceInfo } | null;

      if (!devices) continue;

      const tokens: string[] = [];
      for (const deviceId of Object.keys(devices)) {
        const device = devices[deviceId];
        if (device.fcmToken) {
          tokens.push(device.fcmToken);
          allTokens.push(device.fcmToken);
        }
      }

      if (tokens.length > 0) {
        userTokenMap.set(userId, tokens);
      }
    } catch (error) {
      console.error(`Failed to get tokens for user ${userId}:`, error);
    }
  }

  // 2. 토큰이 없으면 조기 반환
  if (allTokens.length === 0) {
    console.log("📭 No FCM tokens found for users:", userIds);
    return {
      success: true,
      successCount: 0,
      failureCount: userIds.length,
    };
  }

  // 3. FCM 멀티캐스트 전송
  const message: admin.messaging.MulticastMessage = {
    tokens: allTokens,
    notification: {
      title: title,
      body: body,
    },
    data: {
      type: type,
      ...(promiseId && {promiseId}),
      ...(groupId && {groupId}),
      ...(relatedUserId && {relatedUserId}),
      ...(data || {}),
    },
    apns: {
      payload: {
        aps: {
          sound: "default",
          // TODO: 읽지 않은 알림 수로 동적 계산 필요 (현재 하드코딩)
          badge: 1,
        },
      },
    },
  };

  let successCount = 0;
  let failureCount = 0;
  const deliveredTokens = new Set<string>();

  try {
    const response = await admin.messaging().sendEachForMulticast(message);
    successCount = response.successCount;
    failureCount = response.failureCount;

    console.log(`📤 FCM sent: ${successCount} success, ${failureCount} failed`);

    // 성공/실패 토큰 추적
    response.responses.forEach((resp, idx) => {
      if (resp.success) {
        deliveredTokens.add(allTokens[idx]);
      } else {
        console.error(`Token ${allTokens[idx]} failed:`, resp.error);
      }
    });
  } catch (error) {
    console.error("❌ FCM multicast error:", error);
    failureCount = allTokens.length;
  }

  // 유저별 전송 성공 여부 계산
  const userDeliveryStatus = new Map<string, boolean>();
  for (const [userId, tokens] of userTokenMap) {
    const delivered = tokens.some((token) => deliveredTokens.has(token));
    userDeliveryStatus.set(userId, delivered);
  }

  // 4. notifications 컬렉션에 알림 기록 저장
  const now = FieldValue.serverTimestamp();
  const batch = db.batch();

  for (const userId of userIds) {
    const isDelivered = userDeliveryStatus.get(userId) ?? false;
    const notificationDoc: Omit<NotificationDocument, "createdAt" |
      "readAt" | "deliveredAt"> & {
      createdAt: FirebaseFirestore.FieldValue;
      readAt: null;
      deliveredAt: FirebaseFirestore.FieldValue | null;
    } = {
      userId,
      type,
      title,
      body,
      promiseId,
      groupId,
      relatedUserId,
      isRead: false,
      isDelivered,
      createdAt: now,
      readAt: null,
      deliveredAt: isDelivered ? now : null,
      data: data,
    };

    const notificationRef = notificationsCollection.doc();
    batch.set(notificationRef, notificationDoc);
  }

  await batch.commit();

  return {
    success: true,
    successCount,
    failureCount,
  };
}

// ============================================================================
// Firestore Triggers for Push Notifications
// ============================================================================

/**
 * 약속 생성 시 그룹 멤버들에게 알림
 *
 * @remarks
 * promises/{promiseId} 문서가 생성되면 트리거됩니다.
 * - 호스트를 제외한 그룹 멤버들에게 알림 전송
 */
export const onPromiseCreated = onDocumentCreated(
  {
    document: "{env}/root/promises/{promiseId}",
    region: REGION,
  },
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) {
      console.log("No data associated with the event");
      return;
    }

    const promiseData = snapshot.data();
    const promiseId = event.params.promiseId;
    const env = event.params.env as "stage" | "prod";

    const groupId = promiseData.groupId as string;
    const hostId = promiseData.hostId as string;
    const title = promiseData.title as string;

    console.log(`📅 Promise created: ${promiseId} in group ${groupId}`);

    // 그룹 멤버 조회
    const db = admin.firestore();
    const groupsCollection = getEnvironmentCollection("groups", db, env);
    const groupDoc = await groupsCollection.doc(groupId).get();

    if (!groupDoc.exists) {
      console.error(`Group ${groupId} not found`);
      return;
    }

    const groupData = groupDoc.data();
    const memberIds = (groupData?.memberIds as string[]) ?? [];

    // 호스트 제외
    const recipientIds = memberIds.filter((id) => id !== hostId);

    if (recipientIds.length === 0) {
      console.log("No recipients to notify");
      return;
    }

    // 호스트 이름 조회
    const usersCollection = getEnvironmentCollection("users", db, env);
    const hostDoc = await usersCollection.doc(hostId).get();
    const hostName = hostDoc.data()?.nickname as string || "누군가";

    // 푸시 알림 전송
    await sendPushNotificationInternal({
      userIds: recipientIds,
      type: NotificationType.PromiseInvitation,
      title: "새 약속 도착 📩",
      body: `${hostName}님이 ${title}을 제안했어요. 확인해주세요!`,
      promiseId,
      groupId,
      relatedUserId: hostId,
      data: null,
      env,
    });
  },
);

/**
 * 약속 투표 변경 시 확정/미성사 알림
 *
 * @remarks
 * promises/{promiseId} 문서의 votes가 변경되면 트리거됩니다.
 * - 최소 인원 충족 시 → 약속 확정 알림 (그룹 전체)
 * - 최소 인원 충족 불가 시 → 약속 미성사 알림 (그룹 전체)
 */
export const onPromiseVotesUpdated = onDocumentUpdated(
  {
    document: "{env}/root/promises/{promiseId}",
    region: REGION,
  },
  async (event) => {
    const beforeData = event.data?.before.data();
    const afterData = event.data?.after.data();

    if (!beforeData || !afterData) {
      console.log("No data associated with the event");
      return;
    }

    const promiseId = event.params.promiseId;
    const env = event.params.env as "stage" | "prod";
    const groupId = afterData.groupId as string;
    const title = afterData.title as string;
    const minimumParticipants = afterData.minimumParticipants as number || 2;
    const startAt = afterData.startAt as admin.firestore.Timestamp;

    // votes 변경 확인
    const beforeVotes = beforeData.votes || {accepted: [], declined: []};
    const afterVotes = afterData.votes || {accepted: [], declined: []};

    const beforeAccepted = (beforeVotes.accepted as string[]) ?? [];
    const afterAccepted = (afterVotes.accepted as string[]) ?? [];
    const beforeDeclined = (beforeVotes.declined as string[]) ?? [];
    const afterDeclined = (afterVotes.declined as string[]) ?? [];

    // 새로 declined한 사용자 찾기 (미성사 알림용)
    const newDeclined = afterDeclined
      .filter((id: string) => !beforeDeclined.includes(id));

    const db = admin.firestore();
    const groupsCollection = getEnvironmentCollection("groups", db, env);

    // 그룹 멤버 조회
    const groupDoc = await groupsCollection.doc(groupId).get();
    if (!groupDoc.exists) {
      console.log("Group not found:", groupId);
      return;
    }
    const memberIds = groupDoc.data()?.memberIds as string[] || [];
    const totalMembers = memberIds.length;

    // 확정 체크: 이전에는 미충족 → 이제 충족
    const wasConfirmed = beforeAccepted.length >= minimumParticipants;
    const isConfirmed = afterAccepted.length >= minimumParticipants;

    if (!wasConfirmed && isConfirmed) {
      // 약속 확정 알림 (수락한 사람들에게만)
      const startDate = startAt.toDate();
      const dateString = `${startDate.getMonth() + 1}월 ${startDate.getDate()}일`;

      await sendPushNotificationInternal({
        userIds: afterAccepted,
        type: NotificationType.PromiseConfirmed,
        title: "약속 확정! 🎉",
        body: `${title} 약속 확정! ${dateString}에 만나요`,
        promiseId,
        groupId,
        relatedUserId: null,
        data: null,
        env,
      });
      return;
    }

    // 미성사 체크: 남은 가능 인원 < 최소 인원
    const remainingPossible = totalMembers - afterDeclined.length;
    const prevRemaining = totalMembers - beforeDeclined.length;
    const wasCancellable = prevRemaining >= minimumParticipants;
    const isCancelled = remainingPossible < minimumParticipants;

    if (wasCancellable && isCancelled && newDeclined.length > 0) {
      // 약속 미성사 알림 (수락한 사람들에게만)
      if (afterAccepted.length > 0) {
        await sendPushNotificationInternal({
          userIds: afterAccepted,
          type: NotificationType.PromiseCancelled,
          title: "약속 무산 😢",
          body: `${title}의 참여 인원이 부족해서 확정되지 않았어요`,
          promiseId,
          groupId,
          relatedUserId: null,
          data: null,
          env,
        });
      }
    }
  },
);

/**
 * 그룹에 새 멤버 참여 시 기존 멤버들에게 알림
 *
 * @remarks
 * groups/{groupId} 문서의 memberIds가 변경되면 트리거됩니다.
 * - 새로 참여한 멤버가 있으면 기존 멤버들에게 알림
 */
export const onGroupMemberJoined = onDocumentUpdated(
  {
    document: "{env}/root/groups/{groupId}",
    region: REGION,
  },
  async (event) => {
    const beforeData = event.data?.before.data();
    const afterData = event.data?.after.data();

    if (!beforeData || !afterData) {
      return;
    }

    const groupId = event.params.groupId;
    const env = event.params.env as "stage" | "prod";

    const beforeMembers = new Set(beforeData.memberIds as string[] || []);
    const afterMembers = afterData.memberIds as string[] || [];

    // 새로 참여한 멤버 찾기
    const newMembers = afterMembers.filter((id) => !beforeMembers.has(id));

    if (newMembers.length === 0) {
      return; // 새 멤버 없음
    }

    const groupName = afterData.name as string || "그룹";
    const db = admin.firestore();
    const usersCollection = getEnvironmentCollection("users", db, env);

    for (const newMemberId of newMembers) {
      // 기존 멤버들에게 알림 (새 멤버 제외)
      const recipientIds = afterMembers.filter((id) => id !== newMemberId);

      if (recipientIds.length === 0) continue;

      const newMemberDoc = await usersCollection.doc(newMemberId).get();
      const newMemberName = newMemberDoc.data()?.nickname as string || "누군가";

      await sendPushNotificationInternal({
        userIds: recipientIds,
        type: NotificationType.GroupUpdate,
        title: "새 멤버 합류 👋",
        body: `${newMemberName}님이 ${groupName}에 들어왔어요`,
        promiseId: null,
        groupId,
        relatedUserId: newMemberId,
        data: null,
        env,
      });
    }
  },
);

// ============================================================================
// LiveActivity Functions
// ============================================================================

// APNs Production/Development 호스트
const APNS_HOST_PRODUCTION = "api.push.apple.com";
const APNS_HOST_DEVELOPMENT = "api.sandbox.push.apple.com";
const APNS_BUNDLE_ID = "com.promiso.app";

/**
 * APNs JWT 토큰 생성
 *
 * @param {string} keyId - APNs Auth Key ID
 * @param {string} teamId - Apple Developer Team ID
 * @param {string} authKey - APNs Auth Key (P8 내용)
 * @return {string} JWT 토큰
 */
function generateAPNsJWT(
  keyId: string,
  teamId: string,
  authKey: string,
): string {
  const token = jwt.sign(
    {},
    authKey,
    {
      algorithm: "ES256",
      keyid: keyId,
      issuer: teamId,
      expiresIn: "1h",
      header: {
        alg: "ES256",
        kid: keyId,
      },
    },
  );
  return token;
}

/**
 * APNs HTTP/2 푸시 전송
 *
 * @param {object} params - 파라미터
 * @return {Promise<object>} 결과 객체
 */
async function sendAPNsPush(params: {
  deviceToken: string;
  payload: object;
  pushType: "liveactivity";
  topic: string;
  apnsId?: string;
  expiration?: number;
  priority?: number;
  isProduction: boolean;
}): Promise<{success: boolean; statusCode?: number; error?: string}> {
  const {
    deviceToken,
    payload,
    pushType,
    topic,
    apnsId,
    expiration,
    priority,
    isProduction,
  } = params;

  const host = isProduction ? APNS_HOST_PRODUCTION : APNS_HOST_DEVELOPMENT;
  const path = `/3/device/${deviceToken}`;

  // JWT 토큰 생성
  const keyId = APNS_KEY_ID.value();
  const teamId = APNS_TEAM_ID.value();
  const authKey = APNS_AUTH_KEY.value().replace(/\\n/g, "\n");
  const jwtToken = generateAPNsJWT(keyId, teamId, authKey);

  return new Promise((resolve) => {
    const client = http2.connect(`https://${host}`);

    client.on("error", (err) => {
      console.error("❌ APNs HTTP/2 connection error:", err);
      resolve({success: false, error: err.message});
    });

    const headers: http2.OutgoingHttpHeaders = {
      ":method": "POST",
      ":path": path,
      "authorization": `bearer ${jwtToken}`,
      "apns-push-type": pushType,
      "apns-topic": topic,
      ...(apnsId && {"apns-id": apnsId}),
      ...(expiration !== undefined && {
        "apns-expiration": expiration.toString(),
      }),
      ...(priority !== undefined && {
        "apns-priority": priority.toString(),
      }),
    };

    const req = client.request(headers);

    let responseData = "";

    req.on("response", (headers) => {
      const statusCode = headers[":status"] as number;

      req.on("data", (chunk) => {
        responseData += chunk;
      });

      req.on("end", () => {
        client.close();

        if (statusCode === 200) {
          resolve({success: true, statusCode});
        } else {
          console.error(`❌ APNs error: ${statusCode} - ${responseData}`);
          resolve({success: false, statusCode, error: responseData});
        }
      });
    });

    req.on("error", (err) => {
      console.error("❌ APNs request error:", err);
      client.close();
      resolve({success: false, error: err.message});
    });

    req.write(JSON.stringify(payload));
    req.end();
  });
}

/**
 * Push to Start 토큰 등록
 *
 * @remarks
 * **인증 필수**
 *
 * iOS 17.2+ 디바이스에서 앱 시작 시 Push to Start 토큰을 등록합니다.
 */
export const registerPushToStartToken = onCall<
  RegisterPushToStartTokenRequest
>(
  {
    region: REGION,
    secrets: [APNS_KEY_ID, APNS_TEAM_ID, APNS_AUTH_KEY],
  },
  async (request): Promise<RegisterPushToStartTokenResponse> => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "로그인이 필요합니다");
    }

    const userId = request.auth.uid;
    const {token, deviceId, env} = request.data;

    if (!token || !deviceId) {
      throw new HttpsError("invalid-argument", "token과 deviceId는 필수입니다");
    }

    const db = admin.firestore();
    const usersCollection = getEnvironmentCollection("users", db, env);

    try {
      await usersCollection.doc(userId).update({
        [`devices.${deviceId}.liveActivityPushToStartToken`]: token,
      });

      console.log(
        `✅ Push to Start 토큰 등록: userId=${userId}, deviceId=${deviceId}`,
      );
      return {success: true};
    } catch (error) {
      console.error("❌ Push to Start 토큰 등록 실패:", error);
      throw new HttpsError("internal", "토큰 등록에 실패했습니다");
    }
  },
);

/**
 * LiveActivity 시작 (Push to Start)
 *
 * @remarks
 * **인증 필수**
 *
 * 약속 참가자(accepted) 전원에게 Push to Start APNs를 전송하여
 * LiveActivity를 원격으로 시작합니다.
 *
 * @param request.data - StartLiveActivityRequest
 * @returns StartLiveActivityResponse
 */
export const startLiveActivity = onCall<StartLiveActivityRequest>(
  {
    region: REGION,
    secrets: [APNS_KEY_ID, APNS_TEAM_ID, APNS_AUTH_KEY],
  },
  async (request): Promise<StartLiveActivityResponse> => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "로그인이 필요합니다");
    }

    const userId = request.auth.uid;
    const {promiseId, env} = request.data;

    if (!promiseId) {
      throw new HttpsError("invalid-argument", "promiseId는 필수입니다");
    }

    const db = admin.firestore();
    const promisesCollection = getEnvironmentCollection("promises", db, env);
    const usersCollection = getEnvironmentCollection("users", db, env);
    const groupsCollection = getEnvironmentCollection("groups", db, env);

    // 1. 약속 정보 조회
    const promiseDoc = await promisesCollection.doc(promiseId).get();
    if (!promiseDoc.exists) {
      throw new HttpsError("not-found", "약속을 찾을 수 없습니다");
    }

    const promiseData = promiseDoc.data()!;
    const groupId = promiseData.groupId as string;
    const hostId = promiseData.hostId as string;
    const title = promiseData.title as string;
    const emoji = promiseData.emoji as string || "📅";
    const location = promiseData.location?.name as string || null;
    const startAt = promiseData.startAt as FirebaseFirestore.Timestamp;
    const acceptedUserIds = promiseData.votes?.accepted as string[] || [];

    // 2. 권한 확인 (호스트만 시작 가능)
    if (userId !== hostId) {
      throw new HttpsError(
        "permission-denied",
        "호스트만 LiveActivity를 시작할 수 있습니다",
      );
    }

    // 3. 참가자 정보 조회
    const participantPromises = acceptedUserIds.map(async (uid) => {
      const userDoc = await usersCollection.doc(uid).get();
      const userData = userDoc.data();
      return {
        id: uid,
        name: userData?.nickname as string || "참가자",
        estimatedArrivalMinutes: null,
      } as LiveActivityParticipant;
    });
    const participants = await Promise.all(participantPromises);

    // 4. 호스트 이름 조회
    const hostDoc = await usersCollection.doc(hostId).get();
    const hostName = hostDoc.data()?.nickname as string || null;

    // 5. 그룹 멤버들의 Push to Start 토큰 수집
    const groupDoc = await groupsCollection.doc(groupId).get();
    const memberIds = groupDoc.data()?.memberIds as string[] || [];

    const tokenPromises = memberIds.map(async (memberId) => {
      const userDoc = await usersCollection.doc(memberId).get();
      const devices = userDoc.data()?.devices as {
        [key: string]: DeviceInfo;
      } | null;
      if (!devices) return [];

      const tokens: {userId: string; token: string}[] = [];
      for (const deviceId of Object.keys(devices)) {
        const device = devices[deviceId];
        if (device.liveActivityPushToStartToken) {
          tokens.push({
            userId: memberId,
            token: device.liveActivityPushToStartToken,
          });
        }
      }
      return tokens;
    });

    const allTokenArrays = await Promise.all(tokenPromises);
    const allTokens = allTokenArrays.flat();

    if (allTokens.length === 0) {
      console.log("📭 No Push to Start tokens found");
      return {
        success: true,
        successCount: 0,
        failureCount: acceptedUserIds.length,
      };
    }

    // 6. APNs Push to Start 전송
    const isProduction = env === "prod";
    const trackingDurationMinutes = 30;

    let successCount = 0;
    let failureCount = 0;

    for (const {userId: tokenUserId, token} of allTokens) {
      // 각 사용자별로 currentUserId를 다르게 설정
      const payload = {
        aps: {
          "timestamp": Math.floor(Date.now() / 1000),
          "event": "start",
          "attributes-type": "PromiseActivityAttributes",
          "attributes": {
            trackingDurationMinutes,
            promiseId,
            currentUserId: tokenUserId,
            emoji,
            title,
            location,
            scheduledTime: startAt.toDate().toISOString(),
            hostId,
            hostName,
          },
          "content-state": {
            trackingDurationMinutes,
            participants,
          },
        },
      };

      const result = await sendAPNsPush({
        deviceToken: token,
        payload,
        pushType: "liveactivity",
        topic: `${APNS_BUNDLE_ID}.push-type.liveactivity`,
        priority: 10,
        isProduction,
      });

      if (result.success) {
        successCount++;
      } else {
        failureCount++;
      }
    }

    console.log(
      `📤 LiveActivity started: ${successCount}/${failureCount}`
    );
    return {success: true, successCount, failureCount};
  },
);

/**
 * ETA 업데이트
 *
 * @remarks
 * **인증 필수**
 *
 * 호출자의 ETA를 업데이트하고 모든 참가자에게 APNs update 이벤트를 브로드캐스트합니다.
 *
 * @param request.data - UpdateETARequest
 * @returns UpdateETAResponse
 */
export const updateETA = onCall<UpdateETARequest>(
  {region: REGION, secrets: [APNS_KEY_ID, APNS_TEAM_ID, APNS_AUTH_KEY]},
  async (request): Promise<UpdateETAResponse> => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "로그인이 필요합니다");
    }

    const userId = request.auth.uid;
    const {promiseId, estimatedMinutes, env} = request.data;

    if (!promiseId || estimatedMinutes === undefined) {
      throw new HttpsError(
        "invalid-argument",
        "promiseId와 estimatedMinutes는 필수입니다"
      );
    }

    const db = admin.firestore();
    const promisesCollection = getEnvironmentCollection("promises", db, env);
    const liveActivitiesCollection = getEnvironmentCollection(
      "liveActivities", db, env
    );
    const usersCollection = getEnvironmentCollection("users", db, env);

    // 1. 약속 정보 조회
    const promiseDoc = await promisesCollection.doc(promiseId).get();
    if (!promiseDoc.exists) {
      throw new HttpsError("not-found", "약속을 찾을 수 없습니다");
    }

    const promiseData = promiseDoc.data()!;
    const accepted = promiseData.votes?.accepted as string[] || [];

    // 2. LiveActivity 상태 조회/업데이트
    const liveActivityRef = liveActivitiesCollection.doc(promiseId);
    const liveActivityDoc = await liveActivityRef.get();

    let participants: LiveActivityParticipant[];
    const trackingDurationMinutes = 30;

    if (liveActivityDoc.exists) {
      // 기존 상태 업데이트
      const docData = liveActivityDoc.data();
      participants = docData?.participants as LiveActivityParticipant[] || [];
      const idx = participants.findIndex((p) => p.id === userId);
      if (idx >= 0) {
        participants[idx].estimatedArrivalMinutes = estimatedMinutes;
      }
      await liveActivityRef.update({
        participants,
        updatedAt: FieldValue.serverTimestamp(),
      });
    } else {
      // 새로 생성
      const participantPromises = accepted.map(async (uid) => {
        const userDoc = await usersCollection.doc(uid).get();
        const userData = userDoc.data();
        return {
          id: uid,
          name: userData?.nickname as string || "참가자",
          estimatedArrivalMinutes: uid === userId ? estimatedMinutes : null,
        } as LiveActivityParticipant;
      });
      participants = await Promise.all(participantPromises);
      await liveActivityRef.set({
        promiseId,
        participants,
        trackingDurationMinutes,
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });
    }

    // 3. 참가자들의 LiveActivity 토큰 수집
    const tokenPromises = accepted.map(async (memberId) => {
      const userDoc = await usersCollection.doc(memberId).get();
      const userData = userDoc.data();
      const devices = userData?.devices as {[key: string]: DeviceInfo} | null;
      if (!devices) return [];

      const tokens: string[] = [];
      for (const deviceId of Object.keys(devices)) {
        const device = devices[deviceId];
        // Push to Start 토큰 사용
        if (device.liveActivityPushToStartToken) {
          tokens.push(device.liveActivityPushToStartToken);
        }
      }
      return tokens;
    });

    const allTokenArrays = await Promise.all(tokenPromises);
    const allTokens = [...new Set(allTokenArrays.flat())];

    if (allTokens.length === 0) {
      console.log("📭 No LiveActivity tokens found for ETA update");
      return {success: true, successCount: 0, failureCount: accepted.length};
    }

    // 4. APNs update 이벤트 전송
    const isProduction = env === "prod";

    const payload = {
      aps: {
        "timestamp": Math.floor(Date.now() / 1000),
        "event": "update",
        "content-state": {
          trackingDurationMinutes,
          participants,
        },
      },
    };

    let successCount = 0;
    let failureCount = 0;

    for (const token of allTokens) {
      const result = await sendAPNsPush({
        deviceToken: token,
        payload,
        pushType: "liveactivity",
        topic: `${APNS_BUNDLE_ID}.push-type.liveactivity`,
        priority: 10,
        isProduction,
      });

      if (result.success) {
        successCount++;
      } else {
        failureCount++;
      }
    }

    console.log(`📤 ETA updated: ${successCount}/${failureCount}`);
    return {success: true, successCount, failureCount};
  },
);

/**
 * LiveActivity 종료
 *
 * @remarks
 * **인증 필수**
 *
 * 호스트만 LiveActivity를 종료할 수 있습니다.
 * 모든 참가자에게 APNs end 이벤트를 전송합니다.
 *
 * @param request.data - EndLiveActivityRequest
 * @returns EndLiveActivityResponse
 */
export const endLiveActivity = onCall<EndLiveActivityRequest>(
  {region: REGION, secrets: [APNS_KEY_ID, APNS_TEAM_ID, APNS_AUTH_KEY]},
  async (request): Promise<EndLiveActivityResponse> => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "로그인이 필요합니다");
    }

    const userId = request.auth.uid;
    const {promiseId, env} = request.data;

    if (!promiseId) {
      throw new HttpsError("invalid-argument", "promiseId는 필수입니다");
    }

    const db = admin.firestore();
    const promisesCollection = getEnvironmentCollection("promises", db, env);
    const liveActivitiesCollection = getEnvironmentCollection(
      "liveActivities", db, env
    );
    const usersCollection = getEnvironmentCollection("users", db, env);

    // 1. 약속 정보 조회
    const promiseDoc = await promisesCollection.doc(promiseId).get();
    if (!promiseDoc.exists) {
      throw new HttpsError("not-found", "약속을 찾을 수 없습니다");
    }

    const promiseData = promiseDoc.data()!;
    const hostId = promiseData.hostId as string;
    const accepted = promiseData.votes?.accepted as string[] || [];

    // 2. 권한 확인 (호스트만 종료 가능)
    if (userId !== hostId) {
      throw new HttpsError(
        "permission-denied",
        "호스트만 LiveActivity를 종료할 수 있습니다"
      );
    }

    // 3. 참가자들의 LiveActivity 토큰 수집
    const tokenPromises = accepted.map(async (memberId) => {
      const userDoc = await usersCollection.doc(memberId).get();
      const userData = userDoc.data();
      const devices = userData?.devices as {[key: string]: DeviceInfo} | null;
      if (!devices) return [];

      const tokens: string[] = [];
      for (const deviceId of Object.keys(devices)) {
        const device = devices[deviceId];
        if (device.liveActivityPushToStartToken) {
          tokens.push(device.liveActivityPushToStartToken);
        }
      }
      return tokens;
    });

    const allTokenArrays = await Promise.all(tokenPromises);
    const allTokens = [...new Set(allTokenArrays.flat())];

    if (allTokens.length === 0) {
      console.log("📭 No LiveActivity tokens found for end event");
      return {success: true, successCount: 0, failureCount: accepted.length};
    }

    // 4. APNs end 이벤트 전송
    const isProduction = env === "prod";
    const dismissalDate = Math.floor(Date.now() / 1000) + 60; // 1분 후 자동 dismiss

    const payload = {
      aps: {
        "timestamp": Math.floor(Date.now() / 1000),
        "event": "end",
        "dismissal-date": dismissalDate,
      },
    };

    let successCount = 0;
    let failureCount = 0;

    for (const token of allTokens) {
      const result = await sendAPNsPush({
        deviceToken: token,
        payload,
        pushType: "liveactivity",
        topic: `${APNS_BUNDLE_ID}.push-type.liveactivity`,
        priority: 10,
        isProduction,
      });

      if (result.success) {
        successCount++;
      } else {
        failureCount++;
      }
    }

    // 5. LiveActivity 상태 문서 삭제
    try {
      await liveActivitiesCollection.doc(promiseId).delete();
    } catch (error) {
      console.warn("LiveActivity 문서 삭제 실패 (이미 없을 수 있음):", error);
    }

    console.log(`📤 LiveActivity ended: ${successCount}/${failureCount}`);
    return {success: true, successCount, failureCount};
  },
);

// ============================================================================
// Cloud Tasks - LiveActivity 예약 실행
// ============================================================================

/**
 * LiveActivity 예약 시작 태스크 핸들러
 *
 * @remarks
 * Cloud Tasks에 의해 예약된 시간에 자동 실행됩니다.
 * 약속 시간 N분 전에 모든 참가자에게 LiveActivity를 시작합니다.
 */
export const executeLiveActivityStart = onTaskDispatched<
  ScheduledLiveActivityTaskPayload
>(
  {
    region: REGION,
    retryConfig: {
      maxAttempts: 3,
      minBackoffSeconds: 10,
    },
    rateLimits: {
      maxConcurrentDispatches: 10,
    },
    secrets: [APNS_KEY_ID, APNS_TEAM_ID, APNS_AUTH_KEY],
  },
  async (req) => {
    const {promiseId, env} = req.data;
    console.log(`⏰ Scheduled LiveActivity start: ${promiseId}`);

    const db = admin.firestore();
    const promisesCollection = getEnvironmentCollection("promises", db, env);
    const usersCollection = getEnvironmentCollection("users", db, env);
    const liveActivitiesCollection = getEnvironmentCollection(
      "liveActivities", db, env
    );

    // 1. 약속 정보 조회
    const promiseDoc = await promisesCollection.doc(promiseId).get();
    if (!promiseDoc.exists) {
      console.warn(`Promise not found: ${promiseId}`);
      return;
    }

    const promiseData = promiseDoc.data()!;
    const hostId = promiseData.hostId as string;
    const emoji = promiseData.emoji as string || "📌";
    const title = promiseData.title as string;
    const location = promiseData.location?.name as string || null;
    const startAt = promiseData.startAt as admin.firestore.Timestamp;
    const accepted = promiseData.votes?.accepted as string[] || [];
    const minParticipants = promiseData.minimumParticipants as number || 2;

    // 2. 약속이 확정 상태인지 확인
    if (accepted.length < minParticipants) {
      console.log(`Promise not confirmed: ${promiseId}`);
      return;
    }

    // 3. 호스트 이름 조회
    const hostDoc = await usersCollection.doc(hostId).get();
    const hostName = hostDoc.data()?.nickname as string || null;

    // 4. 참가자 정보 생성
    const participantPromises = accepted.map(async (uid) => {
      const userDoc = await usersCollection.doc(uid).get();
      const userData = userDoc.data();
      return {
        id: uid,
        name: userData?.nickname as string || "참가자",
        estimatedArrivalMinutes: null,
      } as LiveActivityParticipant;
    });
    const participants = await Promise.all(participantPromises);

    // 5. LiveActivity 상태 저장
    const trackingDurationMinutes = 30;
    await liveActivitiesCollection.doc(promiseId).set({
      promiseId,
      participants,
      trackingDurationMinutes,
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });

    // 6. 참가자들의 Push to Start 토큰 수집
    const tokenPromises = accepted.map(async (memberId) => {
      const userDoc = await usersCollection.doc(memberId).get();
      const userData = userDoc.data();
      const devices = userData?.devices as {[key: string]: DeviceInfo} | null;
      if (!devices) return [];

      const tokens: {userId: string; token: string}[] = [];
      for (const deviceId of Object.keys(devices)) {
        const device = devices[deviceId];
        if (device.liveActivityPushToStartToken) {
          tokens.push({
            userId: memberId,
            token: device.liveActivityPushToStartToken,
          });
        }
      }
      return tokens;
    });

    const allTokenArrays = await Promise.all(tokenPromises);
    const allTokens = allTokenArrays.flat();

    if (allTokens.length === 0) {
      console.log(`📭 No Push to Start tokens for: ${promiseId}`);
      return;
    }

    // 7. APNs Push to Start 전송
    const isProduction = env === "prod";
    let successCount = 0;
    let failureCount = 0;

    for (const {userId: tokenUserId, token} of allTokens) {
      const payload = {
        aps: {
          "timestamp": Math.floor(Date.now() / 1000),
          "event": "start",
          "attributes-type": "PromiseActivityAttributes",
          "attributes": {
            trackingDurationMinutes,
            promiseId,
            currentUserId: tokenUserId,
            emoji,
            title,
            location,
            scheduledTime: startAt.toDate().toISOString(),
            hostId,
            hostName,
          },
          "content-state": {
            trackingDurationMinutes,
            participants,
          },
        },
      };

      const result = await sendAPNsPush({
        deviceToken: token,
        payload,
        pushType: "liveactivity",
        topic: `${APNS_BUNDLE_ID}.push-type.liveactivity`,
        priority: 10,
        isProduction,
      });

      if (result.success) {
        successCount++;
      } else {
        failureCount++;
      }
    }

    console.log(
      `⏰ Scheduled LiveActivity started: ${successCount}/${failureCount}`
    );
  }
);

/**
 * 약속 확정 또는 실시간 공유 설정 변경 시 LiveActivity 예약
 *
 * @remarks
 * 다음 경우에 Cloud Task를 예약합니다:
 * 1. 약속이 확정됨 (accepted >= minimumParticipants) + trackingMinutes 설정됨
 * 2. 이미 확정된 약속에서 trackingStartMinutesBefore가 변경됨
 */
export const onPromiseConfirmedScheduleLiveActivity = onDocumentUpdated(
  {
    document: "{env}/root/promises/{promiseId}",
    region: REGION,
  },
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    const promiseId = event.params.promiseId;
    const env = event.params.env as "stage" | "prod";

    if (!before || !after) return;

    const minParticipants = after.minimumParticipants as number || 2;
    const beforeAccepted = before.votes?.accepted as string[] || [];
    const afterAccepted = after.votes?.accepted as string[] || [];
    const beforeTrackingMinutes =
      before.trackingStartMinutesBefore as number | null;
    const afterTrackingMinutes =
      after.trackingStartMinutesBefore as number | null;
    const startAt = after.startAt as admin.firestore.Timestamp;

    // 확정 상태 확인
    const wasConfirmed = beforeAccepted.length >= minParticipants;
    const isNowConfirmed = afterAccepted.length >= minParticipants;

    // trackingMinutes 변경 확인
    const trackingMinutesChanged =
      beforeTrackingMinutes !== afterTrackingMinutes;

    // 스케줄링이 필요한 조건:
    // 1. 새로 확정됨 (미확정 → 확정) + trackingMinutes 설정됨
    // 2. 이미 확정 + trackingMinutes가 null → 값으로 변경됨
    // 3. 이미 확정 + trackingMinutes 값이 변경됨
    const justConfirmed = !wasConfirmed && isNowConfirmed;
    const trackingEnabledOnConfirmed =
      isNowConfirmed && trackingMinutesChanged && afterTrackingMinutes !== null;

    const shouldSchedule = justConfirmed || trackingEnabledOnConfirmed;

    if (!shouldSchedule) {
      return;
    }

    // trackingStartMinutesBefore가 설정되지 않으면 예약 안함
    if (!afterTrackingMinutes) {
      console.log(`📭 No tracking schedule for: ${promiseId}`);
      return;
    }

    // 예약 시간 계산
    const startTime = startAt.toDate();
    const scheduleTime = new Date(
      startTime.getTime() - afterTrackingMinutes * 60 * 1000
    );
    const now = new Date();

    // 약속 시작 시간이 이미 지났으면 스킵
    if (startTime <= now) {
      console.log(`⏰ Promise already started, skipping: ${promiseId}`);
      return;
    }

    // 이미 예약되었고 trackingMinutes가 변경되지 않았으면 스킵
    const wasAlreadyScheduled = after.liveActivityScheduled === true;
    if (wasAlreadyScheduled && !trackingMinutesChanged) {
      console.log(`📅 Already scheduled (no change): ${promiseId}`);
      return;
    }

    // 재스케줄링인 경우 로그
    if (wasAlreadyScheduled && trackingMinutesChanged) {
      console.log(
        `🔄 Rescheduling LiveActivity: ${promiseId} ` +
        `(${beforeTrackingMinutes}분 → ${afterTrackingMinutes}분)`
      );
    }

    // Cloud Task 예약
    const queue = getFunctions().taskQueue<ScheduledLiveActivityTaskPayload>(
      "executeLiveActivityStart"
    );

    const delaySeconds = Math.max(
      0,
      Math.floor((scheduleTime.getTime() - now.getTime()) / 1000)
    );

    await queue.enqueue(
      {promiseId, env},
      {scheduleDelaySeconds: delaySeconds}
    );

    // 예약 완료 표시
    const db = admin.firestore();
    const promisesCollection = getEnvironmentCollection("promises", db, env);
    await promisesCollection.doc(promiseId).update({
      liveActivityScheduled: true,
      liveActivityScheduledAt: scheduleTime,
    });

    const isImmediate = delaySeconds === 0;
    console.log(
      `📅 LiveActivity scheduled: ${promiseId} at ` +
      `${scheduleTime.toISOString()}${isImmediate ? " (즉시 실행)" : ""}`
    );
  }
);
