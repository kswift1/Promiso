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

export interface GrantEntitlementOverrideRequest {
  userId: string;
  reason: string;
  expiresAt?: string | null;
}

export interface GrantEntitlementOverrideResponse {
  success: true;
}

export interface RevokeEntitlementOverrideRequest {
  userId: string;
  reason?: string | null;
}

export interface RevokeEntitlementOverrideResponse {
  success: true;
}

export type AdminPushAudience = "all" | "pro" | "free" | "test_user";

export interface SendAdminPushRequest {
  title: string;
  body: string;
  audience: AdminPushAudience;
  dryRun?: boolean;
  testUserId?: string | null;
}

export interface SendAdminPushResponse {
  success: true;
  dryRun: boolean;
  targetCount: number;
  successCount: number;
  failureCount: number;
  jobId: string;
}
