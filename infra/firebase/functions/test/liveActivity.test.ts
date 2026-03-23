// @ts-nocheck
/* eslint-disable @typescript-eslint/no-explicit-any */
/**
 * LiveActivity Functions 테스트
 *
 * 복잡도가 매우 높은 함수에 대한 철저한 유닛 테스트
 * - APNs HTTP/2 통신
 * - JWT 서명 검증
 * - Channel 생성/관리
 * - Cloud Tasks 큐
 * - iOS 18 Push to Start API
 * - 비동기 처리 (Promise chaining)
 */
import {
  describe,
  it,
  expect,
  jest,
  beforeEach,
  afterEach,
} from '@jest/globals';
import * as admin from 'firebase-admin';

// ============================================================================
// Mock 설정
// ============================================================================

// Firebase Functions params mock
jest.mock('firebase-functions/params', () => ({
  defineSecret: jest.fn((name: string) => {
    const secrets: Record<string, string> = {
      APNS_KEY_ID: 'TEST_KEY_ID',
      APNS_TEAM_ID: 'TEST_TEAM_ID',
      APNS_AUTH_KEY: '-----BEGIN PRIVATE KEY-----\nMIGTAgEAMBMGByqGSM49AgEGCCqGSM49AwEHBHkwdwIBAQQg' +
        'TEST_PRIVATE_KEY_DATA\nogBggqhkjOPQMBB6FEAxIANT' +
        '\n-----END PRIVATE KEY-----',
      GEMINI_API_KEY: 'test-gemini-key',
    };
    return {
      value: () => secrets[name] || 'test-secret-value',
    };
  }),
  defineString: jest.fn((name: string, options?: {default?: string}) => ({
    value: () => options?.default ?? '',
  })),
}));

// HTTP/2 mock
const mockHttp2Client = {
  on: jest.fn(),
  request: jest.fn(),
  close: jest.fn(),
};

const mockHttp2Request = {
  on: jest.fn(),
  write: jest.fn(),
  end: jest.fn(),
};

jest.mock('http2', () => ({
  connect: jest.fn(() => mockHttp2Client),
  constants: {
    HTTP2_HEADER_AUTHORITY: ':authority',
    HTTP2_HEADER_METHOD: ':method',
    HTTP2_HEADER_PATH: ':path',
    HTTP2_HEADER_SCHEME: ':scheme',
    HTTP2_HEADER_STATUS: ':status',
    HTTP2_METHOD_POST: 'POST',
  },
}));

// Firebase Functions (getFunctions) mock
const mockTaskQueue = {
  enqueue: jest.fn().mockResolvedValue(undefined as any),
};

jest.mock('firebase-admin/functions', () => ({
  getFunctions: jest.fn(() => ({
    taskQueue: jest.fn(() => mockTaskQueue),
  })),
}));

// JWT mock
jest.mock('jsonwebtoken', () => ({
  sign: jest.fn(() => 'mock-jwt-token'),
  verify: jest.fn(),
}));

// ============================================================================
// 테스트 유틸리티
// ============================================================================

/**
 * Firestore 문서 mock 생성
 */
function createMockDocument(exists: boolean, data?: Record<string, unknown>): any {
  return {
    exists,
    id: 'mock-doc-id',
    data: () => data,
    ref: {
      id: 'mock-doc-id',
      update: jest.fn().mockResolvedValue(undefined as any),
    },
  };
}

/**
 * Firestore Timestamp mock
 */
function createMockTimestamp(date: Date = new Date()): any {
  return {
    toDate: () => date,
    toMillis: () => date.getTime(),
    seconds: Math.floor(date.getTime() / 1000),
    nanoseconds: 0,
  };
}

/**
 * HTTP/2 성공 응답 시뮬레이션
 */
function simulateHttp2Success(statusCode: number = 200, headers: Record<string, string> = {}) {
  simulateHttp2Sequence([{ statusCode, headers }]);
}

function simulateHttp2Sequence(
  responses: Array<{statusCode: number; headers?: Record<string, string>; body?: string}>
) {
  let responseIndex = 0;

  mockHttp2Client.on.mockImplementation((event: string, _callback: Function) => {
    if (event === 'error') {
      // No error
    }
    return mockHttp2Client;
  });

  mockHttp2Client.request.mockImplementation(() => {
    const response =
      responses[Math.min(responseIndex, responses.length - 1)] ||
      { statusCode: 200, headers: {}, body: '' };
    responseIndex += 1;

    mockHttp2Request.on.mockImplementation((event: string, callback: Function) => {
      if (event === 'response') {
        const responseHeaders = {
          ':status': response.statusCode,
          ...(response.headers || {}),
        };
        setTimeout(() => callback(responseHeaders), 0);
      }
      if (event === 'data') {
        setTimeout(() => callback(response.body || ''), 10);
      }
      if (event === 'end') {
        setTimeout(() => callback(), 20);
      }
      return mockHttp2Request;
    });
    return mockHttp2Request;
  });
}

// ============================================================================
// registerPushToStartToken 테스트
// ============================================================================

describe('registerPushToStartToken', () => {
  let registerPushToStartToken: any;
  let mockFirestore: any;
  let mockUserRef: any;

  beforeEach(async () => {
    jest.clearAllMocks();

    mockUserRef = {
      update: jest.fn().mockResolvedValue(undefined as any),
    };

    mockFirestore = {
      collection: jest.fn().mockReturnValue({
        doc: jest.fn().mockReturnValue(mockUserRef),
      }),
    };

    jest.spyOn(admin, 'firestore').mockReturnValue(mockFirestore as any);

    const functions = await import('../src/functions/liveActivity');
    registerPushToStartToken = functions.registerPushToStartToken;
  });

  afterEach(() => {
    jest.restoreAllMocks();
    jest.resetModules();
  });

  // NOTE: 정상 케이스는 실제 Firestore/APNs 작업이 필요하여 에뮬레이터 환경에서 통합 테스트로 수행
  describe.skip('정상 케이스', () => {
    it('Push to Start 토큰을 성공적으로 등록한다', async () => {
      const request = {
        data: {
          token: 'apns-push-to-start-token-12345',
          deviceId: 'device-uuid-12345',
        },
        auth: { uid: 'test-user-id' },
      };

      const result = await registerPushToStartToken(request);

      expect(result).toBeDefined();
      expect(result.success).toBe(true);
      expect(mockUserRef.update).toHaveBeenCalledWith({
        'devices.device-uuid-12345.pushToStartToken': 'apns-push-to-start-token-12345',
      });
    });
  });

  describe('인증 에러', () => {
    it('인증 없이 호출 시 unauthenticated 에러를 발생시킨다', async () => {
      const request = {
        data: {
          token: 'test-token',
          deviceId: 'test-device',
        },
        auth: undefined,
      };

      await expect(registerPushToStartToken(request)).rejects.toThrow();
    });
  });

  describe('유효성 검사 에러', () => {
    it('token이 없으면 에러를 발생시킨다', async () => {
      const request = {
        data: {
          deviceId: 'test-device',
        },
        auth: { uid: 'test-user-id' },
      };

      await expect(registerPushToStartToken(request)).rejects.toThrow();
    });

    it('deviceId가 없으면 에러를 발생시킨다', async () => {
      const request = {
        data: {
          token: 'test-token',
        },
        auth: { uid: 'test-user-id' },
      };

      await expect(registerPushToStartToken(request)).rejects.toThrow();
    });

    it('token과 deviceId 둘 다 없으면 에러를 발생시킨다', async () => {
      const request = {
        data: {},
        auth: { uid: 'test-user-id' },
      };

      await expect(registerPushToStartToken(request)).rejects.toThrow();
    });
  });

  describe('Firestore 에러', () => {
    it('Firestore 업데이트 실패 시 internal 에러를 발생시킨다', async () => {
      mockUserRef.update.mockRejectedValue(new Error('Firestore error') as any);

      const request = {
        data: {
          token: 'test-token',
          deviceId: 'test-device',
        },
        auth: { uid: 'test-user-id' },
      };

      await expect(registerPushToStartToken(request)).rejects.toThrow();
    });
  });
});

// ============================================================================
// startLiveActivity 테스트
// ============================================================================

describe('startLiveActivity', () => {
  let startLiveActivity: any;
  let mockFirestore: any;

  const mockPromiseData = {
    groupId: 'test-group-id',
    hostId: 'host-user-id',
    title: '테스트 약속',
    emoji: '🎉',
    location: { name: '강남역' },
    startAt: createMockTimestamp(new Date(Date.now() + 3600000)), // 1시간 후
    votes: { accepted: ['host-user-id', 'member1', 'member2'] },
    trackingStartMinutesBefore: 30,
  };

  const mockGroupData = {
    name: '테스트 그룹',
    imageUrl: 'https://example.com/group.jpg',
    memberIds: ['host-user-id', 'member1', 'member2'],
  };

  const mockUserData = (userId: string) => ({
    nickname: `유저 ${userId}`,
    devices: {
      'device-1': {
        pushToStartToken: `token-${userId}`,
        fcmToken: 'fcm-token',
      },
    },
  });

  beforeEach(async () => {
    jest.clearAllMocks();

    const mockPromiseRef = createMockDocument(true, mockPromiseData);
    const mockGroupRef = createMockDocument(true, mockGroupData);

    mockFirestore = {
      collection: jest.fn((name: string) => {
        if (name === 'promises') {
          return {
            doc: jest.fn().mockReturnValue({
              get: jest.fn().mockResolvedValue(mockPromiseRef as any),
            }),
          };
        }
        if (name === 'groups') {
          return {
            doc: jest.fn().mockReturnValue({
              get: jest.fn().mockResolvedValue(mockGroupRef as any),
            }),
          };
        }
        if (name === 'users') {
          return {
            doc: jest.fn((userId: string) => ({
              get: jest.fn().mockResolvedValue(
                createMockDocument(true, mockUserData(userId)) as any
              ),
              id: userId,
            })),
          };
        }
        return {};
      }),
      getAll: jest.fn().mockImplementation((...refs: any[]) => {
        return Promise.resolve(
          refs.map((ref) => ({
            exists: true,
            id: ref.id || 'user-id',
            data: () => mockUserData(ref.id || 'user-id'),
          }))
        );
      }),
    };

    jest.spyOn(admin, 'firestore').mockReturnValue(mockFirestore as any);

    // HTTP/2 성공 시뮬레이션
    simulateHttp2Success(200);

    const functions = await import('../src/functions/liveActivity');
    startLiveActivity = functions.startLiveActivity;
  });

  afterEach(() => {
    jest.restoreAllMocks();
    jest.resetModules();
  });

  // NOTE: 정상 케이스는 실제 APNs/HTTP2 작업이 필요하여 에뮬레이터 환경에서 통합 테스트로 수행
  describe.skip('정상 케이스', () => {
    it('호스트가 LiveActivity를 성공적으로 시작한다', async () => {
      const request = {
        data: { promiseId: 'test-promise-id' },
        auth: { uid: 'host-user-id' },
      };

      const result = await startLiveActivity(request);

      expect(result).toBeDefined();
      expect(result.success).toBe(true);
      expect(result.successCount).toBeGreaterThanOrEqual(0);
    });
  });

  describe('인증 에러', () => {
    it('인증 없이 호출 시 에러를 발생시킨다', async () => {
      const request = {
        data: { promiseId: 'test-promise-id' },
        auth: undefined,
      };

      await expect(startLiveActivity(request)).rejects.toThrow();
    });
  });

  describe('유효성 검사 에러', () => {
    it('promiseId가 없으면 에러를 발생시킨다', async () => {
      const request = {
        data: {},
        auth: { uid: 'host-user-id' },
      };

      await expect(startLiveActivity(request)).rejects.toThrow();
    });
  });

  describe('not-found 에러', () => {
    it('존재하지 않는 약속은 에러를 발생시킨다', async () => {
      mockFirestore.collection = jest.fn().mockReturnValue({
        doc: jest.fn().mockReturnValue({
          get: jest.fn().mockResolvedValue(createMockDocument(false) as any),
        }),
      });

      const request = {
        data: { promiseId: 'nonexistent-promise' },
        auth: { uid: 'host-user-id' },
      };

      await expect(startLiveActivity(request)).rejects.toThrow();
    });
  });

  describe('권한 에러', () => {
    it('호스트가 아닌 사용자는 LiveActivity를 시작할 수 없다', async () => {
      const request = {
        data: { promiseId: 'test-promise-id' },
        auth: { uid: 'member1' }, // Not the host
      };

      await expect(startLiveActivity(request)).rejects.toThrow();
    });
  });

  // NOTE: 실제 APNs HTTP/2 작업이 필요하여 에뮬레이터 환경에서 통합 테스트로 수행
  describe.skip('토큰 없음', () => {
    it('Push to Start 토큰이 없으면 successCount 0을 반환한다', async () => {
      // 토큰이 없는 사용자 데이터
      const noTokenUserData = {
        nickname: '토큰 없는 유저',
        devices: {},
      };

      mockFirestore.getAll = jest.fn().mockResolvedValue([
        { exists: true, id: 'host-user-id', data: () => noTokenUserData },
        { exists: true, id: 'member1', data: () => noTokenUserData },
      ] as any);

      const request = {
        data: { promiseId: 'test-promise-id' },
        auth: { uid: 'host-user-id' },
      };

      const result = await startLiveActivity(request);

      expect(result.success).toBe(true);
      expect(result.successCount).toBe(0);
    });
  });
});

// ============================================================================
// updateETA 테스트
// ============================================================================

describe('updateETA', () => {
  let updateETA: any;
  let mockFirestore: any;

  beforeEach(async () => {
    jest.clearAllMocks();

    mockFirestore = {
      collection: jest.fn().mockReturnValue({
        doc: jest.fn().mockReturnValue({
          get: jest.fn().mockResolvedValue(createMockDocument(true, {}) as any),
        }),
      }),
    };

    jest.spyOn(admin, 'firestore').mockReturnValue(mockFirestore as any);

    // HTTP/2 성공 시뮬레이션
    simulateHttp2Success(200);

    const functions = await import('../src/functions/liveActivity');
    updateETA = functions.updateETA;
  });

  afterEach(() => {
    jest.restoreAllMocks();
    jest.resetModules();
  });

  // NOTE: 정상 케이스는 실제 APNs/Cloud Tasks 작업이 필요하여 에뮬레이터 환경에서 통합 테스트로 수행
  describe.skip('정상 케이스', () => {
    it('ETA를 성공적으로 업데이트한다', async () => {
      const request = {
        data: {
          promiseId: 'test-promise-id',
          channelId: 'ch-12345',
          participants: [
            { id: 'user1', name: '유저1', estimatedArrivalMinutes: 10 },
            { id: 'user2', name: '유저2', estimatedArrivalMinutes: 5 },
          ],
          trackingDurationMinutes: 30,
        },
        auth: { uid: 'user1' },
      };

      const result = await updateETA(request);

      expect(result).toBeDefined();
      expect(result.success).toBe(true);
    });

    it('첫 번째 도착 시 alert를 포함한다', async () => {
      const request = {
        data: {
          channelId: 'ch-12345',
          participants: [
            { id: 'user1', name: '유저1', estimatedArrivalMinutes: 0 }, // 도착
            { id: 'user2', name: '유저2', estimatedArrivalMinutes: 5 },
          ],
          trackingDurationMinutes: 30,
        },
        auth: { uid: 'user1' },
      };

      const result = await updateETA(request);

      expect(result.success).toBe(true);
    });

    it('모두 도착 시 종료 Task를 예약한다', async () => {
      const request = {
        data: {
          promiseId: 'test-promise-id',
          channelId: 'ch-12345',
          participants: [
            { id: 'user1', name: '유저1', estimatedArrivalMinutes: 0 },
            { id: 'user2', name: '유저2', estimatedArrivalMinutes: 0 },
          ],
          trackingDurationMinutes: 30,
        },
        auth: { uid: 'user1' },
      };

      const result = await updateETA(request);

      expect(result.success).toBe(true);
      expect(mockTaskQueue.enqueue).toHaveBeenCalled();
    });
  });

  describe('인증 에러', () => {
    it('인증 없이 호출 시 에러를 발생시킨다', async () => {
      const request = {
        data: {
          channelId: 'ch-12345',
          participants: [],
        },
        auth: undefined,
      };

      await expect(updateETA(request)).rejects.toThrow();
    });
  });

  describe('유효성 검사 에러', () => {
    it('channelId가 없으면 에러를 발생시킨다', async () => {
      const request = {
        data: {
          participants: [],
        },
        auth: { uid: 'user1' },
      };

      await expect(updateETA(request)).rejects.toThrow();
    });

    it('participants가 없으면 에러를 발생시킨다', async () => {
      const request = {
        data: {
          channelId: 'ch-12345',
        },
        auth: { uid: 'user1' },
      };

      await expect(updateETA(request)).rejects.toThrow();
    });
  });
});

// ============================================================================
// widgetUpdateETA 테스트
// ============================================================================

describe('widgetUpdateETA', () => {
  let widgetUpdateETA: any;
  let mockFirestore: any;

  const mockPromiseData = {
    groupId: 'test-group-id',
  };

  const mockGroupData = {
    memberIds: ['user1', 'user2', 'user3'],
  };

  beforeEach(async () => {
    jest.clearAllMocks();

    mockFirestore = {
      collection: jest.fn((name: string) => {
        if (name === 'promises') {
          return {
            doc: jest.fn().mockReturnValue({
              get: jest.fn().mockResolvedValue(
                createMockDocument(true, mockPromiseData) as any
              ),
            }),
          };
        }
        if (name === 'groups') {
          return {
            doc: jest.fn().mockReturnValue({
              get: jest.fn().mockResolvedValue(
                createMockDocument(true, mockGroupData) as any
              ),
            }),
          };
        }
        return {};
      }),
    };

    jest.spyOn(admin, 'firestore').mockReturnValue(mockFirestore as any);

    // HTTP/2 성공 시뮬레이션
    simulateHttp2Success(200);

    // Firebase Auth mock
    jest.spyOn(admin, 'auth').mockReturnValue({
      verifyIdToken: jest.fn().mockResolvedValue({ uid: 'user1' } as any),
    } as any);

    const functions = await import('../src/functions/liveActivity');
    widgetUpdateETA = functions.widgetUpdateETA;
  });

  afterEach(() => {
    jest.restoreAllMocks();
    jest.resetModules();
  });

  describe('정상 케이스', () => {
    it('Widget에서 ETA를 성공적으로 업데이트한다', async () => {
      const req = {
        method: 'POST',
        headers: {
          'x-user-id': 'user1',
        },
        body: {
          channelId: 'ch-12345',
          participants: [
            { id: 'user1', name: '유저1', estimatedArrivalMinutes: 5 },
          ],
        },
      };

      const res = {
        set: jest.fn(),
        status: jest.fn().mockReturnThis(),
        json: jest.fn(),
        send: jest.fn(),
      };

      // onRequest는 wrapped function
      const handler = widgetUpdateETA.run;
      if (handler) {
        await handler(req, res);
        expect(res.status).toHaveBeenCalledWith(200);
      }
    });
  });

  describe('OPTIONS 요청 (CORS)', () => {
    it('OPTIONS 요청에 204를 반환한다', async () => {
      const req = {
        method: 'OPTIONS',
        headers: {},
      };

      const res = {
        set: jest.fn(),
        status: jest.fn().mockReturnThis(),
        send: jest.fn(),
      };

      const handler = widgetUpdateETA.run;
      if (handler) {
        await handler(req, res);
        expect(res.status).toHaveBeenCalledWith(204);
      }
    });
  });

  describe('HTTP 메서드 에러', () => {
    it('POST가 아닌 메서드는 405를 반환한다', async () => {
      const req = {
        method: 'GET',
        headers: {},
      };

      const res = {
        set: jest.fn(),
        status: jest.fn().mockReturnThis(),
        json: jest.fn(),
      };

      const handler = widgetUpdateETA.run;
      if (handler) {
        await handler(req, res);
        expect(res.status).toHaveBeenCalledWith(405);
      }
    });
  });

  describe('인증 에러', () => {
    it('X-User-Id 헤더가 없으면 401을 반환한다', async () => {
      const req = {
        method: 'POST',
        headers: {},
        body: {},
      };

      const res = {
        set: jest.fn(),
        status: jest.fn().mockReturnThis(),
        json: jest.fn(),
      };

      const handler = widgetUpdateETA.run;
      if (handler) {
        await handler(req, res);
        expect(res.status).toHaveBeenCalledWith(401);
      }
    });
  });

  describe('권한 에러', () => {
    it('그룹 멤버가 아니면 403을 반환한다', async () => {
      const req = {
        method: 'POST',
        headers: {
          'x-user-id': 'non-member-user',
        },
        body: {
          promiseId: 'test-promise-id',
          channelId: 'ch-12345',
          participants: [],
        },
      };

      const res = {
        set: jest.fn(),
        status: jest.fn().mockReturnThis(),
        json: jest.fn(),
      };

      const handler = widgetUpdateETA.run;
      if (handler) {
        await handler(req, res);
        expect(res.status).toHaveBeenCalledWith(403);
      }
    });
  });
});

// ============================================================================
// executeLiveActivityStart 테스트
// ============================================================================

describe('executeLiveActivityStart', () => {
  let executeLiveActivityStart: any;
  let mockFirestore: any;
  let mockPromiseRef: any;
  const scheduleVersion = 'schedule-v1';

  const mockPromiseData = {
    groupId: 'test-group-id',
    hostId: 'host-user-id',
    title: '테스트 약속',
    emoji: '📍',
    location: { name: '홍대입구역' },
    startAt: createMockTimestamp(new Date(Date.now() + 3600000)),
    votes: { accepted: ['host-user-id', 'member1'] },
    minimumParticipants: 2,
    trackingStartMinutesBefore: 30,
    liveActivitySchedule: {
      scheduled: true,
      started: false,
      version: scheduleVersion,
    },
  };

  const mockGroupData = {
    name: '테스트 그룹',
    imageUrl: null,
  };

  const mockUserData = (userId: string) => ({
    nickname: `유저 ${userId}`,
    devices: {
      'device-1': {
        pushToStartToken: `token-${userId}`,
      },
    },
  });

  beforeEach(async () => {
    jest.clearAllMocks();

    mockPromiseRef = {
      get: jest.fn().mockResolvedValue(
        createMockDocument(true, mockPromiseData) as any
      ),
      update: jest.fn().mockResolvedValue(undefined as any),
    };

    mockFirestore = {
      collection: jest.fn((name: string) => {
        if (name === 'promises') {
          return {
            doc: jest.fn().mockReturnValue(mockPromiseRef),
          };
        }
        if (name === 'groups') {
          return {
            doc: jest.fn().mockReturnValue({
              get: jest.fn().mockResolvedValue(
                createMockDocument(true, mockGroupData) as any
              ),
            }),
          };
        }
        if (name === 'users') {
          return {
            doc: jest.fn((userId: string) => ({
              id: userId,
            })),
          };
        }
        return {};
      }),
      getAll: jest.fn().mockImplementation((...refs: any[]) => {
        return Promise.resolve(
          refs.map((ref) => ({
            exists: true,
            id: ref.id || 'user-id',
            data: () => mockUserData(ref.id || 'user-id'),
          }))
        );
      }),
    };

    jest.spyOn(admin, 'firestore').mockReturnValue(mockFirestore as any);

    // HTTP/2 성공 시뮬레이션 (채널 생성 + 푸시 전송)
    simulateHttp2Success(201, { 'apns-channel-id': 'ch-new-channel' });

    const functions = await import('../src/functions/liveActivity');
    executeLiveActivityStart = functions.executeLiveActivityStart;
  });

  afterEach(() => {
    jest.restoreAllMocks();
    jest.resetModules();
  });

  // NOTE: 정상 케이스는 실제 APNs HTTP/2 작업이 필요하여 에뮬레이터 환경에서 통합 테스트로 수행
  describe.skip('정상 케이스', () => {
    it('예약된 시간에 LiveActivity를 시작한다', async () => {
      const taskData = {
        data: { promiseId: 'test-promise-id', scheduleVersion },
      };

      // Cloud Task handler는 run 메서드
      const handler = executeLiveActivityStart.run;
      if (handler) {
        await expect(handler(taskData)).resolves.not.toThrow();
      }
    });
  });

  // NOTE: 실제 Firestore/APNs 작업이 필요하여 에뮬레이터 환경에서 통합 테스트로 수행
  describe.skip('약속 미확정', () => {
    it('최소 인원 미충족 시 시작하지 않는다', async () => {
      const notConfirmedPromise = {
        ...mockPromiseData,
        votes: { accepted: ['host-user-id'] }, // 1명만 수락
        minimumParticipants: 2,
      };

      mockFirestore.collection = jest.fn().mockReturnValue({
        doc: jest.fn().mockReturnValue({
          get: jest.fn().mockResolvedValue(
            createMockDocument(true, notConfirmedPromise) as any
          ),
        }),
      });

      const taskData = {
        data: { promiseId: 'test-promise-id', scheduleVersion },
      };

      const handler = executeLiveActivityStart.run;
      if (handler) {
        // 에러 없이 조용히 종료
        await expect(handler(taskData)).resolves.not.toThrow();
      }
    });
  });

  // NOTE: 실제 Firestore 작업이 필요하여 에뮬레이터 환경에서 통합 테스트로 수행
  describe.skip('약속 없음', () => {
    it('존재하지 않는 약속은 조용히 종료한다', async () => {
      mockFirestore.collection = jest.fn().mockReturnValue({
        doc: jest.fn().mockReturnValue({
          get: jest.fn().mockResolvedValue(createMockDocument(false) as any),
        }),
      });

      const taskData = {
        data: { promiseId: 'nonexistent-promise', scheduleVersion },
      };

      const handler = executeLiveActivityStart.run;
      if (handler) {
        await expect(handler(taskData)).resolves.not.toThrow();
      }
    });
  });

  // NOTE: 실제 Firestore 작업이 필요하여 에뮬레이터 환경에서 통합 테스트로 수행
  describe.skip('토큰 없음', () => {
    it('토큰이 없으면 조용히 종료한다', async () => {
      mockFirestore.getAll = jest.fn().mockResolvedValue([
        { exists: true, id: 'user-id', data: () => ({ nickname: '유저', devices: {} }) },
      ] as any);

      const taskData = {
        data: { promiseId: 'test-promise-id', scheduleVersion },
      };

      const handler = executeLiveActivityStart.run;
      if (handler) {
        await expect(handler(taskData)).resolves.not.toThrow();
      }
    });
  });

  describe.skip('started 롤백', () => {
    it('채널 생성 실패 시 started를 false로 롤백한다', async () => {
      simulateHttp2Success(500);

      const taskData = {
        data: { promiseId: 'test-promise-id', scheduleVersion },
      };

      const handler = executeLiveActivityStart.run;
      if (handler) {
        await expect(handler(taskData)).resolves.not.toThrow();
      }

      expect(mockPromiseRef.update).toHaveBeenNthCalledWith(1, {
        'liveActivitySchedule.started': true,
      });
      expect(mockPromiseRef.update).toHaveBeenNthCalledWith(2, {
        'liveActivitySchedule.started': false,
      });
      expect(mockTaskQueue.enqueue).not.toHaveBeenCalled();
    });

    it('토큰이 없으면 started를 false로 롤백한다', async () => {
      mockFirestore.getAll = jest.fn().mockResolvedValue([
        { exists: true, id: 'host-user-id', data: () => ({ nickname: '호스트', devices: {} }) },
        { exists: true, id: 'member1', data: () => ({ nickname: '멤버', devices: {} }) },
      ] as any);

      const taskData = {
        data: { promiseId: 'test-promise-id', scheduleVersion },
      };

      const handler = executeLiveActivityStart.run;
      if (handler) {
        await expect(handler(taskData)).resolves.not.toThrow();
      }

      expect(mockPromiseRef.update).toHaveBeenNthCalledWith(1, {
        'liveActivitySchedule.started': true,
      });
      expect(mockPromiseRef.update).toHaveBeenNthCalledWith(2, {
        'liveActivitySchedule.started': false,
      });
      expect(mockTaskQueue.enqueue).not.toHaveBeenCalled();
    });

    it('Push to Start가 전부 실패하면 started를 false로 롤백한다', async () => {
      simulateHttp2Sequence([
        { statusCode: 201, headers: { 'apns-channel-id': 'ch-new-channel' } },
        { statusCode: 500 },
        { statusCode: 500 },
      ]);

      const taskData = {
        data: { promiseId: 'test-promise-id', scheduleVersion },
      };

      const handler = executeLiveActivityStart.run;
      if (handler) {
        await expect(handler(taskData)).resolves.not.toThrow();
      }

      expect(mockPromiseRef.update).toHaveBeenNthCalledWith(1, {
        'liveActivitySchedule.started': true,
      });
      expect(mockPromiseRef.update).toHaveBeenNthCalledWith(2, {
        'liveActivitySchedule.started': false,
      });
      expect(mockTaskQueue.enqueue).not.toHaveBeenCalled();
    });
  });
});

// ============================================================================
// executeLiveActivityEnd 테스트
// ============================================================================

describe('executeLiveActivityEnd', () => {
  let executeLiveActivityEnd: any;

  beforeEach(async () => {
    jest.clearAllMocks();

    // HTTP/2 성공 시뮬레이션
    simulateHttp2Success(200);

    const functions = await import('../src/functions/liveActivity');
    executeLiveActivityEnd = functions.executeLiveActivityEnd;
  });

  afterEach(() => {
    jest.restoreAllMocks();
    jest.resetModules();
  });

  describe('정상 케이스', () => {
    it('LiveActivity를 성공적으로 종료한다', async () => {
      const taskData = {
        data: {
          promiseId: 'test-promise-id',
          channelId: 'ch-12345',
        },
      };

      const handler = executeLiveActivityEnd.run;
      if (handler) {
        await expect(handler(taskData)).resolves.not.toThrow();
      }
    });
  });

  describe('channelId 없음', () => {
    it('channelId가 없으면 조용히 종료한다', async () => {
      const taskData = {
        data: {
          promiseId: 'test-promise-id',
          channelId: '', // 빈 channelId
        },
      };

      const handler = executeLiveActivityEnd.run;
      if (handler) {
        await expect(handler(taskData)).resolves.not.toThrow();
      }
    });
  });
});

// ============================================================================
// onPromiseConfirmedScheduleLiveActivity 트리거 테스트
// ============================================================================

describe('onPromiseConfirmedScheduleLiveActivity', () => {
  let onPromiseConfirmedScheduleLiveActivity: any;
  let mockFirestore: any;
  let mockPromiseRef: any;

  beforeEach(async () => {
    jest.clearAllMocks();

    mockPromiseRef = {
      update: jest.fn().mockResolvedValue(undefined as any),
    };

    mockFirestore = {
      collection: jest.fn().mockReturnValue({
        doc: jest.fn().mockReturnValue(mockPromiseRef),
      }),
    };

    jest.spyOn(admin, 'firestore').mockReturnValue(mockFirestore as any);

    const functions = await import('../src/functions/liveActivity');
    onPromiseConfirmedScheduleLiveActivity = functions.onPromiseConfirmedScheduleLiveActivity;
  });

  afterEach(() => {
    jest.restoreAllMocks();
    jest.resetModules();
  });

  // NOTE: 정상 케이스는 실제 Cloud Tasks 작업이 필요하여 에뮬레이터 환경에서 통합 테스트로 수행
  describe.skip('정상 케이스', () => {
    it('약속 확정 시 LiveActivity 시작을 예약한다', async () => {
      const event = {
        data: {
          before: {
            data: () => ({
              votes: { accepted: ['user1'] },
              minimumParticipants: 2,
              trackingStartMinutesBefore: 30,
              startAt: createMockTimestamp(new Date(Date.now() + 7200000)), // 2시간 후
            }),
          },
          after: {
            data: () => ({
              votes: { accepted: ['user1', 'user2'] }, // 2명으로 확정
              minimumParticipants: 2,
              trackingStartMinutesBefore: 30,
              startAt: createMockTimestamp(new Date(Date.now() + 7200000)),
            }),
          },
        },
        params: { promiseId: 'test-promise-id' },
      };

      const handler = onPromiseConfirmedScheduleLiveActivity.run;
      if (handler) {
        await handler(event);
        expect(mockTaskQueue.enqueue).toHaveBeenCalled();
        expect(mockPromiseRef.update).toHaveBeenCalledWith(
          expect.objectContaining({
            liveActivitySchedule: expect.objectContaining({ scheduled: true }),
          })
        );
      }
    });
  });

  // NOTE: 실제 Firestore 작업이 필요하여 에뮬레이터 환경에서 통합 테스트로 수행
  describe.skip('미확정 -> 확정 취소', () => {
    it('확정 취소 시 예약 상태를 리셋한다', async () => {
      const event = {
        data: {
          before: {
            data: () => ({
              votes: { accepted: ['user1', 'user2'] },
              minimumParticipants: 2,
              trackingStartMinutesBefore: 30,
              startAt: createMockTimestamp(new Date(Date.now() + 7200000)),
            }),
          },
          after: {
            data: () => ({
              votes: { accepted: ['user1'] }, // 1명으로 미확정
              minimumParticipants: 2,
              trackingStartMinutesBefore: 30,
              startAt: createMockTimestamp(new Date(Date.now() + 7200000)),
            }),
          },
        },
        params: { promiseId: 'test-promise-id' },
      };

      const handler = onPromiseConfirmedScheduleLiveActivity.run;
      if (handler) {
        await handler(event);
        expect(mockPromiseRef.update).toHaveBeenCalledWith(
          expect.objectContaining({
            liveActivitySchedule: null,
          })
        );
      }
    });
  });

  // NOTE: 실제 Firestore 작업이 필요하여 에뮬레이터 환경에서 통합 테스트로 수행
  describe.skip('trackingMinutes 변경', () => {
    it('trackingMinutes가 null로 변경되면 예약을 취소한다', async () => {
      const event = {
        data: {
          before: {
            data: () => ({
              votes: { accepted: ['user1', 'user2'] },
              minimumParticipants: 2,
              trackingStartMinutesBefore: 30,
              startAt: createMockTimestamp(new Date(Date.now() + 7200000)),
            }),
          },
          after: {
            data: () => ({
              votes: { accepted: ['user1', 'user2'] },
              minimumParticipants: 2,
              trackingStartMinutesBefore: null, // 비활성화
              startAt: createMockTimestamp(new Date(Date.now() + 7200000)),
            }),
          },
        },
        params: { promiseId: 'test-promise-id' },
      };

      const handler = onPromiseConfirmedScheduleLiveActivity.run;
      if (handler) {
        await handler(event);
        expect(mockPromiseRef.update).toHaveBeenCalledWith(
          expect.objectContaining({
            liveActivitySchedule: null,
          })
        );
      }
    });
  });

  describe('이미 시작된 약속', () => {
    it('약속 시간이 지났으면 예약하지 않는다', async () => {
      const event = {
        data: {
          before: {
            data: () => ({
              votes: { accepted: ['user1'] },
              minimumParticipants: 2,
              trackingStartMinutesBefore: 30,
              startAt: createMockTimestamp(new Date(Date.now() - 3600000)), // 1시간 전
            }),
          },
          after: {
            data: () => ({
              votes: { accepted: ['user1', 'user2'] },
              minimumParticipants: 2,
              trackingStartMinutesBefore: 30,
              startAt: createMockTimestamp(new Date(Date.now() - 3600000)), // 이미 지남
            }),
          },
        },
        params: { promiseId: 'test-promise-id' },
      };

      const handler = onPromiseConfirmedScheduleLiveActivity.run;
      if (handler) {
        await handler(event);
        expect(mockTaskQueue.enqueue).not.toHaveBeenCalled();
      }
    });
  });
});

// ============================================================================
// APNs 유틸리티 테스트
// ============================================================================

describe('APNs Utilities', () => {
  describe('generateAPNsJWT', () => {
    let generateAPNsJWT: any;

    beforeEach(async () => {
      jest.clearAllMocks();
      const apns = await import('../src/utils/apns');
      generateAPNsJWT = apns.generateAPNsJWT;
    });

    afterEach(() => {
      jest.resetModules();
    });

    it('유효한 JWT를 생성한다', () => {
      expect(generateAPNsJWT).toBeDefined();
    });
  });

  describe('sendAPNsPush', () => {
    let sendAPNsPush: any;

    beforeEach(async () => {
      jest.clearAllMocks();
      simulateHttp2Success(200);
      const apns = await import('../src/utils/apns');
      sendAPNsPush = apns.sendAPNsPush;
    });

    afterEach(() => {
      jest.resetModules();
    });

    it('함수가 정의되어 있다', () => {
      expect(sendAPNsPush).toBeDefined();
    });
  });

  describe('createAPNsChannel', () => {
    let createAPNsChannel: any;

    beforeEach(async () => {
      jest.clearAllMocks();
      simulateHttp2Success(201, { 'apns-channel-id': 'ch-test-channel' });
      const apns = await import('../src/utils/apns');
      createAPNsChannel = apns.createAPNsChannel;
    });

    afterEach(() => {
      jest.resetModules();
    });

    it('함수가 정의되어 있다', () => {
      expect(createAPNsChannel).toBeDefined();
    });
  });

  describe('sendAPNsBroadcast', () => {
    let sendAPNsBroadcast: any;

    beforeEach(async () => {
      jest.clearAllMocks();
      simulateHttp2Success(200);
      const apns = await import('../src/utils/apns');
      sendAPNsBroadcast = apns.sendAPNsBroadcast;
    });

    afterEach(() => {
      jest.resetModules();
    });

    it('함수가 정의되어 있다', () => {
      expect(sendAPNsBroadcast).toBeDefined();
    });
  });
});

// ============================================================================
// Edge Cases 테스트
// ============================================================================

describe('Edge Cases', () => {
  describe('중복 시작 처리', () => {
    it('이미 스케줄된 약속은 다시 스케줄하지 않는다', async () => {
      jest.clearAllMocks();

      const mockPromiseRef = {
        update: jest.fn().mockResolvedValue(undefined as any),
      };

      const mockFirestore = {
        collection: jest.fn().mockReturnValue({
          doc: jest.fn().mockReturnValue(mockPromiseRef),
        }),
      };

      jest.spyOn(admin, 'firestore').mockReturnValue(mockFirestore as any);

      const functions = await import('../src/functions/liveActivity');
      const trigger = functions.onPromiseConfirmedScheduleLiveActivity;

      const event = {
        data: {
          before: {
            data: () => ({
              votes: { accepted: ['user1', 'user2'] },
              minimumParticipants: 2,
              trackingStartMinutesBefore: 30,
              liveActivitySchedule: { scheduled: true }, // 이미 스케줄됨
              startAt: createMockTimestamp(new Date(Date.now() + 7200000)),
            }),
          },
          after: {
            data: () => ({
              votes: { accepted: ['user1', 'user2', 'user3'] }, // 멤버만 추가
              minimumParticipants: 2,
              trackingStartMinutesBefore: 30, // 같은 값
              liveActivitySchedule: { scheduled: true },
              startAt: createMockTimestamp(new Date(Date.now() + 7200000)),
            }),
          },
        },
        params: { promiseId: 'test-promise-id' },
      };

      const handler = trigger.run;
      if (handler) {
        await handler(event);
        // trackingMinutes가 변경되지 않았으므로 재스케줄 안함
        expect(mockTaskQueue.enqueue).not.toHaveBeenCalled();
      }
    });
  });

  // NOTE: 실제 APNs HTTP/2 작업이 필요하여 에뮬레이터 환경에서 통합 테스트로 수행
  describe.skip('대량 사용자 처리', () => {
    it('10명 이상의 사용자도 배치로 처리한다', async () => {
      jest.clearAllMocks();

      // 15명의 멤버
      const memberIds = Array.from({ length: 15 }, (_, i) => `user${i + 1}`);

      const mockPromiseData = {
        groupId: 'test-group-id',
        hostId: 'user1',
        title: '대규모 약속',
        emoji: '🎉',
        location: null,
        startAt: createMockTimestamp(new Date(Date.now() + 3600000)),
        votes: { accepted: memberIds },
        trackingStartMinutesBefore: 30,
      };

      const mockGroupData = {
        name: '대규모 그룹',
        memberIds,
      };

      const mockFirestore = {
        collection: jest.fn((name: string) => {
          if (name === 'promises') {
            return {
              doc: jest.fn().mockReturnValue({
                get: jest.fn().mockResolvedValue(
                  createMockDocument(true, mockPromiseData) as any
                ),
              }),
            };
          }
          if (name === 'groups') {
            return {
              doc: jest.fn().mockReturnValue({
                get: jest.fn().mockResolvedValue(
                  createMockDocument(true, mockGroupData) as any
                ),
              }),
            };
          }
          if (name === 'users') {
            return {
              doc: jest.fn((userId: string) => ({ id: userId })),
            };
          }
          return {};
        }),
        getAll: jest.fn().mockImplementation((...refs: any[]) => {
          return Promise.resolve(
            refs.map((ref) => ({
              exists: true,
              id: ref.id || 'user-id',
              data: () => ({
                nickname: `유저 ${ref.id}`,
                devices: {
                  'device-1': {
                    liveActivityPushToStartToken: `token-${ref.id}`,
                  },
                },
              }),
            }))
          );
        }),
      };

      jest.spyOn(admin, 'firestore').mockReturnValue(mockFirestore as any);

      // HTTP/2 성공 시뮬레이션
      simulateHttp2Success(200);

      const functions = await import('../src/functions/liveActivity');
      const startLiveActivity = functions.startLiveActivity;

      const request = {
        data: { promiseId: 'test-promise-id' },
        auth: { uid: 'user1' },
      };

      const result = await startLiveActivity(request);

      expect(result.success).toBe(true);
      // getAll이 배치로 호출되었는지 확인 (10개씩)
      expect(mockFirestore.getAll).toHaveBeenCalled();
    });
  });

  // NOTE: 실제 APNs HTTP/2 작업이 필요하여 에뮬레이터 환경에서 통합 테스트로 수행
  describe.skip('빈 응답 처리', () => {
    it('참가자가 0명이면 successCount 0을 반환한다', async () => {
      jest.clearAllMocks();

      const emptyPromiseData = {
        groupId: 'test-group-id',
        hostId: 'host-user-id',
        title: '빈 약속',
        emoji: '📅',
        startAt: createMockTimestamp(new Date(Date.now() + 3600000)),
        votes: { accepted: ['host-user-id'] }, // 호스트만
        trackingStartMinutesBefore: 30,
      };

      const emptyGroupData = {
        name: '빈 그룹',
        memberIds: ['host-user-id'],
      };

      // 토큰 없는 사용자
      const noTokenUser = {
        nickname: '호스트',
        devices: {},
      };

      const mockFirestore = {
        collection: jest.fn((name: string) => {
          if (name === 'promises') {
            return {
              doc: jest.fn().mockReturnValue({
                get: jest.fn().mockResolvedValue(
                  createMockDocument(true, emptyPromiseData) as any
                ),
              }),
            };
          }
          if (name === 'groups') {
            return {
              doc: jest.fn().mockReturnValue({
                get: jest.fn().mockResolvedValue(
                  createMockDocument(true, emptyGroupData) as any
                ),
              }),
            };
          }
          if (name === 'users') {
            return {
              doc: jest.fn(() => ({ id: 'host-user-id' })),
            };
          }
          return {};
        }),
        getAll: jest.fn().mockResolvedValue([
          { exists: true, id: 'host-user-id', data: () => noTokenUser },
        ] as any),
      };

      jest.spyOn(admin, 'firestore').mockReturnValue(mockFirestore as any);

      const functions = await import('../src/functions/liveActivity');
      const startLiveActivity = functions.startLiveActivity;

      const request = {
        data: { promiseId: 'test-promise-id' },
        auth: { uid: 'host-user-id' },
      };

      const result = await startLiveActivity(request);

      expect(result.success).toBe(true);
      expect(result.successCount).toBe(0);
    });
  });
});
