/**
 * Widget Snapshot Functions
 *
 * 위젯용 약속 스냅샷을 제공하는 Cloud Functions
 *
 * @architecture Snapshot 기반 (v2)
 * - 서버: Firestore Trigger로 스냅샷 미리 계산 → users/{uid}/cache/widgetSnapshot
 * - 클라이언트: 캐시된 스냅샷만 읽기 (계산 없음, Race Condition 없음)
 *
 * @auth Widget Token (30일 유효) 또는 Firebase ID Token
 */
import {onCall, onRequest, HttpsError} from "firebase-functions/v2/https";
import {admin, REGION} from "../config";
import {getEnvironmentCollection} from "../utils/firestore";
import {verifyWidgetToken, WIDGET_JWT_SECRET} from "./widgetToken";
import {WidgetSnapshotDocument} from "../types/api";

// MARK: - Default Empty Snapshot

const emptySnapshot: WidgetSnapshotDocument = {
  next: null,
  today: [],
  upcoming: [],
  meta: {
    todayCount: 0,
    upcomingCount: 0,
    updatedAt: new Date().toISOString(),
    version: 1,
  },
};

// MARK: - Main Functions

/**
 * 위젯용 약속 스냅샷 조회 (Firebase ID Token 인증)
 *
 * @description 캐시된 스냅샷 문서를 반환
 * @requires 인증 필수
 */
export const getWidgetSnapshot = onCall(
  {region: REGION},
  async (request): Promise<WidgetSnapshotDocument> => {
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "Authentication required"
      );
    }

    const userId = request.auth.uid;
    const requestedEnv = request.data?.env as string | undefined;
    const env = requestedEnv === "stage" ? "stage" : "prod";

    const snapshot = await fetchCachedSnapshot(userId, env);
    return snapshot;
  }
);

/**
 * 위젯용 약속 스냅샷 조회 (Widget Token 인증)
 *
 * @description Widget Extension에서 직접 호출하는 HTTP 엔드포인트
 * @auth Widget Token (30일 유효) - Authorization: Bearer <token>
 */
export const getWidgetSnapshotWithToken = onRequest(
  {
    region: REGION,
    secrets: [WIDGET_JWT_SECRET],
  },
  async (req, res) => {
    // CORS 헤더
    res.set("Access-Control-Allow-Origin", "*");
    res.set("Access-Control-Allow-Methods", "POST, OPTIONS");
    res.set("Access-Control-Allow-Headers", "Content-Type, Authorization");

    if (req.method === "OPTIONS") {
      res.status(204).send("");
      return;
    }

    if (req.method !== "POST") {
      res.status(405).json({error: "Method not allowed"});
      return;
    }

    // 1. Authorization 헤더 확인
    const authHeader = req.headers.authorization;
    if (!authHeader?.startsWith("Bearer ")) {
      res.status(401).json({error: "Missing or invalid Authorization header"});
      return;
    }

    const token = authHeader.split("Bearer ")[1];

    try {
      // 2. Widget Token 검증
      const secret = WIDGET_JWT_SECRET.value();
      const decoded = verifyWidgetToken(token, secret);

      // 3. 토큰 버전 확인 (revocation 체크)
      const db = admin.firestore();
      const requestBody = req.body?.data || {};
      const requestedEnv = requestBody.env as string | undefined;
      const env = requestedEnv === "stage" ? "stage" : "prod";

      const usersCollection = getEnvironmentCollection("users", db, env);
      const userDoc = await usersCollection.doc(decoded.sub).get();

      if (userDoc.exists) {
        const userData = userDoc.data();
        const currentVersion = (userData?.widgetTokenVersion as number) || 1;
        if (decoded.version < currentVersion) {
          res.status(401).json({error: "Token revoked"});
          return;
        }
      }

      // 4. 캐시된 스냅샷 조회
      const snapshot = await fetchCachedSnapshot(decoded.sub, env);

      // 5. 응답
      res.status(200).json({result: snapshot});
    } catch (error) {
      if (error instanceof HttpsError) {
        const statusCode = error.code === "unauthenticated" ? 401 :
          error.code === "permission-denied" ? 403 : 500;
        res.status(statusCode).json({error: error.message});
        return;
      }

      console.error("❌ getWidgetSnapshotWithToken error:", error);
      res.status(500).json({error: "Internal server error"});
    }
  }
);

// MARK: - Helper Functions

/**
 * 캐시된 스냅샷 조회
 *
 * @description users/{uid}/cache/widgetSnapshot 문서를 읽어서 반환
 * @fallback 문서가 없으면 빈 스냅샷 반환
 *
 * @param {string} userId 사용자 ID
 * @param {string} env 환경 (stage | prod)
 * @return {Promise<WidgetSnapshotDocument>} 위젯 스냅샷 문서
 */
async function fetchCachedSnapshot(
  userId: string,
  env: string
): Promise<WidgetSnapshotDocument> {
  const db = admin.firestore();
  const usersCollection = getEnvironmentCollection("users", db, env);

  const snapshotDoc = await usersCollection
    .doc(userId)
    .collection("cache")
    .doc("widgetSnapshot")
    .get();

  if (!snapshotDoc.exists) {
    console.log(`📦 [Widget] No cache for user: ${userId}, returning empty`);
    return {
      ...emptySnapshot,
      meta: {
        ...emptySnapshot.meta,
        updatedAt: new Date().toISOString(),
      },
    };
  }

  const data = snapshotDoc.data() as WidgetSnapshotDocument;
  console.log(
    `📦 [Widget] Cache hit: ${userId} ` +
    `(next=${data.next?.id ?? "null"}, ` +
    `today=${data.today.length}, upcoming=${data.upcoming.length})`
  );

  return data;
}
