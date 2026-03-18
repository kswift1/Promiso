/**
 * Schedule Conflict Functions
 *
 * 일정 충돌 감지 Cloud Functions + Firestore Triggers
 * scheduleSlots 비정규화로 O(1) 충돌 체크
 *
 * @path users/{userId}/scheduleSlots/{YYYY-MM-DD}
 * @ios ScheduleConflictClient
 */

import {FieldValue, Timestamp} from "firebase-admin/firestore";
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

const MAX_SLOT_DATE_RANGE_DAYS = 31;
export const MILLISECONDS_PER_DAY = 24 * 60 * 60 * 1000;

export type LocalDate = {
  year: number;
  month: number;
  day: number;
};

type LocalDateTime = LocalDate & {
  hour: number;
  minute: number;
  second: number;
};

export type TimeComponents = {
  hour: number;
  minute: number;
};

const dateFormatterCache = new Map<string, Intl.DateTimeFormat>();
const dateTimeFormatterCache = new Map<string, Intl.DateTimeFormat>();

// ============================================================================
// Helpers
// ============================================================================

/**
 * startAt~endAt 범위에 걸치는 모든 UTC YYYY-MM-DD 키 반환
 *
 * @param {Date} startAt 시작 시간
 * @param {Date} endAt 종료 시간
 * @param {number} maxDays 최대 날짜 수
 * @return {string[]} YYYY-MM-DD 키 배열
 */
function getDateKeys(
  startAt: Date,
  endAt: Date,
  maxDays: number = Number.MAX_SAFE_INTEGER,
): { keys: string[]; isTruncated: boolean } {
  const keys: string[] = [];
  const current = new Date(startAt);
  current.setUTCHours(0, 0, 0, 0);

  const endDate = new Date(endAt);
  endDate.setUTCHours(0, 0, 0, 0);

  while (current <= endDate) {
    keys.push(current.toISOString().slice(0, 10));
    current.setUTCDate(current.getUTCDate() + 1);

    if (keys.length >= maxDays && current <= endDate) {
      return {keys, isTruncated: true};
    }
  }

  return {keys, isTruncated: false};
}

/**
 * 일정 범위가 최대 허용 기간 내인지 검증
 *
 * @param {Date} startAt 시작 시간
 * @param {Date} endAt 종료 시간
 */
function assertDateRangeWithinLimit(startAt: Date, endAt: Date): void {
  const rangeMs = endAt.getTime() - startAt.getTime();
  const maxRangeMs = MAX_SLOT_DATE_RANGE_DAYS * MILLISECONDS_PER_DAY;

  if (rangeMs > maxRangeMs) {
    throw new HttpsError(
      "invalid-argument",
      `일정 조회 범위는 ${MAX_SLOT_DATE_RANGE_DAYS}일 이내여야 합니다`,
    );
  }
}

/**
 * 날짜 포맷터를 캐시에서 가져오거나 새로 생성
 *
 * @param {string} timeZone IANA 타임존 문자열
 * @return {Intl.DateTimeFormat} 날짜 포맷터
 */
function getDateFormatter(timeZone: string): Intl.DateTimeFormat {
  const cached = dateFormatterCache.get(timeZone);
  if (cached) return cached;

  const formatter = new Intl.DateTimeFormat("en-CA", {
    timeZone,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  });
  dateFormatterCache.set(timeZone, formatter);
  return formatter;
}

/**
 * 날짜+시간 포맷터를 캐시에서 가져오거나 새로 생성
 *
 * @param {string} timeZone IANA 타임존 문자열
 * @return {Intl.DateTimeFormat} 날짜+시간 포맷터
 */
function getDateTimeFormatter(timeZone: string): Intl.DateTimeFormat {
  const cached = dateTimeFormatterCache.get(timeZone);
  if (cached) return cached;

  const formatter = new Intl.DateTimeFormat("en-CA", {
    timeZone,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
    second: "2-digit",
    hourCycle: "h23",
  });
  dateTimeFormatterCache.set(timeZone, formatter);
  return formatter;
}

/**
 * DateTimeFormat 파트를 파싱해 숫자 맵으로 반환
 *
 * @param {Intl.DateTimeFormat} formatter 포맷터 인스턴스
 * @param {Date} date 변환할 날짜
 * @return {Record<string, number>} 파트 타입 → 숫자 값 맵
 */
function parseFormatterParts(
  formatter: Intl.DateTimeFormat,
  date: Date,
): Record<string, number> {
  return formatter
    .formatToParts(date)
    .reduce<Record<string, number>>((result, part) => {
      if (part.type !== "literal") {
        result[part.type] = Number(part.value);
      }
      return result;
    }, {});
}

/**
 * UTC Date를 지정 타임존의 로컬 날짜로 변환
 *
 * @param {Date} date 변환할 UTC 날짜
 * @param {string} timeZone IANA 타임존 문자열
 * @return {LocalDate} 로컬 날짜 (year/month/day)
 */
export function getLocalDate(date: Date, timeZone: string): LocalDate {
  const parts = parseFormatterParts(getDateFormatter(timeZone), date);
  return {
    year: parts.year,
    month: parts.month,
    day: parts.day,
  };
}

/**
 * UTC Date를 지정 타임존의 로컬 날짜+시간으로 변환
 *
 * @param {Date} date 변환할 UTC 날짜
 * @param {string} timeZone IANA 타임존 문자열
 * @return {LocalDateTime} 로컬 날짜+시간 (year/month/day/hour/minute/second)
 */
function getLocalDateTime(date: Date, timeZone: string): LocalDateTime {
  const parts = parseFormatterParts(getDateTimeFormatter(timeZone), date);
  return {
    year: parts.year,
    month: parts.month,
    day: parts.day,
    hour: parts.hour,
    minute: parts.minute,
    second: parts.second,
  };
}

/**
 * LocalDate를 YYYY-MM-DD 형식 문자열로 변환
 *
 * @param {LocalDate} date 로컬 날짜
 * @return {string} YYYY-MM-DD 형식 날짜 키
 */
export function localDateKey(date: LocalDate): string {
  return [
    String(date.year).padStart(4, "0"),
    String(date.month).padStart(2, "0"),
    String(date.day).padStart(2, "0"),
  ].join("-");
}

/**
 * 두 LocalDate를 비교
 *
 * @param {LocalDate} a 첫 번째 날짜
 * @param {LocalDate} b 두 번째 날짜
 * @return {number} 음수(a < b), 0(같음), 양수(a > b)
 */
export function compareLocalDates(a: LocalDate, b: LocalDate): number {
  if (a.year !== b.year) return a.year - b.year;
  if (a.month !== b.month) return a.month - b.month;
  return a.day - b.day;
}

/**
 * 두 LocalDate 중 더 늦은 날짜 반환
 *
 * @param {LocalDate} a 첫 번째 날짜
 * @param {LocalDate} b 두 번째 날짜
 * @return {LocalDate} 더 늦은 날짜
 */
export function maxLocalDate(a: LocalDate, b: LocalDate): LocalDate {
  return compareLocalDates(a, b) >= 0 ? a : b;
}

/**
 * 두 LocalDate 중 더 이른 날짜 반환
 *
 * @param {LocalDate} a 첫 번째 날짜
 * @param {LocalDate} b 두 번째 날짜
 * @return {LocalDate} 더 이른 날짜
 */
export function minLocalDate(a: LocalDate, b: LocalDate): LocalDate {
  return compareLocalDates(a, b) <= 0 ? a : b;
}

/**
 * LocalDate에 일수를 더해 새 LocalDate 반환
 *
 * @param {LocalDate} date 기준 날짜
 * @param {number} days 더할 일수 (음수 가능)
 * @return {LocalDate} 계산된 날짜
 */
export function addDays(date: LocalDate, days: number): LocalDate {
  const next = new Date(Date.UTC(date.year, date.month - 1, date.day));
  next.setUTCDate(next.getUTCDate() + days);
  return {
    year: next.getUTCFullYear(),
    month: next.getUTCMonth() + 1,
    day: next.getUTCDate(),
  };
}

/**
 * 해당 연월의 마지막 날짜(일수) 반환
 *
 * @param {number} year 연도
 * @param {number} month 월 (1~12)
 * @return {number} 해당 월의 마지막 날 (28~31)
 */
export function getDaysInMonth(year: number, month: number): number {
  return new Date(Date.UTC(year, month, 0)).getUTCDate();
}

/**
 * LocalDate의 요일을 반환 (iOS CalendarKit 기준: 월=2, 화=3, ..., 일=1)
 *
 * @param {LocalDate} date 로컬 날짜
 * @return {number} 요일 번호 (일=1, 월=2, 화=3, 수=4, 목=5, 금=6, 토=7)
 */
export function getWeekday(date: LocalDate): number {
  const jsWeekday = new Date(
    Date.UTC(date.year, date.month - 1, date.day, 12),
  ).getUTCDay();
  return jsWeekday === 0 ? 1 : jsWeekday + 1;
}

/**
 * LocalDateTime을 비교용 밀리초로 변환 (UTC 기준, 타임존 오프셋 무시)
 *
 * @param {LocalDateTime} date 로컬 날짜+시간
 * @return {number} 비교용 밀리초 값
 */
function localDateTimeToComparableMs(date: LocalDateTime): number {
  return Date.UTC(
    date.year,
    date.month - 1,
    date.day,
    date.hour,
    date.minute,
    date.second,
    0,
  );
}

/**
 * 지정 타임존에서 특정 날짜+시간을 UTC Date로 변환
 *
 * @param {LocalDate} date 로컬 날짜
 * @param {TimeComponents} time 시간 구성요소 (hour, minute)
 * @param {string} timeZone IANA 타임존 문자열
 * @return {Date} UTC Date 객체
 */
export function makeDateInTimeZone(
  date: LocalDate,
  time: TimeComponents,
  timeZone: string,
): Date {
  const target: LocalDateTime = {
    ...date,
    hour: time.hour,
    minute: time.minute,
    second: 0,
  };

  let candidate = new Date(Date.UTC(
    date.year,
    date.month - 1,
    date.day,
    time.hour,
    time.minute,
    0,
    0,
  ));

  for (let i = 0; i < 3; i++) {
    const zoned = getLocalDateTime(candidate, timeZone);
    const diffMs =
      localDateTimeToComparableMs(zoned) -
      localDateTimeToComparableMs(target);

    if (diffMs === 0) {
      return candidate;
    }

    candidate = new Date(candidate.getTime() - diffMs);
  }

  return candidate;
}

/**
 * 반복 일정 슬롯 ID에서 시리즈 ID 추출
 *
 * @param {string} slotId 슬롯 ID (예: recurring_{seriesId}_{YYYY-MM-DD})
 * @return {string | null} 시리즈 ID, 파싱 실패 시 null
 */
function getRecurringSeriesId(slotId: string): string | null {
  const match = /^recurring_(.+)_\d{4}-\d{2}-\d{2}$/.exec(slotId);
  return match?.[1] ?? null;
}

/**
 * 슬롯이 제외 목록에 포함되는지 확인 (반복 일정은 시리즈 ID도 검사)
 *
 * @param {ScheduleSlotEntry} slot 검사할 슬롯
 * @param {Set<string>} excludeIds 제외할 ID 집합
 * @return {boolean} 제외 대상이면 true
 */
function shouldExcludeSlot(
  slot: ScheduleSlotEntry,
  excludeIds: Set<string>,
): boolean {
  if (excludeIds.has(slot.id)) return true;

  if (slot.type !== "recurringPersonalEvent") {
    return false;
  }

  const seriesId = getRecurringSeriesId(slot.id);
  return seriesId ? excludeIds.has(seriesId) : false;
}

/**
 * ScheduleSlotEntry 생성 헬퍼
 *
 * @param {string} id - 일정 ID
 * @param {"promise" | "personalEvent" | "recurringPersonalEvent"} type - 일정 종류
 * @param {string} title - 일정 제목
 * @param {string | null} emoji - 이모지
 * @param {Date} startAt - 시작 시간
 * @param {Date | null} endAt - 종료 시간
 * @param {"confirmed" | "pending"} severity - 확정 상태
 * @return {ScheduleSlotEntry} 슬롯 엔트리 (startAt/endAt은 Timestamp)
 */
export function createSlotEntry(
  id: string,
  type: "promise" | "personalEvent" | "recurringPersonalEvent",
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
    startAt: Timestamp.fromDate(startAt),
    endAt: endAt ? Timestamp.fromDate(endAt) : null,
    severity,
  };
}

/**
 * 반복 일정 문서를 쿼리 범위 내 ScheduleSlotEntry 배열로 확장
 *
 * @param {string} eventId - 반복 일정 문서 ID
 * @param {FirebaseFirestore.DocumentData} data - Firestore 문서 데이터
 * @param {Date} queryStartAt - 조회 범위 시작 (minGap 포함)
 * @param {Date} queryEndAt - 조회 범위 종료 (minGap 포함)
 * @param {string} timeZone - 반복 일정 기준 IANA 타임존 문자열
 * @return {ScheduleSlotEntry[]} 확장된 슬롯 목록
 */
export function expandRecurringEvent(
  eventId: string,
  data: FirebaseFirestore.DocumentData,
  queryStartAt: Date,
  queryEndAt: Date,
  timeZone: string,
): ScheduleSlotEntry[] {
  const results: ScheduleSlotEntry[] = [];

  // 기본 필드 파싱
  const title = (data.title as string) ?? "";
  const emoji = (data.emoji as string) || null;

  const startTimeRaw = data.startTime as TimeComponents | null;
  const endTimeRaw = data.endTime as TimeComponents | null;

  if (!startTimeRaw) return results;

  const recurrence = data.recurrence as {
    frequency: "daily" | "weekly" | "monthly";
    daysOfWeek: number[] | null;
    dayOfMonth: number | null;
    seriesEndDate: Timestamp | null;
  } | null;

  if (!recurrence) return results;

  const seriesStartDateTs = data.seriesStartDate as Timestamp | null;
  if (!seriesStartDateTs) return results;
  const seriesStartDate = seriesStartDateTs.toDate();

  const seriesEndDate = recurrence.seriesEndDate ?
    recurrence.seriesEndDate.toDate() :
    null;

  const excludedDates = (data.excludedDates as string[] | null) ?? [];
  const overrides = (data.overrides as Record<string, {
    title?: string;
    startTime?: { hour: number; minute: number };
    endTime?: { hour: number; minute: number };
    isCancelled?: boolean;
  }> | null) ?? {};

  const seriesStartLocalDate = getLocalDate(seriesStartDate, timeZone);
  const queryStartLocalDate = getLocalDate(queryStartAt, timeZone);
  const queryEndLocalDate = getLocalDate(queryEndAt, timeZone);

  // 유효 범위: [max(seriesStart, queryStart), min(seriesEnd, queryEnd)]
  const effectiveStart = maxLocalDate(
    seriesStartLocalDate,
    queryStartLocalDate,
  );
  const effectiveEnd = seriesEndDate ?
    minLocalDate(getLocalDate(seriesEndDate, timeZone), queryEndLocalDate) :
    queryEndLocalDate;

  if (compareLocalDates(effectiveStart, effectiveEnd) > 0) return results;

  // 후보 날짜 생성 (사용자 로컬 날짜 기준)
  const candidateDates: LocalDate[] = [];
  const {frequency} = recurrence;

  if (frequency === "daily") {
    let current = effectiveStart;
    while (compareLocalDates(current, effectiveEnd) <= 0) {
      candidateDates.push(current);
      current = addDays(current, 1);
    }
  } else if (frequency === "weekly") {
    const daysOfWeek = recurrence.daysOfWeek ?? [];
    if (daysOfWeek.length === 0) return results;

    let current = effectiveStart;
    while (compareLocalDates(current, effectiveEnd) <= 0) {
      if (daysOfWeek.includes(getWeekday(current))) {
        candidateDates.push(current);
      }
      current = addDays(current, 1);
    }
  } else if (frequency === "monthly") {
    const {dayOfMonth} = recurrence;
    if (!dayOfMonth) return results;

    // 최대 24개월 안전장치
    const startYear = effectiveStart.year;
    const startMonth = effectiveStart.month;
    const endYear = effectiveEnd.year;
    const endMonth = effectiveEnd.month;

    const totalMonths = (endYear - startYear) * 12 + (endMonth - startMonth);
    const maxMonths = Math.min(totalMonths, 23); // 최대 24개월(인덱스 0~23)

    for (let i = 0; i <= maxMonths; i++) {
      const zeroBasedMonth = startMonth - 1 + i;
      const year = startYear + Math.floor(zeroBasedMonth / 12);
      const month = (zeroBasedMonth % 12) + 1;
      const lastDay = getDaysInMonth(year, month);

      if (dayOfMonth > lastDay) {
        continue;
      }

      const candidate = {year, month, day: dayOfMonth};
      if (
        compareLocalDates(candidate, effectiveStart) >= 0 &&
        compareLocalDates(candidate, effectiveEnd) <= 0
      ) {
        candidateDates.push(candidate);
      }
    }
  }

  // 각 후보 날짜를 슬롯으로 변환
  for (const date of candidateDates) {
    const dateKey = localDateKey(date);

    // excludedDates 확인
    if (excludedDates.includes(dateKey)) continue;

    // override 확인
    const override = overrides[dateKey];
    if (override?.isCancelled) continue;

    // startTime/endTime 결정 (override 우선)
    const effectiveStartTime = override?.startTime ?? startTimeRaw;
    const effectiveEndTime = override?.endTime ?? endTimeRaw;
    const effectiveTitle = override?.title ?? title;

    const slotStart = makeDateInTimeZone(
      date,
      effectiveStartTime,
      timeZone,
    );

    let slotEnd: Date | null = null;
    if (effectiveEndTime) {
      let endDate = makeDateInTimeZone(
        date,
        effectiveEndTime,
        timeZone,
      );
      // endTime < startTime이면 다음날 자정 넘김 처리
      if (endDate.getTime() < slotStart.getTime()) {
        endDate = new Date(endDate.getTime() + MILLISECONDS_PER_DAY);
      }
      slotEnd = endDate;
    }

    const slotId = `recurring_${eventId}_${dateKey}`;
    results.push(createSlotEntry(
      slotId,
      "recurringPersonalEvent",
      effectiveTitle,
      emoji,
      slotStart,
      slotEnd,
      "confirmed",
    ));
  }

  return results;
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
  const startAt = slotEntry.startAt.toDate();
  const endAt = slotEntry.endAt ?
    slotEntry.endAt.toDate() :
    startAt;

  const {keys: dateKeys, isTruncated} = getDateKeys(
    startAt,
    endAt,
    MAX_SLOT_DATE_RANGE_DAYS,
  );
  if (isTruncated) {
    console.warn(
      `⚠️ upsertSlot: 기간이 너무 김 (${slotEntry.id}), ` +
      `최대 ${MAX_SLOT_DATE_RANGE_DAYS}일만 반영됩니다`,
    );
  }

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
  const effectiveEnd = endAt ?? startAt;
  const {keys: dateKeys, isTruncated} = getDateKeys(
    startAt,
    effectiveEnd,
    MAX_SLOT_DATE_RANGE_DAYS,
  );
  if (isTruncated) {
    console.warn(
      `⚠️ removeSlot: 기간이 너무 김 (${slotId}), ` +
      `최대 ${MAX_SLOT_DATE_RANGE_DAYS}일만 반영됩니다`,
    );
  }

  await Promise.all(dateKeys.map((dateKey) => {
    const docRef = db
      .collection("users").doc(userId)
      .collection("scheduleSlots").doc(dateKey);

    return db.runTransaction(async (tx) => {
      const doc = await tx.get(docRef);
      if (!doc.exists) return;

      const slots: ScheduleSlotEntry[] = doc.data()?.slots ?? [];
      const filtered = slots.filter((s) => s.id !== slotId);

      if (filtered.length === slots.length) {
        return;
      }

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

      // Pro 구독 상태 확인
      const subDoc = await admin.firestore()
        .collection("subscriptions").doc(userId).get();
      const subStatus = subDoc.data()?.status as string | undefined;
      const isPro = subStatus === "subscribed" || subStatus === "lifetime" ||
        subStatus === "gracePeriod";
      if (!isPro) {
        throw new HttpsError(
          "permission-denied",
          "Pro 구독이 필요한 기능입니다",
        );
      }

      if (!data.startAt) {
        throw new HttpsError(
          "invalid-argument",
          "시작 시간은 필수입니다",
        );
      }

      const startAt = new Date(data.startAt);
      const endAt = data.endAt ?
        new Date(data.endAt) :
        new Date(startAt.getTime());
      const minGapMinutes = typeof data.minGapMinutes === "number" ?
        Math.max(0, Math.floor(data.minGapMinutes)) :
        0;
      const minGapMs = minGapMinutes * 60 * 1000;
      const excludeIds = new Set(data.excludeIds ?? []);
      const timeZone = typeof data.timeZone === "string" && data.timeZone ?
        data.timeZone :
        "UTC";

      // dateKey 조회 범위를 minGap만큼 확장 (기존 일정이 gap 안에 있을 수 있으므로)
      const queryStartAt = new Date(startAt.getTime() - minGapMs);
      const queryEndAt = new Date(endAt.getTime() + minGapMs);
      assertDateRangeWithinLimit(queryStartAt, queryEndAt);

      // 해당 날짜 범위의 scheduleSlots 조회
      const {keys: dateKeys, isTruncated} = getDateKeys(
        queryStartAt,
        queryEndAt,
        MAX_SLOT_DATE_RANGE_DAYS,
      );
      if (isTruncated) {
        throw new HttpsError(
          "invalid-argument",
          `일정 조회 범위는 ${MAX_SLOT_DATE_RANGE_DAYS}일 이내여야 합니다`,
        );
      }
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

      // --- 반복 일정 확장 추가 ---
      const recurringEventsSnap = await db
        .collection("users").doc(userId)
        .collection("recurringEvents").get();

      let expandedCount = 0;
      for (const doc of recurringEventsSnap.docs) {
        const recurringData = doc.data();
        const expanded = expandRecurringEvent(
          doc.id,
          recurringData,
          queryStartAt,
          queryEndAt,
          timeZone,
        );
        for (const slot of expanded) {
          if (!allSlots.has(slot.id)) {
            allSlots.set(slot.id, slot);
            expandedCount++;
          }
        }
      }

      if (expandedCount > 0) {
        console.log(
          `🔄 recurringEvents expanded: ${expandedCount} slots ` +
          `from ${recurringEventsSnap.size} series`,
        );
      }

      // 겹침 판정
      const conflicts: ScheduleConflictItem[] = [];
      for (const [, slot] of allSlots) {
        if (shouldExcludeSlot(slot, excludeIds)) continue;

        const slotStart = slot.startAt.toDate();
        const slotEnd = slot.endAt ?
          slot.endAt.toDate() :
          slotStart;

        const slotStartMs = slotStart.getTime();
        const slotEndMs = slotEnd.getTime();
        const startAtMs = startAt.getTime();
        const endAtMs = endAt.getTime();

        // 겹침 조건: zero-duration(endAt 없는) 일정은 경계 포함 판정
        let isOverlapping: boolean;
        if (startAtMs === endAtMs && slotStartMs === slotEndMs) {
          // 둘 다 zero-duration: 같은 시점이면 겹침
          isOverlapping = startAtMs === slotStartMs;
        } else if (startAtMs === endAtMs) {
          // 새 일정이 zero-duration: 기존 일정 범위 내 포함 시 겹침
          isOverlapping = startAtMs >= slotStartMs && startAtMs < slotEndMs;
        } else if (slotStartMs === slotEndMs) {
          // 기존 일정이 zero-duration: 새 일정 범위 내 포함 시 겹침
          isOverlapping = slotStartMs >= startAtMs && slotStartMs < endAtMs;
        } else {
          // 둘 다 범위: 표준 겹침 조건
          isOverlapping = slotStart < endAt && slotEnd > startAt;
        }

        // gap 계산: 두 일정 사이 여유 시간 (ms)
        // 겹치면 음수, 접점이면 0, 떨어져있으면 양수
        const rawGapMs = Math.max(slotStartMs - endAtMs, startAtMs - slotEndMs);

        // 충돌 조건: 겹침 OR gap이 minGap 미만
        const isConflict = isOverlapping ||
          (minGapMs > 0 && rawGapMs >= 0 && rawGapMs < minGapMs);

        if (isConflict) {
          let overlapMinutes = 0;
          let gapMinutes = 0;

          if (isOverlapping) {
            const overlapStart = Math.max(slotStartMs, startAtMs);
            const overlapEnd = Math.min(slotEndMs, endAtMs);
            overlapMinutes = Math.max(
              0,
              Math.floor((overlapEnd - overlapStart) / 60000),
            );
            gapMinutes = 0;
          } else {
            overlapMinutes = 0;
            gapMinutes = Math.max(0, Math.floor(rawGapMs / 60000));
          }

          conflicts.push({
            id: slot.id,
            source: slot.type,
            severity: slot.severity,
            title: slot.title,
            emoji: slot.emoji,
            startAt: slot.startAt.toDate().toISOString(),
            endAt: slot.endAt ? slot.endAt.toDate().toISOString() : null,
            overlapMinutes,
            gapMinutes,
          });
        }
      }

      // 겹침 있는 것 먼저 (overlapMinutes 내림차순), 같으면 gap이 작은 것 먼저 (gapMinutes 오름차순)
      conflicts.sort((a, b) => {
        if (a.overlapMinutes !== b.overlapMinutes) {
          return b.overlapMinutes - a.overlapMinutes;
        }
        return a.gapMinutes - b.gapMinutes;
      });

      console.log(
        `🔍 checkScheduleConflicts: userId=${userId}, ` +
        `range=${dateKeys.join(",")}, minGap=${minGapMinutes}m, ` +
        `conflicts=${conflicts.length}`,
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
