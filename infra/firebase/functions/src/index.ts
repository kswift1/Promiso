import * as admin from "firebase-admin";
import {setGlobalOptions} from "firebase-functions/v2";
import {onCall, onRequest} from "firebase-functions/v2/https";

// Firebase Admin 초기화
admin.initializeApp();

// 공통 옵션(비용/스케일 제어)
setGlobalOptions({maxInstances: 10});

// ✅ 테스트용 간단한 HTTP 함수
export const helloWorld = onRequest(
  {region: "asia-northeast3"},
  (request, response) => {
    response.json({
      message: "Hello from Firebase!",
      timestamp: new Date().toISOString(),
    });
  },
);

// ✅ 테스트용 Callable 함수
export const testCallable = onCall(
  {region: "asia-northeast3"},
  (request) => {
    const name = (request.data as {name?: string} | undefined)?.name ?? "Guest";
    return {
      message: `Hello ${name}!`,
      authenticated: request.auth != null,
      uid: request.auth?.uid ?? null,
    };
  },
);
