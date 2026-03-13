import {FieldValue} from "firebase-admin/firestore";
import type {
  RemoteConfigParameterValue,
  RemoteConfigTemplate,
} from "firebase-admin/remote-config";
import {HttpsError, onCall} from "firebase-functions/v2/https";
import {admin, REGION} from "../config";
import {
  AdminAuditLog,
  AdminDashboardSummary,
  AdminReleaseControls,
  AdminPushAudience,
  AdminRole,
  AdminUserDocument,
  AdminUserSummary,
  GrantEntitlementOverrideRequest,
  GrantEntitlementOverrideResponse,
  GetAdminAuditLogsRequest,
  GetAdminAuditLogsResponse,
  GetAdminDashboardSummaryResponse,
  GetAdminSessionResponse,
  GetAdminReleaseControlsResponse,
  GetAdminUserSummaryRequest,
  GetAdminUserSummaryResponse,
  RevokeEntitlementOverrideRequest,
  RevokeEntitlementOverrideResponse,
  SendAdminPushRequest,
  SendAdminPushResponse,
  UpdateAdminReleaseControlsRequest,
  UpdateAdminReleaseControlsResponse,
} from "../types/admin";
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

type ReleaseControlKey = typeof RELEASE_CONTROL_KEYS[number];

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
 * Loads and validates the admin permission document for the user.
 * @param {string} userId The authenticated user id.
 * @return {Promise<AdminUserDocument>} The validated admin document.
 */
export async function getAdminUserDocument(
  userId: string
): Promise<AdminUserDocument> {
  const snapshot = await admin.firestore()
    .collection("adminUsers")
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
    db.collection("adminUsers").get(),
    db.collection("entitlementOverrides").get(),
    db.collection("adminPushJobs").get(),
    db.collection("adminAuditLogs").get(),
  ]);

  const userIds = usersSnapshot.docs.map((doc) => doc.id);
  const proStates = await Promise.all(
    userIds.map(async (userId) => isEffectivePro(userId))
  );
  const proUsers = proStates.filter(Boolean).length;
  const activeOverrides = overridesSnapshot.docs.filter((doc) =>
    doc.data()?.isActive === true
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
      typeof subscriptionSnapshot.data()?.status === "string" ?
        subscriptionSnapshot.data()?.status :
        null,
    overrideActive: overrideSnapshot.exists &&
      overrideSnapshot.data()?.isActive === true,
  };
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
  await admin.firestore().collection("adminAuditLogs").add({
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
 * Ensures a value is a valid email address.
 * @param {string} value The candidate email value.
 * @param {string} fieldName The field label for errors.
 * @return {string} The validated email address.
 */
function requireEmail(value: string, fieldName: string): string {
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value)) {
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
  const overrideActive = overrideSnapshot.exists &&
    overrideSnapshot.data()?.isActive === true;

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

export const getAdminUserSummary = onCall<GetAdminUserSummaryRequest>(
  {region: REGION},
  async (request): Promise<GetAdminUserSummaryResponse> => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "로그인이 필요합니다");
    }

    const query = request.data.query?.trim();
    if (!query) {
      throw new HttpsError("invalid-argument", "검색어가 필요합니다");
    }

    const adminUser = await getAdminUserDocument(request.auth.uid);
    requireAdminRole(adminUser, ["owner", "support"]);

    const db = admin.firestore();
    const usersCollection = db.collection("users");
    const matches = new Map<string, Record<string, unknown>>();

    const userIdSnapshot = await usersCollection.doc(query).get();
    if (userIdSnapshot.exists) {
      const data = userIdSnapshot.data();
      if (data) {
        matches.set(userIdSnapshot.id, data as Record<string, unknown>);
      }
    }

    const emailSnapshot = await usersCollection
      .where("email", "==", query)
      .limit(10)
      .get();
    emailSnapshot.docs.forEach((doc) => {
      const data = doc.data();
      if (data) {
        matches.set(doc.id, data as Record<string, unknown>);
      }
    });

    const nicknameSnapshot = await usersCollection
      .where("nickname", "==", query)
      .limit(10)
      .get();
    nicknameSnapshot.docs.forEach((doc) => {
      const data = doc.data();
      if (data) {
        matches.set(doc.id, data as Record<string, unknown>);
      }
    });

    const results = await Promise.all(
      [...matches.entries()].map(([userId, userData]) =>
        buildUserSummary(userId, userData)
      )
    );

    return {
      success: true,
      results,
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
        forceUpdateVersion: requireString(
          request.data.forceUpdateVersion,
          "forceUpdateVersion"
        ),
        recommendedVersion: requireString(
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

      RELEASE_CONTROL_KEYS.forEach((key) => {
        setRemoteConfigValue(template, key, nextValues[key]);
      });

      const publishedTemplate = await remoteConfig.publishTemplate(template);
      const after = buildReleaseControls(publishedTemplate);

      await writeAuditLog({
        actorId,
        action: "update_release_controls",
        targetType: "remote_config",
        targetId: "default",
        before,
        after,
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
    const snapshot = await admin.firestore()
      .collection("adminAuditLogs")
      .orderBy("createdAt", "desc")
      .limit(limit)
      .get();

    return {
      success: true,
      logs: snapshot.docs.map((doc) =>
        buildAdminAuditLog(doc.id, doc.data() as Record<string, unknown>)
      ),
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

    const userIds = await resolvePushAudience({
      audience,
      testUserId,
    });

    const db = admin.firestore();
    const jobRef = await db.collection("adminPushJobs").add({
      status: dryRun ? "dry_run" : "completed",
      audience,
      title,
      body,
      dryRun,
      targetCount: userIds.length,
      createdBy: actorId,
      testUserId,
      result: dryRun ? {
        successCount: 0,
        failureCount: 0,
      } : null,
      createdAt: FieldValue.serverTimestamp(),
    });

    if (dryRun) {
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

    await jobRef.set({
      status: "completed",
      result: {
        successCount: result.successCount,
        failureCount: result.failureCount,
      },
      completedAt: FieldValue.serverTimestamp(),
    }, {merge: true});

    await writeAuditLog({
      actorId,
      action: "send_admin_push",
      targetId: jobRef.id,
      after: {
        audience,
        targetCount: userIds.length,
        successCount: result.successCount,
        failureCount: result.failureCount,
      },
    });

    return {
      success: true,
      dryRun: false,
      targetCount: userIds.length,
      successCount: result.successCount,
      failureCount: result.failureCount,
      jobId: jobRef.id,
    };
  }
);
