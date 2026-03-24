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

interface VoteMember {
  id: string;
  name: string;
}

interface VoteContentState {
  acceptedMembers: VoteMember[];
  declinedMembers: VoteMember[];
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
// Internal Helpers
// ============================================================================

/**
 * End Vote LiveActivity (internal helper)
 *
 * Broadcasts APNs "end" event and removes voteChannelId from Firestore.
 * Called by endVoteLiveActivity onCall, deletePromise, and updatePromise.
 *
 * @param {string} scheduleId - The schedule document ID
 * @param {string} reason - Log label for the caller context
 */
export async function endVoteActivityInternal(
  scheduleId: string,
  reason = "internal",
): Promise<void> {
  const db = admin.firestore();
  const scheduleRef = db.collection("promises").doc(scheduleId);

  // 1. Fetch schedule data
  const scheduleDoc = await scheduleRef.get();
  if (!scheduleDoc.exists) {
    console.warn(
      `⚠️ endVoteActivityInternal(${reason}): ` +
        `scheduleId=${scheduleId} not found, skipping`
    );
    return;
  }

  const scheduleData = scheduleDoc.data();
  if (!scheduleData) return;

  // 2. Get channelId — nothing to do if absent
  const channelId = scheduleData.liveActivity?.voteChannelId as
    | string
    | undefined;

  if (!channelId) {
    console.log(
      `⚠️ endVoteActivityInternal(${reason}): ` +
        `no voteChannelId for scheduleId=${scheduleId}`
    );
    return;
  }

  // 3. Build current ContentState from votes
  const votesSnapshot = await scheduleRef.collection("votes").get();
  const acceptedMembers: VoteMember[] = [];
  const declinedMembers: VoteMember[] = [];

  votesSnapshot.forEach((doc) => {
    const voteData = doc.data();
    const member: VoteMember = {
      id: doc.id,
      name: (voteData.userName as string) || "멤버",
    };
    if (voteData.response === "accepted") {
      acceptedMembers.push(member);
    } else if (voteData.response === "declined") {
      declinedMembers.push(member);
    }
  });

  const groupId = scheduleData.groupId as string;
  const groupDoc = await db.collection("groups").doc(groupId).get();
  const groupData = groupDoc.data();
  const memberIds = (groupData?.memberIds as string[]) || [];
  const totalMemberCount = memberIds.length;
  const respondedCount =
    acceptedMembers.length + declinedMembers.length;
  const pendingCount = Math.max(0, totalMemberCount - respondedCount);

  const contentState: VoteContentState = {
    acceptedMembers,
    declinedMembers,
    pendingCount,
    isFinalized: true,
  };

  // 4. Broadcast APNs "end" event
  const isProduction = isAPNsProduction();
  const now = Math.floor(Date.now() / 1000);
  const payload = {
    aps: {
      "timestamp": now,
      "event": "end",
      "dismissal-date": now,
      "content-state": contentState,
    },
  };

  const result = await sendAPNsBroadcast({
    channelId,
    payload,
    isProduction,
  });

  if (result.success) {
    console.log(
      `✅ endVoteActivityInternal(${reason}): ` +
        `end broadcast sent channelId=${channelId}`
    );
  } else {
    console.error(
      `❌ endVoteActivityInternal(${reason}): ` +
        `broadcast failed ${result.error}`
    );
  }

  // 5. Remove voteChannelId from Firestore
  await scheduleRef.update({
    "liveActivity.voteChannelId": admin.firestore.FieldValue.delete(),
    "liveActivity.voteEndedAt":
      admin.firestore.FieldValue.serverTimestamp(),
  });

  console.log(
    `🗑️ endVoteActivityInternal(${reason}): ` +
      `voteChannelId removed scheduleId=${scheduleId}`
  );
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

    // 케이스 4: 약속 시간이 이미 지난 경우 (케이스 3보다 먼저 체크)
    const scheduledAtMs = startAt.toDate().getTime();
    if (scheduledAtMs < Date.now()) {
      throw new HttpsError(
        "failed-precondition",
        "약속 시간이 이미 지났습니다",
      );
    }

    // 케이스 5: 이미 진행 중인 투표가 있는 경우
    const existingChannelId =
      scheduleData.liveActivity?.voteChannelId as string | undefined;
    if (existingChannelId) {
      throw new HttpsError(
        "already-exists",
        "이미 투표가 진행 중입니다",
      );
    }

    // 케이스 3: 투표 마감 시간이 이미 지난 경우
    const trackingStartEarly =
      (scheduleData.trackingStartMinutesBefore as number) || 30;
    const deadlineFromScheduleEarly =
      scheduledAtMs - trackingStartEarly * 60 * 1000;
    const maxDeadlineEarly = Date.now() + 8 * 60 * 60 * 1000;
    const voteDeadlineMsEarly = Math.min(
      deadlineFromScheduleEarly,
      maxDeadlineEarly,
    );
    const voteDeadlineEarly = Math.floor(voteDeadlineMsEarly / 1000);
    if (voteDeadlineEarly <= Math.floor(Date.now() / 1000)) {
      throw new HttpsError(
        "failed-precondition",
        "투표 마감 시간이 이미 지났습니다",
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

    // 6. Save channelId to Firestore + auto-accept host
    const resolvedHostName = hostName || "호스트";
    const now = admin.firestore.FieldValue.serverTimestamp();
    const promiseRef = promisesCollection.doc(scheduleId);
    await promiseRef.update({
      "liveActivity.voteChannelId": channelId,
      "liveActivity.voteStartedAt": now,
      "votes.accepted": admin.firestore.FieldValue.arrayUnion(hostId),
    });

    // Save host vote to subcollection
    await promiseRef.collection("votes").doc(hostId).set({
      response: "accepted",
      userName: resolvedHostName,
      respondedAt: now,
    });

    // 7. Send Push to Start to all members

    // 투표 마감 시간 계산
    // scheduledTime - trackingStartMinutesBefore, 최대 now+8시간
    const trackingStart =
      (scheduleData.trackingStartMinutesBefore as number) || 30;
    const deadlineFromSchedule =
      scheduledAtMs - trackingStart * 60 * 1000;
    const maxDeadline = Date.now() + 8 * 60 * 60 * 1000;
    const voteDeadlineMs = Math.min(deadlineFromSchedule, maxDeadline);
    const voteDeadline = Math.floor(voteDeadlineMs / 1000);

    const initialContentState: VoteContentState = {
      acceptedMembers: [{id: hostId, name: resolvedHostName}],
      declinedMembers: [],
      pendingCount: totalMemberCount - 1,
      isFinalized: false,
    };

    const pushResults = await Promise.allSettled(
      allTokens.map(({userId: tokenUserId, token}) => {
        const payload = {
          aps: {
            "timestamp": Math.floor(Date.now() / 1000),
            "event": "start",
            "dismissal-date": voteDeadline,
            "input-push-channel": channelId, // iOS 18 채널 구독
            "attributes-type": "VoteActivityAttributes",
            "attributes": {
              scheduleId,
              currentUserId: tokenUserId,
              emoji,
              title,
              location,
              scheduledTime: scheduledAtMs / 1000,
              hostId,
              hostName,
              channelId,
              groupName,
              totalMemberCount,
              voteDeadline,
            },
            "content-state": initialContentState,
            "alert": {
              "title": `${emoji} ${title}`,
              "body": "참여 여부를 확인해주세요",
            },
          },
        };
        return sendAPNsPush({
          deviceToken: token,
          payload,
          pushType: "liveactivity",
          topic: `${APNS_BUNDLE_ID}.push-type.liveactivity`,
          priority: 10,
          isProduction,
        });
      })
    );

    let successCount = 0;
    let failureCount = 0;
    pushResults.forEach((result, index) => {
      const tokenUserId = allTokens[index].userId;
      if (
        result.status === "fulfilled" &&
        result.value.success
      ) {
        successCount++;
        console.log(
          `✅ Vote APNs Push to Start success for ${tokenUserId}`
        );
      } else {
        failureCount++;
        const error =
          result.status === "rejected" ?
            result.reason :
            result.value.error;
        console.log(
          "❌ Vote APNs Push to Start failed for " +
            tokenUserId + ": " + error
        );
      }
    });

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
    const voteDocRef = scheduleRef.collection("votes").doc(userId);

    // 1-4. Atomic transaction: save vote + read all votes +
    //       read schedule/group + sync accepted/declined IDs
    let contentState: VoteContentState;
    let channelId: string | undefined;

    await db.runTransaction(async (tx) => {
      // Read schedule, group, and all existing votes atomically
      const scheduleDoc = await tx.get(scheduleRef);
      const scheduleData = scheduleDoc.data();
      if (!scheduleData) {
        throw new HttpsError(
          "not-found",
          "일정을 찾을 수 없습니다",
        );
      }

      const groupId = scheduleData.groupId as string;
      const groupRef = db.collection("groups").doc(groupId);
      const groupDoc = await tx.get(groupRef);
      const groupData = groupDoc.data();
      const memberIds = (groupData?.memberIds as string[]) || [];

      const votesSnapshot = await tx.get(
        scheduleRef.collection("votes")
      );

      // Build ContentState with the new vote included
      const acceptedMembers: VoteMember[] = [];
      const declinedMembers: VoteMember[] = [];

      votesSnapshot.forEach((doc) => {
        if (doc.id === userId) return; // will be overwritten below
        const voteData = doc.data();
        const member: VoteMember = {
          id: doc.id,
          name: (voteData.userName as string) || "멤버",
        };
        if (voteData.response === "accepted") {
          acceptedMembers.push(member);
        } else if (voteData.response === "declined") {
          declinedMembers.push(member);
        }
      });

      // Include the current vote
      const currentMember: VoteMember = {id: userId, name: userName};
      if (response === "accepted") {
        acceptedMembers.push(currentMember);
      } else {
        declinedMembers.push(currentMember);
      }

      const totalMemberCount = memberIds.length;
      const respondedCount =
        acceptedMembers.length + declinedMembers.length;
      const isFinalized = respondedCount >= totalMemberCount;
      const pendingCount = Math.max(0, totalMemberCount - respondedCount);

      contentState = {
        acceptedMembers,
        declinedMembers,
        pendingCount,
        isFinalized,
      };

      channelId = scheduleData?.["liveActivity"]?.voteChannelId as
        | string
        | undefined;

      const acceptedIds = acceptedMembers.map((m) => m.id);
      const declinedIds = declinedMembers.map((m) => m.id);

      // Write: save vote + sync main document
      tx.set(voteDocRef, {
        response,
        userName,
        respondedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      tx.update(scheduleRef, {
        "votes.accepted": acceptedIds,
        "votes.declined": declinedIds,
      });
    });

    // 5. Broadcast via APNs (outside transaction — external call)
    // contentState! is guaranteed to be set by the transaction above
    const finalContentState = contentState!;
    const finalIsFinalized = finalContentState.isFinalized;

    if (!channelId) {
      console.warn(
        `⚠️ No voteChannelId for scheduleId=${scheduleId}, ` +
          "skipping broadcast"
      );
      return {success: true, contentState: finalContentState};
    }

    const isProduction = isAPNsProduction();
    const payload = {
      aps: {
        "timestamp": Math.floor(Date.now() / 1000),
        "event": finalIsFinalized ? "end" : "update",
        "content-state": finalContentState,
        ...(finalIsFinalized && {
          "alert": {
            "title": "투표가 마감되었습니다",
            "body": `참여 ${finalContentState.acceptedMembers.length}명` +
              ` / 불참 ${finalContentState.declinedMembers.length}명`,
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
          `isFinalized=${finalIsFinalized}`
      );
    } else {
      console.error(`❌ Vote broadcast failed: ${result.error}`);
    }

    return {success: result.success, contentState: finalContentState};
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

    // Required auth token verification
    if (!authToken) {
      res.status(401).json({
        error: {
          code: "unauthenticated",
          message: "X-Auth-Token header is required",
        },
      });
      return;
    }

    try {
      const decodedToken = await admin.auth().verifyIdToken(authToken);
      if (decodedToken.uid !== userId) {
        res.status(401).json({
          error: {code: "unauthenticated", message: "Token uid mismatch"},
        });
        return;
      }
    } catch (error) {
      console.error(
        `❌ Widget vote auth token verification failed: ${error}`
      );
      res.status(401).json({
        error: {
          code: "unauthenticated",
          message: "Token verification failed",
        },
      });
      return;
    }

    const {scheduleId, response, userName} = req.body as {
      scheduleId: string;
      response: "accepted" | "declined";
      userName?: string;
    };

    if (!scheduleId || !response) {
      res.status(400).json({
        error: {
          code: "invalid-argument",
          message: "scheduleId and response are required",
        },
      });
      return;
    }

    // userName이 없으면 Firestore에서 조회
    let resolvedUserName = userName;
    if (!resolvedUserName) {
      const userDoc = await admin.firestore()
        .collection("users").doc(userId).get();
      resolvedUserName =
        (userDoc.data()?.nickname as string) || "멤버";
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

    const widgetVoteDocRef = scheduleRef.collection("votes").doc(userId);

    // Atomic transaction: save vote + read all votes +
    // read schedule/group + sync accepted/declined IDs
    let widgetContentState: VoteContentState | undefined;
    let widgetChannelId: string | undefined;

    await db.runTransaction(async (tx) => {
      const scheduleDoc = await tx.get(scheduleRef);
      const scheduleData = scheduleDoc.data();
      if (!scheduleData) {
        throw new Error("Failed to read schedule data in transaction");
      }

      const txGroupId = scheduleData.groupId as string;
      const groupRef = db.collection("groups").doc(txGroupId);
      const groupDoc = await tx.get(groupRef);
      const groupData = groupDoc.data();
      const memberIds = (groupData?.memberIds as string[]) || [];

      const votesSnapshot = await tx.get(
        scheduleRef.collection("votes")
      );

      const acceptedMembers: VoteMember[] = [];
      const declinedMembers: VoteMember[] = [];

      votesSnapshot.forEach((doc) => {
        if (doc.id === userId) return; // will be overwritten below
        const voteData = doc.data();
        const member: VoteMember = {
          id: doc.id,
          name: (voteData.userName as string) || "멤버",
        };
        if (voteData.response === "accepted") {
          acceptedMembers.push(member);
        } else if (voteData.response === "declined") {
          declinedMembers.push(member);
        }
      });

      // Include the current vote
      const currentMember: VoteMember = {
        id: userId,
        name: resolvedUserName || "멤버",
      };
      if (response === "accepted") {
        acceptedMembers.push(currentMember);
      } else {
        declinedMembers.push(currentMember);
      }

      const totalMemberCount = memberIds.length;
      const respondedCount =
        acceptedMembers.length + declinedMembers.length;
      const isFinalized = respondedCount >= totalMemberCount;
      const pendingCount =
        Math.max(0, totalMemberCount - respondedCount);

      widgetContentState = {
        acceptedMembers,
        declinedMembers,
        pendingCount,
        isFinalized,
      };

      widgetChannelId =
        scheduleData?.["liveActivity"]?.voteChannelId as
          | string
          | undefined;

      const acceptedIds = acceptedMembers.map((m) => m.id);
      const declinedIds = declinedMembers.map((m) => m.id);

      tx.set(widgetVoteDocRef, {
        response,
        userName: resolvedUserName,
        respondedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      tx.update(scheduleRef, {
        "votes.accepted": acceptedIds,
        "votes.declined": declinedIds,
      });
    });

    // Broadcast via APNs (outside transaction — external call)
    // widgetContentState is guaranteed set by the transaction above
    const contentState = widgetContentState!;
    const isFinalized = contentState.isFinalized;
    const channelId = widgetChannelId;

    if (!channelId) {
      console.warn(
        `⚠️ No voteChannelId for scheduleId=${scheduleId}, ` +
          "skipping broadcast"
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
            "body": `참여 ${contentState.acceptedMembers.length}명` +
              ` / 불참 ${contentState.declinedMembers.length}명`,
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
    const acceptedMembers: VoteMember[] = [];
    const declinedMembers: VoteMember[] = [];

    votesSnapshot.forEach((doc) => {
      const voteData = doc.data();
      const member: VoteMember = {
        id: doc.id,
        name: (voteData.userName as string) || "멤버",
      };
      if (voteData.response === "accepted") {
        acceptedMembers.push(member);
      } else if (voteData.response === "declined") {
        declinedMembers.push(member);
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

    // 4. Save finalized state to Firestore + sync main document
    const acceptedIds = acceptedMembers.map((m) => m.id);
    const declinedIds = declinedMembers.map((m) => m.id);
    await scheduleRef.update({
      "liveActivity.voteFinalized": true,
      "liveActivity.voteFinalizedAt":
        admin.firestore.FieldValue.serverTimestamp(),
      "liveActivity.acceptedMembers": acceptedMembers,
      "liveActivity.declinedMembers": declinedMembers,
      "votes.accepted": acceptedIds,
      "votes.declined": declinedIds,
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

/**
 * End Vote LiveActivity (케이스 1: 약속 삭제, 케이스 2: 날짜/시간 변경)
 *
 * Broadcasts APNs "end" event to terminate the LiveActivity for all
 * subscribers and removes the voteChannelId from Firestore.
 * Called by the client on schedule deletion or date/time change.
 * Internally delegates to endVoteActivityInternal.
 */
export const endVoteLiveActivity = onCall(
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

    console.log(
      `📥 endVoteLiveActivity called: scheduleId="${scheduleId}"`
    );

    // Permission check (host only)
    const db = admin.firestore();
    const scheduleDoc = await db
      .collection("promises")
      .doc(scheduleId)
      .get();

    if (!scheduleDoc.exists) {
      throw new HttpsError("not-found", "일정을 찾을 수 없습니다");
    }

    const scheduleData = scheduleDoc.data();
    if (!scheduleData) {
      throw new HttpsError("internal", "일정 데이터를 읽을 수 없습니다");
    }

    const hostId = scheduleData.hostId as string;
    if (userId !== hostId) {
      throw new HttpsError(
        "permission-denied",
        "호스트만 투표 LiveActivity를 종료할 수 있습니다",
      );
    }

    await endVoteActivityInternal(scheduleId, "endVoteLiveActivity");
    return {success: true};
  },
);
