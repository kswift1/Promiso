/**
 * Admin Console 전용 타입 정의
 */

export type AdminRole = "owner" | "support" | "marketer";
export type AdminUserSearchField = "all" | "userId" | "email" | "nickname";
export type AdminSubscriptionFilter = "all" | "subscribed" | "not_subscribed";
export type AdminOverrideFilter = "all" | "active" | "inactive";

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
  query?: string;
  field?: AdminUserSearchField;
  subscription?: AdminSubscriptionFilter;
  override?: AdminOverrideFilter;
  limit?: number;
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

export interface AdminReleaseControls {
  forceUpdateVersion: string;
  recommendedVersion: string;
  appStoreURL: string;
  privacyPolicyURL: string;
  termsOfServiceURL: string;
  supportEmail: string;
  notionFAQDatabaseId: string;
  versionNumber: string | null;
  updateTime: string | null;
  updateUserEmail: string | null;
}

export interface GetAdminReleaseControlsResponse {
  success: true;
  controls: AdminReleaseControls;
}

export interface UpdateAdminReleaseControlsRequest {
  forceUpdateVersion: string;
  recommendedVersion: string;
  appStoreURL: string;
  privacyPolicyURL: string;
  termsOfServiceURL: string;
  supportEmail: string;
  notionFAQDatabaseId: string;
}

export interface UpdateAdminReleaseControlsResponse {
  success: true;
  controls: AdminReleaseControls;
}

export interface AdminAuditLog {
  id: string;
  actorId: string | null;
  action: string | null;
  targetType: string | null;
  targetId: string | null;
  before: unknown;
  after: unknown;
  createdAt: string | null;
}

export interface GetAdminAuditLogsRequest {
  limit?: number;
  action?: string;
  actorId?: string;
  targetType?: string;
  targetId?: string;
}

export interface GetAdminAuditLogsResponse {
  success: true;
  logs: AdminAuditLog[];
}

export interface AdminDashboardSummary {
  totalUsers: number;
  proUsers: number;
  freeUsers: number;
  activeOverrides: number;
  totalAdmins: number;
  pushJobCount: number;
  auditLogCount: number;
  remoteConfigVersion: string | null;
  remoteConfigUpdatedAt: string | null;
}

export interface GetAdminDashboardSummaryResponse {
  success: true;
  summary: AdminDashboardSummary;
}
