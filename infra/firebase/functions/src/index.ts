import * as admin from "firebase-admin";
import {setGlobalOptions} from "firebase-functions/v2";
import {HttpsError, onCall, onRequest} from "firebase-functions/v2/https";

// Firebase Admin 초기화
admin.initializeApp();

// 공통 옵션(비용/스케일 제어)
setGlobalOptions({maxInstances: 10});

const REGION = "asia-northeast3";

// ✅ 테스트용 간단한 HTTP 함수
export const helloWorld = onRequest(
  {region: REGION},
  (request, response) => {
    response.json({
      message: "Hello from Firebase!",
      timestamp: new Date().toISOString(),
    });
  },
);

// ✅ 테스트용 Callable 함수
export const testCallable = onCall(
  {region: REGION},
  (request) => {
    const name = (request.data as {name?: string} | undefined)?.name ?? "Guest";
    return {
      message: `Hello ${name}!`,
      authenticated: request.auth != null,
      uid: request.auth?.uid ?? null,
    };
  },
);

// ✅ 그룹 생성 (iOS CreateGroup과 payload 맞춤)
export const createGroup = onCall(
  {region: REGION},
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "로그인이 필요합니다");
    }

    const data = (request.data ?? {}) as Record<string, unknown>;

    // iOS(CreateGroupRequest) 기준: name, maxMembers (emoji는 전달되지 않음)
    const nameRaw = data["name"] ?? data["groupName"];
    const maxMembersRaw = data["maxMembers"];
    const photoPathRaw = data["photoPath"];

    if (typeof nameRaw !== "string") {
      throw new HttpsError(
        "invalid-argument",
        "그룹 이름(name)은 필수입니다",
      );
    }

    const name = nameRaw.trim();
    if (name.length < 2) {
      throw new HttpsError(
        "invalid-argument",
        "그룹 이름은 최소 2글자 이상이어야 합니다",
      );
    }

    if (typeof maxMembersRaw !== "number" || !Number.isInteger(maxMembersRaw)) {
      throw new HttpsError(
        "invalid-argument",
        "최대 인원(maxMembers)은 정수여야 합니다",
      );
    }

    const maxMembers = maxMembersRaw;
    if (maxMembers < 2 || maxMembers > 10) {
      throw new HttpsError(
        "invalid-argument",
        "최대 인원(maxMembers)은 2~10 사이여야 합니다",
      );
    }

    let photoPath: string | null = null;
    if (typeof photoPathRaw === "string" && photoPathRaw.trim().length > 0) {
      photoPath = photoPathRaw.trim();
    }

    const creatorId = request.auth.uid;
    const db = admin.firestore();

    const inviteCode = await generateUniqueInviteCode({
      db,
      length: 6,
      maxAttempts: 5,
    });

    const groupRef = db.collection("groups").doc();
    const now = admin.firestore.FieldValue.serverTimestamp();

    await groupRef.set({
      name,
      description: null,
      emoji: null,
      themeColor: null,
      photoPath,
      memberCount: 1,
      activePromiseCount: 0,
      maxMembers,
      requireApproval: false,
      defaultMinimumParticipants: 2,
      inviteCode,
      createdBy: creatorId,
      createdAt: now,
      updatedAt: now,
      isDeleted: false,
    });

    return {id: groupRef.id, inviteCode};
  },
);

/**
 * Generates a unique invite code that does not collide with existing groups.
 * @param {Object} params Params.
 * @param {FirebaseFirestore.Firestore} params.db Firestore instance.
 * @param {number} params.length Invite code length.
 * @param {number} params.maxAttempts Maximum retry attempts.
 * @return {Promise<string>} A unique invite code.
 */
async function generateUniqueInviteCode(params: {
  db: FirebaseFirestore.Firestore;
  length: number;
  maxAttempts: number;
}): Promise<string> {
  const {db, length, maxAttempts} = params;
  const groups = db.collection("groups");

  for (let attempt = 0; attempt < maxAttempts; attempt++) {
    const code = randomInviteCode(length);
    const snapshot = await groups
      .where("inviteCode", "==", code)
      .limit(1)
      .get();
    if (snapshot.empty) return code;
  }

  throw new HttpsError(
    "internal",
    "초대 코드를 생성하지 못했어요. 잠시 후 다시 시도해주세요.",
  );
}

/**
 * Generates a random invite code.
 * @param {number} length Invite code length.
 * @return {string} Random invite code.
 */
function randomInviteCode(length: number): string {
  const characters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
  let code = "";
  for (let i = 0; i < length; i++) {
    code += characters.charAt(Math.floor(Math.random() * characters.length));
  }
  return code;
}
