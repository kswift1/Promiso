/**
 * APNs (Apple Push Notification Service) 유틸리티
 */
import * as http2 from "http2";
import * as jwt from "jsonwebtoken";
import {
  APNS_KEY_ID,
  APNS_TEAM_ID,
  APNS_AUTH_KEY,
  APNS_HOST_PRODUCTION,
  APNS_HOST_DEVELOPMENT,
  APNS_BUNDLE_ID,
  CHANNEL_MGMT_HOST_PRODUCTION,
  CHANNEL_MGMT_HOST_DEVELOPMENT,
  CHANNEL_MGMT_PORT_PRODUCTION,
  CHANNEL_MGMT_PORT_DEVELOPMENT,
} from "../config";

/**
 * APNs JWT 토큰 생성
 *
 * @param {string} keyId - APNs Auth Key ID
 * @param {string} teamId - Apple Developer Team ID
 * @param {string} authKey - APNs Auth Key (P8 내용)
 * @return {string} JWT 토큰
 */
export function generateAPNsJWT(
  keyId: string,
  teamId: string,
  authKey: string,
): string {
  const token = jwt.sign(
    {},
    authKey,
    {
      algorithm: "ES256",
      keyid: keyId,
      issuer: teamId,
      expiresIn: "1h",
      header: {
        alg: "ES256",
        kid: keyId,
      },
    },
  );
  return token;
}

/**
 * APNs HTTP/2 푸시 전송
 *
 * @param {object} params - 파라미터
 * @return {Promise<object>} 결과 객체
 */
export async function sendAPNsPush(params: {
  deviceToken: string;
  payload: object;
  pushType: "liveactivity";
  topic: string;
  apnsId?: string;
  expiration?: number;
  priority?: number;
  isProduction: boolean;
}): Promise<{success: boolean; statusCode?: number; error?: string}> {
  const {
    deviceToken,
    payload,
    pushType,
    topic,
    apnsId,
    expiration,
    priority,
    isProduction,
  } = params;

  const host = isProduction ? APNS_HOST_PRODUCTION : APNS_HOST_DEVELOPMENT;
  const path = `/3/device/${deviceToken}`;

  // JWT 토큰 생성
  const keyId = APNS_KEY_ID.value();
  const teamId = APNS_TEAM_ID.value();
  const authKey = APNS_AUTH_KEY.value().replace(/\\n/g, "\n");
  const jwtToken = generateAPNsJWT(keyId, teamId, authKey);

  return new Promise((resolve) => {
    const client = http2.connect(`https://${host}`);

    client.on("error", (err) => {
      console.error("❌ APNs HTTP/2 connection error:", err);
      resolve({success: false, error: err.message});
    });

    const headers: http2.OutgoingHttpHeaders = {
      ":method": "POST",
      ":path": path,
      "authorization": `bearer ${jwtToken}`,
      "apns-push-type": pushType,
      "apns-topic": topic,
      ...(apnsId && {"apns-id": apnsId}),
      ...(expiration !== undefined && {
        "apns-expiration": expiration.toString(),
      }),
      ...(priority !== undefined && {
        "apns-priority": priority.toString(),
      }),
    };

    const req = client.request(headers);

    let responseData = "";

    req.on("response", (headers) => {
      const statusCode = headers[":status"] as number;

      req.on("data", (chunk) => {
        responseData += chunk;
      });

      req.on("end", () => {
        client.close();

        if (statusCode === 200) {
          resolve({success: true, statusCode});
        } else {
          console.error(`❌ APNs error: ${statusCode} - ${responseData}`);
          resolve({success: false, statusCode, error: responseData});
        }
      });
    });

    req.on("error", (err) => {
      console.error("❌ APNs request error:", err);
      client.close();
      resolve({success: false, error: err.message});
    });

    req.write(JSON.stringify(payload));
    req.end();
  });
}

/**
 * iOS 18 Broadcast APNs 채널 생성
 * Channel Management API 사용 (별도 호스트/포트)
 *
 * @param {boolean} isProduction - Production 환경 여부
 * @return {Promise<object>} 결과 객체 (channelId는 Apple이 생성해서 반환)
 */
export async function createAPNsChannel(
  isProduction: boolean
): Promise<{success: boolean; channelId?: string; error?: string}> {
  const host = isProduction ?
    CHANNEL_MGMT_HOST_PRODUCTION : CHANNEL_MGMT_HOST_DEVELOPMENT;
  const port = isProduction ?
    CHANNEL_MGMT_PORT_PRODUCTION : CHANNEL_MGMT_PORT_DEVELOPMENT;

  const keyId = APNS_KEY_ID.value();
  const teamId = APNS_TEAM_ID.value();
  const authKey = APNS_AUTH_KEY.value().replace(/\\n/g, "\n");

  const path = `/1/apps/${APNS_BUNDLE_ID}/channels`;
  const jwtToken = generateAPNsJWT(keyId, teamId, authKey);

  console.log(`📡 Creating APNs channel: ${host}:${port}${path}`);

  return new Promise((resolve) => {
    const client = http2.connect(`https://${host}:${port}`);

    client.on("error", (err) => {
      console.error("❌ APNs Channel creation connection error:", err);
      resolve({success: false, error: err.message});
    });

    const headers: http2.OutgoingHttpHeaders = {
      ":method": "POST",
      ":path": path,
      "authorization": `bearer ${jwtToken}`,
      "content-type": "application/json",
    };

    const req = client.request(headers);
    let responseData = "";
    let responseHeaders: http2.IncomingHttpHeaders = {};

    req.on("response", (hdrs) => {
      responseHeaders = hdrs;
      const statusCode = hdrs[":status"] as number;

      req.on("data", (chunk) => {
        responseData += chunk;
      });

      req.on("end", () => {
        client.close();

        if (statusCode === 201 || statusCode === 200) {
          // 채널 ID는 응답 헤더에서 추출
          const channelId = responseHeaders["apns-channel-id"] as string;
          if (channelId) {
            console.log(`✅ APNs Channel created: ${channelId}`);
            resolve({success: true, channelId});
          } else {
            console.warn("⚠️ Channel created but no channelId in response");
            resolve({success: true});
          }
        } else {
          console.error(
            `❌ APNs Channel creation error: ${statusCode} - ${responseData}`
          );
          resolve({success: false, error: responseData});
        }
      });
    });

    req.on("error", (err) => {
      console.error("❌ APNs Channel creation request error:", err);
      client.close();
      resolve({success: false, error: err.message});
    });

    // Apple Channel Management payload 형식
    const payload = {
      "push-type": "LiveActivity",
      "message-storage-policy": 1, // 0: NoStored, 1: MostRecentStored
    };
    req.write(JSON.stringify(payload));
    req.end();
  });
}

/**
 * iOS 18 Broadcast APNs 푸시 전송
 *
 * Broadcast는 채널 기반으로 모든 구독자에게 한 번의 요청으로 전송
 * 개별 토큰 관리 불필요
 *
 * @param {object} params - 파라미터
 * @return {Promise<object>} 결과 객체
 */
export async function sendAPNsBroadcast(params: {
  channelId: string;
  payload: object;
  isProduction: boolean;
}): Promise<{success: boolean; statusCode?: number; error?: string}> {
  const {channelId, payload, isProduction} = params;

  const host = isProduction ?
    APNS_HOST_PRODUCTION : APNS_HOST_DEVELOPMENT;

  const keyId = APNS_KEY_ID.value();
  const teamId = APNS_TEAM_ID.value();
  const authKey = APNS_AUTH_KEY.value().replace(/\\n/g, "\n");
  const jwtToken = generateAPNsJWT(keyId, teamId, authKey);

  // Apple Broadcast API: /4/broadcasts/apps/{bundleId}
  const path = `/4/broadcasts/apps/${APNS_BUNDLE_ID}`;

  return new Promise((resolve) => {
    const client = http2.connect(`https://${host}`);

    client.on("error", (err) => {
      console.error("❌ APNs Broadcast connection error:", err);
      resolve({success: false, error: err.message});
    });

    const headers: http2.OutgoingHttpHeaders = {
      ":method": "POST",
      ":path": path,
      "authorization": `bearer ${jwtToken}`,
      "content-type": "application/json",
      "apns-push-type": "liveactivity",
      "apns-topic": `${APNS_BUNDLE_ID}.push-type.liveactivity`,
      "apns-channel-id": channelId,
      "apns-priority": "10",
      "apns-expiration": "0",
    };

    const req = client.request(headers);
    let responseData = "";

    req.on("response", (headers) => {
      const statusCode = headers[":status"] as number;

      req.on("data", (chunk) => {
        responseData += chunk;
      });

      req.on("end", () => {
        client.close();

        if (statusCode === 200) {
          console.log(`✅ APNs Broadcast sent: channelId=${channelId}`);
          resolve({success: true, statusCode});
        } else {
          console.error(
            `❌ APNs Broadcast error: ${statusCode} - ${responseData}`
          );
          resolve({success: false, statusCode, error: responseData});
        }
      });
    });

    req.on("error", (err) => {
      console.error("❌ APNs Broadcast request error:", err);
      client.close();
      resolve({success: false, error: err.message});
    });

    req.write(JSON.stringify(payload));
    req.end();
  });
}
