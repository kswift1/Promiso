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

export interface AdminSubscriptionSnapshot {
  status: string | null;
  productId: string | null;
  expirationDate: string | null;
  purchaseDate: string | null;
  updatedAt: string | null;
}

export interface AdminEntitlementOverrideSnapshot {
  isActive: boolean;
  type: string | null;
  reason: string | null;
  expiresAt: string | null;
  createdBy: string | null;
  createdAt: string | null;
  revokedBy: string | null;
  revokedReason: string | null;
  revokedAt: string | null;
  updatedAt: string | null;
}

export interface GetAdminUserTimelineRequest {
  userId: string;
  limit?: number;
}

export interface GetAdminUserTimelineResponse {
  success: true;
  summary: AdminUserSummary;
  subscription: AdminSubscriptionSnapshot;
  override: AdminEntitlementOverrideSnapshot | null;
  auditLogs: AdminAuditLog[];
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
export type AdminPushJobStatus =
  "scheduled" |
  "processing" |
  "completed" |
  "failed" |
  "cancelled" |
  "dry_run";

export interface AdminPushJob {
  id: string;
  status: AdminPushJobStatus;
  audience: AdminPushAudience;
  title: string;
  body: string;
  dryRun: boolean;
  targetCount: number | null;
  createdBy: string | null;
  testUserId: string | null;
  scheduledAt: string | null;
  createdAt: string | null;
  executionStartedAt: string | null;
  completedAt: string | null;
  cancelledAt: string | null;
  cancelledReason: string | null;
  errorMessage: string | null;
  result: {
    successCount: number;
    failureCount: number;
  } | null;
}

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

export interface ScheduleAdminPushRequest {
  title: string;
  body: string;
  audience: AdminPushAudience;
  scheduledAt: string;
  testUserId?: string | null;
}

export interface ScheduleAdminPushResponse {
  success: true;
  jobId: string;
  scheduledAt: string;
}

export interface GetAdminPushJobsRequest {
  limit?: number;
  status?: AdminPushJobStatus | "all";
}

export interface GetAdminPushJobsResponse {
  success: true;
  jobs: AdminPushJob[];
}

export interface CancelAdminPushJobRequest {
  jobId: string;
  reason?: string | null;
}

export interface CancelAdminPushJobResponse {
  success: true;
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
