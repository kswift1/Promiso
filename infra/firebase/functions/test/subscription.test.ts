// @ts-nocheck
/* eslint-disable @typescript-eslint/no-explicit-any */
/**
 * Subscription Functions 테스트
 *
 * verifyPurchase / appleServerNotification의 보안 및 정합성 회귀를 검증한다.
 */
import {
  describe,
  it,
  expect,
  jest,
  beforeEach,
  afterEach,
} from "@jest/globals";

jest.mock("../src/utils/appstore", () => ({
  verifyAppleTransactionJWS: jest.fn(),
  verifyAppleRenewalInfoJWS: jest.fn(),
  verifyAppleNotificationPayload: jest.fn(),
}));

type MockFn = jest.Mock<any, any>;
const FUTURE_EXPIRATION = 1893456000000;

function createMockDocument(
  exists: boolean,
  data?: Record<string, unknown>,
): any {
  return {
    exists,
    id: "mock-doc-id",
    data: () => data,
    ref: {
      id: "mock-doc-id",
      update: jest.fn(),
    },
  };
}

function createMockTransactionPayload(
  overrides?: Record<string, unknown>,
): Record<string, unknown> {
  return {
    productId: "com.promiso.pro.monthly",
    originalTransactionId: "txn-123",
    transactionId: "tx-001",
    purchaseDate: 1700000000000,
    expiresDate: FUTURE_EXPIRATION,
    signedDate: 1700000001000,
    type: "Auto-Renewable Subscription",
    ...overrides,
  };
}

function createMockNotificationPayload(
  overrides?: Record<string, unknown>,
): Record<string, unknown> {
  return {
    notificationType: "DID_RENEW",
    signedDate: 1700000002000,
    data: {
      signedTransactionInfo: "signed-transaction-info",
    },
    ...overrides,
  };
}

function createMockRenewalInfoPayload(
  overrides?: Record<string, unknown>,
): Record<string, unknown> {
  return {
    originalTransactionId: "txn-123",
    productId: "com.promiso.pro.monthly",
    autoRenewProductId: "com.promiso.pro.monthly",
    signedDate: 1700000001500,
    renewalDate: FUTURE_EXPIRATION,
    ...overrides,
  };
}

describe("subscription functions", () => {
  let appleServerNotification: any;

  let verifyAppleTransactionJWSMock: MockFn;
  let verifyAppleRenewalInfoJWSMock: MockFn;
  let verifyAppleNotificationPayloadMock: MockFn;

  let mockFirestore: any;
  let mockTransaction: any;
  let mockOwnerRef: any;
  let mockSubscriptionRef: any;
  let mockSettingsRef: any;
  let mockBriefingSubscriptionRef: any;
  let mockUserRef: any;

  let ownerDocument: any;
  let subscriptionDocument: any;

  beforeEach(async () => {
    jest.clearAllMocks();

    const appstore = await import("../src/utils/appstore");
    verifyAppleTransactionJWSMock =
      appstore.verifyAppleTransactionJWS as MockFn;
    verifyAppleRenewalInfoJWSMock =
      appstore.verifyAppleRenewalInfoJWS as MockFn;
    verifyAppleNotificationPayloadMock =
      appstore.verifyAppleNotificationPayload as MockFn;

    ownerDocument = createMockDocument(false);
    subscriptionDocument = createMockDocument(false);

    mockOwnerRef = {
      id: "txn-123",
      get: jest.fn(() => Promise.resolve(ownerDocument)),
    };

    mockSubscriptionRef = {
      id: "user-a",
    };

    mockSettingsRef = {
      id: "main",
    };

    mockBriefingSubscriptionRef = {
      id: "user-a",
    };

    mockUserRef = {
      id: "user-a",
      collection: jest.fn((name: string) => {
        if (name === "settings") {
          return {
            doc: jest.fn().mockReturnValue(mockSettingsRef),
          };
        }
        return {};
      }),
    };

    mockTransaction = {
      get: jest.fn((ref: any) => {
        if (ref === mockOwnerRef) {
          return Promise.resolve(ownerDocument);
        }
        if (ref === mockSubscriptionRef) {
          return Promise.resolve(subscriptionDocument);
        }
        return Promise.resolve(createMockDocument(false));
      }),
      set: jest.fn(),
      delete: jest.fn(),
    };

    mockFirestore = {
      collection: jest.fn((name: string) => {
        if (name === "subscriptionOwners") {
          return {
            doc: jest.fn().mockReturnValue(mockOwnerRef),
          };
        }
        if (name === "subscriptions") {
          return {
            doc: jest.fn().mockReturnValue(mockSubscriptionRef),
          };
        }
        if (name === "briefingSubscriptions") {
          return {
            doc: jest.fn().mockReturnValue(mockBriefingSubscriptionRef),
          };
        }
        if (name === "users") {
          return {
            doc: jest.fn().mockReturnValue(mockUserRef),
          };
        }
        return {};
      }),
      runTransaction: jest.fn(async (callback: any) => {
        return await callback(mockTransaction);
      }),
    };

    const {admin: configAdmin} = await import("../src/config");
    const configFirestoreSpy = jest
      .spyOn(configAdmin, "firestore")
      .mockReturnValue(mockFirestore as any);
    (configFirestoreSpy as any).Timestamp = {
      now: jest.fn().mockReturnValue({seconds: 1700000000, nanoseconds: 0}),
    };
    (configAdmin.firestore as any).Timestamp = {
      now: jest.fn().mockReturnValue({seconds: 1700000000, nanoseconds: 0}),
    };

    const functions = await import("../src/functions/subscription");
    appleServerNotification = functions.appleServerNotification;
  });

  afterEach(() => {
    jest.restoreAllMocks();
    jest.resetModules();
  });

  function resolveWebhookHandler() {
    return typeof appleServerNotification === "function" ?
      appleServerNotification :
      (appleServerNotification as any).run;
  }

  function makeWebhookResponse() {
    return {
      status: jest.fn().mockReturnThis(),
      json: jest.fn(),
      send: jest.fn(),
    };
  }

  describe("appleServerNotification", () => {
    it("subscriptionOwners에서 owner를 찾아 갱신 웹훅 상태를 저장한다", async () => {
      verifyAppleNotificationPayloadMock.mockResolvedValue(
        createMockNotificationPayload(),
      );
      verifyAppleTransactionJWSMock.mockResolvedValue(
        createMockTransactionPayload(),
      );
      ownerDocument = createMockDocument(true, {
        userId: "user-a",
        productId: "com.promiso.pro.monthly",
      });

      const handler = resolveWebhookHandler();
      const res = makeWebhookResponse();

      await handler({
        body: {
          signedPayload: "signed-payload",
        },
      }, res);

      expect(mockOwnerRef.get).toHaveBeenCalledTimes(1);
      expect(mockTransaction.set).toHaveBeenCalledWith(
        mockSubscriptionRef,
        expect.objectContaining({
          status: "subscribed",
          productId: "com.promiso.pro.monthly",
          originalTransactionId: "txn-123",
          expirationDate: new Date(FUTURE_EXPIRATION).toISOString(),
          purchaseDate: new Date(1700000000000).toISOString(),
          lastNotificationType: "DID_RENEW",
          latestAppStoreSignedDate: 1700000002000,
        }),
        {merge: true},
      );
      expect(res.status).toHaveBeenCalledWith(200);
      expect(res.json).toHaveBeenCalledWith({success: true});
    });

    it("owner가 없으면 500으로 반환해 Apple 재시도를 유도한다", async () => {
      verifyAppleNotificationPayloadMock.mockResolvedValue(
        createMockNotificationPayload(),
      );
      verifyAppleTransactionJWSMock.mockResolvedValue(
        createMockTransactionPayload(),
      );

      const handler = resolveWebhookHandler();
      const res = makeWebhookResponse();

      await handler({
        body: {
          signedPayload: "signed-payload",
        },
      }, res);

      expect(mockOwnerRef.get).toHaveBeenCalledTimes(1);
      expect(mockFirestore.runTransaction).not.toHaveBeenCalled();
      expect(res.status).toHaveBeenCalledWith(500);
      expect(res.json).toHaveBeenCalledWith({
        success: false,
        error: "Owner not found for txId: txn-123",
      });
    });

    it("영구 오류면 200으로 응답해 Apple 재시도를 막는다", async () => {
      verifyAppleNotificationPayloadMock.mockRejectedValue(
        new Error("Invalid notification signature"),
      );

      const handler = resolveWebhookHandler();
      const res = makeWebhookResponse();

      await handler({
        body: {
          signedPayload: "signed-payload",
        },
      }, res);

      expect(mockOwnerRef.get).not.toHaveBeenCalled();
      expect(mockFirestore.runTransaction).not.toHaveBeenCalled();
      expect(res.status).toHaveBeenCalledWith(200);
      expect(res.json).toHaveBeenCalledWith({
        success: false,
        error: "Invalid notification signature",
      });
    });

    it("signedRenewalInfo가 있으면 gracePeriod 만료일을 저장한다", async () => {
      verifyAppleNotificationPayloadMock.mockResolvedValue(
        createMockNotificationPayload({
          notificationType: "DID_FAIL_TO_RENEW",
          data: {
            signedTransactionInfo: "signed-transaction-info",
            signedRenewalInfo: "signed-renewal-info",
          },
        }),
      );
      verifyAppleTransactionJWSMock.mockResolvedValue(
        createMockTransactionPayload({
          expiresDate: FUTURE_EXPIRATION,
        }),
      );
      verifyAppleRenewalInfoJWSMock.mockResolvedValue(
        createMockRenewalInfoPayload({
          signedDate: 1700000002500,
          isInBillingRetryPeriod: true,
          gracePeriodExpiresDate: 1703000000000,
        }),
      );
      ownerDocument = createMockDocument(true, {
        userId: "user-a",
        productId: "com.promiso.pro.monthly",
      });

      const handler = resolveWebhookHandler();
      const res = makeWebhookResponse();

      await handler({
        body: {
          signedPayload: "signed-payload",
        },
      }, res);

      expect(mockTransaction.set).toHaveBeenCalledWith(
        mockSubscriptionRef,
        expect.objectContaining({
          status: "gracePeriod",
          expirationDate: new Date(1703000000000).toISOString(),
          lastNotificationType: "DID_FAIL_TO_RENEW",
          latestAppStoreSignedDate: 1700000002500,
        }),
        {merge: true},
      );
      expect(res.status).toHaveBeenCalledWith(200);
    });

    it("refund 웹훅이면 revoked 상태를 저장한다", async () => {
      verifyAppleNotificationPayloadMock.mockResolvedValue(
        createMockNotificationPayload({
          notificationType: "REFUND",
        }),
      );
      verifyAppleTransactionJWSMock.mockResolvedValue(
        createMockTransactionPayload(),
      );
      ownerDocument = createMockDocument(true, {
        userId: "user-a",
        productId: "com.promiso.pro.monthly",
      });

      const handler = resolveWebhookHandler();
      const res = makeWebhookResponse();

      await handler({
        body: {
          signedPayload: "signed-payload",
        },
      }, res);

      expect(mockTransaction.set).toHaveBeenCalledWith(
        mockSubscriptionRef,
        expect.objectContaining({
          status: "revoked",
          lastNotificationType: "REFUND",
        }),
        {merge: true},
      );
      expect(res.status).toHaveBeenCalledWith(200);
      expect(res.json).toHaveBeenCalledWith({success: true});
    });
  });
});
