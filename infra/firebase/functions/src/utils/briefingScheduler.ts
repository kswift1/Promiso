const ONE_HOUR_MS = 60 * 60 * 1000;
const NEXT_DISPATCH_SEARCH_HOURS = 72;

interface RawBriefingSettings {
  notificationHour?: number;
  timezone?: string;
  language?: string;
  style?: string;
  defaultLocation?: {
    name: string;
    latitude?: number;
    longitude?: number;
    address?: string;
  };
}

interface ConfiguredBriefingSettings {
  notificationHour: number;
  timezone: string;
  language: string;
  style: string;
  defaultLocation: {
    title: string;
    latitude: number;
    longitude: number;
  } | null;
}

interface RawSettingsDocument {
  proSettings?: {
    briefing?: RawBriefingSettings;
  };
}

interface RawBriefingSubscriptionDocument {
  notificationHour?: number;
  timezone?: string;
  language?: string;
  style?: string;
  nextDispatchAt?: Date | string | {toDate: () => Date};
  defaultLocation?: {
    title?: string;
    latitude?: number;
    longitude?: number;
  };
}

export const BRIEFING_SUBSCRIPTIONS_COLLECTION = "briefingSubscriptions";

export interface BriefingTaskPayload {
  uid: string;
  timezone: string;
  language: string;
  style: string;
  notificationHour: number;
  defaultLocation: {
    title: string;
    latitude: number;
    longitude: number;
  } | null;
}

export interface BriefingSubscriptionProjection {
  notificationHour: number;
  timezone: string;
  language: string;
  style: string;
  nextDispatchAt: Date;
  defaultLocation: {
    title: string;
    latitude: number;
    longitude: number;
  } | null;
}

/**
 * 구독 상태 값이 현재 Pro 권한을 부여하는지 판별한다.
 * @param {unknown} status Firestore에 저장된 구독 상태 값.
 * @return {boolean} 활성 Pro 상태 여부.
 */
export function hasActiveSubscription(status: unknown): boolean {
  return (
    status === "subscribed" ||
    status === "lifetime" ||
    status === "gracePeriod"
  );
}

/**
 * 구독 상태와 override를 합쳐 실효 Pro 여부를 계산한다.
 * @param {object} params entitlement 입력값.
 * @param {unknown} params.subscriptionStatus 현재 구독 상태.
 * @param {boolean} params.overrideActive entitlement override 활성 여부.
 * @return {boolean} 현재 브리핑 권한 여부.
 */
export function hasEffectiveProAccess(params: {
  subscriptionStatus: unknown;
  overrideActive: boolean;
}): boolean {
  const {subscriptionStatus, overrideActive} = params;
  return hasActiveSubscription(subscriptionStatus) || overrideActive;
}

/**
 * 사용자 설정 문서에서 브리핑 설정을 정규화한다.
 * @param {unknown} settingsData Firestore settings 문서 데이터.
 * @return {ConfiguredBriefingSettings | null} 유효한 브리핑 설정.
 */
function getConfiguredBriefing(
  settingsData: unknown,
): ConfiguredBriefingSettings | null {
  const data = settingsData as RawSettingsDocument | null | undefined;
  const briefing = data?.proSettings?.briefing;

  if (
    !briefing ||
    typeof briefing.notificationHour !== "number" ||
    briefing.notificationHour < 0 ||
    briefing.notificationHour > 23
  ) {
    return null;
  }

  const SUPPORTED_LANGUAGES = ["ko", "en"];
  const rawLanguage = briefing.language || "ko";
  const language = SUPPORTED_LANGUAGES.includes(rawLanguage) ? rawLanguage : "ko";

  const defaultLocation = briefing.defaultLocation?.name &&
    briefing.defaultLocation?.latitude != null &&
    briefing.defaultLocation?.longitude != null
    ? {
      title: briefing.defaultLocation.name,
      latitude: briefing.defaultLocation.latitude,
      longitude: briefing.defaultLocation.longitude,
    }
    : null;

  return {
    notificationHour: briefing.notificationHour,
    timezone: briefing.timezone || "Asia/Seoul",
    language,
    style: briefing.style || "friendly",
    defaultLocation,
  };
}

/**
 * 현재 시각 이후 다음 브리핑 dispatch 시각을 계산한다.
 * @param {object} params 계산 입력값.
 * @param {Date} params.now 기준 시각.
 * @param {string} params.timezone 사용자 타임존.
 * @param {number} params.notificationHour 사용자 로컬 알림 시각.
 * @return {Date | null} 다음 dispatch 시각. 계산 실패 시 null.
 */
export function computeNextDispatchAt(params: {
  now: Date;
  timezone: string;
  notificationHour: number;
}): Date | null {
  const {now, timezone, notificationHour} = params;
  const start = ceilToNextHour(now);

  for (let offset = 0; offset < NEXT_DISPATCH_SEARCH_HOURS; offset++) {
    const candidate = new Date(start.getTime() + offset * ONE_HOUR_MS);
    if (getHourInTimezone(candidate, timezone) === notificationHour) {
      return candidate;
    }
  }

  console.warn(
    "[BriefingScheduler] Failed to compute nextDispatchAt",
    {timezone, notificationHour},
  );
  return null;
}

/**
 * settings + entitlement 상태로 projection 문서를 계산한다.
 * @param {object} params 계산 입력값.
 * @param {unknown} params.settingsData settings/main 문서 데이터.
 * @param {unknown} params.subscriptionStatus 현재 구독 상태.
 * @param {boolean} params.overrideActive entitlement override 활성 여부.
 * @param {Date} params.now 기준 시각.
 * @return {BriefingSubscriptionProjection | null} 유효한 projection 문서.
 * @throws {Error} dispatch 시각 계산에 실패하면 예외를 던진다.
 */
export function buildBriefingSubscriptionProjection(params: {
  settingsData: unknown;
  subscriptionStatus: unknown;
  overrideActive: boolean;
  now: Date;
}): BriefingSubscriptionProjection | null {
  const {settingsData, subscriptionStatus, overrideActive, now} = params;
  const briefing = getConfiguredBriefing(settingsData);

  if (!briefing || !hasEffectiveProAccess({
    subscriptionStatus,
    overrideActive,
  })) {
    return null;
  }

  const nextDispatchAt = computeNextDispatchAt({
    now,
    timezone: briefing.timezone,
    notificationHour: briefing.notificationHour,
  });

  if (!nextDispatchAt) {
    throw new Error(
      "Failed to compute nextDispatchAt: " +
      `timezone=${briefing.timezone}, hour=${briefing.notificationHour}`,
    );
  }

  return {
    ...briefing,
    nextDispatchAt,
  };
}

/**
 * projection 문서에서 스케줄러 enqueue payload를 만든다.
 * @param {object} params enqueue 입력값.
 * @param {string} params.uid 사용자 ID.
 * @param {unknown} params.projectionData briefingSubscriptions 문서 데이터.
 * @param {Date} params.now 현재 시각.
 * @return {BriefingTaskPayload | null} 지금 enqueue해야 하면 payload.
 */
export function buildScheduledBriefingTaskFromProjection(params: {
  uid: string;
  projectionData: unknown;
  now: Date;
}): BriefingTaskPayload | null {
  const {uid, projectionData, now} = params;
  const projection = getConfiguredProjection(projectionData);

  if (!projection || projection.nextDispatchAt.getTime() > now.getTime()) {
    return null;
  }

  return {
    uid,
    timezone: projection.timezone,
    language: projection.language,
    style: projection.style,
    notificationHour: projection.notificationHour,
    defaultLocation: projection.defaultLocation,
  };
}

/**
 * 이미 enqueue된 브리핑 task가 아직 유효한지 판단한다.
 * @param {object} params 현재 payload와 최신 상태.
 * @param {BriefingTaskPayload} params.payload enqueue된 task payload.
 * @param {unknown} params.settingsData 최신 settings/main 문서 데이터.
 * @param {unknown} params.subscriptionStatus 현재 구독 상태.
 * @param {boolean} params.overrideActive 현재 실효 override 여부.
 * @return {boolean} 실행 가능 여부.
 */
export function isCurrentBriefingTaskEligible(params: {
  payload: BriefingTaskPayload;
  settingsData: unknown;
  subscriptionStatus: unknown;
  overrideActive: boolean;
}): boolean {
  const {
    payload,
    settingsData,
    subscriptionStatus,
    overrideActive,
  } = params;

  if (!hasEffectiveProAccess({subscriptionStatus, overrideActive})) {
    return false;
  }

  const briefing = getConfiguredBriefing(settingsData);
  if (!briefing) {
    return false;
  }

  return briefing.notificationHour === payload.notificationHour;
}

/**
 * projection 문서의 필드를 검증하고 정규화한다.
 * @param {unknown} projectionData briefingSubscriptions 문서 데이터.
 * @return {BriefingSubscriptionProjection | null} 유효한 projection 데이터.
 */
function getConfiguredProjection(
  projectionData: unknown,
): BriefingSubscriptionProjection | null {
  const data =
    projectionData as RawBriefingSubscriptionDocument | null | undefined;

  if (
    !data ||
    typeof data.notificationHour !== "number" ||
    data.notificationHour < 0 ||
    data.notificationHour > 23
  ) {
    return null;
  }

  const nextDispatchAt = toDateValue(data.nextDispatchAt);
  if (!nextDispatchAt) {
    return null;
  }

  const defaultLocation = data.defaultLocation?.title &&
    data.defaultLocation?.latitude != null &&
    data.defaultLocation?.longitude != null
    ? {
      title: data.defaultLocation.title,
      latitude: data.defaultLocation.latitude,
      longitude: data.defaultLocation.longitude,
    }
    : null;

  return {
    notificationHour: data.notificationHour,
    timezone: data.timezone || "Asia/Seoul",
    language: data.language || "ko",
    style: data.style || "friendly",
    nextDispatchAt,
    defaultLocation,
  };
}

/**
 * Firestore Timestamp-like 값을 Date로 변환한다.
 * @param {unknown} value Timestamp 또는 Date 값.
 * @return {Date | null} 변환된 Date.
 */
function toDateValue(value: unknown): Date | null {
  if (value instanceof Date) {
    return isNaN(value.getTime()) ? null : value;
  }

  if (typeof value === "string") {
    const parsed = new Date(value);
    return isNaN(parsed.getTime()) ? null : parsed;
  }

  if (
    value &&
    typeof value === "object" &&
    "toDate" in value &&
    typeof value.toDate === "function"
  ) {
    const parsed = value.toDate();
    return parsed instanceof Date && !isNaN(parsed.getTime()) ?
      parsed :
      null;
  }

  return null;
}

/**
 * 특정 타임존 기준 현재 시각(hour)을 계산한다.
 * @param {Date} date 기준 시각.
 * @param {string} timezone 타임존 식별자.
 * @return {number} 로컬 시각 hour. 실패 시 -1.
 */
function getHourInTimezone(date: Date, timezone: string): number {
  try {
    const formatter = new Intl.DateTimeFormat("en-US", {
      timeZone: timezone,
      hour: "numeric",
      hourCycle: "h23",
    });
    const parsed = parseInt(formatter.format(date), 10);
    if (isNaN(parsed)) {
      console.warn(
        `[BriefingScheduler] Failed to parse hour for tz=${timezone}`,
      );
      return -1;
    }
    return parsed;
  } catch (error) {
    console.warn(
      `[BriefingScheduler] Failed to resolve hour for tz=${timezone}:`,
      error,
    );
    return -1;
  }
}

/**
 * 현재 시각 이후 첫 scheduler 시각으로 올림한다.
 * @param {Date} date 기준 시각.
 * @return {Date} 다음 hour bucket.
 */
function ceilToNextHour(date: Date): Date {
  const rounded = new Date(date);
  const hasSubHourValue =
    rounded.getMinutes() > 0 ||
    rounded.getSeconds() > 0 ||
    rounded.getMilliseconds() > 0;

  rounded.setMinutes(0, 0, 0);
  if (hasSubHourValue) {
    rounded.setTime(rounded.getTime() + ONE_HOUR_MS);
  }

  return rounded;
}
