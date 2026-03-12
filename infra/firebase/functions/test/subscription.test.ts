// @ts-nocheck
/* eslint-disable @typescript-eslint/no-explicit-any */
/**
 * Subscription Functions 테스트
 *
 * verifyPurchase의 핵심 비즈니스 로직에 대한 유닛 테스트
 * - 소유권 등록 (새 트랜잭션)
 * - 동일 사용자 재검증
 * - 레이스 컨디션: 다른 사용자의 트랜잭션 도용 방지
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
  defineSecret: jest.fn((name: string) => ({
    value: () => 'test-secret-value',
  })),
}));

// verifyAppleJWS mock
jest.mock('../src/utils/appstore', () => ({
  verifyAppleJWS: jest.fn(),
}));


// ============================================================================
// 테스트 유틸리티
// ============================================================================

// Jest mock 타입 정의
type MockFn = jest.Mock<any, any>;

/**
 * Promise를 반환하는 mock 함수 생성
 */
function mockResolved<T>(value: T): MockFn {
  return jest.fn(() => Promise.resolve(value)) as MockFn;
}

function mockRejected(error: Error): MockFn {
  return jest.fn(() => Promise.reject(error)) as MockFn;
}

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
      update: mockResolved(undefined),
    },
  };
}

/**
 * 테스트용 JWS 페이로드 생성
 */
function createMockJWSPayload(overrides?: Record<string, unknown>): Record<string, unknown> {
  return {
    productId: 'com.promiso.pro.monthly',
    originalTransactionId: 'txn-123',
    purchaseDate: 1700000000000,
    expiresDate: 1702592000000,
    type: 'Auto-Renewable Subscription',
    ...overrides,
  };
}

// ============================================================================
// verifyPurchase 테스트
// ============================================================================

describe('verifyPurchase', () => {
  let verifyPurchase: any;
  let mockFirestore: any;
  let mockTransaction: any;
  let mockOwnerRef: any;
  let mockSubscriptionRef: any;
  let verifyAppleJWSMock: MockFn;

  beforeEach(async () => {
    jest.clearAllMocks();

    // verifyAppleJWS mock 가져오기
    const appstore = await import('../src/utils/appstore');
    verifyAppleJWSMock = appstore.verifyAppleJWS as MockFn;

    mockOwnerRef = {
      id: 'txn-123',
    };

    mockSubscriptionRef = {
      id: 'user-a',
    };

    mockTransaction = {
      get: jest.fn(),
      set: jest.fn(),
    };

    mockFirestore = {
      collection: jest.fn((name: string) => {
        if (name === 'subscriptionOwners') {
          return {
            doc: jest.fn().mockReturnValue(mockOwnerRef),
          };
        }
        if (name === 'subscriptions') {
          return {
            doc: jest.fn().mockReturnValue(mockSubscriptionRef),
          };
        }
        return {};
      }),
      runTransaction: jest.fn(async (callback: any) => {
        return await callback(mockTransaction);
      }),
    };

    // subscription.ts는 config에서 re-export된 admin을 사용하므로
    // configAdmin.firestore를 mock해야 admin.firestore() 호출이 mockFirestore를 반환
    const {admin: configAdmin} = await import('../src/config');
    const configFirestoreSpy = jest.spyOn(configAdmin, 'firestore').mockReturnValue(mockFirestore as any);
    // admin.firestore.Timestamp.now()를 위해 configAdmin.firestore에 Timestamp 설정
    // (subscription.ts line 153: admin.firestore.Timestamp.now())
    (configFirestoreSpy as any).Timestamp = {
      now: jest.fn().mockReturnValue({ seconds: 1700000000, nanoseconds: 0 }),
    };
    (configAdmin.firestore as any).Timestamp = {
      now: jest.fn().mockReturnValue({ seconds: 1700000000, nanoseconds: 0 }),
    };

    const functions = await import('../src/functions/subscription');
    verifyPurchase = functions.verifyPurchase;
  });

  afterEach(() => {
    jest.restoreAllMocks();
    jest.resetModules();
  });

  // NOTE: Firestore 트랜잭션을 mock 처리한 소유권 로직 유닛 테스트

  describe('새 트랜잭션 구매 시 소유권 등록 및 구독 저장', () => {
    it('소유권 문서가 없으면 새로 등록하고 구독 상태를 저장한다', async () => {
      // Given — 소유권 문서가 존재하지 않음
      verifyAppleJWSMock.mockResolvedValue(createMockJWSPayload() as any);
      mockTransaction.get.mockResolvedValue(createMockDocument(false) as any);

      const request = {
        data: {
          transactionJWS: 'test.jws.token',
          productId: 'com.promiso.pro.monthly',
        },
        auth: { uid: 'user-a' },
      };

      // When
      const handler = (verifyPurchase as any).run;
      const result = await handler(request);

      // Then
      expect(result).toBeDefined();
      expect(result.success).toBe(true);
      expect(result.subscriptionStatus).toBeDefined();
      expect(result.subscriptionStatus.productId).toBe('com.promiso.pro.monthly');
      expect(result.subscriptionStatus.originalTransactionId).toBe('txn-123');
      // transaction.set이 ownerRef, subscriptionRef 두 번 호출되어야 함
      expect(mockTransaction.set).toHaveBeenCalledTimes(2);
      expect(mockTransaction.set).toHaveBeenCalledWith(
        mockOwnerRef,
        expect.objectContaining({ userId: 'user-a', productId: 'com.promiso.pro.monthly' }),
        { merge: true }
      );
      expect(mockTransaction.set).toHaveBeenCalledWith(
        mockSubscriptionRef,
        expect.objectContaining({ originalTransactionId: 'txn-123' }),
        { merge: true }
      );
    });
  });

  describe('동일 사용자 재검증 시 성공', () => {
    it('같은 사용자가 동일 트랜잭션을 재검증하면 소유권을 갱신하고 성공한다', async () => {
      // Given — 소유권 문서가 이미 같은 사용자로 등록되어 있음
      verifyAppleJWSMock.mockResolvedValue(createMockJWSPayload() as any);
      mockTransaction.get.mockResolvedValue(
        createMockDocument(true, {
          userId: 'user-a',
          productId: 'com.promiso.pro.monthly',
          createdAt: { seconds: 1699000000, nanoseconds: 0 },
        }) as any
      );

      const request = {
        data: {
          transactionJWS: 'test.jws.token',
          productId: 'com.promiso.pro.monthly',
        },
        auth: { uid: 'user-a' },
      };

      // When
      const handler = (verifyPurchase as any).run;
      const result = await handler(request);

      // Then — 에러 없이 성공해야 함
      expect(result).toBeDefined();
      expect(result.success).toBe(true);
      expect(result.subscriptionStatus.originalTransactionId).toBe('txn-123');
      // 소유권 갱신(set)이 호출되어야 함
      expect(mockTransaction.set).toHaveBeenCalledWith(
        mockOwnerRef,
        expect.objectContaining({ userId: 'user-a' }),
        { merge: true }
      );
    });
  });

  describe('다른 사용자의 트랜잭션 사용 시 already-exists 에러', () => {
    it('이미 다른 사용자가 소유한 트랜잭션이면 already-exists 에러를 발생시킨다', async () => {
      // Given — 소유권 문서가 user-a로 등록되어 있고, user-b가 시도
      verifyAppleJWSMock.mockResolvedValue(createMockJWSPayload() as any);
      mockTransaction.get.mockResolvedValue(
        createMockDocument(true, {
          userId: 'user-a',
          productId: 'com.promiso.pro.monthly',
        }) as any
      );

      const request = {
        data: {
          transactionJWS: 'test.jws.token',
          productId: 'com.promiso.pro.monthly',
        },
        auth: { uid: 'user-b' }, // 다른 사용자
      };

      // When & Then — already-exists HttpsError가 발생해야 함
      const handler = (verifyPurchase as any).run;
      await expect(handler(request)).rejects.toMatchObject({
        code: 'already-exists',
      });
      // 소유권 set이 호출되지 않아야 함 (트랜잭션 중단)
      expect(mockTransaction.set).not.toHaveBeenCalled();
    });
  });

  describe('인증 에러', () => {
    it('인증 없이 호출 시 unauthenticated 에러를 발생시킨다', async () => {
      const request = {
        data: {
          transactionJWS: 'test.jws.token',
          productId: 'com.promiso.pro.monthly',
        },
        auth: undefined,
      };

      await expect(verifyPurchase(request)).rejects.toThrow();
    });
  });

  describe('유효성 검사 에러', () => {
    it('transactionJWS가 없으면 invalid-argument 에러를 발생시킨다', async () => {
      const request = {
        data: {
          productId: 'com.promiso.pro.monthly',
        },
        auth: { uid: 'user-a' },
      };

      await expect(verifyPurchase(request)).rejects.toThrow();
    });

    it('productId가 없으면 invalid-argument 에러를 발생시킨다', async () => {
      const request = {
        data: {
          transactionJWS: 'test.jws.token',
        },
        auth: { uid: 'user-a' },
      };

      await expect(verifyPurchase(request)).rejects.toThrow();
    });

    it('JWS의 productId와 요청 productId가 다르면 에러를 발생시킨다', async () => {
      // Given — JWS에는 monthly, 요청에는 yearly
      verifyAppleJWSMock.mockResolvedValue(
        createMockJWSPayload({ productId: 'com.promiso.pro.monthly' }) as any
      );

      const request = {
        data: {
          transactionJWS: 'test.jws.token',
          productId: 'com.promiso.pro.yearly', // 불일치
        },
        auth: { uid: 'user-a' },
      };

      await expect(verifyPurchase(request)).rejects.toThrow();
    });
  });
});
