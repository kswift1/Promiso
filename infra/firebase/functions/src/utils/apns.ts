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

// ============================================================================
// Types
// ============================================================================

/** APNs 요청 결과 */
export interface APNsResult {
  success: boolean;
  statusCode?: number;
  error?: string;
  channelId?: string;
}

/** APNs 자격 증명 */
interface APNsCredentials {
  keyId: string;
  teamId: string;
  authKey: string;
  jwtToken: string;
}

/** HTTP/2 요청 옵션 */
interface HTTP2RequestOptions {
  host: string;
  port?: number;
  path: string;
  headers: http2.OutgoingHttpHeaders;
  payload?: object;
  successCodes?: number[];
  onSuccess?: (
    headers: http2.IncomingHttpHeaders,
    data: string
  ) => APNsResult;
}

// ============================================================================
// Helper Functions
// ============================================================================

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
  return jwt.sign(
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
}

/**
 * APNs 자격 증명 가져오기
 *
 * @return {APNsCredentials} 자격 증명
 */
function getAPNsCredentials(): APNsCredentials {
  // Secret Manager 값에 trailing newline이 있을 수 있어 trim() 필수
  const keyId = APNS_KEY_ID.value().trim();
  const teamId = APNS_TEAM_ID.value().trim();
  const rawAuthKey = APNS_AUTH_KEY.value().trim();
  const authKey = rawAuthKey.replace(/\\n/g, "\n");
  const jwtToken = generateAPNsJWT(keyId, teamId, authKey);

  return {keyId, teamId, authKey, jwtToken};
}

/**
 * APNs 호스트 가져오기
 *
 * @param {boolean} isProduction - Production 환경 여부
 * @return {string} APNs 호스트
 */
function getAPNsHost(isProduction: boolean): string {
  return isProduction ? APNS_HOST_PRODUCTION : APNS_HOST_DEVELOPMENT;
}

/**
 * HTTP/2 요청 실행 (공통 로직)
 *
 * @param {HTTP2RequestOptions} options - 요청 옵션
 * @return {Promise<APNsResult>} 결과
 */
function executeHTTP2Request(
  options: HTTP2RequestOptions
): Promise<APNsResult> {
  const {
    host,
    port,
    path,
    headers,
    payload,
    successCodes = [200],
    onSuccess,
  } = options;

  const url = port ? `https://${host}:${port}` : `https://${host}`;

  return new Promise((resolve) => {
    const client = http2.connect(url);

    client.on("error", (err) => {
      console.error(`❌ APNs HTTP/2 connection error (${path}):`, err);
      resolve({success: false, error: err.message});
    });

    const req = client.request({
      ":method": "POST",
      ":path": path,
      ...headers,
    });

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

        if (successCodes.includes(statusCode)) {
          if (onSuccess) {
            resolve(onSuccess(responseHeaders, responseData));
          } else {
            resolve({success: true, statusCode});
          }
        } else {
          const msg = `❌ APNs error (${path}): ${statusCode} - ${responseData}`;
          console.error(msg);
          resolve({success: false, statusCode, error: responseData});
        }
      });
    });

    req.on("error", (err) => {
      console.error(`❌ APNs request error (${path}):`, err);
      client.close();
      resolve({success: false, error: err.message});
    });

    if (payload) {
      req.write(JSON.stringify(payload));
    }
    req.end();
  });
}

// ============================================================================
// Public Functions
// ============================================================================

/**
 * APNs HTTP/2 푸시 전송
 *
 * @param {object} params - 파라미터
 * @return {Promise<APNsResult>} 결과 객체
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
}): Promise<APNsResult> {
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

  const {jwtToken} = getAPNsCredentials();
  const host = getAPNsHost(isProduction);

  return executeHTTP2Request({
    host,
    path: `/3/device/${deviceToken}`,
    headers: {
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
    },
    payload,
  });
}

/**
 * iOS 18 Broadcast APNs 채널 생성
 *
 * @param {boolean} isProduction - Production 환경 여부
 * @return {Promise<APNsResult>} 결과 객체 (channelId는 Apple이 생성)
 */
export async function createAPNsChannel(
  isProduction: boolean
): Promise<APNsResult> {
  const host = isProduction ?
    CHANNEL_MGMT_HOST_PRODUCTION : CHANNEL_MGMT_HOST_DEVELOPMENT;
  const port = isProduction ?
    CHANNEL_MGMT_PORT_PRODUCTION : CHANNEL_MGMT_PORT_DEVELOPMENT;

  const {jwtToken} = getAPNsCredentials();
  const path = `/1/apps/${APNS_BUNDLE_ID}/channels`;

  console.log(`📡 Creating APNs channel: ${host}:${port}${path}`);

  return executeHTTP2Request({
    host,
    port,
    path,
    headers: {
      "authorization": `bearer ${jwtToken}`,
      "content-type": "application/json",
    },
    payload: {
      "push-type": "LiveActivity",
      "message-storage-policy": 1,
    },
    successCodes: [200, 201],
    onSuccess: (headers) => {
      const channelId = headers["apns-channel-id"] as string | undefined;
      if (channelId) {
        console.log(`✅ APNs Channel created: ${channelId}`);
        return {success: true, channelId};
      } else {
        console.warn("⚠️ Channel created but no channelId in response");
        return {success: true};
      }
    },
  });
}

/**
 * iOS 18 Broadcast APNs 푸시 전송
 *
 * @param {object} params - 파라미터
 * @return {Promise<APNsResult>} 결과 객체
 */
export async function sendAPNsBroadcast(params: {
  channelId: string;
  payload: object;
  isProduction: boolean;
}): Promise<APNsResult> {
  const {channelId, payload, isProduction} = params;

  const {jwtToken} = getAPNsCredentials();
  const host = getAPNsHost(isProduction);

  const result = await executeHTTP2Request({
    host,
    path: `/4/broadcasts/apps/${APNS_BUNDLE_ID}`,
    headers: {
      "authorization": `bearer ${jwtToken}`,
      "content-type": "application/json",
      "apns-push-type": "liveactivity",
      "apns-topic": `${APNS_BUNDLE_ID}.push-type.liveactivity`,
      "apns-channel-id": channelId,
      "apns-priority": "10",
      "apns-expiration": "0",
    },
    payload,
  });

  if (result.success) {
    console.log(`✅ APNs Broadcast sent: channelId=${channelId}`);
  }

  return result;
}
