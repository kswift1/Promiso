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
