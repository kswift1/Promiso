/**
 * Promiso Firebase Functions
 *
 * 도메인별 함수들을 re-export하는 진입점입니다.
 */

// ============================================================================
// User Functions
// ============================================================================
export {
  createUser,
  getUser,
  updateUser,
  uploadProfileImage,
  checkNicknameAvailable,
  deleteUser,
} from "./functions/users";

// ============================================================================
// Group Functions
// ============================================================================
export {
  createGroup,
  previewGroup,
  joinGroup,
  leaveGroup,
  updateGroup,
  deleteGroup,
  transferGroupHost,
  expelMember,
  onGroupImageUpdated,
} from "./functions/groups";

// ============================================================================
// Promise Functions
// ============================================================================
export {
  createPromise,
  respondPromise,
  updatePromise,
  deletePromise,
  getConfirmedPromisesForCalendar,
} from "./functions/promises";

// ============================================================================
// Notification Functions
// ============================================================================
export {
  sendPushNotification,
  onPromiseCreated,
  onPromiseVotesUpdated,
  onPromiseInfoUpdated,
  onGroupMemberJoined,
} from "./functions/notifications";

// ============================================================================
// LiveActivity Functions
// ============================================================================
export {
  registerPushToStartToken,
  startLiveActivity,
  updateETA,
  widgetUpdateETA,
  executeLiveActivityStart,
  executeLiveActivityEnd,
  executeETASharingNudge,
  onPromiseConfirmedScheduleLiveActivity,
} from "./functions/liveActivity";

// ============================================================================
// Emoji Functions
// ============================================================================
export {generateEmoji} from "./functions/emoji";

// ============================================================================
// Promise Badge Functions (신규 소식 배지 관리)
// ============================================================================
export {
  onPromiseCreatedBadges,
  clearGroupBadge,
} from "./functions/promiseBadges";

// ============================================================================
// Widget Functions (위젯용 약속 API - Direct Query)
// ============================================================================
export {
  getWidgetSnapshot,
  getWidgetSnapshotWithToken,
} from "./functions/widget";

// ============================================================================
// Widget Token Functions (Widget 전용 Long-lived Token)
// ============================================================================
export {generateWidgetToken} from "./functions/widgetToken";

// ============================================================================
// FAQ Functions (Notion 프록시)
// ============================================================================
export {getFAQs} from "./functions/faq";

// ============================================================================
// Kakao Map Functions (Kakao REST API 프록시)
// ============================================================================
export {searchPlaces} from "./functions/kakaoMap";

// ============================================================================
// Weather Functions (기상청 API 프록시)
// ============================================================================
export {getWeather} from "./functions/weather";

// ============================================================================
// Schedule Conflict Functions (일정 충돌 감지 + scheduleSlots 비정규화)
// ============================================================================
export {
  checkScheduleConflicts,
  onPromiseCreatedSlot,
  onPromiseUpdatedSlot,
  onPromiseDeletedSlot,
  onPersonalEventCreatedSlot,
  onPersonalEventUpdatedSlot,
  onPersonalEventDeletedSlot,
} from "./functions/scheduleConflicts";

