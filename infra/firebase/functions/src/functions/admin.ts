import {FieldValue} from "firebase-admin/firestore";
import type {
  RemoteConfigParameterValue,
  RemoteConfigTemplate,
} from "firebase-admin/remote-config";
import {HttpsError, onCall} from "firebase-functions/v2/https";
import {onSchedule} from "firebase-functions/v2/scheduler";
import {admin, REGION} from "../config";

// Admin subcollection 헬퍼
const adminDoc = () =>
  admin.firestore().collection("admin").doc("config");
const adminCol = (name: string) =>
  adminDoc().collection(name);
import {
  AdminAccount,
  AdminAuditLog,
  AdminAnalyticsWindowDays,
  AdminOverrideFilter,
  AdminEntitlementOverrideSnapshot,
  AdminDashboardSummary,
  AdminPushJob,
  AdminPushJobStatus,
  AdminReleaseControlField,
  AdminReleaseControls,
  AdminPushAudience,
  AdminRole,
  AdminSubscriptionSnapshot,
  AdminSubscriptionFilter,
  AdminUserDocument,
  AdminUserSearchField,
  AdminUserSummary,
  CreateAdminUserRequest,
  CreateAdminUserResponse,
  GrantEntitlementOverrideRequest,
  GrantEntitlementOverrideResponse,
  GetAdminAuditLogsRequest,
  GetAdminAuditLogsResponse,
  GetAdminAnalyticsSummaryRequest,
  GetAdminAnalyticsSummaryResponse,
  GetAdminDashboardSummaryResponse,
  GetAdminPushJobsRequest,
  GetAdminPushJobsResponse,
  GetAdminSessionResponse,
  GetAdminUsersResponse,
  GetAdminReleaseControlsResponse,
  GetAdminUserSummaryRequest,
  GetAdminUserSummaryResponse,
  GetAdminUserTimelineRequest,
  GetAdminUserTimelineResponse,
  CancelAdminPushJobRequest,
  CancelAdminPushJobResponse,
  PreviewAdminPushAudienceRequest,
  PreviewAdminPushAudienceResponse,
  RevokeEntitlementOverrideRequest,
  RevokeEntitlementOverrideResponse,
  ScheduleAdminPushRequest,
  ScheduleAdminPushResponse,
  SendAdminPushRequest,
  SendAdminPushResponse,
  UpdateAdminUserRequest,
  UpdateAdminUserResponse,
  UpdateAdminReleaseControlsRequest,
  UpdateAdminReleaseControlsResponse,
  AdminCoupon,
  CreateCouponRequest,
  CreateCouponResponse,
  GetAdminCouponsRequest,
  GetAdminCouponsResponse,
  ExpireCouponRequest,
  ExpireCouponResponse,
  AdminProPlanDashboard,
  GetAdminProPlanDashboardResponse,
} from "../types/admin";
import {getAdminAnalyticsSummaryData} from "../utils/adminAnalytics";
import {isEntitlementOverrideActive} from "../utils/helpers";
import {sendPushNotificationInternal} from "./notifications";
import {NotificationType} from "../types/api";

const RELEASE_CONTROL_KEYS = [
  "forceUpdateVersion",
  "recommendedVersion",
  "appStoreURL",
  "privacyPolicyURL",
  "termsOfServiceURL",
  "supportEmail",
  "notionFAQDatabaseId",
] as const;

const MIN_SCHEDULE_LEAD_TIME_MS = 5 * 60 * 1000;
const ADMIN_AUDIT_LOG_QUERY_SCAN_FACTOR = 10;
const ADMIN_AUDIT_LOG_QUERY_MAX_SCAN = 500;
const ADMIN_ROLE_ORDER: Record<AdminRole, number> = {
  owner: 0,
  support: 1,
  marketer: 2,
};

type ReleaseControlKey = typeof RELEASE_CONTROL_KEYS[number];

const RELEASE_CONTROL_FIELDS:
Record<ReleaseControlKey, AdminReleaseControlField> = {
  forceUpdateVersion: {
    key: "forceUpdateVersion",
    label: "Force Update Version",
    description: "이 버전보다 낮은 앱은 강제 업데이트를 요구합니다.",
    section: "version",
    sectionLabel: "Version Control",
    valueType: "version",
    editableRoles: ["owner"],
    warning: "잘못 올리면 구버전 사용자가 즉시 앱 사용을 막힐 수 있습니다.",
  },
  recommendedVersion: {
    key: "recommendedVersion",
    label: "Recommended Version",
    description: "이 버전보다 낮은 앱에 업데이트 권장 배너를 노출합니다.",
    section: "version",
    sectionLabel: "Version Control",
    valueType: "version",
    editableRoles: ["owner"],
    warning: "과도하게 올리면 정상 사용자에게 불필요한 업데이트 안내가 노출됩니다.",
  },
  appStoreURL: {
    key: "appStoreURL",
    label: "App Store URL",
    description: "업데이트 버튼과 앱 다운로드 이동에 사용하는 링크입니다.",
    section: "version",
    sectionLabel: "Version Control",
    valueType: "url",
    editableRoles: ["owner", "marketer"],
    warning: null,
  },
  privacyPolicyURL: {
    key: "privacyPolicyURL",
    label: "Privacy Policy URL",
    description: "설정 화면과 결제 화면에서 노출하는 개인정보처리방침 링크입니다.",
    section: "legal",
    sectionLabel: "Legal & Policies",
    valueType: "url",
    editableRoles: ["owner", "marketer"],
    warning: null,
  },
  termsOfServiceURL: {
    key: "termsOfServiceURL",
    label: "Terms of Service URL",
    description: "설정 화면과 결제 화면에서 노출하는 이용약관 링크입니다.",
    section: "legal",
    sectionLabel: "Legal & Policies",
    valueType: "url",
    editableRoles: ["owner", "marketer"],
    warning: null,
  },
  supportEmail: {
    key: "supportEmail",
    label: "Support Email",
    description: "문의하기와 운영 지원 연결에 사용하는 대표 이메일입니다.",
    section: "support",
    sectionLabel: "Customer Support",
    valueType: "email",
    editableRoles: ["owner", "marketer"],
    warning: null,
  },
  notionFAQDatabaseId: {
    key: "notionFAQDatabaseId",
    label: "Notion FAQ Database ID",
    description: "도움말/FAQ 화면이 읽는 Notion 데이터베이스 ID입니다.",
    section: "support",
    sectionLabel: "Customer Support",
    valueType: "string",
    editableRoles: ["owner", "marketer"],
    warning: null,
  },
};

const RELEASE_CONTROL_GROUPS: Record<ReleaseControlKey, string> = {
  forceUpdateVersion: "version-control",
  recommendedVersion: "version-control",
  appStoreURL: "version-control",
  privacyPolicyURL: "leagal-policies",
  termsOfServiceURL: "leagal-policies",
  supportEmail: "customer-support",
  notionFAQDatabaseId: "customer-support",
};

/**
 * Returns true when the stored role matches a supported admin role.
 * @param {unknown} value The stored Firestore role value.
 * @return {boolean} True when the role is supported.
 */
function isAdminRole(value: unknown): value is AdminRole {
  return value === "owner" || value === "support" || value === "marketer";
}

/**
 * Returns true when the stored push audience is supported.
 * @param {unknown} value The stored audience value.
 * @return {boolean} True when the audience is supported.
 */
function isAdminPushAudience(value: unknown): value is AdminPushAudience {
  return (
    value === "all" ||
    value === "pro" ||
    value === "free" ||
    value === "test_user"
  );
}

/**
 * Returns true when the stored push job status is supported.
 * @param {unknown} value The stored status value.
 * @return {boolean} True when the status is supported.
 */
function isAdminPushJobStatus(value: unknown): value is AdminPushJobStatus {
  return (
    value === "scheduled" ||
    value === "processing" ||
    value === "completed" ||
    value === "failed" ||
    value === "cancelled" ||
    value === "dry_run"
  );
}

/**
 * Loads and validates the admin permission document for the user.
 * @param {string} userId The authenticated user id.
 * @return {Promise<AdminUserDocument>} The validated admin document.
 */
export async function getAdminUserDocument(
  userId: string
): Promise<AdminUserDocument> {
  const snapshot = await admin.firestore()
    .collection("admin").doc("config").collection("users")
    .doc(userId)
    .get();

  if (!snapshot.exists) {
    throw new HttpsError("permission-denied", "관리자 권한이 없습니다");
  }

  const data = snapshot.data();
  if (!data) {
    throw new HttpsError("internal", "관리자 데이터를 읽을 수 없습니다");
  }

  const role = data.role;
  if (!isAdminRole(role)) {
    throw new HttpsError("permission-denied", "유효하지 않은 관리자 권한입니다");
  }

  if (data.enabled === false) {
    throw new HttpsError("permission-denied", "비활성화된 관리자 계정입니다");
  }

  return {
    role,
    email: typeof data.email === "string" ? data.email : null,
    enabled: data.enabled ?? true,
  };
}

/**
 * Ensures the admin role is allowed for the requested action.
 * @param {AdminUserDocument} adminUser The validated admin document.
 * @param {AdminRole[]} allowedRoles The permitted roles.
 * @return {void}
 */
function requireAdminRole(
  adminUser: AdminUserDocument,
  allowedRoles: AdminRole[]
): void {
  if (!allowedRoles.includes(adminUser.role)) {
    throw new HttpsError(
      "permission-denied",
      "이 작업을 수행할 권한이 없습니다"
    );
  }
}

/**
 * Builds a normalized admin account payload from Firestore.
 * @param {string} userId The admin user id.
 * @param {Record<string, unknown>} data The stored admin user document.
 * @return {AdminAccount} The normalized admin account.
 */
function buildAdminAccount(
  userId: string,
  data: Record<string, unknown>
): AdminAccount {
  if (!isAdminRole(data.role)) {
    throw new HttpsError(
      "internal",
      "adminUsers 데이터 형식이 올바르지 않습니다"
    );
  }

  return {
    userId,
    email: typeof data.email === "string" ? data.email : null,
    role: data.role,
    enabled: data.enabled !== false,
  };
}

/**
 * Sorts admin accounts by enabled state, role, then email.
 * @param {AdminAccount} left The first account.
 * @param {AdminAccount} right The second account.
 * @return {number} Sort comparator result.
 */
function compareAdminAccounts(left: AdminAccount, right: AdminAccount): number {
  if (left.enabled !== right.enabled) {
    return left.enabled ? -1 : 1;
  }

  if (left.role !== right.role) {
    return ADMIN_ROLE_ORDER[left.role] - ADMIN_ROLE_ORDER[right.role];
  }

  return (left.email ?? left.userId).localeCompare(right.email ?? right.userId);
}

/**
 * Loads all admin accounts sorted for console display.
 * @return {Promise<AdminAccount[]>} The normalized admin accounts.
 */
async function listAdminAccounts(): Promise<AdminAccount[]> {
  const snapshot = await admin.firestore()
    .collection("admin").doc("config").collection("users")
    .get();

  return snapshot.docs
    .map((doc) =>
      buildAdminAccount(doc.id, doc.data() as Record<string, unknown>)
    )
    .sort(compareAdminAccounts);
}

/**
 * Counts enabled owner accounts.
 * @return {Promise<number>} The number of enabled owners.
 */
async function getEnabledOwnerCount(): Promise<number> {
  const accounts = await listAdminAccounts();
  return accounts
    .filter((account) => account.role === "owner" && account.enabled)
    .length;
}

/**
 * Resolves a Firebase Auth user by email for admin onboarding.
 * @param {string} email The target email address.
 * @return {Promise<object>} The auth user.
 */
async function getFirebaseAuthUserByEmail(email: string): Promise<{
  uid: string;
  email: string | null;
}> {
  try {
    const user = await admin.auth().getUserByEmail(email);
    return {
      uid: user.uid,
      email: user.email ?? email,
    };
  } catch (error) {
    const authError = error as {code?: string};
    if (authError.code === "auth/user-not-found") {
      throw new HttpsError(
        "not-found",
        "해당 이메일의 Firebase Auth 사용자를 찾을 수 없습니다"
      );
    }

    throw new HttpsError("internal", "Firebase Auth 사용자를 조회할 수 없습니다");
  }
}

/**
 * Ensures owner safety rules before mutating an admin account.
 * @param {object} params The update context.
 * @return {Promise<void>} Resolves when the update is allowed.
 */
async function ensureAdminAccountUpdateAllowed(params: {
  actorId: string;
  currentUser: AdminAccount;
  nextRole: AdminRole;
  nextEnabled: boolean;
}): Promise<void> {
  const {actorId, currentUser, nextRole, nextEnabled} = params;

  if (
    actorId === currentUser.userId &&
    (!nextEnabled || nextRole !== "owner")
  ) {
    throw new HttpsError(
      "permission-denied",
      "자기 자신의 owner 권한을 해제하거나 비활성화할 수 없습니다"
    );
  }

  if (
    currentUser.role === "owner" &&
    currentUser.enabled &&
    (!nextEnabled || nextRole !== "owner")
  ) {
    const enabledOwnerCount = await getEnabledOwnerCount();

    if (enabledOwnerCount <= 1) {
      throw new HttpsError(
        "failed-precondition",
        "마지막 enabled owner는 권한을 변경하거나 비활성화할 수 없습니다"
      );
    }
  }
}

export const getAdminSession = onCall<Record<string, never>>(
  {region: REGION},
  async (request): Promise<GetAdminSessionResponse> => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "로그인이 필요합니다");
    }

    const userId = request.auth.uid;
    const adminUser = await getAdminUserDocument(userId);

    return {
      success: true,
      userId,
      email: adminUser.email ?? request.auth.token.email ?? null,
      role: adminUser.role,
      enabled: adminUser.enabled ?? true,
    };
  }
);

export const getAdminUsers = onCall<Record<string, never>>(
  {region: REGION},
  async (request): Promise<GetAdminUsersResponse> => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "로그인이 필요합니다");
    }

    const adminUser = await getAdminUserDocument(request.auth.uid);
    requireAdminRole(adminUser, ["owner"]);

    return {
      success: true,
      users: await listAdminAccounts(),
    };
  }
);

export const createAdminUser = onCall<CreateAdminUserRequest>(
  {region: REGION},
  async (request): Promise<CreateAdminUserResponse> => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "로그인이 필요합니다");
    }

    const actorId = request.auth.uid;
    const adminUser = await getAdminUserDocument(actorId);
    requireAdminRole(adminUser, ["owner"]);

    const email = requireEmail(request.data.email, "email");
    const role = requireAdminRoleValue(request.data.role, "role");
    const enabled = request.data.enabled !== false;
    const authUser = await getFirebaseAuthUserByEmail(email);
    const docRef = adminCol("users").doc(authUser.uid);
    const snapshot = await docRef.get();

    if (snapshot.exists) {
      throw new HttpsError("already-exists", "이미 등록된 admin 사용자입니다");
    }

    const nextUser: AdminAccount = {
      userId: authUser.uid,
      email: authUser.email ?? email,
      role,
      enabled,
    };

    await docRef.set({
      role,
      email: nextUser.email,
      enabled,
    });

    await writeAuditLog({
      actorId,
      action: "create_admin_user",
      targetType: "admin_user",
      targetId: authUser.uid,
      before: null,
      after: nextUser,
    });

    return {
      success: true,
      user: nextUser,
    };
  }
);

export const updateAdminUser = onCall<UpdateAdminUserRequest>(
  {region: REGION},
  async (request): Promise<UpdateAdminUserResponse> => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "로그인이 필요합니다");
    }

    const actorId = request.auth.uid;
    const adminUser = await getAdminUserDocument(actorId);
    requireAdminRole(adminUser, ["owner"]);

    const userId = requireString(request.data.userId, "userId");
    const role = requireAdminRoleValue(request.data.role, "role");
    const enabled = requireBoolean(request.data.enabled, "enabled");
    const docRef = adminCol("users").doc(userId);
    const snapshot = await docRef.get();

    if (!snapshot.exists) {
      throw new HttpsError("not-found", "admin 사용자를 찾을 수 없습니다");
    }

    const currentUser = buildAdminAccount(
      userId,
      snapshot.data() as Record<string, unknown>
    );

    await ensureAdminAccountUpdateAllowed({
      actorId,
      currentUser,
      nextRole: role,
      nextEnabled: enabled,
    });

    if (currentUser.role === role && currentUser.enabled === enabled) {
      return {
        success: true,
        user: currentUser,
      };
    }

    const nextUser: AdminAccount = {
      ...currentUser,
      role,
      enabled,
    };

    await docRef.set({
      role,
      email: currentUser.email,
      enabled,
    });

    await writeAuditLog({
      actorId,
      action: "update_admin_user",
      targetType: "admin_user",
      targetId: userId,
      before: currentUser,
      after: nextUser,
    });

    return {
      success: true,
      user: nextUser,
    };
  }
);

export const getAdminDashboardSummary = onCall<Record<string, never>>(
  {region: REGION},
  async (request): Promise<GetAdminDashboardSummaryResponse> => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "로그인이 필요합니다");
    }

    await getAdminUserDocument(request.auth.uid);

    return {
      success: true,
      summary: await buildAdminDashboardSummary(),
    };
  }
);

export const getAdminAnalyticsSummary =
  onCall<GetAdminAnalyticsSummaryRequest>(
    {
      region: REGION,
      serviceAccount:
        `${process.env.GCLOUD_PROJECT}@appspot.gserviceaccount.com`,
    },
    async (request): Promise<GetAdminAnalyticsSummaryResponse> => {
      if (!request.auth) {
        throw new HttpsError("unauthenticated", "로그인이 필요합니다");
      }

      await getAdminUserDocument(request.auth.uid);

      return {
        success: true,
        summary: await getAdminAnalyticsSummaryData(
          normalizeAnalyticsWindowDays(request.data.windowDays)
        ),
      };
    }
  );

/**
 * Builds a small live summary for the admin dashboard.
 * @return {Promise<AdminDashboardSummary>} The dashboard summary.
 */
async function buildAdminDashboardSummary(): Promise<AdminDashboardSummary> {
  const db = admin.firestore();
  const remoteConfigTemplate = await admin.remoteConfig().getTemplate();
  const [
    usersSnapshot,
    adminUsersSnapshot,
    overridesSnapshot,
    adminPushJobsSnapshot,
    adminAuditLogsSnapshot,
  ] = await Promise.all([
    db.collection("users").get(),
    adminCol("users").get(),
    db.collection("entitlementOverrides").get(),
    adminCol("pushJobs").get(),
    adminCol("auditLogs").get(),
  ]);

  const userIds = usersSnapshot.docs.map((doc) => doc.id);
  const proStates = await Promise.all(
    userIds.map(async (userId) => isEffectivePro(userId))
  );
  const proUsers = proStates.filter(Boolean).length;
  const activeOverrides = overridesSnapshot.docs.filter((doc) =>
    isEntitlementOverrideActive(doc.data())
  ).length;

  return {
    totalUsers: usersSnapshot.docs.length,
    proUsers,
    freeUsers: usersSnapshot.docs.length - proUsers,
    activeOverrides,
    totalAdmins: adminUsersSnapshot.docs.length,
    pushJobCount: adminPushJobsSnapshot.docs.length,
    auditLogCount: adminAuditLogsSnapshot.docs.length,
    remoteConfigVersion:
      remoteConfigTemplate.version?.versionNumber != null ?
        String(remoteConfigTemplate.version.versionNumber) :
        null,
    remoteConfigUpdatedAt:
      toIsoString(remoteConfigTemplate.version?.updateTime) ?? null,
  };
}

/**
 * Builds a user summary payload for admin search results.
 * @param {string} userId The target user id.
 * @param {Record<string, unknown>} userData The stored user document.
 * @return {Promise<AdminUserSummary>} The admin search summary.
 */
async function buildUserSummary(
  userId: string,
  userData: Record<string, unknown>
): Promise<AdminUserSummary> {
  const db = admin.firestore();
  const subscriptionSnapshot = await db.collection("subscriptions")
    .doc(userId)
    .get();
  const overrideSnapshot = await db.collection("entitlementOverrides")
    .doc(userId)
    .get();

  return buildUserSummaryPayload(
    userId,
    userData,
    subscriptionSnapshot.data() as Record<string, unknown> | undefined,
    overrideSnapshot.data() as Record<string, unknown> | undefined
  );
}

/**
 * Builds an admin user summary from preloaded user-related documents.
 * @param {string} userId The target user id.
 * @param {Record<string, unknown>} userData The stored user document.
 * @param {Record<string, unknown> | undefined} subscriptionData The stored
 * subscription document, if any.
 * @param {Record<string, unknown> | undefined} overrideData The stored
 * entitlement override document, if any.
 * @return {AdminUserSummary} The normalized summary payload.
 */
function buildUserSummaryPayload(
  userId: string,
  userData: Record<string, unknown>,
  subscriptionData?: Record<string, unknown>,
  overrideData?: Record<string, unknown>
): AdminUserSummary {
  const groups = userData.groups && typeof userData.groups === "object" ?
    userData.groups as Record<string, unknown> :
    {};
  const devices = userData.devices && typeof userData.devices === "object" ?
    userData.devices as Record<string, unknown> :
    {};

  return {
    userId,
    name: typeof userData.name === "string" ? userData.name : null,
    nickname: typeof userData.nickname === "string" ? userData.nickname : null,
    email: typeof userData.email === "string" ? userData.email : null,
    groupCount: Object.keys(groups).length,
    deviceCount: Object.keys(devices).length,
    subscriptionStatus:
      typeof subscriptionData?.status === "string" ?
        subscriptionData.status :
        null,
    overrideActive: isEntitlementOverrideActive(overrideData),
  };
}

/**
 * Normalizes a requested admin user search field.
 * @param {unknown} value The raw request value.
 * @return {AdminUserSearchField} The validated field.
 */
function normalizeUserSearchField(value: unknown): AdminUserSearchField {
  if (
    value === "userId" ||
    value === "email" ||
    value === "nickname"
  ) {
    return value;
  }

  return "all";
}

/**
 * Normalizes a requested subscription filter.
 * @param {unknown} value The raw request value.
 * @return {AdminSubscriptionFilter} The validated filter.
 */
function normalizeSubscriptionFilter(value: unknown): AdminSubscriptionFilter {
  if (value === "subscribed" || value === "not_subscribed") {
    return value;
  }

  return "all";
}

/**
 * Normalizes a requested entitlement override filter.
 * @param {unknown} value The raw request value.
 * @return {AdminOverrideFilter} The validated filter.
 */
function normalizeOverrideFilter(value: unknown): AdminOverrideFilter {
  if (value === "active" || value === "inactive") {
    return value;
  }

  return "all";
}

/**
 * Checks whether a user summary matches the requested subscription filter.
 * @param {AdminUserSummary} summary The summary candidate.
 * @param {AdminSubscriptionFilter} filter The selected filter.
 * @return {boolean} True when the summary should be included.
 */
function matchesSubscriptionFilter(
  summary: AdminUserSummary,
  filter: AdminSubscriptionFilter
): boolean {
  if (filter === "all") {
    return true;
  }

  const isSubscribed = Boolean(summary.subscriptionStatus);
  return filter === "subscribed" ? isSubscribed : !isSubscribed;
}

/**
 * Checks whether a user summary matches the requested override filter.
 * @param {AdminUserSummary} summary The summary candidate.
 * @param {AdminOverrideFilter} filter The selected filter.
 * @return {boolean} True when the summary should be included.
 */
function matchesOverrideFilter(
  summary: AdminUserSummary,
  filter: AdminOverrideFilter
): boolean {
  if (filter === "all") {
    return true;
  }

  return filter === "active" ? summary.overrideActive : !summary.overrideActive;
}

/**
 * Writes an immutable admin audit log entry.
 * @param {object} params The audit log payload.
 * @return {Promise<void>} Resolves after the log is written.
 */
async function writeAuditLog(params: {
  actorId: string;
  action: string;
  targetType?: string;
  targetId: string;
  before?: unknown;
  after?: unknown;
}) {
  const {
    actorId,
    action,
    targetType,
    targetId,
    before,
    after,
  } = params;
  await adminCol("auditLogs").add({
    actorId,
    action,
    targetType: targetType ?? "user",
    targetId,
    before: before ?? null,
    after: after ?? null,
    createdAt: FieldValue.serverTimestamp(),
  });
}

/**
 * Reads a Remote Config string parameter value.
 * @param {RemoteConfigTemplate} template The Remote Config template.
 * @param {ReleaseControlKey} key The Remote Config key.
 * @return {string} The current default value.
 */
function getRemoteConfigParameter(
  template: RemoteConfigTemplate,
  key: ReleaseControlKey
) {
  if (template.parameters[key]) {
    return template.parameters[key];
  }

  for (const group of Object.values(template.parameterGroups ?? {})) {
    if (group.parameters[key]) {
      return group.parameters[key];
    }
  }

  return null;
}

/**
 * Reads a Remote Config string parameter value.
 * @param {RemoteConfigTemplate} template The Remote Config template.
 * @param {ReleaseControlKey} key The Remote Config key.
 * @return {string} The current default value.
 */
function getRemoteConfigValue(
  template: RemoteConfigTemplate,
  key: ReleaseControlKey
): string {
  const defaultValue = getRemoteConfigParameter(template, key)?.defaultValue;
  if (
    defaultValue &&
    "value" in defaultValue &&
    typeof (defaultValue as RemoteConfigParameterValue & {value?: unknown})
      .value === "string"
  ) {
    return defaultValue.value;
  }

  return "";
}

/**
 * Updates a Remote Config value while preserving parameter grouping.
 * @param {RemoteConfigTemplate} template The mutable template.
 * @param {ReleaseControlKey} key The parameter key.
 * @param {string} value The next default value.
 * @return {void}
 */
function setRemoteConfigValue(
  template: RemoteConfigTemplate,
  key: ReleaseControlKey,
  value: string
): void {
  const currentParameter = getRemoteConfigParameter(template, key);
  const nextParameter = {
    ...(currentParameter ?? {}),
    defaultValue: {value},
  };

  if (template.parameters[key]) {
    template.parameters[key] = nextParameter;
    return;
  }

  for (const group of Object.values(template.parameterGroups ?? {})) {
    if (group.parameters[key]) {
      group.parameters[key] = nextParameter;
      return;
    }
  }

  const targetGroupKey = RELEASE_CONTROL_GROUPS[key];
  if (!template.parameterGroups[targetGroupKey]) {
    template.parameterGroups[targetGroupKey] = {
      description: "",
      parameters: {},
    };
  }

  template.parameterGroups[targetGroupKey].parameters[key] = nextParameter;
}

/**
 * Returns true when the given admin role can edit the selected release control.
 * @param {AdminRole} role The current admin role.
 * @param {ReleaseControlKey} key The release control key.
 * @return {boolean} True when the field is editable.
 */
function canEditReleaseControlKey(
  role: AdminRole,
  key: ReleaseControlKey
): boolean {
  return RELEASE_CONTROL_FIELDS[key].editableRoles.includes(role);
}

/**
 * Builds the field metadata for the Release Controls UI.
 * @return {AdminReleaseControlField[]} The field descriptors.
 */
function buildReleaseControlFields(): AdminReleaseControlField[] {
  return RELEASE_CONTROL_KEYS.map((key) => ({
    ...RELEASE_CONTROL_FIELDS[key],
    editableRoles: [...RELEASE_CONTROL_FIELDS[key].editableRoles],
  }));
}

/**
 * Extracts a key/value snapshot for the selected release control fields.
 * @param {controls} controls The normalized release controls payload.
 * @param {keys} keys The keys to extract.
 * @return {Record<ReleaseControlKey, string>} The extracted snapshot.
 */
function pickReleaseControlValues(
  controls: AdminReleaseControls,
  keys: ReleaseControlKey[]
): Partial<Record<ReleaseControlKey, string>> {
  return keys.reduce((result, key) => ({
    ...result,
    [key]: controls[key],
  }), {});
}

/**
 * Builds the admin release controls payload from a Remote Config template.
 * @param {RemoteConfigTemplate} template The Remote Config template.
 * @return {AdminReleaseControls} The normalized release control payload.
 */
function buildReleaseControls(
  template: RemoteConfigTemplate
): AdminReleaseControls {
  const {version} = template;
  return {
    forceUpdateVersion: getRemoteConfigValue(template, "forceUpdateVersion"),
    recommendedVersion: getRemoteConfigValue(template, "recommendedVersion"),
    appStoreURL: getRemoteConfigValue(template, "appStoreURL"),
    privacyPolicyURL: getRemoteConfigValue(template, "privacyPolicyURL"),
    termsOfServiceURL: getRemoteConfigValue(template, "termsOfServiceURL"),
    supportEmail: getRemoteConfigValue(template, "supportEmail"),
    notionFAQDatabaseId: getRemoteConfigValue(
      template,
      "notionFAQDatabaseId"
    ),
    fields: buildReleaseControlFields(),
    versionNumber: version?.versionNumber != null ?
      String(version.versionNumber) :
      null,
    updateTime: version?.updateTime ?? null,
    updateUserEmail: version?.updateUser?.email ?? null,
  };
}

/**
 * Converts Firestore timestamp-like values into ISO strings.
 * @param {unknown} value The timestamp candidate.
 * @return {string | null} The ISO string when convertible.
 */
function toIsoString(value: unknown): string | null {
  if (typeof value === "string") {
    return value;
  }

  if (
    value &&
    typeof value === "object" &&
    "toDate" in value &&
    typeof value.toDate === "function"
  ) {
    return value.toDate().toISOString();
  }

  return null;
}

/**
 * Normalizes an admin audit log document for the console UI.
 * @param {string} id The document id.
 * @param {Record<string, unknown>} data The stored document data.
 * @return {AdminAuditLog} The normalized audit log.
 */
function buildAdminAuditLog(
  id: string,
  data: Record<string, unknown>
): AdminAuditLog {
  return {
    id,
    actorId: typeof data.actorId === "string" ? data.actorId : null,
    action: typeof data.action === "string" ? data.action : null,
    targetType: typeof data.targetType === "string" ? data.targetType : null,
    targetId: typeof data.targetId === "string" ? data.targetId : null,
    before: data.before ?? null,
    after: data.after ?? null,
    createdAt: toIsoString(data.createdAt),
  };
}

/**
 * Chooses the most selective audit log filter that can safely run in Firestore.
 * Secondary filters remain in-memory to keep the required index set small.
 * @param {object} params Optional audit log filters.
 * @return {object | null} The primary Firestore filter, if any.
 */
function pickAdminAuditLogPrimaryFilter(params: {
  action?: string;
  actorId?: string;
  targetType?: string;
  targetId?: string;
}): {
  field: "action" | "actorId" | "targetType" | "targetId";
  value: string;
} | null {
  if (params.targetId) {
    return {
      field: "targetId",
      value: params.targetId,
    };
  }

  if (params.actorId) {
    return {
      field: "actorId",
      value: params.actorId,
    };
  }

  if (params.action) {
    return {
      field: "action",
      value: params.action,
    };
  }

  if (params.targetType) {
    return {
      field: "targetType",
      value: params.targetType,
    };
  }

  return null;
}

/**
 * Returns true when an audit log matches the requested filters.
 * @param {AdminAuditLog} log The normalized audit log.
 * @param {object} filters The optional filter set.
 * @return {boolean} True when the log matches all filters.
 */
function matchesAdminAuditLogFilters(log: AdminAuditLog, filters: {
  action?: string;
  actorId?: string;
  targetType?: string;
  targetId?: string;
}): boolean {
  if (filters.action && log.action !== filters.action) {
    return false;
  }

  if (filters.actorId && log.actorId !== filters.actorId) {
    return false;
  }

  if (filters.targetType && log.targetType !== filters.targetType) {
    return false;
  }

  if (filters.targetId && log.targetId !== filters.targetId) {
    return false;
  }

  return true;
}

/**
 * Builds a normalized subscription snapshot for the timeline UI.
 * @param {Record<string, unknown> | undefined} data The stored subscription
 * document, if any.
 * @return {AdminSubscriptionSnapshot} The normalized snapshot.
 */
function buildAdminSubscriptionSnapshot(
  data?: Record<string, unknown>
): AdminSubscriptionSnapshot {
  return {
    status: typeof data?.status === "string" ? data.status : null,
    productId: typeof data?.productId === "string" ? data.productId : null,
    expirationDate:
      typeof data?.expirationDate === "string" ? data.expirationDate : null,
    purchaseDate:
      typeof data?.purchaseDate === "string" ? data.purchaseDate : null,
    updatedAt: toIsoString(data?.updatedAt),
  };
}

/**
 * Builds a normalized entitlement override snapshot for the timeline UI.
 * @param {Record<string, unknown>} data The stored override document.
 * @return {AdminEntitlementOverrideSnapshot} The normalized snapshot.
 */
function buildAdminEntitlementOverrideSnapshot(
  data: Record<string, unknown>
): AdminEntitlementOverrideSnapshot {
  return {
    isActive: isEntitlementOverrideActive(data),
    type: typeof data.type === "string" ? data.type : null,
    reason: typeof data.reason === "string" ? data.reason : null,
    expiresAt: typeof data.expiresAt === "string" ? data.expiresAt : null,
    createdBy: typeof data.createdBy === "string" ? data.createdBy : null,
    createdAt: toIsoString(data.createdAt),
    revokedBy: typeof data.revokedBy === "string" ? data.revokedBy : null,
    revokedReason:
      typeof data.revokedReason === "string" ? data.revokedReason : null,
    revokedAt: toIsoString(data.revokedAt),
    updatedAt: toIsoString(data.updatedAt),
  };
}

/**
 * Builds a normalized admin push job payload for the console UI.
 * @param {string} id The job document id.
 * @param {Record<string, unknown>} data The stored job document.
 * @return {AdminPushJob} The normalized job payload.
 */
function buildAdminPushJob(
  id: string,
  data: Record<string, unknown>
): AdminPushJob {
  const result = data.result && typeof data.result === "object" ?
    data.result as Record<string, unknown> :
    null;

  return {
    id,
    status: isAdminPushJobStatus(data.status) ? data.status : "failed",
    audience: isAdminPushAudience(data.audience) ? data.audience : "all",
    title: typeof data.title === "string" ? data.title : "",
    body: typeof data.body === "string" ? data.body : "",
    dryRun: data.dryRun === true,
    targetCount: typeof data.targetCount === "number" ? data.targetCount : null,
    createdBy: typeof data.createdBy === "string" ? data.createdBy : null,
    testUserId: typeof data.testUserId === "string" ? data.testUserId : null,
    scheduledAt: toIsoString(data.scheduledAt),
    createdAt: toIsoString(data.createdAt),
    executionStartedAt: toIsoString(data.executionStartedAt),
    completedAt: toIsoString(data.completedAt),
    cancelledAt: toIsoString(data.cancelledAt),
    cancelledReason:
      typeof data.cancelledReason === "string" ? data.cancelledReason : null,
    errorMessage:
      typeof data.errorMessage === "string" ? data.errorMessage : null,
    result: result ? {
      successCount:
        typeof result.successCount === "number" ? result.successCount : 0,
      failureCount:
        typeof result.failureCount === "number" ? result.failureCount : 0,
    } : null,
  };
}

/**
 * Normalizes a requested admin push job status filter.
 * @param {unknown} value The raw request value.
 * @return {AdminPushJobStatus | "all"} The validated status filter.
 */
function normalizePushJobStatus(
  value: unknown
): AdminPushJobStatus | "all" {
  return isAdminPushJobStatus(value) ? value : "all";
}

/**
 * Normalizes analytics window input to supported presets.
 * @param {unknown} value The requested window value.
 * @return {AdminAnalyticsWindowDays} The normalized window.
 */
function normalizeAnalyticsWindowDays(
  value: unknown
): AdminAnalyticsWindowDays {
  return value === 1 || value === 7 || value === 30 ? value : 7;
}

/**
 * Ensures a required string field exists.
 * @param {string | undefined} value The candidate value.
 * @param {string} fieldName The field label for errors.
 * @return {string} The trimmed string value.
 */
function requireString(value: string | undefined, fieldName: string): string {
  const trimmed = value?.trim();
  if (!trimmed) {
    throw new HttpsError("invalid-argument", `${fieldName}는 필수입니다`);
  }
  return trimmed;
}

/**
 * Ensures a version string follows x.y.z format.
 * @param {string | undefined} value The candidate version string.
 * @param {string} fieldName The field label for errors.
 * @return {string} The validated version string.
 */
function requireVersionString(
  value: string | undefined,
  fieldName: string
): string {
  const version = requireString(value, fieldName);

  if (!/^\d+\.\d+\.\d+$/.test(version)) {
    throw new HttpsError(
      "invalid-argument",
      `${fieldName}는 x.y.z 형식이어야 합니다`
    );
  }

  return version;
}

/**
 * Ensures a boolean field is explicitly provided.
 * @param {unknown} value The candidate value.
 * @param {string} fieldName The field label for errors.
 * @return {boolean} The validated boolean value.
 */
function requireBoolean(value: unknown, fieldName: string): boolean {
  if (typeof value !== "boolean") {
    throw new HttpsError("invalid-argument", `${fieldName} 형식이 올바르지 않습니다`);
  }

  return value;
}

/**
 * Ensures an admin role field is valid.
 * @param {unknown} value The candidate role.
 * @param {string} fieldName The field label for errors.
 * @return {AdminRole} The validated admin role.
 */
function requireAdminRoleValue(value: unknown, fieldName: string): AdminRole {
  if (!isAdminRole(value)) {
    throw new HttpsError("invalid-argument", `${fieldName} 형식이 올바르지 않습니다`);
  }

  return value;
}

/**
 * Ensures an email field is valid.
 * @param {string | undefined} value The candidate email.
 * @param {string} fieldName The field label for errors.
 * @return {string} The normalized email value.
 */
function requireEmail(value: string | undefined, fieldName: string): string {
  const email = requireString(value, fieldName).toLowerCase();

  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
    throw new HttpsError("invalid-argument", `${fieldName} 형식이 올바르지 않습니다`);
  }

  return email;
}

/**
 * Ensures a value is a valid http(s) URL.
 * @param {string} value The candidate URL value.
 * @param {string} fieldName The field label for errors.
 * @return {string} The validated URL.
 */
function requireHttpUrl(value: string, fieldName: string): string {
  let parsed: URL;
  try {
    parsed = new URL(value);
  } catch {
    throw new HttpsError(
      "invalid-argument",
      `${fieldName} 형식이 올바르지 않습니다`
    );
  }

  if (parsed.protocol !== "http:" && parsed.protocol !== "https:") {
    throw new HttpsError(
      "invalid-argument",
      `${fieldName} 형식이 올바르지 않습니다`
    );
  }

  return value;
}

/**
 * Returns true when a subscription status should grant Pro access.
 * @param {unknown} status The stored subscription status.
 * @return {boolean} True when the status should unlock Pro.
 */
function hasActiveSubscription(status: unknown): boolean {
  return (
    status === "subscribed" ||
    status === "lifetime" ||
    status === "gracePeriod"
  );
}

/**
 * Resolves the user's effective Pro state from subscription and override.
 * @param {string} userId The target user id.
 * @return {Promise<boolean>} Whether the user currently has Pro access.
 */
async function isEffectivePro(userId: string): Promise<boolean> {
  const db = admin.firestore();
  const [subscriptionSnapshot, overrideSnapshot] = await Promise.all([
    db.collection("subscriptions").doc(userId).get(),
    db.collection("entitlementOverrides").doc(userId).get(),
  ]);

  const subscriptionStatus = subscriptionSnapshot.data()?.status;
  const overrideActive = isEntitlementOverrideActive(overrideSnapshot.data());

  return hasActiveSubscription(subscriptionStatus) || overrideActive;
}

/**
 * Resolves the concrete user ids for an admin push audience selector.
 * @param {object} params The audience selector input.
 * @return {Promise<string[]>} The resolved user ids.
 */
async function resolvePushAudience(params: {
  audience: AdminPushAudience;
  testUserId: string | null;
}): Promise<string[]> {
  const {audience, testUserId} = params;
  const db = admin.firestore();

  if (audience === "test_user") {
    if (!testUserId) {
      throw new HttpsError("invalid-argument", "testUserId는 필수입니다");
    }

    const userSnapshot = await db.collection("users").doc(testUserId).get();
    if (!userSnapshot.exists) {
      throw new HttpsError("not-found", "테스트 대상 사용자를 찾을 수 없습니다");
    }

    return [testUserId];
  }

  const usersSnapshot = await db.collection("users").get();
  const allUserIds = usersSnapshot.docs.map((doc) => doc.id);

  if (audience === "all") {
    return allUserIds;
  }

  const effectiveProMap = await Promise.all(
    allUserIds.map(async (userId) => ({
      userId,
      isPro: await isEffectivePro(userId),
    }))
  );

  return effectiveProMap
    .filter((item) => (audience === "pro" ? item.isPro : !item.isPro))
    .map((item) => item.userId);
}

/**
 * Ensures a scheduled push timestamp is valid and in the future.
 * @param {string | undefined} value The requested ISO datetime string.
 * @return {string} The normalized ISO datetime string.
 */
function requireFutureScheduledAt(value: string | undefined): string {
  const scheduledAt = requireString(value, "scheduledAt");
  const parsed = new Date(scheduledAt);

  if (Number.isNaN(parsed.getTime())) {
    throw new HttpsError("invalid-argument", "scheduledAt 형식이 올바르지 않습니다");
  }

  if (parsed.getTime() - Date.now() < MIN_SCHEDULE_LEAD_TIME_MS) {
    throw new HttpsError(
      "invalid-argument",
      "scheduledAt은 최소 5분 이후 시각이어야 합니다"
    );
  }

  return parsed.toISOString();
}

/**
 * Sends an admin push after resolving the concrete audience.
 * @param {object} params The push payload.
 * @return {Promise<{targetCount: number, successCount: number,
 * failureCount: number}>} The delivery counts.
 */
async function deliverAdminPush(params: {
  actorId: string;
  title: string;
  body: string;
  audience: AdminPushAudience;
  testUserId: string | null;
}): Promise<{
  targetCount: number;
  successCount: number;
  failureCount: number;
}> {
  const {actorId, title, body, audience, testUserId} = params;
  const userIds = await resolvePushAudience({
    audience,
    testUserId,
  });
  const result = await sendPushNotificationInternal({
    userIds,
    type: NotificationType.System,
    title,
    body,
    promiseId: null,
    groupId: null,
    relatedUserId: actorId,
    data: null,
  });

  return {
    targetCount: userIds.length,
    successCount: result.successCount,
    failureCount: result.failureCount,
  };
}

/**
 * Returns true when an equivalent scheduled push job already exists.
 * @param {object} params The scheduled push identity fields.
 * @return {Promise<boolean>} True when a duplicate scheduled job exists.
 */
async function hasDuplicateScheduledPushJob(params: {
  title: string;
  body: string;
  audience: AdminPushAudience;
  scheduledAt: string;
  testUserId: string | null;
}): Promise<boolean> {
  const {title, body, audience, scheduledAt, testUserId} = params;
  const snapshot = await admin.firestore()
    .collection("admin").doc("config").collection("pushJobs")
    .get();

  return snapshot.docs.some((doc) => {
    const job = buildAdminPushJob(
      doc.id,
      doc.data() as Record<string, unknown>
    );
    return (
      job.status === "scheduled" &&
      job.title === title &&
      job.body === body &&
      job.audience === audience &&
      job.scheduledAt === scheduledAt &&
      job.testUserId === testUserId
    );
  });
}

export const getAdminUserSummary = onCall<GetAdminUserSummaryRequest>(
  {region: REGION},
  async (request): Promise<GetAdminUserSummaryResponse> => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "로그인이 필요합니다");
    }

    const query = request.data.query?.trim() ?? "";
    const field = normalizeUserSearchField(request.data.field);
    const subscriptionFilter = normalizeSubscriptionFilter(
      request.data.subscription
    );
    const overrideFilter = normalizeOverrideFilter(request.data.override);
    const requestedLimit = request.data.limit ?? 25;
    const limit = Math.min(Math.max(requestedLimit, 1), 50);
    const isDefaultBrowseRequest =
      !query &&
      subscriptionFilter === "all" &&
      overrideFilter === "all";

    const adminUser = await getAdminUserDocument(request.auth.uid);
    requireAdminRole(adminUser, ["owner", "support"]);

    const db = admin.firestore();
    const usersCollection = db.collection("users");
    const matches = new Map<string, Record<string, unknown>>();

    if (query) {
      if (field === "all" || field === "userId") {
        const userIdSnapshot = await usersCollection.doc(query).get();
        if (userIdSnapshot.exists) {
          const data = userIdSnapshot.data();
          if (data) {
            matches.set(userIdSnapshot.id, data as Record<string, unknown>);
          }
        }
      }

      if (field === "all" || field === "email") {
        const emailSnapshot = await usersCollection
          .where("email", "==", query)
          .limit(limit)
          .get();
        emailSnapshot.docs.forEach((doc) => {
          const data = doc.data();
          if (data) {
            matches.set(doc.id, data as Record<string, unknown>);
          }
        });
      }

      if (field === "all" || field === "nickname") {
        const nicknameSnapshot = await usersCollection
          .where("nickname", "==", query)
          .limit(limit)
          .get();
        nicknameSnapshot.docs.forEach((doc) => {
          const data = doc.data();
          if (data) {
            matches.set(doc.id, data as Record<string, unknown>);
          }
        });
      }
    } else {
      const usersSnapshot = isDefaultBrowseRequest ?
        await usersCollection.limit(limit).get() :
        await usersCollection.get();
      usersSnapshot.docs.forEach((doc) => {
        const data = doc.data();
        if (data) {
          matches.set(doc.id, data as Record<string, unknown>);
        }
      });
    }

    const results = await Promise.all(
      [...matches.entries()].map(([userId, userData]) =>
        buildUserSummary(userId, userData)
      )
    );
    const filteredResults = results
      .filter((summary) =>
        matchesSubscriptionFilter(summary, subscriptionFilter) &&
        matchesOverrideFilter(summary, overrideFilter)
      )
      .sort((lhs, rhs) => lhs.userId.localeCompare(rhs.userId))
      .slice(0, limit);

    return {
      success: true,
      results: filteredResults,
    };
  }
);

export const getAdminUserTimeline = onCall<GetAdminUserTimelineRequest>(
  {region: REGION},
  async (request): Promise<GetAdminUserTimelineResponse> => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "로그인이 필요합니다");
    }

    const adminUser = await getAdminUserDocument(request.auth.uid);
    requireAdminRole(adminUser, ["owner", "support"]);

    const userId = request.data.userId?.trim();
    if (!userId) {
      throw new HttpsError("invalid-argument", "userId는 필수입니다");
    }

    const requestedLimit = request.data.limit ?? 20;
    const limit = Math.min(Math.max(requestedLimit, 1), 50);
    const db = admin.firestore();
    const [
      userSnapshot,
      subscriptionSnapshot,
      overrideSnapshot,
      auditSnapshot,
    ] = await Promise.all([
      db.collection("users").doc(userId).get(),
      db.collection("subscriptions").doc(userId).get(),
      db.collection("entitlementOverrides").doc(userId).get(),
      adminCol("auditLogs")
        .where("targetId", "==", userId)
        .orderBy("createdAt", "desc")
        .limit(limit)
        .get(),
    ]);

    const userData = userSnapshot.data();
    if (!userSnapshot.exists || !userData) {
      throw new HttpsError("not-found", "대상 사용자를 찾을 수 없습니다");
    }

    const summary = buildUserSummaryPayload(
      userId,
      userData as Record<string, unknown>,
      subscriptionSnapshot.data() as Record<string, unknown> | undefined,
      overrideSnapshot.data() as Record<string, unknown> | undefined
    );
    const auditLogs = auditSnapshot.docs.map((doc) =>
      buildAdminAuditLog(doc.id, doc.data() as Record<string, unknown>)
    );

    return {
      success: true,
      summary,
      subscription: buildAdminSubscriptionSnapshot(
        subscriptionSnapshot.data() as Record<string, unknown> | undefined
      ),
      override:
        overrideSnapshot.exists && overrideSnapshot.data() ?
          buildAdminEntitlementOverrideSnapshot(
            overrideSnapshot.data() as Record<string, unknown>
          ) :
          null,
      auditLogs,
    };
  }
);

export const getAdminReleaseControls = onCall<Record<string, never>>(
  {region: REGION},
  async (request): Promise<GetAdminReleaseControlsResponse> => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "로그인이 필요합니다");
    }

    const adminUser = await getAdminUserDocument(request.auth.uid);
    requireAdminRole(adminUser, ["owner", "marketer"]);

    const template = await admin.remoteConfig().getTemplate();
    return {
      success: true,
      controls: buildReleaseControls(template),
    };
  }
);

export const updateAdminReleaseControls =
  onCall<UpdateAdminReleaseControlsRequest>(
    {region: REGION},
    async (request): Promise<UpdateAdminReleaseControlsResponse> => {
      if (!request.auth) {
        throw new HttpsError("unauthenticated", "로그인이 필요합니다");
      }

      const actorId = request.auth.uid;
      const adminUser = await getAdminUserDocument(actorId);
      requireAdminRole(adminUser, ["owner", "marketer"]);

      const nextValues = {
        forceUpdateVersion: requireVersionString(
          request.data.forceUpdateVersion,
          "forceUpdateVersion"
        ),
        recommendedVersion: requireVersionString(
          request.data.recommendedVersion,
          "recommendedVersion"
        ),
        appStoreURL: requireHttpUrl(
          requireString(request.data.appStoreURL, "appStoreURL"),
          "appStoreURL"
        ),
        privacyPolicyURL: requireHttpUrl(
          requireString(request.data.privacyPolicyURL, "privacyPolicyURL"),
          "privacyPolicyURL"
        ),
        termsOfServiceURL: requireHttpUrl(
          requireString(request.data.termsOfServiceURL, "termsOfServiceURL"),
          "termsOfServiceURL"
        ),
        supportEmail: requireEmail(
          requireString(request.data.supportEmail, "supportEmail"),
          "supportEmail"
        ),
        notionFAQDatabaseId: requireString(
          request.data.notionFAQDatabaseId,
          "notionFAQDatabaseId"
        ),
      };

      const remoteConfig = admin.remoteConfig();
      const template = await remoteConfig.getTemplate();
      const before = buildReleaseControls(template);
      const changedKeys = RELEASE_CONTROL_KEYS.filter((key) =>
        before[key] !== nextValues[key]
      );

      const forbiddenKeys = changedKeys.filter((key) =>
        !canEditReleaseControlKey(adminUser.role, key)
      );

      if (forbiddenKeys.length > 0) {
        throw new HttpsError(
          "permission-denied",
          `${forbiddenKeys.join(", ")} 수정 권한이 없습니다`
        );
      }

      if (changedKeys.length === 0) {
        return {
          success: true,
          controls: before,
        };
      }

      changedKeys.forEach((key) => {
        setRemoteConfigValue(template, key, nextValues[key]);
      });

      const publishedTemplate = await remoteConfig.publishTemplate(template);
      const after = buildReleaseControls(publishedTemplate);

      await writeAuditLog({
        actorId,
        action: "update_release_controls",
        targetType: "remote_config",
        targetId: "default",
        before: pickReleaseControlValues(before, changedKeys),
        after: pickReleaseControlValues(after, changedKeys),
      });

      return {
        success: true,
        controls: after,
      };
    }
  );

export const getAdminAuditLogs = onCall<GetAdminAuditLogsRequest>(
  {region: REGION},
  async (request): Promise<GetAdminAuditLogsResponse> => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "로그인이 필요합니다");
    }

    await getAdminUserDocument(request.auth.uid);

    const requestedLimit = request.data.limit ?? 50;
    const limit = Math.min(Math.max(requestedLimit, 1), 100);
    const action = request.data.action?.trim();
    const actorId = request.data.actorId?.trim();
    const targetType = request.data.targetType?.trim();
    const targetId = request.data.targetId?.trim();
    const filters = {
      action,
      actorId,
      targetType,
      targetId,
    };
    const primaryFilter = pickAdminAuditLogPrimaryFilter(filters);
    const hasSecondaryFilters = Boolean(
      action && primaryFilter?.field !== "action" ||
      actorId && primaryFilter?.field !== "actorId" ||
      targetType && primaryFilter?.field !== "targetType" ||
      targetId && primaryFilter?.field !== "targetId"
    );
    const queryLimit = hasSecondaryFilters ?
      Math.min(
        limit * ADMIN_AUDIT_LOG_QUERY_SCAN_FACTOR,
        ADMIN_AUDIT_LOG_QUERY_MAX_SCAN
      ) :
      limit;
    let query: FirebaseFirestore.Query = admin.firestore()
      .collection("admin").doc("config").collection("auditLogs");

    if (primaryFilter) {
      query = query.where(primaryFilter.field, "==", primaryFilter.value);
    }

    const snapshot = await query
      .orderBy("createdAt", "desc")
      .limit(queryLimit)
      .get();
    const logs = snapshot.docs
      .map((doc) =>
        buildAdminAuditLog(doc.id, doc.data() as Record<string, unknown>)
      )
      .filter((log) => matchesAdminAuditLogFilters(log, filters))
      .slice(0, limit);

    return {
      success: true,
      logs,
    };
  }
);

export const grantEntitlementOverride = onCall<GrantEntitlementOverrideRequest>(
  {region: REGION},
  async (request): Promise<GrantEntitlementOverrideResponse> => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "로그인이 필요합니다");
    }

    const actorId = request.auth.uid;
    const adminUser = await getAdminUserDocument(actorId);
    requireAdminRole(adminUser, ["owner", "support"]);

    const userId = request.data.userId?.trim();
    const reason = request.data.reason?.trim();

    if (!userId) {
      throw new HttpsError("invalid-argument", "userId는 필수입니다");
    }

    if (!reason) {
      throw new HttpsError("invalid-argument", "reason은 필수입니다");
    }

    const userSnapshot = await admin.firestore()
      .collection("users")
      .doc(userId)
      .get();
    if (!userSnapshot.exists) {
      throw new HttpsError("not-found", "대상 사용자를 찾을 수 없습니다");
    }

    let expiresAt: string | null = null;
    if (request.data.expiresAt) {
      const parsed = new Date(request.data.expiresAt);
      if (Number.isNaN(parsed.getTime())) {
        throw new HttpsError("invalid-argument", "expiresAt 형식이 올바르지 않습니다");
      }
      expiresAt = parsed.toISOString();
    }

    const overrideRef = admin.firestore()
      .collection("entitlementOverrides")
      .doc(userId);
    const before = (await overrideRef.get()).data() ?? null;

    await overrideRef.set({
      isActive: true,
      type: "manual_pro_grant",
      reason,
      expiresAt,
      createdBy: actorId,
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
      revokedAt: null,
      revokedBy: null,
      revokedReason: null,
    }, {merge: true});

    await writeAuditLog({
      actorId,
      action: "grant_entitlement_override",
      targetId: userId,
      before,
      after: {
        isActive: true,
        reason,
        expiresAt,
      },
    });

    return {success: true};
  }
);

export const revokeEntitlementOverride =
  onCall<RevokeEntitlementOverrideRequest>(
    {region: REGION},
    async (request): Promise<RevokeEntitlementOverrideResponse> => {
      if (!request.auth) {
        throw new HttpsError("unauthenticated", "로그인이 필요합니다");
      }

      const actorId = request.auth.uid;
      const adminUser = await getAdminUserDocument(actorId);
      requireAdminRole(adminUser, ["owner", "support"]);

      const userId = request.data.userId?.trim();
      const reason = request.data.reason?.trim() ?? null;

      if (!userId) {
        throw new HttpsError("invalid-argument", "userId는 필수입니다");
      }

      const overrideRef = admin.firestore()
        .collection("entitlementOverrides")
        .doc(userId);
      const existing = await overrideRef.get();
      if (!existing.exists) {
        throw new HttpsError("not-found", "활성 override를 찾을 수 없습니다");
      }

      const before = existing.data() ?? null;

      await overrideRef.set({
        isActive: false,
        updatedAt: FieldValue.serverTimestamp(),
        revokedAt: FieldValue.serverTimestamp(),
        revokedBy: actorId,
        revokedReason: reason,
      }, {merge: true});

      await writeAuditLog({
        actorId,
        action: "revoke_entitlement_override",
        targetId: userId,
        before,
        after: {
          isActive: false,
          revokedReason: reason,
        },
      });

      return {success: true};
    }
  );

export const getAdminPushJobs = onCall<GetAdminPushJobsRequest>(
  {region: REGION},
  async (request): Promise<GetAdminPushJobsResponse> => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "로그인이 필요합니다");
    }

    const adminUser = await getAdminUserDocument(request.auth.uid);
    requireAdminRole(adminUser, ["owner", "marketer"]);

    const requestedLimit = request.data.limit ?? 20;
    const limit = Math.min(Math.max(requestedLimit, 1), 50);
    const status = normalizePushJobStatus(request.data.status);
    const snapshot = await admin.firestore()
      .collection("admin").doc("config").collection("pushJobs")
      .orderBy("createdAt", "desc")
      .get();
    const jobs = snapshot.docs
      .map((doc) =>
        buildAdminPushJob(doc.id, doc.data() as Record<string, unknown>)
      )
      .filter((job) => status === "all" || job.status === status)
      .slice(0, limit);

    return {
      success: true,
      jobs,
    };
  }
);

export const previewAdminPushAudience = onCall<PreviewAdminPushAudienceRequest>(
  {region: REGION},
  async (request): Promise<PreviewAdminPushAudienceResponse> => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "로그인이 필요합니다");
    }

    const adminUser = await getAdminUserDocument(request.auth.uid);
    requireAdminRole(adminUser, ["owner", "marketer"]);

    const audience = request.data.audience;
    const testUserId = request.data.testUserId?.trim() ?? null;

    if (!isAdminPushAudience(audience)) {
      throw new HttpsError("invalid-argument", "audience는 필수입니다");
    }

    const userIds = await resolvePushAudience({
      audience,
      testUserId,
    });

    return {
      success: true,
      targetCount: userIds.length,
    };
  }
);

export const scheduleAdminPush = onCall<ScheduleAdminPushRequest>(
  {region: REGION},
  async (request): Promise<ScheduleAdminPushResponse> => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "로그인이 필요합니다");
    }

    const actorId = request.auth.uid;
    const adminUser = await getAdminUserDocument(actorId);
    requireAdminRole(adminUser, ["owner", "marketer"]);

    const title = requireString(request.data.title, "title");
    const body = requireString(request.data.body, "body");
    const audience = request.data.audience;
    const scheduledAt = requireFutureScheduledAt(request.data.scheduledAt);
    const testUserId = request.data.testUserId?.trim() ?? null;

    if (!isAdminPushAudience(audience)) {
      throw new HttpsError("invalid-argument", "audience는 필수입니다");
    }

    if (audience === "test_user") {
      await resolvePushAudience({
        audience,
        testUserId,
      });
    }

    if (await hasDuplicateScheduledPushJob({
      title,
      body,
      audience,
      scheduledAt,
      testUserId,
    })) {
      throw new HttpsError(
        "already-exists",
        "같은 내용과 대상의 예약 push job이 이미 존재합니다"
      );
    }

    const jobRef = await adminCol("pushJobs").add({
      status: "scheduled",
      audience,
      title,
      body,
      dryRun: false,
      targetCount: null,
      createdBy: actorId,
      testUserId,
      scheduledAt,
      createdAt: FieldValue.serverTimestamp(),
      executionStartedAt: null,
      completedAt: null,
      cancelledAt: null,
      cancelledReason: null,
      errorMessage: null,
      result: null,
    });

    await writeAuditLog({
      actorId,
      action: "schedule_admin_push",
      targetId: jobRef.id,
      after: {
        audience,
        scheduledAt,
        testUserId,
      },
    });

    return {
      success: true,
      jobId: jobRef.id,
      scheduledAt,
    };
  }
);

export const cancelAdminPushJob = onCall<CancelAdminPushJobRequest>(
  {region: REGION},
  async (request): Promise<CancelAdminPushJobResponse> => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "로그인이 필요합니다");
    }

    const actorId = request.auth.uid;
    const adminUser = await getAdminUserDocument(actorId);
    requireAdminRole(adminUser, ["owner", "marketer"]);

    const jobId = requireString(request.data.jobId, "jobId");
    const reason = request.data.reason?.trim() ?? null;
    const jobRef = adminCol("pushJobs").doc(jobId);
    const snapshot = await jobRef.get();

    if (!snapshot.exists) {
      throw new HttpsError("not-found", "대상 push job을 찾을 수 없습니다");
    }

    const job = buildAdminPushJob(
      jobId,
      snapshot.data() as Record<string, unknown>
    );

    if (job.status !== "scheduled") {
      throw new HttpsError(
        "failed-precondition",
        "scheduled 상태의 job만 취소할 수 있습니다"
      );
    }

    await jobRef.set({
      status: "cancelled",
      cancelledAt: FieldValue.serverTimestamp(),
      cancelledReason: reason,
      errorMessage: null,
    }, {merge: true});

    await writeAuditLog({
      actorId,
      action: "cancel_scheduled_admin_push",
      targetId: jobId,
      before: {
        status: job.status,
        scheduledAt: job.scheduledAt,
      },
      after: {
        status: "cancelled",
        reason,
      },
    });

    return {success: true};
  }
);

export const sendAdminPush = onCall<SendAdminPushRequest>(
  {region: REGION},
  async (request): Promise<SendAdminPushResponse> => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "로그인이 필요합니다");
    }

    const actorId = request.auth.uid;
    const adminUser = await getAdminUserDocument(actorId);
    requireAdminRole(adminUser, ["owner", "marketer"]);

    const title = request.data.title?.trim();
    const body = request.data.body?.trim();
    const audience = request.data.audience;
    const dryRun = request.data.dryRun ?? false;
    const testUserId = request.data.testUserId?.trim() ?? null;

    if (!title || !body) {
      throw new HttpsError("invalid-argument", "title과 body는 필수입니다");
    }

    if (!audience) {
      throw new HttpsError("invalid-argument", "audience는 필수입니다");
    }

    if (!isAdminPushAudience(audience)) {
      throw new HttpsError("invalid-argument", "audience는 필수입니다");
    }

    const jobRef = await adminCol("pushJobs").add({
      status: dryRun ? "dry_run" : "processing",
      audience,
      title,
      body,
      dryRun,
      targetCount: null,
      createdBy: actorId,
      testUserId,
      result: dryRun ? {
        successCount: 0,
        failureCount: 0,
      } : null,
      scheduledAt: null,
      createdAt: FieldValue.serverTimestamp(),
      executionStartedAt: dryRun ? null : FieldValue.serverTimestamp(),
      completedAt: null,
      cancelledAt: null,
      cancelledReason: null,
      errorMessage: null,
    });

    if (dryRun) {
      const userIds = await resolvePushAudience({
        audience,
        testUserId,
      });

      await jobRef.set({
        targetCount: userIds.length,
      }, {merge: true});

      await writeAuditLog({
        actorId,
        action: "dry_run_admin_push",
        targetId: jobRef.id,
        after: {
          audience,
          targetCount: userIds.length,
        },
      });

      return {
        success: true,
        dryRun: true,
        targetCount: userIds.length,
        successCount: 0,
        failureCount: 0,
        jobId: jobRef.id,
      };
    }

    const delivery = await deliverAdminPush({
      actorId,
      title,
      body,
      audience,
      testUserId,
    });

    await jobRef.set({
      status: "completed",
      targetCount: delivery.targetCount,
      result: {
        successCount: delivery.successCount,
        failureCount: delivery.failureCount,
      },
      completedAt: FieldValue.serverTimestamp(),
      errorMessage: null,
    }, {merge: true});

    await writeAuditLog({
      actorId,
      action: "send_admin_push",
      targetId: jobRef.id,
      after: {
        audience,
        targetCount: delivery.targetCount,
        successCount: delivery.successCount,
        failureCount: delivery.failureCount,
      },
    });

    return {
      success: true,
      dryRun: false,
      targetCount: delivery.targetCount,
      successCount: delivery.successCount,
      failureCount: delivery.failureCount,
      jobId: jobRef.id,
    };
  }
);

export const dispatchScheduledAdminPushes = onSchedule(
  {
    schedule: "* * * * *",
    region: REGION,
    timeZone: "UTC",
  },
  async () => {
    const now = new Date(Date.now());
    const snapshot = await admin.firestore()
      .collection("admin").doc("config").collection("pushJobs")
      .where("status", "==", "scheduled")
      .where("scheduledAt", "<=", now.toISOString())
      .orderBy("scheduledAt", "asc")
      .get();

    for (const doc of snapshot.docs) {
      const data = doc.data() as Record<string, unknown>;
      const job = buildAdminPushJob(doc.id, data);

      if (!job.scheduledAt) {
        continue;
      }

      const scheduledTime = new Date(job.scheduledAt);
      if (Number.isNaN(scheduledTime.getTime())) {
        continue;
      }

      await doc.ref.set({
        status: "processing",
        executionStartedAt: FieldValue.serverTimestamp(),
        errorMessage: null,
      }, {merge: true});

      try {
        if (!isAdminPushAudience(data.audience)) {
          throw new Error("유효하지 않은 audience입니다");
        }

        const actorId = job.createdBy ?? "system";
        const delivery = await deliverAdminPush({
          actorId,
          title: job.title,
          body: job.body,
          audience: data.audience,
          testUserId: job.testUserId,
        });

        await doc.ref.set({
          status: "completed",
          targetCount: delivery.targetCount,
          result: {
            successCount: delivery.successCount,
            failureCount: delivery.failureCount,
          },
          completedAt: FieldValue.serverTimestamp(),
          errorMessage: null,
        }, {merge: true});

        await writeAuditLog({
          actorId,
          action: "send_scheduled_admin_push",
          targetId: doc.id,
          after: {
            audience: data.audience,
            scheduledAt: job.scheduledAt,
            targetCount: delivery.targetCount,
            successCount: delivery.successCount,
            failureCount: delivery.failureCount,
          },
        });
      } catch (error) {
        const errorMessage = error instanceof Error ?
          error.message :
          "예약 푸시 실행에 실패했습니다";

        await doc.ref.set({
          status: "failed",
          errorMessage,
          completedAt: FieldValue.serverTimestamp(),
        }, {merge: true});

        await writeAuditLog({
          actorId: job.createdBy ?? "system",
          action: "fail_scheduled_admin_push",
          targetId: doc.id,
          after: {
            scheduledAt: job.scheduledAt,
            errorMessage,
          },
        });
      }
    }
  }
);

// ============================================================================
// Coupon Functions
// ============================================================================

import * as crypto from "crypto";

const COUPON_CODE_LENGTH = 8;

/**
 * Generates a random coupon code.
 * @return {string} Generated coupon code.
 */
function generateCouponCode(): string {
  const chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
  const bytes = crypto.randomBytes(COUPON_CODE_LENGTH);
  let code = "";
  for (let i = 0; i < COUPON_CODE_LENGTH; i++) {
    code += chars[bytes[i] % chars.length];
  }
  return code;
}

/**
 * Converts Firestore document data to AdminCoupon.
 * @param {string} code - Coupon code.
 * @param {FirebaseFirestore.DocumentData} data - Document data.
 * @return {AdminCoupon} Converted coupon object.
 */
function toCouponSnapshot(
  code: string,
  data: FirebaseFirestore.DocumentData,
): AdminCoupon {
  const redeemedAt =
    data.redeemedAt?.toDate?.()?.toISOString?.() ??
    data.redeemedAt ?? null;
  const expiresAt =
    data.expiresAt?.toDate?.()?.toISOString?.() ??
    data.expiresAt ?? "";
  const createdAt =
    data.createdAt?.toDate?.()?.toISOString?.() ??
    data.createdAt ?? "";
  return {
    code,
    durationDays: data.durationDays ?? 0,
    memo: data.memo ?? "",
    redeemedBy: data.redeemedBy ?? null,
    redeemedAt,
    expiresAt,
    createdBy: data.createdBy ?? "",
    createdAt,
  };
}

export const createCoupon = onCall<CreateCouponRequest>(
  {region: REGION},
  async (request): Promise<CreateCouponResponse> => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "로그인이 필요합니다");
    }

    const actorId = request.auth.uid;
    const adminUser = await getAdminUserDocument(actorId);
    requireAdminRole(adminUser, ["owner", "marketer"]);

    const durationDays = request.data.durationDays;
    if (durationDays !== 30 && durationDays !== 90) {
      throw new HttpsError("invalid-argument", "durationDays는 30 또는 90이어야 합니다");
    }

    let code = request.data.code?.trim().toUpperCase();
    if (code) {
      const existing =
        await adminCol("coupons").doc(code).get();
      if (existing.exists) {
        throw new HttpsError(
          "already-exists", "이미 존재하는 쿠폰 코드입니다"
        );
      }
    } else {
      let attempts = 0;
      do {
        code = generateCouponCode();
        const existing =
          await adminCol("coupons").doc(code).get();
        if (!existing.exists) break;
        attempts++;
      } while (attempts < 10);
      if (attempts >= 10) {
        throw new HttpsError("internal", "쿠폰 코드 생성에 실패했습니다");
      }
    }

    const expiresAt = new Date(
      Date.now() + durationDays * 24 * 60 * 60 * 1000
    );

    const memo = (request.data.memo ?? "").trim();

    const couponData = {
      durationDays,
      memo,
      redeemedBy: null,
      redeemedAt: null,
      expiresAt: expiresAt.toISOString(),
      createdBy: actorId,
      createdAt: FieldValue.serverTimestamp(),
    };

    await adminCol("coupons").doc(code).set(couponData);

    await writeAuditLog({
      actorId,
      action: "create_coupon",
      targetType: "coupon",
      targetId: code,
      after: {durationDays, expiresAt: expiresAt.toISOString()},
    });

    return {
      success: true,
      coupon: {
        code,
        durationDays,
        memo,
        redeemedBy: null,
        redeemedAt: null,
        expiresAt: expiresAt.toISOString(),
        createdBy: actorId,
        createdAt: new Date().toISOString(),
      },
    };
  }
);

export const getAdminCoupons = onCall<GetAdminCouponsRequest>(
  {region: REGION},
  async (request): Promise<GetAdminCouponsResponse> => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "로그인이 필요합니다");
    }

    const actorId = request.auth.uid;
    const adminUser = await getAdminUserDocument(actorId);
    requireAdminRole(adminUser, ["owner", "marketer"]);

    const statusFilter = request.data.status ?? "all";
    const limit = Math.min(request.data.limit ?? 50, 200);

    const snapshot = await admin.firestore()
      .collection("admin").doc("config").collection("coupons")
      .orderBy("createdAt", "desc")
      .limit(limit)
      .get();

    const now = new Date();
    const coupons: AdminCoupon[] = [];

    for (const doc of snapshot.docs) {
      const data = doc.data();
      const coupon = toCouponSnapshot(doc.id, data);

      if (statusFilter === "all") {
        coupons.push(coupon);
        continue;
      }

      const isRedeemed = !!data.redeemedBy;
      const isExpired = !isRedeemed &&
        coupon.expiresAt !== "" &&
        new Date(coupon.expiresAt) < now;

      if (
        (statusFilter === "redeemed" && isRedeemed) ||
        (statusFilter === "expired" && isExpired) ||
        (statusFilter === "available" && !isRedeemed && !isExpired)
      ) {
        coupons.push(coupon);
      }
    }

    return {success: true, coupons};
  }
);

/**
 * Expires a coupon immediately.
 */
export const expireCoupon = onCall<ExpireCouponRequest>(
  {region: REGION},
  async (request): Promise<ExpireCouponResponse> => {
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated", "로그인이 필요합니다"
      );
    }

    const actorId = request.auth.uid;
    const adminUser = await getAdminUserDocument(actorId);
    requireAdminRole(adminUser, ["owner", "marketer"]);

    const code = request.data.code?.trim().toUpperCase();
    if (!code) {
      throw new HttpsError(
        "invalid-argument", "쿠폰 코드가 필요합니다"
      );
    }

    const couponRef = adminCol("coupons").doc(code);
    const couponDoc = await couponRef.get();

    if (!couponDoc.exists) {
      throw new HttpsError("not-found", "쿠폰을 찾을 수 없습니다");
    }

    const data = couponDoc.data()!;
    if (data.redeemedBy) {
      throw new HttpsError(
        "failed-precondition",
        "이미 사용된 쿠폰은 만료 처리할 수 없습니다"
      );
    }

    await couponRef.update({
      expiresAt: new Date().toISOString(),
    });

    await writeAuditLog({
      actorId,
      action: "expire_coupon",
      targetType: "coupon",
      targetId: code,
    });

    return {success: true};
  }
);

// ============================================================================
// ProPlan Dashboard
// ============================================================================

const DEFAULT_PROPLAN_PRICES = {
  monthly: 3900,
  yearly: 39000,
  lifetime: 59000,
};

/** Fetches Pro plan prices from Firestore or returns defaults. */
async function getProPlanPrices(): Promise<typeof DEFAULT_PROPLAN_PRICES> {
  const doc = await admin.firestore()
    .collection("admin").doc("proPlanPrices").get();
  if (!doc.exists) return DEFAULT_PROPLAN_PRICES;
  const data = doc.data()!;
  return {
    monthly: typeof data.monthly === "number" ?
      data.monthly : DEFAULT_PROPLAN_PRICES.monthly,
    yearly: typeof data.yearly === "number" ?
      data.yearly : DEFAULT_PROPLAN_PRICES.yearly,
    lifetime: typeof data.lifetime === "number" ?
      data.lifetime : DEFAULT_PROPLAN_PRICES.lifetime,
  };
}

/**
 * Builds a ProPlan dashboard summary with subscription breakdown,
 * revenue estimates, coupon stats, and recent activities.
 *
 * NOTE: 전체 컬렉션 스캔 방식은 기존 buildAdminDashboardSummary()와 동일합니다.
 * 사용자 수가 대규모로 증가하면 집계 문서(counter document) 도입을 검토하세요.
 */
async function buildProPlanDashboard(): Promise<AdminProPlanDashboard> {
  const db = admin.firestore();

  const [
    usersSnapshot,
    subscriptionsSnapshot,
    overridesSnapshot,
    couponsSnapshot,
    entitlementsSnapshot,
    prices,
  ] = await Promise.all([
    db.collection("users").get(),
    db.collection("subscriptions").get(),
    db.collection("entitlementOverrides").get(),
    adminCol("coupons").get(),
    db.collection("entitlements").where("hasPro", "==", true).get(),
    getProPlanPrices(),
  ]);

  // Subscription breakdown by plan type
  let monthlyCount = 0;
  let yearlyCount = 0;
  let lifetimeCount = 0;
  let gracePeriodCount = 0;

  const allSubDocs: Array<{
    userId: string;
    status: string;
    productId: string | null;
    updatedAt: string | null;
  }> = [];

  for (const doc of subscriptionsSnapshot.docs) {
    const data = doc.data();
    const status = typeof data.status === "string" ? data.status : "none";
    const productId = typeof data.productId === "string" ? data.productId : "";
    const updatedAt =
      typeof data.updatedAt === "string" ? data.updatedAt : null;

    allSubDocs.push({userId: doc.id, status, productId, updatedAt});

    if (status === "subscribed") {
      if (productId.includes("monthly")) {
        monthlyCount++;
      } else if (productId.includes("yearly")) {
        yearlyCount++;
      }
    } else if (status === "lifetime") {
      lifetimeCount++;
    } else if (status === "gracePeriod") {
      gracePeriodCount++;
    }
  }

  // Active overrides
  const activeOverrideCount = overridesSnapshot.docs.filter((doc) =>
    isEntitlementOverrideActive(doc.data())
  ).length;

  // Pro users from entitlements (SSOT)
  const proUsers = entitlementsSnapshot.docs.length;
  const totalUsers = usersSnapshot.docs.length;

  // Revenue estimates
  const monthlyRevenue = monthlyCount * prices.monthly;
  const yearlyRevenue = yearlyCount * prices.yearly;
  const lifetimeTotalRevenue = lifetimeCount * prices.lifetime;
  const estimatedMRR =
    monthlyRevenue + Math.round(yearlyRevenue / 12);

  // Coupon stats
  let couponTotal = 0;
  let couponAvailable = 0;
  let couponRedeemed = 0;
  let couponExpired = 0;
  const now = new Date();

  for (const doc of couponsSnapshot.docs) {
    const data = doc.data();
    couponTotal++;
    if (data.redeemedBy) {
      couponRedeemed++;
    } else if (
      data.expiresAt &&
      new Date(data.expiresAt as string) < now
    ) {
      couponExpired++;
    } else {
      couponAvailable++;
    }
  }

  // Recent activities (latest 20 by updatedAt)
  const recentActivities = allSubDocs
    .filter((d) => d.updatedAt != null)
    .sort((a, b) => {
      const aTime = new Date(a.updatedAt!).getTime();
      const bTime = new Date(b.updatedAt!).getTime();

      if (isNaN(aTime) && isNaN(bTime)) return 0;
      if (isNaN(aTime)) return 1;
      if (isNaN(bTime)) return -1;

      return bTime - aTime;
    })
    .slice(0, 20)
    .map((d) => ({
      userId: d.userId,
      type: d.status,
      productId: d.productId || null,
      timestamp: d.updatedAt!,
    }));

  return {
    overview: {
      totalUsers,
      proUsers,
      freeUsers: totalUsers - proUsers,
      proRate: totalUsers > 0 ?
        Math.round((proUsers / totalUsers) * 10000) / 100 :
        0,
    },
    breakdown: {
      monthly: {count: monthlyCount, revenue: monthlyRevenue},
      yearly: {count: yearlyCount, revenue: yearlyRevenue},
      lifetime: {count: lifetimeCount, totalRevenue: lifetimeTotalRevenue},
      override: {count: activeOverrideCount},
      gracePeriod: {count: gracePeriodCount},
    },
    revenue: {
      estimatedMRR,
      totalLifetimeRevenue: lifetimeTotalRevenue,
    },
    prices: {
      monthly: prices.monthly,
      yearly: prices.yearly,
      lifetime: prices.lifetime,
    },
    coupons: {
      total: couponTotal,
      available: couponAvailable,
      redeemed: couponRedeemed,
      expired: couponExpired,
    },
    recentActivities,
  };
}

export const getAdminProPlanDashboard = onCall<Record<string, never>>(
  {region: REGION},
  async (request): Promise<GetAdminProPlanDashboardResponse> => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "로그인이 필요합니다");
    }

    const adminUser = await getAdminUserDocument(request.auth.uid);
    requireAdminRole(adminUser, ["owner", "marketer"]);

    return {
      success: true,
      dashboard: await buildProPlanDashboard(),
    };
  }
);
