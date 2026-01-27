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
// Widget Silent Push Functions (홈 화면 위젯 갱신)
// ============================================================================
export {
  onPromiseCreatedWidgetPush,
  onPromiseUpdatedWidgetPush,
  onPromiseDeletedWidgetPush,
} from "./functions/widgetPush";
