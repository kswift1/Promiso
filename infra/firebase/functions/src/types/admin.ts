/**
 * Admin Console 전용 타입 정의
 */

export type AdminRole = "owner" | "support" | "marketer";

export interface AdminUserDocument {
  role: AdminRole;
  email?: string | null;
  enabled?: boolean;
}

export interface GetAdminSessionResponse {
  success: true;
  userId: string;
  email: string | null;
  role: AdminRole;
  enabled: boolean;
}

export interface GetAdminUserSummaryRequest {
  query: string;
}

export interface AdminUserSummary {
  userId: string;
  name: string | null;
  nickname: string | null;
  email: string | null;
  groupCount: number;
  deviceCount: number;
  subscriptionStatus: string | null;
  overrideActive: boolean;
}

export interface GetAdminUserSummaryResponse {
  success: true;
  results: AdminUserSummary[];
}
