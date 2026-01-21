/**
 * User Functions
 *
 * 사용자 관련 Cloud Functions
 *
 * @ios SignUpView, ProfileEditView, SettingsView
 * @see ARCHITECTURE.md - iOS Feature ↔ Functions 매핑
 */
import {FieldValue} from "firebase-admin/firestore";
import {HttpsError, onCall} from "firebase-functions/v2/https";
import {admin, REGION} from "../config";
import {getEnvironmentCollection} from "../utils/firestore";
import {generateDownloadURL} from "../utils/helpers";
import {
  CheckNicknameAvailableRequest,
  CheckNicknameAvailableResponse,
  CreateUserRequest,
  CreateUserResponse,
  GetUserRequest,
  GetUserSettingsResponse,
  UpdateUserRequest,
  UpdateUserResponse,
  UpdateUserSettingsRequest,
  UpdateUserSettingsResponse,
  UploadProfileImageRequest,
  UploadProfileImageResponse,
  UserPrivateResponse,
  UserPublicResponse,
} from "../types/api";

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
