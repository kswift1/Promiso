import {HttpsError, onCall} from "firebase-functions/v2/https";
import {admin, REGION} from "../config";
import {
  AdminRole,
  AdminUserDocument,
  AdminUserSummary,
  GetAdminSessionResponse,
  GetAdminUserSummaryRequest,
  GetAdminUserSummaryResponse,
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
