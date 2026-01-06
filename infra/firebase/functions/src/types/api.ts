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

  /** 환경 구분 (선택적: stage 또는 prod) */
  env?: "stage" | "prod" | null;

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

  /** 환경 구분 (선택적: stage 또는 prod) */
  env?: "stage" | "prod" | null;
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

  /** 환경 구분 (선택적: stage 또는 prod) */
  env?: "stage" | "prod" | null;

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

  /** 활성 약속 수 */
  activePromiseCount: number;

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

  /** 삭제 여부 */
  isDeleted: boolean;
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

  /** 장소 이름 (선택적) */
  place?: string | null;

  /** 도착 상황 공유 시작 시간 (분 단위, 선택적) */
  arrivalSharingTime?: number | null;

  /** 환경 구분 (선택적: stage 또는 prod) */
  env?: "stage" | "prod" | null;
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
// respondPromise
// ============================================================================

/**
 * 약속 응답 요청
 *
 * @remarks
 * - 인증 필수 (Firebase Auth)
 * - 약속 참석자만 응답 가능
 */
export interface RespondPromiseRequest {
  /** 약속 ID */
  promiseId: string;

  /** 응답 상태 */
  status: "accepted" | "declined" | "tentative";

  /** 환경 구분 (선택적: stage 또는 prod) */
  env?: "stage" | "prod" | null;
}

/**
 * 약속 응답 응답
 */
export interface RespondPromiseResponse {
  /** 약속 ID */
  promiseId: string;

  /** 응답 상태 */
  status: "accepted" | "declined" | "tentative";
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

  /** 사용자가 설정한 닉네임 (2~12자) */
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

  /** 환경 구분 (선택적: stage 또는 prod) */
  env?: "stage" | "prod" | null;
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

  /** 환경 구분 (선택적: stage 또는 prod) */
  env?: "stage" | "prod" | null;
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
  /** 닉네임 (2~12자) */
  nickname?: string | null;

  /** 환경 구분 (선택적: stage 또는 prod) */
  env?: "stage" | "prod" | null;
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

  /** 환경 구분 (선택적: stage 또는 prod) */
  env?: "stage" | "prod" | null;
}

/**
 * 프로필 이미지 업로드 응답
 */
export interface UploadProfileImageResponse {
  /** 프로필 이미지 정보 */
  profile: ProfileImage;
}

/**
 * 사용자 설정 조회 응답
 */
export interface GetUserSettingsResponse {
  /** 알림 활성화 여부 */
  notificationEnabled: boolean;
}

/**
 * 사용자 설정 수정 요청
 */
export interface UpdateUserSettingsRequest {
  /** 알림 활성화 여부 */
  notificationEnabled?: boolean | null;

  /** 환경 구분 (선택적: stage 또는 prod) */
  env?: "stage" | "prod" | null;
}

/**
 * 사용자 설정 수정 응답
 */
export interface UpdateUserSettingsResponse {
  /** 성공 여부 */
  success: boolean;
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
  notifications: boolean;
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
