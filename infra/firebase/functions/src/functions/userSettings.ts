/**
 * User Settings Functions
 *
 * 사용자 설정 관련 Cloud Functions
 */
import {HttpsError, onCall} from "firebase-functions/v2/https";
import {admin, REGION} from "../config";
import {getEnvironmentCollection} from "../utils/firestore";
import {
  GetUserSettingsResponse,
  GroupSortOption,
  UpdateUserSettingsRequest,
  UpdateUserSettingsResponse,
} from "../types/api";

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

    // 2. 설정 조회 (없으면 기본값 반환)
    const settingsDoc = await settingsRef.get();
    if (!settingsDoc.exists) {
      return {
        notificationEnabled: true,
        groupSortOption: {type: "joinedRecent"},
      };
    }

    const settingsData = settingsDoc.data();
    if (!settingsData) {
      return {
        notificationEnabled: true,
        groupSortOption: {type: "joinedRecent"},
      };
    }

    // 3. 응답 반환
    return {
      notificationEnabled: settingsData.notificationEnabled ?? true,
      groupSortOption: GroupSortOption.read(settingsData.groupSortOption),
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

    if (
      data.groupSortOption !== undefined &&
      data.groupSortOption !== null
    ) {
      updateData.groupSortOption = GroupSortOption.write(data.groupSortOption);
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
