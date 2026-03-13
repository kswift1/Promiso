import {FieldValue} from "firebase-admin/firestore";
import {HttpsError, onCall} from "firebase-functions/v2/https";
import {admin, REGION} from "../config";
import {
  AdminRole,
  AdminUserDocument,
  AdminUserSummary,
  GrantEntitlementOverrideRequest,
  GrantEntitlementOverrideResponse,
  GetAdminSessionResponse,
  GetAdminUserSummaryRequest,
  GetAdminUserSummaryResponse,
  RevokeEntitlementOverrideRequest,
  RevokeEntitlementOverrideResponse,
} from "../types/admin";

function isAdminRole(value: unknown): value is AdminRole {
  return value === "owner" || value === "support" || value === "marketer";
}

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

async function buildUserSummary(
  userId: string,
  userData: Record<string, unknown>
): Promise<AdminUserSummary> {
  const db = admin.firestore();
  const subscriptionSnapshot = await db.collection("subscriptions").doc(userId).get();
  const overrideSnapshot = await db.collection("entitlementOverrides").doc(userId).get();

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
    subscriptionStatus: typeof subscriptionSnapshot.data()?.status === "string" ?
      subscriptionSnapshot.data()!.status :
      null,
    overrideActive: overrideSnapshot.exists &&
      overrideSnapshot.data()?.isActive === true,
  };
}

async function writeAuditLog(params: {
  actorId: string;
  action: string;
  targetId: string;
  before?: Record<string, unknown> | null;
  after?: Record<string, unknown> | null;
}) {
  const {actorId, action, targetId, before, after} = params;
  await admin.firestore().collection("adminAuditLogs").add({
    actorId,
    action,
    targetType: "user",
    targetId,
    before: before ?? null,
    after: after ?? null,
    createdAt: FieldValue.serverTimestamp(),
  });
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

    await getAdminUserDocument(request.auth.uid);

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

export const grantEntitlementOverride = onCall<GrantEntitlementOverrideRequest>(
  {region: REGION},
  async (request): Promise<GrantEntitlementOverrideResponse> => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "로그인이 필요합니다");
    }

    const actorId = request.auth.uid;
    await getAdminUserDocument(actorId);

    const userId = request.data.userId?.trim();
    const reason = request.data.reason?.trim();

    if (!userId) {
      throw new HttpsError("invalid-argument", "userId는 필수입니다");
    }

    if (!reason) {
      throw new HttpsError("invalid-argument", "reason은 필수입니다");
    }

    const userSnapshot = await admin.firestore().collection("users").doc(userId).get();
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

    const overrideRef = admin.firestore().collection("entitlementOverrides").doc(userId);
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

export const revokeEntitlementOverride = onCall<RevokeEntitlementOverrideRequest>(
  {region: REGION},
  async (request): Promise<RevokeEntitlementOverrideResponse> => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "로그인이 필요합니다");
    }

    const actorId = request.auth.uid;
    await getAdminUserDocument(actorId);

    const userId = request.data.userId?.trim();
    const reason = request.data.reason?.trim() ?? null;

    if (!userId) {
      throw new HttpsError("invalid-argument", "userId는 필수입니다");
    }

    const overrideRef = admin.firestore().collection("entitlementOverrides").doc(userId);
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
