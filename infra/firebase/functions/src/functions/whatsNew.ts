import {FieldValue} from "firebase-admin/firestore";
import {HttpsError, onCall} from "firebase-functions/v2/https";
import {admin, REGION} from "../config";
import type {
  AdminDeleteWhatsNewRequest,
  AdminDeleteWhatsNewResponse,
  AdminListWhatsNewResponse,
  AdminRole,
  AdminSaveWhatsNewRequest,
  AdminSaveWhatsNewResponse,
  AdminUploadWhatsNewImageRequest,
  AdminUploadWhatsNewImageResponse,
  AdminUserDocument,
  GetWhatsNewRequest,
  GetWhatsNewResponse,
  WhatsNewDocument,
  WhatsNewItem,
} from "../types/admin";

// ============================================================================
// Admin 인증 헬퍼
// ============================================================================

/**
 * Admin users 서브컬렉션 참조를 반환합니다.
 * @return {FirebaseFirestore.CollectionReference} Admin users 컬렉션 참조
 */
const adminUsersCol = () =>
  admin.firestore()
    .collection("admin").doc("config").collection("users");

/**
 * 값이 유효한 AdminRole인지 검사합니다.
 * @param {unknown} value 검사할 값
 * @return {boolean} AdminRole 여부
 */
function isAdminRole(value: unknown): value is AdminRole {
  return (
    value === "owner" || value === "support" || value === "marketer"
  );
}

/**
 * 사용자의 Admin 권한 문서를 로드하고 검증합니다.
 * @param {string} userId 인증된 사용자 ID
 * @return {Promise<AdminUserDocument>} 검증된 Admin 문서
 */
async function getAdminUserDocument(
  userId: string
): Promise<AdminUserDocument> {
  const snapshot = await adminUsersCol().doc(userId).get();
  if (!snapshot.exists) {
    throw new HttpsError("permission-denied", "관리자 권한이 없습니다");
  }
  const data = snapshot.data();
  if (!data || !isAdminRole(data.role)) {
    throw new HttpsError(
      "permission-denied", "유효하지 않은 관리자 권한입니다"
    );
  }
  if (data.enabled === false) {
    throw new HttpsError("permission-denied", "비활성화된 관리자 계정입니다");
  }
  return data as AdminUserDocument;
}

/**
 * Admin 역할이 허용된 역할 목록에 포함되는지 검사합니다.
 * @param {AdminUserDocument} adminUser 검증된 Admin 문서
 * @param {AdminRole[]} allowedRoles 허용 역할 목록
 * @return {void}
 */
function requireAdminRole(
  adminUser: AdminUserDocument,
  allowedRoles: AdminRole[]
): void {
  if (!allowedRoles.includes(adminUser.role)) {
    throw new HttpsError(
      "permission-denied", "이 작업을 수행할 권한이 없습니다"
    );
  }
}

// ============================================================================
// Audit Log 헬퍼
// ============================================================================

/**
 * 감사 로그를 기록합니다.
 * @param {object} params 로그 파라미터
 * @return {Promise<void>}
 */
async function writeAuditLog(params: {
  actorId: string;
  action: string;
  targetType: string;
  targetId: string;
  before?: unknown;
  after?: unknown;
}): Promise<void> {
  await admin.firestore()
    .collection("admin").doc("config").collection("auditLogs")
    .add({
      ...params,
      before: params.before ?? null,
      after: params.after ?? null,
      createdAt: FieldValue.serverTimestamp(),
    });
}

// ============================================================================
// 유틸리티
// ============================================================================

const VERSION_REGEX = /^\d+\.\d+\.\d+$/;
const ALLOWED_CONTENT_TYPES = ["image/png", "image/jpeg", "image/webp"];
const MAX_IMAGE_SIZE_BYTES = 5 * 1024 * 1024; // 5MB

/**
 * Firestore Timestamp를 ISO 문자열로 변환합니다.
 * @param {unknown} val Timestamp 또는 임의의 값
 * @return {string} ISO 형식 날짜 문자열
 */
function toISOString(val: unknown): string {
  if (val && typeof val === "object" && "toDate" in val) {
    return (val as {toDate: () => Date}).toDate().toISOString();
  }
  return new Date().toISOString();
}

/**
 * Firestore 문서 데이터를 WhatsNewDocument로 변환합니다.
 * @param {string} version 버전 문자열
 * @param {FirebaseFirestore.DocumentData} data Firestore 문서 데이터
 * @return {WhatsNewDocument} 변환된 WhatsNewDocument
 */
function toWhatsNewDocument(
  version: string,
  data: FirebaseFirestore.DocumentData
): WhatsNewDocument {
  return {
    version,
    enabled: data.enabled ?? false,
    items: (data.items ?? []) as WhatsNewItem[],
    createdBy: data.createdBy ?? "",
    createdAt: toISOString(data.createdAt),
    updatedBy: data.updatedBy ?? "",
    updatedAt: toISOString(data.updatedAt),
  };
}

// ============================================================================
// Functions
// ============================================================================

/**
 * 앱에서 특정 버전의 What's New 정보를 조회합니다.
 * enabled가 true인 경우만 반환합니다.
 */
export const getWhatsNew = onCall<GetWhatsNewRequest>(
  {region: REGION},
  async (request): Promise<GetWhatsNewResponse> => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "로그인이 필요합니다");
    }

    const version = request.data.version?.trim();
    if (!version || !VERSION_REGEX.test(version)) {
      throw new HttpsError(
        "invalid-argument",
        "version 형식이 올바르지 않습니다 (예: 1.3.1)"
      );
    }

    const snapshot = await admin.firestore()
      .collection("whatsNew").doc(version).get();

    if (!snapshot.exists) {
      return {success: true, whatsNew: null};
    }

    const data = snapshot.data();
    if (!data || data.enabled !== true) {
      return {success: true, whatsNew: null};
    }

    return {
      success: true,
      whatsNew: toWhatsNewDocument(version, data),
    };
  }
);

/**
 * 어드민: 모든 What's New 항목을 목록 조회합니다.
 */
export const adminListWhatsNew = onCall(
  {region: REGION},
  async (request): Promise<AdminListWhatsNewResponse> => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "로그인이 필요합니다");
    }

    const adminUser = await getAdminUserDocument(request.auth.uid);
    requireAdminRole(adminUser, ["owner", "marketer"]);

    const snapshot = await admin.firestore()
      .collection("whatsNew")
      .orderBy("createdAt", "desc")
      .get();

    const entries: WhatsNewDocument[] = snapshot.docs.map((doc) =>
      toWhatsNewDocument(doc.id, doc.data())
    );

    return {success: true, entries};
  }
);

/**
 * 어드민: What's New 항목을 생성하거나 수정합니다 (upsert).
 */
export const adminSaveWhatsNew = onCall<AdminSaveWhatsNewRequest>(
  {region: REGION},
  async (request): Promise<AdminSaveWhatsNewResponse> => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "로그인이 필요합니다");
    }

    const actorId = request.auth.uid;
    const adminUser = await getAdminUserDocument(actorId);
    requireAdminRole(adminUser, ["owner", "marketer"]);

    const version = request.data.version?.trim();
    if (!version || !VERSION_REGEX.test(version)) {
      throw new HttpsError(
        "invalid-argument",
        "version 형식이 올바르지 않습니다 (예: 1.3.1)"
      );
    }

    if (typeof request.data.enabled !== "boolean") {
      throw new HttpsError(
        "invalid-argument", "enabled는 boolean이어야 합니다"
      );
    }

    const items = request.data.items;
    if (!Array.isArray(items)) {
      throw new HttpsError("invalid-argument", "items는 배열이어야 합니다");
    }
    for (const item of items) {
      if (!item.title?.trim()) {
        throw new HttpsError(
          "invalid-argument", "각 항목에 title이 필요합니다"
        );
      }
      if (!item.description?.trim()) {
        throw new HttpsError(
          "invalid-argument", "각 항목에 description이 필요합니다"
        );
      }
      if (typeof item.imageURL !== "string") {
        throw new HttpsError(
          "invalid-argument", "각 항목에 imageURL이 필요합니다"
        );
      }
    }

    const docRef = admin.firestore().collection("whatsNew").doc(version);
    const existingSnapshot = await docRef.get();
    const isNew = !existingSnapshot.exists;

    const now = FieldValue.serverTimestamp();
    const writeData = isNew ?
      {
        version,
        enabled: request.data.enabled,
        items,
        createdBy: actorId,
        createdAt: now,
        updatedBy: actorId,
        updatedAt: now,
      } :
      {
        enabled: request.data.enabled,
        items,
        updatedBy: actorId,
        updatedAt: now,
      };

    await docRef.set(writeData, {merge: true});

    await writeAuditLog({
      actorId,
      action: "save_whats_new",
      targetType: "whatsNew",
      targetId: version,
      before: isNew ? null : existingSnapshot.data(),
      after: {version, enabled: request.data.enabled, items},
    });

    const savedSnapshot = await docRef.get();
    const savedData = savedSnapshot.data() ?? {};
    return {
      success: true,
      whatsNew: toWhatsNewDocument(version, savedData),
    };
  }
);

/**
 * 어드민: What's New 항목을 삭제합니다.
 * 관련 Storage 파일도 함께 삭제합니다.
 */
export const adminDeleteWhatsNew = onCall<AdminDeleteWhatsNewRequest>(
  {region: REGION},
  async (request): Promise<AdminDeleteWhatsNewResponse> => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "로그인이 필요합니다");
    }

    const actorId = request.auth.uid;
    const adminUser = await getAdminUserDocument(actorId);
    requireAdminRole(adminUser, ["owner", "marketer"]);

    const version = request.data.version?.trim();
    if (!version || !VERSION_REGEX.test(version)) {
      throw new HttpsError(
        "invalid-argument",
        "version 형식이 올바르지 않습니다 (예: 1.3.1)"
      );
    }

    const docRef = admin.firestore().collection("whatsNew").doc(version);
    const snapshot = await docRef.get();

    if (!snapshot.exists) {
      throw new HttpsError(
        "not-found", "해당 버전의 What's New가 존재하지 않습니다"
      );
    }

    const beforeData = snapshot.data();

    await docRef.delete();

    // 관련 Storage 파일 삭제
    try {
      const bucket = admin.storage().bucket();
      await bucket.deleteFiles({prefix: `whats-new/${version}/`});
    } catch (err) {
      console.error(
        "[adminDeleteWhatsNew] Storage 삭제 실패:", version, err
      );
    }

    await writeAuditLog({
      actorId,
      action: "delete_whats_new",
      targetType: "whatsNew",
      targetId: version,
      before: beforeData,
      after: null,
    });

    return {success: true};
  }
);

/**
 * 어드민: What's New 이미지를 Firebase Storage에 업로드합니다.
 */
export const adminUploadWhatsNewImage =
  onCall<AdminUploadWhatsNewImageRequest>(
    {region: REGION},
    async (request): Promise<AdminUploadWhatsNewImageResponse> => {
      if (!request.auth) {
        throw new HttpsError("unauthenticated", "로그인이 필요합니다");
      }

      const actorId = request.auth.uid;
      const adminUser = await getAdminUserDocument(actorId);
      requireAdminRole(adminUser, ["owner", "marketer"]);

      const version = request.data.version?.trim();
      if (!version || !VERSION_REGEX.test(version)) {
        throw new HttpsError(
          "invalid-argument",
          "version 형식이 올바르지 않습니다 (예: 1.3.1)"
        );
      }

      const fileName = request.data.fileName?.trim();
      if (!fileName || !/^[\w\-.]+$/.test(fileName)) {
        throw new HttpsError(
          "invalid-argument",
          "fileName은 영문자/숫자/하이픈/점/언더스코어만 허용됩니다"
        );
      }

      const contentType = request.data.contentType?.trim();
      if (!ALLOWED_CONTENT_TYPES.includes(contentType)) {
        throw new HttpsError(
          "invalid-argument",
          `허용되지 않는 파일 형식입니다. 허용: ${ALLOWED_CONTENT_TYPES.join(", ")}`
        );
      }

      const base64Data = request.data.base64Data;
      if (!base64Data) {
        throw new HttpsError("invalid-argument", "base64Data가 필요합니다");
      }

      const buffer = Buffer.from(base64Data, "base64");
      if (buffer.byteLength > MAX_IMAGE_SIZE_BYTES) {
        throw new HttpsError(
          "invalid-argument", "이미지 크기는 5MB를 초과할 수 없습니다"
        );
      }

      const storagePath = `whats-new/${version}/${fileName}`;
      const bucket = admin.storage().bucket();
      const file = bucket.file(storagePath);

      await file.save(buffer, {metadata: {contentType}});
      // 앱에서 imageURL로 직접 접근하므로 공개 URL이 필요함
      await file.makePublic();

      const imageURL =
        `https://storage.googleapis.com/${bucket.name}/${storagePath}`;

      return {success: true, imageURL};
    }
  );
