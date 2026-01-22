/**
 * Group Functions
 *
 * 그룹 관련 Cloud Functions
 *
 * @ios CreateGroupView, JoinGroupView, GroupSettingsView
 * @see ARCHITECTURE.md - iOS Feature ↔ Functions 매핑
 */
import {FieldValue} from "firebase-admin/firestore";
import {HttpsError, onCall} from "firebase-functions/v2/https";
import {onDocumentUpdated} from "firebase-functions/v2/firestore";
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

// Firebase Storage URL에서 경로 추출용 정규식
const FIREBASE_STORAGE_PATH_REGEX = /\/o\/(.+?)\?/;

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
            needResponseCount: 0,
            imageUrl: data.imageUrl ?? null,
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
    const groupImageUrl =
      typeof groupData.imageUrl === "string" ? groupData.imageUrl : null;
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
    const nowTimestamp = admin.firestore.Timestamp.now();
    const usersCollection = getEnvironmentCollection("users", db, data.env);
    const promisesCollection = getEnvironmentCollection(
      "promises", db, data.env
    );

    // 4. 해당 그룹의 활성 약속 수 계산 (needResponseCount 초기값)
    // 마감 전(votes.until > now) + 배지 미정리(badgesCleared == false)
    const activePromises = await promisesCollection
      .where("groupId", "==", groupId)
      .where("badgesCleared", "==", false)
      .get();

    // 실제로 마감 전인 약속만 필터링 (쿼리 후 추가 검증)
    let needResponseCount = 0;
    for (const doc of activePromises.docs) {
      const promise = doc.data();
      const votes = promise.votes || {};
      const deadline = votes.until ?? promise.startAt;
      if (deadline && deadline.toMillis() > nowTimestamp.toMillis()) {
        needResponseCount++;
      }
    }

    // 5. Firestore에 저장 (트랜잭션 사용)
    await db.runTransaction(async (transaction) => {
      // 5-1. 그룹의 memberIds에 추가
      transaction.update(groupDoc.ref, {
        memberIds: FieldValue.arrayUnion(userId),
        updatedAt: now,
      });

      // 5-2. 사용자의 그룹 목록에 추가 (Map 방식) + needResponseCount 초기값
      const userRef = usersCollection.doc(userId);
      transaction.set(userRef, {
        groups: {
          [groupId]: {
            groupName: groupName,
            role: "member",
            joinedAt: now,
            notifications: true,
            needResponseCount,
            imageUrl: groupImageUrl,
          },
        },
      }, {merge: true});
    });

    console.log(
      `[joinGroup] ${userId} joined ${groupId}, ` +
      `needResponseCount: ${needResponseCount}`
    );

    // 6. 응답 반환
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
        "그룹 호스트는 나갈 수 없습니다. 그룹을 삭제해주세요.",
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
 * 2. Storage에서 그룹 이미지 삭제 (있는 경우)
 * 3. groups/{groupId} 문서 hard delete
 * 4. 모든 멤버의 users/{userId}/groups Map에서 해당 그룹 삭제
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

    const createdBy = groupData.createdBy;
    if (typeof createdBy !== "string") {
      throw new HttpsError("internal", "잘못된 createdBy 형식입니다");
    }

    const memberIds = groupData.memberIds;
    if (!Array.isArray(memberIds)) {
      throw new HttpsError("internal", "잘못된 memberIds 형식입니다");
    }

    const imageUrl = groupData.imageUrl;
    const validImageUrl = typeof imageUrl === "string" ? imageUrl : null;

    // 3-2. 호스트인지 확인
    if (createdBy !== userId) {
      throw new HttpsError(
        "permission-denied",
        "그룹 호스트만 삭제할 수 있습니다",
      );
    }

    // 4. Storage에서 그룹 이미지 삭제
    if (validImageUrl) {
      try {
        const bucket = admin.storage().bucket();
        const match = validImageUrl.match(FIREBASE_STORAGE_PATH_REGEX);
        if (match) {
          const storagePath = decodeURIComponent(match[1]);
          await bucket.file(storagePath).delete();
          console.log(`🗑️ Group image deleted: ${storagePath}`);
        }
      } catch (error) {
        // 이미지 삭제 실패해도 그룹 삭제는 계속 진행
        console.warn(`⚠️ Failed to delete group image: ${error}`);
      }
    }

    // 4-1. 그룹의 모든 약속 삭제 (트리거가 배지 감소 처리)
    const promisesCollection = getEnvironmentCollection(
      "promises", db, data.env
    );
    const groupPromises = await promisesCollection
      .where("groupId", "==", groupId)
      .get();

    if (!groupPromises.empty) {
      // 약속 삭제: 트랜잭션 밖에서 수행 (트리거 활성화)
      // Firestore batch는 최대 500개 작업 제한 - 500개 단위로 분할
      const BATCH_LIMIT = 500;
      const batches: FirebaseFirestore.WriteBatch[] = [];
      let batch = db.batch();
      let count = 0;

      for (const doc of groupPromises.docs) {
        batch.delete(doc.ref);
        count++;
        if (count === BATCH_LIMIT) {
          batches.push(batch);
          batch = db.batch();
          count = 0;
        }
      }

      if (count > 0) {
        batches.push(batch);
      }

      await Promise.all(batches.map((b) => b.commit()));
      console.log(
        `🗑️ ${groupPromises.size} promises deleted for group ${groupId}`
      );
    }

    const now = FieldValue.serverTimestamp();

    // 5. Firestore에서 삭제 (트랜잭션 사용)
    await db.runTransaction(async (transaction) => {
      // 5-1. 그룹 문서 hard delete
      transaction.delete(groupRef);

      // 5-2. 모든 멤버의 그룹 목록에서 삭제
      for (const memberId of memberIds) {
        const userRef = usersCollection.doc(memberId);
        transaction.update(userRef, {
          [`groups.${groupId}`]: FieldValue.delete(),
          updatedAt: now,
        });
      }
    });

    console.log(`🗑️ Group deleted: ${groupId}`);

    // 6. 응답 반환
    return {
      success: true,
    };
  },
);

/**
 * 그룹 이미지 업데이트 트리거
 *
 * @remarks
 * 그룹의 imageUrl이 변경되면 모든 멤버의
 * users/{userId}.groups[groupId].imageUrl을 업데이트합니다.
 */
export const onGroupImageUpdated = onDocumentUpdated(
  {
    document: "{env}/root/groups/{groupId}",
    region: REGION,
  },
  async (event) => {
    const beforeData = event.data?.before?.data();
    const afterData = event.data?.after?.data();

    if (!beforeData || !afterData) {
      console.log("[onGroupImageUpdated] No data found");
      return;
    }

    const beforeImageUrl =
      typeof beforeData.imageUrl === "string" ? beforeData.imageUrl : null;
    const afterImageUrl =
      typeof afterData.imageUrl === "string" ? afterData.imageUrl : null;

    // imageUrl이 변경되지 않았으면 종료
    if (beforeImageUrl === afterImageUrl) {
      return;
    }

    const groupId = event.params.groupId;
    const env = event.params.env;
    const memberIds =
      Array.isArray(afterData.memberIds) ? afterData.memberIds as string[] : [];

    if (memberIds.length === 0) {
      console.log(`[onGroupImageUpdated] No members in group ${groupId}`);
      return;
    }

    console.log(
      `[onGroupImageUpdated] Group ${groupId} imageUrl changed: ` +
      `${beforeImageUrl} → ${afterImageUrl}`
    );

    // 모든 멤버의 groups[groupId].imageUrl 업데이트
    const db = admin.firestore();
    const usersCollection = getEnvironmentCollection("users", db, env);
    const batch = db.batch();

    for (const memberId of memberIds) {
      const userRef = usersCollection.doc(memberId);
      batch.update(userRef, {
        [`groups.${groupId}.imageUrl`]: afterImageUrl,
      });
    }

    await batch.commit();
    console.log(
      `[onGroupImageUpdated] Updated imageUrl for ${memberIds.length} members`
    );
  }
);
