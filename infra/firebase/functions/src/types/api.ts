/**
 * Firebase Functions API 타입 정의
 *
 * 이 파일은 iOS와 Firebase Functions 간 계약(Contract)을 정의합니다.
 * iOS에서 호출할 때 이 타입 정의를 참고하세요.
 */

// ============================================================================
// createGroup
// ============================================================================

/**
 * 그룹 생성 요청
 *
 * @remarks
 * - 인증 필수 (Firebase Auth)
 * - creatorId는 자동으로 request.auth.uid에서 추출
 */
export interface CreateGroupRequest {
  /** 클라이언트에서 생성한 그룹 ID */
  groupId: string;

  /** 그룹 이름 (최소 2글자 이상) */
  name: string;

  /** 최대 인원 (2 이상) */
  maxMembers: number;

  /** 그룹 설명 (선택적) */
  description?: string | null;

  /** 그룹 이미지 URL (선택적) */
  imageUrl?: string | null;
}

/**
 * 그룹 생성 응답
 */
export interface CreateGroupResponse {
  /** 생성된 그룹 ID (Firestore Document ID) */
  id: string;

  /** 그룹 이름 */
  name: string;

  /** 초대 코드 (6자리 영숫자) */
  inviteCode: string;
}

/**
 * 그룹 생성 에러
 */
export enum CreateGroupError {
  /** 인증되지 않은 사용자 */
  UNAUTHENTICATED = "unauthenticated",

  /** 잘못된 파라미터 */
  INVALID_ARGUMENT = "invalid-argument",

  /** 초대 코드 생성 실패 */
  INTERNAL = "internal",
}

// ============================================================================
// previewGroup
// ============================================================================

/**
 * 그룹 미리보기 요청
 *
 * @remarks
 * - 인증 불필요 (초대 코드만으로 조회 가능)
 * - 실제로 그룹에 참여하지 않고 정보만 조회
 */
export interface PreviewGroupRequest {
  /** 6자리 초대 코드 */
  inviteCode: string;
}

/**
 * 그룹 멤버 미리보기 정보
 */
export interface GroupMemberPreview {
  /** 사용자 ID */
  userId: string;

  /** 사용자 이름 */
  name: string;

  /** 프로필 이미지 */
  profileImage: RemoteImage | null;
}

/**
 * 그룹 미리보기 응답
 */
export interface PreviewGroupResponse {
  /** 그룹 ID */
  groupId: string;

  /** 그룹 이름 */
  groupName: string;

  /** 그룹 설명 */
  description: string | null;

  /** 그룹 이미지 URL */
  imageUrl: string | null;

  /** 최대 인원 */
  maxMembers: number;

  /** 현재 인원 */
  memberCount: number;

  /** 멤버 미리보기 리스트 (최대 10명) */
  members: GroupMemberPreview[];
}

/**
 * 그룹 미리보기 에러
 */
export enum PreviewGroupError {
  /** 잘못된 초대 코드 */
  INVALID_INVITE_CODE = "invalid-argument",

  /** 그룹을 찾을 수 없음 */
  GROUP_NOT_FOUND = "not-found",

  /** 서버 오류 */
  INTERNAL = "internal",
}

// ============================================================================
// joinGroup
// ============================================================================

/**
 * 그룹 참여 요청
 *
 * @remarks
 * - 인증 필수 (Firebase Auth)
 * - userId는 자동으로 request.auth.uid에서 추출
 */
export interface JoinGroupRequest {
  /** 6자리 초대 코드 */
  inviteCode: string;

  /** 참여하려는 사용자 ID (내부적으로 auth.uid 사용, 명시적 파라미터는 검증용) */
  userId?: string;
}

/**
 * 그룹 참여 응답
 */
export interface JoinGroupResponse {
  /** 참여한 그룹 ID */
  groupId: string;

  /** 그룹 이름 */
  groupName: string;
}

/**
 * 그룹 참여 에러
 */
export enum JoinGroupError {
  /** 인증되지 않은 사용자 */
  UNAUTHENTICATED = "unauthenticated",

  /** 잘못된 초대 코드 */
  INVALID_INVITE_CODE = "invalid-argument",

  /** 그룹을 찾을 수 없음 */
  GROUP_NOT_FOUND = "not-found",

  /** 이미 참여한 그룹 */
  ALREADY_MEMBER = "already-exists",

  /** 그룹 정원 초과 */
  GROUP_FULL = "resource-exhausted",

  /** 서버 오류 */
  INTERNAL = "internal",
}

// ============================================================================
// Firestore Group Document Schema
// ============================================================================

/**
 * Firestore groups 컬렉션 스키마
 *
 * @remarks
 * iOS의 GroupModel과 일치해야 합니다.
 */
export interface GroupDocument {
  /** 그룹 이름 */
  name: string;

  /** 그룹 설명 */
  description: string | null;

  /** 그룹 이미지 URL */
  imageUrl: string | null;

  /** 멤버 ID 목록 (users 컬렉션 참조용) */
  memberIds: string[];

  /** 최대 인원 */
  maxMembers: number;

  /** 초대 코드 (6자리) */
  inviteCode: string;

  /** 생성자 UID */
  createdBy: string;

  /** 생성 시각 */
  createdAt: FirebaseFirestore.Timestamp;

  /** 수정 시각 */
  updatedAt: FirebaseFirestore.Timestamp;
}

// ============================================================================
// createPromise
// ============================================================================

/**
 * 약속 생성 요청
 *
 * @remarks
 * - 인증 필수 (Firebase Auth)
 * - hostId는 자동으로 request.auth.uid에서 추출
 */
export interface CreatePromiseRequest {
  /** 그룹 ID */
  groupId: string;

  /** 약속 제목 */
  title: string;

  /** 약속 이모지 (선택적) */
  emoji?: string | null;

  /** 약속 설명 (선택적) */
  description?: string | null;

  /** 시작 시간 (ISO 8601 문자열) */
  startAt: string;

  /** 종료 시간 (선택적, ISO 8601 문자열) */
  endAt?: string | null;

  /** 최소 참가 인원 */
  minimumParticipants: number;

  /** 장소 정보 (선택적) */
  location?: {
    /** 장소 이름 */
    name: string;
    /** 주소 */
    address?: string | null;
    /** 위도 */
    latitude?: number | null;
    /** 경도 */
    longitude?: number | null;
  } | null;

  /** 도착 상황 공유 시작 시간 (분 단위, 선택적) */
  arrivalSharingTime?: number | null;

  /** 첨부 이미지 URL 목록 (선택적, 최대 3장) */
  imageUrls?: string[] | null;
}

/**
 * 약속 생성 응답
 */
export interface CreatePromiseResponse {
  /** 생성된 약속 ID */
  promiseId: string;

  /** 약속 제목 */
  title: string;

  /** 그룹 ID */
  groupId: string;

  /** 시작 시간 */
  startAt: FirebaseFirestore.Timestamp;
}

/**
 * 약속 생성 에러
 */
export enum CreatePromiseError {
  /** 인증 필요 */
  UNAUTHENTICATED = "unauthenticated",

  /** 잘못된 요청 */
  INVALID_ARGUMENT = "invalid-argument",

  /** 그룹을 찾을 수 없음 */
  GROUP_NOT_FOUND = "not-found",

  /** 그룹 멤버가 아님 */
  NOT_GROUP_MEMBER = "permission-denied",

  /** 서버 오류 */
  INTERNAL = "internal",
}

// ============================================================================
// updatePromise
// ============================================================================

/**
 * 약속 수정 요청
 *
 * @remarks
 * - 인증 필수 (Firebase Auth)
 * - 호스트만 수정 가능
 * - 시작 전 약속만 수정 가능 (startAt > now)
 */
export interface UpdatePromiseRequest {
  /** 약속 ID */
  promiseId: string;

  /** 약속 제목 (선택적) */
  title?: string | null;

  /** 약속 이모지 (선택적) */
  emoji?: string | null;

  /** 약속 설명 (선택적) */
  description?: string | null;

  /** 시작 시간 (선택적, ISO 8601 문자열) */
  startAt?: string | null;

  /** 종료 시간 (선택적, ISO 8601 문자열) */
  endAt?: string | null;

  /** 최소 참가 인원 (선택적) */
  minimumParticipants?: number | null;

  /** 실시간 공유 시작 시간 (분 전, 선택적) */
  trackingStartMinutesBefore?: number | null;

  /** 장소 정보 (선택적, null이면 삭제, undefined면 변경 없음) */
  location?: {
    /** 장소 이름 */
    name: string;
    /** 주소 */
    address?: string | null;
    /** 위도 */
    latitude?: number | null;
    /** 경도 */
    longitude?: number | null;
  } | null;

  /** 첨부 이미지 URL 목록 (선택적, null이면 삭제, undefined면 변경 없음, 최대 3장) */
  imageUrls?: string[] | null;
}

/**
 * 약속 수정 응답
 */
export interface UpdatePromiseResponse {
  /** 성공 여부 */
  success: boolean;
}

/**
 * 약속 수정 에러
 */
export enum UpdatePromiseError {
  /** 인증 필요 */
  UNAUTHENTICATED = "unauthenticated",

  /** 잘못된 요청 */
  INVALID_ARGUMENT = "invalid-argument",

  /** 약속을 찾을 수 없음 */
  PROMISE_NOT_FOUND = "not-found",

  /** 호스트만 수정 가능 */
  NOT_HOST = "permission-denied",

  /** 이미 시작된 약속 */
  ALREADY_STARTED = "failed-precondition",

  /** 서버 오류 */
  INTERNAL = "internal",
}

// ============================================================================
// deletePromise
// ============================================================================

/**
 * 약속 삭제 요청
 *
 * @remarks
 * - 인증 필수 (Firebase Auth)
 * - 호스트만 삭제 가능
 * - 시작 전 약속만 삭제 가능
 * - Hard delete: 문서 완전 삭제
 */
export interface DeletePromiseRequest {
  /** 약속 ID */
  promiseId: string;
}

/**
 * 약속 삭제 응답
 */
export interface DeletePromiseResponse {
  /** 성공 여부 */
  success: boolean;
}

// ============================================================================
// respondPromise
// ============================================================================

/**
 * 약속 응답 요청
 *
 * @remarks
 * - 인증 필수 (Firebase Auth)
 * - 그룹 멤버만 응답 가능
 * - votes Map 방식: arrayUnion/arrayRemove로 업데이트
 */
export interface RespondPromiseRequest {
  /** 약속 ID */
  promiseId: string;

  /** 응답 상태 (accepted: 참여 확정, declined: 참여 불가) */
  status: "accepted" | "declined";
}

/**
 * 약속 응답 응답
 */
export interface RespondPromiseResponse {
  /** 약속 ID */
  promiseId: string;

  /** 응답 상태 */
  status: "accepted" | "declined" | "pending";

  /** 약속 확정 여부 (캘린더 동기화용) */
  isConfirmed: boolean;

  /** 확정된 약속 정보 (isConfirmed && status === "accepted"일 때만) */
  confirmedPromise?: CalendarPromise;
}

/**
 * 약속 응답 에러
 */
export enum RespondPromiseError {
  /** 인증 필요 */
  UNAUTHENTICATED = "unauthenticated",

  /** 잘못된 요청 */
  INVALID_ARGUMENT = "invalid-argument",

  /** 약속을 찾을 수 없음 */
  PROMISE_NOT_FOUND = "not-found",

  /** 권한 없음 */
  PERMISSION_DENIED = "permission-denied",

  /** 서버 오류 */
  INTERNAL = "internal",
}

// ============================================================================
// getConfirmedPromisesForCalendar (캘린더 동기화용)
// ============================================================================

/**
 * 캘린더 동기화용 확정 약속 조회 요청
 *
 * @remarks
 * - 인증 필수 (Firebase Auth)
 * - 파라미터 없음 (사용자 ID는 auth에서 추출)
 */
// eslint-disable-next-line @typescript-eslint/no-empty-interface
export interface GetConfirmedPromisesForCalendarRequest {
  // 파라미터 없음
}

/**
 * 캘린더용 약속 정보 (최소 데이터)
 */
export interface CalendarPromise {
  /** 약속 ID */
  id: string;

  /** 약속 제목 */
  title: string;

  /** 약속 이모지 */
  emoji: string;

  /** 시작 시간 (ISO 8601) */
  startAt: string;

  /** 종료 시간 (ISO 8601, nullable) */
  endAt: string | null;

  /** 장소 이름 */
  location: string | null;

  /** 그룹 ID */
  groupId: string;
}

/**
 * 캘린더 동기화용 확정 약속 조회 응답
 */
export interface GetConfirmedPromisesForCalendarResponse {
  /** 확정된 약속 목록 */
  promises: CalendarPromise[];
}

// ============================================================================
// User APIs
// ============================================================================

/**
 * 사용자 생성 요청 (회원가입)
 *
 * @remarks
 * - 인증 필수 (Firebase Auth)
 * - userId는 자동으로 request.auth.uid에서 추출
 * - email은 메인 문서가 아닌 auth 서브컬렉션에만 저장됨
 * - name이 null이면 nickname으로 대체됨
 */
export interface CreateUserRequest {
  /** provider에서 받은 이름 (선택적, null이면 nickname 사용) */
  name?: string | null;

  /** 사용자가 설정한 닉네임 (2~20자) */
  nickname: string;

  /** 인증 제공자 정보 */
  provider: {
    /** 인증 제공자 타입 (google, apple 등) */
    type: string;
    /** 제공자 기준 사용자 ID */
    uid: string;
    /** 제공자에서 받은 이메일 */
    email: string;
  };
}

/**
 * 사용자 생성 응답
 */
export interface CreateUserResponse {
  /** 생성된 사용자 ID (Firebase Auth UID) */
  userId: string;

  /** 계정 생성 시각 */
  createdAt: FirebaseFirestore.Timestamp;
}

/**
 * 사용자 조회 요청
 *
 * @remarks
 * - 인증 필수 (Firebase Auth)
 * - userId 생략 시 본인 정보 조회
 * - isPublic=false: UserPrivateResponse (email, provider 포함, auth 서브컬렉션 읽기)
 * - isPublic=true: UserPublicResponse (email, provider 제외, auth 서브컬렉션 읽기 없음)
 */
export interface GetUserRequest {
  /** 조회할 사용자 ID (생략 시 본인) */
  userId?: string | null;

  /** 공개 정보만 조회할지 여부 (true: auth 서브컬렉션 읽기 생략) */
  isPublic?: boolean | null;
}

/**
 * 사용자 정보 (타인 조회용 - 이메일 제외)
 */
export interface UserPublicResponse {
  /** 사용자 ID */
  userId: string;

  /** provider에서 받은 이름 */
  name: string;

  /** 사용자 설정 닉네임 */
  nickname: string;

  /** 프로필 이미지 정보 */
  profile?: ProfileImage | null;

  /** 메타데이터 */
  metaData: MetaData;

  /** 사용자가 속한 그룹 목록 */
  groups?: { [groupId: string]: UserGroupInfo } | null;
}

/**
 * 사용자 정보 (본인 조회용 - 이메일 포함)
 */
export interface UserPrivateResponse extends UserPublicResponse {
  /** 이메일 주소 (auth 서브컬렉션에서 조회) */
  email: string;

  /** 인증 제공자 타입 (auth 서브컬렉션에서 조회) */
  provider: string;
}

/**
 * 사용자 수정 요청
 *
 * @remarks
 * - 인증 필수 (Firebase Auth)
 * - name, email은 수정 불가 (provider 정보이므로)
 */
export interface UpdateUserRequest {
  /** 닉네임 (2~20자) */
  nickname?: string | null;
}

/**
 * 사용자 수정 응답
 */
export interface UpdateUserResponse {
  /** 성공 여부 */
  success: boolean;

  /** 수정 시각 */
  updatedAt: FirebaseFirestore.Timestamp;
}

/**
 * 프로필 이미지 업로드 요청
 *
 * @remarks
 * - 인증 필수 (Firebase Auth)
 * - iOS에서 먼저 Storage에 업로드 후 경로를 전달
 */
export interface UploadProfileImageRequest {
  /** Firebase Storage에 업로드된 이미지 경로 */
  imagePath: string;
}

/**
 * 프로필 이미지 업로드 응답
 */
export interface UploadProfileImageResponse {
  /** 프로필 이미지 정보 */
  profile: ProfileImage;
}

/**
 * 그룹 정렬 옵션 타입
 */
export type GroupSortOptionType =
  | "joinedRecent"
  | "joinedOldest"
  | "nameAscending"
  | "nameDescending"
  | "custom";

/**
 * 그룹 정렬 옵션 (Firestore 저장 형식)
 */
export interface GroupSortOptionData {
  /** 정렬 타입 */
  type: GroupSortOptionType;
  /** 커스텀 정렬 순서 (type이 custom일 때만 사용) */
  order?: string[];
}

/**
 * GroupSortOption 유틸리티 함수
 */
export const GroupSortOption = {
  /**
   * Firestore 데이터에서 읽기
   * @param {unknown} data - Firestore에서 읽은 데이터
   * @return {GroupSortOptionData} 파싱된 정렬 옵션
   */
  read(data: unknown): GroupSortOptionData {
    if (!data || typeof data !== "object") {
      return {type: "joinedRecent"};
    }
    const obj = data as Record<string, unknown>;
    const type = obj.type as GroupSortOptionType;

    if (type === "custom") {
      const order = Array.isArray(obj.order) ? obj.order as string[] : [];
      return {type: "custom", order};
    }

    const validTypes: GroupSortOptionType[] = [
      "joinedRecent", "joinedOldest", "nameAscending", "nameDescending",
    ];
    if (validTypes.includes(type)) {
      return {type};
    }
    return {type: "joinedRecent"};
  },

  /**
   * Firestore에 저장할 형식으로 변환
   * @param {GroupSortOptionData} option - 정렬 옵션
   * @return {Record<string, unknown>} Firestore 저장용 객체
   */
  write(option: GroupSortOptionData): Record<string, unknown> {
    if (option.type === "custom") {
      return {type: "custom", order: option.order ?? []};
    }
    return {type: option.type};
  },
};

/**
 * 사용자 설정 조회 응답
 */
export interface GetUserSettingsResponse {
  /** 알림 활성화 여부 */
  notificationEnabled: boolean;
  /** 사용자 플랜 */
  plan?: "free" | "pro";
  /** 그룹 정렬 옵션 */
  groupSortOption?: GroupSortOptionData;
  /** Pro 전용 설정 */
  proSettings?: ProSettingsData;
}

/** Pro 전용 설정 (Firestore map) */
export interface ProSettingsData {
  /** 브리핑 설정 */
  briefing?: BriefingSettingsData;
  /** 일정 충돌 감지 임계값 (분) */
  conflictDetectionThresholdMinute?: number;
}

/** 브리핑 설정 데이터 */
export interface BriefingSettingsData {
  /** 브리핑 스타일 */
  style?: BriefingStyle;
  /** 알림 시간 (0~23, null이면 알림 OFF) */
  notificationHour?: number | null;
  /** 타임존 */
  timezone?: string;
  /** 언어 */
  language?: string;
  /** 선호 교통수단 */
  preferredTransport?: "all" | "transit" | "car";
}

/**
 * 사용자 설정 수정 요청
 */
export interface UpdateUserSettingsRequest {
  /** 알림 활성화 여부 */
  notificationEnabled?: boolean | null;

  /** 사용자 플랜 */
  plan?: "free" | "pro" | null;

  /** 그룹 정렬 옵션 */
  groupSortOption?: GroupSortOptionData | null;

  /** Pro 전용 설정 */
  proSettings?: ProSettingsData | null;
}

/**
 * 사용자 설정 수정 응답
 */
export interface UpdateUserSettingsResponse {
  /** 성공 여부 */
  success: boolean;
}

// ============================================================================
// checkNicknameAvailable
// ============================================================================

/**
 * 닉네임 중복 검사 요청
 *
 * @remarks
 * - 인증 필수 (Firebase Auth)
 * - 다른 사용자 문서에 직접 접근하지 않고 Cloud Function을 통해 안전하게 검사
 */
export interface CheckNicknameAvailableRequest {
  /** 검사할 닉네임 (2~20자) */
  nickname: string;
}

/**
 * 닉네임 중복 검사 응답
 */
export interface CheckNicknameAvailableResponse {
  /** 사용 가능 여부 */
  available: boolean;

  /** 검사한 닉네임 */
  nickname: string;
}

/**
 * 닉네임 중복 검사 에러
 */
export enum CheckNicknameAvailableError {
  /** 인증 필요 */
  UNAUTHENTICATED = "unauthenticated",

  /** 잘못된 요청 (닉네임 형식 오류) */
  INVALID_ARGUMENT = "invalid-argument",

  /** 서버 오류 */
  INTERNAL = "internal",
}

// ============================================================================
// deleteUser
// ============================================================================

/**
 * 회원 탈퇴 요청
 *
 * @remarks
 * - 인증 필수 (Firebase Auth)
 * - 그룹 호스트인 경우 탈퇴 불가 (먼저 호스트 양도 필요)
 */
// eslint-disable-next-line @typescript-eslint/no-empty-interface
export interface DeleteUserRequest {
  // 별도 파라미터 없음, auth.uid 사용
}

/**
 * 회원 탈퇴 응답
 */
export interface DeleteUserResponse {
  /** 성공 여부 */
  success: boolean;
}

/**
 * 회원 탈퇴 에러
 */
export enum DeleteUserError {
  /** 인증 필요 */
  UNAUTHENTICATED = "unauthenticated",

  /** 그룹 호스트는 탈퇴 불가 */
  IS_GROUP_HOST = "failed-precondition",

  /** 서버 오류 */
  INTERNAL = "internal",
}

// ============================================================================
// Shared
// ============================================================================

export interface RemoteImage {
  type: "storagePath" | "externalURL";
  url: string;
}

/**
 * 프로필 이미지 정보
 */
export interface ProfileImage {
  /** 원본 이미지 URL */
  url: string;

  /** 썸네일 URL (Cloud Functions 자동 생성) */
  thumbUrl?: string | null;

  /** 업데이트 시각 */
  updatedAt: FirebaseFirestore.Timestamp;
}

/**
 * 메타데이터
 */
export interface MetaData {
  /** 생성 시각 */
  createdAt: FirebaseFirestore.Timestamp;

  /** 수정 시각 */
  updatedAt: FirebaseFirestore.Timestamp;
}

// ============================================================================
// User Document Schema (users/{userId}/groups 서브컬렉션 → Map으로 변경)
// ============================================================================

/**
 * 사용자별 그룹 정보 (users/{userId} 문서 내 groups Map)
 */
export interface UserGroupInfo {
  /** 그룹 이름 (캐시) */
  groupName: string;

  /** 사용자 역할 (admin, member) */
  role: string;

  /** 그룹 가입 시각 */
  joinedAt: FirebaseFirestore.Timestamp;

  /** 알림 활성화 여부 */
  notifications: GroupNotificationSettings | boolean;

  /** (레거시) 그룹 알림 상세 설정 */
  notificationPreferences?: { [key: string]: boolean } | null;
}

/**
 * 그룹 알림 상세 설정
 */
export interface GroupNotificationSettings {
  /** 그룹 알림 전체 ON/OFF */
  enabled: boolean;

  /** 약속 관련 알림 설정 */
  promise?: { [key: string]: boolean } | null;

  /** 그룹 관련 알림 설정 */
  group?: { [key: string]: boolean } | null;
}

/**
 * 사용자 문서 스키마 (users/{userId})
 *
 * @remarks
 * - groups는 Map<groupId, UserGroupInfo> 형태
 * - 기존 서브컬렉션 방식에서 Map으로 변경하여 읽기 비용 절감
 * - 사용자가 10개 그룹에 속해도 1회 읽기로 모든 그룹 정보 조회
 */
export interface UserDocument {
  /** 그룹 목록 (groupId를 키로 하는 Map) */
  groups?: {
    [groupId: string]: UserGroupInfo;
  };
}

// ============================================================================
// leaveGroup
// ============================================================================

/**
 * 그룹 나가기 요청
 *
 * @remarks
 * - 인증 필수 (Firebase Auth)
 * - userId는 자동으로 request.auth.uid에서 추출
 * - 호스트(admin)는 나갈 수 없음 (먼저 deleteGroup 해야 함)
 */
export interface LeaveGroupRequest {
  /** 그룹 ID */
  groupId: string;
}

/**
 * 그룹 나가기 응답
 */
export interface LeaveGroupResponse {
  /** 성공 여부 */
  success: boolean;
}

// ============================================================================
// updateGroup
// ============================================================================

/**
 * 그룹 정보 수정 요청
 *
 * @remarks
 * - 인증 필수 (Firebase Auth)
 * - 호스트(admin)만 수정 가능
 * - 설명과 이미지 URL을 수정할 수 있음
 */
export interface UpdateGroupRequest {
  /** 그룹 ID */
  groupId: string;

  /** 그룹 설명 (선택적) */
  description?: string | null;

  /** 그룹 이미지 URL (선택적) */
  imageUrl?: string | null;

  /** 최대 인원 (선택적) */
  maxMembers?: number | null;
}

/**
 * 그룹 정보 수정 응답
 */
export interface UpdateGroupResponse {
  /** 성공 여부 */
  success: boolean;
}

// ============================================================================
// deleteGroup
// ============================================================================

/**
 * 그룹 삭제 요청
 *
 * @remarks
 * - 인증 필수 (Firebase Auth)
 * - 호스트(admin)만 삭제 가능
 * - Hard delete: 문서 완전 삭제 + Storage 이미지 삭제
 */
export interface DeleteGroupRequest {
  /** 그룹 ID */
  groupId: string;
}

/**
 * 그룹 삭제 응답
 */
export interface DeleteGroupResponse {
  /** 성공 여부 */
  success: boolean;
}

// ============================================================================
// transferGroupHost
// ============================================================================

/**
 * 그룹 호스트 양도 요청
 *
 * @remarks
 * - 인증 필수 (Firebase Auth)
 * - 현재 호스트만 호출 가능
 */
export interface TransferGroupHostRequest {
  /** 그룹 ID */
  groupId: string;

  /** 새 호스트 사용자 ID */
  newHostId: string;
}

/**
 * 그룹 호스트 양도 응답
 */
export interface TransferGroupHostResponse {
  /** 성공 여부 */
  success: boolean;
}

/**
 * 그룹 멤버 추방 요청
 *
 * @remarks
 * - 인증 필수 (Firebase Auth)
 * - 현재 호스트만 호출 가능
 */
export interface ExpelMemberRequest {
  /** 그룹 ID */
  groupId: string;

  /** 추방할 멤버 ID */
  memberId: string;
}

/**
 * 그룹 멤버 추방 응답
 */
export interface ExpelMemberResponse {
  /** 성공 여부 */
  success: boolean;
}

// ============================================================================
// Push Notification
// ============================================================================

/**
 * 알림 타입
 *
 * @remarks
 * iOS NotificationType과 동일하게 유지해야 함
 */
export enum NotificationType {
  /** 약속 초대 */
  PromiseInvitation = "promise_invitation",
  /** 약속 리마인더 */
  PromiseReminder = "promise_reminder",
  /** 약속 확정 */
  PromiseConfirmed = "promise_confirmed",
  /** 약속 취소 */
  PromiseCancelled = "promise_cancelled",
  /** 약속 수정 */
  PromiseUpdated = "promise_updated",
  /** 그룹 초대 */
  GroupInvitation = "group_invitation",
  /** 그룹 업데이트 */
  GroupUpdate = "group_update",
  /** 참석 응답 */
  AttendanceResponse = "attendance_response",
  /** 실시간 공유 넛지 */
  LocationSharingReminder = "location_sharing_reminder",
  /** 시스템 알림 */
  System = "system",
}

/**
 * 푸시 알림 전송 요청
 *
 * @remarks
 * - 내부 함수용 (클라이언트에서 직접 호출하지 않음)
 */
export interface SendPushNotificationRequest {
  /** 수신자 userId 목록 */
  userIds: string[];

  /** 알림 타입 */
  type: NotificationType;

  /** 알림 제목 */
  title: string;

  /** 알림 본문 */
  body: string;

  /** 관련 약속 ID */
  promiseId?: string | null;

  /** 관련 그룹 ID */
  groupId?: string | null;

  /** 관련 사용자 ID (발신자 등) */
  relatedUserId?: string | null;

  /** 추가 데이터 */
  data?: { [key: string]: string } | null;
}

/**
 * 푸시 알림 전송 응답
 */
export interface SendPushNotificationResponse {
  /** 성공 여부 */
  success: boolean;

  /** 전송 성공 수 */
  successCount: number;

  /** 전송 실패 수 */
  failureCount: number;
}

/**
 * Firestore에 저장되는 알림 문서
 */
export interface NotificationDocument {
  /** 수신자 userId */
  userId: string;

  /** 알림 타입 */
  type: NotificationType;

  /** 알림 제목 */
  title: string;

  /** 알림 본문 */
  body: string;

  /** 관련 약속 ID */
  promiseId: string | null;

  /** 관련 그룹 ID */
  groupId: string | null;

  /** 관련 사용자 ID */
  relatedUserId: string | null;

  /** 읽음 여부 */
  isRead: boolean;

  /** 전달 여부 */
  isDelivered: boolean;

  /** 생성 시각 */
  createdAt: FirebaseFirestore.Timestamp;

  /** 읽음 시각 */
  readAt: FirebaseFirestore.Timestamp | null;

  /** 전달 시각 */
  deliveredAt: FirebaseFirestore.Timestamp | null;

  /** 추가 데이터 */
  data: { [key: string]: string } | null;
}

/**
 * 디바이스 정보 (users/{userId} 문서의 devices Map 값)
 */
export interface DeviceInfo {
  /** FCM 토큰 */
  fcmToken: string;

  /** 플랫폼 (ios | android) */
  platform: string;

  /** 마지막 활성 시각 */
  lastActiveAt: FirebaseFirestore.Timestamp;

  /** 토큰 등록 시각 */
  createdAt: FirebaseFirestore.Timestamp;

  /** LiveActivity Push to Start 토큰 (iOS 17.2+) */
  liveActivityPushToStartToken?: string | null;

  /** LiveActivity Push 토큰 (개별 Activity용) */
  liveActivityPushToken?: string | null;
}

// ============================================================================
// LiveActivity APIs
// ============================================================================

/**
 * LiveActivity 참가자 상태
 */
export interface LiveActivityParticipant {
  /** 참가자 ID */
  id: string;

  /** 참가자 이름 */
  name: string;

  /** 도착 예상 시간 (분) - null=대기, 0=도착, N=N분 후 */
  estimatedArrivalMinutes: number | null;
}

/**
 * LiveActivity 시작 요청
 *
 * @remarks
 * - 인증 필수 (Firebase Auth)
 * - 약속 참가자(accepted) 전원에게 Push to Start 전송
 */
export interface StartLiveActivityRequest {
  /** 약속 ID */
  promiseId: string;
}

/**
 * LiveActivity 시작 응답
 */
export interface StartLiveActivityResponse {
  /** 성공 여부 */
  success: boolean;

  /** 전송 성공 수 */
  successCount: number;

  /** 전송 실패 수 */
  failureCount: number;
}

/**
 * ETA 업데이트 요청
 *
 * @remarks
 * - 인증 필수 (Firebase Auth)
 * - Firestore 없이 클라이언트에서 전달받은 데이터로 Broadcast만 전송
 */
export interface UpdateETARequest {
  /** 약속 ID (종료 예약용) */
  promiseId?: string;

  /** APNs Broadcast 채널 ID */
  channelId: string;

  /** 전체 참가자 상태 (업데이트된 ETA 포함) */
  participants: LiveActivityParticipant[];

  /** LiveActivity 추적 시간 (분) */
  trackingDurationMinutes?: number;
}

/**
 * ETA 업데이트 응답
 */
export interface UpdateETAResponse {
  /** 성공 여부 */
  success: boolean;

  /** 전송 성공 수 */
  successCount: number;

  /** 전송 실패 수 */
  failureCount: number;
}

// EndLiveActivityRequest 제거됨 - APNs dismissal-date로 auto-dismiss 처리
// EndLiveActivityResponse 제거됨

/**
 * LiveActivity Push to Start 토큰 등록 요청
 *
 * @remarks
 * - 인증 필수 (Firebase Auth)
 * - iOS 17.2+ 디바이스에서 앱 시작 시 호출
 */
export interface RegisterPushToStartTokenRequest {
  /** Push to Start 토큰 */
  token: string;

  /** 디바이스 ID */
  deviceId: string;
}

/**
 * LiveActivity Push to Start 토큰 등록 응답
 */
export interface RegisterPushToStartTokenResponse {
  /** 성공 여부 */
  success: boolean;
}

// ============================================================================
// LiveActivity Update 토큰 등록 - 제거됨
// ============================================================================
//
// RegisterLiveActivityTokenRequest, RegisterLiveActivityTokenResponse 제거됨
// iOS 18 Broadcast 방식으로 전환되어 개별 토큰 관리가 불필요해짐
// 모든 업데이트/종료는 채널 기반 Broadcast로 전송됨

// ============================================================================
// Cloud Tasks - LiveActivity 예약 시작
// ============================================================================

/**
 * LiveActivity 예약 시작 태스크 페이로드
 *
 * @remarks
 * Cloud Tasks에서 사용되는 내부 타입
 */
export interface ScheduledLiveActivityTaskPayload {
  /** 약속 ID */
  promiseId: string;
  /** 태스크가 실행되도록 예약된 시간 (ISO 문자열) */
  scheduledAt: string;
  /** 스케줄 버전 UUID (stale 감지용) */
  scheduleVersion: string;
}

/**
 * ETA 공유 넛지 푸시 예약 Task Payload
 */
export interface ScheduledNudgeTaskPayload {
  /** 약속 ID */
  promiseId: string;
}

/**
 * LiveActivity 종료 예약 Task Payload
 */
export interface ScheduledLiveActivityEndTaskPayload {
  /** 약속 ID */
  promiseId: string;

  /** Broadcast 채널 ID */
  channelId: string;
}

// ============================================================================
// generateEmoji
// ============================================================================

/**
 * 이모지 생성 요청
 *
 * @remarks
 * - 인증 필수 (Firebase Auth)
 * - Gemini API를 사용하여 제목에 어울리는 이모지 생성
 */
export interface GenerateEmojiRequest {
  /** 약속 제목 */
  title: string;
}

/**
 * 이모지 생성 응답
 */
export interface GenerateEmojiResponse {
  /** 생성된 이모지 */
  emoji: string;
}

/**
 * 이모지 생성 에러
 */
export enum GenerateEmojiError {
  /** 인증 필요 */
  UNAUTHENTICATED = "unauthenticated",

  /** 잘못된 요청 */
  INVALID_ARGUMENT = "invalid-argument",

  /** API 오류 */
  INTERNAL = "internal",
}

// ============================================================================
// generateBriefing
// ============================================================================

/**
 * 하루 브리핑 생성 요청
 *
 * @remarks
 * - 인증 필수 (Firebase Auth)
 * - 클라이언트는 디바이스 전용 데이터만 전송
 * - 일정/날씨는 서버에서 조회 (scheduleSlots + weather.ts)
 */
export interface GenerateBriefingRequest {
  /** 유저 타임존 (서버는 UTC이므로 필수) */
  timezone: string;

  /** 브리핑 언어 (다국어 확장 대비) */
  language: string;

  /** 유저 위치 (위치 권한 거부 시 null) */
  location: {
    /** 위도 */
    latitude: number;
    /** 경도 */
    longitude: number;
    /** 위치 텍스트 (CLGeocoder, 예: "서울 강남구", 역지오코딩 실패 시 없음) */
    title?: string;
  } | null;

  /** 캐시 무시 및 강제 재생성 (오류 제보 시 사용) */
  forceRefresh?: boolean;

  /** 브리핑 스타일 (Pro 설정, 기본: friendly) */
  style?: BriefingStyle;
}

/** 브리핑 스타일 종류 */
export type BriefingStyle =
  "friendly" | "humorous" | "concise" |
  "motivational" | "calm";

/**
 * 하루 브리핑 생성 응답
 */
export interface GenerateBriefingResponse {
  /** 한 줄 요약 (30자 이내) */
  summary: string;
  /** 상세 브리핑 (3~5문장) */
  detail: string;
  /** 기존 캐시가 있었지만 promptKey 변경으로 재생성됨 */
  isUpdated?: boolean;
}

/**
 * 하루 브리핑 생성 에러
 */
export enum GenerateBriefingError {
  /** 인증 필요 */
  UNAUTHENTICATED = "unauthenticated",

  /** API 오류 */
  INTERNAL = "internal",
}

// ============================================================================
// Snapshot (Firestore Cached Document) - Widget & Home 공통
// ============================================================================

/**
 * 내 투표 상태
 *
 * @remarks
 * - pending: 아직 응답 안 함 → 액션 필요
 * - voted: 참여 확정 (accepted)
 * - declined: 참여 거절
 */
export type MyVoteStatus = "pending" | "voted" | "declined";

/**
 * 스냅샷용 통합 일정 데이터 (Widget & Home 공통)
 *
 * @remarks
 * - 그룹 약속(type: "promise")과 개인 일정(type: "personal")을 통합
 * - Firestore `users/{uid}/cache/widgetSnapshot` 문서에 저장
 * - 서버에서 우선순위 정렬 완료 후 저장
 * - type이 "personal"이면 groupId/votes/myVoteStatus 등은 기본값
 */
export interface SnapshotPromise {
  /** 일정 타입 ("promise" | "personal", 생략 시 "promise") */
  type?: "promise" | "personal";

  /** 약속 ID */
  id: string;

  /** 약속 제목 */
  title: string;

  /** 약속 이모지 */
  emoji: string;

  /** 시작 시간 (ISO 8601) */
  startAt: string;

  /** 종료 시간 (ISO 8601, nullable) */
  endAt: string | null;

  /** 장소 이름 */
  location: string | null;

  /** 그룹 ID (개인 일정은 빈 문자열) */
  groupId: string;

  /** 그룹 이름 (개인 일정은 null) */
  groupName: string | null;

  /** 그룹 이미지 URL */
  groupImageUrl: string | null;

  /** 약속 확정 여부 (최소 인원 충족, 개인 일정은 true) */
  isConfirmed: boolean;

  /** 최소 참가 인원 (개인 일정은 0) */
  minimumParticipants: number;

  /** 투표 정보 (개인 일정은 빈 배열) */
  votes: {
    /** 참가 확정 사용자 ID 목록 */
    accepted: string[];
    /** 불참 사용자 ID 목록 */
    declined: string[];
  };

  /** 내 투표 상태 (개인 일정은 "voted") */
  myVoteStatus: MyVoteStatus;

  /** 투표 마감 시간 (ISO 8601, nullable) - 응답 필요 섹션용 */
  votingDeadline: string | null;
}

/**
 * Widget용 약속 데이터 (하위 호환성)
 * @deprecated SnapshotPromise 사용 권장
 */
export type WidgetPromise = SnapshotPromise;

/**
 * Widget Snapshot 메타데이터
 */
export interface WidgetSnapshotMeta {
  /** 오늘 약속 총 개수 (표시되는 것보다 많을 수 있음) */
  todayCount: number;

  /** 다가오는 약속 총 개수 */
  upcomingCount: number;

  /** 스냅샷 마지막 업데이트 시간 (ISO 8601) */
  updatedAt: string;

  /** 변경 감지용 버전 (trigger 실행마다 증가) */
  version: number;
}

/**
 * Widget Snapshot 문서 (Firestore)
 *
 * @path users/{uid}/widgetSnapshot
 *
 * @remarks
 * - Cloud Functions Trigger가 약속/투표 변경 시 자동 업데이트
 * - Widget은 이 문서만 읽으면 됨 (쿼리 불필요)
 *
 * @sorting 정렬 우선순위 (서버에서 적용)
 * 1. 내 투표 상태: pending(미응답) 우선
 * 2. 약속 확정 여부: 미확정 우선 (액션 필요)
 * 3. 시작 시간: 오름차순
 */
export interface WidgetSnapshotDocument {
  /**
   * 가장 가까운 약속 (Small 위젯용)
   *
   * @priority 우선순위 정렬 적용됨
   * - pending + 가까운 시간 → 가장 먼저
   */
  next: WidgetPromise | null;

  /**
   * 오늘 약속 목록 (Medium 위젯용)
   *
   * @max 5개
   * @sorting pending 우선 → 미확정 우선 → 시간순
   */
  today: WidgetPromise[];

  /**
   * 다가오는 일정 목록 (Large 위젯용, 내일부터)
   * 그룹 약속 + 개인 일정 통합, type 필드로 구분
   *
   * @max 7개
   * @sorting 시간순 (확정 여부 무관)
   */
  upcoming: WidgetPromise[];

  /** 메타데이터 */
  meta: WidgetSnapshotMeta;
}

/**
 * Widget Snapshot API 응답
 *
 * @remarks
 * getWidgetSnapshotWithToken API가 반환하는 형식
 * WidgetSnapshotDocument와 동일하지만 API 계약 명시용
 */
export type WidgetSnapshotResponse = WidgetSnapshotDocument;

// ============================================================================
// APNs LiveActivity Payload Types
// ============================================================================

/**
 * APNs LiveActivity 업데이트 Payload
 */
export interface APNsLiveActivityUpdatePayload {
  aps: {
    timestamp: number;
    event: "update";
    "content-state": {
      trackingDurationMinutes: number;
      participants: LiveActivityParticipant[];
    };
    alert?: {
      title: string;
      body: string;
    };
  };
}

// ============================================================================
// Schedule Conflict Check (일정 충돌 감지)
// ============================================================================

/**
 * 일정 충돌 확인 요청
 *
 * @remarks
 * - 인증 필수 (Firebase Auth)
 * - userId는 request.auth.uid에서 자동 추출
 * - 서버 사이드에서 scheduleSlots 기반 O(1) 충돌 체크
 */
export interface CheckScheduleConflictsRequest {
  /** 새 일정 시작 시간 (ISO 8601) */
  startAt: string;

  /** 새 일정 종료 시간 (ISO 8601, nullable → startAt + 2h) */
  endAt?: string | null;

  /** 충돌 결과에서 제외할 일정 ID (편집 시 자기 자신 제외) */
  excludeIds?: string[];

  /** 최소 여유 시간 (분). 기본값 0 = 겹침만 감지 */
  minGapMinutes?: number;
}

/**
 * 충돌 감지된 일정 정보
 */
export interface ScheduleConflictItem {
  /** 일정 ID */
  id: string;

  /** 일정 종류 */
  source: "promise" | "personalEvent";

  /** 확정 상태 */
  severity: "confirmed" | "pending";

  /** 일정 제목 */
  title: string;

  /** 일정 이모지 */
  emoji: string | null;

  /** 시작 시간 (ISO 8601) */
  startAt: string;

  /** 종료 시간 (ISO 8601, nullable) */
  endAt: string | null;

  /** 겹치는 시간 (분) */
  overlapMinutes: number;

  /** 두 일정 사이 여유 시간 (분). 겹치면 0, 겹치지 않으면 양수 */
  gapMinutes: number;
}

/**
 * 일정 충돌 확인 응답
 */
export interface CheckScheduleConflictsResponse {
  /** 충돌 일정 목록 (겹침 시간 내림차순) */
  conflicts: ScheduleConflictItem[];
}

/**
 * Schedule Slot (비정규화된 일정 슬롯)
 *
 * @path users/{userId}/scheduleSlots/{YYYY-MM-DD}
 *
 * @remarks
 * - Firestore 트리거로 자동 유지
 * - 약속 생성/수정/삭제, 개인 일정 생성/수정/삭제 시 갱신
 * - 충돌 체크 시 해당 날짜 문서만 읽으면 됨 (O(1))
 */
export interface ScheduleSlotDocument {
  /** 해당 날짜의 일정 슬롯 목록 */
  slots: ScheduleSlotEntry[];

  /** 마지막 업데이트 시간 */
  updatedAt: FirebaseFirestore.Timestamp;
}

/**
 * 개별 일정 슬롯 엔트리
 */
export interface ScheduleSlotEntry {
  /** 일정 ID (promise ID 또는 personalEvent ID) */
  id: string;

  /** 일정 종류 */
  type: "promise" | "personalEvent";

  /** 일정 제목 */
  title: string;

  /** 일정 이모지 */
  emoji: string | null;

  /** 시작 시간 */
  startAt: FirebaseFirestore.Timestamp;

  /** 종료 시간 (nullable) */
  endAt: FirebaseFirestore.Timestamp | null;

  /** 확정 상태 (promise: isConfirmed 기반, personalEvent: 항상 confirmed) */
  severity: "confirmed" | "pending";
}
