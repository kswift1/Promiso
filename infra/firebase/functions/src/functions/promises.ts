/**
 * Promise Functions
 *
 * 약속 관련 Cloud Functions
 *
 * @ios CreatePromiseView, PromiseDetailView, GroupMainView
 * @see ARCHITECTURE.md - iOS Feature ↔ Functions 매핑
 */
import {FieldValue} from "firebase-admin/firestore";
import {HttpsError, onCall} from "firebase-functions/v2/https";
import {admin, REGION} from "../config";
import {isValidFirebaseStorageUrl} from "../utils/helpers";
import {
  CreatePromiseRequest,
  CreatePromiseResponse,
  RespondPromiseRequest,
  RespondPromiseResponse,
  UpdatePromiseRequest,
  UpdatePromiseResponse,
  DeletePromiseRequest,
  DeletePromiseResponse,
  GetConfirmedPromisesForCalendarRequest,
  GetConfirmedPromisesForCalendarResponse,
  CalendarPromise,
} from "../types/api";

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

    if (data.minimumParticipants < 1) {
      throw new HttpsError(
        "invalid-argument",
        "최소 참가 인원은 1명 이상이어야 합니다",
      );
    }

    const db = admin.firestore();
    const groupsCollection = db.collection("groups");
    const promisesCollection = db.collection("promises");

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

    // 호스트 1명만 accepted이므로 minimumParticipants >= 2면 확정 안 됨
    const initialAccepted = [userId];
    const isConfirmed = initialAccepted.length >= data.minimumParticipants;

    const promiseData = {
      title: data.title,
      emoji: data.emoji || null,
      description: data.description || null,
      hostId: userId,
      groupId: data.groupId,
      minimumParticipants: data.minimumParticipants,
      votes: {
        accepted: initialAccepted, // 호스트는 자동 accepted
        declined: [],
        until: startAtTimestamp, // 기본값: startAt
      },
      isConfirmed, // 캘린더 동기화용 비정규화 필드
      startAt: startAtTimestamp,
      endAt: endAtDate ? admin.firestore.Timestamp.fromDate(endAtDate) : null,
      location: data.location ? {
        name: data.location.name,
        address: data.location.address || null,
        latitude: data.location.latitude || null,
        longitude: data.location.longitude || null,
      } : null,
      trackingStartMinutesBefore: data.arrivalSharingTime || null,
      imageUrls: data.imageUrls && data.imageUrls.length > 0 ?
        data.imageUrls.slice(0, 3).filter(isValidFirebaseStorageUrl) :
        null,
      badgesCleared: false, // 배지 정리 여부 (마감 시 true로 변경)
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
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

    const db = admin.firestore();
    const promisesCollection = db.collection("promises");
    const groupsCollection = db.collection("groups");

    const promiseRef = promisesCollection.doc(data.promiseId);

    const transactionResult = await db.runTransaction(async (transaction) => {
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
      const minimumParticipants =
        (promiseData.minimumParticipants as number) ?? 2;

      const isInAccepted = acceptedList.includes(userId);
      const isInDeclined = declinedList.includes(userId);

      // 이미 같은 상태면 스킵 (변경 없음 반환)
      if (
        (status === "accepted" && isInAccepted) ||
        (status === "declined" && isInDeclined) ||
        (status === "pending" && !isInAccepted && !isInDeclined)
      ) {
        // 기존 상태 유지 - isConfirmed 계산
        const isConfirmed = acceptedList.length >= minimumParticipants;
        return {isConfirmed, promiseData, noChange: true};
      }

      // 4. 새로운 accepted 배열 계산 (isConfirmed 계산용)
      let newAcceptedList = [...acceptedList];
      if (isInAccepted) {
        newAcceptedList = newAcceptedList.filter((id) => id !== userId);
      }
      if (status === "accepted") {
        newAcceptedList.push(userId);
      }

      // 5. isConfirmed 계산
      const isConfirmed = newAcceptedList.length >= minimumParticipants;

      // 6. votes 배열 업데이트 (Set-like 동작)
      // 먼저 기존 상태에서 제거
      const updateData: Record<string, unknown> = {
        updatedAt: FieldValue.serverTimestamp(),
        isConfirmed, // 캘린더 동기화용 비정규화 필드
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

      // 캘린더 동기화용 데이터 반환
      return {isConfirmed, promiseData, noChange: false};
    });

    // 응답 구성
    const response: RespondPromiseResponse = {
      promiseId: data.promiseId,
      status: status as "accepted" | "declined" | "pending",
      isConfirmed: transactionResult.isConfirmed,
    };

    // 확정되고 수락한 경우에만 약속 정보 포함
    if (transactionResult.isConfirmed && status === "accepted") {
      const promiseData = transactionResult.promiseData;
      const startAt = promiseData.startAt as admin.firestore.Timestamp;
      const endAt = promiseData.endAt as admin.firestore.Timestamp | null;
      const location = promiseData.location as {name?: string} | null;

      response.confirmedPromise = {
        id: data.promiseId,
        title: promiseData.title as string,
        emoji: (promiseData.emoji as string) || "📅",
        startAt: startAt.toDate().toISOString(),
        endAt: endAt ? endAt.toDate().toISOString() : null,
        location: location?.name || null,
        groupId: promiseData.groupId as string,
      };
    }

    return response;
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
 * - LiveActivity 실행 중인 약속은 수정 불가
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

    // minimumParticipants 검증
    if (
      data.minimumParticipants !== undefined &&
      data.minimumParticipants !== null &&
      data.minimumParticipants < 1
    ) {
      throw new HttpsError(
        "invalid-argument",
        "최소 참가 인원은 1명 이상이어야 합니다",
      );
    }

    const db = admin.firestore();
    const promisesCollection = db.collection("promises");

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

    // 4. 호스트 권한 확인 (약속 호스트 또는 그룹 호스트)
    const hostId = promiseData.hostId as string;
    const groupId = promiseData.groupId as string;

    // 그룹 정보 조회하여 그룹 호스트 확인
    const groupsCollection = db.collection("groups");
    const groupRef = groupsCollection.doc(groupId);
    const groupDoc = await groupRef.get();
    const groupData = groupDoc.data();
    const groupHostId = groupData?.createdBy as string | undefined;

    const isPromiseHost = hostId === userId;
    const isGroupHost = groupHostId === userId;

    if (!isPromiseHost && !isGroupHost) {
      throw new HttpsError(
        "permission-denied",
        "약속 호스트 또는 그룹 호스트만 약속을 수정할 수 있습니다",
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

    // 6. LiveActivity 실행 중 확인 (실시간 공유 중 수정 불가)
    const schedule = promiseData.liveActivitySchedule as {
      scheduled?: boolean;
      scheduledAt?: admin.firestore.Timestamp;
    } | null;
    if (schedule?.scheduled && schedule?.scheduledAt) {
      if (schedule.scheduledAt.toMillis() <= now.toMillis()) {
        throw new HttpsError(
          "failed-precondition",
          "실시간 공유 중인 약속은 수정할 수 없습니다",
        );
      }
    }

    // 7. 업데이트할 필드 구성
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
      // 라이브 액티비티 예약 상태 리셋 (새 시간으로 재예약 트리거)
      updateData.liveActivitySchedule = null;
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

    // location (장소 정보)
    if (data.location !== undefined) {
      if (data.location === null) {
        updateData.location = null;
      } else {
        updateData.location = {
          name: data.location.name,
          address: data.location.address || null,
          latitude: data.location.latitude || null,
          longitude: data.location.longitude || null,
        };
      }
    }

    // imageUrls (첨부 이미지)
    if (data.imageUrls !== undefined) {
      if (data.imageUrls === null || data.imageUrls.length === 0) {
        updateData.imageUrls = null;
      } else {
        updateData.imageUrls = data.imageUrls
          .slice(0, 3)
          .filter(isValidFirebaseStorageUrl);
      }
    }

    // 8. Firestore 업데이트
    await promiseRef.update(updateData);

    // 9. 응답 반환
    return {
      success: true,
    };
  },
);

/**
 * 약속 삭제
 *
 * @remarks
 * **인증 필수**
 *
 * 약속을 삭제합니다 (Hard Delete):
 * - 호스트만 삭제 가능
 * - 시작 전 약속만 삭제 가능
 *
 * @ios PromiseDetailView
 * @added 2026-01-21
 */
export const deletePromise = onCall<DeletePromiseRequest>(
  {region: REGION},
  async (request): Promise<DeletePromiseResponse> => {
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

    const db = admin.firestore();
    const promisesCollection = db.collection("promises");

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

    // 4. 호스트 권한 확인 (약속 호스트 또는 그룹 호스트)
    const hostId = promiseData.hostId;
    if (typeof hostId !== "string") {
      throw new HttpsError("internal", "잘못된 hostId 형식입니다");
    }

    const groupId = promiseData.groupId as string;

    // 그룹 정보 조회하여 그룹 호스트 확인
    const groupsCollection = db.collection("groups");
    const groupRef = groupsCollection.doc(groupId);
    const groupDoc = await groupRef.get();
    const groupData = groupDoc.data();
    const groupHostId = groupData?.createdBy as string | undefined;

    const isPromiseHost = hostId === userId;
    const isGroupHost = groupHostId === userId;

    if (!isPromiseHost && !isGroupHost) {
      throw new HttpsError(
        "permission-denied",
        "약속 호스트 또는 그룹 호스트만 약속을 삭제할 수 있습니다",
      );
    }

    // 5. 시작 시간 확인 (시작 전 약속만 삭제 가능)
    const startAt = promiseData.startAt;
    if (!(startAt instanceof admin.firestore.Timestamp)) {
      throw new HttpsError("internal", "잘못된 startAt 형식입니다");
    }
    const now = admin.firestore.Timestamp.now();
    if (startAt.toMillis() <= now.toMillis()) {
      throw new HttpsError(
        "failed-precondition",
        "이미 시작된 약속은 삭제할 수 없습니다",
      );
    }

    // 6. Storage 이미지 정리 (best-effort, imageUrls 존재 여부 무관하게 경로 전체 삭제)
    try {
      const bucket = admin.storage().bucket();
      const [files] = await bucket.getFiles({
        prefix: `promise_images/${groupId}/${data.promiseId}/`,
      });
      if (files.length > 0) {
        await Promise.all(files.map((file) => file.delete()));
      }
    } catch (err) {
      console.warn(
        `Failed to clean up images for promise ${data.promiseId}:`,
        err,
      );
    }

    // 7. Firestore에서 삭제 (Hard Delete)
    await promiseRef.delete();

    console.log(`🗑️ Promise deleted: ${data.promiseId}`);

    // 8. 응답 반환
    return {
      success: true,
    };
  },
);

/**
 * 캘린더 동기화용 확정 약속 조회
 *
 * @remarks
 * **인증 필수**
 *
 * 사용자가 참여 중인 확정된 미래 약속 목록을 조회합니다.
 * iOS 캘린더 자동 동기화 기능에서 사용됩니다.
 *
 * @returns 확정된 약속 목록 (캘린더에 필요한 최소 정보만)
 */
export const getConfirmedPromisesForCalendar = onCall<
  GetConfirmedPromisesForCalendarRequest
>(
  {region: REGION},
  async (request): Promise<GetConfirmedPromisesForCalendarResponse> => {
    // 1. 인증 확인
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "로그인이 필요합니다",
      );
    }

    const userId = request.auth.uid;
    const db = admin.firestore();
    const promisesCollection = db.collection("promises");

    // 2. 확정된 + 미래 + 내가 참여한 약속 쿼리
    const now = admin.firestore.Timestamp.now();

    const snapshot = await promisesCollection
      .where("isConfirmed", "==", true)
      .where("votes.accepted", "array-contains", userId)
      .where("startAt", ">=", now)
      .orderBy("startAt", "asc")
      .limit(50) // 최대 50개
      .get();

    // 3. 캘린더에 필요한 최소 정보만 추출
    const promises: CalendarPromise[] = snapshot.docs.map((doc) => {
      const data = doc.data();
      const startAt = data.startAt as admin.firestore.Timestamp;
      const endAt = data.endAt as admin.firestore.Timestamp | null;
      const location = data.location as {name?: string} | null;

      return {
        id: doc.id,
        title: data.title as string,
        emoji: (data.emoji as string) || "📅",
        startAt: startAt.toDate().toISOString(),
        endAt: endAt ? endAt.toDate().toISOString() : null,
        location: location?.name || null,
        groupId: data.groupId as string,
      };
    });

    console.log(
      "📅 getConfirmedPromisesForCalendar:",
      `userId=${userId}, count=${promises.length}`
    );

    return {promises};
  },
);
