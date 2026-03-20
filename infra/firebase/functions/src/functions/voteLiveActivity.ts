/**
 * VoteLiveActivity Functions
 *
 * iOS LiveActivity (Dynamic Island, Lock Screen) for Vote/Schedule confirmation
 *
 * @why Real-time vote response sharing for schedule confirmation
 * @ios VoteActivityAttributes, LiveActivityManager
 *
 * @architecture iOS 18 Broadcast Push
 * 1. startVoteLiveActivity → channelId creation + Push to Start to all members
 * 2. iOS starts Activity and subscribes to channel automatically
 * 3. updateVoteResponse → Broadcast updated ContentState to all subscribers
 * 4. finalizeVote → Broadcast final state with isFinalized: true
 */
import {HttpsError, onCall, onRequest} from "firebase-functions/v2/https";
import {
  admin,
  REGION,
  APNS_KEY_ID,
  APNS_TEAM_ID,
  APNS_AUTH_KEY,
  APNS_BUNDLE_ID,
} from "../config";
import {getCurrentEnvironment} from "../utils/firestore";
import {
  sendAPNsPush,
  sendAPNsBroadcast,
  createAPNsChannel,
} from "../utils/apns";

// ============================================================================
// Types
// ============================================================================

interface DeviceInfo {
  pushToStartToken?: string;
  [key: string]: unknown;
}

interface VoteContentState {
  acceptedMembers: string[];
  declinedMembers: string[];
  pendingCount: number;
  isFinalized: boolean;
}

// ============================================================================
// Helpers
// ============================================================================

/**
 * Determine APNs environment
 *
 * @return {boolean} true = Production, false = Sandbox
 */
function isAPNsProduction(): boolean {
  const env = getCurrentEnvironment();
  return env !== "dev";
}

// ============================================================================
// Functions
// ============================================================================

/**
 * Start Vote LiveActivity (Push to Start)
 *
 * Called by the host when requesting attendance confirmation.
 * Sends Push to Start APNs to all group members to remotely start LiveActivity.
 */
export const startVoteLiveActivity = onCall(
  {
    region: REGION,
    secrets: [APNS_KEY_ID, APNS_TEAM_ID, APNS_AUTH_KEY],
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "로그인이 필요합니다");
    }

    const userId = request.auth.uid;
    const {scheduleId} = request.data as {scheduleId: string};

    console.log(`📥 startVoteLiveActivity called: scheduleId="${scheduleId}"`);

    if (!scheduleId) {
      throw new HttpsError("invalid-argument", "scheduleId는 필수입니다");
    }

    const db = admin.firestore();
    const promisesCollection = db.collection("promises");
    const usersCollection = db.collection("users");
    const groupsCollection = db.collection("groups");

    // 1. Fetch schedule data
    const scheduleDoc = await promisesCollection.doc(scheduleId).get();
    if (!scheduleDoc.exists) {
      throw new HttpsError("not-found", "일정을 찾을 수 없습니다");
    }

    const scheduleData = scheduleDoc.data();
    if (!scheduleData) {
      throw new HttpsError("internal", "일정 데이터를 읽을 수 없습니다");
    }

    const groupId = scheduleData.groupId as string;
    const hostId = scheduleData.hostId as string;
    const title = scheduleData.title as string;
    const emoji = (scheduleData.emoji as string) || "📅";
    const location = (scheduleData.location?.name as string) || null;
    const startAt = scheduleData.startAt as FirebaseFirestore.Timestamp;

    // 2. Permission check (host only)
    if (userId !== hostId) {
      throw new HttpsError(
        "permission-denied",
        "호스트만 투표 LiveActivity를 시작할 수 있습니다",
      );
    }

    // 3. Fetch group data
    const groupDoc = await groupsCollection.doc(groupId).get();
    const groupData = groupDoc.data();
    const memberIds = (groupData?.memberIds as string[]) || [];
    const groupName = (groupData?.name as string) || null;
    const totalMemberCount = memberIds.length;

    // 4. Batch fetch user info and tokens
    const batchSize = 10;
    const allTokens: {userId: string; token: string}[] = [];
    let hostName: string | null = null;

    for (let i = 0; i < memberIds.length; i += batchSize) {
      const batch = memberIds.slice(i, i + batchSize);
      const userRefs = batch.map((uid) => usersCollection.doc(uid));
      const userDocs = await db.getAll(...userRefs);

      for (const userDoc of userDocs) {
        if (!userDoc.exists) continue;
        const uid = userDoc.id;
        const userData = userDoc.data();
        if (!userData) continue;

        const nickname = (userData.nickname as string) || "참가자";
        if (uid === hostId) {
          hostName = nickname;
        }

        type DevicesMap = {[key: string]: DeviceInfo} | null;
        const devices = userData.devices as DevicesMap;
        if (devices) {
          for (const deviceId of Object.keys(devices)) {
            const device = devices[deviceId];
            if (device.pushToStartToken) {
              allTokens.push({
                userId: uid,
                token: device.pushToStartToken,
              });
            }
          }
        }
      }
    }

    if (allTokens.length === 0) {
      console.log("📭 No Push to Start tokens found for vote activity");
      return {success: true, successCount: 0, failureCount: totalMemberCount};
    }

    console.log(`📊 Vote tokens: ${allTokens.length}`);

    // 5. Create APNs Broadcast channel
    const isProduction = isAPNsProduction();
    const channelResult = await createAPNsChannel(isProduction);

    if (!channelResult.success || !channelResult.channelId) {
      console.error("❌ Failed to create APNs channel for vote activity");
      throw new HttpsError("internal", "APNs 채널 생성에 실패했습니다");
    }

    const channelId = channelResult.channelId;
    console.log(`📡 Vote APNs channel created: ${channelId}`);

    // 6. Save channelId to Firestore
    await promisesCollection.doc(scheduleId).update({
      "liveActivity.voteChannelId": channelId,
      "liveActivity.voteStartedAt":
        admin.firestore.FieldValue.serverTimestamp(),
    });

    // 7. Send Push to Start to all members
    const initialContentState: VoteContentState = {
      acceptedMembers: [],
      declinedMembers: [],
      pendingCount: totalMemberCount,
      isFinalized: false,
    };

    let successCount = 0;
    let failureCount = 0;

    for (const {userId: tokenUserId, token} of allTokens) {
      const payload = {
        aps: {
          "timestamp": Math.floor(Date.now() / 1000),
          "event": "start",
          "attributes-type": "VoteActivityAttributes",
          "attributes": {
            scheduleId,
            currentUserId: tokenUserId,
            emoji,
            title,
            location,
            scheduledTime: startAt.toDate().getTime() / 1000,
            hostId,
            hostName,
            channelId,
            groupName,
            totalMemberCount,
          },
          "content-state": initialContentState,
          "alert": {
            "title": `${emoji} ${title}`,
            "body": "참여 여부를 확인해주세요",
          },
        },
      };

      const result = await sendAPNsPush({
        deviceToken: token,
        payload,
        pushType: "liveactivity",
        topic: `${APNS_BUNDLE_ID}.push-type.liveactivity`,
        priority: 10,
        isProduction,
      });

      if (result.success) {
        successCount++;
        console.log(`✅ Vote APNs Push to Start success for ${tokenUserId}`);
      } else {
        failureCount++;
        console.log(
          `❌ Vote APNs Push to Start failed for ${tokenUserId}: ${result.error}`
        );
      }
    }

    console.log(
      "📤 Vote LiveActivity started: " +
        `${successCount} success, ${failureCount} failed`
    );
    return {success: true, successCount, failureCount, channelId};
  },
);

/**
 * Update vote response (in-app)
 *
 * Called when a user responds to the vote from inside the app.
 * Saves the vote result to Firestore and broadcasts updated ContentState.
 */
export const updateVoteResponse = onCall(
  {
    region: REGION,
    secrets: [APNS_KEY_ID, APNS_TEAM_ID, APNS_AUTH_KEY],
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "로그인이 필요합니다");
    }

    const {scheduleId, userId, response, userName} = request.data as {
      scheduleId: string;
      userId: string;
      response: "accepted" | "declined";
      userName: string;
    };

    if (!scheduleId || !userId || !response || !userName) {
      throw new HttpsError(
        "invalid-argument",
        "scheduleId, userId, response, userName은 필수입니다",
      );
    }

    if (response !== "accepted" && response !== "declined") {
      throw new HttpsError(
        "invalid-argument",
        "response는 'accepted' 또는 'declined'이어야 합니다",
      );
    }

    const callerUid = request.auth.uid;
    if (callerUid !== userId) {
      throw new HttpsError(
        "permission-denied",
        "본인의 투표만 응답할 수 있습니다",
      );
    }

    console.log(
      `📥 updateVoteResponse: scheduleId=${scheduleId}, ` +
        `userId=${userId}, response=${response}`
    );

    const db = admin.firestore();
    const scheduleRef = db.collection("promises").doc(scheduleId);

    // 1. Save vote to Firestore subcollection
    await scheduleRef
      .collection("votes")
      .doc(userId)
      .set({
        response,
        userName,
        respondedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

    // 2. Read all votes to build ContentState
    const votesSnapshot = await scheduleRef.collection("votes").get();
    const acceptedMembers: string[] = [];
    const declinedMembers: string[] = [];

    votesSnapshot.forEach((doc) => {
      const voteData = doc.data();
      if (voteData.response === "accepted") {
        acceptedMembers.push(doc.id);
      } else if (voteData.response === "declined") {
        declinedMembers.push(doc.id);
      }
    });

    // 3. Determine if all members have responded
    const scheduleDoc = await scheduleRef.get();
    const scheduleData = scheduleDoc.data();
    const groupId = scheduleData?.groupId as string;

    const groupDoc = await db.collection("groups").doc(groupId).get();
    const groupData = groupDoc.data();
    const memberIds = (groupData?.memberIds as string[]) || [];
    const totalMemberCount = memberIds.length;
    const respondedCount = acceptedMembers.length + declinedMembers.length;
    const isFinalized = respondedCount >= totalMemberCount;
    const pendingCount = Math.max(0, totalMemberCount - respondedCount);

    const contentState: VoteContentState = {
      acceptedMembers,
      declinedMembers,
      pendingCount,
      isFinalized,
    };

    // 4. Broadcast via APNs
    const channelId = scheduleData?.["liveActivity"]?.voteChannelId as
      | string
      | undefined;

    if (!channelId) {
      console.warn(
        `⚠️ No voteChannelId for scheduleId=${scheduleId}, skipping broadcast`
      );
      return {success: true, contentState};
    }

    const isProduction = isAPNsProduction();
    const payload = {
      aps: {
        "timestamp": Math.floor(Date.now() / 1000),
        "event": isFinalized ? "end" : "update",
        "content-state": contentState,
        ...(isFinalized && {
          "alert": {
            "title": "투표가 마감되었습니다",
            "body": `참여 ${acceptedMembers.length}명` +
            ` / 불참 ${declinedMembers.length}명`,
          },
        }),
      },
    };

    const result = await sendAPNsBroadcast({
      channelId,
      payload,
      isProduction,
    });

    if (result.success) {
      console.log(
        `✅ Vote broadcast sent: channelId=${channelId}, ` +
          `isFinalized=${isFinalized}`
      );
    } else {
      console.error(`❌ Vote broadcast failed: ${result.error}`);
    }

    return {success: result.success, contentState};
  },
);

/**
 * Widget vote response (onRequest)
 *
 * HTTP endpoint for Widget Extension which cannot use Firebase SDK.
 * Same logic as updateVoteResponse.
 *
 * Headers:
 * - X-User-Id: user ID (required)
 * - X-Auth-Token: Firebase ID Token (optional)
 *
 * Request Body:
 * ```json
 * {
 *   "scheduleId": "schedule_abc123",
 *   "userId": "user_abc123",
 *   "response": "accepted" | "declined",
 *   "userName": "홍길동"
 * }
 * ```
 */
export const widgetVoteResponse = onRequest(
  {region: REGION, secrets: [APNS_KEY_ID, APNS_TEAM_ID, APNS_AUTH_KEY]},
  async (req, res) => {
    // CORS headers
    res.set("Access-Control-Allow-Origin", "*");
    res.set("Access-Control-Allow-Methods", "POST, OPTIONS");
    res.set(
      "Access-Control-Allow-Headers",
      "Content-Type, X-User-Id, X-Auth-Token",
    );

    if (req.method === "OPTIONS") {
      res.status(204).send("");
      return;
    }

    if (req.method !== "POST") {
      res.status(405).json({
        error: {code: "method-not-allowed", message: "Method not allowed"},
      });
      return;
    }

    const userId = req.headers["x-user-id"] as string;
    const authToken = req.headers["x-auth-token"] as string;

    if (!userId) {
      res.status(401).json({
        error: {
          code: "unauthenticated",
          message: "X-User-Id header is required",
        },
      });
      return;
    }

    // Optional auth token verification
    if (authToken) {
      try {
        const decodedToken = await admin.auth().verifyIdToken(authToken);
        if (decodedToken.uid !== userId) {
          res.status(401).json({
            error: {code: "unauthenticated", message: "Token uid mismatch"},
          });
          return;
        }
      } catch (error) {
        console.warn(`⚠️ Widget vote auth token verification failed: ${error}`);
        // Allow widget requests even if token verification fails
      }
    }

    const {scheduleId, response, userName} = req.body as {
      scheduleId: string;
      response: "accepted" | "declined";
      userName: string;
    };

    if (!scheduleId || !response || !userName) {
      res.status(400).json({
        error: {
          code: "invalid-argument",
          message: "scheduleId, response, and userName are required",
        },
      });
      return;
    }

    if (response !== "accepted" && response !== "declined") {
      res.status(400).json({
        error: {
          code: "invalid-argument",
          message: "response must be 'accepted' or 'declined'",
        },
      });
      return;
    }

    console.log(
      `📥 widgetVoteResponse: scheduleId=${scheduleId}, ` +
        `userId=${userId}, response=${response}`
    );

    const db = admin.firestore();
    const scheduleRef = db.collection("promises").doc(scheduleId);

    // Authorization: verify user is a group member
    try {
      const scheduleDocForAuth = await scheduleRef.get();
      if (!scheduleDocForAuth.exists) {
        res
          .status(404)
          .json({error: {code: "not-found", message: "Schedule not found"}});
        return;
      }

      const scheduleDataForAuth = scheduleDocForAuth.data();
      if (!scheduleDataForAuth) {
        res.status(500).json({
          error: {code: "internal", message: "Failed to read schedule data"},
        });
        return;
      }

      const groupDocForAuth = await db
        .collection("groups")
        .doc(scheduleDataForAuth.groupId)
        .get();

      if (!groupDocForAuth.exists) {
        res
          .status(404)
          .json({error: {code: "not-found", message: "Group not found"}});
        return;
      }

      const groupDataForAuth = groupDocForAuth.data();
      if (!groupDataForAuth?.memberIds) {
        res.status(500).json({
          error: {code: "internal", message: "Failed to read group data"},
        });
        return;
      }

      if (!(groupDataForAuth.memberIds as string[]).includes(userId)) {
        res.status(403).json({
          error: {
            code: "permission-denied",
            message: "User is not a member of this group",
          },
        });
        return;
      }
    } catch (error) {
      console.error("❌ Widget vote authorization check failed:", error);
      res.status(500).json({
        error: {code: "internal", message: "Authorization check failed"},
      });
      return;
    }

    // Save vote result
    await scheduleRef.collection("votes").doc(userId).set({
      response,
      userName,
      respondedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Read all votes to build ContentState
    const votesSnapshot = await scheduleRef.collection("votes").get();
    const acceptedMembers: string[] = [];
    const declinedMembers: string[] = [];

    votesSnapshot.forEach((doc) => {
      const voteData = doc.data();
      if (voteData.response === "accepted") {
        acceptedMembers.push(doc.id);
      } else if (voteData.response === "declined") {
        declinedMembers.push(doc.id);
      }
    });

    const scheduleDoc = await scheduleRef.get();
    const scheduleData = scheduleDoc.data();
    const groupId = scheduleData?.groupId as string;

    const groupDoc = await db.collection("groups").doc(groupId).get();
    const groupData = groupDoc.data();
    const memberIds = (groupData?.memberIds as string[]) || [];
    const totalMemberCount = memberIds.length;
    const respondedCount = acceptedMembers.length + declinedMembers.length;
    const isFinalized = respondedCount >= totalMemberCount;
    const pendingCount = Math.max(0, totalMemberCount - respondedCount);

    const contentState: VoteContentState = {
      acceptedMembers,
      declinedMembers,
      pendingCount,
      isFinalized,
    };

    // Broadcast via APNs
    const channelId = scheduleData?.["liveActivity"]?.voteChannelId as
      | string
      | undefined;

    if (!channelId) {
      console.warn(
        `⚠️ No voteChannelId for scheduleId=${scheduleId}, skipping broadcast`
      );
      res.status(200).json({success: true, contentState});
      return;
    }

    const isProduction = isAPNsProduction();
    const payload = {
      aps: {
        "timestamp": Math.floor(Date.now() / 1000),
        "event": isFinalized ? "end" : "update",
        "content-state": contentState,
        ...(isFinalized && {
          "alert": {
            "title": "투표가 마감되었습니다",
            "body": `참여 ${acceptedMembers.length}명` +
              ` / 불참 ${declinedMembers.length}명`,
          },
        }),
      },
    };

    const broadcastResult = await sendAPNsBroadcast({
      channelId,
      payload,
      isProduction,
    });

    if (broadcastResult.success) {
      console.log(
        `✅ Widget vote broadcast sent: channelId=${channelId}, ` +
          `isFinalized=${isFinalized}`
      );
      res.status(200).json({success: true, contentState});
    } else {
      console.error(`❌ Widget vote broadcast failed: ${broadcastResult.error}`);
      res.status(500).json({
        error: {
          code: "internal",
          message: "Failed to send broadcast",
        },
      });
    }
  },
);

/**
 * Finalize vote (host closes the vote)
 *
 * Called by the host to close voting.
 * Broadcasts isFinalized: true to all subscribers and saves finalized data
 * to Firestore.
 */
export const finalizeVote = onCall(
  {
    region: REGION,
    secrets: [APNS_KEY_ID, APNS_TEAM_ID, APNS_AUTH_KEY],
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "로그인이 필요합니다");
    }

    const userId = request.auth.uid;
    const {scheduleId} = request.data as {scheduleId: string};

    if (!scheduleId) {
      throw new HttpsError("invalid-argument", "scheduleId는 필수입니다");
    }

    console.log(`📥 finalizeVote called: scheduleId=${scheduleId}`);

    const db = admin.firestore();
    const scheduleRef = db.collection("promises").doc(scheduleId);

    // 1. Fetch schedule data
    const scheduleDoc = await scheduleRef.get();
    if (!scheduleDoc.exists) {
      throw new HttpsError("not-found", "일정을 찾을 수 없습니다");
    }

    const scheduleData = scheduleDoc.data();
    if (!scheduleData) {
      throw new HttpsError("internal", "일정 데이터를 읽을 수 없습니다");
    }

    const hostId = scheduleData.hostId as string;

    // 2. Permission check (host only)
    if (userId !== hostId) {
      throw new HttpsError(
        "permission-denied",
        "호스트만 투표를 마감할 수 있습니다",
      );
    }

    // 3. Read all votes
    const votesSnapshot = await scheduleRef.collection("votes").get();
    const acceptedMembers: string[] = [];
    const declinedMembers: string[] = [];

    votesSnapshot.forEach((doc) => {
      const voteData = doc.data();
      if (voteData.response === "accepted") {
        acceptedMembers.push(doc.id);
      } else if (voteData.response === "declined") {
        declinedMembers.push(doc.id);
      }
    });

    const groupId = scheduleData.groupId as string;
    const groupDoc = await db.collection("groups").doc(groupId).get();
    const groupData = groupDoc.data();
    const memberIds = (groupData?.memberIds as string[]) || [];
    const totalMemberCount = memberIds.length;
    const respondedCount = acceptedMembers.length + declinedMembers.length;
    const pendingCount = Math.max(0, totalMemberCount - respondedCount);

    const contentState: VoteContentState = {
      acceptedMembers,
      declinedMembers,
      pendingCount,
      isFinalized: true,
    };

    // 4. Save finalized state to Firestore
    await scheduleRef.update({
      "liveActivity.voteFinalized": true,
      "liveActivity.voteFinalizedAt":
        admin.firestore.FieldValue.serverTimestamp(),
      "liveActivity.acceptedMembers": acceptedMembers,
      "liveActivity.declinedMembers": declinedMembers,
    });

    console.log(
      `✅ Vote finalized: accepted=${acceptedMembers.length}, ` +
        `declined=${declinedMembers.length}`
    );

    // 5. Broadcast final state via APNs
    const channelId = scheduleData["liveActivity"]?.voteChannelId as
      | string
      | undefined;

    if (!channelId) {
      console.warn(
        `⚠️ No voteChannelId for scheduleId=${scheduleId}, skipping broadcast`
      );
      return {success: true, contentState};
    }

    const isProduction = isAPNsProduction();
    const payload = {
      aps: {
        "timestamp": Math.floor(Date.now() / 1000),
        "event": "end",
        "content-state": contentState,
        "alert": {
          "title": "호스트가 투표를 마감했습니다",
          "body": `참여 ${acceptedMembers.length}명` +
            ` / 불참 ${declinedMembers.length}명`,
        },
      },
    };

    const result = await sendAPNsBroadcast({
      channelId,
      payload,
      isProduction,
    });

    if (result.success) {
      console.log(
        `✅ Finalize vote broadcast sent: channelId=${channelId}`
      );
    } else {
      console.error(`❌ Finalize vote broadcast failed: ${result.error}`);
    }

    return {success: result.success, contentState};
  },
);
