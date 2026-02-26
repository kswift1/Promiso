/**
 * Schedule Conflict Functions
 *
 * 일정 충돌 감지 Cloud Functions + Firestore Triggers
 * scheduleSlots 비정규화로 O(1) 충돌 체크
 *
 * @path users/{userId}/scheduleSlots/{YYYY-MM-DD}
 * @ios ScheduleConflictClient
 */

import {FieldValue} from "firebase-admin/firestore";
import {HttpsError, onCall} from "firebase-functions/v2/https";
import {
  onDocumentCreated,
  onDocumentUpdated,
  onDocumentDeleted,
} from "firebase-functions/v2/firestore";
import {admin, REGION} from "../config";
import {
  CheckScheduleConflictsRequest,
  CheckScheduleConflictsResponse,
  ScheduleConflictItem,
  ScheduleSlotEntry,
} from "../types/api";

// ============================================================================
// Constants
// ============================================================================

/** endAt이 null일 때 기본 지속 시간 (2시간, ms) */
const DEFAULT_DURATION_MS = 2 * 60 * 60 * 1000;

// ============================================================================
// Helpers
// ============================================================================

/**
 * startAt~endAt 범위에 걸치는 모든 UTC YYYY-MM-DD 키 반환
 *
 * @param {Date} startAt 시작 시간
 * @param {Date} endAt 종료 시간
 * @return {string[]} YYYY-MM-DD 키 배열
 */
function getDateKeys(startAt: Date, endAt: Date): string[] {
  const keys: string[] = [];
  const current = new Date(startAt);
  current.setUTCHours(0, 0, 0, 0);

  const endDate = new Date(endAt);
  endDate.setUTCHours(0, 0, 0, 0);

  while (current <= endDate) {
    keys.push(current.toISOString().slice(0, 10));
    current.setUTCDate(current.getUTCDate() + 1);
  }

  return keys;
}

/**
 * ScheduleSlotEntry 생성 헬퍼
 *
 * @param {string} id 일정 ID
 * @param {"promise" | "personalEvent"} type 일정 종류
 * @param {string} title 일정 제목
 * @param {string | null} emoji 이모지
 * @param {Date} startAt 시작 시간
 * @param {Date | null} endAt 종료 시간
 * @param {"confirmed" | "pending"} severity 확정 상태
 * @return {ScheduleSlotEntry} 슬롯 엔트리
 */
function createSlotEntry(
  id: string,
  type: "promise" | "personalEvent",
  title: string,
  emoji: string | null,
  startAt: Date,
  endAt: Date | null,
  severity: "confirmed" | "pending",
): ScheduleSlotEntry {
  return {
    id,
    type,
    title,
    emoji,
    startAt: startAt.toISOString(),
    endAt: endAt ? endAt.toISOString() : null,
    severity,
  };
}

/**
 * 사용자의 scheduleSlots에 슬롯 추가/업데이트 (upsert)
 *
 * @param {string} userId 사용자 ID
 * @param {ScheduleSlotEntry} slotEntry 슬롯 엔트리
 * @return {Promise<void>}
 */
async function upsertSlot(
  userId: string,
  slotEntry: ScheduleSlotEntry,
): Promise<void> {
  const db = admin.firestore();
  const startAt = new Date(slotEntry.startAt);
  const endAt = slotEntry.endAt ?
    new Date(slotEntry.endAt) :
    new Date(startAt.getTime() + DEFAULT_DURATION_MS);

  const dateKeys = getDateKeys(startAt, endAt);

  await Promise.all(dateKeys.map((dateKey) => {
    const docRef = db
      .collection("users").doc(userId)
      .collection("scheduleSlots").doc(dateKey);

    return db.runTransaction(async (tx) => {
      const doc = await tx.get(docRef);
      const slots: ScheduleSlotEntry[] = doc.data()?.slots ?? [];

      // 기존 슬롯 제거 후 새로 추가 (upsert)
      const filtered = slots.filter((s) => s.id !== slotEntry.id);
      filtered.push(slotEntry);

      tx.set(docRef, {
        slots: filtered,
        updatedAt: FieldValue.serverTimestamp(),
      });
    });
  }));
}

/**
 * 사용자의 scheduleSlots에서 슬롯 제거
 *
 * @param {string} userId 사용자 ID
 * @param {string} slotId 슬롯 ID
 * @param {Date} startAt 시작 시간
 * @param {Date | null} endAt 종료 시간
 * @return {Promise<void>}
 */
async function removeSlot(
  userId: string,
  slotId: string,
  startAt: Date,
  endAt: Date | null,
): Promise<void> {
  const db = admin.firestore();
  const effectiveEnd = endAt ??
    new Date(startAt.getTime() + DEFAULT_DURATION_MS);
  const dateKeys = getDateKeys(startAt, effectiveEnd);

  await Promise.all(dateKeys.map((dateKey) => {
    const docRef = db
      .collection("users").doc(userId)
      .collection("scheduleSlots").doc(dateKey);

    return db.runTransaction(async (tx) => {
      const doc = await tx.get(docRef);
      if (!doc.exists) return;

      const slots: ScheduleSlotEntry[] = doc.data()?.slots ?? [];
      const filtered = slots.filter((s) => s.id !== slotId);

      if (filtered.length === 0) {
        tx.delete(docRef);
      } else {
        tx.set(docRef, {
          slots: filtered,
          updatedAt: FieldValue.serverTimestamp(),
        });
      }
    });
  }));
}

// ============================================================================
// Callable Function: checkScheduleConflicts
// ============================================================================

/**
 * 일정 충돌 확인
 *
 * @remarks
 * **인증 필수**
 *
 * scheduleSlots 비정규화 데이터 기반 O(1) 충돌 체크.
 * 해당 날짜의 scheduleSlots 문서만 읽어 겹침을 판정합니다.
 *
 * @ios ScheduleConflictClient.checkConflicts
 */
export const checkScheduleConflicts =
  onCall<CheckScheduleConflictsRequest>(
    {region: REGION},
    async (request): Promise<CheckScheduleConflictsResponse> => {
      if (!request.auth) {
        throw new HttpsError("unauthenticated", "로그인이 필요합니다");
      }

      const userId = request.auth.uid;
      const data = request.data;

      if (!data.startAt) {
        throw new HttpsError(
          "invalid-argument",
          "시작 시간은 필수입니다",
        );
      }

      const startAt = new Date(data.startAt);
      const endAt = data.endAt ?
        new Date(data.endAt) :
        new Date(startAt.getTime() + DEFAULT_DURATION_MS);
      const excludeIds = new Set(data.excludeIds ?? []);

      // 해당 날짜 범위의 scheduleSlots 조회
      const dateKeys = getDateKeys(startAt, endAt);
      const db = admin.firestore();
      const slotsCollection = db
        .collection("users").doc(userId)
        .collection("scheduleSlots");

      // 날짜별 문서 병렬 조회
      const docs = await Promise.all(
        dateKeys.map((key) => slotsCollection.doc(key).get()),
      );

      // 모든 슬롯 수집 (다중 날짜 걸친 슬롯은 ID로 중복 제거)
      const allSlots = new Map<string, ScheduleSlotEntry>();
      for (const doc of docs) {
        if (!doc.exists) continue;
        const slots: ScheduleSlotEntry[] = doc.data()?.slots ?? [];
        for (const slot of slots) {
          if (!allSlots.has(slot.id)) {
            allSlots.set(slot.id, slot);
          }
        }
      }

      // 겹침 판정
      const conflicts: ScheduleConflictItem[] = [];
      for (const [, slot] of allSlots) {
        if (excludeIds.has(slot.id)) continue;

        const slotStart = new Date(slot.startAt);
        const slotEnd = slot.endAt ?
          new Date(slot.endAt) :
          new Date(slotStart.getTime() + DEFAULT_DURATION_MS);

        // 겹침 조건: slotStart < endAt && slotEnd > startAt
        if (slotStart < endAt && slotEnd > startAt) {
          const overlapStart = slotStart > startAt ? slotStart : startAt;
          const overlapEnd = slotEnd < endAt ? slotEnd : endAt;
          const overlapMinutes = Math.max(
            0,
            Math.floor(
              (overlapEnd.getTime() - overlapStart.getTime()) / 60000,
            ),
          );

          conflicts.push({
            id: slot.id,
            source: slot.type,
            severity: slot.severity,
            title: slot.title,
            emoji: slot.emoji,
            startAt: slot.startAt,
            endAt: slot.endAt,
            overlapMinutes,
          });
        }
      }

      // 겹침 시간 내림차순 정렬
      conflicts.sort((a, b) => b.overlapMinutes - a.overlapMinutes);

      console.log(
        `🔍 checkScheduleConflicts: userId=${userId}, ` +
        `range=${dateKeys.join(",")}, conflicts=${conflicts.length}`,
      );

      return {conflicts};
    },
  );

// ============================================================================
// Firestore Triggers: Promise → scheduleSlots
// ============================================================================

/**
 * 약속 생성 시 호스트의 scheduleSlots에 추가
 * (호스트는 자동 accepted)
 */
export const onPromiseCreatedSlot = onDocumentCreated(
  {document: "promises/{promiseId}", region: REGION},
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) return;

    const data = snapshot.data();
    const promiseId = event.params.promiseId;
    const hostId = data.hostId as string;
    const title = data.title as string;
    const emoji = (data.emoji as string) || null;
    const startAt = (data.startAt as admin.firestore.Timestamp).toDate();
    const endAtTs = data.endAt as admin.firestore.Timestamp | null;
    const endAt = endAtTs ? endAtTs.toDate() : null;
    const isConfirmed = data.isConfirmed as boolean;

    const slotEntry = createSlotEntry(
      promiseId, "promise", title, emoji, startAt, endAt,
      isConfirmed ? "confirmed" : "pending",
    );

    await upsertSlot(hostId, slotEntry);

    console.log(
      `📅 Slot created: promise/${promiseId} → user/${hostId}`,
    );
  },
);

/**
 * 약속 수정/투표 변경 시 scheduleSlots 갱신
 *
 * - votes.accepted 변경 → 새 수락자 추가, 취소자 제거
 * - 시간/제목/이모지/확정상태 변경 → 기존 accepted 전원 갱신
 */
export const onPromiseUpdatedSlot = onDocumentUpdated(
  {document: "promises/{promiseId}", region: REGION},
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!before || !after) return;

    const promiseId = event.params.promiseId;

    const beforeAccepted = (before.votes?.accepted as string[]) ?? [];
    const afterAccepted = (after.votes?.accepted as string[]) ?? [];

    const title = after.title as string;
    const emoji = (after.emoji as string) || null;
    const startAt = (after.startAt as admin.firestore.Timestamp).toDate();
    const endAtTs = after.endAt as admin.firestore.Timestamp | null;
    const endAt = endAtTs ? endAtTs.toDate() : null;
    const isConfirmed = after.isConfirmed as boolean;

    const beforeStartAt =
      (before.startAt as admin.firestore.Timestamp).toDate();
    const beforeEndAtTs = before.endAt as admin.firestore.Timestamp | null;
    const beforeEndAt = beforeEndAtTs ? beforeEndAtTs.toDate() : null;

    const slotEntry = createSlotEntry(
      promiseId, "promise", title, emoji, startAt, endAt,
      isConfirmed ? "confirmed" : "pending",
    );

    // 새로 accepted된 사용자
    const newlyAccepted = afterAccepted.filter(
      (id) => !beforeAccepted.includes(id),
    );
    // accepted에서 빠진 사용자
    const newlyRemoved = beforeAccepted.filter(
      (id) => !afterAccepted.includes(id),
    );
    // 여전히 accepted인 사용자
    const stillAccepted = afterAccepted.filter(
      (id) => beforeAccepted.includes(id),
    );

    const timeChanged =
      beforeStartAt.getTime() !== startAt.getTime() ||
      (beforeEndAt?.getTime() ?? 0) !== (endAt?.getTime() ?? 0);
    const dataChanged =
      before.title !== after.title ||
      before.emoji !== after.emoji ||
      before.isConfirmed !== after.isConfirmed;

    const ops: Promise<void>[] = [];

    // 새로 accepted → 슬롯 추가
    for (const uid of newlyAccepted) {
      ops.push(upsertSlot(uid, slotEntry));
    }

    // removed → 슬롯 제거 (이전 시간 기준)
    for (const uid of newlyRemoved) {
      ops.push(removeSlot(uid, promiseId, beforeStartAt, beforeEndAt));
    }

    // 시간/제목/확정상태 변경 → 기존 accepted 전원 갱신
    if (timeChanged || dataChanged) {
      for (const uid of stillAccepted) {
        if (timeChanged) {
          ops.push(removeSlot(uid, promiseId, beforeStartAt, beforeEndAt));
        }
        ops.push(upsertSlot(uid, slotEntry));
      }
    }

    await Promise.all(ops);

    console.log(
      `📅 Slot updated: promise/${promiseId} ` +
      `(+${newlyAccepted.length}, -${newlyRemoved.length}, ` +
      `~${(timeChanged || dataChanged) ? stillAccepted.length : 0})`,
    );
  },
);

/**
 * 약속 삭제 시 모든 accepted 사용자의 scheduleSlots에서 제거
 */
export const onPromiseDeletedSlot = onDocumentDeleted(
  {document: "promises/{promiseId}", region: REGION},
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) return;

    const data = snapshot.data();
    const promiseId = event.params.promiseId;
    const accepted = (data.votes?.accepted as string[]) ?? [];
    const startAt = (data.startAt as admin.firestore.Timestamp).toDate();
    const endAtTs = data.endAt as admin.firestore.Timestamp | null;
    const endAt = endAtTs ? endAtTs.toDate() : null;

    await Promise.all(
      accepted.map((uid) => removeSlot(uid, promiseId, startAt, endAt)),
    );

    console.log(
      `📅 Slot deleted: promise/${promiseId} → ${accepted.length} users`,
    );
  },
);

// ============================================================================
// Firestore Triggers: PersonalEvent → scheduleSlots
// ============================================================================

/**
 * 개인 일정 생성 시 scheduleSlots에 추가
 */
export const onPersonalEventCreatedSlot = onDocumentCreated(
  {document: "users/{userId}/personalEvents/{eventId}", region: REGION},
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) return;

    const data = snapshot.data();
    const userId = event.params.userId;
    const eventId = event.params.eventId;
    const title = data.title as string;
    const emoji = (data.emoji as string) || null;
    const startAt = (data.startAt as admin.firestore.Timestamp).toDate();
    const endAtTs = data.endAt as admin.firestore.Timestamp | null;
    const endAt = endAtTs ? endAtTs.toDate() : null;

    const slotEntry = createSlotEntry(
      eventId, "personalEvent", title, emoji, startAt, endAt, "confirmed",
    );

    await upsertSlot(userId, slotEntry);

    console.log(
      `📅 Slot created: personalEvent/${eventId} → user/${userId}`,
    );
  },
);

/**
 * 개인 일정 수정 시 scheduleSlots 갱신
 */
export const onPersonalEventUpdatedSlot = onDocumentUpdated(
  {document: "users/{userId}/personalEvents/{eventId}", region: REGION},
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!before || !after) return;

    const userId = event.params.userId;
    const eventId = event.params.eventId;

    const title = after.title as string;
    const emoji = (after.emoji as string) || null;
    const startAt = (after.startAt as admin.firestore.Timestamp).toDate();
    const endAtTs = after.endAt as admin.firestore.Timestamp | null;
    const endAt = endAtTs ? endAtTs.toDate() : null;

    const beforeStartAt =
      (before.startAt as admin.firestore.Timestamp).toDate();
    const beforeEndAtTs = before.endAt as admin.firestore.Timestamp | null;
    const beforeEndAt = beforeEndAtTs ? beforeEndAtTs.toDate() : null;

    const timeChanged =
      beforeStartAt.getTime() !== startAt.getTime() ||
      (beforeEndAt?.getTime() ?? 0) !== (endAt?.getTime() ?? 0);

    const slotEntry = createSlotEntry(
      eventId, "personalEvent", title, emoji, startAt, endAt, "confirmed",
    );

    if (timeChanged) {
      await removeSlot(userId, eventId, beforeStartAt, beforeEndAt);
    }

    await upsertSlot(userId, slotEntry);

    console.log(
      `📅 Slot updated: personalEvent/${eventId} → user/${userId}`,
    );
  },
);

/**
 * 개인 일정 삭제 시 scheduleSlots에서 제거
 */
export const onPersonalEventDeletedSlot = onDocumentDeleted(
  {document: "users/{userId}/personalEvents/{eventId}", region: REGION},
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) return;

    const data = snapshot.data();
    const userId = event.params.userId;
    const eventId = event.params.eventId;
    const startAt = (data.startAt as admin.firestore.Timestamp).toDate();
    const endAtTs = data.endAt as admin.firestore.Timestamp | null;
    const endAt = endAtTs ? endAtTs.toDate() : null;

    await removeSlot(userId, eventId, startAt, endAt);

    console.log(
      `📅 Slot deleted: personalEvent/${eventId} → user/${userId}`,
    );
  },
);
