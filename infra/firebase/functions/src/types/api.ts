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

  /** 그룹 이미지 정보 (선택적) */
  photo?: RemoteImage | null;
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
// testCallable (테스트용)
// ============================================================================

export interface TestCallableRequest {
  name?: string;
}

export interface TestCallableResponse {
  message: string;
  authenticated: boolean;
  uid: string | null;
}

// ============================================================================
// Firestore Group Document Schema
// ============================================================================

/**
 * Firestore groups 컬렉션 스키마
 *
 * @remarks
 * iOS의 Group 모델과 일치해야 합니다.
 */
export interface GroupDocument {
  /** 그룹 이름 */
  name: string;

  /** 그룹 설명 (현재 미사용) */
  description: string | null;

  /** 그룹 이모지 (현재 미사용) */
  emoji: string | null;

  /** 테마 색상 (현재 미사용) */
  themeColor: string | null;

  /** 그룹 이미지 정보 */
  photo: RemoteImage | null;

  /** 현재 멤버 수 */
  memberCount: number;

  /** 활성 약속 수 */
  activePromiseCount: number;

  /** 최대 인원 */
  maxMembers: number;

  /** 가입 승인 필요 여부 */
  requireApproval: boolean;

  /** 기본 최소 참여 인원 */
  defaultMinimumParticipants: number;

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
// Shared
// ============================================================================

export interface RemoteImage {
  type: "storagePath" | "externalURL";
  url: string;
}
