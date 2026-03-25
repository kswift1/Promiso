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

export interface AdminAccount {
  userId: string;
  email: string | null;
  role: AdminRole;
  enabled: boolean;
}

export interface GetAdminUsersResponse {
  success: true;
  users: AdminAccount[];
}

export interface CreateAdminUserRequest {
  email: string;
  role: AdminRole;
  enabled?: boolean;
}

export interface CreateAdminUserResponse {
  success: true;
  user: AdminAccount;
}

export interface UpdateAdminUserRequest {
  userId: string;
  role: AdminRole;
  enabled: boolean;
}

export interface UpdateAdminUserResponse {
  success: true;
  user: AdminAccount;
}

export interface GetAdminUserSummaryRequest {
  query?: string;
  field?: AdminUserSearchField;
  subscription?: AdminSubscriptionFilter;
  override?: AdminOverrideFilter;
  limit?: number;
  startAfter?: string;
}

export interface AdminUserSummary {
  userId: string;
  name: string | null;
  nickname: string | null;
  email: string | null;
  groupCount: number;
  deviceCount: number;
  personalEventCount: number;
  subscriptionStatus: string | null;
  overrideActive: boolean;
}

export interface GetAdminUserSummaryResponse {
  success: true;
  results: AdminUserSummary[];
  hasMore: boolean;
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

export interface PreviewAdminPushAudienceRequest {
  audience: AdminPushAudience;
  testUserId?: string | null;
}

export interface PreviewAdminPushAudienceResponse {
  success: true;
  targetCount: number;
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

export interface AdminReleaseControlField {
  key: AdminReleaseControlKey;
  label: string;
  description: string;
  section: AdminReleaseControlSection;
  sectionLabel: string;
  valueType: AdminReleaseControlValueType;
  editableRoles: AdminRole[];
  warning: string | null;
}

export interface AdminReleaseControls {
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

export type AdminAnalyticsWindowDays = 1 | 7 | 30;

export interface AdminAnalyticsGa4Summary {
  available: boolean;
  note: string | null;
  signups: number | null;
  logins: number | null;
  paywallOpens: number | null;
  paywallPurchases: number | null;
}

export interface AdminAnalyticsBigQuerySummary {
  available: boolean;
  note: string | null;
  signups: number | null;
  paywallOpens: number | null;
  paywallPurchases: number | null;
}

export interface AdminAnalyticsSummary {
  windowDays: AdminAnalyticsWindowDays;
  ga4: AdminAnalyticsGa4Summary;
  bigQuery: AdminAnalyticsBigQuerySummary;
}

export interface GetAdminAnalyticsSummaryRequest {
  windowDays?: AdminAnalyticsWindowDays;
}

export interface GetAdminAnalyticsSummaryResponse {
  success: true;
  summary: AdminAnalyticsSummary;
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

// ============================================================================
// Coupon Types
// ============================================================================

export interface AdminCoupon {
  code: string;
  durationDays: number;
  memo: string;
  redeemedBy: string | null;
  redeemedAt: string | null;
  expiresAt: string;
  createdBy: string;
  createdAt: string;
}

export interface CreateCouponRequest {
  code?: string;
  durationDays: 30 | 90;
  memo?: string;
}

export interface CreateCouponResponse {
  success: true;
  coupon: AdminCoupon;
}

export interface GetAdminCouponsRequest {
  status?: "all" | "available" | "redeemed" | "expired";
  limit?: number;
}

export interface GetAdminCouponsResponse {
  success: true;
  coupons: AdminCoupon[];
}

export interface ExpireCouponRequest {
  code: string;
}

export interface ExpireCouponResponse {
  success: true;
}

export interface RedeemCouponRequest {
  code: string;
}

export interface RedeemCouponResponse {
  success: true;
  durationDays: number;
  expiresAt: string;
}

// ============================================================================
// ProPlan Dashboard Types
// ============================================================================

export interface AdminProPlanBreakdown {
  monthly: { count: number; revenue: number };
  yearly: { count: number; revenue: number };
  lifetime: { count: number; totalRevenue: number };
  override: { count: number };
  gracePeriod: { count: number };
}

export interface AdminProPlanRevenue {
  estimatedMRR: number;
  totalLifetimeRevenue: number;
}

export interface AdminProPlanCouponSummary {
  total: number;
  available: number;
  redeemed: number;
  expired: number;
}

export interface AdminProPlanActivity {
  userId: string;
  type: string;
  productId: string | null;
  timestamp: string;
}

export interface AdminProPlanPrices {
  monthly: number;
  yearly: number;
  lifetime: number;
}

export interface AdminOfferCodeRedemption {
  userId: string;
  offerIdentifier: string;
  redeemedAt: string;
  productId: string | null;
}

export interface AdminOfferCodeSummary {
  totalRedemptions: number;
  recentRedemptions: AdminOfferCodeRedemption[];
}

export interface AdminProPlanDashboard {
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
  offerCodes: AdminOfferCodeSummary;
}

export interface GetAdminProPlanDashboardResponse {
  success: true;
  dashboard: AdminProPlanDashboard;
}

// ============================================================================
// WhatsNew Types
// ============================================================================

export interface WhatsNewItem {
  title: string;
  description: string;
  imageURL: string;
  displayOrder: number;
}

export interface WhatsNewDocument {
  version: string;
  enabled: boolean;
  items: WhatsNewItem[];
  createdBy: string;
  createdAt: string;
  updatedBy: string;
  updatedAt: string;
}

export interface GetWhatsNewRequest {
  version: string;
}

export interface GetWhatsNewResponse {
  success: true;
  whatsNew: WhatsNewDocument | null;
}

export interface AdminListWhatsNewResponse {
  success: true;
  entries: WhatsNewDocument[];
}

export interface AdminSaveWhatsNewRequest {
  version: string;
  enabled: boolean;
  items: WhatsNewItem[];
}

export interface AdminSaveWhatsNewResponse {
  success: true;
  whatsNew: WhatsNewDocument;
}

export interface AdminDeleteWhatsNewRequest {
  version: string;
}

export interface AdminDeleteWhatsNewResponse {
  success: true;
}

export interface AdminUploadWhatsNewImageRequest {
  version: string;
  fileName: string;
  base64Data: string;
  contentType: string;
}

export interface AdminUploadWhatsNewImageResponse {
  success: true;
  imageURL: string;
}
