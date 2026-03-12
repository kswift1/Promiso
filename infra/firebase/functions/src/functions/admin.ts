import {HttpsError, onCall} from "firebase-functions/v2/https";
import {admin, REGION} from "../config";
import {AdminRole, AdminUserDocument, GetAdminSessionResponse} from "../types/admin";

function isAdminRole(value: unknown): value is AdminRole {
  return value === "owner" || value === "support" || value === "marketer";
}

async function getAdminUserDocument(userId: string): Promise<AdminUserDocument> {
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

