import {httpsCallable} from "firebase/functions";
import {firebaseFunctions} from "../lib/firebase";

export type AdminUserSearchField = "all" | "userId" | "email" | "nickname";
export type AdminSubscriptionFilter = "all" | "subscribed" | "not_subscribed";
export type AdminOverrideFilter = "all" | "active" | "inactive";
export type AdminRole = "owner" | "support" | "marketer";

export type AdminAccount = {
  userId: string;
  email: string | null;
  role: AdminRole;
  enabled: boolean;
};

export type AdminUserSummary = {
  userId: string;
  name: string | null;
  nickname: string | null;
  email: string | null;
  groupCount: number;
  deviceCount: number;
  subscriptionStatus: string | null;
  overrideActive: boolean;
};

export type AdminSubscriptionSnapshot = {
  status: string | null;
  productId: string | null;
  expirationDate: string | null;
  purchaseDate: string | null;
  updatedAt: string | null;
};

export type AdminEntitlementOverrideSnapshot = {
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
};

type GetAdminUserSummaryRequest = {
  query?: string;
  field?: AdminUserSearchField;
  subscription?: AdminSubscriptionFilter;
  override?: AdminOverrideFilter;
  limit?: number;
};

type GetAdminUsersResponse = {
  success: true;
  users: AdminAccount[];
};

type CreateAdminUserRequest = {
  email: string;
  role: AdminRole;
  enabled?: boolean;
};

type CreateAdminUserResponse = {
  success: true;
  user: AdminAccount;
};

type UpdateAdminUserRequest = {
  userId: string;
  role: AdminRole;
  enabled: boolean;
};

type UpdateAdminUserResponse = {
  success: true;
  user: AdminAccount;
};

type GetAdminUserSummaryResponse = {
  success: true;
  results: AdminUserSummary[];
};

type GetAdminUserTimelineRequest = {
  userId: string;
  limit?: number;
};

export type AdminUserTimeline = {
  summary: AdminUserSummary;
  subscription: AdminSubscriptionSnapshot;
  override: AdminEntitlementOverrideSnapshot | null;
  auditLogs: AdminAuditLog[];
};

type GetAdminUserTimelineResponse = {
  success: true;
  summary: AdminUserSummary;
  subscription: AdminSubscriptionSnapshot;
  override: AdminEntitlementOverrideSnapshot | null;
  auditLogs: AdminAuditLog[];
};

type GrantEntitlementOverrideRequest = {
  userId: string;
  reason: string;
  expiresAt?: string | null;
};

type GrantEntitlementOverrideResponse = {
  success: true;
};

type RevokeEntitlementOverrideRequest = {
  userId: string;
  reason?: string | null;
};

type RevokeEntitlementOverrideResponse = {
  success: true;
};

export type AdminPushAudience = "all" | "pro" | "free" | "test_user";
export type AdminPushJobStatus =
  "scheduled" |
  "processing" |
  "completed" |
  "failed" |
  "cancelled" |
  "dry_run";

export type AdminPushJob = {
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
};

type SendAdminPushRequest = {
  title: string;
  body: string;
  audience: AdminPushAudience;
  dryRun?: boolean;
  testUserId?: string | null;
};

type SendAdminPushResponse = {
  success: true;
  dryRun: boolean;
  targetCount: number;
  successCount: number;
  failureCount: number;
  jobId: string;
};

type PreviewAdminPushAudienceRequest = {
  audience: AdminPushAudience;
  testUserId?: string | null;
};

type PreviewAdminPushAudienceResponse = {
  success: true;
  targetCount: number;
};

type ScheduleAdminPushRequest = {
  title: string;
  body: string;
  audience: AdminPushAudience;
  scheduledAt: string;
  testUserId?: string | null;
};

type ScheduleAdminPushResponse = {
  success: true;
  jobId: string;
  scheduledAt: string;
};

type GetAdminPushJobsRequest = {
  limit?: number;
  status?: AdminPushJobStatus | "all";
};

type GetAdminPushJobsResponse = {
  success: true;
  jobs: AdminPushJob[];
};

type CancelAdminPushJobRequest = {
  jobId: string;
  reason?: string | null;
};

type CancelAdminPushJobResponse = {
  success: true;
};

export type AdminReleaseControlKey =
  "forceUpdateVersion" |
  "recommendedVersion" |
  "appStoreURL" |
  "privacyPolicyURL" |
  "termsOfServiceURL" |
  "supportEmail" |
  "notionFAQDatabaseId";

export type AdminReleaseControlSection =
  "version" |
  "legal" |
  "support";

export type AdminReleaseControlValueType =
  "version" |
  "url" |
  "email" |
  "string";

export type AdminReleaseControlField = {
  key: AdminReleaseControlKey;
  label: string;
  description: string;
  section: AdminReleaseControlSection;
  sectionLabel: string;
  valueType: AdminReleaseControlValueType;
  editableRoles: AdminRole[];
  warning: string | null;
};

export type AdminReleaseControls = {
  forceUpdateVersion: string;
  recommendedVersion: string;
  appStoreURL: string;
  privacyPolicyURL: string;
  termsOfServiceURL: string;
  supportEmail: string;
  notionFAQDatabaseId: string;
  fields: AdminReleaseControlField[];
  versionNumber: string | null;
  updateTime: string | null;
  updateUserEmail: string | null;
};

export type AdminAuditLog = {
  id: string;
  actorId: string | null;
  action: string | null;
  targetType: string | null;
  targetId: string | null;
  before: unknown;
  after: unknown;
  createdAt: string | null;
};

export type AdminAnalyticsWindowDays = 1 | 7 | 30;

export type AdminAnalyticsGa4Summary = {
  available: boolean;
  note: string | null;
  signups: number | null;
  logins: number | null;
  paywallOpens: number | null;
  paywallPurchases: number | null;
};

export type AdminAnalyticsBigQuerySummary = {
  available: boolean;
  note: string | null;
  signups: number | null;
  paywallOpens: number | null;
  paywallPurchases: number | null;
};

export type AdminAnalyticsSummary = {
  windowDays: AdminAnalyticsWindowDays;
  ga4: AdminAnalyticsGa4Summary;
  bigQuery: AdminAnalyticsBigQuerySummary;
};

export type AdminDashboardSummary = {
  totalUsers: number;
  proUsers: number;
  freeUsers: number;
  activeOverrides: number;
  totalAdmins: number;
  pushJobCount: number;
  auditLogCount: number;
  remoteConfigVersion: string | null;
  remoteConfigUpdatedAt: string | null;
};

type GetAdminReleaseControlsResponse = {
  success: true;
  controls: AdminReleaseControls;
};

type UpdateAdminReleaseControlsRequest = {
  forceUpdateVersion: string;
  recommendedVersion: string;
  appStoreURL: string;
  privacyPolicyURL: string;
  termsOfServiceURL: string;
  supportEmail: string;
  notionFAQDatabaseId: string;
};

type UpdateAdminReleaseControlsResponse = {
  success: true;
  controls: AdminReleaseControls;
};

type GetAdminAuditLogsRequest = {
  limit?: number;
  action?: string;
  actorId?: string;
  targetType?: string;
  targetId?: string;
};

type GetAdminAuditLogsResponse = {
  success: true;
  logs: AdminAuditLog[];
};

type GetAdminDashboardSummaryResponse = {
  success: true;
  summary: AdminDashboardSummary;
};

type GetAdminAnalyticsSummaryRequest = {
  windowDays?: AdminAnalyticsWindowDays;
};

type GetAdminAnalyticsSummaryResponse = {
  success: true;
  summary: AdminAnalyticsSummary;
};

export async function getAdminUserSummary(params: {
  query?: string;
  field?: AdminUserSearchField;
  subscription?: AdminSubscriptionFilter;
  override?: AdminOverrideFilter;
  limit?: number;
}): Promise<AdminUserSummary[]> {
  if (!firebaseFunctions) {
    throw new Error("Firebase Functions is not configured");
  }

  const callable = httpsCallable<
    GetAdminUserSummaryRequest,
    GetAdminUserSummaryResponse
  >(firebaseFunctions, "getAdminUserSummary");
  const result = await callable(params);
  return result.data.results;
}

export async function getAdminUsers(): Promise<AdminAccount[]> {
  if (!firebaseFunctions) {
    throw new Error("Firebase Functions is not configured");
  }

  const callable = httpsCallable<Record<string, never>, GetAdminUsersResponse>(
    firebaseFunctions,
    "getAdminUsers"
  );
  const result = await callable({});
  return result.data.users;
}

export async function createAdminUser(params: {
  email: string;
  role: AdminRole;
  enabled?: boolean;
}): Promise<AdminAccount> {
  if (!firebaseFunctions) {
    throw new Error("Firebase Functions is not configured");
  }

  const callable = httpsCallable<
    CreateAdminUserRequest,
    CreateAdminUserResponse
  >(firebaseFunctions, "createAdminUser");
  const result = await callable(params);
  return result.data.user;
}

export async function updateAdminUser(params: {
  userId: string;
  role: AdminRole;
  enabled: boolean;
}): Promise<AdminAccount> {
  if (!firebaseFunctions) {
    throw new Error("Firebase Functions is not configured");
  }

  const callable = httpsCallable<
    UpdateAdminUserRequest,
    UpdateAdminUserResponse
  >(firebaseFunctions, "updateAdminUser");
  const result = await callable(params);
  return result.data.user;
}

export async function getAdminUserTimeline(params: {
  userId: string;
  limit?: number;
}): Promise<AdminUserTimeline> {
  if (!firebaseFunctions) {
    throw new Error("Firebase Functions is not configured");
  }

  const callable = httpsCallable<
    GetAdminUserTimelineRequest,
    GetAdminUserTimelineResponse
  >(firebaseFunctions, "getAdminUserTimeline");
  const result = await callable(params);
  return {
    summary: result.data.summary,
    subscription: result.data.subscription,
    override: result.data.override,
    auditLogs: result.data.auditLogs,
  };
}

export async function grantEntitlementOverride(params: {
  userId: string;
  reason: string;
  expiresAt?: string | null;
}): Promise<void> {
  if (!firebaseFunctions) {
    throw new Error("Firebase Functions is not configured");
  }

  const callable = httpsCallable<
    GrantEntitlementOverrideRequest,
    GrantEntitlementOverrideResponse
  >(firebaseFunctions, "grantEntitlementOverride");
  await callable(params);
}

export async function revokeEntitlementOverride(params: {
  userId: string;
  reason?: string | null;
}): Promise<void> {
  if (!firebaseFunctions) {
    throw new Error("Firebase Functions is not configured");
  }

  const callable = httpsCallable<
    RevokeEntitlementOverrideRequest,
    RevokeEntitlementOverrideResponse
  >(firebaseFunctions, "revokeEntitlementOverride");
  await callable(params);
}

export async function sendAdminPush(params: {
  title: string;
  body: string;
  audience: AdminPushAudience;
  dryRun?: boolean;
  testUserId?: string | null;
}): Promise<SendAdminPushResponse> {
  if (!firebaseFunctions) {
    throw new Error("Firebase Functions is not configured");
  }

  const callable = httpsCallable<SendAdminPushRequest, SendAdminPushResponse>(
    firebaseFunctions,
    "sendAdminPush"
  );
  const result = await callable(params);
  return result.data;
}

export async function previewAdminPushAudience(params: {
  audience: AdminPushAudience;
  testUserId?: string | null;
}): Promise<number> {
  if (!firebaseFunctions) {
    throw new Error("Firebase Functions is not configured");
  }

  const callable = httpsCallable<
    PreviewAdminPushAudienceRequest,
    PreviewAdminPushAudienceResponse
  >(firebaseFunctions, "previewAdminPushAudience");
  const result = await callable(params);
  return result.data.targetCount;
}

export async function scheduleAdminPush(params: {
  title: string;
  body: string;
  audience: AdminPushAudience;
  scheduledAt: string;
  testUserId?: string | null;
}): Promise<ScheduleAdminPushResponse> {
  if (!firebaseFunctions) {
    throw new Error("Firebase Functions is not configured");
  }

  const callable = httpsCallable<
    ScheduleAdminPushRequest,
    ScheduleAdminPushResponse
  >(firebaseFunctions, "scheduleAdminPush");
  const result = await callable(params);
  return result.data;
}

export async function getAdminPushJobs(params?: {
  limit?: number;
  status?: AdminPushJobStatus | "all";
}): Promise<AdminPushJob[]> {
  if (!firebaseFunctions) {
    throw new Error("Firebase Functions is not configured");
  }

  const callable = httpsCallable<
    GetAdminPushJobsRequest,
    GetAdminPushJobsResponse
  >(firebaseFunctions, "getAdminPushJobs");
  const result = await callable(params ?? {});
  return result.data.jobs;
}

export async function cancelAdminPushJob(params: {
  jobId: string;
  reason?: string | null;
}): Promise<void> {
  if (!firebaseFunctions) {
    throw new Error("Firebase Functions is not configured");
  }

  const callable = httpsCallable<
    CancelAdminPushJobRequest,
    CancelAdminPushJobResponse
  >(firebaseFunctions, "cancelAdminPushJob");
  await callable(params);
}

export async function getAdminReleaseControls():
Promise<AdminReleaseControls> {
  if (!firebaseFunctions) {
    throw new Error("Firebase Functions is not configured");
  }

  const callable = httpsCallable<
    Record<string, never>,
    GetAdminReleaseControlsResponse
  >(firebaseFunctions, "getAdminReleaseControls");
  const result = await callable({});
  return result.data.controls;
}

export async function updateAdminReleaseControls(
  params: UpdateAdminReleaseControlsRequest
): Promise<AdminReleaseControls> {
  if (!firebaseFunctions) {
    throw new Error("Firebase Functions is not configured");
  }

  const callable = httpsCallable<
    UpdateAdminReleaseControlsRequest,
    UpdateAdminReleaseControlsResponse
  >(firebaseFunctions, "updateAdminReleaseControls");
  const result = await callable(params);
  return result.data.controls;
}

export async function getAdminAuditLogs(params?: {
  limit?: number;
  action?: string;
  actorId?: string;
  targetType?: string;
  targetId?: string;
}): Promise<AdminAuditLog[]> {
  if (!firebaseFunctions) {
    throw new Error("Firebase Functions is not configured");
  }

  const callable = httpsCallable<
    GetAdminAuditLogsRequest,
    GetAdminAuditLogsResponse
  >(firebaseFunctions, "getAdminAuditLogs");
  const result = await callable(params ?? {});
  return result.data.logs;
}

export async function getAdminDashboardSummary():
Promise<AdminDashboardSummary> {
  if (!firebaseFunctions) {
    throw new Error("Firebase Functions is not configured");
  }

  const callable = httpsCallable<
    Record<string, never>,
    GetAdminDashboardSummaryResponse
  >(firebaseFunctions, "getAdminDashboardSummary");
  const result = await callable({});
  return result.data.summary;
}

export async function getAdminAnalyticsSummary(params?: {
  windowDays?: AdminAnalyticsWindowDays;
}): Promise<AdminAnalyticsSummary> {
  if (!firebaseFunctions) {
    throw new Error("Firebase Functions is not configured");
  }

  const callable = httpsCallable<
    GetAdminAnalyticsSummaryRequest,
    GetAdminAnalyticsSummaryResponse
  >(firebaseFunctions, "getAdminAnalyticsSummary");
  const result = await callable(params ?? {});
  return result.data.summary;
}

// ============================================================================
// Coupon API
// ============================================================================

export type AdminCoupon = {
  code: string;
  durationDays: number;
  memo: string;
  redeemedBy: string | null;
  redeemedAt: string | null;
  expiresAt: string;
  createdBy: string;
  createdAt: string;
};

type CreateCouponRequest = {
  code?: string;
  durationDays: 30 | 90;
  memo?: string;
};

type CreateCouponResponse = {
  success: true;
  coupon: AdminCoupon;
};

type GetAdminCouponsRequest = {
  status?: "all" | "available" | "redeemed" | "expired";
  limit?: number;
};

type GetAdminCouponsResponse = {
  success: true;
  coupons: AdminCoupon[];
};

export async function createCoupon(params: {
  code?: string;
  durationDays: 30 | 90;
  memo?: string;
}): Promise<AdminCoupon> {
  if (!firebaseFunctions) {
    throw new Error("Firebase Functions is not configured");
  }

  const callable = httpsCallable<CreateCouponRequest, CreateCouponResponse>(
    firebaseFunctions,
    "createCoupon"
  );
  const result = await callable(params);
  return result.data.coupon;
}

export async function getAdminCoupons(params?: {
  status?: "all" | "available" | "redeemed" | "expired";
  limit?: number;
}): Promise<AdminCoupon[]> {
  if (!firebaseFunctions) {
    throw new Error("Firebase Functions is not configured");
  }

  const callable = httpsCallable<GetAdminCouponsRequest, GetAdminCouponsResponse>(
    firebaseFunctions,
    "getAdminCoupons"
  );
  const result = await callable(params ?? {});
  return result.data.coupons;
}

// ============================================================================
// ProPlan Dashboard API
// ============================================================================

export type AdminProPlanBreakdown = {
  monthly: { count: number; revenue: number };
  yearly: { count: number; revenue: number };
  lifetime: { count: number; totalRevenue: number };
  override: { count: number };
  gracePeriod: { count: number };
};

export type AdminProPlanRevenue = {
  estimatedMRR: number;
  totalLifetimeRevenue: number;
};

export type AdminProPlanCouponSummary = {
  total: number;
  available: number;
  redeemed: number;
  expired: number;
};

export type AdminProPlanActivity = {
  userId: string;
  type: string;
  productId: string | null;
  timestamp: string;
};

export type AdminProPlanPrices = {
  monthly: number;
  yearly: number;
  lifetime: number;
};

export type AdminProPlanDashboard = {
  overview: {
    totalUsers: number;
    proUsers: number;
    proSubscriptionUsers: number;
    proOverrideUsers: number;
    freeUsers: number;
    proRate: number;
  };
  breakdown: AdminProPlanBreakdown;
  revenue: AdminProPlanRevenue;
  prices: AdminProPlanPrices;
  coupons: AdminProPlanCouponSummary;
  recentActivities: AdminProPlanActivity[];
};

type GetAdminProPlanDashboardResponse = {
  success: true;
  dashboard: AdminProPlanDashboard;
};

export async function getAdminProPlanDashboard(): Promise<AdminProPlanDashboard> {
  if (!firebaseFunctions) {
    throw new Error("Firebase Functions is not configured");
  }

  const callable = httpsCallable<
    Record<string, never>,
    GetAdminProPlanDashboardResponse
  >(firebaseFunctions, "getAdminProPlanDashboard");
  const result = await callable({});
  return result.data.dashboard;
}

export async function expireCoupon(code: string): Promise<void> {
  if (!firebaseFunctions) {
    throw new Error("Firebase Functions is not configured");
  }

  const callable = httpsCallable<{code: string}, {success: true}>(
    firebaseFunctions,
    "expireCoupon"
  );
  await callable({code});
}
