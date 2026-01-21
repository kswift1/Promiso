/**
 * Group Functions
 *
 * 그룹 관련 Cloud Functions
 */
import {FieldValue} from "firebase-admin/firestore";
import {HttpsError, onCall} from "firebase-functions/v2/https";
import {admin, REGION} from "../config";
import {getEnvironmentCollection} from "../utils/firestore";
import {
  validateCreateGroupRequest,
  generateUniqueInviteCode,
} from "../utils/helpers";
import {
  CreateGroupRequest,
  CreateGroupResponse,
  PreviewGroupRequest,
  PreviewGroupResponse,
  JoinGroupRequest,
  JoinGroupResponse,
  LeaveGroupRequest,
  LeaveGroupResponse,
  DeleteGroupRequest,
  DeleteGroupResponse,
  GroupMemberPreview,
} from "../types/api";

/**
 * 그룹 생성
 *
 * @remarks
 * **인증 필수**
 *
 * 새로운 그룹을 생성하고 유니크한 초대 코드를 발급합니다.
 * iOS CreateGroup Feature와 연동됩니다.
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
