import {httpsCallable} from "firebase/functions";
import {firebaseFunctions} from "../lib/firebase";

export type AdminUserSearchField = "all" | "userId" | "email" | "nickname";
export type AdminSubscriptionFilter = "all" | "subscribed" | "not_subscribed";
export type AdminOverrideFilter = "all" | "active" | "inactive";

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

export type AdminReleaseControls = {
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
